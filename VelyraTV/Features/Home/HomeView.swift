import SwiftUI

struct HomeView: View {
    private let continueWatching = [
        MediaCardModel(title: "The Last Horizon", subtitle: "S1 · E4", progress: 0.62),
        MediaCardModel(title: "Afterlight", subtitle: "42 min remaining", progress: 0.34),
        MediaCardModel(title: "Northbound", subtitle: "S2 · E1", progress: 0.18)
    ]

    private let watchlist = [
        MediaCardModel(title: "Silent Orbit", subtitle: "2026", progress: nil),
        MediaCardModel(title: "The Glass House", subtitle: "Limited series", progress: nil),
        MediaCardModel(title: "Echoes", subtitle: "New episode", progress: nil),
        MediaCardModel(title: "Wild Coast", subtitle: "Documentary", progress: nil)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            CinematicBackgroundView(videoName: "home-featured", focalColor: .indigo, honoursAutoplayPreference: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 54) {
                    hero
                    MediaRow(titleKey: "home.continueWatching", items: continueWatching)
                    MediaRow(titleKey: "home.watchlist", items: watchlist)
                    MediaRow(titleKey: "home.discover", items: watchlist.reversed())
                }
                .padding(.top, 170)
                .padding(.horizontal, 72)
                .padding(.bottom, 90)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("home.featured.eyebrow")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelyraTheme.primary)

            Text("AURORA")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white)

            Text("home.featured.description")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
                .frame(maxWidth: 760, alignment: .leading)

            HStack(spacing: 18) {
                Button {
                } label: {
                    Label("action.play", systemImage: "play.fill")
                }
                .buttonStyle(VelyraGlassButtonStyle(prominent: true))

                Button {
                } label: {
                    Label("action.details", systemImage: "info.circle")
                }
                .buttonStyle(VelyraGlassButtonStyle())
            }
        }
        .padding(.top, 76)
        .accessibilityElement(children: .contain)
    }
}

private struct MediaRow<Items: RandomAccessCollection>: View where Items.Element == MediaCardModel {
    let titleKey: String
    let items: Items

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(LocalizedStringKey(titleKey))
                .font(.title2.bold())
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 26) {
                    ForEach(Array(items)) { item in
                        MediaCard(model: item)
                    }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 4)
            }
        }
    }
}
