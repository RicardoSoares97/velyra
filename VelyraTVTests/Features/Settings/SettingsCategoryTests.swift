import XCTest

@testable import VelyraTV

final class SettingsCategoryTests: XCTestCase {
  func testCategoryCentreHasStableProductOrder() {
    XCTAssertEqual(
      SettingsCategory.allCases,
      [
        .appearance,
        .experience,
        .playback,
        .audioSubtitles,
        .homeSearch,
        .accountsSync,
        .storageDiagnostics,
        .about,
      ]
    )
  }

  func testEveryCategoryHasLocalizedKeysAndSymbol() {
    for category in SettingsCategory.allCases {
      XCTAssertFalse(category.titleKey.isEmpty)
      XCTAssertTrue(category.summaryKey.hasPrefix("settings.category."))
      XCTAssertFalse(category.systemImage.isEmpty)
    }
  }

  func testHomeSectionsExposeDisplayKeysInsteadOfRawIdentifiers() {
    XCTAssertEqual(
      HomeSectionPreference.allCases.map(\.displayNameKey),
      [
        "home.section.continueWatching",
        "home.section.trendingSeries",
        "home.section.trendingMovies",
        "home.section.topSeries",
        "home.section.topMovies",
        "home.section.genres",
        "home.section.providers",
        "home.section.providerCollections",
      ]
    )
  }
}
