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

  init(repository: any AddonContentProviding = AddonContentRepository()) {
    self.repository = repository
  }

  func resolve(
    item: MediaItem,
    playbackID: String? = nil,
    originalLanguageCode: String?,
    addonManifestURLs: [String]
  ) async throws -> PlaybackRequest {
    guard !addonManifestURLs.isEmpty else { throw ResolutionError.noAddons }
    let id = playbackID ?? item.addonLookupID
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
      let displayName = locale.localizedString(forIdentifier: language)
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
      title: item.title,
      originalLanguageCode: originalLanguageCode,
      sources: sources,
      externalSubtitles: externalTracks,
      initialPosition: 0
    )
  }
}

extension MediaItem {
  var addonLookupID: String {
    if let imdbID, !imdbID.isEmpty { return imdbID }
    if let tmdbID { return "tmdb:\(tmdbID)" }
    return id
  }
}
