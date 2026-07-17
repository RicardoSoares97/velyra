import Foundation
import UIKit

struct DiagnosticsReport: Codable, Equatable, Sendable {
  struct Device: Codable, Equatable, Sendable {
    let systemName: String
    let systemVersion: String
    let model: String
    let locale: String
    let region: String
  }

  struct Application: Codable, Equatable, Sendable {
    let version: String
    let build: String
    let preferredLanguage: String
    let contentRegion: String
    let iCloudEnabled: Bool
    let iCloudStatus: String
    let traktConnected: Bool
    let pendingTraktChanges: Int
    let failedTraktChanges: Int
    let enabledAddonCount: Int
    let disabledAddonCount: Int
    let maximumResolution: String
    let automaticFailover: Bool
    let uncleanExitCount: Int
    let lastUncleanExitDetectedAt: Date?
  }

  let generatedAt: Date
  let device: Device
  let application: Application

  var formattedText: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(self) else { return "" }
    return String(decoding: data, as: UTF8.self)
  }
}

@MainActor
enum DiagnosticsReportBuilder {
  static func build(appState: AppState) async -> DiagnosticsReport {
    let preferences = appState.preferences
    let launchHealth = await appState.launchHealth.snapshot()
    return DiagnosticsReport(
      generatedAt: Date(),
      device: DiagnosticsReport.Device(
        systemName: UIDevice.current.systemName,
        systemVersion: UIDevice.current.systemVersion,
        model: UIDevice.current.model,
        locale: Locale.current.identifier,
        region: Locale.current.region?.identifier ?? "unknown"
      ),
      application: DiagnosticsReport.Application(
        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
        preferredLanguage: preferences.language.rawValue,
        contentRegion: preferences.contentRegion ?? "automatic",
        iCloudEnabled: appState.distributionCapabilities.supportsCloudKit
          && preferences.iCloudSyncEnabled,
        iCloudStatus: appState.distributionCapabilities.supportsCloudKit
          ? appState.iCloudAccount.status.localizedKey : "local-only",
        traktConnected: appState.traktSession.isConnected,
        pendingTraktChanges: await appState.traktLibraryRepository.pendingMutationCount(),
        failedTraktChanges: await appState.traktLibraryRepository.failedMutationCount(),
        enabledAddonCount: preferences.activeAddonManifestURLs.count,
        disabledAddonCount: preferences.disabledAddonManifestURLs.count,
        maximumResolution: preferences.maximumResolution.rawValue,
        automaticFailover: preferences.automaticSourceFailover,
        uncleanExitCount: launchHealth.uncleanExitCount,
        lastUncleanExitDetectedAt: launchHealth.lastUncleanExitDetectedAt
      )
    )
  }
}
