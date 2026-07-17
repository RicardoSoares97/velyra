import XCTest

@testable import VelyraTV

final class ExternalSubtitleServiceTests: XCTestCase {
  override func tearDown() {
    StubURLProtocol.handler = nil
    super.tearDown()
  }

  func testRejectsNonSuccessfulHTTPResponse() async throws {
    StubURLProtocol.handler = { request in
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 503,
        httpVersion: nil,
        headerFields: ["Content-Type": "text/plain"]
      )!
      return (response, Data("temporarily unavailable".utf8))
    }

    let service = ExternalSubtitleService(session: makeSession())
    let track = ExternalSubtitleTrack(
      url: URL(string: "https://subtitles.test/movie.srt")!,
      languageCode: "pt-PT",
      displayName: "Português"
    )

    do {
      _ = try await service.cues(for: track)
      XCTFail("Expected invalid response error")
    } catch ExternalSubtitleService.SubtitleError.invalidResponse {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testLoadsAndCachesValidSubtitleResponse() async throws {
    let counter = LockedCounter()
    StubURLProtocol.handler = { request in
      counter.increment()
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/x-subrip"]
      )!
      let body = """
        1
        00:00:01,000 --> 00:00:03,000
        Olá Velyra
        """
      return (response, Data(body.utf8))
    }

    let service = ExternalSubtitleService(session: makeSession())
    let track = ExternalSubtitleTrack(
      url: URL(string: "https://subtitles.test/movie.srt")!,
      languageCode: "pt-PT",
      displayName: "Português"
    )

    let first = try await service.cues(for: track)
    let second = try await service.cues(for: track)

    XCTAssertEqual(first, second)
    XCTAssertEqual(first.first?.text, "Olá Velyra")
    XCTAssertEqual(counter.value, 1)
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: configuration)
  }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

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

private final class LockedCounter: @unchecked Sendable {
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
