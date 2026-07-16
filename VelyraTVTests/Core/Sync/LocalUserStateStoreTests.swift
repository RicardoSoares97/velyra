import XCTest

@testable import VelyraTV

final class LocalUserStateStoreTests: XCTestCase {
  func testRoundTripAndDelete() async throws {
    let suiteName = "LocalUserStateStoreTests.\(UUID().uuidString)"
    let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }
    let store = LocalUserStateStore(defaults: suite)
    let fractionalDate = Date(timeIntervalSince1970: 1_725_000_000.123_456)
    let state = CloudUserState(
      schemaVersion: 2,
      preferences: .defaults,
      contentPlaybackPreferences: [:],
      updatedAt: fractionalDate
    )

    try await store.save(state)
    let loaded = try XCTUnwrap(try await store.load())
    XCTAssertEqual(loaded, state)
    XCTAssertEqual(loaded.updatedAt, fractionalDate)

    try await store.delete()
    XCTAssertNil(try await store.load())
  }

  func testCorruptPayloadIsDiscarded() async throws {
    let suiteName = "LocalUserStateStoreTests.\(UUID().uuidString)"
    let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { suite.removePersistentDomain(forName: suiteName) }
    suite.set(Data("invalid".utf8), forKey: LocalUserStateStore.storageKey)

    XCTAssertNil(try await LocalUserStateStore(defaults: suite).load())
    XCTAssertNil(suite.data(forKey: LocalUserStateStore.storageKey))
  }
}
