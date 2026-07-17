import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stage: Stage = .welcome
  @StateObject private var media = OnboardingMediaViewModel()
  @FocusState private var focusedAction: Action?

  private let setup = AutomaticSetupService()

  private enum Stage: Equatable {
    case welcome
    case setup
  }

  private enum Action: Hashable {
    case `continue`
    case back
    case start
    case trakt
  }

  private struct MediaTaskID: Hashable {
    let language: String
    let region: String
  }

  private var summary: AutomaticSetupSummary {
    setup.summary()
  }

  private var mediaLanguage: String {
    appState.preferences.language.locale?.identifier ?? Locale.current.identifier
  }

  private var mediaRegion: String {
    appState.preferences.contentRegion ?? Locale.current.region?.identifier ?? "PT"
  }

  private var mediaTaskID: MediaTaskID {
    MediaTaskID(language: mediaLanguage, region: mediaRegion)
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ImmersiveOnboardingBackdropView(items: media.items)

        VStack(spacing: 0) {
          stageContent(in: proxy.size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          privacyFooter
        }
        .padding(.horizontal, max(76, proxy.size.width * 0.06))
        .padding(.vertical, 52)
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: stage)
    .onAppear { focusedAction = .continue }
    .onChange(of: stage) { _, newStage in
      focusedAction = newStage == .welcome ? .continue : .start
    }
    .task(id: mediaTaskID) {
      await media.load(language: mediaLanguage, region: mediaRegion)
    }
  }

  @ViewBuilder
  private func stageContent(in size: CGSize) -> some View {
    switch stage {
    case .welcome:
      welcomeStage(maxWidth: min(size.width * 0.56, 900))
        .transition(.opacity)
    case .setup:
      setupStage(maxWidth: min(size.width * 0.66, 1080))
        .transition(.opacity)
    }
  }

  private func welcomeStage(maxWidth: CGFloat) -> some View {
    VStack(spacing: 26) {
      VelyraBrandMark()
        .padding(.bottom, 6)

      Text("onboarding.immersive.eyebrow")
        .font(.headline.weight(.semibold))
        .foregroundStyle(VelyraTheme.primary)

      Text("onboarding.immersive.title")
        .font(.system(size: 68, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)

      Text("onboarding.immersive.body")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.78))
        .lineSpacing(8)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Button("onboarding.immersive.continue") {
        stage = .setup
      }
      .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      .focused($focusedAction, equals: .continue)
      .accessibilityHint(Text("onboarding.immersive.continue.hint"))
      .padding(.top, 10)
    }
    .frame(maxWidth: maxWidth)
    .accessibilityElement(children: .contain)
  }

  private func setupStage(maxWidth: CGFloat) -> some View {
    VStack(alignment: .leading, spacing: 28) {
      Text("onboarding.simple.eyebrow")
        .font(.headline.weight(.semibold))
        .foregroundStyle(VelyraTheme.primary)

      Text("onboarding.simple.title")
        .font(.system(size: 68, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)

      Text("onboarding.simple.body")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.78))
        .lineSpacing(8)
        .fixedSize(horizontal: false, vertical: true)

      automaticSetupSummary

      traktArea

      setupActions
    }
    .frame(maxWidth: maxWidth, alignment: .leading)
    .accessibilityElement(children: .contain)
  }

  private var setupActions: some View {
    HStack(spacing: 20) {
      Button("onboarding.simple.start") {
        appState.applyAutomaticSetupAndFinish()
      }
      .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      .focused($focusedAction, equals: .start)
      .accessibilityHint(Text("onboarding.simple.start.hint"))

      if appState.traktSession.state == .disconnected {
        Button("onboarding.simple.traktLater") {
          focusedAction = .start
          appState.traktSession.connect()
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .focused($focusedAction, equals: .trakt)
        .accessibilityHint(Text("onboarding.simple.traktLater.hint"))
      }

      Spacer(minLength: 24)

      Button("onboarding.immersive.back") {
        stage = .welcome
        focusedAction = .continue
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .focused($focusedAction, equals: .back)
      .accessibilityHint(Text("onboarding.immersive.back.hint"))
    }
    .padding(.top, 6)
  }

  private var automaticSetupSummary: some View {
    VStack(alignment: .leading, spacing: 16) {
      setupRow(
        symbol: "waveform",
        title: "onboarding.simple.audio",
        value: String(localized: "playback.audio.original")
      )
      setupRow(
        symbol: "captions.bubble.fill",
        title: "onboarding.simple.subtitles",
        value: summary.subtitleLanguageName
      )
      setupRow(
        symbol: "sparkles.tv.fill",
        title: "onboarding.simple.source",
        value: String(localized: "onboarding.simple.source.best")
      )
    }
    .padding(24)
    .velyraGlass(cornerRadius: 28)
    .accessibilityElement(children: .contain)
  }

  private func setupRow(
    symbol: String,
    title: LocalizedStringKey,
    value: String
  ) -> some View {
    HStack(spacing: 18) {
      Image(systemName: symbol)
        .frame(width: 34)
        .font(.title3)
        .foregroundStyle(VelyraTheme.primary)
        .accessibilityHidden(true)

      Text(title)
        .font(.headline)
        .foregroundStyle(.white)

      Spacer()

      Text(value)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.74))
        .multilineTextAlignment(.trailing)
    }
  }

  @ViewBuilder
  private var traktArea: some View {
    switch appState.traktSession.state {
    case .awaitingAuthorization(let code):
      HStack(spacing: 24) {
        VStack(alignment: .leading, spacing: 6) {
          Text("trakt.activate.title")
            .font(.headline)
            .foregroundStyle(.white)
          Text(code.verificationURL.absoluteString)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.68))
        }

        Spacer()

        Text(code.userCode)
          .font(.system(size: 36, weight: .bold, design: .monospaced))
          .tracking(5)
          .foregroundStyle(VelyraTheme.primary)
          .accessibilityLabel(Text("trakt.activate.code"))
          .accessibilityValue(code.userCode)
      }
      .padding(22)
      .velyraGlass(cornerRadius: 24)

    case .connected:
      Label("trakt.connected", systemImage: "checkmark.circle.fill")
        .font(.headline)
        .foregroundStyle(.white)

    case .requestingCode:
      HStack(spacing: 14) {
        ProgressView()
        Text("trakt.connecting")
      }
      .foregroundStyle(.white)

    case .failed:
      Label("trakt.error.generic", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.white)

    case .disconnected:
      EmptyView()
    }
  }

  private var privacyFooter: some View {
    HStack(spacing: 12) {
      Image(
        systemName: appState.distributionCapabilities.isSideload
          ? "internaldrive.fill"
          : (appState.iCloudAccount.status == .available ? "checkmark.icloud.fill" : "icloud")
      )
      .foregroundStyle(VelyraTheme.primary)
      .accessibilityHidden(true)

      Group {
        if appState.distributionCapabilities.isSideload {
          Text("onboarding.sideload.privacy")
        } else {
          Text("onboarding.simple.privacy")
        }
      }
      .font(.footnote)
      .foregroundStyle(.white.opacity(0.58))

      Spacer()

      if reduceMotion {
        Label("accessibility.reduceMotion.active", systemImage: "figure.walk.motion")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.58))
      }
    }
  }
}
