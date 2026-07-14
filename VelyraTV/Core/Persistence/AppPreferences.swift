import Foundation

enum AppThemePreference: String, Codable, CaseIterable, Identifiable {
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

enum AudioSelectionPreference: String, Codable, CaseIterable, Identifiable {
  case original
  case system

  var id: String { rawValue }

  var displayNameKey: String {
    switch self {
    case .original: "playback.audio.original"
    case .system: "playback.audio.system"
    }
  }
}

enum SubtitleSelectionPreference: String, Codable, CaseIterable, Identifiable {
  case region
  case system
  case off

  var id: String { rawValue }

  var displayNameKey: String {
    switch self {
    case .region: "playback.subtitles.region"
    case .system: "playback.subtitles.system"
    case .off: "playback.subtitles.off"
    }
  }
}

enum PlaybackResolutionPreference: String, Codable, CaseIterable, Identifiable {
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

struct AppPreferences: Codable, Equatable {
  var hasCompletedOnboarding = false
  var theme: AppThemePreference = .system
  var language: AppLanguage = .system
  var contentRegion: String? = nil
  var iCloudSyncEnabled = true
  var backgroundVideoEnabled = true
  var autoplayPreviews = true
  var backgroundBlurRadius = 4.0
  var backgroundOverlayOpacity = 0.42

  // Smart playback defaults. These values are intentionally friendly for
  // people who do not want to configure technical media options.
  var preferredAudioLanguage: AudioSelectionPreference = .original
  var preferredSubtitleLanguage: SubtitleSelectionPreference = .region
  var subtitlesEnabledByDefault = true
  var automaticSourceSelection = true
  var automaticLanguageSelection = true
  var maximumResolution: PlaybackResolutionPreference = .automatic
  var preferDirectPlay = true
  var preferDolbyVision = true
  var preferHDR = true
  var preferDolbyAtmos = true
  var automaticSourceFailover = true

  var addonManifestURLs: [String] = []

  static let defaults = AppPreferences()

  private enum CodingKeys: String, CodingKey {
    case hasCompletedOnboarding
    case theme
    case language
    case contentRegion
    case iCloudSyncEnabled
    case backgroundVideoEnabled
    case autoplayPreviews
    case backgroundBlurRadius
    case backgroundOverlayOpacity
    case preferredAudioLanguage
    case preferredSubtitleLanguage
    case subtitlesEnabledByDefault
    case automaticSourceSelection
    case automaticLanguageSelection
    case maximumResolution
    case preferDirectPlay
    case preferDolbyVision
    case preferHDR
    case preferDolbyAtmos
    case automaticSourceFailover
    case addonManifestURLs
  }

  init() {}

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = AppPreferences.defaults

    hasCompletedOnboarding =
      try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
      ?? defaults.hasCompletedOnboarding
    theme =
      try container.decodeIfPresent(AppThemePreference.self, forKey: .theme)
      ?? defaults.theme
    language =
      try container.decodeIfPresent(AppLanguage.self, forKey: .language)
      ?? defaults.language
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
    preferredSubtitleLanguage =
      try container.decodeIfPresent(
        SubtitleSelectionPreference.self, forKey: .preferredSubtitleLanguage)
      ?? defaults.preferredSubtitleLanguage
    subtitlesEnabledByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .subtitlesEnabledByDefault)
      ?? defaults.subtitlesEnabledByDefault
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
    preferDolbyVision =
      try container.decodeIfPresent(Bool.self, forKey: .preferDolbyVision)
      ?? defaults.preferDolbyVision
    preferHDR =
      try container.decodeIfPresent(Bool.self, forKey: .preferHDR)
      ?? defaults.preferHDR
    preferDolbyAtmos =
      try container.decodeIfPresent(Bool.self, forKey: .preferDolbyAtmos)
      ?? defaults.preferDolbyAtmos
    automaticSourceFailover =
      try container.decodeIfPresent(Bool.self, forKey: .automaticSourceFailover)
      ?? defaults.automaticSourceFailover

    addonManifestURLs =
      try container.decodeIfPresent([String].self, forKey: .addonManifestURLs)
      ?? defaults.addonManifestURLs
  }
}
