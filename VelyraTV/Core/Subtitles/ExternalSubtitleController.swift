import AVFoundation
import Combine
import Foundation

@MainActor
final class ExternalSubtitleController: ObservableObject {
  typealias CueLoader = @MainActor (ExternalSubtitleTrack) async throws -> [ExternalSubtitleCue]

  @Published private(set) var tracks: [ExternalSubtitleTrack] = []
  @Published private(set) var selectedTrackID: String?
  @Published private(set) var currentText: String?
  @Published private(set) var errorMessage: String?
  @Published private(set) var timingOffset: TimeInterval = 0

  private let cueLoader: CueLoader
  private weak var player: AVPlayer?
  private var cues: [ExternalSubtitleCue] = []
  private var timeObserver: Any?
  private var currentCueIndex: Int?
  private var selectionGeneration = 0

  init(service: ExternalSubtitleService = .shared) {
    cueLoader = { track in
      try await service.cues(for: track)
    }
  }

  init(cueLoader: @escaping CueLoader) {
    self.cueLoader = cueLoader
  }

  isolated deinit {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
  }

  func configure(tracks: [ExternalSubtitleTrack], player: AVPlayer, preferredLanguage: String?) {
    removeObserver()
    invalidateSelection()
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
    await selectPreferred(languageCodes: [languageCode])
  }

  func selectPreferred(languageCodes: [String]) async {
    for languageCode in languageCodes where !languageCode.isEmpty {
      let normalized = languageCode.lowercased().replacingOccurrences(of: "_", with: "-")
      let base = normalized.split(separator: "-").first
      if let track = tracks.first(where: {
        $0.languageCode.lowercased().replacingOccurrences(of: "_", with: "-") == normalized
      })
        ?? tracks.first(where: {
          $0.languageCode.lowercased().split(separator: "-").first == base
        })
      {
        await select(track)
        return
      }
    }
  }

  func setTimingOffset(_ value: TimeInterval) {
    timingOffset = min(max(value, -10), 10)
    updateText(at: player?.currentTime().seconds ?? 0)
  }

  func adjustTiming(by delta: TimeInterval) {
    setTimingOffset(timingOffset + delta)
  }

  func select(_ track: ExternalSubtitleTrack?) async {
    let generation = beginSelection()
    errorMessage = nil
    guard let track else {
      clearSelection()
      return
    }
    do {
      let loaded = try await cueLoader(track)
      guard generation == selectionGeneration else { return }
      cues = loaded
      currentCueIndex = nil
      selectedTrackID = track.id
      updateText(at: player?.currentTime().seconds ?? 0)
    } catch {
      guard generation == selectionGeneration else { return }
      clearSelection()
      errorMessage = error.localizedDescription
    }
  }

  private func updateText(at time: TimeInterval) {
    guard time.isFinite, !cues.isEmpty else {
      currentCueIndex = nil
      currentText = nil
      return
    }
    let adjusted = time + timingOffset
    if let currentCueIndex, cues.indices.contains(currentCueIndex),
      cues[currentCueIndex].contains(adjusted)
    {
      currentText = cues[currentCueIndex].text
      return
    }

    var lower = 0
    var upper = cues.count - 1
    var match: Int?
    while lower <= upper {
      let middle = (lower + upper) / 2
      let cue = cues[middle]
      if adjusted < cue.start {
        upper = middle - 1
      } else if adjusted >= cue.end {
        lower = middle + 1
      } else {
        match = middle
        break
      }
    }
    currentCueIndex = match
    currentText = match.map { cues[$0].text }
  }

  private func removeObserver() {
    if let timeObserver, let player {
      player.removeTimeObserver(timeObserver)
    }
    timeObserver = nil
  }

  private func beginSelection() -> Int {
    selectionGeneration &+= 1
    return selectionGeneration
  }

  private func invalidateSelection() {
    _ = beginSelection()
    errorMessage = nil
    clearSelection()
  }

  private func clearSelection() {
    selectedTrackID = nil
    cues = []
    currentCueIndex = nil
    currentText = nil
  }
}
