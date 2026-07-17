import XCTest

@testable import VelyraTV

final class CachedImageRequestTests: XCTestCase {
  func testSameURLAndTargetSizeHaveEqualIdentity() {
    let url = URL(string: "https://example.com/backdrop.jpg")!

    XCTAssertEqual(
      CachedImageRequest(url: url, targetSize: CGSize(width: 1_920, height: 1_080)),
      CachedImageRequest(url: url, targetSize: CGSize(width: 1_920, height: 1_080))
    )
  }

  func testTargetSizeParticipatesInIdentity() {
    let url = URL(string: "https://example.com/backdrop.jpg")!
    let prefetched = CachedImageRequest(
      url: url,
      targetSize: CGSize(width: 1_920, height: 1_080)
    )
    let larger = CachedImageRequest(
      url: url,
      targetSize: CGSize(width: 2_304, height: 1_296)
    )

    XCTAssertEqual(prefetched == larger, false)
  }
}
