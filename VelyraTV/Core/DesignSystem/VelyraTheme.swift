import SwiftUI

enum VelyraTheme {
    static let primary = Color(hex: 0xDD571C)
    static let primaryHover = Color(hex: 0xF06A2D)
    static let primaryPressed = Color(hex: 0xB74413)
    static let onPrimary = Color(hex: 0x111114)
    static let focusRing = Color(hex: 0xFF8A55)
    static let pureBlack = Color.black

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x09090B) : Color(hex: 0xF7F7F8)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x151518) : Color(hex: 0xFFFFFF)
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x202024) : Color(hex: 0xEFEFF2)
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF7F7F8) : Color(hex: 0x111114)
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xA7A7AF) : Color(hex: 0x62626A)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x34343A) : Color(hex: 0xDDDDE2)
    }
}
