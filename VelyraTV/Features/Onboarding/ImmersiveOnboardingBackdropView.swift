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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

      if reduceMotion {
        if let item = items.first {
          remoteImage(for: item)
        }
      } else {
        if let item = items.first {
          movingImage(for: item, side: .left)
        }

        if items.count > 1 {
          movingImage(for: items[1], side: .right)
        }
      }

      centerQuietingOverlay
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { updateMotion(reduceMotion: reduceMotion) }
    .onChange(of: reduceMotion) { _, newValue in
      updateMotion(reduceMotion: newValue)
    }
  }

  private enum Side: Equatable {
    case left
    case right
  }

  private func remoteImage(for item: OnboardingMediaItem) -> some View {
    CachedRemoteImage(
      url: item.backdropURL,
      targetSize: CGSize(width: 1920, height: 1080),
      contentMode: .fill
    ) {
      Color.clear
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .contentTransition(.opacity)
    .transaction { transaction in
      transaction.animation = reduceMotion ? nil : .easeOut(duration: 1.2)
    }
  }

  private func movingImage(for item: OnboardingMediaItem, side: Side) -> some View {
    remoteImage(for: item)
      .scaleEffect(scale(for: side))
      .offset(x: horizontalOffset(for: side))
      .mask(side == .left ? leftMask : rightMask)
  }

  private func scale(for side: Side) -> CGFloat {
    switch side {
    case .left:
      isDrifting ? 1.08 : 1.03
    case .right:
      isDrifting ? 1.03 : 1.08
    }
  }

  private func horizontalOffset(for side: Side) -> CGFloat {
    switch side {
    case .left:
      isDrifting ? -24 : 18
    case .right:
      isDrifting ? 20 : -28
    }
  }

  private var leftMask: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: .white, location: 0),
        .init(color: .white.opacity(0.88), location: 0.28),
        .init(color: .clear, location: 0.64),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  private var rightMask: LinearGradient {
    LinearGradient(
      stops: [
        .init(color: .clear, location: 0.36),
        .init(color: .white.opacity(0.88), location: 0.72),
        .init(color: .white, location: 1),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  private var centerQuietingOverlay: LinearGradient {
    let centerOpacity = reduceTransparency ? 0.82 : 0.68

    return LinearGradient(
      stops: [
        .init(color: .clear, location: 0),
        .init(color: .black.opacity(0.2), location: 0.28),
        .init(color: .black.opacity(centerOpacity), location: 0.5),
        .init(color: .black.opacity(0.2), location: 0.72),
        .init(color: .clear, location: 1),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  private func updateMotion(reduceMotion: Bool) {
    guard !reduceMotion else {
      withAnimation(nil) { isDrifting = false }
      return
    }

    withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
      isDrifting = true
    }
  }
}
