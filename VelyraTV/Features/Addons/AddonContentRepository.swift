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
  private let client: AddonClient
  private var manifestCache: [URL: AddonManifest] = [:]

  init(client: AddonClient = AddonClient()) {
    self.client = client
  }

  func installedAddons(urlStrings: [String]) async -> [InstalledAddonDescriptor] {
    var result: [InstalledAddonDescriptor] = []
    for value in urlStrings {
      guard let url = URL(string: value) else { continue }
      do {
        let manifest: AddonManifest
        if let cached = manifestCache[url] {
          manifest = cached
        } else {
          manifest = try await client.manifest(from: url)
          manifestCache[url] = manifest
        }
        result.append(InstalledAddonDescriptor(manifestURL: url, manifest: manifest))
      } catch {
        continue
      }
    }
    return result.sorted {
      $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending
    }
  }

  func search(
    query: String,
    kind: MediaKind?,
    urlStrings: [String]
  ) async -> [AddonMetaPreview] {
    let addons = await installedAddons(urlStrings: urlStrings)
    let supportedTypes = kind.map { [$0.addonType] } ?? [MediaKind.movie.addonType, MediaKind.series.addonType]
    var results: [AddonMetaPreview] = []

    for addon in addons {
      for catalog in addon.manifest.catalogs where supportedTypes.contains(catalog.type) {
        let supportsSearch = catalog.extra?.contains(where: { $0.name == "search" }) ?? false
        guard supportsSearch else { continue }
        if let metas = try? await client.catalog(
          manifestURL: addon.manifestURL,
          type: catalog.type,
          id: catalog.id,
          extras: ["search": query]
        ) {
          results.append(contentsOf: metas)
        }
      }
    }
    return deduplicate(results)
  }

  func metadata(
    type: String,
    id: String,
    urlStrings: [String]
  ) async -> [AddonMetaDetail] {
    let addons = await installedAddons(urlStrings: urlStrings)
    var results: [AddonMetaDetail] = []
    for addon in addons where addon.manifest.supports(resource: "meta", type: type) {
      if let metadata = try? await client.metadata(
        manifestURL: addon.manifestURL,
        type: type,
        id: id
      ) {
        results.append(metadata)
      }
    }
    return results
  }

  func streams(
    type: String,
    id: String,
    urlStrings: [String]
  ) async -> [ResolvedAddonStream] {
    let addons = await installedAddons(urlStrings: urlStrings)
    var results: [ResolvedAddonStream] = []
    for addon in addons where addon.manifest.supports(resource: "stream", type: type) {
      if let streams = try? await client.streams(
        manifestURL: addon.manifestURL,
        type: type,
        id: id
      ) {
        results.append(contentsOf: streams.map {
          ResolvedAddonStream(addonName: addon.manifest.name, stream: $0)
        })
      }
    }
    return deduplicateStreams(results)
  }

  func subtitles(
    type: String,
    id: String,
    urlStrings: [String]
  ) async -> [ResolvedAddonSubtitle] {
    let addons = await installedAddons(urlStrings: urlStrings)
    var results: [ResolvedAddonSubtitle] = []
    for addon in addons where addon.manifest.supports(resource: "subtitles", type: type) {
      if let subtitles = try? await client.subtitles(
        manifestURL: addon.manifestURL,
        type: type,
        id: id
      ) {
        results.append(contentsOf: subtitles.map {
          ResolvedAddonSubtitle(addonName: addon.manifest.name, subtitle: $0)
        })
      }
    }
    return deduplicateSubtitles(results)
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
