import Foundation

struct AddonStreamPlaybackMapper {
  func playbackSources(
    from streams: [AddonStream],
    addonName: String? = nil
  ) -> [PlaybackSource] {
    streams.compactMap { stream -> PlaybackSource? in
      guard let url = stream.url else { return nil }
      let searchable = [stream.name, stream.title, url.lastPathComponent]
        .compactMap { $0 }
        .joined(separator: " ")
      let normalized = searchable.lowercased()

      return PlaybackSource(
        id: stream.id,
        url: url,
        displayName: stream.title ?? stream.name
          ?? NSLocalizedString("playback.source.default", comment: "Fallback source name"),
        addonName: addonName,
        filename: url.lastPathComponent.isEmpty ? nil : url.lastPathComponent,
        container: container(
          url: url, text: normalized, webReady: stream.behaviorHints?.notWebReady != true),
        resolutionHeight: resolutionHeight(in: normalized),
        bitrate: bitrate(in: normalized),
        dynamicRanges: dynamicRanges(in: normalized),
        audioFormats: audioFormats(in: normalized),
        isCached: cachedSignal(in: normalized),
        seeders: seeders(in: normalized),
        headers: stream.behaviorHints?.proxyHeaders?.request ?? [:]
      )
    }
  }

  private func container(
    url: URL,
    text: String,
    webReady: Bool
  ) -> PlaybackSource.Container {
    guard webReady else { return .matroska }

    switch url.pathExtension.lowercased() {
    case "m3u8": return .hls
    case "mp4", "m4v": return .mp4
    case "mov": return .mov
    case "ts", "m2ts": return .mpegTS
    case "mkv": return .matroska
    case "webm": return .webM
    default:
      if text.contains("hls") { return .hls }
      return .unknown
    }
  }

  private func resolutionHeight(in text: String) -> Int? {
    if text.contains("2160p") || text.contains("4k") { return 2160 }
    if text.contains("1440p") { return 1440 }
    if text.contains("1080p") { return 1080 }
    if text.contains("720p") { return 720 }
    if text.contains("576p") { return 576 }
    if text.contains("480p") { return 480 }
    return nil
  }

  private func dynamicRanges(in text: String) -> Set<PlaybackSource.DynamicRange> {
    var result: Set<PlaybackSource.DynamicRange> = []
    if text.contains("dolby vision") || text.contains("dovi")
      || text.range(of: #"\bdv\b"#, options: .regularExpression) != nil
    {
      result.insert(.dolbyVision)
    }
    if text.contains("hdr10") || text.range(of: #"\bhdr\b"#, options: .regularExpression) != nil {
      result.insert(.hdr10)
    }
    if text.contains("hlg") { result.insert(.hlg) }
    if result.isEmpty { result.insert(.sdr) }
    return result
  }

  private func audioFormats(in text: String) -> Set<PlaybackSource.AudioFormat> {
    var result: Set<PlaybackSource.AudioFormat> = []
    if text.contains("atmos") { result.insert(.dolbyAtmos) }
    if text.contains("eac3") || text.contains("dd+") || text.contains("ddp") {
      result.insert(.dolbyDigitalPlus)
    }
    if text.contains("ac3") || text.range(of: #"\bdd\b"#, options: .regularExpression) != nil {
      result.insert(.dolbyDigital)
    }
    if text.contains("truehd") { result.insert(.trueHD) }
    if text.contains("aac") { result.insert(.aac) }
    if text.contains("flac") { result.insert(.flac) }
    if text.contains("dts") { result.insert(.dts) }
    if result.isEmpty { result.insert(.unknown) }
    return result
  }

  private func cachedSignal(in text: String) -> Bool {
    text.contains("cached") || text.contains("instant") || text.contains("⚡")
  }

  private func seeders(in text: String) -> Int? {
    firstInteger(
      in: text,
      patterns: [
        #"(?:seeders?|seeds?)\s*[:=]?\s*(\d+)"#,
        #"👤\s*(\d+)"#,
        #"🌱\s*(\d+)"#,
      ])
  }

  private func bitrate(in text: String) -> Int? {
    guard let mbps = firstDecimal(in: text, pattern: #"(\d+(?:[\.,]\d+)?)\s*mbps"#) else {
      return nil
    }
    return Int(mbps * 1_000_000)
  }

  private func firstInteger(in text: String, patterns: [String]) -> Int? {
    for pattern in patterns {
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
        let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
        match.numberOfRanges > 1,
        let range = Range(match.range(at: 1), in: text),
        let value = Int(text[range])
      else { continue }
      return value
    }
    return nil
  }

  private func firstDecimal(in text: String, pattern: String) -> Double? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      match.numberOfRanges > 1,
      let range = Range(match.range(at: 1), in: text)
    else { return nil }
    return Double(text[range].replacingOccurrences(of: ",", with: "."))
  }
}
