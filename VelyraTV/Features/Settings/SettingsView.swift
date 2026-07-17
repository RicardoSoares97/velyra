import SwiftUI
import UIKit

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState
  @State private var showsResetConfirmation = false
  @State private var showsDiagnostics = false
  @State private var cacheMessage: String?
  @State private var cloudMessage: String?
  @State private var showsCloudDeleteConfirmation = false
  @State private var showsStremioImport = false

  var body: some View {
    NavigationStack {
      ZStack {
        settingsBackground

        ScrollView {
          VStack(alignment: .leading, spacing: 34) {
            header

            LazyVGrid(
              columns: [
                GridItem(.flexible(), spacing: 28),
                GridItem(.flexible(), spacing: 28),
              ],
              spacing: 28
            ) {
              ForEach(SettingsCategory.allCases) { category in
                SettingsCategoryTile(category: category)
              }
            }
          }
          .padding(.top, 72)
          .padding(.horizontal, 82)
          .padding(.bottom, 100)
        }
      }
      .navigationDestination(for: SettingsCategory.self) { category in
        categoryDetail(category)
      }
    }
    .fullScreenCover(isPresented: $showsDiagnostics) {
      DiagnosticsView().environmentObject(appState)
    }
    .fullScreenCover(isPresented: $showsStremioImport) {
      StremioImportView(
        existingURLs: appState.preferences.addonManifestURLs,
        onImport: { urls in
          appState.updatePreferences { $0.addonManifestURLs = urls }
        },
        onClose: { showsStremioImport = false }
      )
      .environmentObject(appState)
    }
    .onChange(of: cloudMessage) { _, cloudMessage in
      postQueuedAccessibilityAnnouncement(cloudMessage)
    }
    .onChange(of: cacheMessage) { _, cacheMessage in
      postQueuedAccessibilityAnnouncement(cacheMessage)
    }
  }

  private var settingsBackground: some View {
    ZStack {
      Color(red: 0.025, green: 0.025, blue: 0.035)
      RadialGradient(
        colors: [VelyraTheme.primary.opacity(0.13), .clear],
        center: .topTrailing,
        startRadius: 20,
        endRadius: 920
      )
    }
    .ignoresSafeArea()
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("settings.title")
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
      Text("settings.body").font(.title3).foregroundStyle(.white.opacity(0.68))
    }
  }

  private func categoryDetail(_ category: SettingsCategory) -> some View {
    ZStack {
      settingsBackground

      ScrollView {
        VStack(alignment: .leading, spacing: 30) {
          VStack(alignment: .leading, spacing: 10) {
            Label(LocalizedStringKey(category.titleKey), systemImage: category.systemImage)
              .font(.system(size: 46, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey(category.summaryKey))
              .font(.title3)
              .foregroundStyle(.white.opacity(0.62))
          }

          categoryContent(category)
        }
        .padding(.horizontal, 94)
        .padding(.vertical, 64)
        .frame(maxWidth: 1_520, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
    }
    .navigationTitle(LocalizedStringKey(category.titleKey))
  }

  @ViewBuilder
  private func categoryContent(_ category: SettingsCategory) -> some View {
    switch category {
    case .appearance:
      appearanceSection
    case .experience:
      experienceSection
    case .playback:
      smartPlaybackSection
    case .audioSubtitles:
      subtitlesSection
    case .homeSearch:
      discoverySection
    case .accountsSync:
      syncSection
      TraktSettingsCard(
        session: appState.traktSession,
        repository: appState.traktLibraryRepository
      )
      stremioSection
    case .storageDiagnostics:
      storageSection
    case .about:
      aboutSection
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
            LocalizedStringKey(section.displayNameKey),
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

  @ViewBuilder
  private var syncSection: some View {
    if appState.distributionCapabilities.isSideload {
      SettingsCard(titleKey: "settings.sideload.title", systemImage: "internaldrive.fill") {
        Text("settings.sideload.body")
          .font(.headline)
          .foregroundStyle(.white.opacity(0.72))
      }
    } else {
      SettingsCard(titleKey: "settings.icloud", systemImage: "icloud.fill") {
        SettingsToggle(
          titleKey: "settings.icloudSync",
          subtitleKey: "settings.icloudSync.body",
          isOn: binding(\.iCloudSyncEnabled)
        )
        cloudControls
      }
    }
  }

  private var stremioSection: some View {
    SettingsCard(titleKey: "stremio.import.title", systemImage: "puzzlepiece.extension.fill") {
      Text("stremio.import.settingsBody")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.68))
        .fixedSize(horizontal: false, vertical: true)

      Button {
        showsStremioImport = true
      } label: {
        Label("stremio.import.action", systemImage: "arrow.down.circle")
      }
      .buttonStyle(VelyraGlassButtonStyle(prominent: true))
    }
  }

  @ViewBuilder
  private var cloudControls: some View {
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
          Text(cacheMessage).foregroundStyle(.white.opacity(0.62))
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

@MainActor
private func postQueuedAccessibilityAnnouncement(_ message: String?) {
  guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    return
  }
  let announcement = NSMutableAttributedString(string: message)
  announcement.addAttribute(
    .accessibilitySpeechQueueAnnouncement,
    value: true,
    range: NSRange(location: 0, length: announcement.length)
  )
  UIAccessibility.post(notification: .announcement, argument: announcement)
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
    .background(
      Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.94),
      in: RoundedRectangle(cornerRadius: 30, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 30, style: .continuous)
        .stroke(.white.opacity(0.1), lineWidth: 1)
    }
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
    .frame(minHeight: 84)
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
    .frame(minHeight: 84)
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
      HStack(spacing: 16) {
        Button {
          adjustValue(by: -step)
        } label: {
          Image(systemName: "minus")
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(value <= range.lowerBound)
        .accessibilityLabel(
          Text("settings.adjust.decrease") + Text(verbatim: " ")
            + Text(LocalizedStringKey(titleKey))
        )
        .accessibilityValue(format(value))

        Text(format(value))
          .font(.headline.monospacedDigit())
          .foregroundStyle(.white.opacity(0.68))
          .frame(width: 86)

        Button {
          adjustValue(by: step)
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(VelyraGlassButtonStyle())
        .disabled(value >= range.upperBound)
        .accessibilityLabel(
          Text("settings.adjust.increase") + Text(verbatim: " ")
            + Text(LocalizedStringKey(titleKey))
        )
        .accessibilityValue(format(value))
      }
      .frame(width: 300)
    }
    .frame(minHeight: 84)
  }

  private func adjustValue(by delta: Double) {
    value = min(max(value + delta, range.lowerBound), range.upperBound)
  }
}
