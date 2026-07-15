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
  @Published private(set) var declaredSeasonCount = 0
  @Published private(set) var loadingSeason: Int?
  @Published private(set) var preferredEpisode: AddonVideo?
  @Published private(set) var ratings: [MediaRating] = []
  @Published private(set) var cast: [MediaCredit] = []
  @Published private(set) var crew: [MediaCredit] = []
  @Published private(set) var recommendations: [MediaItem] = []
  @Published private(set) var streamingProviders: [StreamingProvider] = []
  @Published private(set) var trailerURL: URL?
  @Published private(set) var tagline: String?
  @Published private(set) var runtimeMinutes: Int?
  @Published private(set) var certification: String?
  @Published private(set) var directorNames: [String] = []
  @Published private(set) var isWatchlisted = false
  @Published private(set) var isCollected = false
  @Published private(set) var isWatched = false
  @Published private(set) var userRating: Int?
  @Published private(set) var personalLists: [TraktPersonalList] = []
  @Published private(set) var personalListMembershipIDs: Set<Int> = []
  @Published private(set) var isUpdatingLibrary = false
  @Published var playbackRequest: PlaybackRequest?
  @Published private(set) var isPreparingPlayback = false
  @Published private(set) var playbackError: String?
  @Published private(set) var libraryMessage: String?

  private let tmdb: TMDBAPIClient
  private let addonRepository: any AddonContentProviding
  private let playbackResolver: MediaPlaybackResolver
  private var traktRepository: TraktLibraryRepository?

  init(
    item: MediaItem,
    tmdb: TMDBAPIClient = .shared,
    addonRepository: any AddonContentProviding = AddonContentRepository.shared,
    playbackResolver: MediaPlaybackResolver = MediaPlaybackResolver()
  ) {
    self.item = item
    self.tmdb = tmdb
    self.addonRepository = addonRepository
    self.playbackResolver = playbackResolver
  }

  var availableSeasons: [Int] {
    let loaded = Set(episodes.compactMap(\.season))
    let declared: Set<Int> = declaredSeasonCount > 0 ? Set(1...declaredSeasonCount) : []
    return Array(loaded.union(declared)).sorted()
  }

  func episodes(for season: Int?) -> [AddonVideo] {
    let selected = season ?? availableSeasons.first
    return episodes.filter { selected == nil || $0.season == selected }
      .sorted {
        let lhsSeason = $0.season ?? 0
        let rhsSeason = $1.season ?? 0
        if lhsSeason != rhsSeason { return lhsSeason < rhsSeason }
        return ($0.episode ?? 0) < ($1.episode ?? 0)
      }
  }

  func load(
    language: String,
    region: String,
    addonManifestURLs: [String],
    traktRepository: TraktLibraryRepository
  ) async {
    guard state == .idle else { return }
    state = .loading
    self.traktRepository = traktRepository

    var enriched = item
    var tmdbCast: [TMDBCastMember] = []
    var tmdbCrew: [TMDBCrewMember] = []
    var tmdbVoteCount: Int?
    async let addonMetadata = addonRepository.metadata(
      type: item.kind.addonType,
      id: item.addonLookupID,
      urlStrings: addonManifestURLs
    )

    if let tmdbID = item.tmdbID {
      let bundle = await tmdb.detailsBundle(
        id: tmdbID,
        kind: item.kind,
        language: language,
        region: region
      )
      if let details = bundle.details {
        enriched = details.mediaItem(kind: item.kind).merging(
          fallback: item,
          imdbID: bundle.externalIDs?.imdbID
        )
        originalLanguageCode = details.originalLanguage
        tagline = details.tagline
        runtimeMinutes = details.runtime ?? details.episodeRunTime?.first
        declaredSeasonCount = details.numberOfSeasons ?? 0
        tmdbVoteCount = details.voteCount
      }
      tmdbCast = bundle.credits?.cast ?? []
      tmdbCrew = bundle.credits?.crew ?? []
      trailerURL =
        bundle.videos.first(where: { $0.type == "Trailer" })?.externalURL
        ?? bundle.videos.first?.externalURL
      certification = bundle.certification
      streamingProviders = bundle.providers?.streaming.map(\.streamingProvider) ?? []
      recommendations = deduplicate(
        (bundle.recommendations + bundle.similar).map {
          $0.mediaItem(kind: item.kind)
        }
      )
    }

    let metadata = await addonMetadata
    if let addon = metadata.first {
      enriched = enriched.merging(addon: addon)
      episodes = (addon.videos ?? []).sorted {
        ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0)
      }
    }

    ratings = TMDBMetadataPolicy.ratings(value: enriched.rating, voteCount: tmdbVoteCount)
    cast = TMDBMetadataPolicy.cast(tmdbCast)
    crew = TMDBMetadataPolicy.crew(tmdbCrew)
    directorNames = Array(
      crew.filter { ($0.role ?? "").localizedCaseInsensitiveContains("director") }
        .map(\.name)
        .uniqued()
        .prefix(4)
    )

    if episodes.isEmpty, item.kind == .series {
      await loadSeason(
        enriched.seasonNumber ?? 1,
        language: language,
        item: enriched
      )
    }

    preferredEpisode = episodes.first {
      $0.season == enriched.seasonNumber && $0.episode == enriched.episodeNumber
    }
    item = enriched
    await reloadLibraryState()
    state = .loaded
  }

  func loadSeason(_ season: Int, language: String) async {
    await loadSeason(season, language: language, item: item)
  }

  private func loadSeason(_ season: Int, language: String, item: MediaItem) async {
    guard item.kind == .series,
      let tmdbID = item.tmdbID,
      !episodes.contains(where: { $0.season == season }),
      loadingSeason != season
    else { return }

    loadingSeason = season
    defer { loadingSeason = nil }
    guard
      let tmdbSeason = try? await tmdb.seasonDetails(
        showID: tmdbID,
        season: season,
        language: language
      )
    else { return }

    let values = tmdbSeason.episodes.map { episode in
      AddonVideo(
        id: episodePlaybackID(
          imdbID: item.imdbID,
          tmdbID: tmdbID,
          season: episode.seasonNumber,
          episode: episode.episodeNumber
        ),
        title: episode.name,
        season: episode.seasonNumber,
        episode: episode.episodeNumber,
        released: Self.date(from: episode.airDate)
      )
    }
    var seen = Set(episodes.map(\.id))
    episodes.append(contentsOf: values.filter { seen.insert($0.id).inserted })
    episodes.sort {
      ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0)
    }
  }

  func preparePlayback(addonManifestURLs: [String], episode: AddonVideo? = nil) async {
    isPreparingPlayback = true
    playbackError = nil
    defer { isPreparingPlayback = false }

    do {
      playbackRequest = try await playbackResolver.resolve(
        item: item,
        addonPlaybackID: episode?.id,
        originalLanguageCode: originalLanguageCode,
        addonManifestURLs: addonManifestURLs,
        episode: episode,
        initialProgress: item.progress.map { $0 * 100 },
        traktPlaybackID: item.traktPlaybackID
      )
    } catch {
      playbackError = error.localizedDescription
    }
  }

  func toggleWatchlist() async {
    guard let traktRepository else { return }
    await updateLibrary {
      try await traktRepository.setWatchlist(item.traktReference, isListed: !isWatchlisted)
    }
  }

  func toggleCollection() async {
    guard let traktRepository else { return }
    await updateLibrary {
      try await traktRepository.setCollection(item.traktReference, isCollected: !isCollected)
    }
  }

  func toggleWatched() async {
    guard let traktRepository else { return }
    if isWatched {
      let snapshot = await traktRepository.cachedSnapshot()
      let stableID = item.traktReference.stableID
      let historyIDs = snapshot.history.compactMap { entry in
        entry.mediaReference?.stableID == stableID ? entry.id : nil
      }
      guard !historyIDs.isEmpty else { return }
      await updateLibrary { try await traktRepository.removeHistory(ids: historyIDs) }
    } else {
      await updateLibrary { try await traktRepository.markWatched(item.traktReference) }
    }
  }

  func removePlaybackProgress() async {
    guard let traktRepository, let playbackID = item.traktPlaybackID else { return }
    await updateLibrary { try await traktRepository.removePlayback(id: playbackID) }
  }

  func toggleListMembership(listID: Int) async {
    guard let traktRepository else { return }
    let isListed = personalListMembershipIDs.contains(listID)
    await updateLibrary {
      try await traktRepository.setListMembership(
        listID: listID,
        reference: item.traktReference,
        isListed: !isListed
      )
    }
  }

  func setRating(_ rating: Int?) async {
    guard let traktRepository else { return }
    await updateLibrary { try await traktRepository.setRating(item.traktReference, rating: rating) }
  }

  private func updateLibrary(
    _ action: @escaping @MainActor () async throws -> TraktMutationOutcome
  ) async {
    isUpdatingLibrary = true
    libraryMessage = nil
    defer { isUpdatingLibrary = false }
    do {
      let outcome = try await action()
      libraryMessage =
        outcome == .queued
        ? String(localized: "library.changeQueued")
        : String(localized: "library.changeSaved")
      await reloadLibraryState()
    } catch {
      libraryMessage = error.localizedDescription
    }
  }

  private func reloadLibraryState() async {
    guard let traktRepository else { return }
    let snapshot = await traktRepository.cachedSnapshot()
    let stableID = item.traktReference.stableID
    isWatchlisted = (snapshot.watchlistMovies + snapshot.watchlistShows).contains {
      $0.mediaReference?.stableID == stableID
    }
    isCollected = (snapshot.collectionMovies + snapshot.collectionShows).contains {
      $0.mediaReference?.stableID == stableID
    }
    userRating =
      (snapshot.ratingsMovies + snapshot.ratingsShows)
      .first { $0.mediaReference?.stableID == stableID }?.rating
    isWatched = snapshot.history.contains { $0.mediaReference?.stableID == stableID }
    personalLists = snapshot.lists.filter { $0.id > 0 }
    personalListMembershipIDs = Set(
      personalLists.compactMap { list in
        let contains =
          snapshot.listItems[String(list.id)]?.contains {
            $0.mediaReference?.stableID == stableID
          } == true
        return contains ? list.id : nil
      }
    )
  }

  private func deduplicate(_ values: [MediaItem]) -> [MediaItem] {
    var seen: Set<String> = [item.id]
    return values.filter { media in
      let key = media.tmdbID.map { "tmdb:\($0)" } ?? media.id
      return seen.insert(key).inserted
    }
  }

  private func episodePlaybackID(
    imdbID: String?,
    tmdbID: Int,
    season: Int,
    episode: Int
  ) -> String {
    if let imdbID { return "\(imdbID):\(season):\(episode)" }
    return "tmdb:\(tmdbID):\(season):\(episode)"
  }

  private static func date(from value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }
}

extension MediaItem {
  func merging(fallback: MediaItem, imdbID: String?) -> MediaItem {
    MediaItem(
      id: id,
      tmdbID: tmdbID ?? fallback.tmdbID,
      imdbID: imdbID ?? self.imdbID ?? fallback.imdbID,
      traktID: traktID ?? fallback.traktID,
      traktPlaybackID: traktPlaybackID ?? fallback.traktPlaybackID,
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
      providerName: fallback.providerName,
      seasonNumber: seasonNumber ?? fallback.seasonNumber,
      episodeNumber: episodeNumber ?? fallback.episodeNumber
    )
  }

  func merging(addon: AddonMetaDetail) -> MediaItem {
    MediaItem(
      id: id,
      tmdbID: tmdbID,
      imdbID: imdbID,
      traktID: traktID,
      traktPlaybackID: traktPlaybackID,
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
      providerName: providerName,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber
    )
  }
}

extension Sequence where Element: Hashable {
  fileprivate func uniqued() -> [Element] {
    var seen: Set<Element> = []
    return filter { seen.insert($0).inserted }
  }
}
