import Foundation

actor MediaPlaybackResolver {
  enum ResolutionError: LocalizedError {
    case noAddons
    case noStreams

    var errorDescription: String? {
      switch self {
      case .noAddons: String(localized: "details.error.noAddons")
      case .noStreams: String(localized: "details.error.noStreams")
      }
    }
  }

  private let repository: any AddonContentProviding
  private let mapper = AddonStreamPlaybackMapper()

  init(repository: any AddonContentProviding = AddonContentRepository.shared) {
    self.repository = repository
  }

  func resolve(
    item: MediaItem,
    addonPlaybackID: String? = nil,
    originalLanguageCode: String?,
    addonManifestURLs: [String],
    episode: AddonVideo? = nil,
    initialProgress: Double? = nil,
    traktPlaybackID: Int? = nil
  ) async throws -> PlaybackRequest {
    guard !addonManifestURLs.isEmpty else { throw ResolutionError.noAddons }
    let id = addonPlaybackID ?? item.addonLookupID
    let type = item.kind.addonType

    async let streamTask = repository.streams(type: type, id: id, urlStrings: addonManifestURLs)
    async let subtitleTask = repository.subtitles(type: type, id: id, urlStrings: addonManifestURLs)
    let resolvedStreams = await streamTask
    let resolvedSubtitles = await subtitleTask

    let sources = resolvedStreams.flatMap { resolved in
      mapper.playbackSources(from: [resolved.stream], addonName: resolved.addonName)
    }
    guard !sources.isEmpty else { throw ResolutionError.noStreams }

    let externalTracks = resolvedSubtitles.map { resolved in
      let language = resolved.subtitle.lang
      let locale = Locale(identifier: language)
      let displayName =
        locale.localizedString(forIdentifier: language)
        ?? locale.localizedString(forLanguageCode: language)
        ?? language.uppercased()
      return ExternalSubtitleTrack(
        id: resolved.id,
        url: resolved.subtitle.url,
        languageCode: language,
        displayName: displayName,
        addonName: resolved.addonName
      )
    }

    return PlaybackRequest(
      contentKey: episode.map { "\(item.id):s\($0.season ?? 0)e\($0.episode ?? 0)" } ?? item.id,
      title: item.title,
      originalLanguageCode: originalLanguageCode,
      sources: sources,
      externalSubtitles: externalTracks,
      initialPosition: 0,
      initialProgress: initialProgress,
      traktContext: traktContext(for: item, episode: episode, playbackID: traktPlaybackID)
    )
  }
  private func traktContext(
    for item: MediaItem,
    episode: AddonVideo?,
    playbackID: Int?
  ) -> TraktPlaybackContext {
    let ids = TraktIDs(
      trakt: item.traktID,
      slug: nil,
      imdb: item.imdbID,
      tmdb: item.tmdbID
    )
    if item.kind == .movie {
      return TraktPlaybackContext(
        reference: TraktMediaReference(
          movie: TraktMovie(title: item.title, year: item.releaseYear, ids: ids)
        ),
        playbackID: playbackID
      )
    }

    let show = TraktShow(title: item.title, year: item.releaseYear, ids: ids)
    let resolvedSeason = episode?.season ?? item.seasonNumber
    let resolvedNumber = episode?.episode ?? item.episodeNumber
    if let season = resolvedSeason, let number = resolvedNumber {
      return TraktPlaybackContext(
        reference: TraktMediaReference(
          show: show,
          episode: TraktEpisode(
            season: season,
            number: number,
            title: episode?.title
          )
        ),
        playbackID: playbackID
      )
    }
    return TraktPlaybackContext(reference: TraktMediaReference(show: show), playbackID: playbackID)
  }

}

extension MediaItem {
  var addonLookupID: String {
    if let imdbID, !imdbID.isEmpty { return imdbID }
    if let tmdbID { return "tmdb:\(tmdbID)" }
    return id
  }
}
