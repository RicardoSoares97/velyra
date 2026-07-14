import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw HTTPClientError.httpStatus(httpResponse.statusCode)
        }

        return (data, httpResponse)
    }
}

enum HTTPClientError: Error {
    case invalidResponse
    case httpStatus(Int)
}
