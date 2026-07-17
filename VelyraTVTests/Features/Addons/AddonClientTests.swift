import Foundation
import XCTest

@testable import VelyraTV

final class AddonClientTests: XCTestCase {
  func testCatalogEncodesExtrasAsOneSafePathSegment() async throws {
    let httpClient = RecordingHTTPClient(
      responseBody: #"{"metas":[]}"#.data(using: .utf8)!
    )
    let client = AddonClient(httpClient: httpClient)

    _ = try await client.catalog(
      manifestURL: URL(string: "https://addon.test/manifest.json")!,
      type: "series",
      id: "popular",
      extras: [
        "genre": "Sci-Fi / Drama",
        "search": "The Last of Us & Friends",
      ]
    )

    let recordedRequest = await httpClient.lastRequest()
    let request = try XCTUnwrap(recordedRequest)
    XCTAssertEqual(
      request.url?.absoluteString,
      "https://addon.test/catalog/series/popular/genre=Sci-Fi%20%2F%20Drama&search=The%20Last%20of%20Us%20%26%20Friends.json"
    )
  }

  func testCatalogSortsExtraKeysForStableRequests() async throws {
    let httpClient = RecordingHTTPClient(
      responseBody: #"{"metas":[]}"#.data(using: .utf8)!
    )
    let client = AddonClient(httpClient: httpClient)

    _ = try await client.catalog(
      manifestURL: URL(string: "https://addon.test/manifest.json")!,
      type: "movie",
      id: "top",
      extras: ["skip": "20", "genre": "Drama"]
    )

    let recordedRequest = await httpClient.lastRequest()
    let request = try XCTUnwrap(recordedRequest)
    XCTAssertTrue(request.url?.absoluteString.hasSuffix("/genre=Drama&skip=20.json") == true)
  }
}

private actor RecordingHTTPClient: HTTPClient {
  private let responseBody: Data
  private var request: URLRequest?

  init(responseBody: Data) {
    self.responseBody = responseBody
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    self.request = request
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    return (responseBody, response)
  }

  func lastRequest() -> URLRequest? {
    request
  }
}
