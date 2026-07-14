import Foundation

actor HomeFeedCache {
  private struct Envelope: Codable, Sendable {
    let savedAt: Date
    let feed: HomeFeed
  }

  private let fileManager: FileManager
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let maximumAge: TimeInterval

  init(
    fileManager: FileManager = .default,
    maximumAge: TimeInterval = 60 * 60 * 24
  ) {
    self.fileManager = fileManager
    self.maximumAge = maximumAge
    encoder = JSONEncoder()
    decoder = JSONDecoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  func save(_ feed: HomeFeed, language: String, region: String) {
    do {
      let envelope = Envelope(savedAt: Date(), feed: feed)
      let data = try encoder.encode(envelope)
      let url = try cacheURL(language: language, region: region)
      try data.write(to: url, options: .atomic)
    } catch {
      return
    }
  }

  func load(language: String, region: String, allowExpired: Bool = true) -> HomeFeed? {
    do {
      let url = try cacheURL(language: language, region: region)
      let data = try Data(contentsOf: url)
      let envelope = try decoder.decode(Envelope.self, from: data)
      if !allowExpired, Date().timeIntervalSince(envelope.savedAt) > maximumAge {
        return nil
      }
      return envelope.feed
    } catch {
      return nil
    }
  }

  private func cacheURL(language: String, region: String) throws -> URL {
    let root = try fileManager.url(
      for: .cachesDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = root.appendingPathComponent("Velyra/Home", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    let safeLanguage = language.replacingOccurrences(of: "/", with: "-")
    let safeRegion = region.replacingOccurrences(of: "/", with: "-")
    return directory.appendingPathComponent("home-\(safeLanguage)-\(safeRegion).json")
  }
}
