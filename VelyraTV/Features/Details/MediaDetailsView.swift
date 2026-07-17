import SwiftUI
import UIKit

struct MediaDetailsView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @StateObject private var viewModel: MediaDetailsViewModel
  @State private var selectedEpisode: AddonVideo?
  @State private var selectedSeason: Int?
  @State private var selectedRelatedItem: MediaItem?
  @State private var showsFullCredits = false
  @State private var trailerOpenFailed = false

  init(item: MediaItem) {
    _viewModel = StateObject(wrappedValue: MediaDetailsViewModel(item: item))
  }

  private var languageCode: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  private var regionCode: String {
    appState.preferences.contentRegion ?? Locale.current.region?.identifier ?? "PT"
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      background
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 44) {
          heroContent
          if !viewModel.episodes.isEmpty { episodeRail }
          if !viewModel.streamingProviders.isEmpty { providersRail }
          if !viewModel.cast.isEmpty { castRail }
          if !viewModel.recommendations.isEmpty { recommendationsRail }
          if hasExtendedDetails { extendedDetails }
          attribution
          Spacer(minLength: 100)
        }
        .padding(.horizontal, 72)
        .padding(.top, 120)
      }
      closeButton
    }
    .background(Color.black.ignoresSafeArea())
    .task {
      await viewModel.load(
        language: languageCode,
        region: regionCode,
        addonManifestURLs: appState.preferences.activeAddonManifestURLs,
        traktRepository: appState.traktLibraryRepository
      )
      if selectedSeason == nil {
        selectedSeason = viewModel.availableSeasons.first
      }
    }
    .fullScreenCover(
      item: Binding(
        get: { viewModel.playbackRequest.map(PlaybackPresentation.init) },
        set: { if $0 == nil { viewModel.playbackRequest = nil } }
      )
    ) { presentation in
      VelyraPlayerView(request: presentation.request, preferences: appState.preferences)
    }
    .fullScreenCover(item: $selectedRelatedItem) { item in
      MediaDetailsView(item: item)
        .environmentObject(appState)
    }
    .fullScreenCover(isPresented: $showsFullCredits) {
      CreditsView(cast: viewModel.cast, crew: viewModel.crew)
    }
    .onChange(of: trailerOpenFailed) { _, failed in
      guard failed else { return }
      announceForAccessibility(String(localized: "details.trailer.providerUnavailable"))
    }
    .onChange(of: viewModel.libraryMessage) { _, message in
      guard let message else { return }
      announceForAccessibility(message)
    }
    .onChange(of: viewModel.playbackError) { _, error in
      guard let error else { return }
      announceForAccessibility(error, politely: false)
    }
    .onExitCommand { dismiss() }
  }

  @MainActor
  private func announceForAccessibility(_ message: String, politely: Bool = true) {
    let announcement = NSMutableAttributedString(string: message)
    if politely {
      announcement.addAttribute(
        .accessibilitySpeechQueueAnnouncement,
        value: true,
        range: NSRange(location: 0, length: announcement.length)
      )
    }
    UIAccessibility.post(notification: .announcement, argument: announcement)
  }

  private var background: some View {
    ZStack {
      CachedRemoteImage(
        url: viewModel.item.backdropURL,
        targetSize: CGSize(width: 1_920, height: 1_080)
      ) {
        LinearGradient(
          colors: [VelyraTheme.primary.opacity(0.42), .black],
          startPoint: .topTrailing,
          endPoint: .bottomLeading
        )
      }
      .ignoresSafeArea()
      .blur(radius: 2)

      LinearGradient(
        colors: [.black.opacity(0.18), .black.opacity(0.72), .black],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
      LinearGradient(
        colors: [.black.opacity(0.9), .black.opacity(0.25), .clear],
        startPoint: .leading,
        endPoint: .trailing
      )
      .ignoresSafeArea()
    }
    .accessibilityHidden(true)
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark").frame(width: 54, height: 54)
    }
    .buttonStyle(VelyraGlassButtonStyle())
    .padding(.leading, 56)
    .padding(.top, 40)
    .accessibilityLabel(Text("action.close"))
  }

  private var heroContent: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text(
        LocalizedStringKey(
          viewModel.item.kind == .movie ? "details.kind.movie" : "details.kind.series"
        )
      )
      .font(.headline.weight(.semibold))
      .foregroundStyle(VelyraTheme.primary)

      Text(viewModel.item.title)
        .font(.system(size: 72, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: 980, alignment: .leading)

      if let tagline = viewModel.tagline, !tagline.isEmpty {
        Text(tagline)
          .font(.title2.weight(.medium))
          .foregroundStyle(.white.opacity(0.76))
          .lineLimit(2)
      }

      metadataLine
      ratingsLine

      if let overview = viewModel.item.overview, !overview.isEmpty {
        Text(overview)
          .font(.title3)
          .foregroundStyle(.white.opacity(0.82))
          .lineLimit(6)
          .frame(maxWidth: 940, alignment: .leading)
      }

      actionRow

      if trailerOpenFailed {
        Text("details.trailer.providerUnavailable")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.78))
      }

      if let message = viewModel.libraryMessage {
        Text(message)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.78))
      }

      if let error = viewModel.playbackError {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.white)
          .padding(18)
          .velyraGlass(cornerRadius: 18)
      }
    }
  }

  private var metadataLine: some View {
    HStack(spacing: 16) {
      if let year = viewModel.item.releaseYear { Text(String(year)) }
      if let runtime = viewModel.runtimeMinutes {
        Text(Duration.seconds(runtime * 60).formatted(.units(allowed: [.hours, .minutes])))
      }
      if let certification = viewModel.certification, !certification.isEmpty {
        Text(certification)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .overlay {
            RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 1)
          }
      }
      if let provider = viewModel.item.providerName { Text(provider) }
    }
    .font(.headline)
    .foregroundStyle(.white.opacity(0.72))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var ratingsLine: some View {
    if !viewModel.ratings.isEmpty {
      HStack(spacing: 12) {
        ForEach(viewModel.ratings) { rating in
          RatingBadge(rating: rating)
        }
      }
      .accessibilityElement(children: .contain)
    }
  }

  private var actionRow: some View {
    HStack(spacing: 18) {
      Button {
        Task {
          await viewModel.preparePlayback(
            addonManifestURLs: appState.preferences.activeAddonManifestURLs,
            episode: selectedEpisode ?? viewModel.preferredEpisode ?? viewModel.episodes.first
          )
        }
      } label: {
        if viewModel.isPreparingPlayback {
          HStack {
            ProgressView()
            Text("details.preparing")
          }
        } else {
          Label("action.play", systemImage: "play.fill")
        }
      }
      .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      .disabled(viewModel.isPreparingPlayback)

      if appState.traktSession.isConnected {
        Button {
          Task { await viewModel.toggleWatchlist() }
        } label: {
          Label {
            Text(
              LocalizedStringKey(
                viewModel.isWatchlisted ? "details.watchlist.remove" : "details.watchlist.add"
              )
            )
          } icon: {
            Image(systemName: viewModel.isWatchlisted ? "checkmark" : "plus")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(viewModel.isUpdatingLibrary)

        Button {
          Task { await viewModel.toggleWatched() }
        } label: {
          Label {
            Text(
              LocalizedStringKey(
                viewModel.isWatched ? "details.markUnwatched" : "details.markWatched"
              )
            )
          } icon: {
            Image(systemName: viewModel.isWatched ? "checkmark.circle.fill" : "checkmark.circle")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(viewModel.isUpdatingLibrary)

        Menu {
          Button {
            Task { await viewModel.toggleCollection() }
          } label: {
            Label(
              LocalizedStringKey(
                viewModel.isCollected ? "details.collection.remove" : "details.collection.add"
              ),
              systemImage: viewModel.isCollected
                ? "rectangle.stack.badge.minus" : "rectangle.stack.badge.plus"
            )
          }
          Menu("details.rating") {
            ForEach(1...10, id: \.self) { value in
              Button {
                Task { await viewModel.setRating(value) }
              } label: {
                if viewModel.userRating == value {
                  Label("\(value)/10", systemImage: "checkmark")
                } else {
                  Text("\(value)/10")
                }
              }
            }
            if viewModel.userRating != nil {
              Button("details.rating.remove", role: .destructive) {
                Task { await viewModel.setRating(nil) }
              }
            }
          }
          if !viewModel.personalLists.isEmpty {
            Menu("library.addToList") {
              ForEach(viewModel.personalLists) { list in
                Button {
                  Task { await viewModel.toggleListMembership(listID: list.id) }
                } label: {
                  if viewModel.personalListMembershipIDs.contains(list.id) {
                    Label(list.name, systemImage: "checkmark")
                  } else {
                    Text(list.name)
                  }
                }
              }
            }
          }
          if viewModel.item.traktPlaybackID != nil {
            Button("library.removeProgress", role: .destructive) {
              Task { await viewModel.removePlaybackProgress() }
            }
          }
        } label: {
          Label("action.more", systemImage: "ellipsis.circle")
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(viewModel.isUpdatingLibrary)
      }

      if let trailerURL = viewModel.trailerURL {
        Button {
          trailerOpenFailed = false
          openURL(trailerURL) { accepted in
            trailerOpenFailed = !accepted
          }
        } label: {
          Label("details.trailer.youtube", systemImage: "play.rectangle.fill")
        }
        .buttonStyle(VelyraGlassButtonStyle())
      }

      if !appState.preferences.activeAddonManifestURLs.isEmpty {
        Label("details.automaticSource", systemImage: "sparkles")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.68))
      }
    }
  }

  private var episodeRail: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        sectionTitle("details.episodes")
        Spacer()
        if viewModel.availableSeasons.count > 1 {
          Picker(
            "details.season",
            selection: Binding(
              get: { selectedSeason ?? viewModel.availableSeasons.first },
              set: { selectedSeason = $0 }
            )
          ) {
            ForEach(viewModel.availableSeasons, id: \.self) { season in
              Text(String(format: String(localized: "details.season.number"), season)).tag(
                Optional(season))
            }
          }
          .frame(width: 300)
          .onChange(of: selectedSeason) { _, season in
            guard let season else { return }
            Task {
              await viewModel.loadSeason(
                season,
                language: appState.preferences.language.rawValue == "system"
                  ? Locale.current.identifier : appState.preferences.language.rawValue
              )
            }
          }
        }
      }

      if viewModel.loadingSeason == selectedSeason {
        ProgressView("details.season.loading")
          .tint(VelyraTheme.primary)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 18) {
          ForEach(viewModel.episodes(for: selectedSeason)) { episode in
            Button {
              selectedEpisode = episode
              Task {
                await viewModel.preparePlayback(
                  addonManifestURLs: appState.preferences.activeAddonManifestURLs,
                  episode: episode
                )
              }
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text(episode.title ?? String(localized: "details.episode.untitled"))
                  .font(.headline)
                  .lineLimit(2)
                Text(episodeLabel(episode))
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              .frame(width: 300, height: 110, alignment: .leading)
              .padding(20)
              .velyraGlass(cornerRadius: 22, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("details.episode.playHint")
          }
        }
        .padding(.vertical, 20)
      }
    }
  }

  private var providersRail: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionTitle("details.availableOn")
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 18) {
          ForEach(viewModel.streamingProviders) { provider in
            HStack(spacing: 14) {
              CachedRemoteImage(
                url: provider.logoURL,
                targetSize: CGSize(width: 108, height: 108),
                contentMode: .fit
              ) {
                Image(systemName: "play.tv")
              }
              .frame(width: 54, height: 54)
              .clipShape(RoundedRectangle(cornerRadius: 12))
              Text(provider.name).font(.headline)
            }
            .padding(.horizontal, 20)
            .frame(height: 82)
            .velyraGlass(cornerRadius: 20)
            .focusable()
            .accessibilityElement(children: .combine)
          }
        }
        .padding(.vertical, 14)
      }
    }
  }

  private var castRail: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        sectionTitle("details.cast")
        Spacer()
        if viewModel.cast.count > 12 || !viewModel.crew.isEmpty {
          Button("details.credits.all") { showsFullCredits = true }
            .buttonStyle(VelyraGlassButtonStyle())
        }
      }
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 22) {
          ForEach(viewModel.cast.prefix(12)) { credit in
            CastCreditCard(credit: credit)
          }
        }
        .padding(.vertical, 20)
      }
    }
  }

  private var recommendationsRail: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionTitle("details.recommendations")
      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: 24) {
          ForEach(viewModel.recommendations.prefix(20)) { item in
            HomeMediaCard(item: item, style: .poster) {
              selectedRelatedItem = item
            }
          }
        }
        .padding(.vertical, 20)
      }
    }
  }

  private var extendedDetails: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionTitle("details.moreInformation")
      VStack(alignment: .leading, spacing: 14) {
        if !viewModel.directorNames.isEmpty {
          detailRow(
            title: String(localized: "details.directedBy"),
            value: viewModel.directorNames.joined(separator: ", ")
          )
        }
      }
      .padding(24)
      .frame(maxWidth: 980, alignment: .leading)
      .velyraGlass(cornerRadius: 24)
    }
  }

  private var attribution: some View {
    Text("details.metadata.attribution.tmdb")
      .font(.caption)
      .foregroundStyle(.white.opacity(0.48))
      .accessibilityLabel(Text("details.metadata.attribution.tmdb"))
  }

  private var hasExtendedDetails: Bool {
    !viewModel.directorNames.isEmpty
  }

  private func sectionTitle(_ key: LocalizedStringKey) -> some View {
    Text(key)
      .font(.title2.bold())
      .foregroundStyle(.white)
  }

  private func detailRow(title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 18) {
      Text(title)
        .font(.headline)
        .foregroundStyle(.white.opacity(0.58))
        .frame(width: 210, alignment: .leading)
      Text(value)
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityElement(children: .combine)
  }

  private func episodeLabel(_ episode: AddonVideo) -> String {
    if let season = episode.season, let number = episode.episode {
      return String(format: String(localized: "details.episode.format"), season, number)
    }
    return String(localized: "details.episode")
  }
}

private struct RatingBadge: View {
  let rating: MediaRating

  var body: some View {
    HStack(spacing: 8) {
      Text(rating.source.rawValue.uppercased())
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.blue, in: RoundedRectangle(cornerRadius: 5))
      Text(String(format: "%.1f", rating.value))
        .font(.headline.monospacedDigit())
      if let votes = rating.voteCount {
        Text(votes.formatted(.number.notation(.compactName)))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.58))
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 12)
    .frame(height: 46)
    .velyraGlass(cornerRadius: 14)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    let source = rating.source.rawValue.uppercased()
    if let votes = rating.voteCount {
      return String(
        format: String(localized: "rating.accessibility.withVotes"),
        source,
        rating.value,
        rating.scale,
        votes
      )
    }
    return String(
      format: String(localized: "rating.accessibility"),
      source,
      rating.value,
      rating.scale
    )
  }
}

private struct CastCreditCard: View {
  let credit: MediaCredit

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      CachedRemoteImage(
        url: credit.profileURL,
        targetSize: CGSize(width: 380, height: 490)
      ) {
        ZStack {
          LinearGradient(
            colors: [VelyraTheme.primary.opacity(0.65), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          Image(systemName: "person.fill")
            .font(.system(size: 54))
            .foregroundStyle(.white.opacity(0.35))
        }
      }
      .frame(width: 190, height: 245)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

      Text(credit.name)
        .font(.headline)
        .foregroundStyle(.white)
        .lineLimit(1)
      if let role = credit.role, !role.isEmpty {
        Text(role)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(2)
      }
    }
    .frame(width: 190, alignment: .leading)
    .focusable()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(credit.name)
    .accessibilityValue(credit.role ?? String(localized: "details.castMember"))
  }
}

private struct CreditsView: View {
  @Environment(\.dismiss) private var dismiss
  let cast: [MediaCredit]
  let crew: [MediaCredit]

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.ignoresSafeArea()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 42) {
          creditsSection(title: "details.cast", values: cast)
          if !crew.isEmpty { creditsSection(title: "details.crew", values: crew) }
        }
        .padding(.horizontal, 72)
        .padding(.top, 130)
        .padding(.bottom, 100)
      }
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark").frame(width: 54, height: 54)
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .padding(.leading, 50)
      .padding(.top, 36)
      .accessibilityLabel("action.close")
    }
    .onExitCommand { dismiss() }
  }

  private func creditsSection(title: LocalizedStringKey, values: [MediaCredit]) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(title).font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(.white)
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 190, maximum: 220), spacing: 26)],
        alignment: .leading,
        spacing: 32
      ) {
        ForEach(values) { CastCreditCard(credit: $0) }
      }
    }
  }
}

private struct PlaybackPresentation: Identifiable {
  let request: PlaybackRequest
  var id: String { request.sources.first?.id ?? UUID().uuidString }
}
