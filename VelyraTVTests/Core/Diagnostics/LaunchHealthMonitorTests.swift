import XCTest

@testable import VelyraTV

final class LaunchHealthMonitorTests: XCTestCase {
  func testDetectsPreviousUncleanSessionOnlyOnce() async {
    let suite = "velyra.launch-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = LaunchHealthMonitor(defaults: defaults)
    await first.beginSession(now: Date(timeIntervalSince1970: 100))

    let second = LaunchHealthMonitor(defaults: defaults)
    await second.beginSession(now: Date(timeIntervalSince1970: 200))
    await second.beginSession(now: Date(timeIntervalSince1970: 300))

    let snapshot = await second.snapshot()
    XCTAssertEqual(snapshot.uncleanExitCount, 1)
    XCTAssertEqual(snapshot.lastUncleanExitDetectedAt, Date(timeIntervalSince1970: 200))
  }

  func testCleanSessionDoesNotIncrementCounter() async {
    let suite = "velyra.launch-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = LaunchHealthMonitor(defaults: defaults)
    await first.beginSession()
    await first.endSessionCleanly()

    let second = LaunchHealthMonitor(defaults: defaults)
    await second.beginSession()

    let snapshot = await second.snapshot()
    XCTAssertEqual(snapshot.uncleanExitCount, 0)
  }
}
