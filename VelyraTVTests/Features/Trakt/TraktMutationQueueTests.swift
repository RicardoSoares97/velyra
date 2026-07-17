import XCTest

@testable import VelyraTV

final class TraktMutationQueueTests: XCTestCase {
  func testLatestMutationForSameMediaReplacesPreviousMutation() async {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      "trakt-queue-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let queue = TraktMutationQueue(fileURL: file)
    let movie = TraktMovie(title: "Film", year: 2026, ids: TraktIDs(trakt: 99))
    let request = TraktSyncRequest(movies: [TraktSyncMovieReference(movie: movie)])

    await queue.enqueue(TraktPendingMutation(kind: .addWatchlist, request: request))
    await queue.enqueue(TraktPendingMutation(kind: .removeWatchlist, request: request))

    let values = await queue.all()
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.first?.kind, .removeWatchlist)
  }

  func testRetryAllClearsFailureState() async {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      "trakt-queue-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let queue = TraktMutationQueue(fileURL: file)
    let mutation = TraktPendingMutation(
      kind: .removePlayback,
      playbackID: 12,
      attemptCount: 9,
      lastAttemptAt: Date(),
      lastError: "offline"
    )
    await queue.enqueue(mutation)
    await queue.retryAll()

    let values = await queue.all()
    let value = values.first
    XCTAssertEqual(value?.attemptCount, 0)
    XCTAssertNil(value?.lastAttemptAt)
    XCTAssertNil(value?.lastError)
  }

  func testQueuePersistsAcrossActorInstances() async {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      "trakt-queue-\(UUID().uuidString).json"
    )
    defer { try? FileManager.default.removeItem(at: file) }
    let movie = TraktMovie(title: "Film", ids: TraktIDs(tmdb: 22))
    let request = TraktSyncRequest(movies: [TraktSyncMovieReference(movie: movie)])

    let writer = TraktMutationQueue(fileURL: file)
    await writer.enqueue(TraktPendingMutation(kind: .addCollection, request: request))

    let reader = TraktMutationQueue(fileURL: file)
    let values = await reader.all()
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.first?.kind, .addCollection)
  }

}
