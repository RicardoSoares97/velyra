import XCTest

@testable import VelyraTV

final class AddonHealthMonitorTests: XCTestCase {
  func testCircuitBreakerOpensAfterThreeFailuresAndResetsAfterSuccess() async {
    let monitor = AddonHealthMonitor()
    let url = URL(string: "https://addon.test/manifest.json")!
    let now = Date(timeIntervalSince1970: 100)

    await monitor.recordFailure(url, now: now)
    await monitor.recordFailure(url, now: now)
    let degraded = await monitor.snapshot(for: url, now: now)
    XCTAssertEqual(degraded.state, .degraded)

    await monitor.recordFailure(url, now: now)
    let unavailable = await monitor.snapshot(for: url, now: now)
    let canRequest = await monitor.canRequest(url, now: now.addingTimeInterval(1))
    XCTAssertEqual(unavailable.state, .unavailable)
    XCTAssertFalse(canRequest)

    await monitor.recordSuccess(url, now: now.addingTimeInterval(60))
    let recovered = await monitor.snapshot(for: url, now: now.addingTimeInterval(60))
    XCTAssertEqual(recovered.state, .healthy)
    XCTAssertEqual(recovered.consecutiveFailures, 0)
  }
}
