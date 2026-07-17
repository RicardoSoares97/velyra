import SwiftUI

struct HomeMediaCard: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var isFocused: Bool

  let item: MediaItem
  let style: HomeSectionStyle
  let action: () -> Void

  private var width: CGFloat {
    switch style {
    case .landscape: 360
    case .poster: 246
    case .topTen: 330
    }
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        artwork
        metadata
      }
      .frame(width: width, alignment: .leading)
      .scaleEffect(isFocused && !reduceMotion ? 1.055 : 1)
      .shadow(color: .black.opacity(isFocused ? 0.52 : 0.18), radius: isFocused ? 30 : 10, y: 15)
    }
    .buttonStyle(.plain)
    .focused($isFocused)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(item.title)
    .accessibilityValue(item.accessibilitySummary)
    .accessibilityHint(Text("media.openDetails.hint"))
    .contextMenu {
      Button(action: action) {
        Label("action.details", systemImage: "info.circle")
      }
    }
    .accessibilityAction(named: Text("action.details"), action)
    .accessibleMotion(value: isFocused)
  }

  private var artwork: some View {
    ZStack(alignment: .bottomLeading) {
      if style == .topTen {
        HStack(alignment: .bottom, spacing: -22) {
          Text(String(item.rank ?? 0))
            .font(.system(size: 152, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .shadow(color: .black.opacity(0.72), radius: 12, y: 8)
            .frame(width: 112, alignment: .trailing)
            .offset(x: 6, y: 16)

          RemoteMediaArtwork(url: item.posterURL, title: item.title, aspect: .poster)
            .frame(width: 205)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(width: width, height: 310, alignment: .bottomLeading)
      } else {
        RemoteMediaArtwork(
          url: style == .landscape ? (item.backdropURL ?? item.posterURL) : item.posterURL,
          title: item.title,
          aspect: style == .landscape ? .landscape : .poster
        )
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      }

      if let progress = item.progress, style == .landscape {
        GeometryReader { proxy in
          Capsule()
            .fill(VelyraTheme.primary)
            .frame(width: proxy.size.width * min(max(progress, 0), 1), height: 7)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width - 28, height: 7)
        .padding(14)
      }
    }
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(
          isFocused ? VelyraTheme.focusRing : .white.opacity(0.10), lineWidth: isFocused ? 4 : 1)
    }
  }

  private var metadata: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(item.title)
        .font(.headline)
        .foregroundStyle(.white)
        .lineLimit(1)

      HStack(spacing: 8) {
        if let subtitle = item.subtitle {
          Text(subtitle)
        } else if let year = item.releaseYear {
          Text(String(year))
        }

        if let rating = item.rating, rating > 0 {
          Label(String(format: "%.1f", rating), systemImage: "star.fill")
            .labelStyle(.titleAndIcon)
        }
      }
      .font(.subheadline)
      .foregroundStyle(.white.opacity(0.62))
      .lineLimit(1)
    }
  }
}
