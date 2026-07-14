import SwiftUI

struct CinematicBackgroundView: View {
    @State private var gradientDrift = false
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let videoName: String
    var focalColor: Color = VelyraTheme.primary
    var honoursAutoplayPreference = false

    var body: some View {
        ZStack {
            fallback

            if shouldPlayVideo,
               let url = videoURL {
                LoopingVideoView(url: url)
                    .blur(radius: reduceTransparency ? 0 : appState.preferences.backgroundBlurRadius)
                    .transition(.opacity)
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.16),
                    .black.opacity(reduceTransparency ? max(0.72, appState.preferences.backgroundOverlayOpacity) : appState.preferences.backgroundOverlayOpacity),
                    .black.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [.black.opacity(0.86), .clear, .black.opacity(0.38)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var shouldPlayVideo: Bool {
        appState.preferences.backgroundVideoEnabled
            && (!honoursAutoplayPreference || appState.preferences.autoplayPreviews)
            && !reduceMotion
    }

    private var videoURL: URL? {
        Bundle.main.url(forResource: videoName, withExtension: "mp4", subdirectory: "Media")
            ?? Bundle.main.url(forResource: videoName, withExtension: "mp4")
    }

    private var fallback: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [focalColor.opacity(0.32), Color.black.opacity(0.96)],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 1_200
            )
            .scaleEffect(gradientDrift && !reduceMotion ? 1.12 : 1.0)
            .offset(
                x: gradientDrift && !reduceMotion ? 70 : -40,
                y: gradientDrift && !reduceMotion ? 24 : -18
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 12).repeatForever(autoreverses: true),
                value: gradientDrift
            )
            .onAppear { gradientDrift = true }
        }
    }
}
