import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case portuguesePortugal = "pt-PT"
    case english = "en"
    case spanish = "es"
    case french = "fr"

    var id: String { rawValue }

    var locale: Locale? {
        guard self != .system else { return nil }
        return Locale(identifier: rawValue)
    }

    var displayNameKey: String {
        switch self {
        case .system: "language.system"
        case .portuguesePortugal: "language.portuguese"
        case .english: "language.english"
        case .spanish: "language.spanish"
        case .french: "language.french"
        }
    }
}
