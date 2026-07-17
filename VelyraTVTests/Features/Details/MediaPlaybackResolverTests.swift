import XCTest

@testable import VelyraTV

final class MediaPlaybackResolverTests: XCTestCase {
  func testBuildsPlaybackRequestFromAddonStreamsAndSubtitles() async throws {
    let streamURL = try XCTUnwrap(URL(string: "https://example.com/video/master.m3u8"))
    let subtitleURL = try XCTUnwrap(URL(string: "https://example.com/subtitles/pt.vtt"))
    let provider = FakeAddonContentProvider(
      streams: [
        ResolvedAddonStream(
          addonName: "Example",
          stream: AddonStream(
            name: "4K",
            title: "4K Dolby Vision Atmos Cached",
            url: streamURL,
            externalURL: nil,
            infoHash: nil,
            fileIdx: nil,
            behaviorHints: nil
          )
        )
      ],
      subtitles: [
        ResolvedAddonSubtitle(
          addonName: "Example",
          subtitle: AddonSubtitle(idValue: "pt", url: subtitleURL, lang: "pt-PT")
        )
      ]
    )

    let item = MediaItem(
      id: "movie",
      tmdbID: 1,
      imdbID: "tt0000001",
      kind: .movie,
      title: "Movie",
      subtitle: nil,
      overview: nil,
      posterURL: nil,
      backdropURL: nil,
      releaseYear: 2026,
      genreIDs: [],
      rating: nil,
      progress: nil,
      rank: nil,
      providerName: nil
    )

    let request = try await MediaPlaybackResolver(repository: provider).resolve(
      item: item,
      originalLanguageCode: "en",
      addonManifestURLs: ["https://example.com/manifest.json"]
    )

    XCTAssertEqual(request.sources.count, 1)
    XCTAssertEqual(request.sources[0].container, .hls)
    XCTAssertEqual(request.externalSubtitles.first?.languageCode, "pt-PT")
    XCTAssertEqual(request.originalLanguageCode, "en")
  }

  func testRequiresAnInstalledAddon() async throws {
    let resolver = MediaPlaybackResolver(repository: FakeAddonContentProvider())
    let item = MediaItem.previewHero

    do {
      _ = try await resolver.resolve(
        item: item,
        originalLanguageCode: nil,
        addonManifestURLs: []
      )
      XCTFail("Expected noAddons")
    } catch MediaPlaybackResolver.ResolutionError.noAddons {
      XCTAssertTrue(true)
    }
  }
}

private actor FakeAddonContentProvider: AddonContentProviding {
  let streamsValue: [ResolvedAddonStream]
  let subtitlesValue: [ResolvedAddonSubtitle]

  init(
    streams: [ResolvedAddonStream] = [],
    subtitles: [ResolvedAddonSubtitle] = []
  ) {
    streamsValue = streams
    subtitlesValue = subtitles
  }

  func installedAddons(urlStrings: [String]) async -> [InstalledAddonDescriptor] { [] }
  func search(query: String, kind: MediaKind?, urlStrings: [String]) async -> [AddonMetaPreview] {
    []
  }
  func metadata(type: String, id: String, urlStrings: [String]) async -> [AddonMetaDetail] { [] }
  func streams(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonStream] {
    streamsValue
  }
  func subtitles(type: String, id: String, urlStrings: [String]) async -> [ResolvedAddonSubtitle] {
    subtitlesValue
  }
}
