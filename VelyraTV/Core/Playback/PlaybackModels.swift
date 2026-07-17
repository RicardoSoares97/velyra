import Foundation

struct PlaybackRequest: Equatable, Sendable {
  let contentKey: String
  let title: String
  let originalLanguageCode: String?
  let sources: [PlaybackSource]
  let externalSubtitles: [ExternalSubtitleTrack]
  let initialPosition: TimeInterval
  let initialProgress: Double?
  let traktContext: TraktPlaybackContext?

  init(
    contentKey: String? = nil,
    title: String,
    originalLanguageCode: String? = nil,
    sources: [PlaybackSource],
    externalSubtitles: [ExternalSubtitleTrack] = [],
    initialPosition: TimeInterval = 0,
    initialProgress: Double? = nil,
    traktContext: TraktPlaybackContext? = nil
  ) {
    self.contentKey = contentKey ?? title.lowercased()
    self.title = title
    self.originalLanguageCode = originalLanguageCode
    self.sources = sources
    self.externalSubtitles = externalSubtitles
    self.initialPosition = max(0, initialPosition)
    self.initialProgress = initialProgress.map { min(max($0, 0), 100) }
    self.traktContext = traktContext
  }
}

struct PlaybackSource: Identifiable, Equatable, Hashable, Sendable {
  enum Container: String, Sendable {
    case hls
    case mp4
    case mov
    case mpegTS
    case matroska
    case webM
    case unknown
  }

  enum DynamicRange: String, Hashable, Sendable {
    case dolbyVision
    case hdr10
    case hlg
    case sdr
  }

  enum AudioFormat: String, Hashable, Sendable {
    case dolbyAtmos
    case dolbyDigitalPlus
    case dolbyDigital
    case aac
    case flac
    case trueHD
    case dts
    case unknown
  }

  let id: String
  let url: URL
  let displayName: String
  let addonName: String?
  let filename: String?
  let container: Container
  let resolutionHeight: Int?
  let bitrate: Int?
  let dynamicRanges: Set<DynamicRange>
  let audioFormats: Set<AudioFormat>
  let isCached: Bool
  let seeders: Int?
  let headers: [String: String]

  init(
    id: String = UUID().uuidString,
    url: URL,
    displayName: String,
    addonName: String? = nil,
    filename: String? = nil,
    container: Container = .unknown,
    resolutionHeight: Int? = nil,
    bitrate: Int? = nil,
    dynamicRanges: Set<DynamicRange> = [],
    audioFormats: Set<AudioFormat> = [],
    isCached: Bool = false,
    seeders: Int? = nil,
    headers: [String: String] = [:]
  ) {
    self.id = id
    self.url = url
    self.displayName = displayName
    self.addonName = addonName
    self.filename = filename
    self.container = container
    self.resolutionHeight = resolutionHeight
    self.bitrate = bitrate
    self.dynamicRanges = dynamicRanges
    self.audioFormats = audioFormats
    self.isCached = isCached
    self.seeders = seeders
    self.headers = headers
  }
}

struct RankedPlaybackSource: Identifiable, Equatable, Sendable {
  let source: PlaybackSource
  let score: Int
  let reasons: [String]

  var id: String { source.id }
}

struct PlaybackCapabilities: Equatable, Sendable {
  let maximumResolutionHeight: Int
  let supportsDolbyVision: Bool
  let supportsHDR: Bool
  let supportsDolbyAtmos: Bool
  let supportedContainers: Set<PlaybackSource.Container>

  static let appleTV = PlaybackCapabilities(
    maximumResolutionHeight: 2160,
    supportsDolbyVision: true,
    supportsHDR: true,
    supportsDolbyAtmos: true,
    supportedContainers: [.hls, .mp4, .mov, .mpegTS]
  )
}

struct MediaTrackChoice: Identifiable, Equatable, Sendable {
  enum Kind: Sendable {
    case audio
    case subtitles
  }

  let id: String
  let kind: Kind
  let displayName: String
  let languageCode: String?
  let isSelected: Bool
  let isOff: Bool
  let isAccessibilityTrack: Bool
}
