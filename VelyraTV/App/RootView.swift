import SwiftUI

struct RootView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var identPolicy = LaunchIdentPolicy()
  @State private var identPresentation: LaunchIdentPresentation?
  @State private var didPrepareIdent = false

  var body: some View {
    ZStack {
      if !didPrepareIdent {
        Color.black.ignoresSafeArea()
      } else if let identPresentation {
        RibbonStrikeView(presentation: identPresentation) {
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            self.identPresentation = nil
          }
        }
        .transition(.opacity)
      } else {
        rootContent
      }
    }
    .preferredColorScheme(preferredColorScheme)
    .environment(\.locale, selectedLocale)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 0.35),
      value: appState.preferences.hasCompletedOnboarding
    )
    .onAppear {
      guard !didPrepareIdent else { return }
      identPresentation = identPolicy.consumePresentation(reduceMotion: reduceMotion)
      didPrepareIdent = true
    }
  }

  @ViewBuilder
  private var rootContent: some View {
    if !appState.isReady {
      LaunchExperienceView()
    } else if !appState.preferences.hasCompletedOnboarding {
      OnboardingView()
    } else {
      AppShellView()
    }
  }

  private var preferredColorScheme: ColorScheme? {
    switch appState.preferences.theme {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  private var selectedLocale: Locale {
    appState.preferences.language.locale ?? .current
  }
}

private struct LaunchExperienceView: View {
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ProgressView()
        .tint(VelyraTheme.primary)
        .accessibilityLabel(Text("app.loading"))
    }
  }
}
