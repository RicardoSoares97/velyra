import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var media = OnboardingMediaViewModel()
  @FocusState private var isStartFocused: Bool

  private struct MediaTaskID: Hashable {
    let language: String
    let region: String
  }

  private var mediaLanguage: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  private var mediaRegion: String {
    appState.preferences.contentRegion ?? Locale.current.region?.identifier ?? "PT"
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ImmersiveOnboardingBackdropView(items: media.items)

        VStack(spacing: 26) {
          VelyraBrandMark()
            .padding(.bottom, 4)

          Text("onboarding.simple.eyebrow")
            .font(.headline.weight(.semibold))
            .foregroundStyle(VelyraTheme.primary)

          Text("onboarding.simple.title")
            .font(.system(size: 66, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

          Text("onboarding.simple.body")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.78))
            .lineSpacing(7)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

          assuranceLabels

          Button("onboarding.simple.start") {
            appState.applyAutomaticSetupAndFinish()
          }
          .buttonStyle(VelyraGlassButtonStyle(prominent: true))
          .focused($isStartFocused)
          .accessibilityHint(Text("onboarding.simple.start.hint"))
          .padding(.top, 8)

          privacyLine
        }
        .frame(maxWidth: min(proxy.size.width * 0.66, 1_020))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 76)
        .padding(.vertical, 50)
      }
    }
    .onAppear { isStartFocused = true }
    .task(
      id: MediaTaskID(
        language: mediaLanguage,
        region: mediaRegion
      )
    ) {
      await media.load(language: mediaLanguage, region: mediaRegion)
    }
  }

  private var assuranceLabels: some View {
    HStack(spacing: 18) {
      assurance(
        symbol: "sparkles.tv.fill",
        title: "onboarding.simple.source"
      )
      assurance(
        symbol: "waveform",
        title: "onboarding.simple.audio"
      )
      assurance(
        symbol: "captions.bubble.fill",
        title: "onboarding.simple.subtitles"
      )
    }
    .padding(.top, 4)
  }

  private func assurance(symbol: String, title: LocalizedStringKey) -> some View {
    Label(title, systemImage: symbol)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.white.opacity(0.84))
      .padding(.horizontal, 18)
      .frame(minHeight: 48)
      .background(.black.opacity(0.38), in: Capsule())
      .overlay {
        Capsule().stroke(.white.opacity(0.12), lineWidth: 1)
      }
  }

  private var privacyLine: some View {
    Label(
      appState.distributionCapabilities.isSideload
        ? "onboarding.sideload.privacy"
        : "onboarding.simple.privacy",
      systemImage: appState.distributionCapabilities.isSideload
        ? "internaldrive.fill"
        : "lock.shield.fill"
    )
    .font(.footnote)
    .foregroundStyle(.white.opacity(0.58))
    .padding(.top, 2)
  }
}
