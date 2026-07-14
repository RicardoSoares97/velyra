import SwiftUI

struct AddonsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AddonViewModel()
    @State private var manifestURL = ""

    var body: some View {
        VelyraPlaceholderScreen(
            titleKey: "addons.title",
            bodyKey: "addons.body",
            systemImage: "puzzlepiece.extension.fill",
            accent: VelyraTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    TextField("addons.url.placeholder", text: $manifestURL)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(20)
                        .velyraGlass(cornerRadius: 22, interactive: true)

                    Button("addons.add") {
                        Task { await install() }
                    }
                    .buttonStyle(VelyraGlassButtonStyle(prominent: true))
                    .disabled(manifestURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                status

                if !viewModel.manifests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("addons.installed")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(viewModel.manifests.keys.sorted(by: { $0.absoluteString < $1.absoluteString }), id: \.self) { url in
                            if let manifest = viewModel.manifests[url] {
                                HStack(spacing: 16) {
                                    Image(systemName: "puzzlepiece.extension.fill")
                                        .foregroundStyle(VelyraTheme.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(manifest.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(url.host ?? url.absoluteString)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.58))
                                        Text(capabilitySummary(manifest))
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.48))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("addons.remove") {
                                        viewModel.remove(url: url)
                                        appState.updatePreferences {
                                            $0.addonManifestURLs.removeAll { $0 == url.absoluteString }
                                        }
                                    }
                                    .buttonStyle(VelyraGlassButtonStyle())
                                }
                                .padding(18)
                                .velyraGlass(cornerRadius: 20)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1_100, alignment: .leading)
            .task {
                await viewModel.restore(urlStrings: appState.preferences.addonManifestURLs)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("addons.validating")
            }
            .foregroundStyle(.white)
        case .success(let name):
            Label {
                Text(name + " · " + String(localized: "addons.added"))
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .foregroundStyle(.white)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
        }
    }

    private func capabilitySummary(_ manifest: AddonManifest) -> String {
        let capabilities = [
            manifest.supports(resource: "catalog") ? String(localized: "addons.capability.catalog") : nil,
            manifest.supports(resource: "meta") ? String(localized: "addons.capability.metadata") : nil,
            manifest.supports(resource: "stream") ? String(localized: "addons.capability.streams") : nil,
            manifest.supports(resource: "subtitles") ? String(localized: "addons.capability.subtitles") : nil
        ].compactMap { $0 }
        return capabilities.isEmpty
            ? String(localized: "addons.capability.unknown")
            : capabilities.joined(separator: " · ")
    }

    private func install() async {
        guard let url = await viewModel.install(urlString: manifestURL) else { return }
        appState.updatePreferences { preferences in
            if !preferences.addonManifestURLs.contains(url.absoluteString) {
                preferences.addonManifestURLs.append(url.absoluteString)
            }
        }
        manifestURL = ""
    }
}
