import XCTest

@testable import VelyraTV

final class HTTPClientTests: XCTestCase {
  override func tearDown() {
    HTTPStubURLProtocol.handler = nil
    super.tearDown()
  }

  func testRejectsNonSuccessStatusCode() async throws {
    HTTPStubURLProtocol.handler = { request in
      let response = HTTPURLResponse(
        url: try XCTUnwrap(request.url),
        statusCode: 503,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data())
    }

    let client = URLSessionHTTPClient(session: makeSession())
    let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/status")))

    do {
      _ = try await client.data(for: request)
      XCTFail("Expected the client to reject HTTP 503")
    } catch let error as HTTPClientError {
      XCTAssertEqual(error, .httpStatus(503))
    }
  }

  func testRejectsResponsesAboveConfiguredLimit() async throws {
    HTTPStubURLProtocol.handler = { request in
      let response = HTTPURLResponse(
        url: try XCTUnwrap(request.url),
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data(repeating: 0x41, count: 64))
    }

    let client = URLSessionHTTPClient(
      session: makeSession(),
      maximumResponseBytes: 16
    )
    let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/large")))

    do {
      _ = try await client.data(for: request)
      XCTFail("Expected the client to reject an oversized response")
    } catch let error as HTTPClientError {
      XCTAssertEqual(error, .responseTooLarge)
    }
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HTTPStubURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}

private final class HTTPStubURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler:
    (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
