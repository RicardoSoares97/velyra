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

  @discardableResult
  func scrobble(
    action: TraktScrobbleAction,
    movie: TraktMovie? = nil,
    show: TraktShow? = nil,
    episode: TraktEpisode? = nil,
    progress: Double
  ) async throws -> TraktScrobbleResponse {
    let token = try await session.validToken()
    let reference: TraktMediaReference
    if let movie {
      reference = TraktMediaReference(movie: movie)
    } else if let show, let episode {
      reference = TraktMediaReference(show: show, episode: episode)
    } else if let show {
      reference = TraktMediaReference(show: show)
    } else {
      throw TraktAPIClient.APIError.invalidRequest
    }

    let payload = TraktScrobblePayload.make(
      context: TraktPlaybackContext(reference: reference),
      progress: progress
    )
    return try await api.scrobble(action: action, payload: payload, token: token)
  }
}
