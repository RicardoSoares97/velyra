import Foundation

enum AppDeepLinkParser {
  static func mediaItem(from url: URL) -> MediaItem? {
    guard url.scheme == "velyra", url.host == "details",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }

    let values = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
        item in item.value.map { (item.name, $0) }
      })
    guard let id = values["id"], let title = values["title"] else { return nil }
    let kind = values["kind"].flatMap(MediaKind.init(rawValue:)) ?? .movie
    return MediaItem(
      id: id,
      tmdbID: values["tmdb"].flatMap(Int.init),
      imdbID: nil,
      traktID: values["trakt"].flatMap(Int.init),
      traktPlaybackID: values["playback"].flatMap(Int.init),
      kind: kind,
      title: title,
      subtitle: nil,
      overview: nil,
      posterURL: nil,
      backdropURL: nil,
      releaseYear: nil,
      genreIDs: [],
      rating: nil,
      progress: nil,
      rank: nil,
      providerName: nil,
      seasonNumber: values["season"].flatMap(Int.init),
      episodeNumber: values["episode"].flatMap(Int.init)
    )
  }
}
