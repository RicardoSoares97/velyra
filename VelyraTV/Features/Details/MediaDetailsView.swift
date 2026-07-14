import SwiftUI

struct MediaDetailsView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.dismiss) private var dismiss
  @StateObject private var viewModel: MediaDetailsViewModel
  @State private var selectedEpisode: AddonVideo?

  init(item: MediaItem) {
    _viewModel = StateObject(wrappedValue: MediaDetailsViewModel(item: item))
  }

  private var languageCode: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      background
      ScrollView {
        VStack(alignment: .leading, spacing: 40) {
          heroContent
          if !viewModel.episodes.isEmpty { episodeRail }
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
        addonManifestURLs: appState.preferences.addonManifestURLs
      )
    }
    .fullScreenCover(item: Binding(
      get: { viewModel.playbackRequest.map(PlaybackPresentation.init) },
      set: { if $0 == nil { viewModel.playbackRequest = nil } }
    )) { presentation in
      VelyraPlayerView(request: presentation.request, preferences: appState.preferences)
    }
    .onExitCommand { dismiss() }
  }

  private var background: some View {
    ZStack {
      AsyncImage(url: viewModel.item.backdropURL) { phase in
        if case .success(let image) = phase {
          image.resizable().scaledToFill()
        } else {
          LinearGradient(
            colors: [VelyraTheme.primary.opacity(0.42), .black],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
          )
        }
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
        colors: [.black.opacity(0.88), .black.opacity(0.22), .clear],
        startPoint: .leading,
        endPoint: .trailing
      )
      .ignoresSafeArea()
    }
    .accessibilityHidden(true)
  }

  private var closeButton: some View {
    Button { dismiss() } label: {
      Image(systemName: "xmark").frame(width: 54, height: 54)
    }
    .buttonStyle(VelyraGlassButtonStyle())
    .padding(.leading, 56)
    .padding(.top, 40)
    .accessibilityLabel(Text("action.close"))
  }

  private var heroContent: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text(LocalizedStringKey(
        viewModel.item.kind == .movie ? "details.kind.movie" : "details.kind.series"
      ))
        .font(.headline.weight(.semibold))
        .foregroundStyle(VelyraTheme.primary)

      Text(viewModel.item.title)
        .font(.system(size: 72, weight: .black, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: 980, alignment: .leading)

      metadataLine

      if let overview = viewModel.item.overview, !overview.isEmpty {
        Text(overview)
          .font(.title3)
          .foregroundStyle(.white.opacity(0.8))
          .lineLimit(5)
          .frame(maxWidth: 900, alignment: .leading)
      }

      HStack(spacing: 18) {
        Button {
          Task {
            await viewModel.preparePlayback(
              addonManifestURLs: appState.preferences.addonManifestURLs,
              episode: selectedEpisode ?? viewModel.episodes.first
            )
          }
        } label: {
          if viewModel.isPreparingPlayback {
            HStack { ProgressView(); Text("details.preparing") }
          } else {
            Label("action.play", systemImage: "play.fill")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        .disabled(viewModel.isPreparingPlayback)

        if !appState.preferences.addonManifestURLs.isEmpty {
          Label("details.automaticSource", systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
        }
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
      if let rating = viewModel.item.rating {
        Label(String(format: "%.1f", rating), systemImage: "star.fill")
      }
      if let provider = viewModel.item.providerName { Text(provider) }
    }
    .font(.headline)
    .foregroundStyle(.white.opacity(0.72))
    .accessibilityElement(children: .combine)
  }

  private var episodeRail: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("details.episodes")
        .font(.title2.bold())
        .foregroundStyle(.white)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 18) {
          ForEach(viewModel.episodes) { episode in
            Button {
              selectedEpisode = episode
              Task {
                await viewModel.preparePlayback(
                  addonManifestURLs: appState.preferences.addonManifestURLs,
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
          }
        }
        .padding(.vertical, 20)
      }
    }
  }

  private func episodeLabel(_ episode: AddonVideo) -> String {
    if let season = episode.season, let number = episode.episode {
      return String(format: String(localized: "details.episode.format"), season, number)
    }
    return String(localized: "details.episode")
  }
}

private struct PlaybackPresentation: Identifiable {
  let request: PlaybackRequest
  var id: String { request.sources.first?.id ?? UUID().uuidString }
}
