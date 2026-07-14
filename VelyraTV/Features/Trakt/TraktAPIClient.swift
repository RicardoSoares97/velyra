import Foundation

actor TraktAPIClient {
    enum APIError: Error {
        case notConfigured
        case invalidResponse
        case unauthorized
        case rateLimited
        case server(Int)
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func requestDeviceCode() async throws -> TraktDeviceCode {
        try ensureConfigured()
        return try await send(
            path: "/oauth/device/code",
            method: "POST",
            body: ["client_id": TraktConfiguration.clientID],
            authenticated: false
        )
    }

    func exchangeDeviceCode(_ code: String) async throws -> TraktToken {
        try ensureConfigured()
        let body = [
            "code": code,
            "client_id": TraktConfiguration.clientID,
            "client_secret": TraktConfiguration.clientSecret
        ]
        return try await send(
            path: "/oauth/device/token",
            method: "POST",
            body: body,
            authenticated: false
        )
    }

    func refresh(_ token: TraktToken) async throws -> TraktToken {
        let body = [
            "refresh_token": token.refreshToken,
            "client_id": TraktConfiguration.clientID,
            "client_secret": TraktConfiguration.clientSecret,
            "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
            "grant_type": "refresh_token"
        ]
        return try await send(
            path: "/oauth/token",
            method: "POST",
            body: body,
            authenticated: false
        )
    }

    func playback(token: TraktToken) async throws -> [TraktPlaybackItem] {
        try await send(path: "/sync/playback", token: token)
    }

    func scrobble(
        action: TraktScrobbleAction,
        payload: TraktScrobblePayload,
        token: TraktToken
    ) async throws {
        let _: EmptyResponse = try await send(
            path: "/scrobble/\(action.rawValue)",
            method: "POST",
            encodableBody: payload,
            token: token
        )
    }

    func get<Response: Decodable>(path: String, token: TraktToken) async throws -> Response {
        try await send(path: path, token: token)
    }

    func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        token: TraktToken
    ) async throws -> Response {
        try await send(path: path, method: "POST", encodableBody: body, token: token)
    }

    private func ensureConfigured() throws {
        guard TraktConfiguration.isConfigured else { throw APIError.notConfigured }
    }

    private func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: String]? = nil,
        authenticated: Bool = true,
        token: TraktToken? = nil
    ) async throws -> Response {
        let data = body.flatMap { try? encoder.encode($0) }
        return try await execute(path: path, method: method, body: data, authenticated: authenticated, token: token)
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        encodableBody: Body,
        token: TraktToken
    ) async throws -> Response {
        try await execute(
            path: path,
            method: method,
            body: try encoder.encode(encodableBody),
            authenticated: true,
            token: token
        )
    }

    private func execute<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool,
        token: TraktToken?
    ) async throws -> Response {
        try ensureConfigured()
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var request = URLRequest(url: TraktConfiguration.baseURL.appendingPathComponent(normalizedPath))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TraktConfiguration.apiVersion, forHTTPHeaderField: "trakt-api-version")
        request.setValue(TraktConfiguration.clientID, forHTTPHeaderField: "trakt-api-key")

        if authenticated, let token {
            request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            if Response.self == EmptyResponse.self, data.isEmpty {
                return EmptyResponse() as! Response
            }
            return try decoder.decode(Response.self, from: data)
        case 401: throw APIError.unauthorized
        case 429: throw APIError.rateLimited
        default: throw APIError.server(http.statusCode)
        }
    }
}

struct EmptyResponse: Codable {
    init() {}
}
