import SwiftUI
import UIKit

struct AddonsView: View {
  @EnvironmentObject private var appState: AppState
  @StateObject private var viewModel = AddonViewModel()
  @State private var manifestURL = ""
  @State private var showsTransfer = false
  @State private var transferCode = ""
  @State private var transferMessage: String?
  @State private var showsRemoveAllConfirmation = false
  @State private var showsStremioImport = false

  var body: some View {
    VelyraPlaceholderScreen(
      titleKey: "addons.title",
      bodyKey: "addons.body",
      systemImage: "puzzlepiece.extension.fill",
      accent: VelyraTheme.primary
    ) {
      VStack(alignment: .leading, spacing: 22) {
        installRow
        status
        if !viewModel.entries.isEmpty { installedList }
      }
      .frame(maxWidth: 1_180, alignment: .leading)
      .task {
        await viewModel.restore(
          urlStrings: appState.preferences.addonManifestURLs,
          disabled: appState.preferences.disabledAddonManifestURLs,
          priority: appState.preferences.addonPriority
        )
      }
    }
    .sheet(isPresented: $showsTransfer) {
      AddonTransferSheet(
        code: $transferCode,
        message: transferMessage,
        onImport: importConfiguration,
        onClose: { showsTransfer = false }
      )
    }
    .fullScreenCover(isPresented: $showsStremioImport) {
      StremioImportView(
        existingURLs: appState.preferences.addonManifestURLs,
        onImport: importStremioAddons,
        onClose: { showsStremioImport = false }
      )
      .environmentObject(appState)
    }
    .confirmationDialog(
      "addons.removeAll.title",
      isPresented: $showsRemoveAllConfirmation,
      titleVisibility: .visible
    ) {
      Button("addons.removeAll", role: .destructive) {
        viewModel.removeAll()
        appState.resetAddonPreferences()
      }
      Button("action.cancel", role: .cancel) {}
    } message: {
      Text("addons.removeAll.body")
    }
    .onChange(of: viewModel.state) { _, state in
      switch state {
      case .success(let name):
        postQueuedAccessibilityAnnouncement(
          name + " · " + String(localized: "addons.added")
        )
      case .failed(let message):
        postQueuedAccessibilityAnnouncement(message)
      case .idle, .loading:
        break
      }
    }
  }

  private var installRow: some View {
    HStack(spacing: 16) {
      TextField("addons.url.placeholder", text: $manifestURL)
        .textFieldStyle(.plain)
        .font(.title3)
        .textContentType(.URL)
        .padding(20)
        .velyraGlass(cornerRadius: 22, interactive: true)

      Button("addons.add") { Task { await install() } }
        .buttonStyle(VelyraGlassButtonStyle(prominent: true))
        .disabled(manifestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

      Button {
        Task { await viewModel.refreshAll() }
      } label: {
        Label("addons.refreshAll", systemImage: "arrow.clockwise")
      }
      .buttonStyle(VelyraGlassButtonStyle())

      Button {
        presentTransfer()
      } label: {
        Label("addons.transfer", systemImage: "square.and.arrow.up.on.square")
      }
      .buttonStyle(VelyraGlassButtonStyle())

      Button {
        showsStremioImport = true
      } label: {
        Label("stremio.import.action", systemImage: "arrow.down.circle")
      }
      .buttonStyle(VelyraGlassButtonStyle())

      if !viewModel.entries.isEmpty {
        Button(role: .destructive) {
          showsRemoveAllConfirmation = true
        } label: {
          Label("addons.removeAll", systemImage: "trash")
        }
        .buttonStyle(VelyraGlassButtonStyle())
      }
    }
  }

  @ViewBuilder
  private var status: some View {
    switch viewModel.state {
    case .idle: EmptyView()
    case .loading:
      HStack(spacing: 12) {
        ProgressView()
        Text("addons.validating")
      }
      .foregroundStyle(.white)
    case .success(let name):
      Label(name + " · " + String(localized: "addons.added"), systemImage: "checkmark.circle.fill")
        .foregroundStyle(.white)
    case .failed(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.white)
    }
  }

  private var installedList: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("addons.installed").font(.headline).foregroundStyle(.white)
      ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
        addonRow(entry, index: index)
      }
    }
  }

  private func addonRow(_ entry: AddonViewModel.Entry, index: Int) -> some View {
    HStack(spacing: 18) {
      Image(
        systemName: entry.errorMessage == nil
          ? "puzzlepiece.extension.fill" : "exclamationmark.triangle.fill"
      )
      .foregroundStyle(entry.errorMessage == nil ? VelyraTheme.primary : .yellow)
      .frame(width: 38)

      VStack(alignment: .leading, spacing: 5) {
        Text(entry.manifest?.name ?? entry.url.host ?? entry.url.absoluteString)
          .font(.headline).foregroundStyle(.white)
        Text(entry.manifest.map(capabilitySummary) ?? entry.url.absoluteString)
          .font(.caption).foregroundStyle(.white.opacity(0.56)).lineLimit(2)
        if let health = entry.health {
          Label(
            addonHealthDescription(health),
            systemImage: addonHealthSystemImage(health.state)
          )
          .font(.caption)
          .foregroundStyle(addonHealthColor(health.state))
        }
        if let error = entry.errorMessage {
          Text(error).font(.caption).foregroundStyle(.yellow).lineLimit(1)
        }
      }

      Spacer()

      Toggle(
        "addons.enabled",
        isOn: Binding(
          get: { entry.enabled },
          set: { value in
            viewModel.setEnabled(value, url: entry.url)
            persistConfiguration()
          }
        )
      )
      .labelsHidden()
      .tint(VelyraTheme.primary)
      .accessibilityLabel(Text("addons.enabled"))

      Button {
        viewModel.move(url: entry.url, offset: -1)
        persistConfiguration()
      } label: {
        Image(systemName: "arrow.up")
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .disabled(index == 0)
      .accessibilityLabel(Text("addons.moveUp"))

      Button {
        viewModel.move(url: entry.url, offset: 1)
        persistConfiguration()
      } label: {
        Image(systemName: "arrow.down")
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .disabled(index == viewModel.entries.count - 1)
      .accessibilityLabel(Text("addons.moveDown"))

      Button {
        Task { await viewModel.refresh(url: entry.url) }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .accessibilityLabel(Text("addons.refresh"))

      Button(role: .destructive) {
        viewModel.remove(url: entry.url)
        persistConfiguration()
      } label: {
        Image(systemName: "trash")
      }
      .buttonStyle(VelyraGlassButtonStyle())
      .accessibilityLabel(Text("addons.remove"))
    }
    .padding(18)
    .velyraGlass(cornerRadius: 22)
    .accessibilityElement(children: .contain)
  }

  private func addonHealthDescription(_ health: AddonHealthSnapshot) -> String {
    let state = String(
      localized: LocalizedStringResource(stringLiteral: "addons.health.\(health.state.rawValue)"))
    guard let lastSuccess = health.lastSuccessAt else { return state }
    return String(
      format: String(localized: "addons.health.lastSuccess"),
      state,
      lastSuccess.formatted(date: .abbreviated, time: .shortened)
    )
  }

  private func addonHealthSystemImage(_ state: AddonHealthState) -> String {
    switch state {
    case .healthy: "checkmark.circle.fill"
    case .degraded: "exclamationmark.circle.fill"
    case .unavailable: "xmark.octagon.fill"
    }
  }

  private func addonHealthColor(_ state: AddonHealthState) -> Color {
    switch state {
    case .healthy: .green
    case .degraded: .yellow
    case .unavailable: .red
    }
  }

  private func capabilitySummary(_ manifest: AddonManifest) -> String {
    let capabilities = [
      manifest.supports(resource: "catalog") ? String(localized: "addons.capability.catalog") : nil,
      manifest.supports(resource: "meta") ? String(localized: "addons.capability.metadata") : nil,
      manifest.supports(resource: "stream") ? String(localized: "addons.capability.streams") : nil,
      manifest.supports(resource: "subtitles")
        ? String(localized: "addons.capability.subtitles") : nil,
    ].compactMap { $0 }
    let value =
      capabilities.isEmpty
      ? String(localized: "addons.capability.unknown")
      : capabilities.joined(separator: " · ")
    return "v\(manifest.version) · \(value)"
  }

  private func importStremioAddons(_ urls: [String]) {
    appState.updatePreferences { preferences in
      preferences.addonManifestURLs = urls
    }
    Task {
      await viewModel.restore(
        urlStrings: appState.preferences.addonManifestURLs,
        disabled: appState.preferences.disabledAddonManifestURLs,
        priority: appState.preferences.addonPriority
      )
    }
  }

  private func install() async {
    guard await viewModel.install(urlString: manifestURL) != nil else { return }
    persistConfiguration()
    manifestURL = ""
  }

  private func presentTransfer() {
    transferCode =
      (try? AddonConfigurationTransfer.make(
        preferences: appState.preferences
      ).encodedCode()) ?? ""
    transferMessage = nil
    showsTransfer = true
  }

  private func importConfiguration() {
    do {
      let transfer = try AddonConfigurationTransfer.decode(code: transferCode)
      appState.updatePreferences { transfer.applying(to: &$0) }
      transferMessage = String(localized: "addons.transfer.imported")
      Task {
        await viewModel.restore(
          urlStrings: appState.preferences.addonManifestURLs,
          disabled: appState.preferences.disabledAddonManifestURLs,
          priority: appState.preferences.addonPriority
        )
      }
    } catch {
      transferMessage = error.localizedDescription
    }
  }

  private func persistConfiguration() {
    appState.updatePreferences { preferences in
      preferences.addonManifestURLs = viewModel.orderedURLStrings
      preferences.addonPriority = viewModel.orderedURLStrings
      preferences.disabledAddonManifestURLs = viewModel.disabledURLStrings
    }
  }
}

private struct AddonTransferSheet: View {
  @Binding var code: String
  let message: String?
  let onImport: () -> Void
  let onClose: () -> Void

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 24) {
        Text("addons.transfer.title")
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
        Text("addons.transfer.body")
          .foregroundStyle(.white.opacity(0.62))
        TextField("addons.transfer.placeholder", text: $code, axis: .vertical)
          .lineLimit(4...8)
          .textFieldStyle(.plain)
          .font(.system(.body, design: .monospaced))
          .padding(20)
          .velyraGlass(cornerRadius: 20, interactive: true)
        if let message {
          Text(message).foregroundStyle(.white.opacity(0.74))
        }
        HStack(spacing: 16) {
          Button("action.close", action: onClose)
            .buttonStyle(VelyraGlassButtonStyle())
          Button("addons.transfer.import", action: onImport)
            .buttonStyle(VelyraGlassButtonStyle(prominent: true))
            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .frame(maxWidth: 920)
      .padding(44)
      .velyraGlass(cornerRadius: 34)
    }
    .onExitCommand(perform: onClose)
    .onChange(of: message) { _, message in
      guard let message else { return }
      postQueuedAccessibilityAnnouncement(message)
    }
  }
}

@MainActor
private func postQueuedAccessibilityAnnouncement(_ message: String) {
  guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
  let announcement = NSMutableAttributedString(string: message)
  announcement.addAttribute(
    .accessibilitySpeechQueueAnnouncement,
    value: true,
    range: NSRange(location: 0, length: announcement.length)
  )
  UIAccessibility.post(notification: .announcement, argument: announcement)
}
