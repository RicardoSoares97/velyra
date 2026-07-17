import Foundation

struct TopShelfSnapshot: Codable, Equatable, Sendable {
  struct Item: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let kind: String
    let tmdbID: Int?
    let traktID: Int?
    let traktPlaybackID: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let posterURL: URL?
    let backdropURL: URL?
    let progress: Double?

    var deepLinkURL: URL? {
      var components = URLComponents()
      components.scheme = "velyra"
      components.host = "details"
      components.queryItems = [
        URLQueryItem(name: "id", value: id),
        URLQueryItem(name: "title", value: title),
        URLQueryItem(name: "kind", value: kind),
        URLQueryItem(name: "tmdb", value: tmdbID.map(String.init)),
        URLQueryItem(name: "trakt", value: traktID.map(String.init)),
        URLQueryItem(name: "playback", value: traktPlaybackID.map(String.init)),
        URLQueryItem(name: "season", value: seasonNumber.map(String.init)),
        URLQueryItem(name: "episode", value: episodeNumber.map(String.init)),
      ].filter { $0.value != nil }
      return components.url
    }
  }

  let continueWatching: [Item]
  let recommendations: [Item]
  let updatedAt: Date

  static let empty = TopShelfSnapshot(
    continueWatching: [],
    recommendations: [],
    updatedAt: .distantPast
  )

  func hasSameContent(as other: TopShelfSnapshot) -> Bool {
    continueWatching == other.continueWatching
      && recommendations == other.recommendations
  }
}

actor TopShelfSnapshotStore {
  static let shared = TopShelfSnapshotStore()
  static let appGroupIdentifier = "group.pt.ricardosoares.velyra"

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()
  private let fileURL: URL?

  init(fileURL: URL? = TopShelfSnapshotStore.defaultFileURL) {
    self.fileURL = fileURL
  }

  func save(_ snapshot: TopShelfSnapshot) throws {
    guard let fileURL else { return }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
  }

  @discardableResult
  func saveIfChanged(_ snapshot: TopShelfSnapshot) throws -> Bool {
    guard !load().hasSameContent(as: snapshot) else { return false }
    try save(snapshot)
    return true
  }

  func load() -> TopShelfSnapshot {
    guard let fileURL,
      let data = try? Data(contentsOf: fileURL),
      let snapshot = try? decoder.decode(TopShelfSnapshot.self, from: data)
    else { return .empty }
    return snapshot
  }

  func clear() {
    guard let fileURL else { return }
    try? FileManager.default.removeItem(at: fileURL)
  }

  private static var defaultFileURL: URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )?.appendingPathComponent("TopShelf", isDirectory: true)
      .appendingPathComponent("snapshot.json")
  }
}
