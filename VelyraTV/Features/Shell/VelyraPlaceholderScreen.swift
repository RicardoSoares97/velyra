import SwiftUI

struct VelyraPlaceholderScreen<Content: View>: View {
  let titleKey: String
  let bodyKey: String
  let systemImage: String
  let accent: Color
  let content: () -> Content

  init(
    titleKey: String,
    bodyKey: String,
    systemImage: String,
    accent: Color,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.titleKey = titleKey
    self.bodyKey = bodyKey
    self.systemImage = systemImage
    self.accent = accent
    self.content = content
  }

  var body: some View {
    ZStack {
      CinematicBackgroundView(videoName: "ambient-shell", focalColor: accent)

      VStack(alignment: .leading, spacing: 28) {
        Image(systemName: systemImage)
          .font(.system(size: 52, weight: .semibold))
          .foregroundStyle(VelyraTheme.primary)

        Text(LocalizedStringKey(titleKey))
          .font(.system(size: 56, weight: .bold, design: .rounded))
          .foregroundStyle(.white)

        Text(LocalizedStringKey(bodyKey))
          .font(.title3)
          .foregroundStyle(.white.opacity(0.72))
          .frame(maxWidth: 900, alignment: .leading)

        content()
          .padding(.top, 10)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(.top, 210)
      .padding(.horizontal, 82)
    }
  }
}
