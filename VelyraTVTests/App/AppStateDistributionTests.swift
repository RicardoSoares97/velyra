import XCTest

@testable import VelyraTV

@MainActor
final class AppStateDistributionTests: XCTestCase {
  func testLocalOnlyMonitorRemainsUnavailableAfterRefresh() async {
    let monitor = ICloudAccountMonitor.localOnly()
    await monitor.refresh()
    XCTAssertEqual(monitor.status, .unavailable)
  }

  func testSideloadContentPlaybackPreferenceSurvivesBootstrap() async throws {
    let suiteName = "AppStateDistributionTests.\(UUID().uuidString)"
    let cleanupDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    cleanupDefaults.removePersistentDomain(forName: suiteName)
    defer { cleanupDefaults.removePersistentDomain(forName: suiteName) }
    let stateStore = LocalUserStateStore(
      defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))
    )
    let contentKey = "movie:local-persistence"

    let firstAppState = AppState(
      distributionCapabilities: .sideload,
      preferencesStore: LocalPreferencesStore(
        defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))
      ),
      cloudUserStore: stateStore,
      iCloudAccount: .localOnly()
    )
    await firstAppState.bootstrap()
    firstAppState.updateContentPlaybackPreference(for: contentKey) {
      $0.audioLanguageCode = "pt"
    }

    var didPersist = false
    for _ in 0..<1_000 {
      if try await stateStore.load()?
        .contentPlaybackPreferences[contentKey]?
        .audioLanguageCode == "pt"
      {
        didPersist = true
        break
      }
      await Task.yield()
    }
    XCTAssertTrue(didPersist, "Timed out waiting for the local actor store to persist")

    let secondAppState = AppState(
      distributionCapabilities: .sideload,
      preferencesStore: LocalPreferencesStore(
        defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))
      ),
      cloudUserStore: LocalUserStateStore(
        defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))
      ),
      iCloudAccount: .localOnly()
    )
    await secondAppState.bootstrap()

    XCTAssertEqual(
      secondAppState.contentPlaybackPreference(for: contentKey)?.audioLanguageCode,
      "pt"
    )
  }
}
