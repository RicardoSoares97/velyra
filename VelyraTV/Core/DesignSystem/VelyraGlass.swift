import SwiftUI

private struct VelyraGlassModifier: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast

  let cornerRadius: CGFloat
  let tint: Color
  let interactive: Bool

  @ViewBuilder
  func body(content: Content) -> some View {
    if reduceTransparency {
      content
        .background(
          VelyraTheme.elevatedSurface(for: colorScheme),
          in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
              contrast == .increased
                ? Color.white.opacity(0.72) : VelyraTheme.border(for: colorScheme),
              lineWidth: contrast == .increased ? 2 : 1
            )
        }
    } else if #available(tvOS 26.0, *) {
      if interactive {
        content.glassEffect(
          .regular.tint(tint).interactive(),
          in: .rect(cornerRadius: cornerRadius)
        )
      } else {
        content.glassEffect(
          .regular.tint(tint),
          in: .rect(cornerRadius: cornerRadius)
        )
      }
    } else {
      content
        .background(
          .ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
              contrast == .increased ? Color.white.opacity(0.72) : Color.white.opacity(0.16),
              lineWidth: contrast == .increased ? 2 : 1
            )
        }
    }
  }
}

extension View {
  func velyraGlass(
    cornerRadius: CGFloat = 24,
    tint: Color = .clear,
    interactive: Bool = false
  ) -> some View {
    modifier(
      VelyraGlassModifier(
        cornerRadius: cornerRadius,
        tint: tint,
        interactive: interactive
      )
    )
  }
}

struct VelyraGlassButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.isFocused) private var isFocused
  var prominent = false

  func makeBody(configuration: Configuration) -> some View {
    let visualState = VelyraControlVisualState.resolve(
      isEnabled: isEnabled,
      isFocused: isFocused,
      isPressed: configuration.isPressed
    )

    configuration.label
      .font(.headline.weight(.semibold))
      .foregroundStyle(prominent ? VelyraTheme.onPrimary : Color.primary)
      .padding(.horizontal, 28)
      .frame(minHeight: 62)
      .background {
        if prominent {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(visualState == .pressed ? VelyraTheme.primaryPressed : VelyraTheme.primary)
        }
      }
      .velyraGlass(
        cornerRadius: 22,
        tint: prominent ? VelyraTheme.primary.opacity(0.36) : .clear,
        interactive: true
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(
            visualState.showsHighlight
              ? Color.white.opacity(contrast == .increased ? 0.95 : 0.72)
              : Color.clear,
            lineWidth: contrast == .increased ? 3 : 2
          )
      }
      .shadow(
        color: visualState.showsHighlight ? Color.black.opacity(0.46) : .clear,
        radius: visualState.showsHighlight ? 20 : 0,
        y: visualState.showsHighlight ? 10 : 0
      )
      .scaleEffect(visualState.scale(reduceMotion: reduceMotion))
      .opacity(visualState.opacity)
      .animation(
        reduceMotion ? nil : .easeOut(duration: 0.12),
        value: visualState
      )
  }
}
