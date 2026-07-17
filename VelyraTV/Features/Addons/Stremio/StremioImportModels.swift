import Foundation

struct StremioAuthKey: Equatable, Sendable, CustomDebugStringConvertible {
  let requestValue: String

  init(_ value: String) {
    requestValue = value
  }

  var debugDescription: String { "<redacted>" }
}

struct StremioLinkCode: Equatable, Sendable {
  let code: String
  let linkURL: URL
  let qrCodePayload: String
  let expiresAt: Date
}

enum StremioAuthorizationState: Equatable, Sendable {
  case pending
  case authorized(StremioAuthKey)
}

struct StremioAddonDescriptor: Equatable, Sendable {
  let manifest: AddonManifest
  let transportURL: String
}

enum StremioAddonCandidateStatus: Equatable, Sendable {
  case new
  case installed
  case incompatible(reason: StremioAddonIncompatibility)
}

enum StremioAddonIncompatibility: String, Equatable, Sendable {
  case invalidURL
  case insecureURL
  case localURL
  case unreachable
  case manifestMismatch
}

struct StremioAddonCandidate: Identifiable, Equatable, Sendable {
  var manifest: AddonManifest
  let manifestURL: URL?
  var status: StremioAddonCandidateStatus
  var isSelected: Bool
  private let sourceIdentifier: String

  init(
    manifest: AddonManifest,
    manifestURL: URL?,
    status: StremioAddonCandidateStatus,
    isSelected: Bool,
    sourceIdentifier: String? = nil
  ) {
    self.manifest = manifest
    self.manifestURL = manifestURL
    self.status = status
    self.isSelected = isSelected
    self.sourceIdentifier =
      sourceIdentifier
      ?? manifestURL?.absoluteString
      ?? "invalid:\(manifest.id):\(manifest.version)"
  }

  var id: String {
    sourceIdentifier
  }

  var redactedHost: String {
    manifestURL?.host ?? "—"
  }
}

struct StremioImportPreview: Equatable, Sendable {
  var candidates: [StremioAddonCandidate]

  var selectedImportCount: Int {
    candidates.filter { $0.isSelected && $0.status == .new }.count
  }
}

enum StremioImportError: LocalizedError, Equatable, Sendable {
  case invalidResponse
  case linkUnavailable
  case expired
  case timedOut
  case collectionUnavailable
  case cancelled

  var errorDescription: String? {
    switch self {
    case .invalidResponse: String(localized: "stremio.error.invalidResponse")
    case .linkUnavailable: String(localized: "stremio.error.link")
    case .expired: String(localized: "stremio.error.expired")
    case .timedOut: String(localized: "stremio.error.timeout")
    case .collectionUnavailable: String(localized: "stremio.error.collection")
    case .cancelled: String(localized: "stremio.error.cancelled")
    }
  }
}
