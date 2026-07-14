import AVFoundation
import Combine
import Foundation

@MainActor
final class ExternalSubtitleController: ObservableObject {
  @Published private(set) var tracks: [ExternalSubtitleTrack] = []
  @Published private(set) var selectedTrackID: String?
  @Published private(set) var currentText: String?
  @Published private(set) var errorMessage: String?

  private let service: ExternalSubtitleService
  private weak var player: AVPlayer?
  private var cues: [ExternalSubtitleCue] = []
  private var timeObserver: Any?

  init(service: ExternalSubtitleService = ExternalSubtitleService()) {
    self.service = service
  }

  deinit {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
  }

  func configure(tracks: [ExternalSubtitleTrack], player: AVPlayer, preferredLanguage: String?) {
    removeObserver()
    self.tracks = tracks
    self.player = player
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
      queue: .main
    ) { [weak self] time in
      Task { @MainActor in
        self?.updateText(at: time.seconds)
      }
    }

    guard let preferredLanguage else { return }
    Task { await selectPreferred(languageCode: preferredLanguage) }
  }

  func selectPreferred(languageCode: String) async {
    let normalized = languageCode.lowercased()
    let base = normalized.split(separator: "-").first
    let track = tracks.first(where: { $0.languageCode.lowercased() == normalized })
      ?? tracks.first(where: { $0.languageCode.lowercased().split(separator: "-").first == base })
    await select(track)
  }

  func select(_ track: ExternalSubtitleTrack?) async {
    errorMessage = nil
    guard let track else {
      selectedTrackID = nil
      cues = []
      currentText = nil
      return
    }
    do {
      let loaded = try await service.cues(for: track)
      cues = loaded
      selectedTrackID = track.id
      updateText(at: player?.currentTime().seconds ?? 0)
    } catch {
      selectedTrackID = nil
      cues = []
      currentText = nil
      errorMessage = error.localizedDescription
    }
  }

  private func updateText(at time: TimeInterval) {
    guard time.isFinite else {
      currentText = nil
      return
    }
    currentText = cues.first(where: { $0.contains(time) })?.text
  }

  private func removeObserver() {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
  }
}
