import Foundation

struct AddonConfigurationTransfer: Codable, Equatable, Sendable {
  let schemaVersion: Int
  let manifestURLs: [String]
  let disabledManifestURLs: [String]
  let priority: [String]

  static func make(preferences: AppPreferences) -> AddonConfigurationTransfer {
    AddonConfigurationTransfer(
      schemaVersion: 1,
      manifestURLs: preferences.addonManifestURLs,
      disabledManifestURLs: preferences.disabledAddonManifestURLs,
      priority: preferences.addonPriority
    )
  }

  func encodedCode() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let value = try encoder.encode(self).base64EncodedString()
    return value
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func decode(code: String) throws -> AddonConfigurationTransfer {
    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = normalized.count % 4
    let padded = normalized + (remainder == 0 ? "" : String(repeating: "=", count: 4 - remainder))
    guard let data = Data(base64Encoded: padded) else {
      throw TransferError.invalidCode
    }
    let decoded = try JSONDecoder().decode(AddonConfigurationTransfer.self, from: data)
    guard decoded.schemaVersion == 1,
      decoded.manifestURLs.allSatisfy(Self.isSupportedManifestURL)
    else { throw TransferError.unsupportedPayload }
    return decoded
  }

  func applying(to preferences: inout AppPreferences) {
    preferences.addonManifestURLs = manifestURLs
    preferences.disabledAddonManifestURLs = disabledManifestURLs
    preferences.addonPriority = priority
    preferences.normalize()
  }

  enum TransferError: LocalizedError {
    case invalidCode
    case unsupportedPayload

    var errorDescription: String? {
      switch self {
      case .invalidCode: String(localized: "addons.transfer.invalidCode")
      case .unsupportedPayload: String(localized: "addons.transfer.unsupported")
      }
    }
  }

  private static func isSupportedManifestURL(_ value: String) -> Bool {
    guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "https" || (scheme == "http" && url.host == "127.0.0.1")
  }
}
