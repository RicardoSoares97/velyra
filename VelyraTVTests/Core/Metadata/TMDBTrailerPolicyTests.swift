import XCTest

@testable import VelyraTV

final class TMDBTrailerPolicyTests: XCTestCase {
  func testSupportedOfficialYouTubeTrailerBuildsExpectedURL() throws {
    let video = try decodeVideo(
      id: "official-trailer",
      key: "official-key",
      site: "YouTube",
      type: "Trailer",
      official: true
    )

    XCTAssertEqual(
      video.supportedOfficialTrailerURL?.absoluteString,
      "https://www.youtube.com/watch?v=official-key"
    )
  }

  func testPolicyIsCaseInsensitiveAndTrimsTheKey() throws {
    let video = try decodeVideo(
      id: "case-insensitive",
      key: "  mixed-case-key  ",
      site: "yOuTuBe",
      type: "tRaIlEr",
      official: true
    )

    XCTAssertEqual(
      video.supportedOfficialTrailerURL?.absoluteString,
      "https://www.youtube.com/watch?v=mixed-case-key"
    )
  }

  func testReservedKeyCharactersRemainOneVideoQueryValue() throws {
    let video = try decodeVideo(
      id: "reserved-characters",
      key: "  abc&autoplay=1#part  ",
      site: "YouTube",
      type: "Trailer",
      official: true
    )

    let url = try XCTUnwrap(video.supportedOfficialTrailerURL)
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let queryItems = try XCTUnwrap(components.queryItems)

    XCTAssertEqual(components.scheme, "https")
    XCTAssertEqual(components.host, "www.youtube.com")
    XCTAssertEqual(components.path, "/watch")
    XCTAssertNil(components.fragment)
    XCTAssertEqual(queryItems.count, 1)
    XCTAssertEqual(queryItems.first?.name, "v")
    XCTAssertEqual(queryItems.first?.value, "abc&autoplay=1#part")
    XCTAssertEqual(
      url.absoluteString,
      "https://www.youtube.com/watch?v=abc%26autoplay%3D1%23part"
    )
  }

  func testUnsupportedVideosDoNotProduceURLs() throws {
    let fixtures: [(id: String, key: String, site: String, type: String, official: Bool?)] = [
      ("teaser", "teaser-key", "YouTube", "Teaser", true),
      ("clip", "clip-key", "YouTube", "Clip", true),
      ("other-type", "featurette-key", "YouTube", "Featurette", true),
      ("unofficial", "unofficial-key", "YouTube", "Trailer", false),
      ("missing-official", "missing-official-key", "YouTube", "Trailer", nil),
      ("other-site", "vimeo-key", "Vimeo", "Trailer", true),
      ("empty-key", "", "YouTube", "Trailer", true),
      ("whitespace-key", " \n\t ", "YouTube", "Trailer", true),
    ]

    for fixture in fixtures {
      let video = try decodeVideo(
        id: fixture.id,
        key: fixture.key,
        site: fixture.site,
        type: fixture.type,
        official: fixture.official
      )

      XCTAssertNil(video.supportedOfficialTrailerURL, fixture.id)
    }
  }

  func testSupportedPropertySelectionSkipsUnsupportedVideosWithoutFallback() throws {
    let videos = try [
      decodeVideo(
        id: "unofficial-trailer",
        key: "unofficial-key",
        site: "YouTube",
        type: "Trailer",
        official: false
      ),
      decodeVideo(
        id: "official-teaser",
        key: "teaser-key",
        site: "YouTube",
        type: "Teaser",
        official: true
      ),
      decodeVideo(
        id: "official-vimeo-trailer",
        key: "vimeo-key",
        site: "Vimeo",
        type: "Trailer",
        official: true
      ),
      decodeVideo(
        id: "supported-trailer",
        key: "supported-key",
        site: "YouTube",
        type: "Trailer",
        official: true
      ),
    ]

    let selectedURL = videos.lazy.compactMap(\.supportedOfficialTrailerURL).first

    XCTAssertEqual(
      selectedURL?.absoluteString,
      "https://www.youtube.com/watch?v=supported-key"
    )
    XCTAssertNil(
      videos.dropLast().lazy.compactMap(\.supportedOfficialTrailerURL).first,
      "Unsupported videos must not become a fallback trailer"
    )
  }

  @MainActor
  func testViewModelLoadSkipsUnsupportedVideosAndHasNoFallback() async throws {
    let selectedURL = try await loadTrailerURL(
      videos: [
        videoFixture(
          id: "unsupported-ranked-first",
          key: "vimeo-key",
          site: "Vimeo",
          type: "Trailer",
          official: true
        ),
        videoFixture(
          id: "supported-case-insensitive",
          key: "supported-key",
          site: "yOuTuBe",
          type: "tRaIlEr",
          official: true
        ),
      ]
    )

    XCTAssertEqual(
      selectedURL?.absoluteString,
      "https://www.youtube.com/watch?v=supported-key"
    )

    let unsupportedOnlyURL = try await loadTrailerURL(
      videos: [
        videoFixture(
          id: "official-teaser",
          key: "teaser-key",
          site: "YouTube",
          type: "Teaser",
          official: true
        ),
        videoFixture(
          id: "unofficial-clip",
          key: "clip-key",
          site: "YouTube",
          type: "Clip",
          official: false
        ),
      ]
    )

    XCTAssertNil(unsupportedOnlyURL)
  }

  @MainActor
  private func loadTrailerURL(videos: [[String: Any]]) async throws -> URL? {
    let videoResponse = try JSONSerialization.data(withJSONObject: ["results": videos])
    TrailerPolicyStubURLProtocol.handler = { request in
      let payload: Data
      switch request.url?.path {
      case let path? where path.hasSuffix("/external_ids"):
        payload = Data(#"{}"#.utf8)
      case let path? where path.hasSuffix("/credits"):
        payload = Data(#"{"cast":[],"crew":[]}"#.utf8)
      case let path? where path.hasSuffix("/videos"):
        payload = videoResponse
      case let path? where path.hasSuffix("/recommendations") || path.hasSuffix("/similar"):
        payload = Data(#"{"page":1,"results":[]}"#.utf8)
      case let path? where path.hasSuffix("/watch/providers"):
        payload = Data(#"{"id":700,"results":{}}"#.utf8)
      case let path? where path.hasSuffix("/release_dates"):
        payload = Data(#"{"results":[]}"#.utf8)
      default:
        payload = Data(#"{"id":700,"title":"Trailer Test","genre_ids":[]}"#.utf8)
      }

      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
      )!
      return (response, payload)
    }
    defer { TrailerPolicyStubURLProtocol.handler = nil }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [TrailerPolicyStubURLProtocol.self]
    let tmdb = TMDBAPIClient(
      session: URLSession(configuration: configuration),
      readAccessToken: "test-token"
    )
    let viewModel = MediaDetailsViewModel(
      item: MediaItem(
        id: "tmdb-movie-700",
        tmdbID: 700,
        imdbID: nil,
        kind: .movie,
        title: "Trailer Test",
        subtitle: nil,
        overview: nil,
        posterURL: nil,
        backdropURL: nil,
        releaseYear: nil,
        genreIDs: [],
        rating: nil,
        progress: nil,
        rank: nil,
        providerName: nil
      ),
      tmdb: tmdb,
      addonRepository: TrailerPolicyAddonProvider()
    )

    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let session = TraktSession()
    let traktRepository = TraktLibraryRepository(
      session: session,
      cache: TraktLibraryCache(fileURL: temporaryDirectory.appendingPathComponent("cache.json")),
      queue: TraktMutationQueue(fileURL: temporaryDirectory.appendingPathComponent("queue.json"))
    )

    await viewModel.load(
      language: "en",
      region: "US",
      addonManifestURLs: [],
      traktRepository: traktRepository
    )
    return viewModel.trailerURL
  }

  private func videoFixture(
    id: String,
    key: String,
    site: String,
    type: String,
    official: Bool
  ) -> [String: Any] {
    [
      "id": id,
      "key": key,
      "name": id,
      "site": site,
      "type": type,
      "official": official,
    ]
  }

  private func decodeVideo(
    id: String,
    key: String,
    site: String,
    type: String,
    official: Bool?
  ) throws -> TMDBVideo {
    var fixture: [String: Any] = [
      "id": id,
      "key": key,
      "name": id,
      "site": site,
      "type": type,
    ]
    if let official {
      fixture["official"] = official
    }

    let data = try JSONSerialization.data(withJSONObject: fixture)
    return try JSONDecoder().decode(TMDBVideo.self, from: data)
  }
}

private actor TrailerPolicyAddonProvider: AddonContentProviding {
  func installedAddons(urlStrings: [String]) async -> [InstalledAddonDescriptor] { [] }
  func search(query: String, kind: MediaKind?, urlStrings: [String]) async -> [AddonMetaPreview] {
    []
  }
  func metadata(type: String, id: String, urlStrings: [String]) async -> [AddonMetaDetail] { [] }
  func streams(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonStream] { [] }
  func subtitles(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonSubtitle] {
    []
  }
}

private final class TrailerPolicyStubURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler:
    (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
