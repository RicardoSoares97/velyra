import XCTest

@testable import VelyraTV

final class StremioImportSessionTests: XCTestCase {
  func testPendingThenAuthorizedFetchesCollectionAndLogsOut() async throws {
    let descriptor = StremioAddonDescriptor(
      manifest: manifest(),
      transportURL: "https://example.com/addon/"
    )
    let service = StremioSessionService(
      states: [.pending, .authorized(StremioAuthKey("temporary"))],
      collectionResult: .success([descriptor])
    )
    let sleeper = StremioImmediateSleeper()
    let session = StremioImportSession(service: service, sleeper: sleeper)
    let link = StremioLinkCode(
      code: "CODE",
      linkURL: URL(string: "https://link.stremio.com/CODE")!,
      qrCodePayload: "QR",
      expiresAt: Date().addingTimeInterval(120)
    )

    let result = try await session.fetchDescriptors(link: link)
    let readCount = await service.readCount()
    let logoutCount = await service.logoutCount()
    let sleepCount = await sleeper.sleepCount()
    let hasAuthorizationMaterial = await session.hasAuthorizationMaterial()

    XCTAssertEqual(result, [descriptor])
    XCTAssertEqual(readCount, 2)
    XCTAssertEqual(logoutCount, 1)
    XCTAssertEqual(sleepCount, 1)
    XCTAssertFalse(hasAuthorizationMaterial)
  }

  func testCollectionFailureStillLogsOutAndClearsKey() async {
    let service = StremioSessionService(
      states: [.authorized(StremioAuthKey("temporary"))],
      collectionResult: .failure(.collectionUnavailable)
    )
    let session = StremioImportSession(service: service, sleeper: StremioImmediateSleeper())
    let link = StremioLinkCode(
      code: "CODE",
      linkURL: URL(string: "https://link.stremio.com/CODE")!,
      qrCodePayload: "QR",
      expiresAt: Date().addingTimeInterval(120)
    )

    do {
      _ = try await session.fetchDescriptors(link: link)
      XCTFail("Expected collection failure")
    } catch {
      XCTAssertEqual(error as? StremioImportError, .collectionUnavailable)
    }
    let logoutCount = await service.logoutCount()
    let hasAuthorizationMaterial = await session.hasAuthorizationMaterial()

    XCTAssertEqual(logoutCount, 1)
    XCTAssertFalse(hasAuthorizationMaterial)
  }

  private func manifest() -> AddonManifest {
    AddonManifest(
      id: "one",
      version: "1.0.0",
      name: "One",
      description: nil,
      resources: [.name("catalog")],
      types: ["movie"],
      catalogs: [],
      idPrefixes: nil
    )
  }
}

private actor StremioSessionService: StremioAddonImportServing {
  private var states: [StremioAuthorizationState]
  private let collectionResult: Result<[StremioAddonDescriptor], StremioImportError>
  private var reads = 0
  private var logouts = 0

  init(
    states: [StremioAuthorizationState],
    collectionResult: Result<[StremioAddonDescriptor], StremioImportError>
  ) {
    self.states = states
    self.collectionResult = collectionResult
  }

  func createLink() async throws -> StremioLinkCode {
    throw StremioImportError.linkUnavailable
  }

  func readLink(code: String) async throws -> StremioAuthorizationState {
    reads += 1
    return states.removeFirst()
  }

  func addonCollection(authKey: StremioAuthKey) async throws -> [StremioAddonDescriptor] {
    try collectionResult.get()
  }

  func logout(authKey: StremioAuthKey) async throws {
    logouts += 1
  }

  func readCount() -> Int { reads }
  func logoutCount() -> Int { logouts }
}

private actor StremioImmediateSleeper: StremioImportSleeping {
  private var count = 0

  func sleep(for duration: Duration) async throws {
    count += 1
  }

  func sleepCount() -> Int { count }
}
