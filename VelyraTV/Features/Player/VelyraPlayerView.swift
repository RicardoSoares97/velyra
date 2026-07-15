import AVKit
import SwiftUI

struct VelyraPlayerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var appState: AppState

  let request: PlaybackRequest

  @StateObject private var coordinator: PlaybackCoordinator
  @State private var showsOptions = false
  @FocusState private var focusedControl: Control?

  private enum Control: Hashable {
    case close
    case options
    case retry
  }

  init(request: PlaybackRequest, preferences: AppPreferences) {
    self.request = request
    _coordinator = StateObject(
      wrappedValue: PlaybackCoordinator(preferences: preferences)
    )
  }

  init(url: URL, preferences: AppPreferences = .defaults) {
    self.init(
      request: PlaybackRequest(
        title: "Velyra",
        sources: [
          PlaybackSource(
            url: url,
            displayName: String(localized: "playback.source.default"),
            container: Self.container(for: url)
          )
        ]
      ),
      preferences: preferences
    )
  }

  var body: some View {
    ZStack {
      SystemPlayerView(player: coordinator.player)
        .ignoresSafeArea()

      ExternalSubtitleOverlay(
        controller: coordinator.externalSubtitles,
        textSize: appState.preferences.subtitleTextSize,
        verticalOffset: appState.preferences.subtitleVerticalOffset,
        backgroundOpacity: appState.preferences.subtitleBackgroundOpacity
      )

      topControls

      if showsOptions {
        Color.black.opacity(0.28)
          .ignoresSafeArea()
          .accessibilityHidden(true)
          .onTapGesture { showsOptions = false }

        PlayerOptionsPanel(
          coordinator: coordinator,
          onDismiss: { showsOptions = false }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }

      if case .failed(let message) = coordinator.state {
        failureView(message: message)
      }
    }
    .background(Color.black)
    .task {
      coordinator.configureContentPreference(
        appState.contentPlaybackPreference(for: request.contentKey)
      )
      await coordinator.prepare(request)
      if let context = request.traktContext {
        coordinator.attachTrakt(
          repository: appState.traktLibraryRepository,
          context: context
        )
      }
    }
    .onDisappear {
      coordinator.player.pause()
      Task { await coordinator.finishPlaybackTracking() }
    }
    .onChange(of: coordinator.selectedAudioLanguageCode) { _, value in
      persistContentPreference { $0.audioLanguageCode = value }
    }
    .onChange(of: coordinator.selectedSubtitleLanguageCode) { _, value in
      persistContentPreference { $0.subtitleLanguageCode = value }
    }
    .onChange(of: coordinator.selectedSourceAddonID) { _, value in
      persistContentPreference { $0.preferredSourceAddonID = value }
    }
    .onChange(of: coordinator.subtitlesDisabled) { _, disabled in
      persistContentPreference { $0.subtitlesEnabled = !disabled }
    }
    .onChange(of: coordinator.externalSubtitles.timingOffset) { _, value in
      persistContentPreference { $0.subtitleTimingOffset = value }
    }
    .onExitCommand {
      if showsOptions {
        showsOptions = false
      } else {
        dismiss()
      }
    }
    .accessibleMotion(value: showsOptions)
  }

  private func persistContentPreference(
    _ mutate: (inout ContentPlaybackPreference) -> Void
  ) {
    appState.updateContentPlaybackPreference(for: request.contentKey, mutate)
  }

  private var topControls: some View {
    VStack {
      HStack(spacing: 18) {
        Button {
          dismiss()
        } label: {
          Label("action.close", systemImage: "xmark")
            .labelStyle(.iconOnly)
            .frame(width: 54, height: 54)
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .focused($focusedControl, equals: .close)
        .accessibilityLabel(Text("action.close"))

        Spacer()

        Button {
          showsOptions = true
        } label: {
          Label("playback.options", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .focused($focusedControl, equals: .options)
        .accessibilityHint(Text("playback.options.hint"))
      }
      .padding(.horizontal, 54)
      .padding(.top, 40)

      Spacer()
    }
  }

  private func failureView(message: String) -> some View {
    VStack(spacing: 22) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 42))
        .foregroundStyle(VelyraTheme.primary)

      Text("playback.error.title")
        .font(.title.bold())

      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 620)

      Button("action.retry") {
        Task { await coordinator.retry() }
      }
      .buttonStyle(VelyraGlassButtonStyle(prominent: true))
      .focused($focusedControl, equals: .retry)
    }
    .padding(42)
    .velyraGlass(cornerRadius: 30)
    .onAppear { focusedControl = .retry }
  }

  private static func container(for url: URL) -> PlaybackSource.Container {
    switch url.pathExtension.lowercased() {
    case "m3u8": .hls
    case "mp4", "m4v": .mp4
    case "mov": .mov
    case "ts": .mpegTS
    case "mkv": .matroska
    case "webm": .webM
    default: .unknown
    }
  }
}

private struct SystemPlayerView: UIViewControllerRepresentable {
  let player: AVPlayer

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.showsPlaybackControls = true
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    if controller.player !== player {
      controller.player = player
    }
  }
}

private struct PlayerOptionsPanel: View {
  @ObservedObject var coordinator: PlaybackCoordinator
  let onDismiss: () -> Void

  @FocusState private var focusedOption: String?

  var body: some View {
    HStack {
      Spacer()

      ScrollView {
        VStack(alignment: .leading, spacing: 30) {
          header

          if coordinator.rankedSources.count > 1 {
            sourceSection
          }

          if !coordinator.audioTracks.isEmpty {
            trackSection(
              title: "playback.audio",
              systemImage: "speaker.wave.2.fill",
              tracks: coordinator.audioTracks,
              select: coordinator.selectAudio
            )
          }

          if !coordinator.subtitleTracks.isEmpty {
            trackSection(
              title: "playback.subtitles.embedded",
              systemImage: "captions.bubble.fill",
              tracks: coordinator.subtitleTracks,
              select: coordinator.selectSubtitles
            )
          }

          if !coordinator.externalSubtitles.tracks.isEmpty {
            ExternalSubtitleOptions(
              controller: coordinator.externalSubtitles,
              select: { track in
                Task { await coordinator.selectExternalSubtitle(track) }
              }
            )
            SubtitleTimingControls(controller: coordinator.externalSubtitles)
          }

          if let diagnostics = coordinator.diagnostics {
            PlaybackDiagnosticsView(diagnostics: diagnostics)
          }
        }
        .padding(34)
      }
      .frame(width: 610, maxHeight: 780)
      .velyraGlass(cornerRadius: 34)
      .padding(.trailing, 60)
    }
    .onAppear {
      focusedOption =
        coordinator.currentSource?.id ?? coordinator.audioTracks.first(where: \.isSelected)?.id
        ?? coordinator.subtitleTracks.first(where: \.isSelected)?.id
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text("playback.options")
          .font(.title2.bold())
        Text("playback.options.body")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .frame(width: 48, height: 48)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("action.close"))
    }
  }

  private var sourceSection: some View {
    optionGroup(title: "playback.source", systemImage: "server.rack") {
      ForEach(coordinator.rankedSources) { ranked in
        Button {
          Task { await coordinator.selectSource(ranked.source) }
        } label: {
          OptionRow(
            title: ranked.source.displayName,
            subtitle: sourceDescription(ranked),
            selected: coordinator.currentSource?.id == ranked.source.id
          )
        }
        .buttonStyle(.plain)
        .focused($focusedOption, equals: ranked.source.id)
        .accessibilityValue(
          coordinator.currentSource?.id == ranked.source.id
            ? Text("accessibility.selected")
            : Text("")
        )
      }
    }
  }

  private func trackSection(
    title: LocalizedStringKey,
    systemImage: String,
    tracks: [MediaTrackChoice],
    select: @escaping (MediaTrackChoice) -> Void
  ) -> some View {
    optionGroup(title: title, systemImage: systemImage) {
      ForEach(tracks) { track in
        Button {
          select(track)
        } label: {
          OptionRow(
            title: track.displayName,
            subtitle: track.isAccessibilityTrack
              ? String(localized: "playback.track.accessibility")
              : nil,
            selected: track.isSelected
          )
        }
        .buttonStyle(.plain)
        .focused($focusedOption, equals: track.id)
        .accessibilityValue(track.isSelected ? Text("accessibility.selected") : Text(""))
      }
    }
  }

  private func optionGroup<Content: View>(
    title: LocalizedStringKey,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .foregroundStyle(.secondary)
      content()
    }
  }

  private func sourceDescription(_ ranked: RankedPlaybackSource) -> String? {
    var parts: [String] = []
    if let height = ranked.source.resolutionHeight {
      parts.append(height >= 2160 ? "4K" : "\(height)p")
    }
    if ranked.source.dynamicRanges.contains(.dolbyVision) {
      parts.append("Dolby Vision")
    } else if !ranked.source.dynamicRanges.isDisjoint(with: [.hdr10, .hlg]) {
      parts.append("HDR")
    }
    if ranked.source.audioFormats.contains(.dolbyAtmos) {
      parts.append("Dolby Atmos")
    }
    if ranked.source.isCached {
      parts.append(String(localized: "playback.source.cached"))
    }
    return parts.isEmpty ? ranked.source.addonName : parts.joined(separator: " · ")
  }
}

private struct OptionRow: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isFocused) private var isFocused

  let title: String
  let subtitle: String?
  let selected: Bool

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .lineLimit(1)
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      if selected {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(VelyraTheme.primary)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 18)
    .frame(minHeight: 64)
    .background(
      isFocused ? Color.white.opacity(0.14) : Color.clear,
      in: RoundedRectangle(cornerRadius: 16, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(isFocused ? VelyraTheme.focusRing : .clear, lineWidth: 3)
    }
    .scaleEffect(isFocused ? 1.025 : 1)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isFocused)
  }
}

private struct ExternalSubtitleOverlay: View {
  @ObservedObject var controller: ExternalSubtitleController
  let textSize: SubtitleTextSizePreference
  let verticalOffset: Double
  let backgroundOpacity: Double

  var body: some View {
    VStack {
      Spacer()
      if let text = controller.currentText {
        Text(text)
          .font(.system(size: 34 * textSize.scale, weight: .semibold))
          .multilineTextAlignment(.center)
          .foregroundStyle(.white)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
          .background(.black.opacity(backgroundOpacity), in: RoundedRectangle(cornerRadius: 12))
          .shadow(radius: 6)
          .frame(maxWidth: 1_260)
          .accessibilityHidden(true)
      }
    }
    .padding(.bottom, 92 + (verticalOffset * 320))
    .allowsHitTesting(false)
  }
}

private struct ExternalSubtitleOptions: View {
  @ObservedObject var controller: ExternalSubtitleController
  let select: (ExternalSubtitleTrack?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("playback.subtitles.external", systemImage: "text.bubble.fill")
        .font(.headline)
        .foregroundStyle(.secondary)

      Button {
        select(nil)
      } label: {
        OptionRow(
          title: String(localized: "playback.subtitles.off"),
          subtitle: nil,
          selected: controller.selectedTrackID == nil
        )
      }
      .buttonStyle(.plain)

      ForEach(controller.tracks) { track in
        Button {
          select(track)
        } label: {
          OptionRow(
            title: track.displayName,
            subtitle: track.addonName,
            selected: controller.selectedTrackID == track.id
          )
        }
        .buttonStyle(.plain)
        .accessibilityValue(
          controller.selectedTrackID == track.id ? Text("accessibility.selected") : Text("")
        )
      }

      if let error = controller.errorMessage {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct SubtitleTimingControls: View {
  @ObservedObject var controller: ExternalSubtitleController

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("playback.subtitles.timing", systemImage: "timer")
        .font(.headline)
        .foregroundStyle(.secondary)
      HStack(spacing: 12) {
        Button {
          controller.adjustTiming(by: -0.5)
        } label: {
          Label("-0.5 s", systemImage: "minus")
        }
        .buttonStyle(VelyraGlassButtonStyle())
        Button {
          controller.setTimingOffset(0)
        } label: {
          Text(String(format: "%+.1f s", controller.timingOffset))
            .monospacedDigit()
        }
        .buttonStyle(VelyraGlassButtonStyle())
        Button {
          controller.adjustTiming(by: 0.5)
        } label: {
          Label("+0.5 s", systemImage: "plus")
        }
        .buttonStyle(VelyraGlassButtonStyle())
      }
      Text("playback.subtitles.timing.body")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }
}

private struct PlaybackDiagnosticsView: View {
  let diagnostics: PlaybackDiagnostics

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("playback.diagnostics.title", systemImage: "waveform.path.ecg.rectangle")
        .font(.headline)
        .foregroundStyle(.secondary)

      ForEach(Array(diagnostics.rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .firstTextBaseline) {
          Text(row.0)
            .foregroundStyle(.secondary)
          Spacer()
          Text(row.1)
            .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
      }

      Text("playback.diagnostics.privacy")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }
}
