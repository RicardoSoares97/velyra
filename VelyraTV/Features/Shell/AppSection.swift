import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case home
    case search
    case library
    case addons
    case settings

    var id: String { rawValue }

    var titleKey: String {
        "navigation.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .search: "magnifyingglass"
        case .library: "rectangle.stack.fill"
        case .addons: "puzzlepiece.extension.fill"
        case .settings: "gearshape.fill"
        }
    }
}
