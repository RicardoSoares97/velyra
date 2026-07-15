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
  @Published private(set) var profile: TraktUser?
  @Published private(set) var lastSuccessfulConnection: Date?

  var isConnected: Bool {
    if case .connected = state { return true }
    return false
  }

  var isConfigured: Bool { TraktConfiguration.isConfigured }

  private let api: TraktAPIClient
  private let keychain: KeychainStore
  private let tokenAccount = "trakt.oauth.token"
  private var token: TraktToken?
  private var authorizationTask: Task<Void, Never>?
  private var refreshTask: Task<TraktToken, Error>?

  init(
    api: TraktAPIClient = TraktAPIClient(),
    keychain: KeychainStore = KeychainStore()
  ) {
    self.api = api
    self.keychain = keychain
  }

  deinit {
    authorizationTask?.cancel()
    refreshTask?.cancel()
  }

  func restore() async {
    guard TraktConfiguration.isConfigured else {
      state = .failed(String(localized: "trakt.error.notConfigured"))
      return
    }

    guard let data = try? await keychain.read(account: tokenAccount),
      let stored = try? JSONDecoder().decode(TraktToken.self, from: data)
    else {
      state = .disconnected
      return
    }

    token = stored
    do {
      _ = try await validToken()
      try await loadProfile()
      state = .connected
      lastSuccessfulConnection = Date()
    } catch {
      await clearLocalSession()
      state = .disconnected
    }
  }

  func connect() {
    guard TraktConfiguration.isConfigured else {
      state = .failed(String(localized: "trakt.error.notConfigured"))
      return
    }

    authorizationTask?.cancel()
    authorizationTask = Task { [weak self] in
      guard let self else { return }
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

  func cancelConnection() {
    authorizationTask?.cancel()
    authorizationTask = nil
    if !isConnected { state = .disconnected }
  }

  func disconnect(revokeRemoteToken: Bool = true) async {
    authorizationTask?.cancel()
    refreshTask?.cancel()

    if revokeRemoteToken, let token {
      try? await api.revoke(token)
    }
    await clearLocalSession()
    state = .disconnected
  }

  func validToken() async throws -> TraktToken {
    guard let token else { throw TraktAPIClient.APIError.unauthorized }
    guard token.needsRefresh() else { return token }

    if let refreshTask { return try await refreshTask.value }

    let task = Task { [api] in
      try await api.refresh(token)
    }
    refreshTask = task
    defer { refreshTask = nil }

    do {
      let refreshed = try await task.value
      try await persist(refreshed)
      self.token = refreshed
      return refreshed
    } catch {
      await clearLocalSession()
      state = .disconnected
      throw error
    }
  }

  func invalidateAuthorization() async {
    authorizationTask?.cancel()
    refreshTask?.cancel()
    await clearLocalSession()
    state = .disconnected
  }

  func refreshProfile() async {
    guard isConnected else { return }
    do {
      try await loadProfile()
    } catch TraktAPIClient.APIError.unauthorized {
      await invalidateAuthorization()
    } catch {
      // A transient profile refresh failure must not disconnect a valid account.
    }
  }

  private func pollForAuthorization(_ code: TraktDeviceCode) async throws {
    let deadline = Date().addingTimeInterval(TimeInterval(code.expiresIn))
    var interval = max(code.interval, 1)

    while Date() < deadline {
      try Task.checkCancellation()
      try await Task.sleep(for: .seconds(interval))
      guard Date() < deadline else { break }
      do {
        let token = try await api.exchangeDeviceCode(code.deviceCode)
        try await persist(token)
        self.token = token
        try await loadProfile()
        state = .connected
        lastSuccessfulConnection = Date()
        return
      } catch TraktAPIClient.APIError.pendingAuthorization {
        continue
      } catch TraktAPIClient.APIError.rateLimited(let retryAfter) {
        interval = max(interval + 2, Int(retryAfter ?? 0))
        continue
      } catch TraktAPIClient.APIError.authorizationDenied {
        throw TraktAPIClient.APIError.authorizationDenied
      } catch TraktAPIClient.APIError.authorizationExpired {
        throw TraktAPIClient.APIError.authorizationExpired
      }
    }
    throw TraktAPIClient.APIError.authorizationExpired
  }

  private func loadProfile() async throws {
    guard let token else { throw TraktAPIClient.APIError.unauthorized }
    let settings = try await api.userSettings(token: token)
    profile = settings.user
  }

  private func persist(_ token: TraktToken) async throws {
    let data = try JSONEncoder().encode(token)
    try await keychain.save(data, account: tokenAccount)
  }

  private func clearLocalSession() async {
    token = nil
    profile = nil
    lastSuccessfulConnection = nil
    try? await keychain.delete(account: tokenAccount)
  }
}
