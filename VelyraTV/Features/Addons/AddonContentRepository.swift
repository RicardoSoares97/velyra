import Foundation

struct InstalledAddonDescriptor: Identifiable, Equatable, Sendable {
  let manifestURL: URL
  let manifest: AddonManifest
  var id: String { manifest.id }
}

struct ResolvedAddonStream: Identifiable, Equatable, Sendable {
  let addonName: String
  let stream: AddonStream
  var id: String { "\(addonName)-\(stream.id)" }
}

struct ResolvedAddonSubtitle: Identifiable, Equatable, Sendable {
  let addonName: String
  let subtitle: AddonSubtitle
  var id: String { "\(addonName)-\(subtitle.id)" }
}

protocol AddonContentProviding: Sendable {
  func installedAddons(urlStrings: [String]) async -> [InstalledAddonDescriptor]
  func search(query: String, kind: MediaKind?, urlStrings: [String]) async -> [AddonMetaPreview]
  func metadata(type: String, id: String, urlStrings: [String]) async -> [AddonMetaDetail]
  func streams(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonStream]
  func subtitles(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonSubtitle]
}

actor AddonContentRepository: AddonContentProviding {
  static let shared = AddonContentRepository()

  private let client: AddonClient
  private let health: AddonHealthMonitor
  private var manifestCache: [URL: (manifest: AddonManifest, loadedAt: Date)] = [:]
  private let manifestTTL: TimeInterval = 6 * 60 * 60

  init(
    client: AddonClient = AddonClient(),
    health: AddonHealthMonitor = .shared
  ) {
    self.client = client
    self.health = health
  }

  func installedAddons(urlStrings: [String]) async -> [InstalledAddonDescriptor] {
    let urls = urlStrings.compactMap(URL.init(string:))
    return await withTaskGroup(of: (Int, InstalledAddonDescriptor?).self) { group in
      for (index, url) in urls.enumerated() {
        group.addTask { [health] in
          guard await health.canRequest(url) else { return (index, nil) }
          do {
            let manifest = try await self.manifest(for: url)
            await health.recordSuccess(url)
            return (index, InstalledAddonDescriptor(manifestURL: url, manifest: manifest))
          } catch {
            await health.recordFailure(url)
            return (index, nil)
          }
        }
      }
      var values: [(Int, InstalledAddonDescriptor)] = []
      for await (index, descriptor) in group {
        if let descriptor { values.append((index, descriptor)) }
      }
      return values.sorted { $0.0 < $1.0 }.map(\.1)
    }
  }

  func search(query: String, kind: MediaKind?, urlStrings: [String]) async -> [AddonMetaPreview] {
    let addons = await installedAddons(urlStrings: urlStrings)
    let supportedTypes =
      kind.map { [$0.addonType] }
      ?? [MediaKind.movie.addonType, MediaKind.series.addonType]
    return await withTaskGroup(of: [AddonMetaPreview].self) { group in
      for addon in addons {
        for catalog in addon.manifest.catalogs where supportedTypes.contains(catalog.type) {
          let supportsSearch = catalog.extra?.contains(where: { $0.name == "search" }) ?? false
          guard supportsSearch else { continue }
          group.addTask { [client, health] in
            do {
              let values = try await client.catalog(
                manifestURL: addon.manifestURL,
                type: catalog.type,
                id: catalog.id,
                extras: ["search": query]
              )
              await health.recordSuccess(addon.manifestURL)
              return values
            } catch {
              await health.recordFailure(addon.manifestURL)
              return []
            }
          }
        }
      }
      var values: [AddonMetaPreview] = []
      for await result in group { values.append(contentsOf: result) }
      return deduplicate(values)
    }
  }

  func metadata(type: String, id: String, urlStrings: [String]) async -> [AddonMetaDetail] {
    let addons = await installedAddons(urlStrings: urlStrings)
    return await withTaskGroup(of: AddonMetaDetail?.self) { group in
      for addon in addons where addon.manifest.supports(resource: "meta", type: type) {
        group.addTask { [client, health] in
          do {
            let value = try await client.metadata(
              manifestURL: addon.manifestURL, type: type, id: id)
            await health.recordSuccess(addon.manifestURL)
            return value
          } catch {
            await health.recordFailure(addon.manifestURL)
            return nil
          }
        }
      }
      var values: [AddonMetaDetail] = []
      for await value in group { if let value { values.append(value) } }
      return values
    }
  }

  func streams(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonStream] {
    let addons = await installedAddons(urlStrings: urlStrings)
    return await withTaskGroup(of: [ResolvedAddonStream].self) { group in
      for addon in addons where addon.manifest.supports(resource: "stream", type: type) {
        group.addTask { [client, health] in
          do {
            let streams = try await client.streams(
              manifestURL: addon.manifestURL, type: type, id: id)
            await health.recordSuccess(addon.manifestURL)
            return streams.map { ResolvedAddonStream(addonName: addon.manifest.name, stream: $0) }
          } catch {
            await health.recordFailure(addon.manifestURL)
            return []
          }
        }
      }
      var values: [ResolvedAddonStream] = []
      for await value in group { values.append(contentsOf: value) }
      return deduplicateStreams(values)
    }
  }

  func subtitles(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonSubtitle] {
    let addons = await installedAddons(urlStrings: urlStrings)
    return await withTaskGroup(of: [ResolvedAddonSubtitle].self) { group in
      for addon in addons where addon.manifest.supports(resource: "subtitles", type: type) {
        group.addTask { [client, health] in
          do {
            let subtitles = try await client.subtitles(
              manifestURL: addon.manifestURL, type: type, id: id)
            await health.recordSuccess(addon.manifestURL)
            return subtitles.map {
              ResolvedAddonSubtitle(addonName: addon.manifest.name, subtitle: $0)
            }
          } catch {
            await health.recordFailure(addon.manifestURL)
            return []
          }
        }
      }
      var values: [ResolvedAddonSubtitle] = []
      for await value in group { values.append(contentsOf: value) }
      return deduplicateSubtitles(values)
    }
  }

  func clearCaches() async {
    manifestCache.removeAll()
    await health.resetAll()
  }

  func healthSnapshot(for url: URL) async -> AddonHealthSnapshot {
    await health.snapshot(for: url)
  }

  private func manifest(for url: URL) async throws -> AddonManifest {
    if let cached = manifestCache[url], Date().timeIntervalSince(cached.loadedAt) < manifestTTL {
      return cached.manifest
    }
    let value = try await client.manifest(from: url)
    manifestCache[url] = (value, Date())
    return value
  }

  private func deduplicate(_ values: [AddonMetaPreview]) -> [AddonMetaPreview] {
    var seen: Set<String> = []
    return values.filter { seen.insert("\($0.type):\($0.id)").inserted }
  }

  private func deduplicateStreams(_ values: [ResolvedAddonStream]) -> [ResolvedAddonStream] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0.stream.id).inserted }
  }

  private func deduplicateSubtitles(_ values: [ResolvedAddonSubtitle]) -> [ResolvedAddonSubtitle] {
    var seen: Set<String> = []
    return values.filter { seen.insert($0.subtitle.url.absoluteString).inserted }
  }
}

extension MediaKind {
  var addonType: String {
    switch self {
    case .movie: "movie"
    case .series: "series"
    }
  }
}
