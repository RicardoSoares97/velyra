import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0
    @FocusState private var focusedAction: Action?

    private enum Action: Hashable {
        case primary
        case secondary
    }

    private var step: OnboardingStep { OnboardingStep.all[currentIndex] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CinematicBackgroundView(videoName: step.videoName)
                    .id(step.id)
                    .transition(.opacity)

                VStack(alignment: .leading, spacing: 0) {
                    brandHeader
                    Spacer(minLength: 40)
                    content(maxWidth: min(proxy.size.width * 0.58, 980))
                    Spacer(minLength: 40)
                    footer
                }
                .padding(.horizontal, max(72, proxy.size.width * 0.055))
                .padding(.vertical, 50)
            }
        }
        .onAppear { focusedAction = .primary }
        .onChange(of: currentIndex) { _, _ in
            focusedAction = .primary
        }
        .accessibleMotion(value: currentIndex)
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

    private func content(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 26) {
            Label {
                Text(LocalizedStringKey(step.eyebrowKey))
            } icon: {
                Image(systemName: step.symbol)
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(VelyraTheme.primary)

            Text(LocalizedStringKey(step.titleKey))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(step.bodyKey))
                .font(.title3)
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)

            if step.id == "icloud" {
                iCloudStatus
            }

            if step.id == "trakt" {
                traktStatus
            }

            actions
                .padding(.top, 14)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .id(step.id)
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                )
        )
        .accessibilityElement(children: .contain)
    }

    private var iCloudStatus: some View {
        HStack(spacing: 16) {
            Image(systemName: appState.iCloudAccount.status == .available ? "checkmark.icloud.fill" : "icloud.slash")
                .font(.title2)
                .foregroundStyle(appState.iCloudAccount.status == .available ? VelyraTheme.primary : .white.opacity(0.7))

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(appState.iCloudAccount.status.localizedKey))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("icloud.privacy.explanation")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
        .padding(20)
        .velyraGlass(cornerRadius: 22)
    }

    @ViewBuilder
    private var traktStatus: some View {
        switch appState.traktSession.state {
        case .awaitingAuthorization(let code):
            VStack(alignment: .leading, spacing: 12) {
                Text("trakt.activate.title")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(code.verificationURL.absoluteString)
                    .foregroundStyle(.white.opacity(0.72))
                Text(code.userCode)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(VelyraTheme.primary)
                    .accessibilityLabel(Text("trakt.activate.code"))
                    .accessibilityValue(code.userCode)
            }
            .padding(22)
            .velyraGlass(cornerRadius: 22)
        case .connected:
            Label("trakt.connected", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(20)
                .velyraGlass(cornerRadius: 22, tint: VelyraTheme.primary.opacity(0.15))
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

    private var actions: some View {
        HStack(spacing: 20) {
            Button(primaryTitle) { advance() }
                .buttonStyle(VelyraGlassButtonStyle(prominent: true))
                .focused($focusedAction, equals: .primary)
                .accessibilityHint(Text(primaryHint))

            if step.id == "trakt", appState.traktSession.state == .disconnected {
                Button("trakt.connect") {
                    appState.traktSession.connect()
                }
                .buttonStyle(VelyraGlassButtonStyle())
                .focused($focusedAction, equals: .secondary)
            } else if currentIndex > 0 && currentIndex < OnboardingStep.all.count - 1 {
                Button("action.back") { goBack() }
                    .buttonStyle(VelyraGlassButtonStyle())
                    .focused($focusedAction, equals: .secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            ForEach(OnboardingStep.all.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? VelyraTheme.primary : Color.white.opacity(0.28))
                    .frame(width: index == currentIndex ? 34 : 10, height: 8)
                    .accessibilityHidden(true)
            }

            Spacer()

            Text("onboarding.progress \(currentIndex + 1) \(OnboardingStep.all.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
                .accessibilityLabel(Text("onboarding.progress.accessibility \(currentIndex + 1) \(OnboardingStep.all.count)"))
        }
    }

    private var primaryTitle: LocalizedStringKey {
        currentIndex == OnboardingStep.all.count - 1 ? "action.enterVelyra" : "action.continue"
    }

    private var primaryHint: LocalizedStringKey {
        currentIndex == OnboardingStep.all.count - 1 ? "action.enterVelyra.hint" : "action.continue.hint"
    }

    private func advance() {
        if currentIndex == OnboardingStep.all.count - 1 {
            appState.finishOnboarding()
        } else {
            withAnimation { currentIndex += 1 }
        }
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        withAnimation { currentIndex -= 1 }
    }
}
