import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let samples = [
        ("Continue watching", "Resume where you stopped"),
        ("Your watchlist", "Synced with Trakt"),
        ("Discover", "Catalogues from your addons"),
        ("Recently added", "New titles from your sources")
    ]

    var body: some View {
        ZStack {
            VelyraTheme.background(for: colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    header

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Start watching")
                            .font(.title2.bold())
                            .foregroundStyle(VelyraTheme.textPrimary(for: colorScheme))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 26) {
                                ForEach(Array(samples.enumerated()), id: \.offset) { _, item in
                                    MediaCard(title: item.0, subtitle: item.1)
                                }
                            }
                            .padding(.vertical, 24)
                        }
                    }
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 48)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("VELYRA")
                    .font(.system(size: 50, weight: .black, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(VelyraTheme.primary)

                Text("Your media. Beautifully focused.")
                    .font(.title3)
                    .foregroundStyle(VelyraTheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button("Connect Trakt") {}
                .buttonStyle(VelyraPrimaryButtonStyle())
        }
    }
}

#Preview {
    HomeView()
}
