import Foundation

actor TMDBAPIClient {
  static let shared = TMDBAPIClient()

  enum APIError: Error {
    case notConfigured
    case invalidResponse
    case server(Int)
  }

  private let session: URLSession
  private let decoder = JSONDecoder()
  private struct CacheEntry: Sendable {
    let data: Data
    let loadedAt: Date
  }

  private let maximumResponseBytes: Int
  private let readAccessToken: String
  private var responseCache: [URL: CacheEntry] = [:]
  private var inFlight: [URL: Task<Data, Error>] = [:]

  init(
    session: URLSession = .shared,
    maximumResponseBytes: Int = 10_000_000,
    readAccessToken: String = TMDBConfiguration.readAccessToken
  ) {
    self.session = session
    self.maximumResponseBytes = maximumResponseBytes
    self.readAccessToken = readAccessToken
  }

  func search(query: String, language: String, page: Int = 1) async throws -> [TMDBMediaResult] {
    let response: TMDBPagedResponse<TMDBMediaResult> = try await get(
      path: "/search/multi",
      query: [
        URLQueryItem(name: "query", value: query),
        URLQueryItem(name: "language", value: language),
        URLQueryItem(name: "include_adult", value: "false"),
        URLQueryItem(name: "page", value: String(page)),
      ]
    )
    return response.results.flatMap { result in
      if result.mediaType == "movie" || result.mediaType == "tv" { return [result] }
      if result.mediaType == "person" {
        return result.knownFor.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
      }
      return []
    }
  }

  func trending(kind: MediaKind, timeWindow: String = "day", language: String) async throws
    -> [TMDBMediaResult]
  {
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
      URLQueryItem(name: "page", value: String(page)),
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
        URLQueryItem(name: "watch_region", value: region),
      ]
    )
    return response.results.sorted {
      ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max)
    }
  }

  func externalIDs(id: Int, kind: MediaKind) async throws -> TMDBExternalIDs {
    let mediaPath = kind == .movie ? "movie" : "tv"
    return try await get(path: "/\(mediaPath)/\(id)/external_ids", query: [])
  }

  func details(id: Int, kind: MediaKind, language: String) async throws -> TMDBMediaResult {
    let mediaPath = kind == .movie ? "movie" : "tv"
    return try await get(
      path: "/\(mediaPath)/\(id)",
      query: [URLQueryItem(name: "language", value: language)]
    )
  }

  func credits(id: Int, kind: MediaKind, language: String) async throws -> TMDBCreditsResponse {
    let mediaPath = kind == .movie ? "movie" : "tv"
    return try await get(
      path: "/\(mediaPath)/\(id)/credits",
      query: [URLQueryItem(name: "language", value: language)]
    )
  }

  func videos(id: Int, kind: MediaKind, language: String) async throws -> [TMDBVideo] {
    let mediaPath = kind == .movie ? "movie" : "tv"
    let response: TMDBVideoResponse = try await get(
      path: "/\(mediaPath)/\(id)/videos",
      query: [URLQueryItem(name: "language", value: language)]
    )
    return response.results.sorted { lhs, rhs in
      let left = (lhs.official == true ? 100 : 0) + (lhs.type == "Trailer" ? 20 : 0)
      let right = (rhs.official == true ? 100 : 0) + (rhs.type == "Trailer" ? 20 : 0)
      return left > right
    }
  }

  func recommendations(id: Int, kind: MediaKind, language: String, page: Int = 1) async throws
    -> [TMDBMediaResult]
  {
    let mediaPath = kind == .movie ? "movie" : "tv"
    let response: TMDBPagedResponse<TMDBMediaResult> = try await get(
      path: "/\(mediaPath)/\(id)/recommendations",
      query: [
        URLQueryItem(name: "language", value: language),
        URLQueryItem(name: "page", value: String(page)),
      ]
    )
    return response.results
  }

  func similar(id: Int, kind: MediaKind, language: String, page: Int = 1) async throws
    -> [TMDBMediaResult]
  {
    let mediaPath = kind == .movie ? "movie" : "tv"
    let response: TMDBPagedResponse<TMDBMediaResult> = try await get(
      path: "/\(mediaPath)/\(id)/similar",
      query: [
        URLQueryItem(name: "language", value: language),
        URLQueryItem(name: "page", value: String(page)),
      ]
    )
    return response.results
  }

  func watchProviders(id: Int, kind: MediaKind, region: String) async throws
    -> TMDBRegionWatchProviders?
  {
    let mediaPath = kind == .movie ? "movie" : "tv"
    let response: TMDBWatchProviderResponse = try await get(
      path: "/\(mediaPath)/\(id)/watch/providers",
      query: []
    )
    return response.results[region.uppercased()]
  }

  func seasonDetails(showID: Int, season: Int, language: String) async throws -> TMDBSeasonDetails {
    try await get(
      path: "/tv/\(showID)/season/\(season)",
      query: [URLQueryItem(name: "language", value: language)]
    )
  }

  func certification(id: Int, kind: MediaKind, region: String) async throws -> String? {
    if kind == .series {
      let response: TMDBContentRatingResponse = try await get(
        path: "/tv/\(id)/content_ratings",
        query: []
      )
      return response.results.first { $0.iso31661 == region.uppercased() }?.rating
    }

    let response: TMDBReleaseDateResponse = try await get(
      path: "/movie/\(id)/release_dates",
      query: []
    )
    return response.results
      .first { $0.iso31661 == region.uppercased() }?
      .releaseDates
      .compactMap(\.certification)
      .first { !$0.isEmpty }
  }

  func detailsBundle(
    id: Int,
    kind: MediaKind,
    language: String,
    region: String
  ) async -> TMDBDetailsBundle {
    async let detailsResult = try? details(id: id, kind: kind, language: language)
    async let externalResult = try? externalIDs(id: id, kind: kind)
    async let creditsResult = try? credits(id: id, kind: kind, language: language)
    async let videosResult = try? videos(id: id, kind: kind, language: language)
    async let recommendationsResult = try? recommendations(id: id, kind: kind, language: language)
    async let similarResult = try? similar(id: id, kind: kind, language: language)
    async let providersResult = try? watchProviders(id: id, kind: kind, region: region)
    async let certificationResult = try? certification(id: id, kind: kind, region: region)

    return await TMDBDetailsBundle(
      details: detailsResult,
      externalIDs: externalResult,
      credits: creditsResult,
      videos: videosResult ?? [],
      recommendations: recommendationsResult ?? [],
      similar: similarResult ?? [],
      providers: providersResult,
      certification: certificationResult ?? nil
    )
  }

  private func get<Response: Decodable>(path: String, query: [URLQueryItem]) async throws
    -> Response
  {
    guard !readAccessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw APIError.notConfigured
    }

    var components = URLComponents(
      url: TMDBConfiguration.baseURL.appendingPathComponent(
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = query
    guard let url = components?.url else { throw APIError.invalidResponse }

    var request = URLRequest(url: url)
    request.setValue(
      "Bearer \(readAccessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "accept")

    request.cachePolicy = .returnCacheDataElseLoad
    request.timeoutInterval = 25

    let data = try await responseData(for: request)
    return try decoder.decode(Response.self, from: data)
  }

  func clearCache() {
    responseCache.removeAll()
    inFlight.values.forEach { $0.cancel() }
    inFlight.removeAll()
  }

  private func responseData(for request: URLRequest) async throws -> Data {
    guard let url = request.url else { throw APIError.invalidResponse }
    purgeExpiredCache()
    if let cached = responseCache[url] { return cached.data }
    if let task = inFlight[url] { return try await task.value }

    let task = Task { try await performRequest(request) }
    inFlight[url] = task
    defer { inFlight[url] = nil }
    let data = try await task.value
    responseCache[url] = CacheEntry(data: data, loadedAt: Date())
    return data
  }

  private func performRequest(_ request: URLRequest) async throws -> Data {
    var attempt = 0
    while true {
      try Task.checkCancellation()
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
      if 200..<300 ~= http.statusCode {
        guard http.expectedContentLength <= Int64(maximumResponseBytes),
          data.count <= maximumResponseBytes
        else { throw APIError.invalidResponse }
        return data
      }
      if [429, 500, 502, 503, 504].contains(http.statusCode), attempt < 3 {
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
        let delay = min(max(retryAfter ?? pow(2, Double(attempt)), 1), 30)
        attempt += 1
        try await Task.sleep(for: .seconds(delay))
        continue
      }
      throw APIError.server(http.statusCode)
    }
  }

  private func purgeExpiredCache(now: Date = Date()) {
    responseCache = responseCache.filter { url, entry in
      now.timeIntervalSince(entry.loadedAt) < cacheLifetime(for: url)
    }
  }

  private func cacheLifetime(for url: URL) -> TimeInterval {
    let path = url.path
    if path.contains("/search/") { return 5 * 60 }
    if path.contains("/trending/") { return 10 * 60 }
    if path.contains("/discover/") { return 30 * 60 }
    if path.contains("/watch/providers") || path.contains("/genre/") { return 24 * 60 * 60 }
    if path.contains("/recommendations") || path.contains("/similar") { return 6 * 60 * 60 }
    return 24 * 60 * 60
  }
}
