import Foundation

actor TraktRequestGate {
  private var blockedUntil: Date?

  func waitIfNeeded(now: Date = Date()) async throws {
    guard let blockedUntil, blockedUntil > now else {
      self.blockedUntil = nil
      return
    }
    try await Task.sleep(for: .seconds(blockedUntil.timeIntervalSince(now)))
    self.blockedUntil = nil
  }

  func block(for interval: TimeInterval, now: Date = Date()) {
    let candidate = now.addingTimeInterval(min(max(interval, 1), 300))
    if let blockedUntil, blockedUntil >= candidate { return }
    blockedUntil = candidate
  }

  func reset() { blockedUntil = nil }
}
