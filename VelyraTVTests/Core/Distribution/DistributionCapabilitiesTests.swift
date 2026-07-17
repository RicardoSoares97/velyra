import XCTest

@testable import VelyraTV

final class DistributionCapabilitiesTests: XCTestCase {
  func testFullEditionEnablesAppleCloudAndTopShelf() {
    XCTAssertTrue(DistributionCapabilities.full.supportsICloudPreferences)
    XCTAssertTrue(DistributionCapabilities.full.supportsCloudKit)
    XCTAssertTrue(DistributionCapabilities.full.supportsTopShelf)
    XCTAssertFalse(DistributionCapabilities.full.isSideload)
  }

  func testSideloadEditionUsesOnlyLocalCapabilities() {
    XCTAssertFalse(DistributionCapabilities.sideload.supportsICloudPreferences)
    XCTAssertFalse(DistributionCapabilities.sideload.supportsCloudKit)
    XCTAssertFalse(DistributionCapabilities.sideload.supportsTopShelf)
    XCTAssertTrue(DistributionCapabilities.sideload.isSideload)
  }

  func testUnsignedTestHostUsesOnlyLocalCapabilities() {
    let capabilities = DistributionCapabilities.current(
      environment: ["VELYRA_TEST_HOST": "1"]
    )

    XCTAssertEqual(capabilities, .sideload)
  }
}
