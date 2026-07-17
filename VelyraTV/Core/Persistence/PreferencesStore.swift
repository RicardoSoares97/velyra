import Foundation

protocol PreferencesStore: Sendable {
  func load() async -> AppPreferences
  func save(_ preferences: AppPreferences) async
}

actor LocalPreferencesStore: PreferencesStore {
  private let defaults: UserDefaults
  private let key = "velyra.preferences.v1"
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() async -> AppPreferences {
    guard let data = defaults.data(forKey: key),
      let preferences = try? decoder.decode(AppPreferences.self, from: data)
    else {
      return .defaults
    }
    return preferences
  }

  func save(_ preferences: AppPreferences) async {
    guard let data = try? encoder.encode(preferences) else { return }
    defaults.set(data, forKey: key)
  }
}

actor ICloudPreferencesStore: PreferencesStore {
  private let localStore: LocalPreferencesStore
  private let cloudStore: NSUbiquitousKeyValueStore
  private let key = "velyra.preferences.v1"
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(
    localStore: LocalPreferencesStore = LocalPreferencesStore(),
    cloudStore: NSUbiquitousKeyValueStore = .default
  ) {
    self.localStore = localStore
    self.cloudStore = cloudStore
    cloudStore.synchronize()
  }

  func load() async -> AppPreferences {
    let localPreferences = await localStore.load()
    guard localPreferences.iCloudSyncEnabled else { return localPreferences }

    if let data = cloudStore.data(forKey: key),
      let cloudPreferences = try? decoder.decode(AppPreferences.self, from: data)
    {
      await localStore.save(cloudPreferences)
      return cloudPreferences
    }
    return localPreferences
  }

  func save(_ preferences: AppPreferences) async {
    await localStore.save(preferences)

    guard preferences.iCloudSyncEnabled,
      let data = try? encoder.encode(preferences)
    else { return }

    cloudStore.set(data, forKey: key)
    cloudStore.synchronize()
  }
}
