import Foundation

enum TraktMutationOutcome: Equatable, Sendable {
  case synced
  case queued
}

actor TraktLibraryRepository {
  enum RepositoryError: LocalizedError {
    case disconnected

    var errorDescription: String? {
      String(localized: "trakt.error.unauthorized")
    }
  }

  private let api: TraktAPIClient
  private let session: TraktSession
  private let cache: TraktLibraryCache
  private let queue: TraktMutationQueue
  private var currentSnapshot: TraktLibrarySnapshot?

  init(
    api: TraktAPIClient = TraktAPIClient(),
    session: TraktSession,
    cache: TraktLibraryCache = TraktLibraryCache(),
    queue: TraktMutationQueue = TraktMutationQueue()
  ) {
    self.api = api
    self.session = session
    self.cache = cache
    self.queue = queue
  }

  func cachedSnapshot() async -> TraktLibrarySnapshot {
    if let currentSnapshot { return currentSnapshot }
    let loaded = await cache.load()
    currentSnapshot = loaded
    return loaded
  }

  func pendingMutationCount() async -> Int {
    await queue.all().count
  }

  func pendingMutations() async -> [TraktPendingMutation] {
    await queue.all()
  }

  func failedMutationCount() async -> Int {
    await queue.failed().count
  }

  func refresh(force: Bool = false) async throws -> TraktLibrarySnapshot {
    var cached = await cachedSnapshot()
    guard await session.isConnected else {
      if !cached.isEmpty { return cached }
      throw RepositoryError.disconnected
    }

    let token = try await session.validToken()
    await drainQueue(token: token)

    let activities: TraktLastActivities?
    do {
      activities = try await api.lastActivities(token: token)
    } catch TraktAPIClient.APIError.unauthorized {
      await session.invalidateAuthorization()
      throw TraktAPIClient.APIError.unauthorized
    } catch {
      activities = nil
    }
    if !force,
      let activities,
      activities == cached.lastActivities,
      let syncedAt = cached.syncedAt,
      Date().timeIntervalSince(syncedAt) < 900
    {
      cached.profile = await session.profile
      cached.syncedAt = Date()
      await persist(cached)
      return cached
    }

    async let settingsResult: TraktUserSettings? = optional {
      try await self.api.userSettings(token: token)
    }
    async let playbackResult: [TraktPlaybackItem]? = optional {
      try await self.api.allPages(path: "/sync/playback", token: token)
    }
    async let watchlistMoviesResult: [TraktWatchlistItem]? = optional {
      try await self.api.allPages(path: "/sync/watchlist/movies", token: token)
    }
    async let watchlistShowsResult: [TraktWatchlistItem]? = optional {
      try await self.api.allPages(path: "/sync/watchlist/shows", token: token)
    }
    async let collectionMoviesResult: [TraktCollectionItem]? = optional {
      try await self.api.allPages(path: "/sync/collection/movies", token: token)
    }
    async let collectionShowsResult: [TraktCollectionItem]? = optional {
      try await self.api.allPages(path: "/sync/collection/shows", token: token)
    }
    async let watchedMoviesResult: [TraktWatchedMovie]? = optional {
      try await self.api.allPages(path: "/sync/watched/movies", token: token)
    }
    async let watchedShowsResult: [TraktWatchedShow]? = optional {
      try await self.api.allPages(path: "/sync/watched/shows", token: token)
    }
    async let ratingsMoviesResult: [TraktRatingItem]? = optional {
      try await self.api.allPages(path: "/sync/ratings/movies", token: token)
    }
    async let ratingsShowsResult: [TraktRatingItem]? = optional {
      try await self.api.allPages(path: "/sync/ratings/shows", token: token)
    }
    async let historyResult: [TraktHistoryItem]? = optional {
      try await self.fetchAllHistory(token: token)
    }
    async let listsResult: [TraktPersonalList]? = optional {
      try await self.api.allPages(path: "/users/me/lists", token: token)
    }

    let settings = await settingsResult
    let playback = await playbackResult
    let watchlistMovies = await watchlistMoviesResult
    let watchlistShows = await watchlistShowsResult
    let collectionMovies = await collectionMoviesResult
    let collectionShows = await collectionShowsResult
    let watchedMovies = await watchedMoviesResult
    let watchedShows = await watchedShowsResult
    let ratingsMovies = await ratingsMoviesResult
    let ratingsShows = await ratingsShowsResult
    let history = await historyResult
    let lists = await listsResult

    let resolvedLists = lists ?? cached.lists
    let resolvedListItems = await fetchListItems(
      lists: resolvedLists,
      token: token,
      fallback: cached.listItems
    )

    let snapshot = TraktLibrarySnapshot(
      profile: settings?.user ?? await session.profile ?? cached.profile,
      playback: playback ?? cached.playback,
      watchlistMovies: watchlistMovies ?? cached.watchlistMovies,
      watchlistShows: watchlistShows ?? cached.watchlistShows,
      collectionMovies: collectionMovies ?? cached.collectionMovies,
      collectionShows: collectionShows ?? cached.collectionShows,
      history: history ?? cached.history,
      watchedMovies: watchedMovies ?? cached.watchedMovies,
      watchedShows: watchedShows ?? cached.watchedShows,
      ratingsMovies: ratingsMovies ?? cached.ratingsMovies,
      ratingsShows: ratingsShows ?? cached.ratingsShows,
      lists: resolvedLists,
      listItems: resolvedListItems,
      lastActivities: activities ?? cached.lastActivities,
      syncedAt: Date()
    )
    await persist(snapshot)
    return snapshot
  }

  func setWatchlist(_ reference: TraktMediaReference, isListed: Bool) async throws
    -> TraktMutationOutcome
  {
    let normalized = watchlistReference(reference)
    let request = syncRequest(for: normalized)
    let kind: TraktMutationKind = isListed ? .addWatchlist : .removeWatchlist
    await optimisticallyUpdateWatchlist(normalized, isListed: isListed)
    return try await submit(TraktPendingMutation(kind: kind, request: request))
  }

  func setCollection(_ reference: TraktMediaReference, isCollected: Bool) async throws
    -> TraktMutationOutcome
  {
    let request = syncRequest(for: reference, collectedAt: isCollected ? Date() : nil)
    let kind: TraktMutationKind = isCollected ? .addCollection : .removeCollection
    await optimisticallyUpdateCollection(reference, isCollected: isCollected)
    return try await submit(TraktPendingMutation(kind: kind, request: request))
  }

  func markWatched(_ reference: TraktMediaReference, watchedAt: Date = Date()) async throws
    -> TraktMutationOutcome
  {
    let request = syncRequest(for: reference, watchedAt: watchedAt)
    await optimisticallyAddHistory(reference, watchedAt: watchedAt)
    return try await submit(TraktPendingMutation(kind: .addHistory, request: request))
  }

  func removeHistory(ids: [Int]) async throws -> TraktMutationOutcome {
    guard !ids.isEmpty else { return .synced }
    await optimisticallyRemoveHistory(ids: ids)
    return try await submit(
      TraktPendingMutation(kind: .removeHistory, request: TraktSyncRequest(ids: ids))
    )
  }

  func setRating(_ reference: TraktMediaReference, rating: Int?) async throws
    -> TraktMutationOutcome
  {
    let normalizedRating = rating.map { min(max($0, 1), 10) }
    let kind: TraktMutationKind = normalizedRating == nil ? .removeRating : .addRating
    let request = syncRequest(for: reference, ratedAt: Date(), rating: normalizedRating)
    await optimisticallyUpdateRating(reference, rating: normalizedRating)
    return try await submit(TraktPendingMutation(kind: kind, request: request))
  }

  func removePlayback(id: Int) async throws -> TraktMutationOutcome {
    await optimisticallyRemovePlayback(id: id)
    return try await submit(TraktPendingMutation(kind: .removePlayback, playbackID: id))
  }

  func enqueueScrobble(
    action: TraktScrobbleAction,
    payload: TraktScrobblePayload
  ) async throws -> TraktMutationOutcome {
    try await submit(
      TraktPendingMutation(
        kind: .scrobble,
        scrobbleAction: action,
        scrobblePayload: payload
      )
    )
  }

  func createList(_ request: TraktListRequest) async throws -> TraktMutationOutcome {
    let mutation = TraktPendingMutation(kind: .createList, listRequest: request)
    await optimisticallyCreateList(request: request, mutationID: mutation.id)
    return try await submit(mutation)
  }

  func updateList(
    id: Int,
    request: TraktListRequest
  ) async throws -> TraktMutationOutcome {
    await optimisticallyUpdateList(id: id, request: request)
    return try await submit(
      TraktPendingMutation(kind: .updateList, listID: id, listRequest: request)
    )
  }

  func deleteList(id: Int) async throws -> TraktMutationOutcome {
    await optimisticallyDeleteList(id: id)
    return try await submit(TraktPendingMutation(kind: .deleteList, listID: id))
  }

  func setListMembership(
    listID: Int,
    reference: TraktMediaReference,
    isListed: Bool
  ) async throws -> TraktMutationOutcome {
    let kind: TraktMutationKind = isListed ? .addListItems : .removeListItems
    let request = syncRequest(for: reference)
    await optimisticallySetListMembership(
      listID: listID,
      reference: reference,
      isListed: isListed
    )
    return try await submit(
      TraktPendingMutation(kind: kind, request: request, listID: listID)
    )
  }

  func clearCachedSnapshotPreservingMutations() async {
    currentSnapshot = .empty
    await cache.clear()
  }

  func retryPendingMutations() async throws {
    guard await session.isConnected else { throw RepositoryError.disconnected }
    let token = try await session.validToken()
    await drainQueue(token: token)
  }

  func clearLocalData() async {
    currentSnapshot = .empty
    await cache.clear()
    await queue.clear()
  }

  // MARK: - Mutation processing

  private func submit(_ mutation: TraktPendingMutation) async throws -> TraktMutationOutcome {
    guard await session.isConnected else {
      await queue.enqueue(mutation)
      return .queued
    }

    do {
      let token = try await session.validToken()
      try await execute(mutation, token: token)
      return .synced
    } catch TraktAPIClient.APIError.unauthorized {
      await session.invalidateAuthorization()
      throw TraktAPIClient.APIError.unauthorized
    } catch {
      if isQueueable(error) {
        await queue.enqueue(mutation)
        return .queued
      }
      throw error
    }
  }

  private func drainQueue(token: TraktToken) async {
    let pending = await queue.all().sorted { $0.createdAt < $1.createdAt }
    for var mutation in pending {
      do {
        try await execute(mutation, token: token)
        await queue.remove(id: mutation.id)
      } catch TraktAPIClient.APIError.conflict {
        await queue.remove(id: mutation.id)
      } catch TraktAPIClient.APIError.unauthorized {
        await session.invalidateAuthorization()
        break
      } catch {
        mutation.attemptCount += 1
        mutation.lastAttemptAt = Date()
        mutation.lastError = error.localizedDescription
        await queue.replace(mutation)
        if !isQueueable(error) || mutation.attemptCount >= 8 { continue }
        break
      }
    }
  }

  private func execute(_ mutation: TraktPendingMutation, token: TraktToken) async throws {
    switch mutation.kind {
    case .addWatchlist:
      guard let request = mutation.request else { return }
      _ = try await api.addToWatchlist(request, token: token)
    case .removeWatchlist:
      guard let request = mutation.request else { return }
      _ = try await api.removeFromWatchlist(request, token: token)
    case .addCollection:
      guard let request = mutation.request else { return }
      _ = try await api.addToCollection(request, token: token)
    case .removeCollection:
      guard let request = mutation.request else { return }
      _ = try await api.removeFromCollection(request, token: token)
    case .addHistory:
      guard let request = mutation.request else { return }
      _ = try await api.addToHistory(request, token: token)
    case .removeHistory:
      guard let request = mutation.request else { return }
      _ = try await api.removeFromHistory(request, token: token)
    case .addRating:
      guard let request = mutation.request else { return }
      _ = try await api.addRatings(request, token: token)
    case .removeRating:
      guard let request = mutation.request else { return }
      _ = try await api.removeRatings(request, token: token)
    case .removePlayback:
      guard let playbackID = mutation.playbackID else { return }
      try await api.removePlayback(id: playbackID, token: token)
    case .scrobble:
      guard let action = mutation.scrobbleAction, let payload = mutation.scrobblePayload else {
        return
      }
      _ = try await api.scrobble(action: action, payload: payload, token: token)
    case .createList:
      guard let request = mutation.listRequest else { return }
      let created = try await api.createList(request, token: token)
      var snapshot = await cachedSnapshot()
      snapshot.lists.removeAll {
        $0.id == created.id || ($0.id < 0 && $0.name == request.name)
      }
      snapshot.lists.append(created)
      snapshot.lists.sort {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      await persist(snapshot)
    case .updateList:
      guard let listID = mutation.listID, let request = mutation.listRequest else { return }
      let updated = try await api.updateList(id: listID, request: request, token: token)
      var snapshot = await cachedSnapshot()
      if let index = snapshot.lists.firstIndex(where: { $0.id == listID }) {
        snapshot.lists[index] = updated
      } else {
        snapshot.lists.append(updated)
      }
      await persist(snapshot)
    case .deleteList:
      guard let listID = mutation.listID else { return }
      try await api.deleteList(id: listID, token: token)
      var snapshot = await cachedSnapshot()
      snapshot.lists.removeAll { $0.id == listID }
      snapshot.listItems[String(listID)] = nil
      await persist(snapshot)
    case .addListItems:
      guard let listID = mutation.listID, let request = mutation.request else { return }
      _ = try await api.addListItems(listID: listID, request: request, token: token)
      var snapshot = await cachedSnapshot()
      snapshot.listItems[String(listID)] = try await allListItems(listID: listID, token: token)
      await persist(snapshot)
    case .removeListItems:
      guard let listID = mutation.listID, let request = mutation.request else { return }
      _ = try await api.removeListItems(listID: listID, request: request, token: token)
      var snapshot = await cachedSnapshot()
      snapshot.listItems[String(listID)] = try await allListItems(listID: listID, token: token)
      await persist(snapshot)
    }
  }

  private func isQueueable(_ error: Error) -> Bool {
    if error is URLError { return true }
    guard let apiError = error as? TraktAPIClient.APIError else { return false }
    switch apiError {
    case .unauthorized, .rateLimited, .server: true
    default: false
    }
  }

  // MARK: - Fetch helpers

  private func fetchAllHistory(token: TraktToken) async throws -> [TraktHistoryItem] {
    try await api.allPages(
      path: "/sync/history",
      limit: 1_000,
      maximumPages: 50,
      token: token
    )
  }

  private func allListItems(listID: Int, token: TraktToken) async throws -> [TraktListItem] {
    try await api.allPages(
      path: "/users/me/lists/\(listID)/items",
      limit: 1_000,
      maximumPages: 50,
      token: token
    )
  }

  private func fetchListItems(
    lists: [TraktPersonalList],
    token: TraktToken,
    fallback: [String: [TraktListItem]]
  ) async -> [String: [TraktListItem]] {
    await withTaskGroup(of: (String, [TraktListItem]?).self) { group in
      for list in lists {
        group.addTask {
          let values: [TraktListItem]? = try? await self.allListItems(
            listID: list.id,
            token: token
          )
          return (String(list.id), values)
        }
      }

      var result = fallback
      for await (id, values) in group {
        if let values { result[id] = values }
      }
      return result.filter { key, _ in lists.contains { String($0.id) == key } }
    }
  }

  private func optional<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
  ) async -> Value? {
    try? await operation()
  }

  // MARK: - Request mapping

  private func watchlistReference(_ reference: TraktMediaReference) -> TraktMediaReference {
    if reference.type == .episode, let show = reference.show {
      return TraktMediaReference(show: show)
    }
    return reference
  }

  private func syncRequest(
    for reference: TraktMediaReference,
    watchedAt: Date? = nil,
    collectedAt: Date? = nil,
    ratedAt: Date? = nil,
    rating: Int? = nil
  ) -> TraktSyncRequest {
    switch reference.type {
    case .movie:
      guard let movie = reference.movie else { return TraktSyncRequest() }
      return TraktSyncRequest(
        movies: [
          TraktSyncMovieReference(
            movie: movie,
            watchedAt: watchedAt,
            collectedAt: collectedAt,
            ratedAt: ratedAt,
            rating: rating
          )
        ]
      )
    case .show:
      guard let show = reference.show else { return TraktSyncRequest() }
      return TraktSyncRequest(
        shows: [
          TraktSyncShowReference(
            show: show,
            watchedAt: watchedAt,
            collectedAt: collectedAt,
            ratedAt: ratedAt,
            rating: rating
          )
        ]
      )
    case .episode:
      guard let episode = reference.episode else { return TraktSyncRequest() }
      return TraktSyncRequest(
        episodes: [
          TraktSyncEpisodeReference(
            episode: episode,
            watchedAt: watchedAt,
            collectedAt: collectedAt,
            ratedAt: ratedAt,
            rating: rating
          )
        ]
      )
    }
  }

  // MARK: - Optimistic cache

  private func optimisticallyUpdateWatchlist(
    _ reference: TraktMediaReference,
    isListed: Bool
  ) async {
    var snapshot = await cachedSnapshot()
    let id = reference.stableID
    snapshot.watchlistMovies.removeAll { $0.mediaReference?.stableID == id }
    snapshot.watchlistShows.removeAll { $0.mediaReference?.stableID == id }
    if isListed {
      let item = TraktWatchlistItem(
        rank: nil,
        listedAt: Date(),
        type: reference.type.rawValue,
        movie: reference.movie,
        show: reference.show
      )
      if reference.type == .movie {
        snapshot.watchlistMovies.insert(item, at: 0)
      } else {
        snapshot.watchlistShows.insert(item, at: 0)
      }
    }
    await persist(snapshot)
  }

  private func optimisticallyUpdateCollection(
    _ reference: TraktMediaReference,
    isCollected: Bool
  ) async {
    var snapshot = await cachedSnapshot()
    let id = reference.stableID
    snapshot.collectionMovies.removeAll { $0.mediaReference?.stableID == id }
    snapshot.collectionShows.removeAll { $0.mediaReference?.stableID == id }
    if isCollected {
      let item = TraktCollectionItem(
        collectedAt: Date(),
        updatedAt: Date(),
        movie: reference.movie,
        show: reference.show,
        seasons: nil
      )
      if reference.type == .movie {
        snapshot.collectionMovies.insert(item, at: 0)
      } else {
        snapshot.collectionShows.insert(item, at: 0)
      }
    }
    await persist(snapshot)
  }

  private func optimisticallyAddHistory(
    _ reference: TraktMediaReference,
    watchedAt: Date
  ) async {
    var snapshot = await cachedSnapshot()
    let provisionalID = -Int(watchedAt.timeIntervalSince1970)
    snapshot.history.insert(
      TraktHistoryItem(
        id: provisionalID,
        watchedAt: watchedAt,
        action: "scrobble",
        type: reference.type.rawValue,
        movie: reference.movie,
        episode: reference.episode,
        show: reference.show
      ),
      at: 0
    )
    await persist(snapshot)
  }

  private func optimisticallyRemoveHistory(ids: [Int]) async {
    var snapshot = await cachedSnapshot()
    snapshot.history.removeAll { ids.contains($0.id) }
    await persist(snapshot)
  }

  private func optimisticallyUpdateRating(
    _ reference: TraktMediaReference,
    rating: Int?
  ) async {
    var snapshot = await cachedSnapshot()
    let id = reference.stableID
    snapshot.ratingsMovies.removeAll { $0.mediaReference?.stableID == id }
    snapshot.ratingsShows.removeAll { $0.mediaReference?.stableID == id }
    if let rating {
      let item = TraktRatingItem(
        ratedAt: Date(),
        rating: rating,
        type: reference.type.rawValue,
        movie: reference.movie,
        show: reference.show,
        episode: reference.episode
      )
      if reference.type == .movie {
        snapshot.ratingsMovies.insert(item, at: 0)
      } else {
        snapshot.ratingsShows.insert(item, at: 0)
      }
    }
    await persist(snapshot)
  }

  private func optimisticallyRemovePlayback(id: Int) async {
    var snapshot = await cachedSnapshot()
    snapshot.playback.removeAll { $0.id == id }
    await persist(snapshot)
  }

  private func optimisticallyCreateList(
    request: TraktListRequest,
    mutationID: UUID
  ) async {
    var snapshot = await cachedSnapshot()
    let prefix = mutationID.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)
    let numeric = Int(prefix, radix: 16) ?? Int(Date().timeIntervalSince1970)
    let provisionalID = -max(numeric, 1)
    snapshot.lists.removeAll { $0.id < 0 && $0.name == request.name }
    snapshot.lists.append(
      TraktPersonalList(
        name: request.name,
        description: request.description,
        privacy: request.privacy,
        shareLink: nil,
        type: "personal",
        displayNumbers: request.displayNumbers,
        allowComments: request.allowComments,
        sortBy: request.sortBy,
        sortHow: request.sortHow,
        createdAt: Date(),
        updatedAt: Date(),
        itemCount: 0,
        commentCount: 0,
        likes: 0,
        ids: TraktListIDs(trakt: provisionalID, slug: nil)
      )
    )
    await persist(snapshot)
  }

  private func optimisticallyUpdateList(id: Int, request: TraktListRequest) async {
    var snapshot = await cachedSnapshot()
    guard let index = snapshot.lists.firstIndex(where: { $0.id == id }) else { return }
    let existing = snapshot.lists[index]
    snapshot.lists[index] = TraktPersonalList(
      name: request.name,
      description: request.description,
      privacy: request.privacy,
      shareLink: existing.shareLink,
      type: existing.type,
      displayNumbers: request.displayNumbers,
      allowComments: request.allowComments,
      sortBy: request.sortBy,
      sortHow: request.sortHow,
      createdAt: existing.createdAt,
      updatedAt: Date(),
      itemCount: existing.itemCount,
      commentCount: existing.commentCount,
      likes: existing.likes,
      ids: existing.ids
    )
    await persist(snapshot)
  }

  private func optimisticallyDeleteList(id: Int) async {
    var snapshot = await cachedSnapshot()
    snapshot.lists.removeAll { $0.id == id }
    snapshot.listItems.removeValue(forKey: String(id))
    await persist(snapshot)
  }

  private func optimisticallySetListMembership(
    listID: Int,
    reference: TraktMediaReference,
    isListed: Bool
  ) async {
    var snapshot = await cachedSnapshot()
    let key = String(listID)
    var items = snapshot.listItems[key] ?? []
    items.removeAll { $0.mediaReference?.stableID == reference.stableID }
    if isListed {
      let provisionalID = -Int(Date().timeIntervalSince1970)
      items.append(
        TraktListItem(
          rank: items.count + 1,
          id: provisionalID,
          listedAt: Date(),
          notes: nil,
          type: reference.type.rawValue,
          movie: reference.movie,
          show: reference.show,
          episode: reference.episode
        )
      )
    }
    snapshot.listItems[key] = items
    await persist(snapshot)
  }

  private func persist(_ snapshot: TraktLibrarySnapshot) async {
    currentSnapshot = snapshot
    try? await cache.save(snapshot)
  }
}
