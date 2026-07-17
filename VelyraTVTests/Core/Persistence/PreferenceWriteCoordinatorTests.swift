import XCTest

@testable import VelyraTV

final class PreferenceWriteCoordinatorTests: XCTestCase {
  @MainActor
  func testFlushWritesOnlyLatestScheduledSnapshot() async {
    let recorder = PreferenceSnapshotRecorder()
    let coordinator = PreferenceWriteCoordinator(
      delay: .seconds(60),
      sink: { snapshot in await recorder.record(snapshot) }
    )
    var first = AppPreferences.defaults
    first.backgroundBlurRadius = 2
    var second = first
    second.backgroundBlurRadius = 5
    var latest = second
    latest.backgroundBlurRadius = 8

    coordinator.schedule(first)
    coordinator.schedule(second)
    coordinator.schedule(latest)
    await coordinator.flush()
    let values = await recorder.values()

    XCTAssertEqual(values, [latest])
  }

  @MainActor
  func testCancelDropsPendingSnapshot() async {
    let recorder = PreferenceSnapshotRecorder()
    let coordinator = PreferenceWriteCoordinator(
      delay: .seconds(60),
      sink: { snapshot in await recorder.record(snapshot) }
    )

    coordinator.schedule(.defaults)
    coordinator.cancel()
    await coordinator.flush()
    let values = await recorder.values()

    XCTAssertTrue(values.isEmpty)
  }
}

private actor PreferenceSnapshotRecorder {
  private var snapshots: [AppPreferences] = []

  func record(_ snapshot: AppPreferences) {
    snapshots.append(snapshot)
  }

  func values() -> [AppPreferences] {
    snapshots
  }
}
