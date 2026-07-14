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

  @Published private(set) var state: State = .idle
  @Published private(set) var results: [MediaItem] = []

  private let tmdb: TMDBAPIClient
  private let addonRepository: any AddonContentProviding

  init(
    tmdb: TMDBAPIClient = TMDBAPIClient(),
    addonRepository: any AddonContentProviding = AddonContentRepository()
  ) {
    self.tmdb = tmdb
    self.addonRepository = addonRepository
  }

  func search(query: String, language: String, addonManifestURLs: [String]) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else {
      results = []
      state = .idle
      return
    }

    state = .searching
    do {
      async let tmdbTask = tmdb.search(query: trimmed, language: language)
      async let addonTask = addonRepository.search(
        query: trimmed,
        kind: nil,
        urlStrings: addonManifestURLs
      )
      let tmdbResults = try await tmdbTask
      let addonResults = await addonTask

      let mappedTMDB = tmdbResults.map {
        $0.mediaItem(kind: $0.mediaType == "movie" ? .movie : .series)
      }
      let mappedAddons = addonResults.map(MediaItem.init(addon:))
      results = deduplicate(mappedTMDB + mappedAddons)
      state = results.isEmpty ? .empty : .results
    } catch {
      let addonResults = await addonRepository.search(
        query: trimmed,
        kind: nil,
        urlStrings: addonManifestURLs
      )
      results = deduplicate(addonResults.map(MediaItem.init(addon:)))
      state = results.isEmpty ? .failed(error.localizedDescription) : .results
    }
  }

  private func deduplicate(_ values: [MediaItem]) -> [MediaItem] {
    var seen: Set<String> = []
    return values.filter { item in
      let key = item.imdbID ?? item.tmdbID.map(String.init) ?? "\(item.kind.rawValue):\(item.title.lowercased())"
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
