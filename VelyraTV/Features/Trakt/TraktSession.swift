import Foundation

@MainActor
final class TraktSession: ObservableObject {
    enum State: Equatable {
        case disconnected
        case requestingCode
        case awaitingAuthorization(TraktDeviceCode)
        case connected
        case failed(String)
    }

    @Published private(set) var state: State = .disconnected

    private let api = TraktAPIClient()
    private let keychain = KeychainStore()
    private let tokenAccount = "trakt.oauth.token"
    private var token: TraktToken?
    private var authorizationTask: Task<Void, Never>?

    deinit {
        authorizationTask?.cancel()
    }

    func restore() async {
        guard let data = try? await keychain.read(account: tokenAccount),
              let stored = try? JSONDecoder().decode(TraktToken.self, from: data) else {
            state = .disconnected
            return
        }

        if stored.expiryDate.timeIntervalSinceNow < 86_400 {
            do {
                let refreshed = try await api.refresh(stored)
                try await persist(refreshed)
                token = refreshed
            } catch {
                state = .disconnected
                return
            }
        } else {
            token = stored
        }
        state = .connected
    }

    func connect() {
        authorizationTask?.cancel()
        authorizationTask = Task {
            do {
                state = .requestingCode
                let code = try await api.requestDeviceCode()
                state = .awaitingAuthorization(code)
                try await pollForAuthorization(code)
            } catch is CancellationError {
                state = .disconnected
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func disconnect() async {
        authorizationTask?.cancel()
        token = nil
        try? await keychain.delete(account: tokenAccount)
        state = .disconnected
    }

    func validToken() async throws -> TraktToken {
        guard let token else { throw TraktAPIClient.APIError.unauthorized }
        if token.expiryDate.timeIntervalSinceNow < 86_400 {
            let refreshed = try await api.refresh(token)
            try await persist(refreshed)
            self.token = refreshed
            return refreshed
        }
        return token
    }

    private func pollForAuthorization(_ code: TraktDeviceCode) async throws {
        let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
        while Date() < deadline {
            try Task.checkCancellation()
            do {
                let token = try await api.exchangeDeviceCode(code.deviceCode)
                try await persist(token)
                self.token = token
                state = .connected
                return
            } catch TraktAPIClient.APIError.server(let status) where status == 400 || status == 404 {
                try await Task.sleep(for: .seconds(code.interval))
            } catch TraktAPIClient.APIError.rateLimited {
                try await Task.sleep(for: .seconds(code.interval + 2))
            }
        }
        state = .failed(String(localized: "trakt.error.expired"))
    }

    private func persist(_ token: TraktToken) async throws {
        let data = try JSONEncoder().encode(token)
        try await keychain.save(data, account: tokenAccount)
    }
}
