import Foundation

protocol HTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
  private let session: URLSession
  private let maximumResponseBytes: Int

  init(
    session: URLSession = .shared,
    maximumResponseBytes: Int = 20_000_000
  ) {
    self.session = session
    self.maximumResponseBytes = maximumResponseBytes
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw HTTPClientError.invalidResponse
    }

    guard 200..<300 ~= httpResponse.statusCode else {
      throw HTTPClientError.httpStatus(httpResponse.statusCode)
    }
    if httpResponse.expectedContentLength > Int64(maximumResponseBytes)
      || data.count > maximumResponseBytes
    {
      throw HTTPClientError.responseTooLarge
    }

    return (data, httpResponse)
  }
}

enum HTTPClientError: LocalizedError, Equatable {
  case invalidResponse
  case httpStatus(Int)
  case responseTooLarge

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      String(localized: "network.error.invalidResponse")
    case .httpStatus:
      String(localized: "network.error.server")
    case .responseTooLarge:
      String(localized: "network.error.responseTooLarge")
    }
  }
}
