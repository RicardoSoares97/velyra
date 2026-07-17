import Foundation

enum StremioAddonImportPlanner {
  enum NormalizationError: Error, Equatable, Sendable {
    case invalid
    case insecure
    case local
  }

  static func normalizedManifestURL(from value: String) throws -> URL {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.utf8.count <= 2_048,
      var components = URLComponents(string: trimmed),
      components.scheme?.lowercased() == "https",
      let host = components.host?.lowercased(),
      !host.isEmpty,
      components.user == nil,
      components.password == nil,
      components.fragment == nil
    else {
      if URLComponents(string: trimmed)?.scheme?.lowercased() != "https" {
        throw NormalizationError.insecure
      }
      throw NormalizationError.invalid
    }

    guard !isLocalHost(host) else {
      throw NormalizationError.local
    }

    components.scheme = "https"
    components.host = host
    guard let baseURL = components.url else {
      throw NormalizationError.invalid
    }

    let result =
      baseURL.lastPathComponent.lowercased() == "manifest.json"
      ? baseURL
      : baseURL.appendingPathComponent("manifest.json", isDirectory: false)

    guard result.absoluteString.utf8.count <= 2_048 else {
      throw NormalizationError.invalid
    }
    return result
  }

  static func candidates(
    from descriptors: [StremioAddonDescriptor],
    installed: [String]
  ) -> [StremioAddonCandidate] {
    let installedKeys = Set(installed.compactMap { normalizedKey(for: $0) })
    var seen = Set<String>()
    var result: [StremioAddonCandidate] = []

    for descriptor in descriptors {
      do {
        let url = try normalizedManifestURL(from: descriptor.transportURL)
        let key = normalizedKey(for: url)
        guard seen.insert(key).inserted else { continue }
        result.append(
          StremioAddonCandidate(
            manifest: descriptor.manifest,
            manifestURL: url,
            status: installedKeys.contains(key) ? .installed : .new,
            isSelected: !installedKeys.contains(key)
          )
        )
      } catch let error as NormalizationError {
        let reason: StremioAddonIncompatibility =
          switch error {
          case .invalid: .invalidURL
          case .insecure: .insecureURL
          case .local: .localURL
          }
        let invalidKey = "invalid:\(descriptor.manifest.id):\(descriptor.transportURL.lowercased())"
        guard seen.insert(invalidKey).inserted else { continue }
        result.append(
          StremioAddonCandidate(
            manifest: descriptor.manifest,
            manifestURL: nil,
            status: .incompatible(reason: reason),
            isSelected: false,
            sourceIdentifier: invalidKey
          )
        )
      } catch {
        continue
      }
    }
    return result
  }

  static func merging(
    existing: [String],
    candidates: [StremioAddonCandidate]
  ) -> [String] {
    var merged = existing
    var seen = Set(existing.compactMap { normalizedKey(for: $0) })

    for candidate in candidates
    where candidate.isSelected && candidate.status == .new {
      guard let url = candidate.manifestURL else { continue }
      let key = normalizedKey(for: url)
      guard seen.insert(key).inserted else { continue }
      merged.append(url.absoluteString)
    }
    return merged
  }

  private static func normalizedKey(for value: String) -> String? {
    guard let url = try? normalizedManifestURL(from: value) else { return nil }
    return normalizedKey(for: url)
  }

  private static func normalizedKey(for url: URL) -> String {
    url.absoluteString.lowercased()
  }

  private static func isLocalHost(_ host: String) -> Bool {
    let normalizedHost = host.trimmingCharacters(
      in: CharacterSet(charactersIn: "[]")
    )
    return normalizedHost == "localhost" || normalizedHost == "127.0.0.1"
      || normalizedHost == "::1" || normalizedHost.hasSuffix(".localhost")
  }
}
