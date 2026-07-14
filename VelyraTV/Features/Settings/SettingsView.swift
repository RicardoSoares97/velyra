import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    ZStack {
      CinematicBackgroundView(videoName: "settings-ambient", focalColor: VelyraTheme.primary)

      ScrollView {
        VStack(alignment: .leading, spacing: 34) {
          header
          appearanceSection
          playbackSection
          smartPlaybackSection
          syncSection
          TraktSettingsCard(session: appState.traktSession)
          aboutSection
        }
        .padding(.top, 180)
        .padding(.horizontal, 82)
        .padding(.bottom, 100)
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("settings.title")
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
      Text("settings.body")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.68))
    }
  }

  private var appearanceSection: some View {
    SettingsCard(titleKey: "settings.appearance", systemImage: "circle.lefthalf.filled") {
      SettingsPicker(
        titleKey: "settings.theme",
        selection: Binding(
          get: { appState.preferences.theme },
          set: { value in appState.updatePreferences { $0.theme = value } }
        ),
        values: AppThemePreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )

      SettingsPicker(
        titleKey: "settings.language",
        selection: Binding(
          get: { appState.preferences.language },
          set: { value in appState.updatePreferences { $0.language = value } }
        ),
        values: AppLanguage.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
    }
  }

  private var playbackSection: some View {
    SettingsCard(titleKey: "settings.experience", systemImage: "sparkles.tv") {
      SettingsToggle(
        titleKey: "settings.backgroundVideo",
        subtitleKey: "settings.backgroundVideo.body",
        isOn: Binding(
          get: { appState.preferences.backgroundVideoEnabled },
          set: { value in appState.updatePreferences { $0.backgroundVideoEnabled = value } }
        )
      )

      SettingsToggle(
        titleKey: "settings.autoplayPreviews",
        subtitleKey: "settings.autoplayPreviews.body",
        isOn: Binding(
          get: { appState.preferences.autoplayPreviews },
          set: { value in appState.updatePreferences { $0.autoplayPreviews = value } }
        )
      )
    }
  }

  private var smartPlaybackSection: some View {
    SettingsCard(titleKey: "settings.smartPlayback", systemImage: "wand.and.stars") {
      SettingsToggle(
        titleKey: "settings.automaticSource",
        subtitleKey: "settings.automaticSource.body",
        isOn: Binding(
          get: { appState.preferences.automaticSourceSelection },
          set: { value in appState.updatePreferences { $0.automaticSourceSelection = value } }
        )
      )

      SettingsPicker(
        titleKey: "settings.maximumQuality",
        selection: Binding(
          get: { appState.preferences.maximumResolution },
          set: { value in appState.updatePreferences { $0.maximumResolution = value } }
        ),
        values: PlaybackResolutionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )

      SettingsPicker(
        titleKey: "settings.preferredAudio",
        selection: Binding(
          get: { appState.preferences.preferredAudioLanguage },
          set: { value in appState.updatePreferences { $0.preferredAudioLanguage = value } }
        ),
        values: AudioSelectionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )

      SettingsPicker(
        titleKey: "settings.preferredSubtitles",
        selection: Binding(
          get: { appState.preferences.preferredSubtitleLanguage },
          set: { value in appState.updatePreferences { $0.preferredSubtitleLanguage = value } }
        ),
        values: SubtitleSelectionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )

      SettingsToggle(
        titleKey: "settings.automaticFailover",
        subtitleKey: "settings.automaticFailover.body",
        isOn: Binding(
          get: { appState.preferences.automaticSourceFailover },
          set: { value in appState.updatePreferences { $0.automaticSourceFailover = value } }
        )
      )

      HStack {
        Label("settings.region", systemImage: "globe.europe.africa.fill")
          .foregroundStyle(.white)
        Spacer()
        Text(regionDisplayName)
          .foregroundStyle(.white.opacity(0.62))
      }
    }
  }

  private var regionDisplayName: String {
    let code = appState.preferences.contentRegion ?? RegionLanguageResolver.regionCode()
    return Locale.current.localizedString(forRegionCode: code) ?? code
  }

  private var syncSection: some View {
    SettingsCard(titleKey: "settings.icloud", systemImage: "icloud.fill") {
      SettingsToggle(
        titleKey: "settings.icloudSync",
        subtitleKey: "settings.icloudSync.body",
        isOn: Binding(
          get: { appState.preferences.iCloudSyncEnabled },
          set: { value in appState.updatePreferences { $0.iCloudSyncEnabled = value } }
        )
      )

      HStack {
        Label(
          LocalizedStringKey(appState.iCloudAccount.status.localizedKey),
          systemImage: appState.iCloudAccount.status == .available
            ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .foregroundStyle(.white)

        Spacer()

        Text("icloud.noLoginRequired")
          .foregroundStyle(.white.opacity(0.58))
      }
    }
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
  }

  private var aboutSection: some View {
    SettingsCard(titleKey: "settings.about", systemImage: "info.circle.fill") {
      HStack(alignment: .center, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Velyra")
            .font(.title2.bold())
            .foregroundStyle(.white)
          Text("brand.madeInPortugal")
            .foregroundStyle(.white.opacity(0.62))
        }
        Spacer()
        Text(appVersion)
          .font(.headline.monospacedDigit())
          .foregroundStyle(.white.opacity(0.5))
      }

      Button("settings.restartOnboarding") {
        appState.resetOnboarding()
      }
      .buttonStyle(VelyraGlassButtonStyle())
    }
  }
}

private struct SettingsCard<Content: View>: View {
  let titleKey: String
  let systemImage: String
  let content: () -> Content

  init(
    titleKey: String,
    systemImage: String,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.titleKey = titleKey
    self.systemImage = systemImage
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Label(LocalizedStringKey(titleKey), systemImage: systemImage)
        .font(.title2.bold())
        .foregroundStyle(.white)

      Divider().overlay(.white.opacity(0.16))
      content()
    }
    .padding(30)
    .velyraGlass(cornerRadius: 30)
  }
}

private struct SettingsToggle: View {
  let titleKey: String
  let subtitleKey: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 5) {
        Text(LocalizedStringKey(titleKey))
          .font(.headline)
          .foregroundStyle(.white)
        Text(LocalizedStringKey(subtitleKey))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.58))
      }
      Spacer()
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .tint(VelyraTheme.primary)
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
    }
  }
}

private struct SettingsPicker<Value: Hashable & Identifiable>: View {
  let titleKey: String
  @Binding var selection: Value
  let values: [Value]
  let label: (Value) -> LocalizedStringKey

  var body: some View {
    HStack {
      Text(LocalizedStringKey(titleKey))
        .font(.headline)
        .foregroundStyle(.white)
      Spacer()
      Picker(LocalizedStringKey(titleKey), selection: $selection) {
        ForEach(values) { value in
          Text(label(value)).tag(value)
        }
      }
      .frame(width: 420)
    }
  }
}
