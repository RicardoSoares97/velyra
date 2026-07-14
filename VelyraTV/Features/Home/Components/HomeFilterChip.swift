import SwiftUI

struct HomeFilterChip: View {
    @FocusState private var isFocused: Bool

    let title: String
    let iconURL: URL?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let iconURL {
                    AsyncImage(url: iconURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                }

                Text(title)
                    .font(.headline.weight(isSelected ? .bold : .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 58)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected ? VelyraTheme.primary.opacity(0.94) : .white.opacity(isFocused ? 0.18 : 0.09))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isFocused ? VelyraTheme.focusRing : .white.opacity(0.10), lineWidth: isFocused ? 3 : 1)
            }
            .scaleEffect(isFocused ? 1.05 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.36 : 0.12), radius: isFocused ? 22 : 8, y: 10)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibleMotion(value: isFocused)
    }
}
