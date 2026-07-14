import Foundation

struct AddonManifest: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let version: String
  let name: String
  let description: String?
  let resources: [AddonResource]
  let types: [String]
  let catalogs: [AddonCatalog]
  let idPrefixes: [String]?

  enum CodingKeys: String, CodingKey {
    case id, version, name, description, resources, types, catalogs, idPrefixes
  }

  func supports(resource name: String, type: String? = nil) -> Bool {
    resources.contains { resource in
      switch resource {
      case .name(let resourceName):
        return resourceName == name
      case .descriptor(let resourceName, let types, _):
        guard resourceName == name else { return false }
        guard let type else { return true }
        return types?.contains(type) ?? true
      }
    }
  }
}

enum AddonResource: Codable, Equatable, Sendable {
  case name(String)
  case descriptor(name: String, types: [String]?, idPrefixes: [String]?)

  private enum CodingKeys: String, CodingKey {
    case name, types, idPrefixes
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      self = .name(string)
      return
    }
    let object = try container.decode(ResourceObject.self)
    self = .descriptor(name: object.name, types: object.types, idPrefixes: object.idPrefixes)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .name(let value):
      try container.encode(value)
    case .descriptor(let name, let types, let idPrefixes):
      try container.encode(ResourceObject(name: name, types: types, idPrefixes: idPrefixes))
    }
  }

  private struct ResourceObject: Codable, Equatable, Sendable {
    let name: String
    let types: [String]?
    let idPrefixes: [String]?
  }
}

struct AddonCatalog: Codable, Equatable, Identifiable, Sendable {
  let type: String
  let id: String
  let name: String?
  let extra: [AddonCatalogExtra]?
}

struct AddonCatalogExtra: Codable, Equatable, Sendable {
  let name: String
  let isRequired: Bool?
  let options: [String]?

  enum CodingKeys: String, CodingKey {
    case name, options, isRequired
  }
}

struct AddonMetaPreview: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let type: String
  let name: String
  let poster: URL?
  let background: URL?
  let description: String?
  let releaseInfo: String?
  let imdbRating: String?
  let genres: [String]?
}

struct AddonMetaResponse: Codable, Sendable {
  let metas: [AddonMetaPreview]
}

struct AddonMetaDetailResponse: Codable, Sendable {
  let meta: AddonMetaDetail
}

struct AddonMetaDetail: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let type: String
  let name: String
  let poster: URL?
  let background: URL?
  let logo: URL?
  let description: String?
  let releaseInfo: String?
  let imdbRating: String?
  let genres: [String]?
  let videos: [AddonVideo]?
}

struct AddonVideo: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let title: String?
  let season: Int?
  let episode: Int?
  let released: Date?
}

struct AddonStreamResponse: Codable, Sendable {
  let streams: [AddonStream]
}

struct AddonStream: Codable, Equatable, Identifiable, Sendable {
  var id: String {
    let fallback = [name, title].compactMap { $0 }.joined(separator: "|")
    return url?.absoluteString ?? externalURL?.absoluteString ?? infoHash
      ?? (fallback.isEmpty ? "unknown-stream" : fallback)
  }

  let name: String?
  let title: String?
  let url: URL?
  let externalURL: URL?
  let infoHash: String?
  let fileIdx: Int?
  let behaviorHints: AddonStreamBehaviorHints?

  enum CodingKeys: String, CodingKey {
    case name, title, url, infoHash, fileIdx, behaviorHints
    case externalURL = "externalUrl"
  }
}

struct AddonStreamBehaviorHints: Codable, Equatable, Sendable {
  let notWebReady: Bool?
  let bingeGroup: String?
  let proxyHeaders: AddonProxyHeaders?
}

struct AddonProxyHeaders: Codable, Equatable, Sendable {
  let request: [String: String]?
  let response: [String: String]?
}

struct AddonSubtitleResponse: Codable, Sendable {
  let subtitles: [AddonSubtitle]
}

struct AddonSubtitle: Codable, Equatable, Identifiable, Sendable {
  var id: String { "\(lang)-\(url.absoluteString)" }
  let idValue: String?
  let url: URL
  let lang: String

  enum CodingKeys: String, CodingKey {
    case idValue = "id"
    case url, lang
  }
}
