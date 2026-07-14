import XCTest

@testable import VelyraTV

final class AddonStreamPlaybackMapperTests: XCTestCase {
  func testExtractsPlaybackSignalsConservatively() throws {
    let stream = AddonStream(
      name: "Provider",
      title: "4K Dolby Vision Atmos · 24 Mbps · Seeders: 42 · Cached",
      url: try XCTUnwrap(URL(string: "https://example.com/master.m3u8")),
      externalURL: nil,
      infoHash: nil,
      fileIdx: nil,
      behaviorHints: nil
    )

    let source = try XCTUnwrap(
      AddonStreamPlaybackMapper().playbackSources(from: [stream]).first
    )

    XCTAssertEqual(source.container, .hls)
    XCTAssertEqual(source.resolutionHeight, 2160)
    XCTAssertEqual(source.bitrate, 24_000_000)
    XCTAssertTrue(source.dynamicRanges.contains(.dolbyVision))
    XCTAssertTrue(source.audioFormats.contains(.dolbyAtmos))
    XCTAssertTrue(source.isCached)
    XCTAssertEqual(source.seeders, 42)
  }
}
