import AVFoundation
import Foundation

struct MediaSelectionResolver {
  struct ResolvedSelection {
    let audio: AVMediaSelectionOption?
    let subtitles: AVMediaSelectionOption?
  }

  func resolve(
    item: AVPlayerItem,
    originalLanguageCode: String?,
    subtitleLanguageCode: String,
    preferences: AppPreferences
  ) async throws -> ResolvedSelection {
    let asset = item.asset
    _ = try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions)

    let audioGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
    let subtitleGroup = asset.mediaSelectionGroup(forMediaCharacteristic: .legible)

    let audio = chooseAudio(
      from: audioGroup,
      originalLanguageCode: originalLanguageCode,
      preference: preferences.preferredAudioLanguage
    )

    let subtitles = chooseSubtitles(
      from: subtitleGroup,
      languageCode: subtitleLanguageCode,
      preference: preferences.preferredSubtitleLanguage,
      enabledByDefault: preferences.subtitlesEnabledByDefault
    )

    return ResolvedSelection(audio: audio, subtitles: subtitles)
  }

  func choices(
    from group: AVMediaSelectionGroup?,
    selected: AVMediaSelectionOption?,
    kind: MediaTrackChoice.Kind,
    includeOff: Bool
  ) -> [MediaTrackChoice] {
    var result: [MediaTrackChoice] = []

    if includeOff {
      result.append(
        MediaTrackChoice(
          id: "off",
          kind: kind,
          displayName: String(localized: "playback.track.off"),
          languageCode: nil,
          isSelected: selected == nil,
          isOff: true,
          isAccessibilityTrack: false
        )
      )
    }

    guard let group else { return result }

    result += group.options.enumerated().map { index, option in
      MediaTrackChoice(
        id: optionID(option, index: index, kind: kind),
        kind: kind,
        displayName: option.displayName,
        languageCode: normalizedLanguageCode(for: option),
        isSelected: option == selected,
        isOff: false,
        isAccessibilityTrack: option.hasMediaCharacteristic(.describesVideo)
          || option.hasMediaCharacteristic(.describesMusicAndSound)
          || option.hasMediaCharacteristic(.transcribesSpokenDialog)
      )
    }

    return result
  }

  func option(
    matching choiceID: String,
    in group: AVMediaSelectionGroup?,
    kind: MediaTrackChoice.Kind
  ) -> AVMediaSelectionOption? {
    guard choiceID != "off", let group else { return nil }
    return group.options.enumerated().first {
      optionID($0.element, index: $0.offset, kind: kind) == choiceID
    }?.element
  }

  func option(
    matchingLanguage languageCode: String,
    in group: AVMediaSelectionGroup?
  ) -> AVMediaSelectionOption? {
    guard let group else { return nil }
    return bestLanguageMatch(in: group.options, preferred: languageCode)
  }

  private func chooseAudio(
    from group: AVMediaSelectionGroup?,
    originalLanguageCode: String?,
    preference: AudioSelectionPreference
  ) -> AVMediaSelectionOption? {
    guard let group else { return nil }

    let regularOptions = group.options.filter {
      !$0.hasMediaCharacteristic(.describesVideo)
    }

    if preference == .original,
      let originalLanguageCode,
      let exact = bestLanguageMatch(in: regularOptions, preferred: originalLanguageCode)
    {
      return exact
    }

    if preference == .system,
      let systemLanguage = Locale.preferredLanguages.first,
      let system = bestLanguageMatch(in: regularOptions, preferred: systemLanguage)
    {
      return system
    }

    return group.defaultOption ?? regularOptions.first ?? group.options.first
  }

  private func chooseSubtitles(
    from group: AVMediaSelectionGroup?,
    languageCode: String,
    preference: SubtitleSelectionPreference,
    enabledByDefault: Bool
  ) -> AVMediaSelectionOption? {
    guard enabledByDefault, preference != .off, let group else { return nil }

    let target =
      preference == .system
      ? (Locale.preferredLanguages.first ?? languageCode)
      : languageCode

    let fullSubtitles = group.options.filter {
      !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
    }

    if let regular = bestLanguageMatch(
      in: fullSubtitles.filter {
        !$0.hasMediaCharacteristic(.describesMusicAndSound)
          && !$0.hasMediaCharacteristic(.transcribesSpokenDialog)
      },
      preferred: target
    ) {
      return regular
    }

    return bestLanguageMatch(in: fullSubtitles, preferred: target)
  }

  private func bestLanguageMatch(
    in options: [AVMediaSelectionOption],
    preferred: String
  ) -> AVMediaSelectionOption? {
    options.first {
      guard let candidate = normalizedLanguageCode(for: $0) else { return false }
      return candidate.caseInsensitiveCompare(preferred) == .orderedSame
    }
      ?? options.first {
        guard let candidate = normalizedLanguageCode(for: $0) else { return false }
        return RegionLanguageResolver.languageMatches(candidate, preferred: preferred)
      }
  }

  private func normalizedLanguageCode(for option: AVMediaSelectionOption) -> String? {
    option.extendedLanguageTag ?? option.locale?.identifier
  }

  private func optionID(
    _ option: AVMediaSelectionOption,
    index: Int,
    kind: MediaTrackChoice.Kind
  ) -> String {
    let language = normalizedLanguageCode(for: option) ?? "und"
    return "\(kind)-\(index)-\(language)-\(option.displayName)"
  }
}
