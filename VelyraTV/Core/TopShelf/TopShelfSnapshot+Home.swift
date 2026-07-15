import Foundation

extension TopShelfSnapshot {
  static func make(feed: HomeFeed) -> TopShelfSnapshot {
    let continueWatching = feed.continueWatching.prefix(12).map(Item.init(media:))
    let continueWatchingIDs = Set(continueWatching.map(\.id))
    let recommendations = ([feed.hero] + feed.sections.flatMap(\.items))
      .uniqued(by: \.id)
      .filter { !continueWatchingIDs.contains($0.id) }
      .prefix(20)
      .map(Item.init(media:))
    return TopShelfSnapshot(
      continueWatching: Array(continueWatching),
      recommendations: Array(recommendations),
      updatedAt: Date()
    )
  }
}

extension TopShelfSnapshot.Item {
  fileprivate init(media: MediaItem) {
    self.init(
      id: media.id,
      title: media.title,
      subtitle: media.subtitle,
      kind: media.kind.rawValue,
      tmdbID: media.tmdbID,
      traktID: media.traktID,
      traktPlaybackID: media.traktPlaybackID,
      seasonNumber: media.seasonNumber,
      episodeNumber: media.episodeNumber,
      posterURL: media.posterURL,
      backdropURL: media.backdropURL,
      progress: media.progress
    )
  }
}

extension Sequence {
  fileprivate func uniqued<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
    var seen = Set<Key>()
    return filter { seen.insert($0[keyPath: keyPath]).inserted }
  }
}
