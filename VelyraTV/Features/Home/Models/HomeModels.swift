import Foundation

enum MediaKind: String, Codable, Hashable, Sendable {
  case movie
  case series
}

struct MediaItem: Identifiable, Hashable, Codable, Sendable {
  let id: String
  let tmdbID: Int?
  let imdbID: String?
  let traktID: Int?
  let traktPlaybackID: Int?
  let kind: MediaKind
  let title: String
  let subtitle: String?
  let overview: String?
  let posterURL: URL?
  let backdropURL: URL?
  let releaseYear: Int?
  let genreIDs: [Int]
  let rating: Double?
  let progress: Double?
  let rank: Int?
  let providerName: String?
  let seasonNumber: Int?
  let episodeNumber: Int?

  init(
    id: String,
    tmdbID: Int?,
    imdbID: String?,
    traktID: Int? = nil,
    traktPlaybackID: Int? = nil,
    kind: MediaKind,
    title: String,
    subtitle: String?,
    overview: String?,
    posterURL: URL?,
    backdropURL: URL?,
    releaseYear: Int?,
    genreIDs: [Int],
    rating: Double?,
    progress: Double?,
    rank: Int?,
    providerName: String?,
    seasonNumber: Int? = nil,
    episodeNumber: Int? = nil
  ) {
    self.id = id
    self.tmdbID = tmdbID
    self.imdbID = imdbID
    self.traktID = traktID
    self.traktPlaybackID = traktPlaybackID
    self.kind = kind
    self.title = title
    self.subtitle = subtitle
    self.overview = overview
    self.posterURL = posterURL
    self.backdropURL = backdropURL
    self.releaseYear = releaseYear
    self.genreIDs = genreIDs
    self.rating = rating
    self.progress = progress
    self.rank = rank
    self.providerName = providerName
    self.seasonNumber = seasonNumber
    self.episodeNumber = episodeNumber
  }

  var accessibilitySummary: String {
    [subtitle, releaseYear.map(String.init), rating.map { String(format: "%.1f", $0) }]
      .compactMap { $0 }
      .joined(separator: ", ")
  }
}

struct GenreFilter: Identifiable, Hashable, Codable, Sendable {
  let id: String
  let name: String
  let movieGenreID: Int?
  let seriesGenreID: Int?
}

struct StreamingProvider: Identifiable, Hashable, Codable, Sendable {
  let id: Int
  let name: String
  let logoURL: URL?
}

enum HomeSectionStyle: String, Hashable, Codable, Sendable {
  case landscape
  case poster
  case topTen
}

struct HomeSection: Identifiable, Hashable, Codable, Sendable {
  let id: String
  let title: String
  let subtitle: String?
  let style: HomeSectionStyle
  let items: [MediaItem]
}

struct HomeFeed: Equatable, Codable, Sendable {
  let hero: MediaItem
  let continueWatching: [MediaItem]
  let genres: [GenreFilter]
  let providers: [StreamingProvider]
  let sections: [HomeSection]
}

extension MediaItem {
  static let previewHero = MediaItem(
    id: "preview-hero",
    tmdbID: nil,
    imdbID: nil,
    kind: .series,
    title: "Aurora",
    subtitle: "Velyra Original · Drama · 2026",
    overview: "Uma viagem cinematográfica por mundos onde cada história encontra o seu lugar.",
    posterURL: nil,
    backdropURL: nil,
    releaseYear: 2026,
    genreIDs: [],
    rating: 8.7,
    progress: nil,
    rank: nil,
    providerName: nil
  )
}
