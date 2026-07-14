import Foundation

struct TMDBPagedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let page: Int
    let results: [Item]
}

struct TMDBMediaResult: Decodable, Sendable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let genreIDs: [Int]
    let voteAverage: Double?
    let mediaType: String?
    let popularity: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case genreIDs = "genre_ids"
        case voteAverage = "vote_average"
        case mediaType = "media_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        genreIDs = try container.decodeIfPresent([Int].self, forKey: .genreIDs) ?? []
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
    }

    func mediaItem(kind fallbackKind: MediaKind, rank: Int? = nil, providerName: String? = nil) -> MediaItem {
        let resolvedKind: MediaKind = mediaType == "movie" ? .movie : mediaType == "tv" ? .series : fallbackKind
        let date = releaseDate ?? firstAirDate
        let year = date.flatMap { Int($0.prefix(4)) }
        let resolvedTitle = title ?? name ?? String(localized: "media.unknownTitle")

        return MediaItem(
            id: "tmdb-\(resolvedKind.rawValue)-\(id)",
            tmdbID: id,
            imdbID: nil,
            kind: resolvedKind,
            title: resolvedTitle,
            subtitle: nil,
            overview: overview,
            posterURL: TMDBConfiguration.imageURL(path: posterPath, width: "w500"),
            backdropURL: TMDBConfiguration.imageURL(path: backdropPath, width: "w1280"),
            releaseYear: year,
            genreIDs: genreIDs,
            rating: voteAverage,
            progress: nil,
            rank: rank,
            providerName: providerName
        )
    }
}

struct TMDBGenreResponse: Decodable, Sendable {
    let genres: [TMDBGenre]
}

struct TMDBGenre: Decodable, Sendable {
    let id: Int
    let name: String
}

struct TMDBProviderResponse: Decodable, Sendable {
    let results: [TMDBProvider]
}

struct TMDBProvider: Decodable, Sendable {
    let providerID: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }

    var streamingProvider: StreamingProvider {
        StreamingProvider(
            id: providerID,
            name: providerName,
            logoURL: TMDBConfiguration.imageURL(path: logoPath, width: "w185")
        )
    }
}
