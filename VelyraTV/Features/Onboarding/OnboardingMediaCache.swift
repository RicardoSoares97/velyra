import Foundation

enum OnboardingMediaCacheState: Equatable, Sendable {
  case fresh(OnboardingMediaSnapshot)
  case stale(OnboardingMediaSnapshot)
  case missing
}

actor OnboardingMediaCache {
  static let storageKey = "velyra.onboarding-media.v1"
  static let freshLifetime: TimeInterval = 6 * 60 * 60
  static let staleLifetime: TimeInterval = 7 * 24 * 60 * 60

  private let defaults: UserDefaults
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
  }

  func load(language: String, region: String, now: Date) -> OnboardingMediaCacheState {
    guard
      let data = defaults.data(forKey: Self.storageKey),
      let value = try? decoder.decode(OnboardingMediaSnapshot.self, from: data)
    else {
      defaults.removeObject(forKey: Self.storageKey)
      return .missing
    }
    guard value.language == language, value.region == region else { return .missing }

    let age = max(0, now.timeIntervalSince(value.loadedAt))
    if age <= Self.freshLifetime { return .fresh(value) }
    if age <= Self.staleLifetime { return .stale(value) }
    defaults.removeObject(forKey: Self.storageKey)
    return .missing
  }

  func save(_ snapshot: OnboardingMediaSnapshot) {
    guard let data = try? encoder.encode(snapshot) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  func clear() {
    defaults.removeObject(forKey: Self.storageKey)
  }
}
