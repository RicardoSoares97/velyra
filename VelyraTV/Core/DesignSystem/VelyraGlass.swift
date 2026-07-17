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
  var prominent = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline.weight(.semibold))
      .foregroundStyle(prominent ? VelyraTheme.onPrimary : Color.primary)
      .padding(.horizontal, 28)
      .frame(minHeight: 62)
      .background {
        if prominent {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(configuration.isPressed ? VelyraTheme.primaryPressed : VelyraTheme.primary)
        }
      }
      .velyraGlass(
        cornerRadius: 22,
        tint: prominent ? VelyraTheme.primary.opacity(0.36) : .clear,
        interactive: true
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
