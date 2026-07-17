import Foundation

struct PlaybackDiagnostics: Equatable, Sendable {
  let sourceName: String
  let addonName: String?
  let container: String
  let resolution: String?
  let dynamicRange: String?
  let audioFormat: String?
  let delivery: String

  init(source: PlaybackSource) {
    sourceName = source.displayName
    addonName = source.addonName
    container = source.container.rawValue.uppercased()
    resolution = source.resolutionHeight.map { $0 >= 2160 ? "4K" : "\($0)p" }
    if source.dynamicRanges.contains(.dolbyVision) {
      dynamicRange = "Dolby Vision"
    } else if source.dynamicRanges.contains(.hdr10) {
      dynamicRange = "HDR10"
    } else if source.dynamicRanges.contains(.hlg) {
      dynamicRange = "HLG"
    } else {
      dynamicRange = source.dynamicRanges.contains(.sdr) ? "SDR" : nil
    }
    if source.audioFormats.contains(.dolbyAtmos) {
      audioFormat = "Dolby Atmos"
    } else if source.audioFormats.contains(.dolbyDigitalPlus) {
      audioFormat = "Dolby Digital Plus"
    } else if source.audioFormats.contains(.dolbyDigital) {
      audioFormat = "Dolby Digital"
    } else if source.audioFormats.contains(.aac) {
      audioFormat = "AAC"
    } else {
      audioFormat = nil
    }
    delivery =
      source.isCached
      ? String(localized: "playback.diagnostics.cached")
      : String(localized: "playback.diagnostics.direct")
  }

  var rows: [(String, String)] {
    var result = [
      (String(localized: "playback.diagnostics.source"), sourceName),
      (String(localized: "playback.diagnostics.container"), container),
      (String(localized: "playback.diagnostics.delivery"), delivery),
    ]
    if let addonName { result.append((String(localized: "playback.diagnostics.addon"), addonName)) }
    if let resolution {
      result.append((String(localized: "playback.diagnostics.resolution"), resolution))
    }
    if let dynamicRange {
      result.append((String(localized: "playback.diagnostics.range"), dynamicRange))
    }
    if let audioFormat {
      result.append((String(localized: "playback.diagnostics.audio"), audioFormat))
    }
    return result
  }
}
