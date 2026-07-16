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
  let voteCount: Int?
  let mediaType: String?
  let popularity: Double?
  let originalLanguage: String?
  let runtime: Int?
  let episodeRunTime: [Int]?
  let numberOfSeasons: Int?
  let numberOfEpisodes: Int?
  let tagline: String?
  let status: String?
  let knownFor: [TMDBMediaResult]

  enum CodingKeys: String, CodingKey {
    case id, title, name, overview, popularity
    case posterPath = "poster_path"
    case backdropPath = "backdrop_path"
    case releaseDate = "release_date"
    case firstAirDate = "first_air_date"
    case genreIDs = "genre_ids"
    case voteAverage = "vote_average"
    case voteCount = "vote_count"
    case mediaType = "media_type"
    case originalLanguage = "original_language"
    case runtime
    case episodeRunTime = "episode_run_time"
    case numberOfSeasons = "number_of_seasons"
    case numberOfEpisodes = "number_of_episodes"
    case tagline, status
    case knownFor = "known_for"
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
    voteCount = try container.decodeIfPresent(Int.self, forKey: .voteCount)
    mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)
    originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
    runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
    episodeRunTime = try container.decodeIfPresent([Int].self, forKey: .episodeRunTime)
    numberOfSeasons = try container.decodeIfPresent(Int.self, forKey: .numberOfSeasons)
    numberOfEpisodes = try container.decodeIfPresent(Int.self, forKey: .numberOfEpisodes)
    tagline = try container.decodeIfPresent(String.self, forKey: .tagline)
    status = try container.decodeIfPresent(String.self, forKey: .status)
    knownFor = try container.decodeIfPresent([TMDBMediaResult].self, forKey: .knownFor) ?? []
  }

  func mediaItem(kind fallbackKind: MediaKind, rank: Int? = nil, providerName: String? = nil)
    -> MediaItem
  {
    let resolvedKind: MediaKind =
      mediaType == "movie" ? .movie : mediaType == "tv" ? .series : fallbackKind
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

struct TMDBExternalIDs: Decodable, Sendable {
  let imdbID: String?

  enum CodingKeys: String, CodingKey {
    case imdbID = "imdb_id"
  }
}

struct TMDBCreditsResponse: Decodable, Sendable {
  let cast: [TMDBCastMember]
  let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Decodable, Identifiable, Sendable {
  let id: Int
  let name: String
  let character: String?
  let profilePath: String?
  let order: Int?

  enum CodingKeys: String, CodingKey {
    case id, name, character, order
    case profilePath = "profile_path"
  }

  var profileURL: URL? {
    TMDBConfiguration.imageURL(path: profilePath, width: "w300")
  }
}

struct TMDBCrewMember: Decodable, Identifiable, Sendable {
  let id: Int
  let name: String
  let job: String?
  let department: String?

  enum CodingKeys: String, CodingKey {
    case id, name, job, department
  }
}

struct TMDBVideoResponse: Decodable, Sendable {
  let results: [TMDBVideo]
}

struct TMDBVideo: Decodable, Identifiable, Sendable {
  let id: String
  let key: String
  let name: String
  let site: String
  let type: String
  let official: Bool?
  let publishedAt: String?

  enum CodingKeys: String, CodingKey {
    case id, key, name, site, type, official
    case publishedAt = "published_at"
  }

  var supportedOfficialTrailerURL: URL? {
    guard official == true,
      type.caseInsensitiveCompare("Trailer") == .orderedSame,
      site.caseInsensitiveCompare("YouTube") == .orderedSame
    else { return nil }

    let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedKey.isEmpty else { return nil }

    var components = URLComponents()
    components.scheme = "https"
    components.host = "www.youtube.com"
    components.path = "/watch"
    components.queryItems = [URLQueryItem(name: "v", value: trimmedKey)]
    return components.url
  }
}

struct TMDBWatchProviderResponse: Decodable, Sendable {
  let id: Int
  let results: [String: TMDBRegionWatchProviders]
}

struct TMDBRegionWatchProviders: Decodable, Sendable {
  let link: URL?
  let flatrate: [TMDBProvider]?
  let rent: [TMDBProvider]?
  let buy: [TMDBProvider]?
  let free: [TMDBProvider]?
  let ads: [TMDBProvider]?

  var streaming: [TMDBProvider] {
    let combined = (flatrate ?? []) + (free ?? []) + (ads ?? [])
    var seen: Set<Int> = []
    return combined.filter { seen.insert($0.providerID).inserted }
  }
}

struct TMDBSeasonDetails: Decodable, Sendable {
  let id: Int
  let name: String
  let overview: String?
  let seasonNumber: Int
  let posterPath: String?
  let episodes: [TMDBEpisode]

  enum CodingKeys: String, CodingKey {
    case id, name, overview, episodes
    case seasonNumber = "season_number"
    case posterPath = "poster_path"
  }
}

struct TMDBEpisode: Decodable, Identifiable, Sendable {
  let id: Int
  let name: String
  let overview: String?
  let episodeNumber: Int
  let seasonNumber: Int
  let airDate: String?
  let runtime: Int?
  let stillPath: String?
  let voteAverage: Double?
  let voteCount: Int?

  enum CodingKeys: String, CodingKey {
    case id, name, overview, runtime
    case episodeNumber = "episode_number"
    case seasonNumber = "season_number"
    case airDate = "air_date"
    case stillPath = "still_path"
    case voteAverage = "vote_average"
    case voteCount = "vote_count"
  }

  var stillURL: URL? {
    TMDBConfiguration.imageURL(path: stillPath, width: "w780")
  }
}

struct TMDBContentRatingResponse: Decodable, Sendable {
  let results: [TMDBContentRating]
}

struct TMDBContentRating: Decodable, Sendable {
  let descriptor: [String]?
  let iso31661: String
  let rating: String

  enum CodingKeys: String, CodingKey {
    case descriptor, rating
    case iso31661 = "iso_3166_1"
  }
}

struct TMDBReleaseDateResponse: Decodable, Sendable {
  let results: [TMDBReleaseDateRegion]
}

struct TMDBReleaseDateRegion: Decodable, Sendable {
  let iso31661: String
  let releaseDates: [TMDBReleaseDate]

  enum CodingKeys: String, CodingKey {
    case iso31661 = "iso_3166_1"
    case releaseDates = "release_dates"
  }
}

struct TMDBReleaseDate: Decodable, Sendable {
  let certification: String?
  let type: Int?
}

struct TMDBDetailsBundle: Sendable {
  let details: TMDBMediaResult?
  let externalIDs: TMDBExternalIDs?
  let credits: TMDBCreditsResponse?
  let videos: [TMDBVideo]
  let recommendations: [TMDBMediaResult]
  let similar: [TMDBMediaResult]
  let providers: TMDBRegionWatchProviders?
  let certification: String?
}
