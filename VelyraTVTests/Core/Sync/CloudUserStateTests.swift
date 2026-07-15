import XCTest

@testable import VelyraTV

final class CloudUserStateTests: XCTestCase {
  func testMergePreservesNewerIndependentPreferenceDomains() {
    let oldDate = Date(timeIntervalSince1970: 100)
    let localDate = Date(timeIntervalSince1970: 300)
    let remoteDate = Date(timeIntervalSince1970: 400)

    var localPreferences = AppPreferences()
    localPreferences.theme = .dark
    localPreferences.maximumResolution = .ultraHD

    var remotePreferences = AppPreferences()
    remotePreferences.theme = .light
    remotePreferences.maximumResolution = .hd
    remotePreferences.contentRegion = "US"

    let local = CloudUserState(
      schemaVersion: 2,
      preferences: localPreferences,
      preferenceDomainUpdatedAt: [
        CloudPreferenceDomain.appearance.rawValue: localDate,
        CloudPreferenceDomain.playback.rawValue: localDate,
        CloudPreferenceDomain.localization.rawValue: oldDate,
      ],
      contentPlaybackPreferences: [:],
      updatedAt: localDate
    )
    let remote = CloudUserState(
      schemaVersion: 2,
      preferences: remotePreferences,
      preferenceDomainUpdatedAt: [
        CloudPreferenceDomain.appearance.rawValue: oldDate,
        CloudPreferenceDomain.playback.rawValue: oldDate,
        CloudPreferenceDomain.localization.rawValue: remoteDate,
      ],
      contentPlaybackPreferences: [:],
      updatedAt: remoteDate
    )

    let merged = local.merging(with: remote)

    XCTAssertEqual(merged.preferences.theme, .dark)
    XCTAssertEqual(merged.preferences.maximumResolution, .ultraHD)
    XCTAssertEqual(merged.preferences.contentRegion, "US")
  }

  func testMergeUsesNewestPerContentPreference() {
    let oldDate = Date(timeIntervalSince1970: 100)
    let middleDate = Date(timeIntervalSince1970: 200)
    let newDate = Date(timeIntervalSince1970: 300)

    let local = CloudUserState(
      schemaVersion: 2,
      preferences: AppPreferences(),
      contentPlaybackPreferences: [
        "movie:1": ContentPlaybackPreference(
          audioLanguageCode: "en",
          subtitleLanguageCode: "pt-PT",
          subtitlesEnabled: true,
          preferredSourceAddonID: "addon-a",
          subtitleTimingOffset: 0,
          updatedAt: newDate
        )
      ],
      updatedAt: oldDate
    )
    let remote = CloudUserState(
      schemaVersion: 2,
      preferences: AppPreferences(),
      contentPlaybackPreferences: [
        "movie:1": ContentPlaybackPreference(
          audioLanguageCode: "fr",
          subtitleLanguageCode: "fr",
          subtitlesEnabled: false,
          preferredSourceAddonID: "addon-b",
          subtitleTimingOffset: 1,
          updatedAt: middleDate
        ),
        "show:2": ContentPlaybackPreference(
          audioLanguageCode: "es",
          subtitleLanguageCode: "pt-PT",
          subtitlesEnabled: true,
          preferredSourceAddonID: nil,
          subtitleTimingOffset: nil,
          updatedAt: middleDate
        ),
      ],
      updatedAt: middleDate
    )

    let merged = local.merging(with: remote)

    XCTAssertEqual(merged.contentPlaybackPreferences["movie:1"]?.audioLanguageCode, "en")
    XCTAssertEqual(merged.contentPlaybackPreferences["show:2"]?.audioLanguageCode, "es")
  }

  func testPlaybackPreferenceResetDoesNotRestoreOlderRemoteValues() {
    let oldDate = Date(timeIntervalSince1970: 100)
    let resetDate = Date(timeIntervalSince1970: 300)
    var local = CloudUserState(
      schemaVersion: 2,
      preferences: AppPreferences(),
      contentPlaybackPreferences: [:],
      updatedAt: oldDate
    )
    local.clearContentPlaybackPreferences(at: resetDate)

    let remote = CloudUserState(
      schemaVersion: 2,
      preferences: AppPreferences(),
      contentPlaybackPreferences: [
        "movie:1": ContentPlaybackPreference(
          audioLanguageCode: "en",
          subtitleLanguageCode: "pt-PT",
          subtitlesEnabled: true,
          preferredSourceAddonID: nil,
          subtitleTimingOffset: 0,
          updatedAt: oldDate
        )
      ],
      updatedAt: oldDate
    )

    let merged = local.merging(with: remote)

    XCTAssertTrue(merged.contentPlaybackPreferences.isEmpty)
    XCTAssertEqual(merged.contentPlaybackPreferencesResetAt, resetDate)
  }

  func testLegacyPayloadWithoutDomainDatesCanStillDecode() throws {
    let payload = """
      {
        "schemaVersion": 1,
        "preferences": {},
        "contentPlaybackPreferences": {},
        "updatedAt": 100
      }
      """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970

    let state = try decoder.decode(CloudUserState.self, from: payload)

    XCTAssertEqual(state.preferenceDomainUpdatedAt.count, CloudPreferenceDomain.allCases.count)
    XCTAssertEqual(
      state.preferenceDomainUpdatedAt[CloudPreferenceDomain.playback.rawValue],
      Date(timeIntervalSince1970: 100))
  }
}
