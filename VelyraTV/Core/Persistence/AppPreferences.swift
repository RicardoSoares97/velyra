import Foundation

enum AppThemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  var id: String { rawValue }
  var displayNameKey: String {
    switch self {
    case .system: "theme.system"
    case .light: "theme.light"
    case .dark: "theme.dark"
    }
  }
}

enum AudioSelectionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case original
  case system
  case custom

  var id: String { rawValue }
  var displayNameKey: String {
    switch self {
    case .original: "playback.audio.original"
    case .system: "playback.audio.system"
    case .custom: "playback.audio.custom"
    }
  }
}

enum SubtitleSelectionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case region
  case system
  case custom
  case off

  var id: String { rawValue }
  var displayNameKey: String {
    switch self {
    case .region: "playback.subtitles.region"
    case .system: "playback.subtitles.system"
    case .custom: "playback.subtitles.custom"
    case .off: "playback.subtitles.off"
    }
  }
}

enum PlaybackResolutionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case automatic
  case ultraHD
  case fullHD
  case hd

  var id: String { rawValue }
  var maximumHeight: Int? {
    switch self {
    case .automatic, .ultraHD: 2160
    case .fullHD: 1080
    case .hd: 720
    }
  }
  var displayNameKey: String {
    switch self {
    case .automatic: "playback.quality.automatic"
    case .ultraHD: "playback.quality.4k"
    case .fullHD: "playback.quality.1080p"
    case .hd: "playback.quality.720p"
    }
  }
}

enum SubtitleTextSizePreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case small
  case medium
  case large
  case extraLarge

  var id: String { rawValue }
  var scale: Double {
    switch self {
    case .small: 0.85
    case .medium: 1
    case .large: 1.2
    case .extraLarge: 1.45
    }
  }
  var displayNameKey: String {
    switch self {
    case .small: "playback.subtitles.size.small"
    case .medium: "playback.subtitles.size.medium"
    case .large: "playback.subtitles.size.large"
    case .extraLarge: "playback.subtitles.size.extraLarge"
    }
  }
}

enum HomeSectionPreference: String, Codable, CaseIterable, Identifiable, Sendable {
  case continueWatching
  case trendingSeries
  case trendingMovies
  case topSeries
  case topMovies
  case genres
  case providers
  case providerCollections

  var id: String { rawValue }
}

struct AppPreferences: Codable, Equatable, Sendable {
  var hasCompletedOnboarding = false
  var theme: AppThemePreference = .system
  var language: AppLanguage = .system
  var contentRegion: String? = nil
  var iCloudSyncEnabled = true
  var backgroundVideoEnabled = true
  var autoplayPreviews = true
  var backgroundBlurRadius = 4.0
  var backgroundOverlayOpacity = 0.42

  var preferredAudioLanguage: AudioSelectionPreference = .original
  var preferredAudioLanguageCode: String? = nil
  var secondaryAudioLanguageCode: String? = nil
  var preferredSubtitleLanguage: SubtitleSelectionPreference = .region
  var preferredSubtitleLanguageCode: String? = nil
  var secondarySubtitleLanguageCode: String? = "en"
  var subtitlesEnabledByDefault = true
  var subtitleTextSize: SubtitleTextSizePreference = .medium
  var subtitleVerticalOffset = 0.0
  var subtitleBackgroundOpacity = 0.66

  var automaticSourceSelection = true
  var automaticLanguageSelection = true
  var maximumResolution: PlaybackResolutionPreference = .automatic
  var preferDirectPlay = true
  var preferCachedSources = true
  var preferDolbyVision = true
  var preferHDR = true
  var preferDolbyAtmos = true
  var automaticSourceFailover = true

  var addonManifestURLs: [String] = []
  var disabledAddonManifestURLs: [String] = []
  var addonPriority: [String] = []

  var homeSectionOrder: [HomeSectionPreference] = HomeSectionPreference.allCases
  var hiddenHomeSections: [HomeSectionPreference] = []
  var searchHistoryEnabled = true
  var diagnosticsEnabled = false

  static let defaults = AppPreferences()

  var activeAddonManifestURLs: [String] {
    let enabled = addonManifestURLs.filter { !disabledAddonManifestURLs.contains($0) }
    let priority = Dictionary(uniqueKeysWithValues: addonPriority.enumerated().map { ($1, $0) })
    return enabled.sorted {
      let lhs = priority[$0] ?? Int.max
      let rhs = priority[$1] ?? Int.max
      return lhs == rhs ? $0 < $1 : lhs < rhs
    }
  }

  mutating func normalize() {
    var seenAddonURLs = Set<String>()
    addonManifestURLs = addonManifestURLs.filter { seenAddonURLs.insert($0).inserted }
    disabledAddonManifestURLs = disabledAddonManifestURLs.filter(addonManifestURLs.contains)
    addonPriority = addonPriority.filter(addonManifestURLs.contains)
    for url in addonManifestURLs where !addonPriority.contains(url) { addonPriority.append(url) }
    homeSectionOrder = homeSectionOrder.filter(HomeSectionPreference.allCases.contains)
    for section in HomeSectionPreference.allCases where !homeSectionOrder.contains(section) {
      homeSectionOrder.append(section)
    }
    hiddenHomeSections = hiddenHomeSections.filter(HomeSectionPreference.allCases.contains)
    backgroundBlurRadius = min(max(backgroundBlurRadius, 0), 20)
    backgroundOverlayOpacity = min(max(backgroundOverlayOpacity, 0.2), 0.9)
    subtitleVerticalOffset = min(max(subtitleVerticalOffset, -0.25), 0.25)
    subtitleBackgroundOpacity = min(max(subtitleBackgroundOpacity, 0), 1)
  }

  private enum CodingKeys: String, CodingKey {
    case hasCompletedOnboarding, theme, language, contentRegion, iCloudSyncEnabled
    case backgroundVideoEnabled, autoplayPreviews, backgroundBlurRadius, backgroundOverlayOpacity
    case preferredAudioLanguage, preferredAudioLanguageCode, secondaryAudioLanguageCode
    case preferredSubtitleLanguage, preferredSubtitleLanguageCode, secondarySubtitleLanguageCode
    case subtitlesEnabledByDefault, subtitleTextSize, subtitleVerticalOffset
    case subtitleBackgroundOpacity, automaticSourceSelection, automaticLanguageSelection
    case maximumResolution, preferDirectPlay, preferCachedSources, preferDolbyVision, preferHDR
    case preferDolbyAtmos, automaticSourceFailover, addonManifestURLs, disabledAddonManifestURLs
    case addonPriority, homeSectionOrder, hiddenHomeSections, searchHistoryEnabled
    case diagnosticsEnabled
  }

  init() {}

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = AppPreferences.defaults
    hasCompletedOnboarding =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
      ?? defaults.hasCompletedOnboarding
    theme = try container.decodeIfPresent(AppThemePreference.self, forKey: .theme) ?? defaults.theme
    language =
      try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? defaults.language
    contentRegion = try container.decodeIfPresent(String.self, forKey: .contentRegion)
    iCloudSyncEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled)
      ?? defaults.iCloudSyncEnabled
    backgroundVideoEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .backgroundVideoEnabled)
      ?? defaults.backgroundVideoEnabled
    autoplayPreviews =
      try container.decodeIfPresent(Bool.self, forKey: .autoplayPreviews)
      ?? defaults.autoplayPreviews
    backgroundBlurRadius =
      try container.decodeIfPresent(Double.self, forKey: .backgroundBlurRadius)
      ?? defaults.backgroundBlurRadius
    backgroundOverlayOpacity =
      try container.decodeIfPresent(Double.self, forKey: .backgroundOverlayOpacity)
      ?? defaults.backgroundOverlayOpacity
    preferredAudioLanguage =
      try container.decodeIfPresent(AudioSelectionPreference.self, forKey: .preferredAudioLanguage)
      ?? defaults.preferredAudioLanguage
    preferredAudioLanguageCode = try container.decodeIfPresent(
      String.self, forKey: .preferredAudioLanguageCode)
    secondaryAudioLanguageCode = try container.decodeIfPresent(
      String.self, forKey: .secondaryAudioLanguageCode)
    preferredSubtitleLanguage =
      try container.decodeIfPresent(
        SubtitleSelectionPreference.self, forKey: .preferredSubtitleLanguage)
      ?? defaults.preferredSubtitleLanguage
    preferredSubtitleLanguageCode = try container.decodeIfPresent(
      String.self, forKey: .preferredSubtitleLanguageCode)
    secondarySubtitleLanguageCode =
      try container.decodeIfPresent(String.self, forKey: .secondarySubtitleLanguageCode)
      ?? defaults.secondarySubtitleLanguageCode
    subtitlesEnabledByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .subtitlesEnabledByDefault)
      ?? defaults.subtitlesEnabledByDefault
    subtitleTextSize =
      try container.decodeIfPresent(SubtitleTextSizePreference.self, forKey: .subtitleTextSize)
      ?? defaults.subtitleTextSize
    subtitleVerticalOffset =
      try container.decodeIfPresent(Double.self, forKey: .subtitleVerticalOffset)
      ?? defaults.subtitleVerticalOffset
    subtitleBackgroundOpacity =
      try container.decodeIfPresent(Double.self, forKey: .subtitleBackgroundOpacity)
      ?? defaults.subtitleBackgroundOpacity
    automaticSourceSelection =
      try container.decodeIfPresent(Bool.self, forKey: .automaticSourceSelection)
      ?? defaults.automaticSourceSelection
    automaticLanguageSelection =
      try container.decodeIfPresent(Bool.self, forKey: .automaticLanguageSelection)
      ?? defaults.automaticLanguageSelection
    maximumResolution =
      try container.decodeIfPresent(PlaybackResolutionPreference.self, forKey: .maximumResolution)
      ?? defaults.maximumResolution
    preferDirectPlay =
      try container.decodeIfPresent(Bool.self, forKey: .preferDirectPlay)
      ?? defaults.preferDirectPlay
    preferCachedSources =
      try container.decodeIfPresent(Bool.self, forKey: .preferCachedSources)
      ?? defaults.preferCachedSources
    preferDolbyVision =
      try container.decodeIfPresent(Bool.self, forKey: .preferDolbyVision)
      ?? defaults.preferDolbyVision
    preferHDR = try container.decodeIfPresent(Bool.self, forKey: .preferHDR) ?? defaults.preferHDR
    preferDolbyAtmos =
      try container.decodeIfPresent(Bool.self, forKey: .preferDolbyAtmos)
      ?? defaults.preferDolbyAtmos
    automaticSourceFailover =
      try container.decodeIfPresent(Bool.self, forKey: .automaticSourceFailover)
      ?? defaults.automaticSourceFailover
    addonManifestURLs =
      try container.decodeIfPresent([String].self, forKey: .addonManifestURLs)
      ?? defaults.addonManifestURLs
    disabledAddonManifestURLs =
      try container.decodeIfPresent([String].self, forKey: .disabledAddonManifestURLs)
      ?? defaults.disabledAddonManifestURLs
    addonPriority =
      try container.decodeIfPresent([String].self, forKey: .addonPriority) ?? addonManifestURLs
    homeSectionOrder =
      try container.decodeIfPresent([HomeSectionPreference].self, forKey: .homeSectionOrder)
      ?? defaults.homeSectionOrder
    hiddenHomeSections =
      try container.decodeIfPresent([HomeSectionPreference].self, forKey: .hiddenHomeSections)
      ?? defaults.hiddenHomeSections
    searchHistoryEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .searchHistoryEnabled)
      ?? defaults.searchHistoryEnabled
    diagnosticsEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled)
      ?? defaults.diagnosticsEnabled
    normalize()
  }
}

extension AppPreferences {
  mutating func resetPlaybackPreferences() {
    let defaults = AppPreferences.defaults
    preferredAudioLanguage = defaults.preferredAudioLanguage
    preferredAudioLanguageCode = defaults.preferredAudioLanguageCode
    secondaryAudioLanguageCode = defaults.secondaryAudioLanguageCode
    preferredSubtitleLanguage = defaults.preferredSubtitleLanguage
    preferredSubtitleLanguageCode = defaults.preferredSubtitleLanguageCode
    secondarySubtitleLanguageCode = defaults.secondarySubtitleLanguageCode
    subtitlesEnabledByDefault = defaults.subtitlesEnabledByDefault
    subtitleTextSize = defaults.subtitleTextSize
    subtitleVerticalOffset = defaults.subtitleVerticalOffset
    subtitleBackgroundOpacity = defaults.subtitleBackgroundOpacity
    automaticSourceSelection = defaults.automaticSourceSelection
    automaticLanguageSelection = defaults.automaticLanguageSelection
    maximumResolution = defaults.maximumResolution
    preferDirectPlay = defaults.preferDirectPlay
    preferCachedSources = defaults.preferCachedSources
    preferDolbyVision = defaults.preferDolbyVision
    preferHDR = defaults.preferHDR
    preferDolbyAtmos = defaults.preferDolbyAtmos
    automaticSourceFailover = defaults.automaticSourceFailover
  }

  mutating func resetHomePreferences() {
    homeSectionOrder = AppPreferences.defaults.homeSectionOrder
    hiddenHomeSections = AppPreferences.defaults.hiddenHomeSections
  }

  mutating func resetAddonPreferences() {
    addonManifestURLs = []
    disabledAddonManifestURLs = []
    addonPriority = []
  }
}
