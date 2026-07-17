import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  @Published var preferences: AppPreferences = .defaults
  @Published var isReady = false
  @Published private(set) var cloudState: CloudUserState = .initial(preferences: .defaults)
  @Published private(set) var cloudSyncError: String?
  @Published var deepLinkedItem: MediaItem?

  let distributionCapabilities: DistributionCapabilities
  let iCloudAccount: ICloudAccountMonitor
  let traktSession = TraktSession()
  let launchHealth = LaunchHealthMonitor.shared
  let networkStatus = NetworkStatusMonitor()
  lazy var traktLibraryRepository = TraktLibraryRepository(session: traktSession)

  private let preferencesStore: any PreferencesStore
  private let cloudUserStore: any CloudUserStateStoring
  private let automaticSetup = AutomaticSetupService()
  private let searchHistoryStore = SearchHistoryStore()
  private var traktObservation: AnyCancellable?
  private var iCloudObservation: AnyCancellable?
  private var memoryWarningObservation: AnyCancellable?
  private var networkObservation: AnyCancellable?

  init(
    distributionCapabilities: DistributionCapabilities = .current,
    preferencesStore: (any PreferencesStore)? = nil,
    cloudUserStore: (any CloudUserStateStoring)? = nil,
    iCloudAccount: ICloudAccountMonitor? = nil
  ) {
    self.distributionCapabilities = distributionCapabilities
    if let preferencesStore {
      self.preferencesStore = preferencesStore
    } else if distributionCapabilities.supportsICloudPreferences {
      self.preferencesStore = ICloudPreferencesStore()
    } else {
      self.preferencesStore = LocalPreferencesStore()
    }
    if let cloudUserStore {
      self.cloudUserStore = cloudUserStore
    } else if distributionCapabilities.supportsCloudKit {
      self.cloudUserStore = CloudKitUserStateStore()
    } else {
      self.cloudUserStore = LocalUserStateStore()
    }
    self.iCloudAccount =
      iCloudAccount
      ?? (distributionCapabilities.supportsCloudKit ? ICloudAccountMonitor() : .localOnly())
    traktObservation = traktSession.objectWillChange.sink { [weak self] _ in
      self?.objectWillChange.send()
    }

    if distributionCapabilities.supportsICloudPreferences {
      iCloudObservation = NotificationCenter.default
        .publisher(
          for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
          object: NSUbiquitousKeyValueStore.default
        )
        .sink { [weak self] _ in
          Task { @MainActor in await self?.reloadPreferencesFromStore() }
        }
    }

    memoryWarningObservation = NotificationCenter.default
      .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
      .sink { _ in
        Task { await ImagePipeline.shared.clearMemory() }
      }

    networkObservation = networkStatus.$isConnected
      .removeDuplicates()
      .dropFirst()
      .sink { [weak self] connected in
        self?.objectWillChange.send()
        guard connected else { return }
        Task { @MainActor in
          guard let self, self.traktSession.isConnected else { return }
          try? await self.traktLibraryRepository.retryPendingMutations()
          _ = try? await self.traktLibraryRepository.refresh(force: false)
        }
      }
  }

  func bootstrap() async {
    await launchHealth.beginSession()
    var loadedPreferences = await preferencesStore.load()
    loadedPreferences.normalize()
    preferences = loadedPreferences
    cloudState = .initial(preferences: loadedPreferences)

    if !distributionCapabilities.supportsCloudKit {
      do {
        if var local = try await cloudUserStore.load() {
          local.preferences.normalize()
          cloudState = local
          preferences = local.preferences
        } else {
          try await cloudUserStore.save(cloudState)
        }
        cloudSyncError = nil
      } catch {
        cloudSyncError = error.localizedDescription
      }
    } else {
      await iCloudAccount.refresh()
      if loadedPreferences.iCloudSyncEnabled, iCloudAccount.status == .available {
        do {
          if var remote = try await cloudUserStore.load() {
            remote.preferences.normalize()
            let merged = cloudState.merging(with: remote)
            cloudState = merged
            preferences = merged.preferences
            await preferencesStore.save(merged.preferences)
            try await cloudUserStore.save(merged)
          } else {
            try await persistCloudState()
          }
          cloudSyncError = nil
        } catch {
          cloudSyncError = error.localizedDescription
        }
      }
    }

    await traktSession.restore()
    if traktSession.isConnected {
      _ = try? await traktLibraryRepository.refresh(force: false)
    }
    isReady = true
  }

  func handleOpenURL(_ url: URL) {
    deepLinkedItem = AppDeepLinkParser.mediaItem(from: url)
  }

  func handleScenePhase(_ phase: ScenePhase) async {
    switch phase {
    case .active:
      await launchHealth.beginSession()
      if distributionCapabilities.supportsCloudKit {
        await iCloudAccount.refresh()
      }
      await traktSession.refreshProfile()
      if traktSession.isConnected {
        _ = try? await traktLibraryRepository.refresh(force: false)
      }
      if distributionCapabilities.supportsCloudKit, preferences.iCloudSyncEnabled,
        iCloudAccount.status == .available
      {
        await refreshCloudState()
      }
    case .inactive:
      break
    case .background:
      await launchHealth.endSessionCleanly()
      await preferencesStore.save(preferences)
      await persistCloudStateReportingError()
      await ImagePipeline.shared.clearMemory()
    @unknown default:
      break
    }
  }

  func updatePreferences(_ mutate: (inout AppPreferences) -> Void) {
    let previous = preferences
    mutate(&preferences)
    preferences.normalize()
    cloudState.markPreferenceChanges(from: previous, to: preferences)
    let snapshot = preferences
    Task {
      await preferencesStore.save(snapshot)
      await persistCloudStateReportingError()
    }
  }

  func contentPlaybackPreference(for key: String) -> ContentPlaybackPreference? {
    cloudState.contentPlaybackPreferences[key]
  }

  func updateContentPlaybackPreference(
    for key: String,
    _ mutate: (inout ContentPlaybackPreference) -> Void
  ) {
    var value =
      cloudState.contentPlaybackPreferences[key]
      ?? ContentPlaybackPreference(
        audioLanguageCode: nil,
        subtitleLanguageCode: nil,
        subtitlesEnabled: nil,
        preferredSourceAddonID: nil,
        subtitleTimingOffset: nil,
        updatedAt: Date()
      )
    mutate(&value)
    value.updatedAt = Date()
    cloudState.contentPlaybackPreferences[key] = value
    cloudState.updatedAt = Date()
    Task { await persistCloudStateReportingError() }
  }

  func applyAutomaticSetupAndFinish() {
    let previous = preferences
    var configured = automaticSetup.configuredPreferences(from: preferences)
    configured.hasCompletedOnboarding = true
    preferences = configured
    cloudState.markPreferenceChanges(from: previous, to: configured)
    Task {
      await preferencesStore.save(configured)
      await persistCloudStateReportingError()
    }
  }

  func finishOnboarding() {
    updatePreferences { $0.hasCompletedOnboarding = true }
  }

  func resetOnboarding() {
    updatePreferences { $0.hasCompletedOnboarding = false }
  }

  func resetPlaybackPreferences() {
    let previous = preferences
    preferences.resetPlaybackPreferences()
    cloudState.markPreferenceChanges(from: previous, to: preferences)
    cloudState.clearContentPlaybackPreferences()
    let snapshot = preferences
    Task {
      await preferencesStore.save(snapshot)
      await persistCloudStateReportingError()
    }
  }

  func resetHomePreferences() {
    updatePreferences { $0.resetHomePreferences() }
  }

  func resetAddonPreferences() {
    updatePreferences { $0.resetAddonPreferences() }
  }

  func syncCloudNow() async {
    guard distributionCapabilities.supportsCloudKit else { return }
    await iCloudAccount.refresh()
    guard preferences.iCloudSyncEnabled, iCloudAccount.status == .available else { return }
    await refreshCloudState()
    await persistCloudStateReportingError()
  }

  func disableAndDeleteCloudData() async {
    let previous = preferences
    preferences.iCloudSyncEnabled = false
    cloudState.markPreferenceChanges(from: previous, to: preferences)
    await preferencesStore.save(preferences)
    do {
      try await cloudUserStore.delete()
      cloudState = .initial(preferences: preferences)
      if !distributionCapabilities.supportsCloudKit {
        try await cloudUserStore.save(cloudState)
      }
      cloudSyncError = nil
    } catch {
      cloudSyncError = error.localizedDescription
    }
  }

  func clearSearchHistory() async {
    await searchHistoryStore.clear()
  }

  func clearCaches() async {
    await traktLibraryRepository.clearCachedSnapshotPreservingMutations()
    await AddonContentRepository.shared.clearCaches()
    await HomeFeedCache.shared.clear()
    await ExternalSubtitleService.shared.clearCache()
    await TMDBAPIClient.shared.clearCache()
    URLCache.shared.removeAllCachedResponses()
    await ImagePipeline.shared.clearAll()
  }

  func resetApplicationData() async {
    await traktSession.disconnect()
    await traktLibraryRepository.clearLocalData()
    await TopShelfSnapshotStore.shared.clear()
    await searchHistoryStore.clear()
    await AddonContentRepository.shared.clearCaches()
    await HomeFeedCache.shared.clear()
    await ExternalSubtitleService.shared.clearCache()
    await TMDBAPIClient.shared.clearCache()
    await ImagePipeline.shared.clearAll()
    await launchHealth.reset()
    URLCache.shared.removeAllCachedResponses()
    do {
      try await cloudUserStore.delete()
      cloudSyncError = nil
    } catch {
      cloudSyncError = error.localizedDescription
    }
    preferences = .defaults
    cloudState = .initial(preferences: .defaults)
    await preferencesStore.save(.defaults)
    if !distributionCapabilities.supportsCloudKit {
      do {
        try await cloudUserStore.save(cloudState)
        cloudSyncError = nil
      } catch {
        cloudSyncError = error.localizedDescription
      }
    }
  }

  private func reloadPreferencesFromStore() async {
    var remote = await preferencesStore.load()
    remote.normalize()
    if remote != preferences {
      let previous = preferences
      preferences = remote
      cloudState.markPreferenceChanges(from: previous, to: remote)
    }
  }

  private func refreshCloudState() async {
    guard distributionCapabilities.supportsCloudKit else { return }
    do {
      guard var remote = try await cloudUserStore.load() else { return }
      remote.preferences.normalize()
      let merged = cloudState.merging(with: remote)
      if merged != cloudState {
        cloudState = merged
        preferences = merged.preferences
        await preferencesStore.save(merged.preferences)
        try await cloudUserStore.save(merged)
      }
      cloudSyncError = nil
    } catch {
      cloudSyncError = error.localizedDescription
    }
  }

  private func persistCloudStateReportingError() async {
    do {
      try await persistCloudState()
      cloudSyncError = nil
    } catch {
      cloudSyncError = error.localizedDescription
    }
  }

  private func persistCloudState() async throws {
    cloudState.preferences = preferences
    if !distributionCapabilities.supportsCloudKit {
      try await cloudUserStore.save(cloudState)
      return
    }
    guard preferences.iCloudSyncEnabled, iCloudAccount.status == .available else { return }
    try await cloudUserStore.save(cloudState)
    cloudSyncError = nil
  }
}
