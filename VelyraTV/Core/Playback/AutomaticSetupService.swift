import Foundation

struct AutomaticSetupSummary: Equatable {
  let regionCode: String
  let regionName: String
  let subtitleLanguageCode: String
  let subtitleLanguageName: String
}

struct AutomaticSetupService {
  func summary(locale: Locale = .autoupdatingCurrent) -> AutomaticSetupSummary {
    let regionCode = RegionLanguageResolver.regionCode(for: locale)
    let languageCode = RegionLanguageResolver.subtitleLanguageCode(for: regionCode)
    let regionName = locale.localizedString(forRegionCode: regionCode) ?? regionCode
    let languageName =
      locale.localizedString(forIdentifier: languageCode)
      ?? Locale(identifier: languageCode).localizedString(forLanguageCode: languageCode)
      ?? languageCode

    return AutomaticSetupSummary(
      regionCode: regionCode,
      regionName: regionName,
      subtitleLanguageCode: languageCode,
      subtitleLanguageName: languageName
    )
  }

  func configuredPreferences(
    from current: AppPreferences,
    locale: Locale = .autoupdatingCurrent
  ) -> AppPreferences {
    var preferences = current
    let setup = summary(locale: locale)

    if preferences.contentRegion == nil {
      preferences.contentRegion = setup.regionCode
    }

    preferences.iCloudSyncEnabled = true
    preferences.preferredAudioLanguage = .original
    preferences.preferredSubtitleLanguage = .region
    preferences.subtitlesEnabledByDefault = true
    preferences.automaticSourceSelection = true
    preferences.automaticLanguageSelection = true
    preferences.maximumResolution = .automatic
    preferences.preferDirectPlay = true
    preferences.preferDolbyVision = true
    preferences.preferHDR = true
    preferences.preferDolbyAtmos = true
    preferences.automaticSourceFailover = true

    return preferences
  }
}

enum RegionLanguageResolver {
  static func regionCode(for locale: Locale = .autoupdatingCurrent) -> String {
    if let region = locale.region?.identifier, !region.isEmpty {
      return region.uppercased()
    }

    let components = Locale.Components(identifier: locale.identifier)
    return (components.region?.identifier ?? "PT").uppercased()
  }

  static func subtitleLanguageCode(for regionCode: String) -> String {
    let region = regionCode.uppercased()

    let explicit: [String: String] = [
      "PT": "pt-PT",
      "BR": "pt-BR",
      "ES": "es-ES",
      "MX": "es-MX",
      "AR": "es-AR",
      "CO": "es-CO",
      "EC": "es-EC",
      "US": "en-US",
      "GB": "en-GB",
      "IE": "en-IE",
      "CA": "en-CA",
      "AU": "en-AU",
      "NZ": "en-NZ",
      "FR": "fr-FR",
      "BE": "fr-BE",
      "CH": "de-CH",
      "DE": "de-DE",
      "AT": "de-AT",
      "IT": "it-IT",
      "NL": "nl-NL",
      "PL": "pl-PL",
      "RO": "ro-RO",
      "CZ": "cs-CZ",
      "SK": "sk-SK",
      "HU": "hu-HU",
      "GR": "el-GR",
      "TR": "tr-TR",
      "SE": "sv-SE",
      "NO": "nb-NO",
      "DK": "da-DK",
      "FI": "fi-FI",
      "JP": "ja-JP",
      "KR": "ko-KR",
      "CN": "zh-Hans-CN",
      "TW": "zh-Hant-TW",
      "HK": "zh-Hant-HK",
      "IN": "hi-IN",
    ]

    if let language = explicit[region] {
      return language
    }

    return Locale.preferredLanguages.first ?? "en"
  }

  static func languageMatches(_ candidate: String?, preferred: String) -> Bool {
    guard let candidate else { return false }
    let normalizedCandidate = candidate.replacingOccurrences(of: "_", with: "-").lowercased()
    let normalizedPreferred = preferred.replacingOccurrences(of: "_", with: "-").lowercased()

    if normalizedCandidate == normalizedPreferred {
      return true
    }

    let candidateBase = normalizedCandidate.split(separator: "-").first.map(String.init)
    let preferredBase = normalizedPreferred.split(separator: "-").first.map(String.init)
    return candidateBase == preferredBase
  }
}
