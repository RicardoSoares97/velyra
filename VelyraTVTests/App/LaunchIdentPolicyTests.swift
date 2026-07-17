import XCTest

@testable import VelyraTV

final class LaunchIdentPolicyTests: XCTestCase {
  func testColdLaunchShowsFullIdentOnce() {
    var policy = LaunchIdentPolicy()

    XCTAssertEqual(policy.consumePresentation(reduceMotion: false), .ribbonStrike)
    XCTAssertNil(policy.consumePresentation(reduceMotion: false))
  }

  func testReduceMotionUsesFadeOnce() {
    var policy = LaunchIdentPolicy()

    XCTAssertEqual(policy.consumePresentation(reduceMotion: true), .fade)
    XCTAssertNil(policy.consumePresentation(reduceMotion: true))
  }
}
