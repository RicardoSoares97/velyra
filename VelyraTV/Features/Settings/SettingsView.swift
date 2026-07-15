import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @State private var showsResetConfirmation = false
  @State private var showsDiagnostics = false
  @State private var cacheMessage: String?
  @State private var cloudMessage: String?
  @State private var showsCloudDeleteConfirmation = false

  var body: some View {
    ZStack {
      CinematicBackgroundView(videoName: "settings-ambient", focalColor: VelyraTheme.primary)
      ScrollView {
        VStack(alignment: .leading, spacing: 34) {
          header
          appearanceSection
          experienceSection
          smartPlaybackSection
          subtitlesSection
          discoverySection
          syncSection
          TraktSettingsCard(
            session: appState.traktSession, repository: appState.traktLibraryRepository)
          storageSection
          aboutSection
        }
        .padding(.top, 180)
        .padding(.horizontal, 82)
        .padding(.bottom, 100)
      }
    }
    .fullScreenCover(isPresented: $showsDiagnostics) {
      DiagnosticsView().environmentObject(appState)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("settings.title")
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
      Text("settings.body").font(.title3).foregroundStyle(.white.opacity(0.68))
    }
  }

  private var appearanceSection: some View {
    SettingsCard(titleKey: "settings.appearance", systemImage: "circle.lefthalf.filled") {
      SettingsPicker(
        titleKey: "settings.theme",
        selection: binding(\.theme),
        values: AppThemePreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      SettingsPicker(
        titleKey: "settings.language",
        selection: binding(\.language),
        values: AppLanguage.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      optionalCodePicker(
        title: "settings.region",
        selection: binding(\.contentRegion),
        options: Self.regionOptions,
        automaticLabel: "settings.region.automatic"
      )
    }
  }

  private var experienceSection: some View {
    SettingsCard(titleKey: "settings.experience", systemImage: "sparkles.tv") {
      SettingsToggle(
        titleKey: "settings.backgroundVideo",
        subtitleKey: "settings.backgroundVideo.body",
        isOn: binding(\.backgroundVideoEnabled)
      )
      SettingsToggle(
        titleKey: "settings.autoplayPreviews",
        subtitleKey: "settings.autoplayPreviews.body",
        isOn: binding(\.autoplayPreviews)
      )
      SettingsSlider(
        titleKey: "settings.backgroundBlur",
        value: binding(\.backgroundBlurRadius),
        range: 0...12,
        step: 1,
        format: { "\(Int($0))" }
      )
      SettingsSlider(
        titleKey: "settings.backgroundOverlay",
        value: binding(\.backgroundOverlayOpacity),
        range: 0.25...0.8,
        step: 0.05,
        format: { $0.formatted(.percent.precision(.fractionLength(0))) }
      )
    }
  }

  private var smartPlaybackSection: some View {
    SettingsCard(titleKey: "settings.smartPlayback", systemImage: "wand.and.stars") {
      SettingsToggle(
        titleKey: "settings.automaticSource",
        subtitleKey: "settings.automaticSource.body",
        isOn: binding(\.automaticSourceSelection)
      )
      SettingsPicker(
        titleKey: "settings.maximumQuality",
        selection: binding(\.maximumResolution),
        values: PlaybackResolutionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      SettingsToggle(
        titleKey: "settings.preferCached",
        subtitleKey: "settings.preferCached.body",
        isOn: binding(\.preferCachedSources)
      )
      SettingsToggle(
        titleKey: "settings.preferDirectPlay",
        subtitleKey: "settings.preferDirectPlay.body",
        isOn: binding(\.preferDirectPlay)
      )
      SettingsToggle(
        titleKey: "settings.preferDolbyVision",
        subtitleKey: "settings.preferDolbyVision.body",
        isOn: binding(\.preferDolbyVision)
      )
      SettingsToggle(
        titleKey: "settings.preferHDR",
        subtitleKey: "settings.preferHDR.body",
        isOn: binding(\.preferHDR)
      )
      SettingsToggle(
        titleKey: "settings.preferAtmos",
        subtitleKey: "settings.preferAtmos.body",
        isOn: binding(\.preferDolbyAtmos)
      )
      SettingsToggle(
        titleKey: "settings.automaticFailover",
        subtitleKey: "settings.automaticFailover.body",
        isOn: binding(\.automaticSourceFailover)
      )
    }
  }

  private var subtitlesSection: some View {
    SettingsCard(titleKey: "settings.languagesAndSubtitles", systemImage: "captions.bubble.fill") {
      SettingsToggle(
        titleKey: "settings.automaticLanguage",
        subtitleKey: "settings.automaticLanguage.body",
        isOn: binding(\.automaticLanguageSelection)
      )
      SettingsPicker(
        titleKey: "settings.preferredAudio",
        selection: binding(\.preferredAudioLanguage),
        values: AudioSelectionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      optionalCodePicker(
        title: "settings.audio.primaryLanguage",
        selection: binding(\.preferredAudioLanguageCode),
        options: Self.languageOptions,
        automaticLabel: "settings.language.automatic"
      )
      optionalCodePicker(
        title: "settings.audio.secondaryLanguage",
        selection: binding(\.secondaryAudioLanguageCode),
        options: Self.languageOptions,
        automaticLabel: "settings.language.none"
      )
      SettingsToggle(
        titleKey: "settings.subtitles.default",
        subtitleKey: "settings.subtitles.default.body",
        isOn: binding(\.subtitlesEnabledByDefault)
      )
      SettingsPicker(
        titleKey: "settings.preferredSubtitles",
        selection: binding(\.preferredSubtitleLanguage),
        values: SubtitleSelectionPreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      optionalCodePicker(
        title: "settings.subtitles.primaryLanguage",
        selection: binding(\.preferredSubtitleLanguageCode),
        options: Self.languageOptions,
        automaticLabel: "settings.language.automatic"
      )
      optionalCodePicker(
        title: "settings.subtitles.secondaryLanguage",
        selection: binding(\.secondarySubtitleLanguageCode),
        options: Self.languageOptions,
        automaticLabel: "settings.language.none"
      )
      SettingsPicker(
        titleKey: "settings.subtitles.size",
        selection: binding(\.subtitleTextSize),
        values: SubtitleTextSizePreference.allCases,
        label: { LocalizedStringKey($0.displayNameKey) }
      )
      SettingsSlider(
        titleKey: "settings.subtitles.position",
        value: binding(\.subtitleVerticalOffset),
        range: -0.25...0.25,
        step: 0.05,
        format: { String(format: "%+.0f%%", $0 * 100) }
      )
      SettingsSlider(
        titleKey: "settings.subtitles.background",
        value: binding(\.subtitleBackgroundOpacity),
        range: 0...1,
        step: 0.05,
        format: { $0.formatted(.percent.precision(.fractionLength(0))) }
      )
      Button("settings.resetPlaybackPreferences") {
        appState.resetPlaybackPreferences()
      }
      .buttonStyle(VelyraGlassButtonStyle())
    }
  }

  private var discoverySection: some View {
    SettingsCard(titleKey: "settings.discovery", systemImage: "rectangle.stack.fill") {
      SettingsToggle(
        titleKey: "settings.searchHistory",
        subtitleKey: "settings.searchHistory.body",
        isOn: binding(\.searchHistoryEnabled)
      )
      ForEach(Array(appState.preferences.homeSectionOrder.enumerated()), id: \.element.id) {
        index, section in
        HStack(spacing: 18) {
          Toggle(
            LocalizedStringKey("home.section.\(section.rawValue)"),
            isOn: Binding(
              get: { !appState.preferences.hiddenHomeSections.contains(section) },
              set: { visible in
                appState.updatePreferences { preferences in
                  preferences.hiddenHomeSections.removeAll { $0 == section }
                  if !visible { preferences.hiddenHomeSections.append(section) }
                }
              }
            )
          )
          .tint(VelyraTheme.primary)
          .font(.headline)
          Spacer()
          Button {
            moveHomeSection(section, offset: -1)
          } label: {
            Image(systemName: "arrow.up")
          }
          .buttonStyle(VelyraGlassButtonStyle())
          .disabled(index == 0)
          .accessibilityLabel("settings.moveUp")
          Button {
            moveHomeSection(section, offset: 1)
          } label: {
            Image(systemName: "arrow.down")
          }
          .buttonStyle(VelyraGlassButtonStyle())
          .disabled(index == appState.preferences.homeSectionOrder.count - 1)
          .accessibilityLabel("settings.moveDown")
        }
      }
      Text("settings.homeSection.body")
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.54))
      HStack(spacing: 16) {
        Button("settings.resetHomeLayout") {
          appState.resetHomePreferences()
        }
        .buttonStyle(VelyraGlassButtonStyle())
        Button("settings.clearSearchHistory") {
          Task { await appState.clearSearchHistory() }
        }
        .buttonStyle(VelyraGlassButtonStyle())
      }
    }
  }

  private var syncSection: some View {
    SettingsCard(titleKey: "settings.icloud", systemImage: "icloud.fill") {
      SettingsToggle(
        titleKey: "settings.icloudSync",
        subtitleKey: "settings.icloudSync.body",
        isOn: binding(\.iCloudSyncEnabled)
      )
      HStack {
        Label(
          LocalizedStringKey(appState.iCloudAccount.status.localizedKey),
          systemImage: appState.iCloudAccount.status == .available
            ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .foregroundStyle(.white)
        Spacer()
        Text("icloud.noLoginRequired").foregroundStyle(.white.opacity(0.58))
      }
      HStack(spacing: 16) {
        Button("settings.icloud.syncNow") {
          Task {
            await appState.syncCloudNow()
            cloudMessage =
              appState.cloudSyncError
              ?? String(localized: "settings.icloud.syncComplete")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(
          !appState.preferences.iCloudSyncEnabled
            || appState.iCloudAccount.status != .available
        )

        Button("settings.icloud.delete", role: .destructive) {
          showsCloudDeleteConfirmation = true
        }
        .buttonStyle(VelyraGlassButtonStyle())

        if let cloudMessage {
          Text(cloudMessage)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.62))
            .accessibilityLiveRegion(.polite)
        }
      }
      .confirmationDialog(
        "settings.icloud.delete.title",
        isPresented: $showsCloudDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("settings.icloud.delete.confirm", role: .destructive) {
          Task {
            await appState.disableAndDeleteCloudData()
            cloudMessage =
              appState.cloudSyncError
              ?? String(localized: "settings.icloud.delete.done")
          }
        }
        Button("action.cancel", role: .cancel) {}
      } message: {
        Text("settings.icloud.delete.body")
      }

      if let error = appState.cloudSyncError {
        Label(error, systemImage: "exclamationmark.icloud")
          .font(.subheadline)
          .foregroundStyle(.yellow)
      }
    }
  }

  private var storageSection: some View {
    SettingsCard(titleKey: "settings.storageAndDiagnostics", systemImage: "internaldrive.fill") {
      SettingsToggle(
        titleKey: "settings.diagnostics",
        subtitleKey: "settings.diagnostics.body",
        isOn: binding(\.diagnosticsEnabled)
      )
      HStack(spacing: 16) {
        Button("settings.openDiagnostics") { showsDiagnostics = true }
          .buttonStyle(VelyraGlassButtonStyle())
          .disabled(!appState.preferences.diagnosticsEnabled)
        Button("settings.clearCaches") {
          Task {
            await appState.clearCaches()
            cacheMessage = String(localized: "settings.clearCaches.done")
          }
        }
        .buttonStyle(VelyraGlassButtonStyle())
        if let cacheMessage {
          Text(cacheMessage).foregroundStyle(.white.opacity(0.62)).accessibilityLiveRegion(.polite)
        }
      }
    }
  }

  private var aboutSection: some View {
    SettingsCard(titleKey: "settings.about", systemImage: "info.circle.fill") {
      HStack(alignment: .center, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Velyra").font(.title2.bold()).foregroundStyle(.white)
          Text("brand.madeInPortugal").foregroundStyle(.white.opacity(0.62))
        }
        Spacer()
        Text(appVersion).font(.headline.monospacedDigit()).foregroundStyle(.white.opacity(0.5))
      }
      HStack(spacing: 16) {
        Button("settings.restartOnboarding") { appState.resetOnboarding() }
          .buttonStyle(VelyraGlassButtonStyle())
        Button("settings.resetData", role: .destructive) { showsResetConfirmation = true }
          .buttonStyle(VelyraGlassButtonStyle())
      }
      .confirmationDialog(
        "settings.resetData.title",
        isPresented: $showsResetConfirmation,
        titleVisibility: .visible
      ) {
        Button("settings.resetData.confirm", role: .destructive) {
          Task { await appState.resetApplicationData() }
        }
        Button("action.cancel", role: .cancel) {}
      } message: {
        Text("settings.resetData.body")
      }
    }
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
  }

  private func moveHomeSection(_ section: HomeSectionPreference, offset: Int) {
    appState.updatePreferences { preferences in
      guard let source = preferences.homeSectionOrder.firstIndex(of: section) else { return }
      let destination = source + offset
      guard preferences.homeSectionOrder.indices.contains(destination) else { return }
      preferences.homeSectionOrder.swapAt(source, destination)
    }
  }

  private func binding<Value>(_ keyPath: WritableKeyPath<AppPreferences, Value>) -> Binding<Value> {
    Binding(
      get: { appState.preferences[keyPath: keyPath] },
      set: { value in appState.updatePreferences { $0[keyPath: keyPath] = value } }
    )
  }

  private func optionalCodePicker(
    title: LocalizedStringKey,
    selection: Binding<String?>,
    options: [CodeOption],
    automaticLabel: LocalizedStringKey
  ) -> some View {
    HStack {
      Text(title).font(.headline).foregroundStyle(.white)
      Spacer()
      Picker(
        title,
        selection: Binding(
          get: { selection.wrappedValue ?? "" },
          set: { selection.wrappedValue = $0.isEmpty ? nil : $0 }
        )
      ) {
        Text(automaticLabel).tag("")
        ForEach(options) { option in Text(option.name).tag(option.id) }
      }
      .frame(width: 420)
    }
  }

  private static let languageOptions: [CodeOption] = [
    "pt-PT", "en", "es", "fr", "de", "it", "ja", "ko", "pl", "ro", "nl", "sv",
  ].map { CodeOption(id: $0, name: Locale.current.localizedString(forIdentifier: $0) ?? $0) }

  private static let regionOptions: [CodeOption] = [
    "PT", "ES", "FR", "GB", "US", "BR", "DE", "IT", "NL", "PL", "RO",
  ].map { CodeOption(id: $0, name: Locale.current.localizedString(forRegionCode: $0) ?? $0) }
}

private struct CodeOption: Identifiable, Hashable {
  let id: String
  let name: String
}

private struct SettingsCard<Content: View>: View {
  let titleKey: String
  let systemImage: String
  let content: () -> Content
  init(titleKey: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
    self.titleKey = titleKey
    self.systemImage = systemImage
    self.content = content
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Label(LocalizedStringKey(titleKey), systemImage: systemImage)
        .font(.title2.bold()).foregroundStyle(.white)
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
        Text(LocalizedStringKey(titleKey)).font(.headline).foregroundStyle(.white)
        Text(LocalizedStringKey(subtitleKey)).font(.subheadline).foregroundStyle(
          .white.opacity(0.58))
      }
      Spacer()
      Toggle("", isOn: $isOn).labelsHidden().tint(VelyraTheme.primary)
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
      Text(LocalizedStringKey(titleKey)).font(.headline).foregroundStyle(.white)
      Spacer()
      Picker(LocalizedStringKey(titleKey), selection: $selection) {
        ForEach(values) { value in Text(label(value)).tag(value) }
      }
      .frame(width: 420)
    }
  }
}

private struct SettingsSlider: View {
  let titleKey: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let format: (Double) -> String
  var body: some View {
    HStack(spacing: 24) {
      Text(LocalizedStringKey(titleKey)).font(.headline).foregroundStyle(.white)
      Spacer()
      Slider(value: $value, in: range, step: step).frame(width: 300).tint(VelyraTheme.primary)
      Text(format(value)).font(.headline.monospacedDigit()).foregroundStyle(.white.opacity(0.68))
        .frame(width: 86, alignment: .trailing)
    }
  }
}
