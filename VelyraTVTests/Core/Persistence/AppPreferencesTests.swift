import XCTest

@testable import VelyraTV

final class AppPreferencesTests: XCTestCase {
  func testNormalizeDeduplicatesAndKeepsKnownValues() {
    var preferences = AppPreferences()
    preferences.addonManifestURLs = [
      "https://a.test/manifest.json", "https://a.test/manifest.json",
      "https://b.test/manifest.json",
    ]
    preferences.disabledAddonManifestURLs = [
      "https://missing.test/manifest.json", "https://b.test/manifest.json",
    ]
    preferences.addonPriority = [
      "https://b.test/manifest.json", "https://missing.test/manifest.json",
    ]
    preferences.homeSectionOrder = [.trendingMovies, .trendingMovies]
    preferences.hiddenHomeSections = [.topMovies]
    preferences.backgroundBlurRadius = 99
    preferences.backgroundOverlayOpacity = 0
    preferences.subtitleVerticalOffset = 3
    preferences.subtitleBackgroundOpacity = -1

    preferences.normalize()

    XCTAssertEqual(
      preferences.addonManifestURLs,
      ["https://a.test/manifest.json", "https://b.test/manifest.json"])
    XCTAssertEqual(preferences.disabledAddonManifestURLs, ["https://b.test/manifest.json"])
    XCTAssertEqual(preferences.addonPriority.first, "https://b.test/manifest.json")
    XCTAssertEqual(Set(preferences.homeSectionOrder), Set(HomeSectionPreference.allCases))
    XCTAssertEqual(preferences.homeSectionOrder.count, HomeSectionPreference.allCases.count)
    XCTAssertEqual(preferences.backgroundBlurRadius, 20)
    XCTAssertEqual(preferences.backgroundOverlayOpacity, 0.2)
    XCTAssertEqual(preferences.subtitleVerticalOffset, 0.25)
    XCTAssertEqual(preferences.subtitleBackgroundOpacity, 0)
  }

  func testActiveAddonsRespectDisabledStateAndPriority() {
    var preferences = AppPreferences()
    preferences.addonManifestURLs = ["https://a.test", "https://b.test", "https://c.test"]
    preferences.disabledAddonManifestURLs = ["https://b.test"]
    preferences.addonPriority = ["https://c.test", "https://a.test", "https://b.test"]

    XCTAssertEqual(preferences.activeAddonManifestURLs, ["https://c.test", "https://a.test"])
  }

  func testGranularResetsDoNotEraseUnrelatedPreferences() {
    var preferences = AppPreferences()
    preferences.theme = .light
    preferences.preferDolbyVision = false
    preferences.preferredSubtitleLanguageCode = "fr"
    preferences.homeSectionOrder = [.topMovies]
    preferences.hiddenHomeSections = [.genres]
    preferences.addonManifestURLs = ["https://addon.test/manifest.json"]

    preferences.resetPlaybackPreferences()
    XCTAssertTrue(preferences.preferDolbyVision)
    XCTAssertNil(preferences.preferredSubtitleLanguageCode)
    XCTAssertEqual(preferences.theme, .light)
    XCTAssertEqual(preferences.addonManifestURLs.count, 1)

    preferences.resetHomePreferences()
    XCTAssertEqual(preferences.homeSectionOrder, HomeSectionPreference.allCases)
    XCTAssertTrue(preferences.hiddenHomeSections.isEmpty)
    XCTAssertEqual(preferences.theme, .light)

    preferences.resetAddonPreferences()
    XCTAssertTrue(preferences.addonManifestURLs.isEmpty)
    XCTAssertEqual(preferences.theme, .light)
  }

  func testDecodingOlderPreferencesUsesNewDefaults() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "hasCompletedOnboarding": true,
      "theme": "dark",
      "language": "pt-PT",
    ])

    let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

    XCTAssertTrue(decoded.hasCompletedOnboarding)
    XCTAssertEqual(decoded.theme, .dark)
    XCTAssertEqual(decoded.language, .portuguesePortugal)
    XCTAssertTrue(decoded.automaticSourceSelection)
    XCTAssertEqual(decoded.maximumResolution, .automatic)
    XCTAssertEqual(decoded.homeSectionOrder, HomeSectionPreference.allCases)
  }

}
