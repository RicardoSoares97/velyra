import Foundation

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
  case appearance
  case experience
  case playback
  case audioSubtitles
  case homeSearch
  case accountsSync
  case storageDiagnostics
  case about

  var id: String { rawValue }
  var titleKey: String {
    switch self {
    case .appearance: "settings.appearance"
    case .experience: "settings.experience"
    case .playback: "settings.smartPlayback"
    case .audioSubtitles: "settings.languagesAndSubtitles"
    case .homeSearch: "settings.discovery"
    case .accountsSync: "settings.category.accountsSync.title"
    case .storageDiagnostics: "settings.storageAndDiagnostics"
    case .about: "settings.about"
    }
  }
  var summaryKey: String { "settings.category.\(rawValue).summary" }

  var systemImage: String {
    switch self {
    case .appearance: "circle.lefthalf.filled"
    case .experience: "sparkles.tv"
    case .playback: "play.rectangle.on.rectangle"
    case .audioSubtitles: "captions.bubble.fill"
    case .homeSearch: "rectangle.stack.badge.play"
    case .accountsSync: "person.2.badge.gearshape"
    case .storageDiagnostics: "externaldrive.badge.checkmark"
    case .about: "info.circle.fill"
    }
  }
}
