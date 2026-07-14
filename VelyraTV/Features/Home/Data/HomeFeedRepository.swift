import Foundation

@MainActor
final class HomeFeedRepository {
    private let tmdb: TMDBAPIClient
    private let traktSession: TraktSession
    private let cache: HomeFeedCache

    init(
        tmdb: TMDBAPIClient = TMDBAPIClient(),
        traktSession: TraktSession,
        cache: HomeFeedCache = HomeFeedCache()
    ) {
        self.tmdb = tmdb
        self.traktSession = traktSession
        self.cache = cache
    }

    func load(language: String, region: String) async throws -> HomeFeed {
        guard TMDBConfiguration.isConfigured else {
            throw TMDBAPIClient.APIError.notConfigured
        }

        async let trendingMoviesTask = tmdb.trending(kind: .movie, language: language)
        async let trendingSeriesTask = tmdb.trending(kind: .series, language: language)
        async let movieProvidersTask = tmdb.providers(kind: .movie, language: language, region: region)
        async let seriesProvidersTask = tmdb.providers(kind: .series, language: language, region: region)
        async let countryMoviesTask = tmdb.discover(kind: .movie, language: language, region: region)
        async let countrySeriesTask = tmdb.discover(kind: .series, language: language, region: region)

        let trendingMovies = try await trendingMoviesTask
        let trendingSeries = try await trendingSeriesTask
        let movieProviders = try await movieProvidersTask
        let seriesProviders = try await seriesProvidersTask
        let providerResults = mergeProviders(movieProviders, seriesProviders)
        let countryMovies = try await countryMoviesTask
        let countrySeries = try await countrySeriesTask
        let continueWatching = await loadContinueWatching(language: language)

        let providers = preferredProviders(from: providerResults).map(\.streamingProvider)
        let genreFilters = curatedGenres()
        let hero = (trendingSeries.first ?? trendingMovies.first)?.mediaItem(kind: .series) ?? .previewHero
        let countryName = Locale(identifier: language).localizedString(forRegionCode: region) ?? region

        var sections = [
            HomeSection(
                id: "trending-series",
                title: String(localized: "home.trending.series"),
                subtitle: String(localized: "home.trending.today"),
                style: .poster,
                items: Array(trendingSeries.prefix(18)).map { $0.mediaItem(kind: .series) }
            ),
            HomeSection(
                id: "trending-movies",
                title: String(localized: "home.trending.movies"),
                subtitle: String(localized: "home.trending.today"),
                style: .poster,
                items: Array(trendingMovies.prefix(18)).map { $0.mediaItem(kind: .movie) }
            ),
            HomeSection(
                id: "country-series",
                title: String(format: String(localized: "home.top10.series.country"), countryName),
                subtitle: String(localized: "home.top10.velyra.explanation"),
                style: .topTen,
                items: Array(countrySeries.prefix(10).enumerated()).map { index, item in
                    item.mediaItem(kind: .series, rank: index + 1)
                }
            ),
            HomeSection(
                id: "country-movies",
                title: String(format: String(localized: "home.top10.movies.country"), countryName),
                subtitle: String(localized: "home.top10.velyra.explanation"),
                style: .topTen,
                items: Array(countryMovies.prefix(10).enumerated()).map { index, item in
                    item.mediaItem(kind: .movie, rank: index + 1)
                }
            )
        ]

        let providerSections = await withTaskGroup(of: (Int, HomeSection?).self) { group in
            for (index, provider) in providers.prefix(5).enumerated() {
                group.addTask { [tmdb] in
                    async let moviesTask = tmdb.discover(
                        kind: .movie,
                        language: language,
                        region: region,
                        providerID: provider.id
                    )
                    async let seriesTask = tmdb.discover(
                        kind: .series,
                        language: language,
                        region: region,
                        providerID: provider.id
                    )

                    guard let movies = try? await moviesTask,
                          let series = try? await seriesTask else {
                        return (index, nil)
                    }

                    let items = (movies.map { ($0, MediaKind.movie) } + series.map { ($0, MediaKind.series) })
                        .sorted { ($0.0.popularity ?? 0) > ($1.0.popularity ?? 0) }
                        .prefix(16)
                        .map { result, kind in
                            result.mediaItem(kind: kind, providerName: provider.name)
                        }

                    guard !items.isEmpty else { return (index, nil) }
                    return (index, HomeSection(
                        id: "provider-\(provider.id)",
                        title: String(format: String(localized: "home.provider.available"), provider.name),
                        subtitle: String(localized: "home.provider.attribution"),
                        style: .poster,
                        items: Array(items)
                    ))
                }
            }

            var results: [(Int, HomeSection)] = []
            for await (index, section) in group {
                if let section { results.append((index, section)) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
        sections.append(contentsOf: providerSections)

        let feed = HomeFeed(
            hero: hero,
            continueWatching: continueWatching,
            genres: genreFilters,
            providers: providers,
            sections: deduplicateAdjacent(sections, excluding: hero.id)
        )
        await cache.save(feed, language: language, region: region)
        return feed
    }

    func cachedFeed(language: String, region: String) async -> HomeFeed? {
        await cache.load(language: language, region: region)
    }

    func loadGenre(_ genre: GenreFilter, language: String, region: String) async throws -> HomeSection {
        async let moviesTask: [TMDBMediaResult] = if let movieGenreID = genre.movieGenreID {
            try await tmdb.discover(
                kind: .movie,
                language: language,
                region: region,
                genreID: movieGenreID
            )
        } else {
            []
        }

        async let seriesTask: [TMDBMediaResult] = if let seriesGenreID = genre.seriesGenreID {
            try await tmdb.discover(
                kind: .series,
                language: language,
                region: region,
                genreID: seriesGenreID
            )
        } else {
            []
        }

        let movies = try await moviesTask
        let series = try await seriesTask
        let items = (movies.map { ($0, MediaKind.movie) } + series.map { ($0, MediaKind.series) })
            .sorted { ($0.0.popularity ?? 0) > ($1.0.popularity ?? 0) }
            .prefix(24)
            .map { result, kind in result.mediaItem(kind: kind) }

        return HomeSection(
            id: "genre-\(genre.id)",
            title: genre.name,
            subtitle: String(localized: "home.genre.selection"),
            style: .poster,
            items: Array(items)
        )
    }

    func loadProvider(_ provider: StreamingProvider, language: String, region: String) async throws -> HomeSection {
        async let movieResults = tmdb.discover(
            kind: .movie,
            language: language,
            region: region,
            providerID: provider.id
        )
        async let seriesResults = tmdb.discover(
            kind: .series,
            language: language,
            region: region,
            providerID: provider.id
        )

        let movies = try await movieResults
        let series = try await seriesResults
        let combined = movies.map { $0.mediaItem(kind: .movie, providerName: provider.name) }
            + series.map { $0.mediaItem(kind: .series, providerName: provider.name) }

        return HomeSection(
            id: "provider-selection-\(provider.id)",
            title: provider.name,
            subtitle: String(localized: "home.provider.attribution"),
            style: .poster,
            items: Array(combined.prefix(24))
        )
    }

    private func loadContinueWatching(language: String) async -> [MediaItem] {
        guard case .connected = traktSession.state else { return [] }
        let coordinator = TraktSyncCoordinator(session: traktSession)
        guard let playback = try? await coordinator.fetchPlaybackProgress() else { return [] }

        return await withTaskGroup(of: (Int, MediaItem?).self) { group in
            for (index, item) in playback.prefix(20).enumerated() {
                group.addTask { [tmdb] in
                    let kind: MediaKind = item.movie != nil ? .movie : .series
                    let tmdbID = item.movie?.ids.tmdb ?? item.show?.ids.tmdb
                    guard let tmdbID,
                          let details = try? await tmdb.details(id: tmdbID, kind: kind, language: language) else {
                        let title = item.movie?.title ?? item.show?.title ?? String(localized: "media.unknownTitle")
                        return (index, MediaItem(
                            id: "trakt-playback-\(item.id)",
                            tmdbID: tmdbID,
                            imdbID: item.movie?.ids.imdb ?? item.show?.ids.imdb,
                            kind: kind,
                            title: title,
                            subtitle: Self.playbackSubtitle(item),
                            overview: nil,
                            posterURL: nil,
                            backdropURL: nil,
                            releaseYear: item.movie?.year ?? item.show?.year,
                            genreIDs: [],
                            rating: nil,
                            progress: item.progress / 100,
                            rank: nil,
                            providerName: nil
                        ))
                    }

                    let base = details.mediaItem(kind: kind)
                    return (index, MediaItem(
                        id: "trakt-playback-\(item.id)",
                        tmdbID: base.tmdbID,
                        imdbID: item.movie?.ids.imdb ?? item.show?.ids.imdb,
                        kind: base.kind,
                        title: base.title,
                        subtitle: Self.playbackSubtitle(item),
                        overview: base.overview,
                        posterURL: base.posterURL,
                        backdropURL: base.backdropURL,
                        releaseYear: base.releaseYear,
                        genreIDs: base.genreIDs,
                        rating: base.rating,
                        progress: item.progress / 100,
                        rank: nil,
                        providerName: nil
                    ))
                }
            }

            var items: [(Int, MediaItem)] = []
            for await (index, item) in group {
                if let item { items.append((index, item)) }
            }
            return items.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    nonisolated private static func playbackSubtitle(_ item: TraktPlaybackItem) -> String? {
        guard let episode = item.episode else { return String(localized: "home.continueWatching.movie") }
        return String(
            format: String(localized: "home.episode.format"),
            episode.season,
            episode.number
        )
    }

    private func curatedGenres() -> [GenreFilter] {
        [
            GenreFilter(id: "action", name: String(localized: "genre.action"), movieGenreID: 28, seriesGenreID: 10759),
            GenreFilter(id: "comedy", name: String(localized: "genre.comedy"), movieGenreID: 35, seriesGenreID: 35),
            GenreFilter(id: "drama", name: String(localized: "genre.drama"), movieGenreID: 18, seriesGenreID: 18),
            GenreFilter(id: "scifi", name: String(localized: "genre.scifi"), movieGenreID: 878, seriesGenreID: 10765),
            GenreFilter(id: "thriller", name: String(localized: "genre.thriller"), movieGenreID: 53, seriesGenreID: 9648),
            GenreFilter(id: "animation", name: String(localized: "genre.animation"), movieGenreID: 16, seriesGenreID: 16),
            GenreFilter(id: "documentary", name: String(localized: "genre.documentary"), movieGenreID: 99, seriesGenreID: 99)
        ]
    }

    private func mergeProviders(_ movieProviders: [TMDBProvider], _ seriesProviders: [TMDBProvider]) -> [TMDBProvider] {
        var providersByID: [Int: TMDBProvider] = [:]
        for provider in movieProviders + seriesProviders {
            let current = providersByID[provider.providerID]
            if current == nil || (provider.displayPriority ?? .max) < (current?.displayPriority ?? .max) {
                providersByID[provider.providerID] = provider
            }
        }
        return providersByID.values.sorted {
            ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max)
        }
    }

    private func deduplicateAdjacent(_ sections: [HomeSection], excluding heroID: String) -> [HomeSection] {
        var previousIDs: Set<String> = [heroID]
        return sections.compactMap { section in
            let filtered = section.items.filter { !previousIDs.contains($0.id) }
            previousIDs = Set(section.items.map(\.id))
            guard !filtered.isEmpty else { return nil }
            return HomeSection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                style: section.style,
                items: filtered
            )
        }
    }

    private func preferredProviders(from providers: [TMDBProvider]) -> [TMDBProvider] {
        let priorities = ["Netflix", "Disney Plus", "Amazon Prime Video", "Max", "Apple TV Plus", "SkyShowtime"]
        var selected: [TMDBProvider] = []
        for preferred in priorities {
            if let match = providers.first(where: { $0.providerName.localizedCaseInsensitiveContains(preferred) }),
               !selected.contains(where: { $0.providerID == match.providerID }) {
                selected.append(match)
            }
        }
        return selected.isEmpty ? Array(providers.prefix(6)) : selected
    }
}

extension HomeFeed {
    static func preview(region: String) -> HomeFeed {
        let countryName = Locale.current.localizedString(forRegionCode: region) ?? region
        let titles = [
            "The Last Horizon", "Afterlight", "Northbound", "Silent Orbit", "The Glass House",
            "Echoes", "Wild Coast", "Midnight Signal", "Aether", "The Long Way Home"
        ]
        let items = titles.enumerated().map { index, title in
            MediaItem(
                id: "preview-\(index)",
                tmdbID: nil,
                imdbID: nil,
                kind: index.isMultiple(of: 2) ? .series : .movie,
                title: title,
                subtitle: index < 3 ? String(localized: "home.preview.subtitle") : nil,
                overview: nil,
                posterURL: nil,
                backdropURL: nil,
                releaseYear: 2026,
                genreIDs: [],
                rating: 7.8 + Double(index % 10) / 10,
                progress: index < 3 ? [0.62, 0.34, 0.18][index] : nil,
                rank: index + 1,
                providerName: nil
            )
        }

        return HomeFeed(
            hero: .previewHero,
            continueWatching: Array(items.prefix(3)),
            genres: [
                GenreFilter(id: "action", name: String(localized: "genre.action"), movieGenreID: 28, seriesGenreID: 10759),
                GenreFilter(id: "comedy", name: String(localized: "genre.comedy"), movieGenreID: 35, seriesGenreID: 35),
                GenreFilter(id: "drama", name: String(localized: "genre.drama"), movieGenreID: 18, seriesGenreID: 18),
                GenreFilter(id: "scifi", name: String(localized: "genre.scifi"), movieGenreID: 878, seriesGenreID: 10765),
                GenreFilter(id: "thriller", name: String(localized: "genre.thriller"), movieGenreID: 53, seriesGenreID: 9648)
            ],
            providers: [
                StreamingProvider(id: 8, name: "Netflix", logoURL: nil),
                StreamingProvider(id: 337, name: "Disney+", logoURL: nil),
                StreamingProvider(id: 119, name: "Prime Video", logoURL: nil),
                StreamingProvider(id: 1899, name: "Max", logoURL: nil),
                StreamingProvider(id: 350, name: "Apple TV+", logoURL: nil)
            ],
            sections: [
                HomeSection(id: "preview-trending-series", title: String(localized: "home.trending.series"), subtitle: String(localized: "home.trending.today"), style: .poster, items: items),
                HomeSection(id: "preview-trending-movies", title: String(localized: "home.trending.movies"), subtitle: String(localized: "home.trending.today"), style: .poster, items: Array(items.reversed())),
                HomeSection(id: "preview-top-series", title: String(format: String(localized: "home.top10.series.country"), countryName), subtitle: String(localized: "home.top10.velyra.explanation"), style: .topTen, items: items),
                HomeSection(id: "preview-top-movies", title: String(format: String(localized: "home.top10.movies.country"), countryName), subtitle: String(localized: "home.top10.velyra.explanation"), style: .topTen, items: Array(items.reversed()))
            ]
        )
    }
}
