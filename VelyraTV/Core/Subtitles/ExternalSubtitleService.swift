import Foundation

struct ExternalSubtitleTrack: Identifiable, Equatable, Hashable, Sendable {
  let id: String
  let url: URL
  let languageCode: String
  let displayName: String
  let addonName: String?

  init(
    id: String = UUID().uuidString,
    url: URL,
    languageCode: String,
    displayName: String,
    addonName: String? = nil
  ) {
    self.id = id
    self.url = url
    self.languageCode = languageCode
    self.displayName = displayName
    self.addonName = addonName
  }
}

struct ExternalSubtitleCue: Equatable, Sendable {
  let start: TimeInterval
  let end: TimeInterval
  let text: String

  func contains(_ time: TimeInterval) -> Bool {
    time >= start && time < end
  }
}

actor ExternalSubtitleService {
  static let shared = ExternalSubtitleService()

  enum SubtitleError: LocalizedError {
    case insecureURL
    case invalidResponse
    case responseTooLarge
    case unsupportedFormat
    case invalidEncoding

    var errorDescription: String? {
      switch self {
      case .insecureURL: String(localized: "subtitles.error.secureConnection")
      case .invalidResponse: String(localized: "subtitles.error.invalidResponse")
      case .responseTooLarge: String(localized: "subtitles.error.tooLarge")
      case .unsupportedFormat: String(localized: "subtitles.error.unsupported")
      case .invalidEncoding: String(localized: "subtitles.error.encoding")
      }
    }
  }

  private struct CacheEntry: Sendable {
    let cues: [ExternalSubtitleCue]
    let loadedAt: Date
  }

  private let session: URLSession
  private let maximumBytes = 5_000_000
  private let cacheLifetime: TimeInterval = 6 * 60 * 60
  private var cache: [URL: CacheEntry] = [:]
  private var inFlight: [URL: Task<[ExternalSubtitleCue], Error>] = [:]

  init(session: URLSession = .shared) {
    self.session = session
  }

  func cues(for track: ExternalSubtitleTrack) async throws -> [ExternalSubtitleCue] {
    purgeExpiredCache()
    if let entry = cache[track.url] {
      return entry.cues
    }
    if let task = inFlight[track.url] { return try await task.value }

    let task = Task { [session, maximumBytes] in
      guard track.url.scheme?.lowercased() == "https" || Self.isLocalhost(track.url) else {
        throw SubtitleError.insecureURL
      }

      var request = URLRequest(url: track.url)
      request.timeoutInterval = 20
      request.cachePolicy = .returnCacheDataElseLoad
      request.setValue(
        "text/vtt, application/x-subrip, text/x-ssa, text/x-ass, text/plain",
        forHTTPHeaderField: "Accept"
      )
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
        (200..<300).contains(httpResponse.statusCode)
      else { throw SubtitleError.invalidResponse }
      let expected = response.expectedContentLength
      if expected > Int64(maximumBytes) {
        throw SubtitleError.responseTooLarge
      }
      guard data.count <= maximumBytes else { throw SubtitleError.responseTooLarge }
      guard
        let text = String(data: data, encoding: .utf8)
          ?? String(data: data, encoding: .utf16)
          ?? String(data: data, encoding: .isoLatin1)
      else { throw SubtitleError.invalidEncoding }

      let extensionName = track.url.pathExtension.lowercased()
      if extensionName == "vtt"
        || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT")
      {
        return ExternalSubtitleParser.parseWebVTT(text)
      }
      if extensionName == "ass" || extensionName == "ssa" || text.contains("[Events]") {
        return ExternalSubtitleParser.parseASS(text)
      }
      if extensionName == "srt" || text.contains("-->") {
        return ExternalSubtitleParser.parseSRT(text)
      }
      throw SubtitleError.unsupportedFormat
    }
    inFlight[track.url] = task
    defer { inFlight[track.url] = nil }
    let loaded = try await task.value
    cache[track.url] = CacheEntry(cues: loaded, loadedAt: Date())
    return loaded
  }

  func clearCache() {
    cache.removeAll()
    inFlight.values.forEach { $0.cancel() }
    inFlight.removeAll()
  }

  private func purgeExpiredCache(now: Date = Date()) {
    cache = cache.filter { now.timeIntervalSince($0.value.loadedAt) < cacheLifetime }
  }

  nonisolated private static func isLocalhost(_ url: URL) -> Bool {
    ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
  }
}

enum ExternalSubtitleParser {
  static func parseSRT(_ text: String) -> [ExternalSubtitleCue] {
    parseTimedText(text, commaMilliseconds: true)
  }

  static func parseWebVTT(_ text: String) -> [ExternalSubtitleCue] {
    parseTimedText(text.replacingOccurrences(of: "WEBVTT", with: ""), commaMilliseconds: false)
  }

  static func parseASS(_ text: String) -> [ExternalSubtitleCue] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    var inEvents = false
    var format: [String] = []
    var cues: [ExternalSubtitleCue] = []

    for rawLine in normalized.components(separatedBy: "\n") {
      let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      if line.hasPrefix("[") {
        inEvents = line.caseInsensitiveCompare("[Events]") == .orderedSame
        continue
      }
      guard inEvents else { continue }
      if line.lowercased().hasPrefix("format:") {
        format = line.dropFirst(line.firstIndex(of: ":")!.utf16Offset(in: line) + 1)
          .split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        continue
      }
      guard line.lowercased().hasPrefix("dialogue:") else { continue }
      let payload = String(line.dropFirst(line.firstIndex(of: ":")!.utf16Offset(in: line) + 1))
      let expectedColumns = max(format.count, 10)
      let values = payload.split(
        separator: ",", maxSplits: expectedColumns - 1, omittingEmptySubsequences: false
      )
      .map(String.init)
      let startIndex = format.firstIndex(of: "start") ?? 1
      let endIndex = format.firstIndex(of: "end") ?? 2
      let textIndex = format.firstIndex(of: "text") ?? min(9, values.count - 1)
      guard values.indices.contains(startIndex), values.indices.contains(endIndex),
        values.indices.contains(textIndex),
        let start = assTimestamp(values[startIndex]),
        let end = assTimestamp(values[endIndex]), end > start
      else { continue }
      let cueText = values[textIndex]
        .replacingOccurrences(of: #"\{[^}]*\}"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: "\\N", with: "\n")
        .replacingOccurrences(of: "\\n", with: "\n")
        .replacingOccurrences(of: "\\h", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cueText.isEmpty else { continue }
      cues.append(ExternalSubtitleCue(start: start, end: end, text: cueText))
    }
    return cues.sorted { $0.start < $1.start }
  }

  private static func parseTimedText(_ text: String, commaMilliseconds: Bool)
    -> [ExternalSubtitleCue]
  {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    return normalized.components(separatedBy: "\n\n").compactMap { block in
      let lines = block.components(separatedBy: "\n").filter { !$0.isEmpty }
      guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else { return nil }
      let parts = lines[timingIndex].components(separatedBy: "-->")
      guard parts.count == 2 else { return nil }
      let endValue = parts[1]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .first
        .map(String.init)
      guard
        let start = timestamp(parts[0], commaMilliseconds: commaMilliseconds),
        let endValue,
        let end = timestamp(endValue, commaMilliseconds: commaMilliseconds)
      else { return nil }

      let cueText = lines.dropFirst(timingIndex + 1)
        .joined(separator: "\n")
        .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cueText.isEmpty else { return nil }
      return ExternalSubtitleCue(start: start, end: end, text: cueText)
    }
    .sorted { $0.start < $1.start }
  }

  private static func timestamp(_ value: String, commaMilliseconds: Bool) -> TimeInterval? {
    var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if commaMilliseconds { cleaned = cleaned.replacingOccurrences(of: ",", with: ".") }
    let components = cleaned.split(separator: ":")
    guard components.count == 2 || components.count == 3 else { return nil }
    guard let seconds = Double(components.last ?? "") else { return nil }
    let minutes = Double(components[components.count - 2]) ?? 0
    let hours = components.count == 3 ? Double(components[0]) ?? 0 : 0
    return hours * 3600 + minutes * 60 + seconds
  }

  private static func assTimestamp(_ value: String) -> TimeInterval? {
    timestamp(value, commaMilliseconds: false)
  }
}
