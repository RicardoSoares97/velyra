import Foundation

@MainActor
final class AddonViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case loading
    case success(String)
    case failed(String)
  }

  struct Entry: Identifiable, Equatable {
    let url: URL
    var manifest: AddonManifest?
    var enabled: Bool
    var isRefreshing: Bool
    var errorMessage: String?
    var health: AddonHealthSnapshot?
    var id: String { url.absoluteString }
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var entries: [Entry] = []

  private let client: AddonClient
  private let health: AddonHealthMonitor

  init(
    client: AddonClient = AddonClient(),
    health: AddonHealthMonitor = .shared
  ) {
    self.client = client
    self.health = health
  }

  func restore(urlStrings: [String], disabled: [String], priority: [String]) async {
    let priorityMap = Dictionary(uniqueKeysWithValues: priority.enumerated().map { ($1, $0) })
    entries = urlStrings.compactMap { value in
      URL(string: value).map {
        Entry(
          url: $0,
          manifest: nil,
          enabled: !disabled.contains(value),
          isRefreshing: true,
          errorMessage: nil,
          health: nil
        )
      }
    }
    .sorted {
      (priorityMap[$0.url.absoluteString] ?? .max)
        < (priorityMap[$1.url.absoluteString] ?? .max)
    }
    await refreshAll()
  }

  func install(urlString: String) async -> URL? {
    guard let url = URL(string: urlString) else {
      state = .failed(String(localized: "addons.error.invalidURL"))
      return nil
    }
    state = .loading
    do {
      let manifest = try await client.manifest(from: url)
      await health.recordSuccess(url)
      let snapshot = await health.snapshot(for: url)
      entries.removeAll { $0.url == url || $0.manifest?.id == manifest.id }
      entries.append(
        Entry(
          url: url,
          manifest: manifest,
          enabled: true,
          isRefreshing: false,
          errorMessage: nil,
          health: snapshot
        )
      )
      state = .success(manifest.name)
      return url
    } catch AddonClient.AddonError.insecureURL {
      await health.recordFailure(url)
      state = .failed(String(localized: "addons.error.https"))
    } catch {
      await health.recordFailure(url)
      state = .failed(String(localized: "addons.error.manifest"))
    }
    return nil
  }

  func refreshAll() async {
    await withTaskGroup(
      of: (URL, Result<AddonManifest, Error>, AddonHealthSnapshot).self
    ) { group in
      for entry in entries {
        group.addTask { [client, health] in
          let result: Result<AddonManifest, Error>
          do {
            let manifest = try await client.manifest(from: entry.url)
            await health.recordSuccess(entry.url)
            result = .success(manifest)
          } catch {
            await health.recordFailure(entry.url)
            result = .failure(error)
          }
          return (entry.url, result, await health.snapshot(for: entry.url))
        }
      }
      for await (url, result, snapshot) in group {
        apply(result, health: snapshot, to: url)
      }
    }
  }

  func refresh(url: URL) async {
    guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
    entries[index].isRefreshing = true
    do {
      let manifest = try await client.manifest(from: url)
      await health.recordSuccess(url)
      apply(.success(manifest), health: await health.snapshot(for: url), to: url)
    } catch {
      await health.recordFailure(url)
      apply(.failure(error), health: await health.snapshot(for: url), to: url)
    }
  }

  func setEnabled(_ enabled: Bool, url: URL) {
    guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
    entries[index].enabled = enabled
  }

  func move(url: URL, offset: Int) {
    guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
    let destination = min(max(index + offset, 0), entries.count - 1)
    guard destination != index else { return }
    let value = entries.remove(at: index)
    entries.insert(value, at: destination)
  }

  func remove(url: URL) {
    entries.removeAll { $0.url == url }
    state = .idle
  }

  func removeAll() {
    entries = []
    state = .idle
  }

  var orderedURLStrings: [String] { entries.map { $0.url.absoluteString } }
  var disabledURLStrings: [String] {
    entries.filter { !$0.enabled }.map { $0.url.absoluteString }
  }

  private func apply(
    _ result: Result<AddonManifest, Error>,
    health: AddonHealthSnapshot,
    to url: URL
  ) {
    guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
    entries[index].isRefreshing = false
    entries[index].health = health
    switch result {
    case .success(let manifest):
      entries[index].manifest = manifest
      entries[index].errorMessage = nil
    case .failure(let error):
      entries[index].errorMessage = error.localizedDescription
    }
  }
}
