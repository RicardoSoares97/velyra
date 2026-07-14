import Foundation

actor TraktSyncCoordinator {
    private let api: TraktAPIClient
    private let session: TraktSession

    init(api: TraktAPIClient = TraktAPIClient(), session: TraktSession) {
        self.api = api
        self.session = session
    }

    func fetchPlaybackProgress() async throws -> [TraktPlaybackItem] {
        let token = try await session.validToken()
        return try await api.playback(token: token)
    }

    func scrobble(
        action: TraktScrobbleAction,
        movie: TraktMovie? = nil,
        show: TraktShow? = nil,
        episode: TraktEpisode? = nil,
        progress: Double
    ) async throws {
        let token = try await session.validToken()
        let payload = TraktScrobblePayload(
            movie: movie,
            show: show,
            episode: episode,
            progress: min(max(progress, 0), 100),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
            appDate: "2026-07-14"
        )
        try await api.scrobble(action: action, payload: payload, token: token)
    }
}
