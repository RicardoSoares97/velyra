import XCTest

@testable import VelyraTV

final class TMDBAPIClientCacheTests: XCTestCase {
  override func tearDown() {
    TMDBStubURLProtocol.handler = nil
    super.tearDown()
  }

  func testConcurrentIdenticalRequestsAreDeduplicatedAndCached() async throws {
    let counter = TMDBLockedCounter()
    TMDBStubURLProtocol.handler = { request in
      counter.increment()
      Thread.sleep(forTimeInterval: 0.08)
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      let payload = """
        {
          "page": 1,
          "total_pages": 1,
          "total_results": 1,
          "results": [
            {
              "id": 42,
              "media_type": "movie",
              "title": "Velyra",
              "release_date": "2026-01-01",
              "genre_ids": []
            }
          ]
        }
        """
      return (response, Data(payload.utf8))
    }

    let client = TMDBAPIClient(
      session: makeSession(),
      readAccessToken: "test-token"
    )

    async let first = client.search(query: "Velyra", language: "pt-PT")
    async let second = client.search(query: "Velyra", language: "pt-PT")
    let concurrent = try await (first, second)
    let cached = try await client.search(query: "Velyra", language: "pt-PT")

    XCTAssertEqual(concurrent.0.first?.id, 42)
    XCTAssertEqual(concurrent.1.first?.id, 42)
    XCTAssertEqual(cached.first?.id, 42)
    XCTAssertEqual(counter.value, 1)
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TMDBStubURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}

private final class TMDBStubURLProtocol: URLProtocol, @unchecked Sendable {
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

private final class TMDBLockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  func increment() {
    lock.lock()
    storage += 1
    lock.unlock()
  }

  var value: Int {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}
