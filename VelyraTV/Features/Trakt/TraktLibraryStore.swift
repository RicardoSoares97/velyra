import Foundation

struct TraktLibrarySnapshot: Codable, Equatable, Sendable {
  var profile: TraktUser?
  var playback: [TraktPlaybackItem]
  var watchlistMovies: [TraktWatchlistItem]
  var watchlistShows: [TraktWatchlistItem]
  var collectionMovies: [TraktCollectionItem]
  var collectionShows: [TraktCollectionItem]
  var history: [TraktHistoryItem]
  var watchedMovies: [TraktWatchedMovie]
  var watchedShows: [TraktWatchedShow]
  var ratingsMovies: [TraktRatingItem]
  var ratingsShows: [TraktRatingItem]
  var lists: [TraktPersonalList]
  var listItems: [String: [TraktListItem]]
  var lastActivities: TraktLastActivities?
  var syncedAt: Date?

  static let empty = TraktLibrarySnapshot(
    profile: nil,
    playback: [],
    watchlistMovies: [],
    watchlistShows: [],
    collectionMovies: [],
    collectionShows: [],
    history: [],
    watchedMovies: [],
    watchedShows: [],
    ratingsMovies: [],
    ratingsShows: [],
    lists: [],
    listItems: [:],
    lastActivities: nil,
    syncedAt: nil
  )

  var isEmpty: Bool {
    playback.isEmpty
      && watchlistMovies.isEmpty
      && watchlistShows.isEmpty
      && collectionMovies.isEmpty
      && collectionShows.isEmpty
      && history.isEmpty
      && lists.isEmpty
  }
}

actor TraktLibraryCache {
  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? Self.defaultFileURL(name: "trakt-library-v2.json")
    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  func load() -> TraktLibrarySnapshot {
    guard let data = try? Data(contentsOf: fileURL),
      let snapshot = try? decoder.decode(TraktLibrarySnapshot.self, from: data)
    else { return .empty }
    return snapshot
  }

  func save(_ snapshot: TraktLibrarySnapshot) throws {
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try encoder.encode(snapshot)
    try data.write(to: fileURL, options: .atomic)
  }

  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }

  private static func defaultFileURL(name: String) -> URL {
    let directory =
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return directory.appendingPathComponent("Velyra", isDirectory: true).appendingPathComponent(
      name)
  }
}

enum TraktMutationKind: String, Codable, Sendable {
  case addWatchlist
  case removeWatchlist
  case addCollection
  case removeCollection
  case addHistory
  case removeHistory
  case addRating
  case removeRating
  case removePlayback
  case scrobble
  case createList
  case updateList
  case deleteList
  case addListItems
  case removeListItems
}

struct TraktPendingMutation: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let kind: TraktMutationKind
  let request: TraktSyncRequest?
  let playbackID: Int?
  let scrobbleAction: TraktScrobbleAction?
  let scrobblePayload: TraktScrobblePayload?
  let listID: Int?
  let listRequest: TraktListRequest?
  let createdAt: Date
  var attemptCount: Int
  var lastAttemptAt: Date?
  var lastError: String?

  init(
    id: UUID = UUID(),
    kind: TraktMutationKind,
    request: TraktSyncRequest? = nil,
    playbackID: Int? = nil,
    scrobbleAction: TraktScrobbleAction? = nil,
    scrobblePayload: TraktScrobblePayload? = nil,
    listID: Int? = nil,
    listRequest: TraktListRequest? = nil,
    createdAt: Date = Date(),
    attemptCount: Int = 0,
    lastAttemptAt: Date? = nil,
    lastError: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.request = request
    self.playbackID = playbackID
    self.scrobbleAction = scrobbleAction
    self.scrobblePayload = scrobblePayload
    self.listID = listID
    self.listRequest = listRequest
    self.createdAt = createdAt
    self.attemptCount = attemptCount
    self.lastAttemptAt = lastAttemptAt
    self.lastError = lastError
  }
}

actor TraktMutationQueue {
  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var loaded = false
  private var mutations: [TraktPendingMutation] = []

  init(fileURL: URL? = nil) {
    self.fileURL = fileURL ?? Self.defaultFileURL(name: "trakt-mutations-v1.json")
    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  func all() -> [TraktPendingMutation] {
    loadIfNeeded()
    return mutations
  }

  func enqueue(_ mutation: TraktPendingMutation) {
    loadIfNeeded()
    if let key = mutation.coalescingKey {
      mutations.removeAll { $0.coalescingKey == key }
    } else {
      mutations.removeAll { existing in
        existing.kind == mutation.kind
          && existing.request == mutation.request
          && existing.playbackID == mutation.playbackID
          && existing.listID == mutation.listID
          && existing.listRequest == mutation.listRequest
      }
    }
    mutations.append(mutation)
    mutations.sort { $0.createdAt < $1.createdAt }
    persist()
  }

  func failed(maximumAttempts: Int = 8) -> [TraktPendingMutation] {
    loadIfNeeded()
    return mutations.filter { $0.attemptCount >= maximumAttempts }
  }

  func retryAll() {
    loadIfNeeded()
    mutations = mutations.map { value in
      var value = value
      value.attemptCount = 0
      value.lastAttemptAt = nil
      value.lastError = nil
      return value
    }
    persist()
  }

  func replace(_ mutation: TraktPendingMutation) {
    loadIfNeeded()
    if let index = mutations.firstIndex(where: { $0.id == mutation.id }) {
      mutations[index] = mutation
      persist()
    }
  }

  func remove(id: UUID) {
    loadIfNeeded()
    mutations.removeAll { $0.id == id }
    persist()
  }

  func clear() {
    loaded = true
    mutations = []
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func loadIfNeeded() {
    guard !loaded else { return }
    loaded = true
    guard let data = try? Data(contentsOf: fileURL),
      let decoded = try? decoder.decode([TraktPendingMutation].self, from: data)
    else { return }
    mutations = decoded
  }

  private func persist() {
    let directory = fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let data = try? encoder.encode(mutations) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }

  private static func defaultFileURL(name: String) -> URL {
    let directory =
      FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    return directory.appendingPathComponent("Velyra", isDirectory: true).appendingPathComponent(
      name)
  }
}
