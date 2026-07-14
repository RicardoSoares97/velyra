import Foundation

struct AutomaticSourceSelector {
  func rank(
    _ sources: [PlaybackSource],
    preferences: AppPreferences,
    capabilities: PlaybackCapabilities = .appleTV
  ) -> [RankedPlaybackSource] {
    sources
      .map { score($0, preferences: preferences, capabilities: capabilities) }
      .sorted {
        if $0.score == $1.score {
          return $0.source.displayName.localizedStandardCompare($1.source.displayName)
            == .orderedAscending
        }
        return $0.score > $1.score
      }
  }

  func bestSource(
    from sources: [PlaybackSource],
    preferences: AppPreferences,
    capabilities: PlaybackCapabilities = .appleTV
  ) -> PlaybackSource? {
    rank(sources, preferences: preferences, capabilities: capabilities).first?.source
  }

  private func score(
    _ source: PlaybackSource,
    preferences: AppPreferences,
    capabilities: PlaybackCapabilities
  ) -> RankedPlaybackSource {
    var score = 0
    var reasons: [String] = []

    if source.url.scheme?.lowercased() == "https" {
      score += 12
      reasons.append("secure")
    } else {
      score -= 40
    }

    if capabilities.supportedContainers.contains(source.container) {
      score += preferences.preferDirectPlay ? 140 : 80
      reasons.append("direct-play")
    } else if source.container == .matroska || source.container == .webM {
      score -= 260
      reasons.append("requires-fallback")
    } else {
      score -= 25
    }

    if source.isCached {
      score += 110
      reasons.append("cached")
    }

    if let height = source.resolutionHeight {
      let maximum = min(
        preferences.maximumResolution.maximumHeight ?? capabilities.maximumResolutionHeight,
        capabilities.maximumResolutionHeight
      )

      if height <= maximum {
        score += min(height / 9, 240)
        if height >= 2160 { reasons.append("4k") }
      } else {
        score -= 120 + ((height - maximum) / 10)
      }
    } else {
      score -= 10
    }

    if preferences.preferDolbyVision,
      capabilities.supportsDolbyVision,
      source.dynamicRanges.contains(.dolbyVision)
    {
      score += 55
      reasons.append("dolby-vision")
    } else if preferences.preferHDR,
      capabilities.supportsHDR,
      !source.dynamicRanges.isDisjoint(with: [.hdr10, .hlg])
    {
      score += 35
      reasons.append("hdr")
    }

    if preferences.preferDolbyAtmos,
      capabilities.supportsDolbyAtmos,
      source.audioFormats.contains(.dolbyAtmos)
    {
      score += 42
      reasons.append("dolby-atmos")
    }

    if let seeders = source.seeders {
      score += min(max(seeders, 0), 100)
      if seeders == 0 && !source.isCached { score -= 80 }
    }

    if let bitrate = source.bitrate {
      // Prefer high-quality encodes, but avoid implausibly large streams that
      // are more likely to stall on typical living-room connections.
      switch bitrate {
      case 1...2_000_000: score += 8
      case 2_000_001...25_000_000: score += 35
      case 25_000_001...60_000_000: score += 20
      case 60_000_001...: score -= 20
      default: break
      }
    }

    if source.displayName.localizedCaseInsensitiveContains("cam")
      || source.displayName.localizedCaseInsensitiveContains("telesync")
    {
      score -= 500
    }

    return RankedPlaybackSource(source: source, score: score, reasons: reasons)
  }
}
