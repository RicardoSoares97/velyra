import AVFoundation
import Combine
import Foundation

@MainActor
final class TraktScrobbleController {
  private let player: AVPlayer
  private let repository: TraktLibraryRepository
  private let context: TraktPlaybackContext
  private var timeObserver: Any?
  private var timeControlObservation: AnyCancellable?
  private var endObservation: AnyCancellable?
  private var lastTimeControlStatus: AVPlayer.TimeControlStatus = .paused
  private var lastSentProgress: Double = -1
  private var lastSentAt: Date = .distantPast
  private var hasStarted = false
  private var hasStopped = false

  init(
    player: AVPlayer,
    repository: TraktLibraryRepository,
    context: TraktPlaybackContext
  ) {
    self.player = player
    self.repository = repository
    self.context = context
  }

  deinit {
    if let timeObserver { player.removeTimeObserver(timeObserver) }
  }

  func start() {
    guard timeObserver == nil else { return }
    lastTimeControlStatus = player.timeControlStatus

    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 10, preferredTimescale: 600),
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.periodicUpdate() }
    }

    timeControlObservation = player.publisher(for: \.timeControlStatus)
      .removeDuplicates()
      .sink { [weak self] status in
        Task { @MainActor in await self?.timeControlStatusChanged(status) }
      }

    endObservation = NotificationCenter.default
      .publisher(for: .AVPlayerItemDidPlayToEndTime)
      .sink { [weak self] notification in
        Task { @MainActor in
          guard let self, notification.object as? AVPlayerItem === self.player.currentItem else {
            return
          }
          await self.finish(forceProgress: 100)
        }
      }
  }

  func finish(forceProgress: Double? = nil) async {
    guard !hasStopped else { return }
    let progress = forceProgress ?? currentProgress()
    guard progress.isFinite, progress > 0 else { return }
    hasStopped = true
    await send(action: .stop, progress: progress)
  }

  func detach() async {
    if hasStarted, !hasStopped {
      let progress = currentProgress()
      if progress > 0 { await send(action: .pause, progress: progress) }
    }
    if let timeObserver {
      player.removeTimeObserver(timeObserver)
      self.timeObserver = nil
    }
    timeControlObservation = nil
    endObservation = nil
  }

  private func periodicUpdate() async {
    guard player.timeControlStatus == .playing else { return }
    let progress = currentProgress()
    guard progress > 0 else { return }
    let enoughTimePassed = Date().timeIntervalSince(lastSentAt) >= 30
    let enoughProgressChanged = abs(progress - lastSentProgress) >= 0.5
    guard !hasStarted || enoughTimePassed || enoughProgressChanged else { return }
    hasStarted = true
    await send(action: .start, progress: progress)
  }

  private func timeControlStatusChanged(_ status: AVPlayer.TimeControlStatus) async {
    defer { lastTimeControlStatus = status }
    guard status != lastTimeControlStatus else { return }

    switch status {
    case .playing:
      let progress = currentProgress()
      if progress > 0 {
        hasStarted = true
        await send(action: .start, progress: progress)
      }
    case .paused:
      guard hasStarted, !hasStopped else { return }
      let progress = currentProgress()
      if progress > 0 { await send(action: .pause, progress: progress) }
    case .waitingToPlayAtSpecifiedRate:
      break
    @unknown default:
      break
    }
  }

  private func currentProgress() -> Double {
    guard let duration = player.currentItem?.duration.seconds,
      duration.isFinite,
      duration > 0
    else { return 0 }
    let position = player.currentTime().seconds
    guard position.isFinite else { return 0 }
    return min(max((position / duration) * 100, 0), 100)
  }

  private func send(action: TraktScrobbleAction, progress: Double) async {
    let payload = TraktScrobblePayload.make(context: context, progress: progress)
    do {
      _ = try await repository.enqueueScrobble(action: action, payload: payload)
      lastSentProgress = progress
      lastSentAt = Date()
    } catch {
      // Repository persists retryable failures. Non-retryable failures are intentionally silent in playback.
    }
  }
}
