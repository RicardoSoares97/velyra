import Foundation

enum TraktConfiguration {
  static var clientID: String {
    Bundle.main.object(forInfoDictionaryKey: "TRAKT_CLIENT_ID") as? String ?? ""
  }

  static var clientSecret: String {
    Bundle.main.object(forInfoDictionaryKey: "TRAKT_CLIENT_SECRET") as? String ?? ""
  }

  static let apiVersion = "2"
  static let baseURL = URL(string: "https://api.trakt.tv")!

  static var isConfigured: Bool {
    !clientID.isEmpty
      && !clientSecret.isEmpty
      && !clientID.contains("$(")
      && !clientSecret.contains("$(")
  }

  static var userAgent: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "Velyra/\(version) (tvOS; build \(build))"
  }
}
