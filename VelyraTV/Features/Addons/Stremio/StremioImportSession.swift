import Foundation

protocol StremioImportSleeping: Sendable {
  func sleep(for duration: Duration) async throws
}

struct StremioTaskSleeper: StremioImportSleeping {
  func sleep(for duration: Duration) async throws {
    try await Task.sleep(for: duration)
  }
}

actor StremioImportSession {
  private let service: any StremioAddonImportServing
  private let sleeper: any StremioImportSleeping
  private let pollInterval: Duration
  private let maximumDuration: TimeInterval
  private var authKey: StremioAuthKey?

  init(
    service: any StremioAddonImportServing,
    sleeper: any StremioImportSleeping = StremioTaskSleeper(),
    pollInterval: Duration = .seconds(3),
    maximumDuration: TimeInterval = 120
  ) {
    self.service = service
    self.sleeper = sleeper
    self.pollInterval = pollInterval
    self.maximumDuration = maximumDuration
  }

  func fetchDescriptors(link: StremioLinkCode) async throws -> [StremioAddonDescriptor] {
    let startedAt = Date()

    while true {
      try Task.checkCancellation()
      let now = Date()
      guard now < link.expiresAt else {
        throw StremioImportError.expired
      }
      guard now.timeIntervalSince(startedAt) < maximumDuration else {
        throw StremioImportError.timedOut
      }

      switch try await service.readLink(code: link.code) {
      case .pending:
        try await sleeper.sleep(for: pollInterval)

      case .authorized(let key):
        authKey = key
        do {
          let descriptors = try await service.addonCollection(authKey: key)
          await cleanup()
          return descriptors
        } catch {
          await cleanup()
          throw error
        }
      }
    }
  }

  func hasAuthorizationMaterial() -> Bool {
    authKey != nil
  }

  private func cleanup() async {
    guard let key = authKey else { return }
    authKey = nil
    try? await service.logout(authKey: key)
  }
}
