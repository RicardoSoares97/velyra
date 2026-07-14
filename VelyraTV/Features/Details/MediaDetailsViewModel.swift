import Foundation

@MainActor
final class MediaDetailsViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var item: MediaItem
  @Published private(set) var originalLanguageCode: String?
  @Published private(set) var episodes: [AddonVideo] = []
  @Published var playbackRequest: PlaybackRequest?
  @Published private(set) var isPreparingPlayback = false
  @Published private(set) var playbackError: String?

  private let tmdb: TMDBAPIClient
  private let addonRepository: any AddonContentProviding
  private let playbackResolver: MediaPlaybackResolver

  init(
    item: MediaItem,
    tmdb: TMDBAPIClient = TMDBAPIClient(),
    addonRepository: any AddonContentProviding = AddonContentRepository(),
    playbackResolver: MediaPlaybackResolver = MediaPlaybackResolver()
  ) {
    self.item = item
    self.tmdb = tmdb
    self.addonRepository = addonRepository
    self.playbackResolver = playbackResolver
  }

  func load(language: String, addonManifestURLs: [String]) async {
    guard state == .idle else { return }
    state = .loading

    var enriched = item
    if let tmdbID = item.tmdbID,
      let details = try? await tmdb.details(id: tmdbID, kind: item.kind, language: language)
    {
      let external = try? await tmdb.externalIDs(id: tmdbID, kind: item.kind)
      enriched = details.mediaItem(kind: item.kind).merging(
        fallback: item,
        imdbID: external?.imdbID
      )
      originalLanguageCode = details.originalLanguage
    }

    let metadata = await addonRepository.metadata(
      type: enriched.kind.addonType,
      id: enriched.addonLookupID,
      urlStrings: addonManifestURLs
    )
    if let addon = metadata.first {
      enriched = enriched.merging(addon: addon)
      episodes = (addon.videos ?? []).sorted {
        ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0)
      }
    }

    item = enriched
    state = .loaded
  }

  func preparePlayback(addonManifestURLs: [String], episode: AddonVideo? = nil) async {
    isPreparingPlayback = true
    playbackError = nil
    defer { isPreparingPlayback = false }

    do {
      playbackRequest = try await playbackResolver.resolve(
        item: item,
        playbackID: episode?.id,
        originalLanguageCode: originalLanguageCode,
        addonManifestURLs: addonManifestURLs
      )
    } catch {
      playbackError = error.localizedDescription
    }
  }
}

extension MediaItem {
  func merging(fallback: MediaItem, imdbID: String?) -> MediaItem {
    MediaItem(
      id: id,
      tmdbID: tmdbID ?? fallback.tmdbID,
      imdbID: imdbID ?? self.imdbID ?? fallback.imdbID,
      kind: kind,
      title: title.isEmpty ? fallback.title : title,
      subtitle: subtitle ?? fallback.subtitle,
      overview: overview?.isEmpty == false ? overview : fallback.overview,
      posterURL: posterURL ?? fallback.posterURL,
      backdropURL: backdropURL ?? fallback.backdropURL,
      releaseYear: releaseYear ?? fallback.releaseYear,
      genreIDs: genreIDs.isEmpty ? fallback.genreIDs : genreIDs,
      rating: rating ?? fallback.rating,
      progress: fallback.progress,
      rank: fallback.rank,
      providerName: fallback.providerName
    )
  }

  func merging(addon: AddonMetaDetail) -> MediaItem {
    MediaItem(
      id: id,
      tmdbID: tmdbID,
      imdbID: imdbID,
      kind: kind,
      title: title.isEmpty ? addon.name : title,
      subtitle: subtitle ?? addon.releaseInfo,
      overview: overview?.isEmpty == false ? overview : addon.description,
      posterURL: posterURL ?? addon.poster,
      backdropURL: backdropURL ?? addon.background,
      releaseYear: releaseYear,
      genreIDs: genreIDs,
      rating: rating ?? addon.imdbRating.flatMap(Double.init),
      progress: progress,
      rank: rank,
      providerName: providerName
    )
  }
}
