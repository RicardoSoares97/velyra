import Foundation

protocol StremioAddonImportServing: Sendable {
  func createLink() async throws -> StremioLinkCode
  func readLink(code: String) async throws -> StremioAuthorizationState
  func addonCollection(authKey: StremioAuthKey) async throws -> [StremioAddonDescriptor]
  func logout(authKey: StremioAuthKey) async throws
}

actor StremioAddonImportService: StremioAddonImportServing {
  private let httpClient: any HTTPClient
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(httpClient: any HTTPClient = URLSessionHTTPClient(maximumResponseBytes: 2_000_000)) {
    self.httpClient = httpClient
  }

  func createLink() async throws -> StremioLinkCode {
    let response: LinkCodeResponse = try await getLink(
      path: "create",
      query: [
        URLQueryItem(name: "type", value: "Create")
      ])
    guard let linkURL = URL(string: response.link), !response.code.isEmpty else {
      throw StremioImportError.invalidResponse
    }
    return StremioLinkCode(
      code: response.code,
      linkURL: linkURL,
      qrCodePayload: response.qrcode,
      expiresAt: Date().addingTimeInterval(120)
    )
  }

  func readLink(code: String) async throws -> StremioAuthorizationState {
    guard !code.isEmpty else { throw StremioImportError.invalidResponse }
    let url = try linkURL(
      path: "read",
      query: [
        URLQueryItem(name: "type", value: "Read"),
        URLQueryItem(name: "code", value: code),
      ]
    )
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, _) = try await httpClient.data(for: request)
    let envelope = try decodeEnvelope(LinkAuthKeyResponse.self, from: data)
    if let result = envelope.result {
      guard !result.authKey.isEmpty else { throw StremioImportError.invalidResponse }
      return .authorized(StremioAuthKey(result.authKey))
    }
    if envelope.error != nil {
      return .pending
    }
    throw StremioImportError.invalidResponse
  }

  func addonCollection(authKey: StremioAuthKey) async throws -> [StremioAddonDescriptor] {
    let body = AddonCollectionRequest(
      type: "AddonCollectionGet",
      authKey: authKey.requestValue,
      update: true
    )
    let response: AddonCollectionResponse
    do {
      response = try await post(
        endpoint: "addonCollectionGet",
        body: body,
        response: AddonCollectionResponse.self
      )
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw StremioImportError.collectionUnavailable
    }
    return response.addons.map {
      StremioAddonDescriptor(manifest: $0.manifest, transportURL: $0.transportURL)
    }
  }

  func logout(authKey: StremioAuthKey) async throws {
    let body = LogoutRequest(type: "Logout", authKey: authKey.requestValue)
    let _: SuccessResponse = try await post(
      endpoint: "logout",
      body: body,
      response: SuccessResponse.self
    )
  }

  private func getLink<Response: Decodable>(
    path: String,
    query: [URLQueryItem]
  ) async throws -> Response {
    let url = try linkURL(path: path, query: query)
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, _) = try await httpClient.data(for: request)
    let envelope = try decodeEnvelope(Response.self, from: data)
    guard let result = envelope.result else {
      throw StremioImportError.linkUnavailable
    }
    return result
  }

  private func post<Body: Encodable, Response: Decodable>(
    endpoint: String,
    body: Body,
    response: Response.Type
  ) async throws -> Response {
    guard let url = URL(string: "https://api.strem.io/api/\(endpoint)") else {
      throw StremioImportError.invalidResponse
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try encoder.encode(body)
    let (data, _) = try await httpClient.data(for: request)
    let envelope = try decodeEnvelope(Response.self, from: data)
    guard let result = envelope.result else {
      throw StremioImportError.invalidResponse
    }
    return result
  }

  private func linkURL(path: String, query: [URLQueryItem]) throws -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "link.stremio.com"
    components.path = "/api/v2/\(path)"
    components.queryItems = query
    guard let url = components.url else {
      throw StremioImportError.invalidResponse
    }
    return url
  }

  private func decodeEnvelope<Response: Decodable>(
    _ type: Response.Type,
    from data: Data
  ) throws -> APIEnvelope<Response> {
    do {
      return try decoder.decode(APIEnvelope<Response>.self, from: data)
    } catch {
      throw StremioImportError.invalidResponse
    }
  }
}

private struct APIEnvelope<Result: Decodable>: Decodable {
  let result: Result?
  let error: APIErrorResponse?
}

private struct APIErrorResponse: Decodable {
  let message: String
  let code: Int
}

private struct LinkCodeResponse: Decodable {
  let code: String
  let link: String
  let qrcode: String
}

private struct LinkAuthKeyResponse: Decodable {
  let authKey: String
}

private struct AddonCollectionRequest: Encodable {
  let type: String
  let authKey: String
  let update: Bool
}

private struct LogoutRequest: Encodable {
  let type: String
  let authKey: String
}

private struct AddonCollectionResponse: Decodable {
  let addons: [Descriptor]

  struct Descriptor: Decodable {
    let manifest: AddonManifest
    let transportURL: String

    enum CodingKeys: String, CodingKey {
      case manifest
      case transportURL = "transportUrl"
    }
  }
}

private struct SuccessResponse: Decodable {
  let success: Bool
}
