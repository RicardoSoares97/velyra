import Foundation

@MainActor
final class AddonViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case success(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var manifests: [URL: AddonManifest] = [:]

    private let client: AddonClient

    init(client: AddonClient = AddonClient()) {
        self.client = client
    }

    func restore(urlStrings: [String]) async {
        for value in urlStrings {
            guard let url = URL(string: value) else { continue }
            if let manifest = try? await client.manifest(from: url) {
                manifests[url] = manifest
            }
        }
    }

    func install(urlString: String) async -> URL? {
        guard let url = URL(string: urlString) else {
            state = .failed(String(localized: "addons.error.invalidURL"))
            return nil
        }

        state = .loading
        do {
            let manifest = try await client.manifest(from: url)
            manifests[url] = manifest
            state = .success(manifest.name)
            return url
        } catch AddonClient.AddonError.insecureURL {
            state = .failed(String(localized: "addons.error.https"))
        } catch {
            state = .failed(String(localized: "addons.error.manifest"))
        }
        return nil
    }

    func remove(url: URL) {
        manifests.removeValue(forKey: url)
        state = .idle
    }
}
