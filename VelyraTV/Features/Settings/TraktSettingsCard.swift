import SwiftUI

struct TraktSettingsCard: View {
    @ObservedObject var session: TraktSession

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("settings.trakt", systemImage: "arrow.triangle.2.circlepath")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Divider().overlay(.white.opacity(0.16))

            switch session.state {
            case .disconnected:
                Text("settings.trakt.body")
                    .foregroundStyle(.white.opacity(0.65))
                Button("trakt.connect") { session.connect() }
                    .buttonStyle(VelyraGlassButtonStyle(prominent: true))

            case .requestingCode:
                HStack(spacing: 14) {
                    ProgressView()
                    Text("trakt.connecting")
                }
                .foregroundStyle(.white)

            case .awaitingAuthorization(let code):
                VStack(alignment: .leading, spacing: 12) {
                    Text("trakt.activate.title")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(code.verificationURL.absoluteString)
                        .foregroundStyle(.white.opacity(0.68))
                    Text(code.userCode)
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(VelyraTheme.primary)
                }

            case .connected:
                Label("trakt.connected", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Button("trakt.disconnect") {
                    Task { await session.disconnect() }
                }
                .buttonStyle(VelyraGlassButtonStyle())

            case .failed(let message):
                Text(message)
                    .foregroundStyle(.white)
                Button("action.retry") { session.connect() }
                    .buttonStyle(VelyraGlassButtonStyle(prominent: true))
            }
        }
        .padding(30)
        .velyraGlass(cornerRadius: 30)
    }
}
