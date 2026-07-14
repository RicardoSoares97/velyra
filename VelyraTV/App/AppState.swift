import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  @Published var preferences: AppPreferences = .defaults
  @Published var isReady = false

  let iCloudAccount = ICloudAccountMonitor()
  let traktSession = TraktSession()

  private let preferencesStore: PreferencesStore
  private let automaticSetup = AutomaticSetupService()
  private var traktObservation: AnyCancellable?
  private var iCloudObservation: AnyCancellable?

  init(preferencesStore: PreferencesStore = ICloudPreferencesStore()) {
    self.preferencesStore = preferencesStore
    traktObservation = traktSession.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
    }

    iCloudObservation = NotificationCenter.default
      .publisher(
        for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
        object: NSUbiquitousKeyValueStore.default
      )
      .sink { [weak self] _ in
        Task { @MainActor in
          await self?.reloadPreferencesFromStore()
        }
      }
  }

  func bootstrap() async {
    preferences = await preferencesStore.load()
    await iCloudAccount.refresh()
    await traktSession.restore()
    isReady = true
  }

  private func reloadPreferencesFromStore() async {
    let remote = await preferencesStore.load()
    if remote != preferences {
      preferences = remote
    }
  }

  func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
    mutate(&preferences)
    let snapshot = preferences
    Task { await preferencesStore.save(snapshot) }
  }

  func applyAutomaticSetupAndFinish() {
    var configured = automaticSetup.configuredPreferences(from: preferences)
    configured.hasCompletedOnboarding = true
    preferences = configured
    let snapshot = configured
    Task { await preferencesStore.save(snapshot) }
  }

  func finishOnboarding() {
    updatePreferences { $0.hasCompletedOnboarding = true }
  }

  func resetOnboarding() {
    updatePreferences { $0.hasCompletedOnboarding = false }
  }

  func resetApplicationData() async {
    await traktSession.disconnect()
    preferences = .defaults
    await preferencesStore.save(.defaults)
  }
}
