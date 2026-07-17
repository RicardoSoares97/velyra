import Foundation

// MARK: - OAuth

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

  func needsRefresh(now: Date = Date(), tolerance: TimeInterval = 86_400) -> Bool {
    expiryDate.timeIntervalSince(now) <= tolerance
  }
}

// MARK: - Identity and profile

struct TraktIDs: Codable, Equatable, Hashable, Sendable {
  let trakt: Int?
  let slug: String?
  let imdb: String?
  let tmdb: Int?

  init(trakt: Int? = nil, slug: String? = nil, imdb: String? = nil, tmdb: Int? = nil) {
    self.trakt = trakt
    self.slug = slug
    self.imdb = imdb
    self.tmdb = tmdb
  }
}

struct TraktUser: Codable, Equatable, Sendable {
  let username: String
  let isPrivate: Bool?
  let name: String?
  let isVIP: Bool?
  let isVIPExecutiveProducer: Bool?
  let ids: TraktIDs?

  enum CodingKeys: String, CodingKey {
    case username
    case isPrivate = "private"
    case name
    case isVIP = "vip"
    case isVIPExecutiveProducer = "vip_ep"
    case ids
  }

  var displayName: String {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? username : trimmed
  }
}

struct TraktAccountSettings: Codable, Equatable, Sendable {
  let timezone: String?
  let time24Hour: Bool?
  let coverImage: URL?

  enum CodingKeys: String, CodingKey {
    case timezone
    case time24Hour = "time_24hr"
    case coverImage = "cover_image"
  }
}

struct TraktConnections: Codable, Equatable, Sendable {
  let facebook: Bool?
  let twitter: Bool?
  let google: Bool?
  let tumblr: Bool?
  let medium: Bool?
  let slack: Bool?
  let apple: Bool?
}

struct TraktSharingSettings: Codable, Equatable, Sendable {
  let watching: Bool?
  let watched: Bool?
  let rated: Bool?
}

struct TraktUserSettings: Codable, Equatable, Sendable {
  let user: TraktUser
  let account: TraktAccountSettings?
  let connections: TraktConnections?
  let sharingText: TraktSharingSettings?

  enum CodingKeys: String, CodingKey {
    case user, account, connections
    case sharingText = "sharing_text"
  }
}

// MARK: - Media

struct TraktMovie: Codable, Equatable, Hashable, Sendable {
  let title: String
  let year: Int?
  let ids: TraktIDs

  init(title: String, year: Int? = nil, ids: TraktIDs = TraktIDs()) {
    self.title = title
    self.year = year
    self.ids = ids
  }
}

struct TraktShow: Codable, Equatable, Hashable, Sendable {
  let title: String
  let year: Int?
  let ids: TraktIDs

  init(title: String, year: Int? = nil, ids: TraktIDs = TraktIDs()) {
    self.title = title
    self.year = year
    self.ids = ids
  }
}

struct TraktEpisode: Codable, Equatable, Hashable, Sendable {
  let season: Int
  let number: Int
  let title: String?
  let ids: TraktIDs

  init(season: Int, number: Int, title: String? = nil, ids: TraktIDs = TraktIDs()) {
    self.season = season
    self.number = number
    self.title = title
    self.ids = ids
  }
}

enum TraktMediaType: String, Codable, CaseIterable, Identifiable, Sendable {
  case movie
  case show
  case episode

  var id: String { rawValue }
}

struct TraktMediaReference: Codable, Equatable, Hashable, Sendable {
  let type: TraktMediaType
  let movie: TraktMovie?
  let show: TraktShow?
  let episode: TraktEpisode?

  init(movie: TraktMovie) {
    type = .movie
    self.movie = movie
    show = nil
    episode = nil
  }

  init(show: TraktShow) {
    type = .show
    movie = nil
    self.show = show
    episode = nil
  }

  init(show: TraktShow, episode: TraktEpisode) {
    type = .episode
    movie = nil
    self.show = show
    self.episode = episode
  }

  var stableID: String {
    switch type {
    case .movie:
      if let trakt = movie?.ids.trakt { return "movie:trakt:\(trakt)" }
      if let tmdb = movie?.ids.tmdb { return "movie:tmdb:\(tmdb)" }
      if let imdb = movie?.ids.imdb { return "movie:imdb:\(imdb)" }
      return "movie:\(movie?.title ?? "unknown"):\(movie?.year ?? 0)"
    case .show:
      if let trakt = show?.ids.trakt { return "show:trakt:\(trakt)" }
      if let tmdb = show?.ids.tmdb { return "show:tmdb:\(tmdb)" }
      if let imdb = show?.ids.imdb { return "show:imdb:\(imdb)" }
      return "show:\(show?.title ?? "unknown"):\(show?.year ?? 0)"
    case .episode:
      let parent = TraktMediaReference(show: show ?? TraktShow(title: "unknown")).stableID
      return "\(parent):s\(episode?.season ?? 0)e\(episode?.number ?? 0)"
    }
  }
}

// MARK: - Playback and watched state

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

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show, let episode { return TraktMediaReference(show: show, episode: episode) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

struct TraktWatchedMovie: Codable, Equatable, Sendable {
  let plays: Int
  let lastWatchedAt: Date?
  let lastUpdatedAt: Date?
  let resetAt: Date?
  let movie: TraktMovie

  enum CodingKeys: String, CodingKey {
    case plays
    case lastWatchedAt = "last_watched_at"
    case lastUpdatedAt = "last_updated_at"
    case resetAt = "reset_at"
    case movie
  }
}

struct TraktWatchedEpisode: Codable, Equatable, Sendable {
  let number: Int
  let plays: Int
  let lastWatchedAt: Date?
  let completed: Bool?
}

struct TraktWatchedSeason: Codable, Equatable, Sendable {
  let number: Int
  let episodes: [TraktWatchedEpisode]
}

struct TraktWatchedShow: Codable, Equatable, Sendable {
  let plays: Int
  let lastWatchedAt: Date?
  let lastUpdatedAt: Date?
  let resetAt: Date?
  let show: TraktShow
  let seasons: [TraktWatchedSeason]

  enum CodingKeys: String, CodingKey {
    case plays
    case lastWatchedAt = "last_watched_at"
    case lastUpdatedAt = "last_updated_at"
    case resetAt = "reset_at"
    case show, seasons
  }
}

// MARK: - Library collections

struct TraktWatchlistItem: Codable, Equatable, Identifiable, Sendable {
  let rank: Int?
  let listedAt: Date
  let type: String?
  let movie: TraktMovie?
  let show: TraktShow?

  enum CodingKeys: String, CodingKey {
    case rank
    case listedAt = "listed_at"
    case type, movie, show
  }

  var id: String {
    mediaReference?.stableID ?? "watchlist:\(listedAt.timeIntervalSince1970)"
  }

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

struct TraktCollectedEpisode: Codable, Equatable, Sendable {
  let number: Int
  let collectedAt: Date?
  let metadata: TraktMediaMetadata?

  enum CodingKeys: String, CodingKey {
    case number
    case collectedAt = "collected_at"
    case metadata
  }
}

struct TraktCollectedSeason: Codable, Equatable, Sendable {
  let number: Int
  let episodes: [TraktCollectedEpisode]
}

struct TraktCollectionItem: Codable, Equatable, Identifiable, Sendable {
  let collectedAt: Date
  let updatedAt: Date?
  let movie: TraktMovie?
  let show: TraktShow?
  let seasons: [TraktCollectedSeason]?

  enum CodingKeys: String, CodingKey {
    case collectedAt = "collected_at"
    case updatedAt = "updated_at"
    case movie, show, seasons
  }

  var id: String {
    mediaReference?.stableID ?? "collection:\(collectedAt.timeIntervalSince1970)"
  }

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

struct TraktHistoryItem: Codable, Equatable, Identifiable, Sendable {
  let id: Int
  let watchedAt: Date
  let action: String?
  let type: String?
  let movie: TraktMovie?
  let episode: TraktEpisode?
  let show: TraktShow?

  enum CodingKeys: String, CodingKey {
    case id
    case watchedAt = "watched_at"
    case action, type, movie, episode, show
  }

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show, let episode { return TraktMediaReference(show: show, episode: episode) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

struct TraktRatingItem: Codable, Equatable, Identifiable, Sendable {
  let ratedAt: Date
  let rating: Int
  let type: String?
  let movie: TraktMovie?
  let show: TraktShow?
  let episode: TraktEpisode?

  enum CodingKeys: String, CodingKey {
    case ratedAt = "rated_at"
    case rating, type, movie, show, episode
  }

  var id: String {
    mediaReference?.stableID ?? "rating:\(ratedAt.timeIntervalSince1970)"
  }

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show, let episode { return TraktMediaReference(show: show, episode: episode) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

struct TraktMediaMetadata: Codable, Equatable, Sendable {
  let mediaType: String?
  let mediaResolution: String?
  let audio: String?
  let audioChannels: String?
  let is3D: Bool?

  enum CodingKeys: String, CodingKey {
    case mediaType = "media_type"
    case mediaResolution = "media_resolution"
    case audio
    case audioChannels = "audio_channels"
    case is3D = "3d"
  }
}

// MARK: - Lists

struct TraktListIDs: Codable, Equatable, Hashable, Sendable {
  let trakt: Int
  let slug: String?
}

struct TraktPersonalList: Codable, Equatable, Identifiable, Sendable {
  let name: String
  let description: String?
  let privacy: String?
  let shareLink: URL?
  let type: String?
  let displayNumbers: Bool?
  let allowComments: Bool?
  let sortBy: String?
  let sortHow: String?
  let createdAt: Date?
  let updatedAt: Date?
  let itemCount: Int?
  let commentCount: Int?
  let likes: Int?
  let ids: TraktListIDs

  enum CodingKeys: String, CodingKey {
    case name, description, privacy, type, likes, ids
    case shareLink = "share_link"
    case displayNumbers = "display_numbers"
    case allowComments = "allow_comments"
    case sortBy = "sort_by"
    case sortHow = "sort_how"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case itemCount = "item_count"
    case commentCount = "comment_count"
  }

  var id: Int { ids.trakt }
}

struct TraktListItem: Codable, Equatable, Identifiable, Sendable {
  let rank: Int?
  let id: Int
  let listedAt: Date?
  let notes: String?
  let type: String?
  let movie: TraktMovie?
  let show: TraktShow?
  let episode: TraktEpisode?

  enum CodingKeys: String, CodingKey {
    case rank, id, notes, type, movie, show, episode
    case listedAt = "listed_at"
  }

  var mediaReference: TraktMediaReference? {
    if let movie { return TraktMediaReference(movie: movie) }
    if let show, let episode { return TraktMediaReference(show: show, episode: episode) }
    if let show { return TraktMediaReference(show: show) }
    return nil
  }
}

// MARK: - Last activity

struct TraktLastActivityItem: Codable, Equatable, Sendable {
  let watchedAt: Date?
  let collectedAt: Date?
  let ratedAt: Date?
  let watchlistedAt: Date?
  let commentedAt: Date?
  let pausedAt: Date?
  let hiddenAt: Date?

  enum CodingKeys: String, CodingKey {
    case watchedAt = "watched_at"
    case collectedAt = "collected_at"
    case ratedAt = "rated_at"
    case watchlistedAt = "watchlisted_at"
    case commentedAt = "commented_at"
    case pausedAt = "paused_at"
    case hiddenAt = "hidden_at"
  }
}

struct TraktLastActivities: Codable, Equatable, Sendable {
  let all: Date?
  let movies: TraktLastActivityItem?
  let episodes: TraktLastActivityItem?
  let shows: TraktLastActivityItem?
  let seasons: TraktLastActivityItem?
  let lists: TraktLastActivityItem?
}

// MARK: - Scrobble

enum TraktScrobbleAction: String, Codable, Sendable {
  case start
  case pause
  case stop
}

struct TraktScrobblePayload: Codable, Equatable, Sendable {
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

struct TraktScrobbleResponse: Decodable, Sendable {
  let id: Int?
  let action: String?
  let progress: Double?
  let movie: TraktMovie?
  let show: TraktShow?
  let episode: TraktEpisode?
}

// MARK: - Sync mutations

struct TraktSyncMovieReference: Codable, Equatable, Sendable {
  let title: String?
  let year: Int?
  let ids: TraktIDs
  let watchedAt: Date?
  let collectedAt: Date?
  let ratedAt: Date?
  let rating: Int?
  let metadata: TraktMediaMetadata?

  enum CodingKeys: String, CodingKey {
    case title, year, ids, rating, metadata
    case watchedAt = "watched_at"
    case collectedAt = "collected_at"
    case ratedAt = "rated_at"
  }

  init(
    movie: TraktMovie,
    watchedAt: Date? = nil,
    collectedAt: Date? = nil,
    ratedAt: Date? = nil,
    rating: Int? = nil,
    metadata: TraktMediaMetadata? = nil
  ) {
    title = movie.title
    year = movie.year
    ids = movie.ids
    self.watchedAt = watchedAt
    self.collectedAt = collectedAt
    self.ratedAt = ratedAt
    self.rating = rating
    self.metadata = metadata
  }
}

struct TraktSyncEpisodeReference: Codable, Equatable, Sendable {
  let ids: TraktIDs
  let season: Int?
  let number: Int?
  let watchedAt: Date?
  let collectedAt: Date?
  let ratedAt: Date?
  let rating: Int?
  let metadata: TraktMediaMetadata?

  enum CodingKeys: String, CodingKey {
    case ids, season, number, rating, metadata
    case watchedAt = "watched_at"
    case collectedAt = "collected_at"
    case ratedAt = "rated_at"
  }

  init(
    episode: TraktEpisode,
    watchedAt: Date? = nil,
    collectedAt: Date? = nil,
    ratedAt: Date? = nil,
    rating: Int? = nil,
    metadata: TraktMediaMetadata? = nil
  ) {
    ids = episode.ids
    season = episode.season
    number = episode.number
    self.watchedAt = watchedAt
    self.collectedAt = collectedAt
    self.ratedAt = ratedAt
    self.rating = rating
    self.metadata = metadata
  }
}

struct TraktSyncShowEpisode: Codable, Equatable, Sendable {
  let number: Int
  let watchedAt: Date?
  let collectedAt: Date?
  let metadata: TraktMediaMetadata?

  enum CodingKeys: String, CodingKey {
    case number, metadata
    case watchedAt = "watched_at"
    case collectedAt = "collected_at"
  }
}

struct TraktSyncShowSeason: Codable, Equatable, Sendable {
  let number: Int
  let episodes: [TraktSyncShowEpisode]?
}

struct TraktSyncShowReference: Codable, Equatable, Sendable {
  let title: String?
  let year: Int?
  let ids: TraktIDs
  let seasons: [TraktSyncShowSeason]?
  let watchedAt: Date?
  let collectedAt: Date?
  let ratedAt: Date?
  let rating: Int?

  enum CodingKeys: String, CodingKey {
    case title, year, ids, seasons, rating
    case watchedAt = "watched_at"
    case collectedAt = "collected_at"
    case ratedAt = "rated_at"
  }

  init(
    show: TraktShow,
    seasons: [TraktSyncShowSeason]? = nil,
    watchedAt: Date? = nil,
    collectedAt: Date? = nil,
    ratedAt: Date? = nil,
    rating: Int? = nil
  ) {
    title = show.title
    year = show.year
    ids = show.ids
    self.seasons = seasons
    self.watchedAt = watchedAt
    self.collectedAt = collectedAt
    self.ratedAt = ratedAt
    self.rating = rating
  }
}

struct TraktSyncRequest: Codable, Equatable, Sendable {
  var movies: [TraktSyncMovieReference]?
  var shows: [TraktSyncShowReference]?
  var episodes: [TraktSyncEpisodeReference]?
  var ids: [Int]?

  init(
    movies: [TraktSyncMovieReference]? = nil,
    shows: [TraktSyncShowReference]? = nil,
    episodes: [TraktSyncEpisodeReference]? = nil,
    ids: [Int]? = nil
  ) {
    self.movies = movies
    self.shows = shows
    self.episodes = episodes
    self.ids = ids
  }
}

struct TraktSyncCount: Codable, Equatable, Sendable {
  let movies: Int?
  let shows: Int?
  let seasons: Int?
  let episodes: Int?
}

struct TraktSyncNotFound: Codable, Equatable, Sendable {
  let movies: [TraktSyncMovieReference]?
  let shows: [TraktSyncShowReference]?
  let seasons: [TraktSyncShowSeason]?
  let episodes: [TraktSyncEpisodeReference]?
  let ids: [Int]?
}

struct TraktSyncResponse: Codable, Equatable, Sendable {
  let added: TraktSyncCount?
  let deleted: TraktSyncCount?
  let existing: TraktSyncCount?
  let notFound: TraktSyncNotFound?

  enum CodingKeys: String, CodingKey {
    case added, deleted, existing
    case notFound = "not_found"
  }
}

// MARK: - Pagination

struct TraktPagination: Equatable, Sendable {
  let page: Int
  let limit: Int
  let pageCount: Int
  let itemCount: Int

  static let single = TraktPagination(page: 1, limit: 0, pageCount: 1, itemCount: 0)
}

struct TraktPage<Value: Sendable>: Sendable {
  let values: Value
  let pagination: TraktPagination
}

struct EmptyResponse: Codable, Sendable {
  init() {}
}

struct TraktPlaybackContext: Equatable, Sendable {
  let reference: TraktMediaReference
  let playbackID: Int?

  init(reference: TraktMediaReference, playbackID: Int? = nil) {
    self.reference = reference
    self.playbackID = playbackID
  }

  var movie: TraktMovie? { reference.movie }
  var show: TraktShow? { reference.show }
  var episode: TraktEpisode? { reference.episode }
}

extension TraktScrobblePayload {
  static func make(context: TraktPlaybackContext, progress: Double) -> TraktScrobblePayload {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return TraktScrobblePayload(
      movie: context.movie,
      show: context.show,
      episode: context.episode,
      progress: min(max(progress, 0), 100),
      appVersion: version,
      appDate: formatter.string(from: Date())
    )
  }
}

struct TraktListRequest: Codable, Equatable, Sendable {
  let name: String
  let description: String?
  let privacy: String
  let displayNumbers: Bool
  let allowComments: Bool
  let sortBy: String
  let sortHow: String

  enum CodingKeys: String, CodingKey {
    case name, description, privacy
    case displayNumbers = "display_numbers"
    case allowComments = "allow_comments"
    case sortBy = "sort_by"
    case sortHow = "sort_how"
  }

  init(
    name: String,
    description: String? = nil,
    privacy: String = "private",
    displayNumbers: Bool = false,
    allowComments: Bool = false,
    sortBy: String = "rank",
    sortHow: String = "asc"
  ) {
    self.name = name
    self.description = description
    self.privacy = privacy
    self.displayNumbers = displayNumbers
    self.allowComments = allowComments
    self.sortBy = sortBy
    self.sortHow = sortHow
  }
}
