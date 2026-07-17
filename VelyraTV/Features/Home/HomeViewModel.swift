import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(HomeFeed)
        case failed(String, HomeFeed)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var selectedDiscoverySection: HomeSection?
    @Published var selectedGenreID: String?
    @Published var selectedProviderID: Int?

    private var repository: HomeFeedRepository?

    var feed: HomeFeed? {
        switch state {
        case .loaded(let feed), .failed(_, let feed): feed
        default: nil
        }
    }

    func load(traktSession: TraktSession, language: String, region: String) async {
        guard state == .idle else { return }
        await refresh(traktSession: traktSession, language: language, region: region)
    }

    func refresh(traktSession: TraktSession, language: String, region: String) async {
        state = .loading
        let repository = HomeFeedRepository(traktSession: traktSession)
        self.repository = repository

        do {
            state = .loaded(try await repository.load(language: language, region: region))
        } catch {
            let fallback = await repository.cachedFeed(language: language, region: region)
                ?? .preview(region: region)
            state = .failed(error.localizedDescription, fallback)
        }
    }

    func retry(traktSession: TraktSession, language: String, region: String) async {
        state = .idle
        selectedDiscoverySection = nil
        await refresh(traktSession: traktSession, language: language, region: region)
    }

    func select(genre: GenreFilter, language: String, region: String) async {
        guard let repository else { return }
        selectedGenreID = genre.id
        selectedProviderID = nil
        selectedDiscoverySection = try? await repository.loadGenre(genre, language: language, region: region)
    }

    func select(provider: StreamingProvider, language: String, region: String) async {
        guard let repository else { return }
        selectedProviderID = provider.id
        selectedGenreID = nil
        selectedDiscoverySection = try? await repository.loadProvider(provider, language: language, region: region)
    }
}
