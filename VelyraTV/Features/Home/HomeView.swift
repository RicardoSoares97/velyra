import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var viewModel = HomeViewModel()
  @State private var selectedItem: MediaItem?

  private var languageCode: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  private var regionCode: String {
    appState.preferences.contentRegion ?? Locale.current.region?.identifier ?? "PT"
  }

  private var regionName: String {
    let locale = appState.preferences.language.locale ?? Locale.current
    return locale.localizedString(forRegionCode: regionCode) ?? regionCode
  }

  private var loadTaskID: String {
    "\(traktStateID)|\(languageCode)|\(regionCode)"
  }

  private var traktStateID: String {
    switch appState.traktSession.state {
    case .disconnected: "disconnected"
    case .requestingCode: "requesting"
    case .awaitingAuthorization: "awaiting"
    case .connected: "connected"
    case .failed: "failed"
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      CinematicBackgroundView(
        videoName: "home-featured",
        focalColor: VelyraTheme.primary,
        honoursAutoplayPreference: true
      )
      .opacity(0.36)

      content
    }
    .fullScreenCover(item: $selectedItem) { item in
      MediaDetailsView(item: item)
    }
    .task(id: loadTaskID) {
      await viewModel.refresh(
        traktSession: appState.traktSession,
        language: languageCode,
        region: regionCode
      )
      if appState.distributionCapabilities.supportsTopShelf, let feed = viewModel.feed {
        _ = try? await TopShelfSnapshotStore.shared.saveIfChanged(.make(feed: feed))
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      loadingView
    case .loaded(let feed):
      feedView(feed)
    case .failed(let message, let feed):
      feedView(feed, warning: message)
    }
  }

  private var loadingView: some View {
    VStack(spacing: 22) {
      ProgressView()
        .controlSize(.large)
        .tint(VelyraTheme.primary)
      Text("home.loading")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.72))
    }
    .accessibilityElement(children: .combine)
  }

  private func feedView(_ feed: HomeFeed, warning: String? = nil) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 34) {
        CinematicHeroView(
          item: feed.hero,
          onPlay: { selectedItem = feed.hero },
          onDetails: { selectedItem = feed.hero }
        )

        if let warning {
          warningBanner(warning)
            .padding(.horizontal, 72)
        }

        ForEach(visibleSectionOrder) { preference in
          homeBlock(preference, feed: feed)
        }

        attributionFooter
          .padding(.horizontal, 72)
          .padding(.top, 18)
          .padding(.bottom, 100)
      }
    }
    .accessibleMotion(value: viewModel.selectedDiscoverySection?.id)
  }

  private var visibleSectionOrder: [HomeSectionPreference] {
    appState.preferences.homeSectionOrder.filter {
      !appState.preferences.hiddenHomeSections.contains($0)
    }
  }

  @ViewBuilder
  private func homeBlock(_ preference: HomeSectionPreference, feed: HomeFeed) -> some View {
    switch preference {
    case .continueWatching:
      if !feed.continueWatching.isEmpty {
        HomeSectionView(
          section: HomeSection(
            id: "continue-watching",
            title: String(localized: "home.continueWatching"),
            subtitle: String(localized: "home.continueWatching.synced"),
            style: .landscape,
            items: feed.continueWatching
          ),
          onSelect: { selectedItem = $0 }
        )
        .padding(.horizontal, 72)
      }
    case .genres:
      genreFilters(feed)
        .padding(.horizontal, 72)
      if viewModel.selectedGenreID != nil, let selected = viewModel.selectedDiscoverySection {
        HomeSectionView(section: selected, onSelect: { selectedItem = $0 })
          .padding(.horizontal, 72)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    case .providers:
      providerFilters(feed)
        .padding(.horizontal, 72)
      if viewModel.selectedProviderID != nil, let selected = viewModel.selectedDiscoverySection {
        HomeSectionView(section: selected, onSelect: { selectedItem = $0 })
          .padding(.horizontal, 72)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    case .trendingSeries:
      section(id: "trending-series", in: feed)
    case .trendingMovies:
      section(id: "trending-movies", in: feed)
    case .topSeries:
      section(id: "country-series", in: feed)
    case .topMovies:
      section(id: "country-movies", in: feed)
    case .providerCollections:
      ForEach(feed.sections.filter { $0.id.hasPrefix("provider-") }) { value in
        HomeSectionView(section: value, onSelect: { selectedItem = $0 })
          .padding(.horizontal, 72)
      }
    }
  }

  @ViewBuilder
  private func section(id: String, in feed: HomeFeed) -> some View {
    if let value = feed.sections.first(where: { $0.id == id }) {
      HomeSectionView(section: value, onSelect: { selectedItem = $0 })
        .padding(.horizontal, 72)
    }
  }

  private func genreFilters(_ feed: HomeFeed) -> some View {
    filterGroup(
      title: String(localized: "home.explore.genres"),
      subtitle: String(localized: "home.explore.genres.body")
    ) {
      ForEach(feed.genres) { genre in
        HomeFilterChip(
          title: genre.name,
          iconURL: nil,
          systemImage: "sparkles.tv",
          isSelected: viewModel.selectedGenreID == genre.id
        ) {
          Task {
            await viewModel.select(
              genre: genre,
              language: languageCode,
              region: regionCode
            )
          }
        }
      }
    }
  }

  private func providerFilters(_ feed: HomeFeed) -> some View {
    filterGroup(
      title: String(localized: "home.explore.providers"),
      subtitle: String(format: String(localized: "home.explore.providers.body"), regionName)
    ) {
      ForEach(feed.providers) { provider in
        HomeFilterChip(
          title: provider.name,
          iconURL: provider.logoURL,
          systemImage: provider.logoURL == nil ? "play.tv" : nil,
          isSelected: viewModel.selectedProviderID == provider.id
        ) {
          Task {
            await viewModel.select(
              provider: provider,
              language: languageCode,
              region: regionCode
            )
          }
        }
      }
    }
  }

  private func filterGroup<Content: View>(
    title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.title2.bold())
          .foregroundStyle(.white)
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.58))
      }
      .accessibilityElement(children: .combine)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 15) {
          content()
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 4)
      }
    }
  }

  private func warningBanner(_ message: String) -> some View {
    HStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(VelyraTheme.primary)
      VStack(alignment: .leading, spacing: 4) {
        Text("home.previewMode.title")
          .font(.headline)
        Text(message)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.66))
          .lineLimit(2)
      }
      Spacer()
      Button("action.retry") {
        Task {
          await viewModel.retry(
            traktSession: appState.traktSession,
            language: languageCode,
            region: regionCode
          )
        }
      }
      .buttonStyle(VelyraGlassButtonStyle())
    }
    .foregroundStyle(.white)
    .padding(22)
    .velyraGlass(cornerRadius: 22)
  }

  private var attributionFooter: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("home.data.attribution")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.48))
      Text("brand.madeInPortugal")
        .font(.caption.weight(.semibold))
        .foregroundStyle(VelyraTheme.primary.opacity(0.88))
    }
    .accessibilityElement(children: .combine)
  }
}
