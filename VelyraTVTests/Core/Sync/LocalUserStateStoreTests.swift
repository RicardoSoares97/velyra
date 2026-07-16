import XCTest

@testable import VelyraTV

final class LocalUserStateStoreTests: XCTestCase {
  func testRoundTripAndDelete() async throws {
    let suiteName = "LocalUserStateStoreTests.\(UUID().uuidString)"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    let storeDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    let store = LocalUserStateStore(defaults: storeDefaults)
    let fractionalDate = Date(timeIntervalSince1970: 1_725_000_000.123_456)
    let state = CloudUserState(
      schemaVersion: 2,
      preferences: .defaults,
      contentPlaybackPreferences: [:],
      updatedAt: fractionalDate
    )

    try await store.save(state)
    let storedState = try await store.load()
    let loaded = try XCTUnwrap(storedState)
    XCTAssertEqual(loaded, state)
    XCTAssertEqual(loaded.updatedAt, fractionalDate)

    await store.delete()
    let deletedState = try await store.load()
    XCTAssertNil(deletedState)
  }

  func testCorruptPayloadIsDiscarded() async throws {
    let suiteName = "LocalUserStateStoreTests.\(UUID().uuidString)"
    defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
    let seedDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    seedDefaults.set(Data("invalid".utf8), forKey: LocalUserStateStore.storageKey)

    let storeDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    let store = LocalUserStateStore(defaults: storeDefaults)
    let discardedState = try await store.load()
    XCTAssertNil(discardedState)
    let verificationDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    XCTAssertNil(verificationDefaults.data(forKey: LocalUserStateStore.storageKey))
  }
}
