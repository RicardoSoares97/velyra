import SwiftUI

struct RootView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if !appState.isReady {
        LaunchExperienceView()
      } else if !appState.preferences.hasCompletedOnboarding {
        OnboardingView()
      } else {
        AppShellView()
      }
    }
    .preferredColorScheme(preferredColorScheme)
    .environment(\.locale, selectedLocale)
    .animation(
      reduceMotion ? nil : .easeInOut(duration: 0.35),
      value: appState.preferences.hasCompletedOnboarding
    )
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
      VStack(spacing: 18) {
        Text("VELYRA")
          .font(.system(size: 58, weight: .black, design: .rounded))
          .tracking(7)
          .foregroundStyle(VelyraTheme.primary)
        ProgressView()
          .tint(.white)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(Text("app.loading"))
    }
  }
}
