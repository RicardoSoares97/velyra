import Foundation

@MainActor
final class PreferenceWriteCoordinator {
  typealias Sink = @Sendable (AppPreferences) async -> Void

  private let delay: Duration
  private let sink: Sink
  private var pending: AppPreferences?
  private var delayedTask: Task<Void, Never>?

  init(
    delay: Duration = .milliseconds(250),
    sink: @escaping Sink
  ) {
    self.delay = delay
    self.sink = sink
  }

  deinit {
    delayedTask?.cancel()
  }

  func schedule(_ snapshot: AppPreferences) {
    pending = snapshot
    delayedTask?.cancel()
    delayedTask = Task { [weak self, delay] in
      do {
        try await Task.sleep(for: delay)
      } catch {
        return
      }
      await self?.flush()
    }
  }

  func flush() async {
    delayedTask?.cancel()
    delayedTask = nil
    guard let snapshot = pending else { return }
    pending = nil
    await sink(snapshot)
  }

  func cancel() {
    delayedTask?.cancel()
    delayedTask = nil
    pending = nil
  }
}
