import AVFoundation
import XCTest

@testable import VelyraTV

final class MediaSelectionResolverTests: XCTestCase {
  private enum LoaderError: Error {
    case unavailable
  }

  @MainActor
  func testAudioGroupFailureDoesNotPreventSubtitleResolution() async throws {
    var requestedCharacteristics: [AVMediaCharacteristic] = []
    let resolver = MediaSelectionResolver { _, characteristic in
      requestedCharacteristics.append(characteristic)
      if characteristic == .audible {
        throw LoaderError.unavailable
      }
      return nil
    }

    let result = try await resolver.resolve(
      item: inertPlayerItem(),
      originalLanguageCode: "en",
      subtitleLanguageCode: "en",
      preferences: .defaults
    )

    XCTAssertNil(result.audio)
    XCTAssertNil(result.subtitles)
    XCTAssertEqual(requestedCharacteristics, [.audible, .legible])
  }

  @MainActor
  func testSubtitleGroupFailureDoesNotDiscardMissingAudioGroup() async throws {
    var requestedCharacteristics: [AVMediaCharacteristic] = []
    let resolver = MediaSelectionResolver { _, characteristic in
      requestedCharacteristics.append(characteristic)
      if characteristic == .legible {
        throw LoaderError.unavailable
      }
      return nil
    }

    let result = try await resolver.resolve(
      item: inertPlayerItem(),
      originalLanguageCode: "en",
      subtitleLanguageCode: "en",
      preferences: .defaults
    )

    XCTAssertNil(result.audio)
    XCTAssertNil(result.subtitles)
    XCTAssertEqual(requestedCharacteristics, [.audible, .legible])
  }

  @MainActor
  func testMissingMediaSelectionGroupsResolveWithoutSelection() async throws {
    let resolver = MediaSelectionResolver { _, _ in nil }

    let result = try await resolver.resolve(
      item: inertPlayerItem(),
      originalLanguageCode: nil,
      subtitleLanguageCode: "en",
      preferences: .defaults
    )

    XCTAssertNil(result.audio)
    XCTAssertNil(result.subtitles)
  }

  @MainActor
  private func inertPlayerItem() -> AVPlayerItem {
    AVPlayerItem(asset: AVURLAsset(url: URL(fileURLWithPath: "/dev/null")))
  }
}
