import XCTest

@testable import VelyraTV

final class TopShelfSnapshotTests: XCTestCase {
  func testSemanticComparisonIgnoresOnlyUpdatedAt() {
    let item = snapshotItem(progress: 0.4)
    let first = TopShelfSnapshot(
      continueWatching: [item],
      recommendations: [],
      updatedAt: Date(timeIntervalSince1970: 1)
    )
    let later = TopShelfSnapshot(
      continueWatching: [item],
      recommendations: [],
      updatedAt: Date(timeIntervalSince1970: 99)
    )
    let changed = TopShelfSnapshot(
      continueWatching: [snapshotItem(progress: 0.8)],
      recommendations: [],
      updatedAt: later.updatedAt
    )

    XCTAssertTrue(first.hasSameContent(as: later))
    XCTAssertFalse(first.hasSameContent(as: changed))
  }

  func testStoreSkipsUnchangedWrite() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("snapshot.json")
    let store = TopShelfSnapshotStore(fileURL: fileURL)
    let snapshot = TopShelfSnapshot(
      continueWatching: [snapshotItem(progress: 0.4)],
      recommendations: [],
      updatedAt: Date()
    )

    let firstWrite = try await store.saveIfChanged(snapshot)
    let secondWrite = try await store.saveIfChanged(
      TopShelfSnapshot(
        continueWatching: snapshot.continueWatching,
        recommendations: [],
        updatedAt: Date().addingTimeInterval(30)
      )
    )

    XCTAssertTrue(firstWrite)
    XCTAssertFalse(secondWrite)
  }

  private func snapshotItem(progress: Double) -> TopShelfSnapshot.Item {
    TopShelfSnapshot.Item(
      id: "movie:1",
      title: "Film",
      subtitle: nil,
      kind: "movie",
      tmdbID: 1,
      traktID: nil,
      traktPlaybackID: nil,
      seasonNumber: nil,
      episodeNumber: nil,
      posterURL: URL(string: "https://example.com/poster.jpg"),
      backdropURL: nil,
      progress: progress
    )
  }
}
