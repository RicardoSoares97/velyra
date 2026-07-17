import Foundation

struct OnboardingMediaItem: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let kind: MediaKind
  let title: String
  let backdropURL: URL
}

struct OnboardingMediaSnapshot: Codable, Equatable, Sendable {
  let language: String
  let region: String
  let selectedDay: String
  let loadedAt: Date
  let items: [OnboardingMediaItem]
}

protocol OnboardingMediaProviding: Sendable {
  func media(language: String, region: String) async -> [OnboardingMediaItem]
}

protocol TrendingMediaProviding: Sendable {
  func trending(kind: MediaKind, timeWindow: String, language: String) async throws
    -> [TMDBMediaResult]
}

extension TMDBAPIClient: TrendingMediaProviding {}
