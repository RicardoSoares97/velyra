import Foundation

actor SearchHistoryStore {
  private let defaults: UserDefaults
  private let key = "velyra.search.history.v1"
  private let maximumCount: Int

  init(defaults: UserDefaults = .standard, maximumCount: Int = 12) {
    self.defaults = defaults
    self.maximumCount = maximumCount
  }

  func values() -> [String] {
    defaults.stringArray(forKey: key) ?? []
  }

  func add(_ query: String) {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count >= 2 else { return }
    var items = values().filter { $0.localizedCaseInsensitiveCompare(normalized) != .orderedSame }
    items.insert(normalized, at: 0)
    defaults.set(Array(items.prefix(maximumCount)), forKey: key)
  }

  func remove(_ query: String) {
    defaults.set(values().filter { $0 != query }, forKey: key)
  }

  func clear() { defaults.removeObject(forKey: key) }
}
