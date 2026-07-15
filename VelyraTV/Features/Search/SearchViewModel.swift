import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case searching
    case results
    case empty
    case failed(String)
  }

  enum KindFilter: String, CaseIterable, Identifiable {
    case all
    case movies
    case series
    var id: String { rawValue }
    var titleKey: String {
      switch self {
      case .all: "search.filter.all"
      case .movies: "search.filter.movies"
      case .series: "search.filter.series"
      }
    }
    var mediaKind: MediaKind? {
      switch self {
      case .all: nil
      case .movies: .movie
      case .series: .series
      }
    }
  }

  enum Sort: String, CaseIterable, Identifiable {
    case relevance
    case rating
    case newest
    var id: String { rawValue }
    var titleKey: String {
      switch self {
      case .relevance: "search.sort.relevance"
      case .rating: "search.sort.rating"
      case .newest: "search.sort.newest"
      }
    }
  }

  enum YearFilter: String, CaseIterable, Identifiable {
    case any
    case currentDecade
    case previousDecade
    case older

    var id: String { rawValue }
    var titleKey: String {
      switch self {
      case .any: "search.year.any"
      case .currentDecade: "search.year.currentDecade"
      case .previousDecade: "search.year.previousDecade"
      case .older: "search.year.older"
      }
    }

    func includes(_ year: Int?, currentYear: Int = Calendar.current.component(.year, from: Date()))
      -> Bool
    {
      guard self != .any else { return true }
      guard let year else { return false }
      let currentDecadeStart = (currentYear / 10) * 10
      switch self {
      case .any: return true
      case .currentDecade: return year >= currentDecadeStart
      case .previousDecade: return year >= currentDecadeStart - 10 && year < currentDecadeStart
      case .older: return year < currentDecadeStart - 10
      }
    }
  }

  enum RatingFilter: String, CaseIterable, Identifiable {
    case any
    case sevenPlus
    case eightPlus

    var id: String { rawValue }
    var titleKey: String {
      switch self {
      case .any: "search.rating.any"
      case .sevenPlus: "search.rating.sevenPlus"
      case .eightPlus: "search.rating.eightPlus"
      }
    }
    var minimumValue: Double? {
      switch self {
      case .any: nil
      case .sevenPlus: 7
      case .eightPlus: 8
      }
    }
  }

  @Published private(set) var state: State = .idle
  @Published private(set) var results: [MediaItem] = []
  @Published private(set) var recentSearches: [String] = []
  @Published var kindFilter: KindFilter = .all
  @Published var sort: Sort = .relevance
  @Published var yearFilter: YearFilter = .any
  @Published var ratingFilter: RatingFilter = .any

  private let tmdb: TMDBAPIClient
  private let addonRepository: any AddonContentProviding
  private let history: SearchHistoryStore
  private var rawResults: [MediaItem] = []
  private var currentQuery = ""
  private var currentPage = 1
  private var currentLanguage = "en"
  private var currentAddonURLs: [String] = []
  private var canLoadMore = true

  init(
    tmdb: TMDBAPIClient = .shared,
    addonRepository: any AddonContentProviding = AddonContentRepository.shared,
    history: SearchHistoryStore = SearchHistoryStore()
  ) {
    self.tmdb = tmdb
    self.addonRepository = addonRepository
    self.history = history
  }

  func loadHistory() async { recentSearches = await history.values() }
  func clearHistory() async {
    await history.clear()
    recentSearches = []
  }

  func search(
    query: String,
    language: String,
    addonManifestURLs: [String],
    saveToHistory: Bool
  ) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else {
      rawResults = []
      results = []
      state = .idle
      return
    }

    currentQuery = trimmed
    currentLanguage = language
    currentAddonURLs = addonManifestURLs
    currentPage = 1
    canLoadMore = true
    state = .searching

    do {
      async let tmdbTask = tmdb.search(query: trimmed, language: language, page: 1)
      async let addonTask = addonRepository.search(
        query: trimmed,
        kind: kindFilter.mediaKind,
        urlStrings: addonManifestURLs
      )
      let tmdbResults = try await tmdbTask
      let addonResults = await addonTask
      rawResults = deduplicate(
        tmdbResults.map { $0.mediaItem(kind: $0.mediaType == "movie" ? .movie : .series) }
          + addonResults.map(MediaItem.init(addon:))
      )
      canLoadMore = !tmdbResults.isEmpty
      applyFilters()
    } catch {
      let addonResults = await addonRepository.search(
        query: trimmed,
        kind: kindFilter.mediaKind,
        urlStrings: addonManifestURLs
      )
      rawResults = deduplicate(addonResults.map(MediaItem.init(addon:)))
      applyFilters(fallbackError: error.localizedDescription)
    }

    if saveToHistory {
      await history.add(trimmed)
      recentSearches = await history.values()
    }
  }

  func loadNextPageIfNeeded(currentItem: MediaItem) async {
    guard canLoadMore, state == .results,
      results.suffix(5).contains(where: { $0.id == currentItem.id })
    else { return }
    currentPage += 1
    do {
      let values = try await tmdb.search(
        query: currentQuery, language: currentLanguage, page: currentPage)
      canLoadMore = !values.isEmpty
      rawResults = deduplicate(
        rawResults + values.map { $0.mediaItem(kind: $0.mediaType == "movie" ? .movie : .series) }
      )
      applyFilters()
    } catch {
      currentPage -= 1
      canLoadMore = false
    }
  }

  func filtersChanged() { applyFilters() }

  private func applyFilters(fallbackError: String? = nil) {
    var values = rawResults
    if let kind = kindFilter.mediaKind { values = values.filter { $0.kind == kind } }
    values = values.filter { yearFilter.includes($0.releaseYear) }
    if let minimumRating = ratingFilter.minimumValue {
      values = values.filter { ($0.rating ?? -1) >= minimumRating }
    }
    switch sort {
    case .relevance: break
    case .rating: values.sort { ($0.rating ?? -1) > ($1.rating ?? -1) }
    case .newest: values.sort { ($0.releaseYear ?? 0) > ($1.releaseYear ?? 0) }
    }
    results = values
    if values.isEmpty {
      state = fallbackError.map(State.failed) ?? .empty
    } else {
      state = .results
    }
  }

  private func deduplicate(_ values: [MediaItem]) -> [MediaItem] {
    var seen: Set<String> = []
    return values.filter { item in
      let key =
        item.imdbID ?? item.tmdbID.map(String.init)
        ?? "\(item.kind.rawValue):\(item.title.lowercased())"
      return seen.insert(key).inserted
    }
  }
}

extension MediaItem {
  init(addon: AddonMetaPreview) {
    let kind: MediaKind = addon.type == "movie" ? .movie : .series
    self.init(
      id: "addon-\(addon.type)-\(addon.id)",
      tmdbID: addon.id.hasPrefix("tmdb:") ? Int(addon.id.dropFirst(5)) : nil,
      imdbID: addon.id.hasPrefix("tt") ? addon.id : nil,
      kind: kind,
      title: addon.name,
      subtitle: addon.releaseInfo,
      overview: addon.description,
      posterURL: addon.poster,
      backdropURL: addon.background,
      releaseYear: addon.releaseInfo.flatMap { Int($0.prefix(4)) },
      genreIDs: [],
      rating: addon.imdbRating.flatMap(Double.init),
      progress: nil,
      rank: nil,
      providerName: nil
    )
  }
}
