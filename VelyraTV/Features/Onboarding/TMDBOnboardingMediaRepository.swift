import Foundation

actor TMDBOnboardingMediaRepository: OnboardingMediaProviding {
  private let provider: any TrendingMediaProviding
  private let cache: OnboardingMediaCache
  private let now: @Sendable () -> Date

  init(
    provider: any TrendingMediaProviding = TMDBAPIClient.shared,
    cache: OnboardingMediaCache = OnboardingMediaCache(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.provider = provider
    self.cache = cache
    self.now = now
  }

  func media(language: String, region: String) async -> [OnboardingMediaItem] {
    let loadedAt = now()
    let cacheState = await cache.load(language: language, region: region, now: loadedAt)
    let staleItems: [OnboardingMediaItem]?
    switch cacheState {
    case .fresh(let snapshot): return snapshot.items
    case .stale(let snapshot): staleItems = snapshot.items
    case .missing: staleItems = nil
    }

    async let series = Self.trending(
      provider: provider,
      kind: .series,
      language: language
    )
    async let movies = Self.trending(
      provider: provider,
      kind: .movie,
      language: language
    )
    let candidates = Self.interleave(series: await series, movies: await movies)
    guard !candidates.isEmpty else { return staleItems ?? [] }

    let selectedDay = Self.dayString(for: loadedAt)
    let seed = "\(selectedDay)|\(language)|\(region)"
    let startIndex = Self.stableIndex(for: seed, count: candidates.count)
    let rotated = Array(candidates[startIndex...]) + Array(candidates[..<startIndex])
    let selection = Array(rotated.prefix(2))
    await cache.save(
      OnboardingMediaSnapshot(
        language: language,
        region: region,
        selectedDay: selectedDay,
        loadedAt: loadedAt,
        items: selection
      )
    )
    return selection
  }

  static func stableIndex(for value: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    let hash = value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
      ($0 ^ UInt64($1)) &* 1_099_511_628_211
    }
    return Int(hash % UInt64(count))
  }

  static func interleave(
    series: [TMDBMediaResult],
    movies: [TMDBMediaResult]
  ) -> [OnboardingMediaItem] {
    let seriesItems = series.compactMap { mediaItem(from: $0, kind: .series) }
    let movieItems = movies.compactMap { mediaItem(from: $0, kind: .movie) }
    var values: [OnboardingMediaItem] = []
    var seriesIndex = 0
    var movieIndex = 0

    while seriesIndex < seriesItems.count || movieIndex < movieItems.count {
      if seriesIndex < seriesItems.count {
        values.append(seriesItems[seriesIndex])
        seriesIndex += 1
      }
      if movieIndex < movieItems.count {
        values.append(movieItems[movieIndex])
        movieIndex += 1
      }
    }

    return values
  }

  private static func trending(
    provider: any TrendingMediaProviding,
    kind: MediaKind,
    language: String
  ) async -> [TMDBMediaResult] {
    (try? await provider.trending(kind: kind, timeWindow: "day", language: language)) ?? []
  }

  private static func dayString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func mediaItem(
    from result: TMDBMediaResult,
    kind: MediaKind
  ) -> OnboardingMediaItem? {
    guard
      let backdropURL = TMDBConfiguration.imageURL(
        path: result.backdropPath,
        width: "original"
      )
    else { return nil }

    let title =
      switch kind {
      case .movie: result.title ?? result.name
      case .series: result.name ?? result.title
      }

    return OnboardingMediaItem(
      id: "tmdb-\(kind.rawValue)-\(result.id)",
      kind: kind,
      title: title ?? String(localized: "media.unknownTitle"),
      backdropURL: backdropURL
    )
  }
}
