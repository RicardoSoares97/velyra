import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackCoordinator: ObservableObject {
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
  private var request: PlaybackRequest?
  private var itemFailureCancellable: AnyCancellable?
  private var manuallySelectedAudioLanguage: String?
  private var manuallySelectedSubtitleLanguage: String?
  private var subtitlesManuallyDisabled = false
  private var scrobbleController: TraktScrobbleController?
  private var contentPreference: ContentPlaybackPreference?
  private var failedSourceIDs = Set<String>()

  init(
    preferences: AppPreferences,
    sourceSelector: AutomaticSourceSelector = AutomaticSourceSelector(),
    mediaResolver: MediaSelectionResolver = MediaSelectionResolver()
  ) {
    self.preferences = preferences
    self.sourceSelector = sourceSelector
    self.mediaResolver = mediaResolver
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

    await load(source, position: request.initialPosition, autoplay: true)
  }

  func selectSource(_ source: PlaybackSource) async {
    let currentPosition = player.currentTime().seconds
    state = .switchingSource
    await load(
      source,
      position: currentPosition.isFinite ? currentPosition : 0,
      autoplay: player.rate > 0
    )
  }

  func selectAudio(_ choice: MediaTrackChoice) {
    guard let item = player.currentItem,
      let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
    else { return }

    let option = mediaResolver.option(matching: choice.id, in: group, kind: .audio)
    item.select(option, in: group)
    manuallySelectedAudioLanguage = choice.languageCode
    selectedAudioLanguageCode = choice.languageCode
    refreshTrackChoices(for: item)
  }

  func selectSubtitles(_ choice: MediaTrackChoice) {
    Task { await externalSubtitles.select(nil) }
    guard let item = player.currentItem,
      let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
    else { return }

    let option = mediaResolver.option(matching: choice.id, in: group, kind: .subtitles)
    item.select(option, in: group)
    manuallySelectedSubtitleLanguage = choice.languageCode
    subtitlesManuallyDisabled = choice.isOff
    selectedSubtitleLanguageCode = choice.languageCode
    subtitlesDisabled = choice.isOff
    refreshTrackChoices(for: item)
  }

  func selectExternalSubtitle(_ track: ExternalSubtitleTrack?) async {
    if let item = player.currentItem,
      let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
    {
      item.select(nil, in: group)
      refreshTrackChoices(for: item)
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
    autoplay: Bool
  ) async {
    do {
      let asset = AVURLAsset(
        url: source.url,
        options: source.headers.isEmpty
          ? nil
          : ["AVURLAssetHTTPHeaderFieldsKey": source.headers]
      )
      let playable = try await asset.load(.isPlayable)
      guard playable else { throw PlaybackError.notPlayable }

      let item = AVPlayerItem(asset: asset)
      installFailureObserver(for: item)
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

      if let audioGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
        let selectedAudio =
          manuallySelectedAudioLanguage.flatMap {
            mediaResolver.option(matchingLanguage: $0, in: audioGroup)
          } ?? resolved.audio
        item.select(selectedAudio, in: audioGroup)
      }
      if let subtitleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
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
        if let durationSeconds = duration?.seconds, durationSeconds.isFinite, durationSeconds > 0 {
          resolvedPosition = durationSeconds * (initialProgress / 100)
        }
      }
      if resolvedPosition > 0 {
        await seek(to: resolvedPosition)
      }

      refreshTrackChoices(for: item)
      if let subtitleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
        item.currentMediaSelection.selectedMediaOption(in: subtitleGroup) != nil
      {
        await externalSubtitles.select(nil)
      } else if preferences.subtitlesEnabledByDefault {
        await externalSubtitles.selectPreferred(languageCodes: externalSubtitleCandidates)
      }
      failedSourceIDs.remove(source.id)
      state = .ready
      if autoplay { player.play() }
    } catch {
      await failover(after: source, underlyingError: error)
    }
  }

  private func installFailureObserver(for item: AVPlayerItem) {
    itemFailureCancellable = NotificationCenter.default
      .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
      .sink { [weak self] notification in
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        Task { @MainActor in
          guard let self, let source = self.currentSource else { return }
          await self.failover(after: source, underlyingError: error)
        }
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

  private func failover(after source: PlaybackSource, underlyingError: Error?) async {
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
      autoplay: true
    )
  }

  private func refreshTrackChoices(for item: AVPlayerItem) {
    let audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
    let subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
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
