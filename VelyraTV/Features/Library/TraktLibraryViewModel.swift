import Foundation

struct TraktLibraryDisplayItem: Identifiable, Equatable, Sendable {
  let id: String
  let media: MediaItem
  let reference: TraktMediaReference
  let date: Date?
  let rating: Int?
  let historyID: Int?
  let playbackID: Int?
}

enum TraktLibraryMediaFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case movies
  case series

  var id: String { rawValue }
  var titleKey: String {
    switch self {
    case .all: "library.filter.all"
    case .movies: "library.filter.movies"
    case .series: "library.filter.series"
    }
  }
}

enum TraktLibrarySort: String, CaseIterable, Identifiable, Sendable {
  case recent
  case title
  case rating
  case progress

  var id: String { rawValue }
  var titleKey: String {
    switch self {
    case .recent: "library.sort.recent"
    case .title: "library.sort.title"
    case .rating: "library.sort.rating"
    case .progress: "library.sort.progress"
    }
  }
}

enum TraktLibraryCategory: Hashable, Identifiable, Sendable {
  case continueWatching
  case watchlist
  case history
  case collection
  case ratings
  case personalList(id: Int, name: String)

  var id: String {
    switch self {
    case .continueWatching: "continue"
    case .watchlist: "watchlist"
    case .history: "history"
    case .collection: "collection"
    case .ratings: "ratings"
    case .personalList(let id, _): "list:\(id)"
    }
  }

  var title: String {
    switch self {
    case .continueWatching: String(localized: "library.continueWatching")
    case .watchlist: String(localized: "library.watchlist")
    case .history: String(localized: "library.history")
    case .collection: String(localized: "library.collection")
    case .ratings: String(localized: "library.ratings")
    case .personalList(_, let name): name
    }
  }

  var systemImage: String {
    switch self {
    case .continueWatching: "play.circle.fill"
    case .watchlist: "bookmark.fill"
    case .history: "clock.arrow.circlepath"
    case .collection: "rectangle.stack.fill"
    case .ratings: "star.fill"
    case .personalList: "list.bullet.rectangle.fill"
    }
  }
}

struct TraktLibraryContent: Equatable, Sendable {
  let profile: TraktUser?
  let categories: [TraktLibraryCategory]
  let items: [String: [TraktLibraryDisplayItem]]
  let syncedAt: Date?
  let pendingMutationCount: Int
  let failedMutationCount: Int

  func items(for category: TraktLibraryCategory) -> [TraktLibraryDisplayItem] {
    items[category.id] ?? []
  }
}

@MainActor
final class TraktLibraryViewModel: ObservableObject {
  enum State: Equatable {
    case idle
    case loading
    case loaded(TraktLibraryContent, isStale: Bool, warning: String?)
    case failed(String)
  }

  @Published private(set) var state: State = .idle
  @Published var selectedCategory: TraktLibraryCategory = .continueWatching
  @Published var query = ""
  @Published var mediaFilter: TraktLibraryMediaFilter = .all
  @Published var sort: TraktLibrarySort = .recent
  @Published private(set) var isMutating = false
  @Published private(set) var mutationMessage: String?

  private let tmdb: TMDBAPIClient
  private var repository: TraktLibraryRepository?
  private var language = Locale.current.identifier

  init(tmdb: TMDBAPIClient = .shared) {
    self.tmdb = tmdb
  }

  func load(
    repository: TraktLibraryRepository,
    language: String,
    force: Bool = false
  ) async {
    self.repository = repository
    self.language = language

    let cached = await repository.cachedSnapshot()
    if !cached.isEmpty {
      let content = await makeContent(from: cached, repository: repository)
      apply(content: content, isStale: true, warning: nil)
    } else {
      state = .loading
    }

    do {
      let snapshot = try await repository.refresh(force: force)
      let content = await makeContent(from: snapshot, repository: repository)
      apply(content: content, isStale: false, warning: nil)
    } catch {
      if case .loaded(let content, _, _) = state {
        state = .loaded(content, isStale: true, warning: error.localizedDescription)
      } else {
        state = .failed(error.localizedDescription)
      }
    }
  }

  func visibleItems(in content: TraktLibraryContent) -> [TraktLibraryDisplayItem] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let filtered = content.items(for: selectedCategory).filter { item in
      let matchesKind: Bool
      switch mediaFilter {
      case .all: matchesKind = true
      case .movies: matchesKind = item.media.kind == .movie
      case .series: matchesKind = item.media.kind == .series
      }
      guard matchesKind else { return false }
      guard !normalizedQuery.isEmpty else { return true }
      return item.media.title.localizedCaseInsensitiveContains(normalizedQuery)
        || (item.media.subtitle?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
    }

    return filtered.sorted { lhs, rhs in
      switch sort {
      case .recent:
        return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
      case .title:
        return lhs.media.title.localizedStandardCompare(rhs.media.title) == .orderedAscending
      case .rating:
        return (lhs.rating ?? Int(lhs.media.rating ?? 0))
          > (rhs.rating ?? Int(rhs.media.rating ?? 0))
      case .progress:
        return (lhs.media.progress ?? 0) > (rhs.media.progress ?? 0)
      }
    }
  }

  func retryPendingChanges() async {
    guard let repository else { return }
    do {
      try await repository.retryPendingMutations()
      await refresh()
    } catch {
      mutationMessage = error.localizedDescription
    }
  }

  func refresh() async {
    guard let repository else { return }
    await load(repository: repository, language: language, force: true)
  }

  func setWatchlist(_ item: TraktLibraryDisplayItem, isListed: Bool) async {
    await mutate {
      try await self.repository?.setWatchlist(item.reference, isListed: isListed)
    }
  }

  func setCollection(_ item: TraktLibraryDisplayItem, isCollected: Bool) async {
    await mutate {
      try await self.repository?.setCollection(item.reference, isCollected: isCollected)
    }
  }

  func markWatched(_ item: TraktLibraryDisplayItem) async {
    await mutate {
      try await self.repository?.markWatched(item.reference)
    }
  }

  func setRating(_ item: TraktLibraryDisplayItem, rating: Int?) async {
    await mutate {
      try await self.repository?.setRating(item.reference, rating: rating)
    }
  }

  func removeHistory(_ item: TraktLibraryDisplayItem) async {
    guard let historyID = item.historyID else { return }
    await mutate {
      try await self.repository?.removeHistory(ids: [historyID])
    }
  }

  func removePlayback(_ item: TraktLibraryDisplayItem) async {
    guard let playbackID = item.playbackID else { return }
    await mutate {
      try await self.repository?.removePlayback(id: playbackID)
    }
  }

  func createList(name: String, description: String?) async {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    await mutate {
      try await self.repository?.createList(
        TraktListRequest(name: trimmed, description: description)
      )
    }
  }

  func updateList(id: Int, name: String, description: String?) async {
    guard id > 0 else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    await mutate {
      try await self.repository?.updateList(
        id: id,
        request: TraktListRequest(name: trimmed, description: description)
      )
    }
  }

  func deleteList(id: Int) async {
    guard id > 0 else { return }
    await mutate { try await self.repository?.deleteList(id: id) }
  }

  func setListMembership(
    listID: Int,
    item: TraktLibraryDisplayItem,
    isListed: Bool
  ) async {
    guard listID > 0 else { return }
    await mutate {
      try await self.repository?.setListMembership(
        listID: listID,
        reference: item.reference,
        isListed: isListed
      )
    }
  }

  private func mutate(
    operation: @escaping @Sendable () async throws -> TraktMutationOutcome?
  ) async {
    guard let repository else { return }
    isMutating = true
    mutationMessage = nil
    defer { isMutating = false }

    do {
      let outcome = try await operation()
      if outcome == .queued {
        mutationMessage = String(localized: "library.changeQueued")
      }
      let snapshot: TraktLibrarySnapshot
      if outcome == .synced, let refreshed = try? await repository.refresh(force: true) {
        snapshot = refreshed
      } else {
        snapshot = await repository.cachedSnapshot()
      }
      let content = await makeContent(from: snapshot, repository: repository)
      apply(content: content, isStale: outcome == .queued, warning: mutationMessage)
    } catch {
      mutationMessage = error.localizedDescription
    }
  }

  private func apply(content: TraktLibraryContent, isStale: Bool, warning: String?) {
    if !content.categories.contains(selectedCategory) {
      selectedCategory = content.categories.first ?? .continueWatching
    }
    state = .loaded(content, isStale: isStale, warning: warning)
  }

  private func makeContent(
    from snapshot: TraktLibrarySnapshot,
    repository: TraktLibraryRepository
  ) async -> TraktLibraryContent {
    let continueItems = await enrich(
      snapshot.playback.compactMap { item -> RawLibraryItem? in
        guard let reference = item.mediaReference else { return nil }
        return RawLibraryItem(
          reference: reference,
          date: item.pausedAt,
          progress: item.progress / 100,
          rating: nil,
          historyID: nil,
          playbackID: item.id
        )
      }
    )

    let watchlistItems = await enrich(
      (snapshot.watchlistMovies + snapshot.watchlistShows).compactMap { item in
        item.mediaReference.map {
          RawLibraryItem(
            reference: $0,
            date: item.listedAt,
            progress: nil,
            rating: nil,
            historyID: nil,
            playbackID: nil
          )
        }
      }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    )

    let historyItems = await enrich(
      snapshot.history.compactMap { item in
        item.mediaReference.map {
          RawLibraryItem(
            reference: $0,
            date: item.watchedAt,
            progress: nil,
            rating: nil,
            historyID: item.id,
            playbackID: nil
          )
        }
      }
    )

    let collectionItems = await enrich(
      (snapshot.collectionMovies + snapshot.collectionShows).compactMap { item in
        item.mediaReference.map {
          RawLibraryItem(
            reference: $0,
            date: item.collectedAt,
            progress: nil,
            rating: nil,
            historyID: nil,
            playbackID: nil
          )
        }
      }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    )

    let ratingItems = await enrich(
      (snapshot.ratingsMovies + snapshot.ratingsShows).compactMap { item in
        item.mediaReference.map {
          RawLibraryItem(
            reference: $0,
            date: item.ratedAt,
            progress: nil,
            rating: item.rating,
            historyID: nil,
            playbackID: nil
          )
        }
      }.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    )

    var categories: [TraktLibraryCategory] = [
      .continueWatching, .watchlist, .history, .collection, .ratings,
    ]
    var values: [String: [TraktLibraryDisplayItem]] = [
      TraktLibraryCategory.continueWatching.id: continueItems,
      TraktLibraryCategory.watchlist.id: watchlistItems,
      TraktLibraryCategory.history.id: historyItems,
      TraktLibraryCategory.collection.id: collectionItems,
      TraktLibraryCategory.ratings.id: ratingItems,
    ]

    for list in snapshot.lists {
      let category = TraktLibraryCategory.personalList(id: list.id, name: list.name)
      categories.append(category)
      let raw = (snapshot.listItems[String(list.id)] ?? []).compactMap { item in
        item.mediaReference.map {
          RawLibraryItem(
            reference: $0,
            date: item.listedAt,
            progress: nil,
            rating: nil,
            historyID: nil,
            playbackID: nil
          )
        }
      }
      values[category.id] = await enrich(raw)
    }

    return TraktLibraryContent(
      profile: snapshot.profile,
      categories: categories,
      items: values,
      syncedAt: snapshot.syncedAt,
      pendingMutationCount: await repository.pendingMutationCount(),
      failedMutationCount: await repository.failedMutationCount()
    )
  }

  private func enrich(_ rawItems: [RawLibraryItem]) async -> [TraktLibraryDisplayItem] {
    let indexed = Array(rawItems.prefix(500).enumerated())
    var enriched: [(Int, TraktLibraryDisplayItem)] = []
    enriched.reserveCapacity(indexed.count)

    for batchStart in stride(from: 0, to: indexed.count, by: 8) {
      guard !Task.isCancelled else { break }
      let batch = indexed[batchStart..<min(batchStart + 8, indexed.count)]
      let values = await withTaskGroup(of: (Int, TraktLibraryDisplayItem).self) { group in
        for (index, raw) in batch {
          group.addTask {
            let media = await self.mediaItem(for: raw)
            return (
              index,
              TraktLibraryDisplayItem(
                id: "\(raw.reference.stableID):\(raw.historyID ?? raw.playbackID ?? index)",
                media: media,
                reference: raw.reference,
                date: raw.date,
                rating: raw.rating,
                historyID: raw.historyID,
                playbackID: raw.playbackID
              )
            )
          }
        }

        var batchResult: [(Int, TraktLibraryDisplayItem)] = []
        for await value in group { batchResult.append(value) }
        return batchResult
      }
      enriched.append(contentsOf: values)
    }

    return enriched.sorted { $0.0 < $1.0 }.map(\.1)
  }

  private func mediaItem(for raw: RawLibraryItem) async -> MediaItem {
    let reference = raw.reference
    let kind: MediaKind = reference.type == .movie ? .movie : .series
    let title =
      reference.movie?.title ?? reference.show?.title ?? String(localized: "media.unknownTitle")
    let year = reference.movie?.year ?? reference.show?.year
    let ids = reference.movie?.ids ?? reference.show?.ids ?? TraktIDs()

    var item = MediaItem(
      id: reference.stableID,
      tmdbID: ids.tmdb,
      imdbID: ids.imdb,
      kind: kind,
      title: title,
      subtitle: episodeSubtitle(reference) ?? raw.rating.map { "★ \($0)/10" },
      overview: nil,
      posterURL: nil,
      backdropURL: nil,
      releaseYear: year,
      genreIDs: [],
      rating: raw.rating.map(Double.init),
      progress: raw.progress,
      rank: nil,
      providerName: nil
    )

    if let tmdbID = ids.tmdb,
      let details = try? await tmdb.details(id: tmdbID, kind: kind, language: language)
    {
      let enriched = details.mediaItem(kind: kind)
      item = MediaItem(
        id: item.id,
        tmdbID: tmdbID,
        imdbID: ids.imdb,
        kind: kind,
        title: enriched.title,
        subtitle: item.subtitle,
        overview: enriched.overview,
        posterURL: enriched.posterURL,
        backdropURL: enriched.backdropURL,
        releaseYear: enriched.releaseYear ?? year,
        genreIDs: enriched.genreIDs,
        rating: item.rating ?? enriched.rating,
        progress: raw.progress,
        rank: nil,
        providerName: nil
      )
    }
    return item
  }

  private func episodeSubtitle(_ reference: TraktMediaReference) -> String? {
    guard let episode = reference.episode else { return nil }
    let format = String(localized: "library.episodeFormat")
    return String(format: format, episode.season, episode.number)
  }
}

private struct RawLibraryItem: Sendable {
  let reference: TraktMediaReference
  let date: Date?
  let progress: Double?
  let rating: Int?
  let historyID: Int?
  let playbackID: Int?
}
