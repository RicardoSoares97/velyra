import Foundation

enum TraktMutationFamily: String, Sendable {
  case watchlist
  case collection
  case history
  case rating
  case playback
  case scrobble
  case list
  case listMembership
}

extension TraktPendingMutation {
  var family: TraktMutationFamily {
    switch kind {
    case .addWatchlist, .removeWatchlist: .watchlist
    case .addCollection, .removeCollection: .collection
    case .addHistory, .removeHistory: .history
    case .addRating, .removeRating: .rating
    case .removePlayback: .playback
    case .scrobble: .scrobble
    case .createList, .updateList, .deleteList: .list
    case .addListItems, .removeListItems: .listMembership
    }
  }

  var coalescingKey: String? {
    switch family {
    case .watchlist, .collection, .rating:
      return request?.singleMediaStableID.map { "\(family.rawValue):\($0)" }
    case .history:
      if kind == .addHistory {
        return request?.singleMediaStableID.map { "history:add:\($0)" }
      }
      return request?.ids.map { "history:remove:\($0.sorted().map(String.init).joined(separator: ","))" }
    case .playback:
      return playbackID.map { "playback:\($0)" }
    case .scrobble:
      return scrobblePayload?.stableMediaID.map { "scrobble:\($0)" }
    case .list:
      if kind == .createList { return nil }
      return listID.map { "list:\($0)" }
    case .listMembership:
      guard let listID, let mediaID = request?.singleMediaStableID else { return nil }
      return "list-membership:\(listID):\(mediaID)"
    }
  }
}

extension TraktSyncRequest {
  var singleMediaStableID: String? {
    if let movie = movies?.first {
      return movie.ids.stableID(prefix: "movie")
    }
    if let show = shows?.first {
      return show.ids.stableID(prefix: "show")
    }
    if let episode = episodes?.first {
      return episode.ids.stableID(prefix: "episode")
        ?? "episode:\(episode.season ?? 0):\(episode.number ?? 0)"
    }
    return nil
  }
}

extension TraktIDs {
  fileprivate func stableID(prefix: String) -> String? {
    if let trakt { return "\(prefix):trakt:\(trakt)" }
    if let tmdb { return "\(prefix):tmdb:\(tmdb)" }
    if let imdb { return "\(prefix):imdb:\(imdb)" }
    if let slug { return "\(prefix):slug:\(slug)" }
    return nil
  }
}

extension TraktScrobblePayload {
  fileprivate var stableMediaID: String? {
    if let episode {
      return episode.ids.stableID(prefix: "episode")
        ?? "episode:\(episode.season):\(episode.number)"
    }
    if let movie { return movie.ids.stableID(prefix: "movie") }
    if let show { return show.ids.stableID(prefix: "show") }
    return nil
  }
}
