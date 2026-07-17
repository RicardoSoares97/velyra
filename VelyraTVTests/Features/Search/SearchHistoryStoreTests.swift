import XCTest

@testable import VelyraTV

final class SearchHistoryStoreTests: XCTestCase {
  func testNormalizesDeduplicatesAndCapsHistory() async {
    let suite = "SearchHistoryStoreTests-\(UUID().uuidString)"
    defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
    let store = SearchHistoryStore(
      defaults: UserDefaults(suiteName: suite)!,
      maximumCount: 3
    )

    await store.add("  Dark  ")
    await store.add("dark")
    await store.add("Severance")
    await store.add("Silo")
    await store.add("Foundation")

    let values = await store.values()
    XCTAssertEqual(values, ["Foundation", "Silo", "Severance"])
  }
}
