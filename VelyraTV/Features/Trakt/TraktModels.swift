import Foundation

struct TraktDeviceCode: Codable, Equatable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURL = "verification_url"
        case expiresIn = "expires_in"
        case interval
    }
}

struct TraktToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let scope: String
    let expiresIn: Int
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case createdAt = "created_at"
    }

    var expiryDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt + expiresIn))
    }
}

struct TraktIDs: Codable, Equatable, Hashable, Sendable {
    let trakt: Int?
    let slug: String?
    let imdb: String?
    let tmdb: Int?
}

struct TraktMovie: Codable, Equatable, Hashable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktIDs
}

struct TraktShow: Codable, Equatable, Hashable, Sendable {
    let title: String
    let year: Int?
    let ids: TraktIDs
}

struct TraktEpisode: Codable, Equatable, Hashable, Sendable {
    let season: Int
    let number: Int
    let title: String?
    let ids: TraktIDs
}

struct TraktPlaybackItem: Codable, Equatable, Identifiable, Sendable {
    let progress: Double
    let pausedAt: Date
    let id: Int
    let type: String
    let movie: TraktMovie?
    let episode: TraktEpisode?
    let show: TraktShow?

    enum CodingKeys: String, CodingKey {
        case progress
        case pausedAt = "paused_at"
        case id, type, movie, episode, show
    }
}

enum TraktScrobbleAction: String, Sendable {
    case start
    case pause
    case stop
}

struct TraktScrobblePayload: Encodable, Sendable {
    let movie: TraktMovie?
    let show: TraktShow?
    let episode: TraktEpisode?
    let progress: Double
    let appVersion: String
    let appDate: String

    enum CodingKeys: String, CodingKey {
        case movie, show, episode, progress
        case appVersion = "app_version"
        case appDate = "app_date"
    }
}
