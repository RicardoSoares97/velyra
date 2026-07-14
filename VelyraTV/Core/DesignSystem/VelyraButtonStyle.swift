import SwiftUI

struct VelyraPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(VelyraTheme.onPrimary)
            .padding(.horizontal, 30)
            .padding(.vertical, 16)
            .background(
                configuration.isPressed
                    ? VelyraTheme.primaryPressed
                    : VelyraTheme.primary
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VelyraTheme.focusRing, lineWidth: isFocused ? 5 : 0)
            }
            .scaleEffect(isFocused ? 1.06 : 1)
            .shadow(radius: isFocused ? 18 : 0)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}
