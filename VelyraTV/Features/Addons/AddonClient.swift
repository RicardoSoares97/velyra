import Foundation

protocol AddonManifestValidating: Sendable {
  func manifest(from manifestURL: URL) async throws -> AddonManifest
}

actor AddonClient: AddonManifestValidating {
  enum AddonError: Error {
    case invalidManifestURL
    case insecureURL
    case malformedResponse
  }

  private let httpClient: any HTTPClient
  private let decoder: JSONDecoder

  init(httpClient: any HTTPClient = URLSessionHTTPClient()) {
    self.httpClient = httpClient
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  func manifest(from manifestURL: URL) async throws -> AddonManifest {
    try validate(manifestURL)
    return try await fetch(manifestURL)
  }

  func catalog(
    manifestURL: URL,
    type: String,
    id: String,
    extras: [String: String] = [:]
  ) async throws -> [AddonMetaPreview] {
    let url = try resourceURL(
      manifestURL: manifestURL,
      pathComponents: ["catalog", type, id],
      extras: extras
    )
    let response: AddonMetaResponse = try await fetch(url)
    return response.metas
  }

  func metadata(manifestURL: URL, type: String, id: String) async throws -> AddonMetaDetail {
    let url = try resourceURL(manifestURL: manifestURL, pathComponents: ["meta", type, id])
    let response: AddonMetaDetailResponse = try await fetch(url)
    return response.meta
  }

  func streams(manifestURL: URL, type: String, id: String) async throws -> [AddonStream] {
    let url = try resourceURL(manifestURL: manifestURL, pathComponents: ["stream", type, id])
    let response: AddonStreamResponse = try await fetch(url)
    return response.streams
  }

  func subtitles(
    manifestURL: URL,
    type: String,
    id: String,
    extras: [String: String] = [:]
  ) async throws -> [AddonSubtitle] {
    let url = try resourceURL(
      manifestURL: manifestURL,
      pathComponents: ["subtitles", type, id],
      extras: extras
    )
    let response: AddonSubtitleResponse = try await fetch(url)
    return response.subtitles
  }

  private func resourceURL(
    manifestURL: URL,
    pathComponents: [String],
    extras: [String: String] = [:]
  ) throws -> URL {
    try validate(manifestURL)
    let baseURL = manifestURL.deletingLastPathComponent()
    let url = pathComponents.reduce(baseURL) { partial, component in
      partial.appendingPathComponent(component)
    }

    guard !extras.isEmpty else {
      return url.appendingPathExtension("json")
    }

    let encodedExtras =
      try extras
      .sorted(by: { $0.key < $1.key })
      .map { key, value in
        guard
          let encodedKey = encodeExtraComponent(key),
          let encodedValue = encodeExtraComponent(value)
        else {
          throw AddonError.invalidManifestURL
        }
        return "\(encodedKey)=\(encodedValue)"
      }
      .joined(separator: "&")

    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw AddonError.invalidManifestURL
    }
    components.percentEncodedPath += "/\(encodedExtras).json"
    guard let resourceURL = components.url else {
      throw AddonError.invalidManifestURL
    }
    return resourceURL
  }

  private func encodeExtraComponent(_ value: String) -> String? {
    let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
    return value.addingPercentEncoding(withAllowedCharacters: unreserved)
  }

  private func validate(_ url: URL) throws {
    guard url.lastPathComponent == "manifest.json" else {
      throw AddonError.invalidManifestURL
    }
    guard url.scheme?.lowercased() == "https" || isLocalhost(url) else {
      throw AddonError.insecureURL
    }
  }

  private func isLocalhost(_ url: URL) -> Bool {
    ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
  }

  private func fetch<Response: Decodable>(_ url: URL) async throws -> Response {
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.timeoutInterval = 20
    let (data, _) = try await httpClient.data(for: request)
    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw AddonError.malformedResponse
    }
  }
}
