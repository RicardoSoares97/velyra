import CloudKit
import Foundation

enum CloudPreferenceDomain: String, CaseIterable, Codable, Sendable {
  case onboarding
  case appearance
  case localization
  case cloud
  case playback
  case addons
  case home
  case privacy
}

struct ContentPlaybackPreference: Codable, Equatable, Sendable {
  var audioLanguageCode: String?
  var subtitleLanguageCode: String?
  var subtitlesEnabled: Bool?
  var preferredSourceAddonID: String?
  var subtitleTimingOffset: Double?
  var updatedAt: Date
}

struct CloudUserState: Codable, Equatable, Sendable {
  var schemaVersion: Int
  var preferences: AppPreferences
  var preferenceDomainUpdatedAt: [String: Date]
  var contentPlaybackPreferences: [String: ContentPlaybackPreference]
  var contentPlaybackPreferencesResetAt: Date?
  var updatedAt: Date

  init(
    schemaVersion: Int,
    preferences: AppPreferences,
    preferenceDomainUpdatedAt: [String: Date]? = nil,
    contentPlaybackPreferences: [String: ContentPlaybackPreference],
    contentPlaybackPreferencesResetAt: Date? = nil,
    updatedAt: Date
  ) {
    self.schemaVersion = schemaVersion
    self.preferences = preferences
    self.preferenceDomainUpdatedAt =
      preferenceDomainUpdatedAt
      ?? Dictionary(
        uniqueKeysWithValues: CloudPreferenceDomain.allCases.map { ($0.rawValue, updatedAt) })
    self.contentPlaybackPreferences = contentPlaybackPreferences
    self.contentPlaybackPreferencesResetAt = contentPlaybackPreferencesResetAt
    self.updatedAt = updatedAt
  }

  static func initial(preferences: AppPreferences) -> CloudUserState {
    let now = Date()
    return CloudUserState(
      schemaVersion: 2,
      preferences: preferences,
      contentPlaybackPreferences: [:],
      updatedAt: now
    )
  }

  mutating func markPreferenceChanges(
    from previous: AppPreferences,
    to current: AppPreferences,
    at date: Date = Date()
  ) {
    for domain in current.changedCloudDomains(comparedTo: previous) {
      preferenceDomainUpdatedAt[domain.rawValue] = date
    }
    preferences = current
    updatedAt = max(updatedAt, date)
    schemaVersion = max(schemaVersion, 2)
  }

  func merging(with other: CloudUserState) -> CloudUserState {
    var mergedPreferences = preferences
    var mergedDomainDates: [String: Date] = [:]

    for domain in CloudPreferenceDomain.allCases {
      let localDate = preferenceDomainUpdatedAt[domain.rawValue] ?? updatedAt
      let remoteDate = other.preferenceDomainUpdatedAt[domain.rawValue] ?? other.updatedAt
      if remoteDate > localDate {
        mergedPreferences.applyCloudDomain(domain, from: other.preferences)
        mergedDomainDates[domain.rawValue] = remoteDate
      } else {
        mergedDomainDates[domain.rawValue] = localDate
      }
    }
    mergedPreferences.normalize()

    let resetAt = [contentPlaybackPreferencesResetAt, other.contentPlaybackPreferencesResetAt]
      .compactMap { $0 }
      .max()
    var mergedContent: [String: ContentPlaybackPreference] = [:]
    for (key, candidate) in contentPlaybackPreferences.merging(
      other.contentPlaybackPreferences,
      uniquingKeysWith: { local, remote in
        local.updatedAt >= remote.updatedAt ? local : remote
      }
    ) {
      if let resetAt, candidate.updatedAt <= resetAt { continue }
      mergedContent[key] = candidate
    }

    return CloudUserState(
      schemaVersion: max(max(schemaVersion, other.schemaVersion), 2),
      preferences: mergedPreferences,
      preferenceDomainUpdatedAt: mergedDomainDates,
      contentPlaybackPreferences: mergedContent,
      contentPlaybackPreferencesResetAt: resetAt,
      updatedAt: max(updatedAt, other.updatedAt)
    )
  }

  mutating func clearContentPlaybackPreferences(at date: Date = Date()) {
    contentPlaybackPreferences = [:]
    contentPlaybackPreferencesResetAt = date
    updatedAt = max(updatedAt, date)
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case preferences
    case preferenceDomainUpdatedAt
    case contentPlaybackPreferences
    case contentPlaybackPreferencesResetAt
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    preferences = try container.decode(AppPreferences.self, forKey: .preferences)
    contentPlaybackPreferences =
      try container.decodeIfPresent(
        [String: ContentPlaybackPreference].self,
        forKey: .contentPlaybackPreferences
      ) ?? [:]
    contentPlaybackPreferencesResetAt = try container.decodeIfPresent(
      Date.self,
      forKey: .contentPlaybackPreferencesResetAt
    )
    let decodedUpdatedAt =
      try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    updatedAt = decodedUpdatedAt
    let fallbackDomainDates = Dictionary(
      uniqueKeysWithValues: CloudPreferenceDomain.allCases.map {
        ($0.rawValue, decodedUpdatedAt)
      }
    )
    preferenceDomainUpdatedAt =
      try container.decodeIfPresent([String: Date].self, forKey: .preferenceDomainUpdatedAt)
      ?? fallbackDomainDates
  }
}

extension AppPreferences {
  fileprivate func changedCloudDomains(comparedTo previous: AppPreferences) -> Set<
    CloudPreferenceDomain
  > {
    var domains = Set<CloudPreferenceDomain>()
    for domain in CloudPreferenceDomain.allCases {
      var projected = previous
      projected.applyCloudDomain(domain, from: self)
      if projected != previous { domains.insert(domain) }
    }
    return domains
  }

  fileprivate mutating func applyCloudDomain(
    _ domain: CloudPreferenceDomain,
    from source: AppPreferences
  ) {
    switch domain {
    case .onboarding:
      hasCompletedOnboarding = source.hasCompletedOnboarding
    case .appearance:
      theme = source.theme
      backgroundVideoEnabled = source.backgroundVideoEnabled
      autoplayPreviews = source.autoplayPreviews
      backgroundBlurRadius = source.backgroundBlurRadius
      backgroundOverlayOpacity = source.backgroundOverlayOpacity
    case .localization:
      language = source.language
      contentRegion = source.contentRegion
    case .cloud:
      iCloudSyncEnabled = source.iCloudSyncEnabled
    case .playback:
      preferredAudioLanguage = source.preferredAudioLanguage
      preferredAudioLanguageCode = source.preferredAudioLanguageCode
      secondaryAudioLanguageCode = source.secondaryAudioLanguageCode
      preferredSubtitleLanguage = source.preferredSubtitleLanguage
      preferredSubtitleLanguageCode = source.preferredSubtitleLanguageCode
      secondarySubtitleLanguageCode = source.secondarySubtitleLanguageCode
      subtitlesEnabledByDefault = source.subtitlesEnabledByDefault
      subtitleTextSize = source.subtitleTextSize
      subtitleVerticalOffset = source.subtitleVerticalOffset
      subtitleBackgroundOpacity = source.subtitleBackgroundOpacity
      automaticSourceSelection = source.automaticSourceSelection
      automaticLanguageSelection = source.automaticLanguageSelection
      maximumResolution = source.maximumResolution
      preferDirectPlay = source.preferDirectPlay
      preferCachedSources = source.preferCachedSources
      preferDolbyVision = source.preferDolbyVision
      preferHDR = source.preferHDR
      preferDolbyAtmos = source.preferDolbyAtmos
      automaticSourceFailover = source.automaticSourceFailover
    case .addons:
      addonManifestURLs = source.addonManifestURLs
      disabledAddonManifestURLs = source.disabledAddonManifestURLs
      addonPriority = source.addonPriority
    case .home:
      homeSectionOrder = source.homeSectionOrder
      hiddenHomeSections = source.hiddenHomeSections
    case .privacy:
      searchHistoryEnabled = source.searchHistoryEnabled
      diagnosticsEnabled = source.diagnosticsEnabled
    }
  }
}

protocol CloudUserStateStoring: Sendable {
  func load() async throws -> CloudUserState?
  func save(_ state: CloudUserState) async throws
  func delete() async throws
}

actor CloudKitUserStateStore: CloudUserStateStoring {
  enum StoreError: Error {
    case invalidPayload
  }

  private let database: CKDatabase
  private let recordID = CKRecord.ID(recordName: "velyra-private-user-state")
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(containerIdentifier: String = "iCloud.pt.ricardosoares.velyra") {
    database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  func load() async throws -> CloudUserState? {
    do {
      let record = try await database.record(for: recordID)
      guard let data = record["payload"] as? Data else { throw StoreError.invalidPayload }
      return try decoder.decode(CloudUserState.self, from: data)
    } catch let error as CKError where error.code == .unknownItem {
      return nil
    }
  }

  func save(_ state: CloudUserState) async throws {
    var candidate = state
    var lastError: Error?

    for attempt in 0..<2 {
      let record: CKRecord
      do {
        record = try await database.record(for: recordID)
        if let payload = record["payload"] as? Data,
          let remote = try? decoder.decode(CloudUserState.self, from: payload)
        {
          candidate = candidate.merging(with: remote)
        }
      } catch let error as CKError where error.code == .unknownItem {
        record = CKRecord(recordType: "VelyraUserState", recordID: recordID)
      }

      record["payload"] = try encoder.encode(candidate) as CKRecordValue
      record["schemaVersion"] = candidate.schemaVersion as CKRecordValue
      record["updatedAt"] = candidate.updatedAt as CKRecordValue

      do {
        _ = try await database.save(record)
        return
      } catch let error as CKError where error.code == .serverRecordChanged && attempt == 0 {
        lastError = error
        continue
      } catch {
        throw error
      }
    }

    if let lastError { throw lastError }
  }

  func delete() async throws {
    do {
      _ = try await database.deleteRecord(withID: recordID)
    } catch let error as CKError where error.code == .unknownItem {
      return
    }
  }
}

actor InMemoryCloudUserStateStore: CloudUserStateStoring {
  private var state: CloudUserState?
  func load() -> CloudUserState? { state }
  func save(_ state: CloudUserState) { self.state = state }
  func delete() { state = nil }
}
