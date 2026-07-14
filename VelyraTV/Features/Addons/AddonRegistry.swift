import Foundation

actor AddonRegistry {
    struct InstalledAddon: Codable, Equatable, Identifiable {
        let manifestURL: URL
        let manifest: AddonManifest
        let installedAt: Date

        var id: String { manifest.id }
    }

    private let client: AddonClient
    private var addons: [InstalledAddon] = []

    init(client: AddonClient = AddonClient()) {
        self.client = client
    }

    func install(manifestURL: URL) async throws -> InstalledAddon {
        let manifest = try await client.manifest(from: manifestURL)
        let installed = InstalledAddon(
            manifestURL: manifestURL,
            manifest: manifest,
            installedAt: Date()
        )
        addons.removeAll { $0.manifest.id == manifest.id }
        addons.append(installed)
        return installed
    }

    func remove(id: String) {
        addons.removeAll { $0.id == id }
    }

    func all() -> [InstalledAddon] {
        addons.sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }
}
