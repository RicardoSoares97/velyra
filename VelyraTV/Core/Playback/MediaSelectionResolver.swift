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
      preference: preferences.preferredAudioLanguage,
      customLanguageCode: preferences.preferredAudioLanguageCode,
      secondaryLanguageCode: preferences.secondaryAudioLanguageCode
    )

    let subtitles = chooseSubtitles(
      from: subtitleGroup,
      regionalLanguageCode: subtitleLanguageCode,
      preference: preferences.preferredSubtitleLanguage,
      customLanguageCode: preferences.preferredSubtitleLanguageCode,
      secondaryLanguageCode: preferences.secondarySubtitleLanguageCode,
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
    preference: AudioSelectionPreference,
    customLanguageCode: String?,
    secondaryLanguageCode: String?
  ) -> AVMediaSelectionOption? {
    guard let group else { return nil }

    let regularOptions = group.options.filter {
      !$0.hasMediaCharacteristic(.describesVideo)
    }

    let preferredCodes: [String?]
    switch preference {
    case .original:
      preferredCodes = [originalLanguageCode, customLanguageCode, secondaryLanguageCode]
    case .system:
      preferredCodes = [Locale.preferredLanguages.first, secondaryLanguageCode, originalLanguageCode]
    case .custom:
      preferredCodes = [customLanguageCode, secondaryLanguageCode, originalLanguageCode]
    }

    for code in preferredCodes.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
      where !code.isEmpty
    {
      if let match = bestLanguageMatch(in: regularOptions, preferred: code) {
        return match
      }
    }

    return group.defaultOption ?? regularOptions.first ?? group.options.first
  }

  private func chooseSubtitles(
    from group: AVMediaSelectionGroup?,
    regionalLanguageCode: String,
    preference: SubtitleSelectionPreference,
    customLanguageCode: String?,
    secondaryLanguageCode: String?,
    enabledByDefault: Bool
  ) -> AVMediaSelectionOption? {
    guard enabledByDefault, preference != .off, let group else { return nil }

    let primary: String?
    switch preference {
    case .region:
      primary = regionalLanguageCode
    case .system:
      primary = Locale.preferredLanguages.first ?? regionalLanguageCode
    case .custom:
      primary = customLanguageCode
    case .off:
      primary = nil
    }

    let fullSubtitles = group.options.filter {
      !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
    }
    let regularSubtitles = fullSubtitles.filter {
      !$0.hasMediaCharacteristic(.describesMusicAndSound)
        && !$0.hasMediaCharacteristic(.transcribesSpokenDialog)
    }

    for code in [primary, secondaryLanguageCode].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
      where !code.isEmpty
    {
      if let regular = bestLanguageMatch(in: regularSubtitles, preferred: code) {
        return regular
      }
      if let accessible = bestLanguageMatch(in: fullSubtitles, preferred: code) {
        return accessible
      }
    }

    return nil
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
