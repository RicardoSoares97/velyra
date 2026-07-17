import XCTest

@testable import VelyraTV

final class OnboardingMediaCacheTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  func testFiveHourSnapshotIsFreshAndPreservesFractionalDate() async {
    let fixture = isolatedCache()
    defer { clearCache(fixture) }
    let value = snapshot(loadedAt: now.addingTimeInterval(-(5 * 60 * 60) + 0.123_456))

    await fixture.cache.save(value)
    let state = await fixture.cache.load(language: "en", region: "US", now: now)

    XCTAssertEqual(state, .fresh(value))
  }

  func testTwoDaySnapshotIsStale() async {
    let fixture = isolatedCache()
    defer { clearCache(fixture) }
    let value = snapshot(loadedAt: now.addingTimeInterval(-(2 * 24 * 60 * 60)))

    await fixture.cache.save(value)
    let state = await fixture.cache.load(language: "en", region: "US", now: now)

    XCTAssertEqual(state, .stale(value))
  }

  func testEightDaySnapshotIsMissingAndDeleted() async {
    let fixture = isolatedCache()
    defer { clearCache(fixture) }
    let value = snapshot(loadedAt: now.addingTimeInterval(-(8 * 24 * 60 * 60)))

    await fixture.cache.save(value)
    let state = await fixture.cache.load(language: "en", region: "US", now: now)
    let storedData = UserDefaults(suiteName: fixture.suiteName)!.data(
      forKey: OnboardingMediaCache.storageKey
    )

    XCTAssertEqual(state, .missing)
    XCTAssertEqual(storedData, nil)
  }

  func testCorruptSnapshotIsMissingAndDeleted() async {
    let fixture = isolatedCache()
    defer { clearCache(fixture) }
    UserDefaults(suiteName: fixture.suiteName)!.set(
      Data("invalid".utf8),
      forKey: OnboardingMediaCache.storageKey
    )

    let state = await fixture.cache.load(language: "en", region: "US", now: now)
    let storedData = UserDefaults(suiteName: fixture.suiteName)!.data(
      forKey: OnboardingMediaCache.storageKey
    )

    XCTAssertEqual(state, .missing)
    XCTAssertEqual(storedData, nil)
  }

  func testLocaleMismatchIsMissingWithoutDeletingOtherLocaleSnapshot() async {
    let fixture = isolatedCache()
    defer { clearCache(fixture) }
    let value = snapshot(loadedAt: now.addingTimeInterval(-(5 * 60 * 60)))

    await fixture.cache.save(value)
    let languageMismatch = await fixture.cache.load(language: "pt", region: "US", now: now)
    let regionMismatch = await fixture.cache.load(language: "en", region: "PT", now: now)
    let matchingLocale = await fixture.cache.load(language: "en", region: "US", now: now)

    XCTAssertEqual(languageMismatch, .missing)
    XCTAssertEqual(regionMismatch, .missing)
    XCTAssertEqual(matchingLocale, .fresh(value))
  }

  private func isolatedCache() -> CacheFixture {
    let suiteName = "OnboardingMediaCacheTests.\(UUID().uuidString)"
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

  private func snapshot(loadedAt: Date) -> OnboardingMediaSnapshot {
    OnboardingMediaSnapshot(
      language: "en",
      region: "US",
      selectedDay: "2023-11-14",
      loadedAt: loadedAt,
      items: [
        OnboardingMediaItem(
          id: "tmdb-series-1",
          kind: .series,
          title: "Series One",
          backdropURL: URL(string: "https://image.tmdb.org/t/p/original/series-1.jpg")!
        ),
        OnboardingMediaItem(
          id: "tmdb-movie-10",
          kind: .movie,
          title: "Movie One",
          backdropURL: URL(string: "https://image.tmdb.org/t/p/original/movie-10.jpg")!
        ),
      ]
    )
  }
}

private struct CacheFixture {
  let cache: OnboardingMediaCache
  let suiteName: String
}
