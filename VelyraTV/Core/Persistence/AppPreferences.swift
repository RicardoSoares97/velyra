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

struct AppPreferences: Codable, Equatable {
    var hasCompletedOnboarding = false
    var theme: AppThemePreference = .system
    var language: AppLanguage = .system
    var iCloudSyncEnabled = true
    var backgroundVideoEnabled = true
    var autoplayPreviews = true
    var backgroundBlurRadius = 4.0
    var backgroundOverlayOpacity = 0.42
    var preferredAudioLanguage = "system"
    var preferredSubtitleLanguage = "system"
    var subtitlesEnabledByDefault = false
    var addonManifestURLs: [String] = []

    static let defaults = AppPreferences()
}
