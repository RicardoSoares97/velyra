import XCTest

@testable import VelyraTV

final class AppSectionTests: XCTestCase {
  func testSectionsHaveStableOrderAndMetadata() {
    XCTAssertEqual(AppSection.allCases, [.home, .search, .library, .addons, .settings])
    XCTAssertEqual(
      AppSection.allCases.map(\.titleKey),
      [
        "navigation.home",
        "navigation.search",
        "navigation.library",
        "navigation.addons",
        "navigation.settings",
      ]
    )
    XCTAssertEqual(Set(AppSection.allCases.map(\.rawValue)).count, AppSection.allCases.count)
    XCTAssertTrue(AppSection.allCases.allSatisfy { !$0.systemImage.isEmpty })
  }
}
