import SwiftUI

struct RemoteMediaArtwork: View {
    enum Aspect: Equatable {
        case landscape
        case poster

        var ratio: CGFloat {
            switch self {
            case .landscape: 16 / 9
            case .poster: 2 / 3
            }
        }
    }

    let url: URL?
    let title: String
    let aspect: Aspect

    var body: some View {
        GeometryReader { proxy in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .aspectRatio(aspect.ratio, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    VelyraTheme.primary.opacity(0.76),
                    Color(red: 0.16, green: 0.10, blue: 0.25),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(title.prefix(1).uppercased())
                .font(.system(size: aspect == .poster ? 72 : 58, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.32))
        }
    }
}
