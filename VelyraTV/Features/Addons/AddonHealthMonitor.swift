import Foundation

enum AddonHealthState: String, Codable, Equatable, Sendable {
  case healthy
  case degraded
  case unavailable
}

struct AddonHealthSnapshot: Equatable, Sendable {
  let state: AddonHealthState
  let consecutiveFailures: Int
  let lastSuccessAt: Date?
  let lastFailureAt: Date?
  let nextRetryAt: Date?
}

actor AddonHealthMonitor {
  static let shared = AddonHealthMonitor()

  private struct Entry {
    var failures = 0
    var lastSuccessAt: Date?
    var lastFailureAt: Date?
    var nextRetryAt: Date?
  }

  private var entries: [URL: Entry] = [:]

  func canRequest(_ url: URL, now: Date = Date()) -> Bool {
    guard let retry = entries[url]?.nextRetryAt else { return true }
    return retry <= now
  }

  func recordSuccess(_ url: URL, now: Date = Date()) {
    var entry = entries[url] ?? Entry()
    entry.failures = 0
    entry.lastSuccessAt = now
    entry.nextRetryAt = nil
    entries[url] = entry
  }

  func recordFailure(_ url: URL, now: Date = Date()) {
    var entry = entries[url] ?? Entry()
    entry.failures += 1
    entry.lastFailureAt = now
    if entry.failures >= 3 {
      let delay = min(pow(2, Double(entry.failures - 3)) * 30, 900)
      entry.nextRetryAt = now.addingTimeInterval(delay)
    }
    entries[url] = entry
  }

  func snapshot(for url: URL, now: Date = Date()) -> AddonHealthSnapshot {
    let entry = entries[url] ?? Entry()
    let state: AddonHealthState
    if let retry = entry.nextRetryAt, retry > now {
      state = .unavailable
    } else if entry.failures > 0 {
      state = .degraded
    } else {
      state = .healthy
    }
    return AddonHealthSnapshot(
      state: state,
      consecutiveFailures: entry.failures,
      lastSuccessAt: entry.lastSuccessAt,
      lastFailureAt: entry.lastFailureAt,
      nextRetryAt: entry.nextRetryAt
    )
  }

  func reset(_ url: URL) { entries.removeValue(forKey: url) }

  func resetAll() { entries.removeAll() }
}
