import SwiftUI

struct RibbonStrikeView: View {
  let presentation: LaunchIdentPresentation
  let completion: () -> Void

  @State private var strikeProgress: CGFloat = 0
  @State private var ribbonProgress: CGFloat = 0
  @State private var brandOpacity = 0.0
  @State private var didComplete = false

  var body: some View {
    ZStack {
      Color.black

      if presentation == .ribbonStrike {
        Rectangle()
          .fill(
            LinearGradient(
              colors: [.clear, VelyraTheme.primary, .white, VelyraTheme.primary, .clear],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 5, height: 580 * strikeProgress)
          .shadow(color: VelyraTheme.primary.opacity(0.82), radius: 34)

        RibbonStrikeShape(progress: ribbonProgress)
          .stroke(
            LinearGradient(
              colors: [.white, VelyraTheme.primary, VelyraTheme.primaryPressed],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round)
          )
          .frame(width: 170, height: 220)
          .shadow(color: VelyraTheme.primary.opacity(0.62), radius: 28)
      }

      VelyraBrandMark()
        .opacity(brandOpacity)
    }
    .ignoresSafeArea()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("app.loading"))
    .task { await play() }
    .onDisappear { finish() }
  }

  @MainActor
  private func play() async {
    switch presentation {
    case .fade:
      withAnimation(.easeOut(duration: 0.3)) {
        brandOpacity = 1
      }
      try? await Task.sleep(for: .milliseconds(650))

    case .ribbonStrike:
      withAnimation(.easeOut(duration: 0.32)) {
        strikeProgress = 1
      }
      try? await Task.sleep(for: .milliseconds(260))
      withAnimation(.easeInOut(duration: 0.48)) {
        ribbonProgress = 1
        strikeProgress = 0
      }
      try? await Task.sleep(for: .milliseconds(380))
      withAnimation(.easeOut(duration: 0.28)) {
        brandOpacity = 1
      }
      try? await Task.sleep(for: .milliseconds(520))
    }

    finish()
  }

  @MainActor
  private func finish() {
    guard !didComplete else { return }
    didComplete = true
    completion()
  }
}

private struct RibbonStrikeShape: Shape {
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY))
    return path.trimmedPath(from: 0, to: progress)
  }
}
