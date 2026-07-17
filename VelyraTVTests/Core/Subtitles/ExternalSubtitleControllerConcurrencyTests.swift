import AVFoundation
import XCTest

@testable import VelyraTV

final class ExternalSubtitleControllerConcurrencyTests: XCTestCase {
  private enum LoaderError: Error {
    case unavailable
  }

  @MainActor
  func testSupersededCueLoadCannotReplaceCurrentSubtitleState() async {
    let oldTrack = track(id: "old")
    let newTrack = track(id: "new")
    let loader = SuspendedCueLoader(suspendedTrackID: oldTrack.id)
    let controller = ExternalSubtitleController(cueLoader: loader.load)
    controller.configure(
      tracks: [oldTrack, newTrack],
      player: AVPlayer(),
      preferredLanguage: nil
    )

    let oldSelection = Task { await controller.select(oldTrack) }
    await loader.waitUntilSuspended()

    await controller.select(newTrack)
    XCTAssertEqual(controller.selectedTrackID, newTrack.id)
    XCTAssertEqual(controller.currentText, "new cue")

    loader.resume(with: [cue(text: "old cue")])
    await oldSelection.value

    XCTAssertEqual(controller.selectedTrackID, newTrack.id)
    XCTAssertEqual(controller.currentText, "new cue")
  }

  @MainActor
  func testSupersededCueLoadErrorCannotClearCurrentSubtitleState() async {
    let oldTrack = track(id: "old-error")
    let newTrack = track(id: "new-after-error")
    let loader = SuspendedCueLoader(suspendedTrackID: oldTrack.id)
    let controller = ExternalSubtitleController(cueLoader: loader.load)
    controller.configure(
      tracks: [oldTrack, newTrack],
      player: AVPlayer(),
      preferredLanguage: nil
    )

    let oldSelection = Task { await controller.select(oldTrack) }
    await loader.waitUntilSuspended()

    await controller.select(newTrack)
    XCTAssertEqual(controller.selectedTrackID, newTrack.id)
    XCTAssertEqual(controller.currentText, "new cue")
    XCTAssertNil(controller.errorMessage)

    loader.resume(throwing: LoaderError.unavailable)
    await oldSelection.value

    XCTAssertEqual(controller.selectedTrackID, newTrack.id)
    XCTAssertEqual(controller.currentText, "new cue")
    XCTAssertNil(controller.errorMessage)
  }

  private func track(id: String) -> ExternalSubtitleTrack {
    ExternalSubtitleTrack(
      id: id,
      url: URL(string: "https://subtitles.test/\(id).srt")!,
      languageCode: "en",
      displayName: id
    )
  }

  private func cue(text: String) -> ExternalSubtitleCue {
    ExternalSubtitleCue(start: 0, end: 60, text: text)
  }
}

@MainActor
private final class SuspendedCueLoader {
  private let suspendedTrackID: String
  private var suspension: CheckedContinuation<[ExternalSubtitleCue], any Error>?
  private var suspensionObserver: CheckedContinuation<Void, Never>?
  private var isSuspended = false

  init(suspendedTrackID: String) {
    self.suspendedTrackID = suspendedTrackID
  }

  func load(track: ExternalSubtitleTrack) async throws -> [ExternalSubtitleCue] {
    guard track.id == suspendedTrackID else {
      return [ExternalSubtitleCue(start: 0, end: 60, text: "new cue")]
    }

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

  func resume(with cues: [ExternalSubtitleCue]) {
    suspension?.resume(returning: cues)
    suspension = nil
  }

  func resume(throwing error: any Error) {
    suspension?.resume(throwing: error)
    suspension = nil
  }
}
