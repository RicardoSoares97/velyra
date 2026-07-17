import SwiftUI

struct MediaCardModel: Identifiable, Hashable {
  let id = UUID()
  let title: String
  let subtitle: String
  let progress: Double?
}

struct MediaCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isFocused: Bool

  let model: MediaCardModel

  var body: some View {
    Button {
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        ZStack(alignment: .bottomLeading) {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  VelyraTheme.primary.opacity(0.76),
                  Color.indigo.opacity(0.78),
                  Color.black,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 330, height: 186)
            .overlay(alignment: .center) {
              Image(systemName: "play.tv.fill")
                .font(.system(size: 46))
                .foregroundStyle(.white.opacity(0.24))
            }

          if let progress = model.progress {
            GeometryReader { proxy in
              Capsule()
                .fill(VelyraTheme.primary)
                .frame(width: proxy.size.width * progress, height: 6)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: 302, height: 6)
            .padding(14)
          }
        }
        .overlay {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
              isFocused ? VelyraTheme.focusRing : .white.opacity(0.12), lineWidth: isFocused ? 4 : 1
            )
        }

        Text(model.title)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)

        Text(model.subtitle)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.62))
          .lineLimit(1)
      }
      .frame(width: 330, alignment: .leading)
      .scaleEffect(isFocused && !reduceMotion ? 1.055 : 1)
      .shadow(color: .black.opacity(isFocused ? 0.48 : 0.16), radius: isFocused ? 28 : 10, y: 14)
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(model.title)
    .accessibilityValue(model.subtitle)
    .accessibilityHint(Text("media.openDetails.hint"))
    .accessibleMotion(value: isFocused)
  }
}
