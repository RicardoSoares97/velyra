import SwiftUI

struct CinematicHeroView: View {
    let item: MediaItem
    let onPlay: () -> Void
    let onDetails: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: item.backdropURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [VelyraTheme.primary.opacity(0.46), Color.indigo.opacity(0.34), .black],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
            }
            .frame(height: 720)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.black.opacity(0.92), .black.opacity(0.32), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 19) {
                Text("home.featured.eyebrow")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelyraTheme.primary)

                Text(item.title.uppercased())
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(3)
                        .frame(maxWidth: 760, alignment: .leading)
                }

                HStack(spacing: 18) {
                    Button(action: onPlay) {
                        Label("action.play", systemImage: "play.fill")
                    }
                    .buttonStyle(VelyraGlassButtonStyle(prominent: true))

                    Button(action: onDetails) {
                        Label("action.details", systemImage: "info.circle")
                    }
                    .buttonStyle(VelyraGlassButtonStyle())
                }
            }
            .padding(.horizontal, 72)
            .padding(.bottom, 76)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(height: 720)
        .accessibilityElement(children: .contain)
    }
}
