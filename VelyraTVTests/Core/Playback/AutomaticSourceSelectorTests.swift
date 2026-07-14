import XCTest

@testable import VelyraTV

final class AutomaticSourceSelectorTests: XCTestCase {
  private let selector = AutomaticSourceSelector()

  func testPrefersCompatibleCached4KDolbySource() throws {
    let hls = PlaybackSource(
      id: "best",
      url: try XCTUnwrap(URL(string: "https://example.com/master.m3u8")),
      displayName: "4K Dolby Vision Atmos",
      container: .hls,
      resolutionHeight: 2160,
      bitrate: 24_000_000,
      dynamicRanges: [.dolbyVision],
      audioFormats: [.dolbyAtmos],
      isCached: true
    )
    let lowerQuality = PlaybackSource(
      id: "lower",
      url: try XCTUnwrap(URL(string: "https://example.com/movie.mp4")),
      displayName: "1080p",
      container: .mp4,
      resolutionHeight: 1080,
      bitrate: 8_000_000
    )

    XCTAssertEqual(
      selector.bestSource(from: [lowerQuality, hls], preferences: .defaults)?.id,
      "best"
    )
  }

  func testCompatibilityOutranksUnsupportedContainerLabels() throws {
    let direct = PlaybackSource(
      id: "direct",
      url: try XCTUnwrap(URL(string: "https://example.com/movie.m3u8")),
      displayName: "1080p HLS",
      container: .hls,
      resolutionHeight: 1080
    )
    let unsupported = PlaybackSource(
      id: "mkv",
      url: try XCTUnwrap(URL(string: "https://example.com/movie.mkv")),
      displayName: "4K Dolby Vision Atmos",
      container: .matroska,
      resolutionHeight: 2160,
      dynamicRanges: [.dolbyVision],
      audioFormats: [.dolbyAtmos]
    )

    XCTAssertEqual(
      selector.bestSource(from: [unsupported, direct], preferences: .defaults)?.id,
      "direct"
    )
  }

  func testRejectsLowQualityReleaseLabels() throws {
    let cam = PlaybackSource(
      id: "cam",
      url: try XCTUnwrap(URL(string: "https://example.com/cam.mp4")),
      displayName: "NEW MOVIE CAM",
      container: .mp4,
      resolutionHeight: 2160
    )
    let regular = PlaybackSource(
      id: "regular",
      url: try XCTUnwrap(URL(string: "https://example.com/regular.mp4")),
      displayName: "1080p WEB",
      container: .mp4,
      resolutionHeight: 1080
    )

    XCTAssertEqual(
      selector.bestSource(from: [cam, regular], preferences: .defaults)?.id,
      "regular"
    )
  }
}
