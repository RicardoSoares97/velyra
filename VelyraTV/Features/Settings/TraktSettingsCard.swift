import CoreImage.CIFilterBuiltins
import SwiftUI

struct TraktSettingsCard: View {
  @ObservedObject var session: TraktSession
  let repository: TraktLibraryRepository

  @Environment(\.openURL) private var openURL
  @State private var pendingCount = 0
  @State private var failedCount = 0
  @State private var isSynchronising = false
  @State private var syncMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack {
        Label("settings.trakt", systemImage: "arrow.triangle.2.circlepath")
          .font(.title2.bold())
          .foregroundStyle(.white)
        Spacer()
        if pendingCount > 0 {
          Label(
            "\(pendingCount)",
            systemImage: failedCount > 0 ? "exclamationmark.icloud.fill" : "icloud.and.arrow.up"
          )
            .font(.subheadline.bold())
            .foregroundStyle(VelyraTheme.primary)
            .accessibilityLabel(
              Text(String(format: String(localized: "library.pendingChanges"), pendingCount))
            )
        }
      }

      Divider().overlay(.white.opacity(0.16))

      switch session.state {
      case .disconnected:
        disconnected
      case .requestingCode:
        requestingCode
      case .awaitingAuthorization(let code):
        authorization(code)
      case .connected:
        connected
      case .failed(let message):
        failed(message)
      }
    }
    .padding(30)
    .velyraGlass(cornerRadius: 30)
    .task(id: stateID) {
      pendingCount = await repository.pendingMutationCount()
      failedCount = await repository.failedMutationCount()
    }
  }

  private var stateID: String {
    switch session.state {
    case .disconnected: "disconnected"
    case .requestingCode: "requesting"
    case .awaitingAuthorization(let code): "awaiting:\(code.userCode)"
    case .connected: "connected:\(pendingCount)"
    case .failed(let message): "failed:\(message)"
    }
  }

  private var disconnected: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("settings.trakt.body")
        .foregroundStyle(.white.opacity(0.65))
      if !session.isConfigured {
        Label("trakt.configurationRequired", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(VelyraTheme.primary)
      }
      Button("trakt.connect") { session.connect() }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        .disabled(!session.isConfigured)
    }
  }

  private var requestingCode: some View {
    HStack(spacing: 14) {
      ProgressView()
      Text("trakt.connecting")
      Spacer()
      Button("action.cancel") { session.cancelConnection() }
        .buttonStyle(VelyraGlassButtonStyle())
    }
    .foregroundStyle(.white)
  }

  private func authorization(_ code: TraktDeviceCode) -> some View {
    HStack(alignment: .center, spacing: 32) {
      if let image = QRCodeGenerator.image(for: code.verificationURL) {
        Image(uiImage: image)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .frame(width: 190, height: 190)
          .padding(14)
          .background(.white, in: RoundedRectangle(cornerRadius: 18))
          .accessibilityHidden(true)
      }

      VStack(alignment: .leading, spacing: 13) {
        Text("trakt.activate.title")
          .font(.headline)
          .foregroundStyle(.white)
        Text("trakt.activate.body")
          .foregroundStyle(.white.opacity(0.66))
        Text(code.verificationURL.absoluteString)
          .font(.subheadline.monospaced())
          .foregroundStyle(.white.opacity(0.72))
        Text(code.userCode)
          .font(.system(size: 42, weight: .bold, design: .monospaced))
          .tracking(7)
          .foregroundStyle(VelyraTheme.primary)
          .accessibilityLabel(Text("trakt.activationCode"))
          .accessibilityValue(code.userCode)

        HStack(spacing: 14) {
          Button("trakt.openActivation") { openURL(code.verificationURL) }
            .buttonStyle(VelyraGlassButtonStyle(prominent: true))
          Button("action.cancel") { session.cancelConnection() }
            .buttonStyle(VelyraGlassButtonStyle())
        }
      }
    }
  }

  private var connected: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.title)
          .foregroundStyle(.green)
        VStack(alignment: .leading, spacing: 4) {
          Text(session.profile?.displayName ?? String(localized: "trakt.connected"))
            .font(.headline)
            .foregroundStyle(.white)
          Text(
            session.profile.map { "@\($0.username)" } ?? String(localized: "trakt.connected.body")
          )
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
        }
        Spacer()
        if session.profile?.isVIP == true {
          Label("VIP", systemImage: "star.fill")
            .font(.caption.bold())
            .foregroundStyle(VelyraTheme.primary)
        }
      }

      if let syncMessage {
        Label(syncMessage, systemImage: "checkmark.icloud")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.66))
      }

      if failedCount > 0 {
        Label(
          String(format: String(localized: "trakt.failedChanges"), failedCount),
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.subheadline)
        .foregroundStyle(.yellow)
      }

      HStack(spacing: 14) {
        Button {
          Task { await synchronise() }
        } label: {
          if isSynchronising {
            ProgressView().controlSize(.small)
          } else {
            Label("trakt.syncNow", systemImage: "arrow.clockwise")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle(prominent: pendingCount > 0))
        .disabled(isSynchronising)

        Button("trakt.disconnect", role: .destructive) {
          Task {
            await session.disconnect()
            pendingCount = 0
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
      }
    }
  }

  private func failed(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.white)
      HStack(spacing: 14) {
        Button("action.retry") { session.connect() }
          .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        Button("action.cancel") { session.cancelConnection() }
          .buttonStyle(VelyraGlassButtonStyle())
      }
    }
  }

  private func synchronise() async {
    isSynchronising = true
    syncMessage = nil
    defer { isSynchronising = false }
    do {
      _ = try await repository.refresh(force: true)
      pendingCount = await repository.pendingMutationCount()
      failedCount = await repository.failedMutationCount()
      syncMessage = String(localized: "trakt.syncComplete")
    } catch {
      syncMessage = error.localizedDescription
    }
  }
}

private enum QRCodeGenerator {
  static func image(for url: URL) -> UIImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(url.absoluteString.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
      let cgImage = context.createCGImage(output, from: output.extent)
    else { return nil }
    return UIImage(cgImage: cgImage)
  }
}
