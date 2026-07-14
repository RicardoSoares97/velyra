import Foundation

actor TMDBAPIClient {
    enum APIError: Error {
        case notConfigured
        case invalidResponse
        case server(Int)
    }

    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func trending(kind: MediaKind, timeWindow: String = "day", language: String) async throws -> [TMDBMediaResult] {
        let mediaPath = kind == .movie ? "movie" : "tv"
        let response: TMDBPagedResponse<TMDBMediaResult> = try await get(
            path: "/trending/\(mediaPath)/\(timeWindow)",
            query: [URLQueryItem(name: "language", value: language)]
        )
        return response.results
    }

    func discover(
        kind: MediaKind,
        language: String,
        region: String,
        genreID: Int? = nil,
        providerID: Int? = nil,
        page: Int = 1
    ) async throws -> [TMDBMediaResult] {
        var query = [
            URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "watch_region", value: region),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "with_watch_monetization_types", value: "flatrate|free|ads"),
            URLQueryItem(name: "page", value: String(page))
        ]

        if let genreID {
            query.append(URLQueryItem(name: "with_genres", value: String(genreID)))
        }
        if let providerID {
            query.append(URLQueryItem(name: "with_watch_providers", value: String(providerID)))
        }

        let endpoint = kind == .movie ? "/discover/movie" : "/discover/tv"
        let response: TMDBPagedResponse<TMDBMediaResult> = try await get(path: endpoint, query: query)
        return response.results
    }

    func genres(kind: MediaKind, language: String) async throws -> [TMDBGenre] {
        let endpoint = kind == .movie ? "/genre/movie/list" : "/genre/tv/list"
        let response: TMDBGenreResponse = try await get(
            path: endpoint,
            query: [URLQueryItem(name: "language", value: language)]
        )
        return response.genres
    }

    func providers(kind: MediaKind, language: String, region: String) async throws -> [TMDBProvider] {
        let mediaPath = kind == .movie ? "movie" : "tv"
        let response: TMDBProviderResponse = try await get(
            path: "/watch/providers/\(mediaPath)",
            query: [
                URLQueryItem(name: "language", value: language),
                URLQueryItem(name: "watch_region", value: region)
            ]
        )
        return response.results.sorted {
            ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max)
        }
    }

    func details(id: Int, kind: MediaKind, language: String) async throws -> TMDBMediaResult {
        let mediaPath = kind == .movie ? "movie" : "tv"
        return try await get(
            path: "/\(mediaPath)/\(id)",
            query: [URLQueryItem(name: "language", value: language)]
        )
    }

    private func get<Response: Decodable>(path: String, query: [URLQueryItem]) async throws -> Response {
        guard TMDBConfiguration.isConfigured else { throw APIError.notConfigured }

        var components = URLComponents(
            url: TMDBConfiguration.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(TMDBConfiguration.readAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard 200..<300 ~= http.statusCode else { throw APIError.server(http.statusCode) }
        return try decoder.decode(Response.self, from: data)
    }
}
