import SwiftUI

struct HomeSectionView: View {
  let section: HomeSection
  let onSelect: (MediaItem) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text(section.title)
          .font(.title2.bold())
          .foregroundStyle(.white)

        if let subtitle = section.subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.58))
        }
      }
      .accessibilityElement(children: .combine)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: section.style == .topTen ? 12 : 26) {
          ForEach(section.items) { item in
            HomeMediaCard(item: item, style: section.style) {
              onSelect(item)
            }
          }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 5)
      }
    }
  }
}
