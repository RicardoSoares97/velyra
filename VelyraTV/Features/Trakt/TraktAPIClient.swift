import Foundation

actor TraktAPIClient {
  enum APIError: LocalizedError, Equatable {
    case notConfigured
    case invalidRequest
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case pendingAuthorization
    case authorizationDenied
    case authorizationExpired
    case rateLimited(retryAfter: TimeInterval?)
    case validation(String?)
    case server(Int)
    case decoding(String)

    var errorDescription: String? {
      switch self {
      case .notConfigured: String(localized: "trakt.error.notConfigured")
      case .invalidRequest: String(localized: "trakt.error.invalidRequest")
      case .invalidResponse: String(localized: "trakt.error.invalidResponse")
      case .unauthorized: String(localized: "trakt.error.unauthorized")
      case .forbidden: String(localized: "trakt.error.forbidden")
      case .notFound: String(localized: "trakt.error.notFound")
      case .conflict: String(localized: "trakt.error.conflict")
      case .pendingAuthorization: String(localized: "trakt.error.pending")
      case .authorizationDenied: String(localized: "trakt.error.denied")
      case .authorizationExpired: String(localized: "trakt.error.expired")
      case .rateLimited: String(localized: "trakt.error.rateLimited")
      case .validation(let message): message ?? String(localized: "trakt.error.validation")
      case .server: String(localized: "trakt.error.server")
      case .decoding: String(localized: "trakt.error.invalidResponse")
      }
    }
  }

  private struct APIErrorPayload: Decodable {
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
      case error
      case errorDescription = "error_description"
    }
  }

  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let maximumRetries: Int
  private let maximumResponseBytes: Int
  private let requestGate: TraktRequestGate

  init(
    session: URLSession = .shared,
    maximumRetries: Int = 3,
    maximumResponseBytes: Int = 10_000_000,
    requestGate: TraktRequestGate = TraktRequestGate()
  ) {
    self.session = session
    self.maximumRetries = maximumRetries
    self.maximumResponseBytes = maximumResponseBytes
    self.requestGate = requestGate

    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      try container.encode(Self.iso8601String(from: date))
    }

    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let value = try container.decode(String.self)
      guard let date = Self.date(from: value) else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Invalid Trakt date: \(value)"
        )
      }
      return date
    }
  }

  // MARK: OAuth

  func requestDeviceCode() async throws -> TraktDeviceCode {
    try ensureConfigured()
    return try await send(
      path: "/oauth/device/code",
      method: "POST",
      body: ["client_id": TraktConfiguration.clientID],
      authenticated: false
    ).values
  }

  func exchangeDeviceCode(_ code: String) async throws -> TraktToken {
    try ensureConfigured()
    let body = [
      "code": code,
      "client_id": TraktConfiguration.clientID,
      "client_secret": TraktConfiguration.clientSecret,
    ]
    return try await send(
      path: "/oauth/device/token",
      method: "POST",
      body: body,
      authenticated: false,
      retriesEnabled: false
    ).values
  }

  func refresh(_ token: TraktToken) async throws -> TraktToken {
    let body = [
      "refresh_token": token.refreshToken,
      "client_id": TraktConfiguration.clientID,
      "client_secret": TraktConfiguration.clientSecret,
      "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
      "grant_type": "refresh_token",
    ]
    return try await send(
      path: "/oauth/token",
      method: "POST",
      body: body,
      authenticated: false
    ).values
  }

  func revoke(_ token: TraktToken) async throws {
    let body = [
      "token": token.accessToken,
      "client_id": TraktConfiguration.clientID,
      "client_secret": TraktConfiguration.clientSecret,
    ]
    let _: EmptyResponse = try await send(
      path: "/oauth/revoke",
      method: "POST",
      body: body,
      authenticated: false
    ).values
  }

  // MARK: Account

  func userSettings(token: TraktToken) async throws -> TraktUserSettings {
    try await get(path: "/users/settings", token: token)
  }

  func lastActivities(token: TraktToken) async throws -> TraktLastActivities {
    try await get(path: "/sync/last_activities", token: token)
  }

  // MARK: Playback

  func playback(token: TraktToken) async throws -> [TraktPlaybackItem] {
    try await get(path: "/sync/playback", token: token)
  }

  func removePlayback(id: Int, token: TraktToken) async throws {
    let _: EmptyResponse = try await delete(path: "/sync/playback/\(id)", token: token)
  }

  func scrobble(
    action: TraktScrobbleAction,
    payload: TraktScrobblePayload,
    token: TraktToken
  ) async throws -> TraktScrobbleResponse {
    try await post(
      path: "/scrobble/\(action.rawValue)",
      body: payload,
      token: token
    )
  }

  // MARK: Library reads

  func watchlistMovies(token: TraktToken) async throws -> [TraktWatchlistItem] {
    try await get(path: "/sync/watchlist/movies", token: token)
  }

  func watchlistShows(token: TraktToken) async throws -> [TraktWatchlistItem] {
    try await get(path: "/sync/watchlist/shows", token: token)
  }

  func collectionMovies(token: TraktToken) async throws -> [TraktCollectionItem] {
    try await get(path: "/sync/collection/movies", token: token)
  }

  func collectionShows(token: TraktToken) async throws -> [TraktCollectionItem] {
    try await get(path: "/sync/collection/shows", token: token)
  }

  func watchedMovies(token: TraktToken) async throws -> [TraktWatchedMovie] {
    try await get(path: "/sync/watched/movies", token: token)
  }

  func watchedShows(token: TraktToken) async throws -> [TraktWatchedShow] {
    try await get(path: "/sync/watched/shows", token: token)
  }

  func ratingsMovies(token: TraktToken) async throws -> [TraktRatingItem] {
    try await get(path: "/sync/ratings/movies", token: token)
  }

  func ratingsShows(token: TraktToken) async throws -> [TraktRatingItem] {
    try await get(path: "/sync/ratings/shows", token: token)
  }

  func history(
    type: TraktMediaType? = nil,
    page: Int = 1,
    limit: Int = 100,
    token: TraktToken
  ) async throws -> TraktPage<[TraktHistoryItem]> {
    var path = "/sync/history"
    if let type {
      let component = type == .show ? "shows" : "\(type.rawValue)s"
      path += "/\(component)"
    }
    return try await getPage(
      path: path,
      query: [
        URLQueryItem(name: "page", value: String(max(1, page))),
        URLQueryItem(name: "limit", value: String(min(max(limit, 1), 1000))),
      ],
      token: token
    )
  }

  func personalLists(token: TraktToken) async throws -> [TraktPersonalList] {
    try await get(path: "/users/me/lists", token: token)
  }

  func listItems(listID: Int, token: TraktToken) async throws -> [TraktListItem] {
    try await get(path: "/users/me/lists/\(listID)/items", token: token)
  }

  func createList(_ request: TraktListRequest, token: TraktToken) async throws -> TraktPersonalList
  {
    try await post(path: "/users/me/lists", body: request, token: token)
  }

  func updateList(
    id: Int,
    request: TraktListRequest,
    token: TraktToken
  ) async throws -> TraktPersonalList {
    try await put(path: "/users/me/lists/\(id)", body: request, token: token)
  }

  func deleteList(id: Int, token: TraktToken) async throws {
    let _: EmptyResponse = try await delete(path: "/users/me/lists/\(id)", token: token)
  }

  func addListItems(
    listID: Int,
    request: TraktSyncRequest,
    token: TraktToken
  ) async throws -> TraktSyncResponse {
    try await post(path: "/users/me/lists/\(listID)/items", body: request, token: token)
  }

  func removeListItems(
    listID: Int,
    request: TraktSyncRequest,
    token: TraktToken
  ) async throws -> TraktSyncResponse {
    try await post(path: "/users/me/lists/\(listID)/items/remove", body: request, token: token)
  }

  // MARK: Library writes

  func addToWatchlist(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/watchlist", body: request, token: token)
  }

  func removeFromWatchlist(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/watchlist/remove", body: request, token: token)
  }

  func addToCollection(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/collection", body: request, token: token)
  }

  func removeFromCollection(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/collection/remove", body: request, token: token)
  }

  func addToHistory(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/history", body: request, token: token)
  }

  func removeFromHistory(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/history/remove", body: request, token: token)
  }

  func addRatings(_ request: TraktSyncRequest, token: TraktToken) async throws -> TraktSyncResponse
  {
    try await post(path: "/sync/ratings", body: request, token: token)
  }

  func removeRatings(_ request: TraktSyncRequest, token: TraktToken) async throws
    -> TraktSyncResponse
  {
    try await post(path: "/sync/ratings/remove", body: request, token: token)
  }

  // MARK: Generic transport

  func get<Response: Decodable & Sendable>(path: String, token: TraktToken) async throws -> Response
  {
    try await send(path: path, token: token).values
  }

  func getPage<Response: Decodable & Sendable>(
    path: String,
    query: [URLQueryItem] = [],
    token: TraktToken
  ) async throws -> TraktPage<Response> {
    try await send(path: path, query: query, token: token)
  }

  func allPages<Item: Decodable & Sendable>(
    path: String,
    query: [URLQueryItem] = [],
    limit: Int = 1000,
    maximumPages: Int = 50,
    token: TraktToken
  ) async throws -> [Item] {
    var page = 1
    var results: [Item] = []
    repeat {
      var items = query.filter { $0.name != "page" && $0.name != "limit" }
      items.append(URLQueryItem(name: "page", value: String(page)))
      items.append(URLQueryItem(name: "limit", value: String(min(max(limit, 1), 1000))))
      let response: TraktPage<[Item]> = try await getPage(path: path, query: items, token: token)
      results.append(contentsOf: response.values)
      guard page < response.pagination.pageCount, page < maximumPages else { break }
      page += 1
    } while !Task.isCancelled
    try Task.checkCancellation()
    return results
  }

  func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
    path: String,
    body: Body,
    token: TraktToken
  ) async throws -> Response {
    try await send(path: path, method: "POST", encodableBody: body, token: token).values
  }

  func put<Body: Encodable & Sendable, Response: Decodable & Sendable>(
    path: String,
    body: Body,
    token: TraktToken
  ) async throws -> Response {
    try await send(path: path, method: "PUT", encodableBody: body, token: token).values
  }

  func delete<Response: Decodable & Sendable>(path: String, token: TraktToken) async throws
    -> Response
  {
    try await send(path: path, method: "DELETE", token: token).values
  }

  private func ensureConfigured() throws {
    guard TraktConfiguration.isConfigured else { throw APIError.notConfigured }
  }

  private func send<Response: Decodable & Sendable>(
    path: String,
    method: String = "GET",
    query: [URLQueryItem] = [],
    body: [String: String]? = nil,
    authenticated: Bool = true,
    token: TraktToken? = nil,
    retriesEnabled: Bool = true
  ) async throws -> TraktPage<Response> {
    let data = try body.map(encoder.encode)
    return try await execute(
      path: path,
      method: method,
      query: query,
      body: data,
      authenticated: authenticated,
      token: token,
      retriesEnabled: retriesEnabled
    )
  }

  private func send<Body: Encodable & Sendable, Response: Decodable & Sendable>(
    path: String,
    method: String,
    query: [URLQueryItem] = [],
    encodableBody: Body,
    authenticated: Bool = true,
    token: TraktToken,
    retriesEnabled: Bool = true
  ) async throws -> TraktPage<Response> {
    try await execute(
      path: path,
      method: method,
      query: query,
      body: try encoder.encode(encodableBody),
      authenticated: authenticated,
      token: token,
      retriesEnabled: retriesEnabled
    )
  }

  private func execute<Response: Decodable & Sendable>(
    path: String,
    method: String,
    query: [URLQueryItem],
    body: Data?,
    authenticated: Bool,
    token: TraktToken?,
    retriesEnabled: Bool
  ) async throws -> TraktPage<Response> {
    try ensureConfigured()
    let request = try makeRequest(
      path: path,
      method: method,
      query: query,
      body: body,
      authenticated: authenticated,
      token: token
    )

    var attempt = 0
    while true {
      do {
        try await requestGate.waitIfNeeded()
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if 200..<300 ~= http.statusCode {
          guard http.expectedContentLength <= Int64(maximumResponseBytes),
            data.count <= maximumResponseBytes
          else { throw APIError.invalidResponse }
          let value: Response
          if data.isEmpty {
            guard Response.self == EmptyResponse.self else { throw APIError.invalidResponse }
            value = EmptyResponse() as! Response
          } else {
            do {
              value = try decoder.decode(Response.self, from: data)
            } catch {
              if Response.self == EmptyResponse.self {
                value = EmptyResponse() as! Response
              } else {
                throw APIError.decoding(error.localizedDescription)
              }
            }
          }
          return TraktPage(values: value, pagination: pagination(from: http))
        }

        let mapped = mapError(status: http.statusCode, data: data, response: http)
        if case .rateLimited(let retryAfter) = mapped {
          await requestGate.block(for: retryAfter ?? 5)
        }
        if retriesEnabled, shouldRetry(mapped), attempt < maximumRetries {
          let delay = retryDelay(error: mapped, attempt: attempt)
          attempt += 1
          try await Task.sleep(for: .seconds(delay))
          continue
        }
        throw mapped
      } catch is CancellationError {
        throw CancellationError()
      } catch let error as APIError {
        throw error
      } catch {
        if retriesEnabled, attempt < maximumRetries {
          let delay = min(pow(2, Double(attempt)), 8)
          attempt += 1
          try await Task.sleep(for: .seconds(delay))
          continue
        }
        throw error
      }
    }
  }

  private func makeRequest(
    path: String,
    method: String,
    query: [URLQueryItem],
    body: Data?,
    authenticated: Bool,
    token: TraktToken?
  ) throws -> URLRequest {
    let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard
      var components = URLComponents(
        url: TraktConfiguration.baseURL.appendingPathComponent(normalizedPath),
        resolvingAgainstBaseURL: false
      )
    else { throw APIError.invalidRequest }
    if !query.isEmpty { components.queryItems = query }
    guard let url = components.url else { throw APIError.invalidRequest }

    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(TraktConfiguration.apiVersion, forHTTPHeaderField: "trakt-api-version")
    request.setValue(TraktConfiguration.clientID, forHTTPHeaderField: "trakt-api-key")
    request.setValue(TraktConfiguration.userAgent, forHTTPHeaderField: "User-Agent")

    if authenticated {
      guard let token else { throw APIError.unauthorized }
      request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  private func mapError(status: Int, data: Data, response: HTTPURLResponse) -> APIError {
    let payload = try? decoder.decode(APIErrorPayload.self, from: data)
    switch status {
    case 400:
      if response.url?.path == "/oauth/device/token" { return .pendingAuthorization }
      return .validation(payload?.errorDescription ?? payload?.error)
    case 401: return .unauthorized
    case 403: return .forbidden
    case 404: return .notFound
    case 409: return .conflict
    case 410: return .authorizationExpired
    case 418: return .authorizationDenied
    case 422: return .validation(payload?.errorDescription ?? payload?.error)
    case 429:
      let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
      return .rateLimited(retryAfter: retryAfter)
    default: return .server(status)
    }
  }

  private func shouldRetry(_ error: APIError) -> Bool {
    switch error {
    case .rateLimited, .server(500), .server(502), .server(503), .server(504): true
    default: false
    }
  }

  private func retryDelay(error: APIError, attempt: Int) -> TimeInterval {
    if case .rateLimited(let retryAfter) = error, let retryAfter {
      return min(max(retryAfter, 1), 60)
    }
    return min(pow(2, Double(attempt)), 8)
  }

  private func pagination(from response: HTTPURLResponse) -> TraktPagination {
    func int(_ name: String, fallback: Int) -> Int {
      response.value(forHTTPHeaderField: name).flatMap(Int.init) ?? fallback
    }
    return TraktPagination(
      page: int("X-Pagination-Page", fallback: 1),
      limit: int("X-Pagination-Limit", fallback: 0),
      pageCount: int("X-Pagination-Page-Count", fallback: 1),
      itemCount: int("X-Pagination-Item-Count", fallback: 0)
    )
  }

  private static func date(from value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let value = fractional.date(from: value) { return value }

    let standard = ISO8601DateFormatter()
    standard.formatOptions = [.withInternetDateTime]
    return standard.date(from: value)
  }

  private static func iso8601String(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}
