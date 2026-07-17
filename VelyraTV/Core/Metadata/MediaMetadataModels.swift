import Foundation

enum MediaMetadataSource: String, Codable, Hashable, Sendable {
  case tmdb
  case trakt
  case addon
}

struct MediaRating: Identifiable, Codable, Hashable, Sendable {
  let source: MediaMetadataSource
  let value: Double
  let scale: Double
  let voteCount: Int?

  var id: String { source.rawValue }

  var normalizedValue: Double {
    guard scale > 0 else { return value }
    return value / scale * 10
  }
}

struct MediaCredit: Identifiable, Codable, Hashable, Sendable {
  let id: String
  let name: String
  let role: String?
  let profileURL: URL?
  let source: MediaMetadataSource
}

enum TMDBMetadataPolicy {
  static func ratings(value: Double?, voteCount: Int? = nil) -> [MediaRating] {
    guard let value, value > 0 else { return [] }
    return [MediaRating(source: .tmdb, value: value, scale: 10, voteCount: voteCount)]
  }

  static func cast(_ values: [TMDBCastMember]) -> [MediaCredit] {
    Array(
      values
        .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
        .prefix(24)
        .map { member in
          MediaCredit(
            id: "tmdb-\(member.id)",
            name: member.name,
            role: member.character,
            profileURL: member.profileURL,
            source: .tmdb
          )
        }
    )
  }

  static func crew(_ values: [TMDBCrewMember]) -> [MediaCredit] {
    let preferredJobs = [
      "Director", "Series Director", "Creator", "Writer", "Screenplay", "Executive Producer",
    ]
    return Array(
      values
        .filter { preferredJobs.contains($0.job ?? "") }
        .prefix(20)
        .map { member in
          MediaCredit(
            id: "tmdb-\(member.id)-\(member.job ?? member.department ?? "crew")",
            name: member.name,
            role: member.job ?? member.department,
            profileURL: nil,
            source: .tmdb
          )
        }
    )
  }
}
