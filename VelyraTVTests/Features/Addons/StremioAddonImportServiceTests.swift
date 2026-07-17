import XCTest

@testable import VelyraTV

final class StremioAddonImportServiceTests: XCTestCase {
  func testUsesOfficialV2LinkEndpoints() async throws {
    let client = StremioRecordingHTTPClient(
      responses: [
        #"{"result":{"code":"CODE","link":"https://link.stremio.com/CODE","qrcode":"QR"}}"#,
        #"{"result":{"authKey":"temporary-key"}}"#,
      ]
    )
    let service = StremioAddonImportService(httpClient: client)

    let link = try await service.createLink()
    let state = try await service.readLink(code: link.code)
    let requests = await client.requests()

    XCTAssertEqual(link.code, "CODE")
    XCTAssertEqual(state, .authorized(StremioAuthKey("temporary-key")))
    XCTAssertEqual(
      requests.map { $0.url?.absoluteString },
      [
        "https://link.stremio.com/api/v2/create?type=Create",
        "https://link.stremio.com/api/v2/read?type=Read&code=CODE",
      ]
    )
    XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" })
  }

  func testReadsCollectionAndLogsOutWithoutWriteEndpoint() async throws {
    let client = StremioRecordingHTTPClient(
      responses: [
        """
        {"result":{"addons":[{"manifest":{"id":"one","version":"1.0.0","name":"One","resources":["catalog"],"types":["movie"],"catalogs":[]},"transportUrl":"https://example.com/addon/","flags":{}}],"lastModified":"2026-07-17T09:00:00Z"}}
        """,
        #"{"result":{"success":true}}"#,
      ]
    )
    let service = StremioAddonImportService(httpClient: client)
    let key = StremioAuthKey("temporary-key")

    let descriptors = try await service.addonCollection(authKey: key)
    try await service.logout(authKey: key)
    let requests = await client.requests()
    let bodies = requests.compactMap(\.httpBody).compactMap {
      String(data: $0, encoding: .utf8)
    }

    XCTAssertEqual(descriptors.first?.manifest.name, "One")
    XCTAssertEqual(descriptors.first?.transportURL, "https://example.com/addon/")
    XCTAssertEqual(
      requests.map { $0.url?.absoluteString },
      [
        "https://api.strem.io/api/addonCollectionGet",
        "https://api.strem.io/api/logout",
      ]
    )
    XCTAssertTrue(bodies[0].contains(#""type":"AddonCollectionGet""#))
    XCTAssertTrue(bodies[0].contains(#""update":true"#))
    XCTAssertTrue(bodies[1].contains(#""type":"Logout""#))
    XCTAssertFalse(bodies.joined().contains("AddonCollectionSet"))
  }
}

private actor StremioRecordingHTTPClient: HTTPClient {
  private var recordedRequests: [URLRequest] = []
  private var responses: [Data]

  init(responses: [String]) {
    self.responses = responses.map { Data($0.utf8) }
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    recordedRequests.append(request)
    let data = responses.removeFirst()
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    return (data, response)
  }

  func requests() -> [URLRequest] {
    recordedRequests
  }
}
