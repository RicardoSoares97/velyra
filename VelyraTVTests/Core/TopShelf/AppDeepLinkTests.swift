import XCTest

@testable import VelyraTV

final class AppDeepLinkTests: XCTestCase {
  func testTopShelfItemRoundTripsIntoMediaItem() throws {
    let item = TopShelfSnapshot.Item(
      id: "movie-42",
      title: "Cinema",
      subtitle: nil,
      kind: MediaKind.movie.rawValue,
      tmdbID: 42,
      traktID: 77,
      traktPlaybackID: 91,
      seasonNumber: 2,
      episodeNumber: 5,
      posterURL: nil,
      backdropURL: nil,
      progress: 37
    )

    let url = try XCTUnwrap(item.deepLinkURL)
    let media = try XCTUnwrap(AppDeepLinkParser.mediaItem(from: url))

    XCTAssertEqual(media.id, "movie-42")
    XCTAssertEqual(media.title, "Cinema")
    XCTAssertEqual(media.kind, .movie)
    XCTAssertEqual(media.tmdbID, 42)
    XCTAssertEqual(media.traktID, 77)
    XCTAssertEqual(media.traktPlaybackID, 91)
    XCTAssertEqual(media.seasonNumber, 2)
    XCTAssertEqual(media.episodeNumber, 5)
  }

  func testRejectsForeignScheme() {
    XCTAssertNil(
      AppDeepLinkParser.mediaItem(from: URL(string: "https://example.com/details?id=1&title=A")!))
  }
}
