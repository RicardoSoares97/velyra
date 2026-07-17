import XCTest

@testable import VelyraTV

final class StremioAddonImportPlannerTests: XCTestCase {
  func testNormalizesHTTPSManifestAndTransportBase() throws {
    XCTAssertEqual(
      try StremioAddonImportPlanner.normalizedManifestURL(
        from: "https://example.com/addon/manifest.json"
      ).absoluteString,
      "https://example.com/addon/manifest.json"
    )
    XCTAssertEqual(
      try StremioAddonImportPlanner.normalizedManifestURL(
        from: "https://example.com/addon/"
      ).absoluteString,
      "https://example.com/addon/manifest.json"
    )
  }

  func testRejectsInsecureLocalAndCredentialBearingURLs() {
    for value in [
      "http://example.com/manifest.json",
      "https://localhost/addon",
      "https://127.0.0.1/addon",
      "https://[::1]/addon",
      "https://user:secret@example.com/addon",
    ] {
      XCTAssertThrowsError(
        try StremioAddonImportPlanner.normalizedManifestURL(from: value),
        "Expected rejection for \(value)"
      )
    }
  }

  func testDeduplicatesEquivalentCandidatesAndClassifiesInstalled() {
    let descriptor = StremioAddonDescriptor(
      manifest: manifest(id: "one", name: "One"),
      transportURL: "https://EXAMPLE.com/addon/"
    )
    let duplicate = StremioAddonDescriptor(
      manifest: manifest(id: "one-copy", name: "One Copy"),
      transportURL: "https://example.com/addon/manifest.json"
    )

    let candidates = StremioAddonImportPlanner.candidates(
      from: [descriptor, duplicate],
      installed: ["https://example.com/addon/manifest.json"]
    )

    XCTAssertEqual(candidates.count, 1)
    XCTAssertEqual(candidates.first?.status, .installed)
    XCTAssertEqual(candidates.first?.redactedHost, "example.com")
  }

  func testMergeAppendsOnlySelectedNewCandidatesWithoutReplacingExisting() throws {
    let existing = ["https://existing.example/manifest.json"]
    let newURL = try StremioAddonImportPlanner.normalizedManifestURL(
      from: "https://new.example/addon"
    )
    let installedURL = try StremioAddonImportPlanner.normalizedManifestURL(
      from: existing[0]
    )
    let candidates = [
      StremioAddonCandidate(
        manifest: manifest(id: "new", name: "New"),
        manifestURL: newURL,
        status: .new,
        isSelected: true
      ),
      StremioAddonCandidate(
        manifest: manifest(id: "installed", name: "Installed"),
        manifestURL: installedURL,
        status: .installed,
        isSelected: true
      ),
    ]

    XCTAssertEqual(
      StremioAddonImportPlanner.merging(existing: existing, candidates: candidates),
      [
        "https://existing.example/manifest.json",
        "https://new.example/addon/manifest.json",
      ]
    )
  }

  private func manifest(id: String, name: String) -> AddonManifest {
    AddonManifest(
      id: id,
      version: "1.0.0",
      name: name,
      description: nil,
      resources: [.name("catalog")],
      types: ["movie"],
      catalogs: [],
      idPrefixes: nil
    )
  }
}
