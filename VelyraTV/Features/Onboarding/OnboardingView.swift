import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @FocusState private var focusedAction: Action?

  private let setup = AutomaticSetupService()

  private enum Action: Hashable {
    case start
    case trakt
  }

  private var summary: AutomaticSetupSummary {
    setup.summary()
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        CinematicBackgroundView(
          videoName: "onboarding-welcome",
          focalColor: VelyraTheme.primary
        )

        VStack(alignment: .leading, spacing: 0) {
          brandHeader
          Spacer(minLength: 44)
          introduction(maxWidth: min(proxy.size.width * 0.62, 1040))
          Spacer(minLength: 44)
          privacyFooter
        }
        .padding(.horizontal, max(76, proxy.size.width * 0.06))
        .padding(.vertical, 52)
      }
    }
    .onAppear { focusedAction = .start }
  }

  private var brandHeader: some View {
    HStack {
      Text("VELYRA")
        .font(.system(size: 32, weight: .black, design: .rounded))
        .tracking(5)
        .foregroundStyle(.white)
        .accessibilityLabel("Velyra")

      Spacer()

      Text("brand.madeInPortugal")
        .font(.footnote.weight(.medium))
        .foregroundStyle(.white.opacity(0.62))
    }
  }

  private func introduction(maxWidth: CGFloat) -> some View {
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

      HStack(spacing: 20) {
        Button("onboarding.simple.start") {
          appState.applyAutomaticSetupAndFinish()
        }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        .focused($focusedAction, equals: .start)
        .accessibilityHint(Text("onboarding.simple.start.hint"))

        if appState.traktSession.state == .disconnected {
          Button("onboarding.simple.traktLater") {
            appState.traktSession.connect()
          }
          .buttonStyle(VelyraGlassButtonStyle())
          .focused($focusedAction, equals: .trakt)
          .accessibilityHint(Text("onboarding.simple.traktLater.hint"))
        }
      }
      .padding(.top, 6)
    }
    .frame(maxWidth: maxWidth, alignment: .leading)
    .accessibilityElement(children: .contain)
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
        systemName: appState.iCloudAccount.status == .available ? "checkmark.icloud.fill" : "icloud"
      )
      .foregroundStyle(VelyraTheme.primary)
      .accessibilityHidden(true)

      Text("onboarding.simple.privacy")
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
