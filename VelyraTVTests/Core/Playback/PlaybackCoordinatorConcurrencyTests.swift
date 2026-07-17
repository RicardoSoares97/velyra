import AVFoundation
import Combine
import XCTest

@testable import VelyraTV

final class PlaybackCoordinatorConcurrencyTests: XCTestCase {
  private enum LoaderError: Error {
    case unavailable
  }

  @MainActor
  func testSupersededLoadCannotAutoplayOrReplaceCurrentItemAfterSelectionResumes() async {
    let oldURL = URL(fileURLWithPath: "/tmp/velyra-old.mp4")
    let newURL = URL(fileURLWithPath: "/tmp/velyra-new.mp4")
    let loader = SuspendedMediaGroupLoader(suspendedURL: oldURL)
    var playedItems: [AVPlayerItem?] = []
    let coordinator = PlaybackCoordinator(
      preferences: .defaults,
      mediaResolver: MediaSelectionResolver(groupLoader: loader.load),
      isPlayableLoader: { _ in true },
      play: { player in playedItems.append(player.currentItem) }
    )

    let oldLoad = Task {
      await coordinator.prepare(request(url: oldURL, id: "old"))
    }
    await loader.waitUntilSuspended()

    await coordinator.prepare(request(url: newURL, id: "new"))
    let currentItem = coordinator.player.currentItem
    let audioTracks = coordinator.audioTracks
    let subtitleTracks = coordinator.subtitleTracks
    XCTAssertEqual(coordinator.currentSource?.id, "new")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playedItems.count, 1)

    loader.resume()
    await oldLoad.value

    XCTAssertTrue(coordinator.player.currentItem === currentItem)
    XCTAssertEqual(coordinator.currentSource?.id, "new")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playedItems.count, 1)
    XCTAssertEqual(coordinator.audioTracks, audioTracks)
    XCTAssertEqual(coordinator.subtitleTracks, subtitleTracks)
  }

  @MainActor
  func testSupersededLoadFailureCannotTriggerFailover() async {
    let oldURL = URL(fileURLWithPath: "/tmp/velyra-old-error.mp4")
    let newURL = URL(fileURLWithPath: "/tmp/velyra-new-after-error.mp4")
    let loader = SuspendedIsPlayableLoader(suspendedURL: oldURL)
    var playCount = 0
    let coordinator = PlaybackCoordinator(
      preferences: .defaults,
      mediaResolver: MediaSelectionResolver(groupLoader: { _, _ in nil }),
      isPlayableLoader: loader.load,
      play: { _ in playCount += 1 }
    )

    let oldLoad = Task {
      await coordinator.prepare(request(url: oldURL, id: "old"))
    }
    await loader.waitUntilSuspended()

    await coordinator.prepare(request(url: newURL, id: "new"))
    let currentItem = coordinator.player.currentItem
    loader.resume(throwing: LoaderError.unavailable)
    await oldLoad.value

    XCTAssertTrue(coordinator.player.currentItem === currentItem)
    XCTAssertEqual(coordinator.currentSource?.id, "new")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playCount, 1)
    XCTAssertEqual(loader.requestedURLs, [oldURL, newURL])
  }

  @MainActor
  func testOldItemFailureCannotFailoverCurrentItemWithinSameGeneration() async throws {
    let oldURL = URL(fileURLWithPath: "/tmp/velyra-observer-old.mp4")
    let newURL = URL(fileURLWithPath: "/tmp/velyra-observer-new.mp4")
    let observer = ControlledItemFailureObserver()
    var preferences = AppPreferences.defaults
    preferences.automaticSourceSelection = false
    var playCount = 0
    let coordinator = PlaybackCoordinator(
      preferences: preferences,
      mediaResolver: MediaSelectionResolver(groupLoader: { _, _ in nil }),
      isPlayableLoader: { _ in true },
      play: { _ in playCount += 1 },
      failureObserverInstaller: observer.install
    )

    await coordinator.prepare(
      PlaybackRequest(
        title: "observer",
        sources: [
          PlaybackSource(id: "old", url: oldURL, displayName: "old", container: .mp4),
          PlaybackSource(id: "new", url: newURL, displayName: "new", container: .mp4),
        ]
      )
    )
    let oldItem = try XCTUnwrap(coordinator.player.currentItem)

    await observer.fail(item: oldItem)
    let currentItem = try XCTUnwrap(coordinator.player.currentItem)
    XCTAssertFalse(currentItem === oldItem)
    XCTAssertEqual(coordinator.currentSource?.id, "new")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playCount, 2)

    await observer.fail(item: oldItem)

    XCTAssertTrue(coordinator.player.currentItem === currentItem)
    XCTAssertEqual(coordinator.currentSource?.id, "new")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playCount, 2)
  }

  @MainActor
  func testReplacedItemRejectsQueuedFailureWhenGenerationAndSourceStillMatch() async throws {
    let url = URL(fileURLWithPath: "/tmp/velyra-observer-replaced.mp4")
    let observer = ControlledItemFailureObserver()
    var playCount = 0
    let coordinator = PlaybackCoordinator(
      preferences: .defaults,
      mediaResolver: MediaSelectionResolver(groupLoader: { _, _ in nil }),
      isPlayableLoader: { _ in true },
      play: { _ in playCount += 1 },
      failureObserverInstaller: observer.install
    )

    await coordinator.prepare(request(url: url, id: "same-source"))
    let oldItem = try XCTUnwrap(coordinator.player.currentItem)
    let replacement = AVPlayerItem(
      asset: AVURLAsset(url: URL(fileURLWithPath: "/tmp/velyra-replacement.mp4"))
    )
    coordinator.player.replaceCurrentItem(with: replacement)

    await observer.fail(item: oldItem)

    XCTAssertTrue(coordinator.player.currentItem === replacement)
    XCTAssertEqual(coordinator.currentSource?.id, "same-source")
    XCTAssertEqual(coordinator.state, .ready)
    XCTAssertEqual(playCount, 1)
  }

  @MainActor
  private func request(url: URL, id: String) -> PlaybackRequest {
    PlaybackRequest(
      title: id,
      sources: [PlaybackSource(id: id, url: url, displayName: id, container: .mp4)]
    )
  }
}

@MainActor
private final class SuspendedIsPlayableLoader {
  private let suspendedURL: URL
  private var suspension: CheckedContinuation<Bool, any Error>?
  private var suspensionObserver: CheckedContinuation<Void, Never>?
  private var isSuspended = false
  private(set) var requestedURLs: [URL] = []

  init(suspendedURL: URL) {
    self.suspendedURL = suspendedURL
  }

  func load(asset: AVAsset) async throws -> Bool {
    let url = (asset as? AVURLAsset)?.url
    if let url { requestedURLs.append(url) }
    guard url == suspendedURL else { return true }

    return try await withCheckedThrowingContinuation { continuation in
      suspension = continuation
      isSuspended = true
      suspensionObserver?.resume()
      suspensionObserver = nil
    }
  }

  func waitUntilSuspended() async {
    guard !isSuspended else { return }
    await withCheckedContinuation { continuation in
      suspensionObserver = continuation
    }
  }

  func resume(throwing error: any Error) {
    suspension?.resume(throwing: error)
    suspension = nil
  }
}

@MainActor
private final class ControlledItemFailureObserver {
  private var handlers: [ObjectIdentifier: @MainActor (Error?) async -> Void] = [:]

  func install(
    item: AVPlayerItem,
    handler: @escaping @MainActor (Error?) async -> Void
  ) -> AnyCancellable {
    handlers[ObjectIdentifier(item)] = handler
    return AnyCancellable {}
  }

  func fail(item: AVPlayerItem) async {
    await handlers[ObjectIdentifier(item)]?(nil)
  }
}

@MainActor
private final class SuspendedMediaGroupLoader {
  private let suspendedURL: URL
  private var suspension: CheckedContinuation<AVMediaSelectionGroup?, any Error>?
  private var suspensionObserver: CheckedContinuation<Void, Never>?
  private var isSuspended = false

  init(suspendedURL: URL) {
    self.suspendedURL = suspendedURL
  }

  func load(
    asset: AVAsset,
    characteristic: AVMediaCharacteristic
  ) async throws -> AVMediaSelectionGroup? {
    guard characteristic == .audible,
      (asset as? AVURLAsset)?.url == suspendedURL
    else { return nil }

    return try await withCheckedThrowingContinuation { continuation in
      suspension = continuation
      isSuspended = true
      suspensionObserver?.resume()
      suspensionObserver = nil
    }
  }

  func waitUntilSuspended() async {
    guard !isSuspended else { return }
    await withCheckedContinuation { continuation in
      suspensionObserver = continuation
    }
  }

  func resume() {
    suspension?.resume(returning: nil)
    suspension = nil
  }

  func resume(throwing error: any Error) {
    suspension?.resume(throwing: error)
    suspension = nil
  }
}
