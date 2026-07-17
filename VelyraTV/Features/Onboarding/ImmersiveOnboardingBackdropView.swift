import SwiftUI

struct ImmersiveOnboardingBackdropView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @State private var isDrifting = false

  let items: [OnboardingMediaItem]

  var body: some View {
    ZStack {
      Image("OnboardingFallback")
        .resizable()
        .scaledToFill()

      if let item = items.first {
        CachedRemoteImage(
          url: item.backdropURL,
          targetSize: CGSize(width: 1920, height: 1080),
          contentMode: .fill
        ) {
          Color.clear
        }
        .scaleEffect(reduceMotion ? 1 : (isDrifting ? 1.07 : 1.025))
        .contentTransition(.opacity)
      }

      Color.black.opacity(reduceTransparency ? 0.52 : 0.28)

      RadialGradient(
        colors: [
          Color.black.opacity(reduceTransparency ? 0.78 : 0.66),
          Color.black.opacity(0.18),
        ],
        center: .center,
        startRadius: 80,
        endRadius: 820
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { updateMotion() }
    .onChange(of: reduceMotion) { _, _ in updateMotion() }
  }

  private func updateMotion() {
    guard !reduceMotion else {
      withAnimation(nil) { isDrifting = false }
      return
    }
    withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
      isDrifting = true
    }
  }
}
