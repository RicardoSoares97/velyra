import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackCoordinator: ObservableObject {
  typealias IsPlayableLoader = @MainActor (AVAsset) async throws -> Bool
  typealias MediaSelectionGroupLoader =
    @MainActor (
      _ asset: AVAsset,
      _ characteristic: AVMediaCharacteristic
    ) async throws -> AVMediaSelectionGroup?
  typealias Play = @MainActor (AVPlayer) -> Void
  typealias FailureObserverInstaller =
    @MainActor (
      _ item: AVPlayerItem,
      _ handler: @escaping @MainActor (Error?) async -> Void
    ) -> AnyCancellable

  enum State: Equatable {
    case idle
    case preparing
    case ready
    case switchingSource
    case failed(String)
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var rankedSources: [RankedPlaybackSource] = []
  @Published private(set) var currentSource: PlaybackSource?
  @Published private(set) var audioTracks: [MediaTrackChoice] = []
  @Published private(set) var subtitleTracks: [MediaTrackChoice] = []
  @Published private(set) var selectedAudioLanguageCode: String?
  @Published private(set) var selectedSubtitleLanguageCode: String?
  @Published private(set) var selectedSourceAddonID: String?
  @Published private(set) var subtitlesDisabled = false

  let player = AVPlayer()
  let externalSubtitles = ExternalSubtitleController()

  var diagnostics: PlaybackDiagnostics? {
    currentSource.map(PlaybackDiagnostics.init(source:))
  }

  private let preferences: AppPreferences
  private let sourceSelector: AutomaticSourceSelector
  private let mediaResolver: MediaSelectionResolver
  private let mediaSelectionGroupLoader: MediaSelectionGroupLoader
  private let isPlayableLoader: IsPlayableLoader
  private let play: Play
  private let failureObserverInstaller: FailureObserverInstaller
  private var request: PlaybackRequest?
  private var itemFailureCancellable: AnyCancellable?
  private var manuallySelectedAudioLanguage: String?
  private var manuallySelectedSubtitleLanguage: String?
  private var subtitlesManuallyDisabled = false
  private var scrobbleController: TraktScrobbleController?
  private var contentPreference: ContentPlaybackPreference?
  private var failedSourceIDs = Set<String>()
  private var loadGeneration = 0
  private var audioSelectionGeneration = 0
  private var subtitleSelectionGeneration = 0

  init(
    preferences: AppPreferences,
    sourceSelector: AutomaticSourceSelector = AutomaticSourceSelector(),
    mediaResolver: MediaSelectionResolver = MediaSelectionResolver(),
    mediaSelectionGroupLoader: @escaping MediaSelectionGroupLoader = { asset, characteristic in
      try await asset.loadMediaSelectionGroup(for: characteristic)
    },
    isPlayableLoader: @escaping IsPlayableLoader = { asset in
      try await asset.load(.isPlayable)
    },
    play: @escaping Play = { player in player.play() },
    failureObserverInstaller: @escaping FailureObserverInstaller = { item, handler in
      NotificationCenter.default
        .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
        .sink { notification in
          let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
          Task { @MainActor in await handler(error) }
        }
    }
  ) {
    self.preferences = preferences
    self.sourceSelector = sourceSelector
    self.mediaResolver = mediaResolver
    self.mediaSelectionGroupLoader = mediaSelectionGroupLoader
    self.isPlayableLoader = isPlayableLoader
    self.play = play
    self.failureObserverInstaller = failureObserverInstaller
    player.automaticallyWaitsToMinimizeStalling = true
    player.preventsDisplaySleepDuringVideoPlayback = true
  }

  func configureContentPreference(_ preference: ContentPlaybackPreference?) {
    contentPreference = preference
    manuallySelectedAudioLanguage = preference?.audioLanguageCode
    manuallySelectedSubtitleLanguage = preference?.subtitleLanguageCode
    subtitlesManuallyDisabled = preference?.subtitlesEnabled == false
    selectedAudioLanguageCode = preference?.audioLanguageCode
    selectedSubtitleLanguageCode = preference?.subtitleLanguageCode
    subtitlesDisabled = preference?.subtitlesEnabled == false
    selectedSourceAddonID = preference?.preferredSourceAddonID
    externalSubtitles.setTimingOffset(preference?.subtitleTimingOffset ?? 0)
  }

  func prepare(_ request: PlaybackRequest) async {
    let generation = beginLoadGeneration()
    self.request = request
    failedSourceIDs.removeAll()
    state = .preparing
    rankedSources =
      preferences.automaticSourceSelection
      ? sourceSelector.rank(request.sources, preferences: preferences)
      : request.sources.enumerated().map { index, source in
        RankedPlaybackSource(source: source, score: -index, reasons: ["manual-order"])
      }
    if let preferredAddon = contentPreference?.preferredSourceAddonID {
      rankedSources.sort { lhs, rhs in
        let lhsPreferred = lhs.source.addonName == preferredAddon
        let rhsPreferred = rhs.source.addonName == preferredAddon
        if lhsPreferred != rhsPreferred { return lhsPreferred }
        return lhs.score > rhs.score
      }
    }

    externalSubtitles.configure(
      tracks: request.externalSubtitles,
      player: player,
      preferredLanguage: nil
    )

    guard let source = rankedSources.first?.source else {
      state = .failed(String(localized: "playback.error.noSources"))
      return
    }

    await load(
      source,
      position: request.initialPosition,
      autoplay: true,
      generation: generation
    )
  }

  func selectSource(_ source: PlaybackSource) async {
    let generation = beginLoadGeneration()
    let currentPosition = player.currentTime().seconds
    state = .switchingSource
    await load(
      source,
      position: currentPosition.isFinite ? currentPosition : 0,
      autoplay: player.rate > 0,
      generation: generation
    )
  }

  func selectAudio(_ choice: MediaTrackChoice) {
    guard let item = player.currentItem else { return }
    audioSelectionGeneration &+= 1
    let generation = audioSelectionGeneration
    Task { [weak self] in
      await self?.applyAudioSelection(choice, to: item, generation: generation)
    }
  }

  func selectSubtitles(_ choice: MediaTrackChoice) {
    guard let item = player.currentItem else { return }
    subtitleSelectionGeneration &+= 1
    let generation = subtitleSelectionGeneration
    Task { [weak self] in
      await self?.applySubtitleSelection(choice, to: item, generation: generation)
    }
  }

  func selectExternalSubtitle(_ track: ExternalSubtitleTrack?) async {
    subtitleSelectionGeneration &+= 1
    let generation = subtitleSelectionGeneration
    if let item = player.currentItem {
      let group = try? await mediaSelectionGroupLoader(item.asset, .legible)
      guard isCurrentSubtitleSelection(generation, item: item) else { return }
      if let group {
        item.select(nil, in: group)
        await refreshTrackChoices(for: item)
        guard isCurrentSubtitleSelection(generation, item: item) else { return }
      }
    }
    subtitlesManuallyDisabled = track == nil
    manuallySelectedSubtitleLanguage = track?.languageCode
    selectedSubtitleLanguageCode = track?.languageCode
    subtitlesDisabled = track == nil
    await externalSubtitles.select(track)
  }

  func retry() async {
    guard let request else { return }
    await prepare(request)
  }

  func attachTrakt(
    repository: TraktLibraryRepository,
    context: TraktPlaybackContext
  ) {
    guard scrobbleController == nil else { return }
    let controller = TraktScrobbleController(
      player: player,
      repository: repository,
      context: context
    )
    scrobbleController = controller
    controller.start()
  }

  func finishPlaybackTracking() async {
    await scrobbleController?.finish()
    await scrobbleController?.detach()
    scrobbleController = nil
  }

  private func load(
    _ source: PlaybackSource,
    position: TimeInterval,
    autoplay: Bool,
    generation: Int
  ) async {
    var installedItem: AVPlayerItem?
    do {
      let asset = AVURLAsset(
        url: source.url,
        options: source.headers.isEmpty
          ? nil
          : ["AVURLAssetHTTPHeaderFieldsKey": source.headers]
      )
      let playable = try await isPlayableLoader(asset)
      guard isCurrentLoad(generation) else { return }
      guard playable else { throw PlaybackError.notPlayable }

      let item = AVPlayerItem(asset: asset)
      installedItem = item
      installFailureObserver(for: item, source: source, generation: generation)
      player.replaceCurrentItem(with: item)
      currentSource = source
      selectedSourceAddonID = source.addonName

      let regionalSubtitleLanguage = RegionLanguageResolver.subtitleLanguageCode(
        for: preferences.contentRegion ?? RegionLanguageResolver.regionCode()
      )
      let subtitleLanguage: String
      switch preferences.preferredSubtitleLanguage {
      case .region:
        subtitleLanguage = regionalSubtitleLanguage
      case .system:
        subtitleLanguage = Locale.preferredLanguages.first ?? regionalSubtitleLanguage
      case .custom:
        subtitleLanguage = preferences.preferredSubtitleLanguageCode ?? regionalSubtitleLanguage
      case .off:
        subtitleLanguage = regionalSubtitleLanguage
      }
      let externalSubtitleCandidates = [
        manuallySelectedSubtitleLanguage,
        subtitleLanguage,
        preferences.secondarySubtitleLanguageCode,
      ].compactMap { $0 }
      let resolved = try await mediaResolver.resolve(
        item: item,
        originalLanguageCode: request?.originalLanguageCode,
        subtitleLanguageCode: subtitleLanguage,
        preferences: preferences
      )
      guard isCurrentLoad(generation, item: item) else { return }

      let audioGroup = try? await mediaSelectionGroupLoader(asset, .audible)
      guard isCurrentLoad(generation, item: item) else { return }
      if let audioGroup {
        let selectedAudio =
          manuallySelectedAudioLanguage.flatMap {
            mediaResolver.option(matchingLanguage: $0, in: audioGroup)
          } ?? resolved.audio
        item.select(selectedAudio, in: audioGroup)
      }
      let subtitleGroup = try? await mediaSelectionGroupLoader(asset, .legible)
      guard isCurrentLoad(generation, item: item) else { return }
      if let subtitleGroup {
        let selectedSubtitles: AVMediaSelectionOption?
        if subtitlesManuallyDisabled {
          selectedSubtitles = nil
        } else {
          selectedSubtitles =
            manuallySelectedSubtitleLanguage.flatMap {
              mediaResolver.option(matchingLanguage: $0, in: subtitleGroup)
            } ?? resolved.subtitles
        }
        item.select(selectedSubtitles, in: subtitleGroup)
      }

      var resolvedPosition = position
      if resolvedPosition <= 0,
        let initialProgress = request?.initialProgress,
        initialProgress > 0
      {
        let duration = try? await asset.load(.duration)
        guard isCurrentLoad(generation, item: item) else { return }
        if let durationSeconds = duration?.seconds, durationSeconds.isFinite, durationSeconds > 0 {
          resolvedPosition = durationSeconds * (initialProgress / 100)
        }
      }
      if resolvedPosition > 0 {
        await seek(to: resolvedPosition)
        guard isCurrentLoad(generation, item: item) else { return }
      }

      await refreshTrackChoices(for: item)
      guard isCurrentLoad(generation, item: item) else { return }
      if let subtitleGroup,
        item.currentMediaSelection.selectedMediaOption(in: subtitleGroup) != nil
      {
        await externalSubtitles.select(nil)
        guard isCurrentLoad(generation, item: item) else { return }
      } else if preferences.subtitlesEnabledByDefault {
        await externalSubtitles.selectPreferred(languageCodes: externalSubtitleCandidates)
        guard isCurrentLoad(generation, item: item) else { return }
      }
      failedSourceIDs.remove(source.id)
      state = .ready
      if autoplay { play(player) }
    } catch {
      guard isCurrentLoad(generation, item: installedItem) else { return }
      await failover(after: source, underlyingError: error, generation: generation)
    }
  }

  private func installFailureObserver(
    for item: AVPlayerItem,
    source: PlaybackSource,
    generation: Int
  ) {
    itemFailureCancellable = failureObserverInstaller(item) { [weak self] error in
      guard let self,
        self.isCurrentLoad(generation, item: item),
        self.currentSource?.id == source.id
      else { return }
      await self.failover(
        after: source,
        underlyingError: error,
        generation: generation
      )
    }
  }

  private func seek(to seconds: TimeInterval) async {
    await withCheckedContinuation { continuation in
      player.seek(
        to: CMTime(seconds: seconds, preferredTimescale: 600),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      ) { _ in
        continuation.resume()
      }
    }
  }

  private func failover(
    after source: PlaybackSource,
    underlyingError: Error?,
    generation: Int
  ) async {
    failedSourceIDs.insert(source.id)
    guard preferences.automaticSourceFailover else {
      state = .failed(
        underlyingError?.localizedDescription ?? String(localized: "playback.error.generic"))
      return
    }

    guard let next = rankedSources.first(where: { !failedSourceIDs.contains($0.source.id) })?.source
    else {
      state = .failed(
        underlyingError?.localizedDescription
          ?? String(localized: "playback.error.allSourcesFailed"))
      return
    }

    let position = player.currentTime().seconds
    state = .switchingSource
    await load(
      next,
      position: position.isFinite ? position : 0,
      autoplay: true,
      generation: generation
    )
  }

  private func beginLoadGeneration() -> Int {
    loadGeneration &+= 1
    return loadGeneration
  }

  private func isCurrentLoad(_ generation: Int, item: AVPlayerItem? = nil) -> Bool {
    guard generation == loadGeneration else { return false }
    guard let item else { return true }
    return player.currentItem === item
  }

  private func applyAudioSelection(
    _ choice: MediaTrackChoice,
    to item: AVPlayerItem,
    generation: Int
  ) async {
    let group = try? await mediaSelectionGroupLoader(item.asset, .audible)
    guard generation == audioSelectionGeneration,
      player.currentItem === item,
      let group
    else { return }

    let option = mediaResolver.option(matching: choice.id, in: group, kind: .audio)
    item.select(option, in: group)
    manuallySelectedAudioLanguage = choice.languageCode
    selectedAudioLanguageCode = choice.languageCode
    await refreshTrackChoices(for: item)
  }

  private func applySubtitleSelection(
    _ choice: MediaTrackChoice,
    to item: AVPlayerItem,
    generation: Int
  ) async {
    guard isCurrentSubtitleSelection(generation, item: item) else { return }
    await externalSubtitles.select(nil)
    guard isCurrentSubtitleSelection(generation, item: item) else { return }

    let group = try? await mediaSelectionGroupLoader(item.asset, .legible)
    guard isCurrentSubtitleSelection(generation, item: item), let group else { return }

    let option = mediaResolver.option(matching: choice.id, in: group, kind: .subtitles)
    item.select(option, in: group)
    manuallySelectedSubtitleLanguage = choice.languageCode
    subtitlesManuallyDisabled = choice.isOff
    selectedSubtitleLanguageCode = choice.languageCode
    subtitlesDisabled = choice.isOff
    await refreshTrackChoices(for: item)
  }

  private func isCurrentSubtitleSelection(_ generation: Int, item: AVPlayerItem) -> Bool {
    generation == subtitleSelectionGeneration && player.currentItem === item
  }

  private func refreshTrackChoices(for item: AVPlayerItem) async {
    let audioGroup = try? await mediaSelectionGroupLoader(item.asset, .audible)
    guard player.currentItem === item else { return }
    let subtitleGroup = try? await mediaSelectionGroupLoader(item.asset, .legible)
    guard player.currentItem === item else { return }
    let selectedAudio = audioGroup.flatMap {
      item.currentMediaSelection.selectedMediaOption(in: $0)
    }
    let selectedSubtitles = subtitleGroup.flatMap {
      item.currentMediaSelection.selectedMediaOption(in: $0)
    }

    audioTracks = mediaResolver.choices(
      from: audioGroup,
      selected: selectedAudio,
      kind: .audio,
      includeOff: false
    )
    subtitleTracks = mediaResolver.choices(
      from: subtitleGroup,
      selected: selectedSubtitles,
      kind: .subtitles,
      includeOff: true
    )
  }
}

private enum PlaybackError: LocalizedError {
  case notPlayable

  var errorDescription: String? {
    switch self {
    case .notPlayable: String(localized: "playback.error.notPlayable")
    }
  }
}
