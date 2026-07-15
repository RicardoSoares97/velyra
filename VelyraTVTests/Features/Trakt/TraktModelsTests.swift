import XCTest

@testable import VelyraTV

final class TraktModelsTests: XCTestCase {
  func testTokenRefreshUsesToleranceWindow() {
    let token = TraktToken(
      accessToken: "access",
      refreshToken: "refresh",
      tokenType: "bearer",
      scope: "public",
      expiresIn: 3600,
      createdAt: 1_000
    )

    XCTAssertFalse(
      token.needsRefresh(now: Date(timeIntervalSince1970: 1_100), tolerance: 100)
    )
    XCTAssertTrue(
      token.needsRefresh(now: Date(timeIntervalSince1970: 4_500), tolerance: 100)
    )
  }

  func testEpisodeStableIDIncludesParentShowAndEpisodeNumber() {
    let show = TraktShow(title: "Series", ids: TraktIDs(trakt: 50))
    let episode = TraktEpisode(season: 2, number: 4, ids: TraktIDs(trakt: 80))
    let reference = TraktMediaReference(show: show, episode: episode)

    XCTAssertEqual(reference.stableID, "show:trakt:50:s2e4")
  }

  func testScrobblePayloadClampsProgress() {
    let context = TraktPlaybackContext(
      reference: TraktMediaReference(
        movie: TraktMovie(title: "Film", ids: TraktIDs(trakt: 1))
      )
    )

    XCTAssertEqual(TraktScrobblePayload.make(context: context, progress: -10).progress, 0)
    XCTAssertEqual(TraktScrobblePayload.make(context: context, progress: 110).progress, 100)
  }
}
