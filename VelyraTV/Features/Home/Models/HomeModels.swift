import Foundation

enum MediaKind: String, Codable, Hashable, Sendable {
    case movie
    case series
}

struct MediaItem: Identifiable, Hashable, Sendable {
    let id: String
    let tmdbID: Int?
    let imdbID: String?
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

    var accessibilitySummary: String {
        [subtitle, releaseYear.map(String.init), rating.map { String(format: "%.1f", $0) }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct GenreFilter: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let movieGenreID: Int?
    let seriesGenreID: Int?
}

struct StreamingProvider: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let logoURL: URL?
}

enum HomeSectionStyle: Hashable, Sendable {
    case landscape
    case poster
    case topTen
}

struct HomeSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let style: HomeSectionStyle
    let items: [MediaItem]
}

struct HomeFeed: Equatable, Sendable {
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
