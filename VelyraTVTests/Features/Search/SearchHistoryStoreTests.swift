import XCTest

@testable import VelyraTV

final class SearchHistoryStoreTests: XCTestCase {
  func testNormalizesDeduplicatesAndCapsHistory() async {
    let suite = "SearchHistoryStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = SearchHistoryStore(defaults: defaults, maximumCount: 3)

    await store.add("  Dark  ")
    await store.add("dark")
    await store.add("Severance")
    await store.add("Silo")
    await store.add("Foundation")

    let values = await store.values()
    XCTAssertEqual(values, ["Foundation", "Silo", "Severance"])
  }
}
