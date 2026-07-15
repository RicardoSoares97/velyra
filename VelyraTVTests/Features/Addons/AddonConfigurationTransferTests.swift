import XCTest

@testable import VelyraTV

final class AddonConfigurationTransferTests: XCTestCase {
  func testConfigurationRoundTrip() throws {
    var preferences = AppPreferences()
    preferences.addonManifestURLs = ["https://one.test/manifest.json", "https://two.test/manifest.json"]
    preferences.disabledAddonManifestURLs = ["https://two.test/manifest.json"]
    preferences.addonPriority = ["https://two.test/manifest.json", "https://one.test/manifest.json"]

    let code = try AddonConfigurationTransfer.make(preferences: preferences).encodedCode()
    let decoded = try AddonConfigurationTransfer.decode(code: code)
    var imported = AppPreferences()
    decoded.applying(to: &imported)

    XCTAssertEqual(imported.addonManifestURLs, preferences.addonManifestURLs)
    XCTAssertEqual(imported.disabledAddonManifestURLs, preferences.disabledAddonManifestURLs)
    XCTAssertEqual(imported.addonPriority, preferences.addonPriority)
  }

  func testRejectsUnsupportedManifestScheme() throws {
    let value = AddonConfigurationTransfer(
      schemaVersion: 1,
      manifestURLs: ["ftp://unsafe.test/manifest.json"],
      disabledManifestURLs: [],
      priority: []
    )
    let code = try value.encodedCode()
    XCTAssertThrowsError(try AddonConfigurationTransfer.decode(code: code))
  }
}
