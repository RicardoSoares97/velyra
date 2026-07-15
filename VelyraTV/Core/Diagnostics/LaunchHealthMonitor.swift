import Foundation

struct LaunchHealthSnapshot: Codable, Equatable, Sendable {
  let uncleanExitCount: Int
  let lastUncleanExitDetectedAt: Date?
}

actor LaunchHealthMonitor {
  static let shared = LaunchHealthMonitor()

  private enum Key {
    static let cleanShutdown = "velyra.launch.cleanShutdown.v1"
    static let uncleanExitCount = "velyra.launch.uncleanExitCount.v1"
    static let lastUncleanExitDetectedAt = "velyra.launch.lastUncleanExitDetectedAt.v1"
  }

  private let defaults: UserDefaults
  private var sessionIsRunning = false

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func beginSession(now: Date = Date()) {
    guard !sessionIsRunning else { return }
    if defaults.object(forKey: Key.cleanShutdown) != nil,
      !defaults.bool(forKey: Key.cleanShutdown)
    {
      defaults.set(defaults.integer(forKey: Key.uncleanExitCount) + 1, forKey: Key.uncleanExitCount)
      defaults.set(now, forKey: Key.lastUncleanExitDetectedAt)
    }
    defaults.set(false, forKey: Key.cleanShutdown)
    sessionIsRunning = true
  }

  func endSessionCleanly() {
    guard sessionIsRunning else { return }
    defaults.set(true, forKey: Key.cleanShutdown)
    sessionIsRunning = false
  }

  func snapshot() -> LaunchHealthSnapshot {
    LaunchHealthSnapshot(
      uncleanExitCount: defaults.integer(forKey: Key.uncleanExitCount),
      lastUncleanExitDetectedAt: defaults.object(forKey: Key.lastUncleanExitDetectedAt) as? Date
    )
  }

  func reset() {
    defaults.removeObject(forKey: Key.cleanShutdown)
    defaults.removeObject(forKey: Key.uncleanExitCount)
    defaults.removeObject(forKey: Key.lastUncleanExitDetectedAt)
    sessionIsRunning = false
  }
}
