import SwiftUI

struct SettingsCategoryTile: View {
  let category: SettingsCategory

  var body: some View {
    NavigationLink(value: category) {
      HStack(spacing: 24) {
        Image(systemName: category.systemImage)
          .font(.system(size: 34, weight: .semibold))
          .foregroundStyle(VelyraTheme.primary)
          .frame(width: 58, height: 58)
          .background(VelyraTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

        VStack(alignment: .leading, spacing: 8) {
          Text(LocalizedStringKey(category.titleKey))
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)

          Text(LocalizedStringKey(category.summaryKey))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Image(systemName: "chevron.right")
          .font(.headline.weight(.bold))
          .foregroundStyle(.white.opacity(0.34))
      }
      .padding(.horizontal, 26)
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
      .background(
        Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.92),
        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .stroke(.white.opacity(0.1), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}
