import XCTest

@testable import VelyraTV

final class MediaMetadataPolicyTests: XCTestCase {
  func testRatingsAreAttributedAndNormalized() throws {
    let rating = try XCTUnwrap(TMDBMetadataPolicy.ratings(value: 7.8, voteCount: 1250).first)
    XCTAssertEqual(rating.source, .tmdb)
    XCTAssertEqual(rating.normalizedValue, 7.8, accuracy: 0.001)
    XCTAssertEqual(rating.voteCount, 1250)
  }

  func testInvalidRatingIsOmitted() {
    XCTAssertTrue(TMDBMetadataPolicy.ratings(value: 0).isEmpty)
    XCTAssertTrue(TMDBMetadataPolicy.ratings(value: nil).isEmpty)
  }
}

extension MediaMetadataPolicyTests {
  func testPersonSearchPayloadCanExposeKnownForMedia() throws {
    let payload = #"""
      {
        "id": 1,
        "name": "Performer",
        "media_type": "person",
        "known_for": [
          {
            "id": 42,
            "title": "Known Film",
            "media_type": "movie",
            "genre_ids": [],
            "vote_average": 8.2
          }
        ]
      }
      """#.data(using: .utf8)!

    let person = try JSONDecoder().decode(TMDBMediaResult.self, from: payload)

    XCTAssertEqual(person.knownFor.count, 1)
    XCTAssertEqual(person.knownFor.first?.title, "Known Film")
    XCTAssertEqual(person.knownFor.first?.mediaType, "movie")
  }
}
