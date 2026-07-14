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
  enum SubtitleError: LocalizedError {
    case insecureURL
    case responseTooLarge
    case unsupportedFormat
    case invalidEncoding

    var errorDescription: String? {
      switch self {
      case .insecureURL: String(localized: "subtitles.error.secureConnection")
      case .responseTooLarge: String(localized: "subtitles.error.tooLarge")
      case .unsupportedFormat: String(localized: "subtitles.error.unsupported")
      case .invalidEncoding: String(localized: "subtitles.error.encoding")
      }
    }
  }

  private let session: URLSession
  private let maximumBytes = 5_000_000

  init(session: URLSession = .shared) {
    self.session = session
  }

  func cues(for track: ExternalSubtitleTrack) async throws -> [ExternalSubtitleCue] {
    guard track.url.scheme?.lowercased() == "https" || isLocalhost(track.url) else {
      throw SubtitleError.insecureURL
    }

    var request = URLRequest(url: track.url)
    request.timeoutInterval = 20
    request.setValue("text/vtt, application/x-subrip, text/plain", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    if let expected = response.expectedContentLength, expected > maximumBytes {
      throw SubtitleError.responseTooLarge
    }
    guard data.count <= maximumBytes else { throw SubtitleError.responseTooLarge }
    guard
      let text = String(data: data, encoding: .utf8)
        ?? String(data: data, encoding: .isoLatin1)
    else {
      throw SubtitleError.invalidEncoding
    }

    let extensionName = track.url.pathExtension.lowercased()
    if extensionName == "vtt"
      || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT")
    {
      return ExternalSubtitleParser.parseWebVTT(text)
    }
    if extensionName == "srt" || text.contains("-->") {
      return ExternalSubtitleParser.parseSRT(text)
    }
    throw SubtitleError.unsupportedFormat
  }

  private func isLocalhost(_ url: URL) -> Bool {
    ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
  }
}

enum ExternalSubtitleParser {
  static func parseSRT(_ text: String) -> [ExternalSubtitleCue] {
    parse(text, commaMilliseconds: true)
  }

  static func parseWebVTT(_ text: String) -> [ExternalSubtitleCue] {
    parse(text.replacingOccurrences(of: "WEBVTT", with: ""), commaMilliseconds: false)
  }

  private static func parse(_ text: String, commaMilliseconds: Bool) -> [ExternalSubtitleCue] {
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
    if commaMilliseconds {
      cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
    }
    let components = cleaned.split(separator: ":")
    guard components.count == 2 || components.count == 3 else { return nil }
    let secondsPart = Double(components.last ?? "")
    guard let secondsPart else { return nil }
    let minutes = Double(components[components.count - 2]) ?? 0
    let hours = components.count == 3 ? Double(components[0]) ?? 0 : 0
    return hours * 3600 + minutes * 60 + secondsPart
  }
}
