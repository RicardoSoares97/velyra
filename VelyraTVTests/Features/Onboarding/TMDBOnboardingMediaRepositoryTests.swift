import XCTest

@testable import VelyraTV

final class TMDBOnboardingMediaRepositoryTests: XCTestCase {
  func testFreshCacheReturnsWithoutCallingProvider() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let fixture = makeCache()
    defer { clearCache(fixture) }
    let cachedItems = [
      mediaItem(id: "cached-series", kind: .series),
      mediaItem(id: "cached-movie", kind: .movie),
    ]
    await fixture.cache.save(
      OnboardingMediaSnapshot(
        language: "en-US",
        region: "US",
        selectedDay: "2026-07-15",
        loadedAt: now,
        items: cachedItems
      )
    )
    let provider = StubTrendingProvider(responses: [:])
    let repository = TMDBOnboardingMediaRepository(
      provider: provider,
      cache: fixture.cache,
      now: { now }
    )

    let values = await repository.media(language: "en-US", region: "US")
    let receivedKinds = await provider.receivedKinds()

    XCTAssertEqual(values, cachedItems)
    XCTAssertEqual(receivedKinds, [])
  }

  func testSuccessfulRefreshReturnsTwoItemsAndSavesSnapshot() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let fixture = makeCache()
    defer { clearCache(fixture) }
    let provider = StubTrendingProvider(
      responses: [
        .series: .success([
          try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg"),
          try decodeResult(id: 2, title: "Series Two", backdrop: "/series-2.jpg"),
        ]),
        .movie: .success([
          try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
          try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
        ]),
      ]
    )
    let repository = TMDBOnboardingMediaRepository(
      provider: provider,
      cache: fixture.cache,
      now: { now }
    )

    let values = await repository.media(language: "en-US", region: "US")
    let receivedKinds = await provider.receivedKinds()

    XCTAssertEqual(values.count, 2)
    let savedState = await fixture.cache.load(language: "en-US", region: "US", now: now)
    XCTAssertEqual(
      savedState,
      .fresh(
        OnboardingMediaSnapshot(
          language: "en-US",
          region: "US",
          selectedDay: "2026-07-15",
          loadedAt: now,
          items: values
        )
      )
    )
    XCTAssertEqual(Set(receivedKinds), Set([.series, .movie]))
  }

  func testOneFailedEndpointReturnsTwoItemsFromOtherEndpoint() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let fixture = makeCache()
    defer { clearCache(fixture) }
    let provider = StubTrendingProvider(
      responses: [
        .series: .failure,
        .movie: .success([
          try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
          try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
          try decodeResult(id: 12, title: "Movie Three", backdrop: "/movie-3.jpg"),
        ]),
      ]
    )
    let repository = TMDBOnboardingMediaRepository(
      provider: provider,
      cache: fixture.cache,
      now: { now }
    )

    let values = await repository.media(language: "en-US", region: "US")
    let receivedKinds = await provider.receivedKinds()

    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(Set(values.map(\.kind)), Set([.movie]))
    XCTAssertEqual(Set(receivedKinds), Set([.series, .movie]))
  }

  func testBothFailuresReturnStaleCache() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let fixture = makeCache()
    defer { clearCache(fixture) }
    let staleItems = [
      mediaItem(id: "stale-series", kind: .series),
      mediaItem(id: "stale-movie", kind: .movie),
    ]
    await fixture.cache.save(
      OnboardingMediaSnapshot(
        language: "en-US",
        region: "US",
        selectedDay: "2026-07-14",
        loadedAt: now.addingTimeInterval(-(OnboardingMediaCache.freshLifetime + 1)),
        items: staleItems
      )
    )
    let provider = StubTrendingProvider(
      responses: [.series: .failure, .movie: .failure]
    )
    let repository = TMDBOnboardingMediaRepository(
      provider: provider,
      cache: fixture.cache,
      now: { now }
    )

    let values = await repository.media(language: "en-US", region: "US")
    let receivedKinds = await provider.receivedKinds()

    XCTAssertEqual(values, staleItems)
    XCTAssertEqual(Set(receivedKinds), Set([.series, .movie]))
  }

  func testBothFailuresWithoutCacheReturnEmpty() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let fixture = makeCache()
    defer { clearCache(fixture) }
    let provider = StubTrendingProvider(
      responses: [.series: .failure, .movie: .failure]
    )
    let repository = TMDBOnboardingMediaRepository(
      provider: provider,
      cache: fixture.cache,
      now: { now }
    )

    let values = await repository.media(language: "en-US", region: "US")
    let receivedKinds = await provider.receivedKinds()

    XCTAssertEqual(values, [])
    XCTAssertEqual(Set(receivedKinds), Set([.series, .movie]))
  }

  func testSameUTCDayLanguageAndRegionReturnSameTwoIDs() async throws {
    let now = try date("2026-07-15T12:00:00Z")
    let firstFixture = makeCache()
    let secondFixture = makeCache()
    defer {
      clearCache(firstFixture)
      clearCache(secondFixture)
    }
    let responses = try trendingResponses()
    let firstRepository = TMDBOnboardingMediaRepository(
      provider: StubTrendingProvider(responses: responses),
      cache: firstFixture.cache,
      now: { now }
    )
    let secondRepository = TMDBOnboardingMediaRepository(
      provider: StubTrendingProvider(responses: responses),
      cache: secondFixture.cache,
      now: { now }
    )

    let firstValues = await firstRepository.media(language: "en-US", region: "US")
    let secondValues = await secondRepository.media(language: "en-US", region: "US")

    XCTAssertEqual(firstValues.map(\.id), ["tmdb-series-2", "tmdb-movie-11"])
    XCTAssertEqual(secondValues.map(\.id), firstValues.map(\.id))
  }

  func testChangingUTCDayRotatesStartingPointDeterministically() async throws {
    let firstDay = try date("2026-07-15T12:00:00Z")
    let secondDay = try date("2026-07-16T12:00:00Z")
    let firstFixture = makeCache()
    let secondFixture = makeCache()
    defer {
      clearCache(firstFixture)
      clearCache(secondFixture)
    }
    let responses = try trendingResponses()
    let firstRepository = TMDBOnboardingMediaRepository(
      provider: StubTrendingProvider(responses: responses),
      cache: firstFixture.cache,
      now: { firstDay }
    )
    let secondRepository = TMDBOnboardingMediaRepository(
      provider: StubTrendingProvider(responses: responses),
      cache: secondFixture.cache,
      now: { secondDay }
    )

    let firstValues = await firstRepository.media(language: "en-US", region: "US")
    let secondValues = await secondRepository.media(language: "en-US", region: "US")

    XCTAssertEqual(firstValues.map(\.id), ["tmdb-series-2", "tmdb-movie-11"])
    XCTAssertEqual(secondValues.map(\.id), ["tmdb-movie-11", "tmdb-series-3"])
  }

  func testInterleaveAlternatesSeriesAndMoviesAndExcludesMissingBackdrops() throws {
    let series = [
      try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg"),
      try decodeResult(id: 2, title: "Series Two", backdrop: nil),
      try decodeResult(id: 3, title: "Series Three", backdrop: "/series-3.jpg"),
    ]
    let movies = [
      try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
      try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
    ]

    let values = TMDBOnboardingMediaRepository.interleave(series: series, movies: movies)

    XCTAssertEqual(
      values.map(\.id),
      ["tmdb-series-1", "tmdb-movie-10", "tmdb-series-3", "tmdb-movie-11"]
    )
  }

  func testInterleaveExhaustsRemainingSeries() throws {
    let series = [
      try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg"),
      try decodeResult(id: 2, title: "Series Two", backdrop: "/series-2.jpg"),
      try decodeResult(id: 3, title: "Series Three", backdrop: "/series-3.jpg"),
    ]
    let movies = [
      try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg")
    ]

    let values = TMDBOnboardingMediaRepository.interleave(series: series, movies: movies)

    XCTAssertEqual(
      values.map(\.id),
      ["tmdb-series-1", "tmdb-movie-10", "tmdb-series-2", "tmdb-series-3"]
    )
  }

  func testInterleaveExhaustsRemainingMovies() throws {
    let series = [
      try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg")
    ]
    let movies = [
      try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
      try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
      try decodeResult(id: 12, title: "Movie Three", backdrop: "/movie-3.jpg"),
    ]

    let values = TMDBOnboardingMediaRepository.interleave(series: series, movies: movies)

    XCTAssertEqual(
      values.map(\.id),
      ["tmdb-series-1", "tmdb-movie-10", "tmdb-movie-11", "tmdb-movie-12"]
    )
  }

  func testInterleaveUsesKindSpecificTitlesAndOriginalBackdropURLs() throws {
    let series = [
      try decodeResult(
        id: 1,
        title: "Series Movie Alias",
        name: "Preferred Series",
        backdrop: "/series.jpg"
      )
    ]
    let movies = [
      try decodeResult(
        id: 10,
        title: "Preferred Movie",
        name: "Movie Series Alias",
        backdrop: "/movie.jpg"
      )
    ]

    let values = TMDBOnboardingMediaRepository.interleave(series: series, movies: movies)

    XCTAssertEqual(values.map(\.title), ["Preferred Series", "Preferred Movie"])
    XCTAssertEqual(
      values.map(\.backdropURL.absoluteString),
      [
        "https://image.tmdb.org/t/p/original/series.jpg",
        "https://image.tmdb.org/t/p/original/movie.jpg",
      ]
    )
  }

  private func decodeResult(
    id: Int,
    title: String,
    name: String? = nil,
    backdrop: String?
  ) throws -> TMDBMediaResult {
    var object: [String: Any] = [
      "id": id,
      "name": name ?? title,
      "title": title,
      "genre_ids": [],
    ]
    object["backdrop_path"] = backdrop ?? NSNull()
    return try JSONDecoder().decode(
      TMDBMediaResult.self,
      from: JSONSerialization.data(withJSONObject: object)
    )
  }

  private func date(_ value: String) throws -> Date {
    try XCTUnwrap(ISO8601DateFormatter().date(from: value))
  }

  private func makeCache() -> CacheFixture {
    let suiteName = "TMDBOnboardingMediaRepositoryTests.\(UUID().uuidString)"
    UserDefaults(suiteName: suiteName)!.removePersistentDomain(forName: suiteName)
    return CacheFixture(
      cache: OnboardingMediaCache(defaults: UserDefaults(suiteName: suiteName)!),
      suiteName: suiteName
    )
  }

  private func clearCache(_ fixture: CacheFixture) {
    UserDefaults(suiteName: fixture.suiteName)!.removePersistentDomain(
      forName: fixture.suiteName
    )
  }

  private func mediaItem(id: String, kind: MediaKind) -> OnboardingMediaItem {
    OnboardingMediaItem(
      id: id,
      kind: kind,
      title: id,
      backdropURL: URL(string: "https://example.com/\(id).jpg")!
    )
  }

  private func trendingResponses() throws -> [MediaKind: StubTrendingProvider.Response] {
    [
      .series: .success([
        try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg"),
        try decodeResult(id: 2, title: "Series Two", backdrop: "/series-2.jpg"),
        try decodeResult(id: 3, title: "Series Three", backdrop: "/series-3.jpg"),
      ]),
      .movie: .success([
        try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
        try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
        try decodeResult(id: 12, title: "Movie Three", backdrop: "/movie-3.jpg"),
      ]),
    ]
  }
}

private struct CacheFixture {
  let cache: OnboardingMediaCache
  let suiteName: String
}

private actor StubTrendingProvider: TrendingMediaProviding {
  enum Response: Sendable {
    case success([TMDBMediaResult])
    case failure
  }

  private let responses: [MediaKind: Response]
  private var kinds: [MediaKind] = []

  init(responses: [MediaKind: Response]) {
    self.responses = responses
  }

  func trending(kind: MediaKind, timeWindow: String, language: String) async throws
    -> [TMDBMediaResult]
  {
    kinds.append(kind)
    switch responses[kind] ?? .failure {
    case .success(let values): return values
    case .failure: throw StubError.failed
    }
  }

  func receivedKinds() -> [MediaKind] {
    kinds
  }
}

private enum StubError: Error {
  case failed
}
