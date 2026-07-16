import Foundation

actor LocalUserStateStore: CloudUserStateStoring {
  static let storageKey = "velyra.user-state.v2"

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

  func load() throws -> CloudUserState? {
    guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
    guard let state = try? decoder.decode(CloudUserState.self, from: data) else {
      defaults.removeObject(forKey: Self.storageKey)
      return nil
    }
    return state
  }

  func save(_ state: CloudUserState) throws {
    defaults.set(try encoder.encode(state), forKey: Self.storageKey)
  }

  func delete() {
    defaults.removeObject(forKey: Self.storageKey)
  }
}
