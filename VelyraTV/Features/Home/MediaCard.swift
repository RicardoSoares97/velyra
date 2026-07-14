import SwiftUI

struct MediaCard: View {
    let title: String
    let subtitle: String

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VelyraTheme.elevatedSurface(for: colorScheme))

                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(VelyraTheme.primary)
                }
                .frame(width: 300, height: 170)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(VelyraTheme.textPrimary(for: colorScheme))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VelyraTheme.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            .padding(14)
            .background(VelyraTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isFocused ? VelyraTheme.focusRing : VelyraTheme.border(for: colorScheme),
                        lineWidth: isFocused ? 5 : 1
                    )
            }
            .scaleEffect(isFocused ? 1.07 : 1)
            .shadow(radius: isFocused ? 22 : 4)
            .animation(.easeOut(duration: 0.16), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }
}
