# Immersive Trending Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single static onboarding composition with the approved Palco imersivo, enriched by stable TMDB trending backdrops while remaining immediate, offline-safe, silent, and accessible.

**Architecture:** A repository converts existing TMDB trending results into two small presentation items and persists metadata through a bounded cache. A view model prefetches image pixels before publishing them, while a focused SwiftUI backdrop component owns only motion and accessibility.

**Tech Stack:** Swift 6, SwiftUI, URLSession/TMDB client, UserDefaults, ImagePipeline, XCTest, String Catalogs.

---

Repository policy prohibits agent-executed Git commands. Manual checkpoints name the suggested user commit.

## File map

- Create `VelyraTV/Features/Onboarding/OnboardingMediaModels.swift`: media item, snapshot, and protocol contracts.
- Create `VelyraTV/Features/Onboarding/OnboardingMediaCache.swift`: six-hour fresh and seven-day stale metadata cache.
- Create `VelyraTV/Features/Onboarding/TMDBOnboardingMediaRepository.swift`: trending fetch, interleave, and stable selection.
- Create `VelyraTV/Features/Onboarding/OnboardingMediaViewModel.swift`: loading and image-prefetch state.
- Create `VelyraTV/Features/Onboarding/ImmersiveOnboardingBackdropView.swift`: fallback, two-sided artwork, and native motion.
- Create `VelyraTV/Features/Onboarding/VelyraBrandMark.swift`: reusable mark and wordmark presentation.
- Create `VelyraTVTests/Features/Onboarding/OnboardingMediaCacheTests.swift`: cache lifetime and corruption tests.
- Create `VelyraTVTests/Features/Onboarding/TMDBOnboardingMediaRepositoryTests.swift`: interleave, fallback, and daily stability tests.
- Create `VelyraTVTests/Features/Onboarding/OnboardingMediaViewModelTests.swift`: publish-after-prefetch behavior.
- Create `VelyraTVTests/Core/Metadata/TMDBTrailerPolicyTests.swift`: explicit official-trailer filtering.
- Modify `VelyraTV/Features/Onboarding/OnboardingView.swift`: two-stage Palco imersivo UI.
- Modify `VelyraTV/Core/Metadata/TMDBModels.swift`: supported trailer policy.
- Modify `VelyraTV/Features/Details/MediaDetailsViewModel.swift`: select only supported official trailers.
- Modify `VelyraTV/Features/Details/MediaDetailsView.swift`: recoverable external-open failure.
- Modify `VelyraTV/Resources/Localizable.xcstrings`: onboarding and trailer failure strings.
- Modify `docs/data-sources.md`, `docs/home-discovery.md`, and `docs/release-readiness.md`: behavior and attribution.

### Task 1: Define presentation and provider contracts

**Files:**
- Create: `VelyraTV/Features/Onboarding/OnboardingMediaModels.swift`
- Create: `VelyraTVTests/Features/Onboarding/TMDBOnboardingMediaRepositoryTests.swift`

- [ ] **Step 1: Write a decoding helper and interleave expectation**

Start the test file with:

```swift
import XCTest

@testable import VelyraTV

final class TMDBOnboardingMediaRepositoryTests: XCTestCase {
  func testInterleaveAlternatesSeriesAndMoviesAndExcludesMissingBackdrops() throws {
    let series = [
      try decodeResult(id: 1, title: "Series One", backdrop: "/series-1.jpg"),
      try decodeResult(id: 2, title: "Series Two", backdrop: nil),
      try decodeResult(id: 3, title: "Series Three", backdrop: "/series-3.jpg"),
    ]
    let movies = [
      try decodeResult(id: 10, title: "Movie One", backdrop: "/movie-1.jpg"),
      try decodeResult(id: 11, title: "Movie Two", backdrop: "/movie-2.jpg"),
    ]

    let values = TMDBOnboardingMediaRepository.interleave(series: series, movies: movies)

    XCTAssertEqual(values.map(\.id), ["tmdb-series-1", "tmdb-movie-10", "tmdb-series-3", "tmdb-movie-11"])
  }

  private func decodeResult(id: Int, title: String, backdrop: String?) throws -> TMDBMediaResult {
    var object: [String: Any] = [
      "id": id,
      "name": title,
      "title": title,
      "genre_ids": [],
    ]
    object["backdrop_path"] = backdrop ?? NSNull()
    return try JSONDecoder().decode(
      TMDBMediaResult.self,
      from: JSONSerialization.data(withJSONObject: object)
    )
  }
}
```

- [ ] **Step 2: Run the focused test and observe the missing repository**

Expected: compilation fails because `TMDBOnboardingMediaRepository` is undefined.

- [ ] **Step 3: Add the presentation types**

```swift
import Foundation

struct OnboardingMediaItem: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let kind: MediaKind
  let title: String
  let backdropURL: URL
}

struct OnboardingMediaSnapshot: Codable, Equatable, Sendable {
  let language: String
  let region: String
  let selectedDay: String
  let loadedAt: Date
  let items: [OnboardingMediaItem]
}

protocol OnboardingMediaProviding: Sendable {
  func media(language: String, region: String) async -> [OnboardingMediaItem]
}

protocol TrendingMediaProviding: Sendable {
  func trending(kind: MediaKind, timeWindow: String, language: String) async throws
    -> [TMDBMediaResult]
}

extension TMDBAPIClient: TrendingMediaProviding {}
```

- [ ] **Step 4: Add pure interleaving**

Create `TMDBOnboardingMediaRepository` with a static `interleave(series:movies:)` that filters missing `backdropPath`, alternates series then movie, converts URLs with `TMDBConfiguration.imageURL(path:width: "original")`, and stops only after both arrays are exhausted.

- [ ] **Step 5: Run the focused test**

Expected: PASS with the exact alternating identifiers.

- [ ] **Step 6: Manual Git checkpoint**

Ask the user to commit with `feat: define onboarding media contracts`.

### Task 2: Add the bounded metadata cache

**Files:**
- Create: `VelyraTV/Features/Onboarding/OnboardingMediaCache.swift`
- Create: `VelyraTVTests/Features/Onboarding/OnboardingMediaCacheTests.swift`

- [ ] **Step 1: Write fresh, stale, expired, and corrupt tests**

Use fixed `Date(timeIntervalSince1970: 1_700_000_000)`, a unique UserDefaults suite per test, and a two-item snapshot. Assert:

- age 5 hours returns `.fresh(snapshot)`;
- age 2 days returns `.stale(snapshot)`;
- age 8 days returns `.missing` and deletes the key;
- invalid JSON returns `.missing` and deletes the key;
- language or region mismatch returns `.missing` without using another locale's selection.

- [ ] **Step 2: Run the tests and verify the missing cache type**

Expected: compilation fails because `OnboardingMediaCache` is undefined.

- [ ] **Step 3: Implement cache state and actor**

```swift
enum OnboardingMediaCacheState: Equatable, Sendable {
  case fresh(OnboardingMediaSnapshot)
  case stale(OnboardingMediaSnapshot)
  case missing
}

actor OnboardingMediaCache {
  static let storageKey = "velyra.onboarding-media.v1"
  static let freshLifetime: TimeInterval = 6 * 60 * 60
  static let staleLifetime: TimeInterval = 7 * 24 * 60 * 60

  private let defaults: UserDefaults
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601
  }

  func load(language: String, region: String, now: Date) -> OnboardingMediaCacheState {
    guard let data = defaults.data(forKey: Self.storageKey),
      let value = try? decoder.decode(OnboardingMediaSnapshot.self, from: data)
    else {
      defaults.removeObject(forKey: Self.storageKey)
      return .missing
    }
    guard value.language == language, value.region == region else { return .missing }
    let age = max(0, now.timeIntervalSince(value.loadedAt))
    if age <= Self.freshLifetime { return .fresh(value) }
    if age <= Self.staleLifetime { return .stale(value) }
    defaults.removeObject(forKey: Self.storageKey)
    return .missing
  }

  func save(_ snapshot: OnboardingMediaSnapshot) {
    guard let data = try? encoder.encode(snapshot) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  func clear() { defaults.removeObject(forKey: Self.storageKey) }
}
```

- [ ] **Step 4: Run all cache tests**

Expected: every lifetime and corruption case PASS.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `feat: cache onboarding trend metadata`.

### Task 3: Fetch and select stable daily trends

**Files:**
- Modify: `VelyraTV/Features/Onboarding/TMDBOnboardingMediaRepository.swift`
- Modify: `VelyraTVTests/Features/Onboarding/TMDBOnboardingMediaRepositoryTests.swift`

- [ ] **Step 1: Add repository behavior tests**

Create a `StubTrendingProvider` actor keyed by `MediaKind` and add tests proving:

- a fresh cache returns without calling the provider;
- a successful refresh returns exactly two items and saves them;
- one failed endpoint still returns two items from the other endpoint when available;
- both failures return the stale cache;
- both failures with no cache return an empty array;
- the same UTC day/language/region produces the same two IDs;
- changing the UTC day rotates the starting point deterministically.

- [ ] **Step 2: Run tests and observe behavior failures**

Expected: new tests fail because the repository has only pure interleaving.

- [ ] **Step 3: Implement deterministic hashing**

```swift
static func stableIndex(for value: String, count: Int) -> Int {
  guard count > 0 else { return 0 }
  let hash = value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
    ($0 ^ UInt64($1)) &* 1_099_511_628_211
  }
  return Int(hash % UInt64(count))
}
```

Use an injected UTC Gregorian calendar and format `yyyy-MM-dd`. Seed with `day|language|region` and rotate the interleaved candidates before taking two.

- [ ] **Step 4: Implement repository dependencies and flow**

```swift
actor TMDBOnboardingMediaRepository: OnboardingMediaProviding {
  private let provider: any TrendingMediaProviding
  private let cache: OnboardingMediaCache
  private let now: @Sendable () -> Date

  init(
    provider: any TrendingMediaProviding = TMDBAPIClient.shared,
    cache: OnboardingMediaCache = OnboardingMediaCache(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.provider = provider
    self.cache = cache
    self.now = now
  }

  func media(language: String, region: String) async -> [OnboardingMediaItem] {
    let date = now()
    let cached = await cache.load(language: language, region: region, now: date)
    if case .fresh(let snapshot) = cached { return snapshot.items }

    async let seriesRequest = provider.trending(
      kind: .series, timeWindow: "day", language: language)
    async let moviesRequest = provider.trending(
      kind: .movie, timeWindow: "day", language: language)
    let series = (try? await seriesRequest) ?? []
    let movies = (try? await moviesRequest) ?? []
    let candidates = Self.interleave(series: series, movies: movies)

    guard !candidates.isEmpty else {
      if case .stale(let snapshot) = cached { return snapshot.items }
      return []
    }
    let selected = Self.dailySelection(candidates, language: language, region: region, date: date)
    let snapshot = OnboardingMediaSnapshot(
      language: language,
      region: region,
      selectedDay: Self.dayString(date),
      loadedAt: date,
      items: selected
    )
    await cache.save(snapshot)
    return selected
  }
}
```

- [ ] **Step 5: Run repository and cache tests**

Expected: all tests PASS without timing sleeps or real network calls.

- [ ] **Step 6: Manual Git checkpoint**

Ask the user to commit with `feat: select stable daily onboarding trends`.

### Task 4: Publish artwork only after prefetch

**Files:**
- Create: `VelyraTV/Features/Onboarding/OnboardingMediaViewModel.swift`
- Create: `VelyraTVTests/Features/Onboarding/OnboardingMediaViewModelTests.swift`

- [ ] **Step 1: Define an image-prefetch seam and failing tests**

```swift
protocol OnboardingImagePrefetching: Sendable {
  func prefetch(_ url: URL) async -> Bool
}

struct DefaultOnboardingImagePrefetcher: OnboardingImagePrefetching {
  func prefetch(_ url: URL) async -> Bool {
    (try? await ImagePipeline.shared.image(
      for: url,
      targetSize: CGSize(width: 1_920, height: 1_080)
    )) != nil
  }
}
```

Test that the view model starts with `items == []`, publishes only successful-prefetch items, retains the fallback when every prefetch fails, and ignores the result of a cancelled previous load.

- [ ] **Step 2: Run tests and verify the missing view model**

Expected: compilation fails because `OnboardingMediaViewModel` is undefined.

- [ ] **Step 3: Implement the main-actor view model**

```swift
@MainActor
final class OnboardingMediaViewModel: ObservableObject {
  @Published private(set) var items: [OnboardingMediaItem] = []

  private let repository: any OnboardingMediaProviding
  private let prefetcher: any OnboardingImagePrefetching
  private var task: Task<Void, Never>?

  init(
    repository: any OnboardingMediaProviding = TMDBOnboardingMediaRepository(),
    prefetcher: any OnboardingImagePrefetching = DefaultOnboardingImagePrefetcher()
  ) {
    self.repository = repository
    self.prefetcher = prefetcher
  }

  deinit { task?.cancel() }

  func load(language: String, region: String) {
    task?.cancel()
    task = Task { [weak self, repository, prefetcher] in
      let candidates = await repository.media(language: language, region: region)
      var ready: [OnboardingMediaItem] = []
      for item in candidates where !Task.isCancelled {
        if await prefetcher.prefetch(item.backdropURL) { ready.append(item) }
      }
      guard !Task.isCancelled else { return }
      self?.items = Array(ready.prefix(2))
    }
  }
}
```

- [ ] **Step 4: Run focused tests and formatter**

Expected: tests PASS and formatter exits 0.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `feat: prefetch onboarding artwork`.

### Task 5: Build the Palco imersivo rendering components

**Files:**
- Create: `VelyraTV/Features/Onboarding/VelyraBrandMark.swift`
- Create: `VelyraTV/Features/Onboarding/ImmersiveOnboardingBackdropView.swift`

- [ ] **Step 1: Create the accessible brand component**

Render `Image("VelyraMark")` above `Text("VELYRA")`; give the combined element accessibility label `Velyra`, hide the decorative image from VoiceOver, and keep the wordmark as real text with tracking.

- [ ] **Step 2: Create the fallback-first backdrop**

Start with `Image("OnboardingFallback")` aspect-filled edge to edge. Overlay remote images only when provided, putting item zero on the left and item one on the right with independent masks that preserve the center copy area.

- [ ] **Step 3: Add restrained native motion**

Use one `@State` boolean and a 16-second autoreversing ease-in-out animation. Scale left from 1.03 to 1.08 and right from 1.08 to 1.03 while translating no more than 36 points. Crossfade loaded items once; do not create a recurring carousel.

- [ ] **Step 4: Enforce accessibility environment behavior**

When `accessibilityReduceMotion` is true, remove all animation and show the first ready image as a static layer. When `accessibilityReduceTransparency` is true, increase the black center overlay to at least 0.78. Mark the entire backdrop `accessibilityHidden(true)`.

- [ ] **Step 5: Compile the components**

Run an unsigned simulator build. Expected: BUILD SUCCEEDED with no sendability or main-actor diagnostics.

- [ ] **Step 6: Manual Git checkpoint**

Ask the user to commit with `feat: add immersive onboarding backdrop`.

### Task 6: Convert onboarding to two stages

**Files:**
- Modify: `VelyraTV/Features/Onboarding/OnboardingView.swift`
- Modify: `VelyraTV/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add explicit stage state**

```swift
private enum Stage: Equatable { case welcome, setup }
@State private var stage: Stage = .welcome
@StateObject private var media = OnboardingMediaViewModel()
```

- [ ] **Step 2: Render the approved welcome stage**

Center `VelyraBrandMark`, localized eyebrow, title, body, and a prominent continue button between the two artwork regions. The button changes `stage = .setup`; it does not complete onboarding.

- [ ] **Step 3: Reuse current setup and Trakt behavior**

Move `automaticSetupSummary`, `traktArea`, and the existing final actions into the setup stage. Preserve `applyAutomaticSetupAndFinish()` and Trakt device authorization behavior. Add a secondary Back action that returns to `.welcome` and restores focus to Continue.

- [ ] **Step 4: Load media by current language and region**

In `.task(id:)`, call `media.load(language:region:)` using `appState.preferences.language.locale?.identifier ?? Locale.current.identifier` and `contentRegion ?? Locale.current.region?.identifier ?? "PT"`.

- [ ] **Step 5: Add localized strings in four locales**

Add these exact values:

| Key | English | Portuguese (Portugal) | Spanish | French |
| --- | --- | --- | --- | --- |
| `onboarding.immersive.eyebrow` | Your Apple TV. Your cinema. | A tua Apple TV. O teu cinema. | Tu Apple TV. Tu cine. | Votre Apple TV. Votre cinéma. |
| `onboarding.immersive.title` | Cinema finds you. | O cinema encontra-te. | El cine te encuentra. | Le cinéma vient à vous. |
| `onboarding.immersive.body` | Velyra prepares source, original audio, and regional subtitles while current stories shape the atmosphere. | A Velyra prepara a fonte, o áudio original e as legendas regionais enquanto as histórias do momento dão vida ao ambiente. | Velyra prepara la fuente, el audio original y los subtítulos regionales mientras las historias del momento dan vida al ambiente. | Velyra prépare la source, l’audio original et les sous-titres régionaux pendant que les histoires du moment donnent vie à l’ambiance. |
| `onboarding.immersive.continue` | Continue | Continuar | Continuar | Continuer |
| `onboarding.immersive.continue.hint` | Shows your automatic setup choices. | Mostra as tuas escolhas de configuração automática. | Muestra tus opciones de configuración automática. | Affiche vos choix de configuration automatique. |
| `onboarding.immersive.back` | Back to welcome | Voltar às boas-vindas | Volver a la bienvenida | Revenir à l’accueil |
| `onboarding.immersive.back.hint` | Returns to the Velyra welcome screen. | Regressa ao ecrã de boas-vindas da Velyra. | Vuelve a la pantalla de bienvenida de Velyra. | Revient à l’écran d’accueil de Velyra. |

- [ ] **Step 6: Run localization and simulator tests**

Run project validation, formatter lint, all onboarding tests, and a simulator build. Expected: all pass.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `feat: add two-stage immersive onboarding`.

### Task 7: Enforce the official trailer policy

**Files:**
- Modify: `VelyraTV/Core/Metadata/TMDBModels.swift`
- Modify: `VelyraTV/Features/Details/MediaDetailsViewModel.swift`
- Modify: `VelyraTV/Features/Details/MediaDetailsView.swift`
- Create: `VelyraTVTests/Core/Metadata/TMDBTrailerPolicyTests.swift`
- Modify: `VelyraTV/Resources/Localizable.xcstrings`

- [ ] **Step 1: Write trailer filtering tests**

Decode TMDBVideo fixtures and assert that only `official == true`, case-insensitive `type == "Trailer"`, `site == "YouTube"`, and a non-empty key produce a supported URL. Assert teasers, unofficial videos, unknown sites, and empty keys return nil.

- [ ] **Step 2: Run tests and observe current policy failures**

Expected: unofficial and fallback videos currently produce URLs or are selected by the view model.

- [ ] **Step 3: Add the supported trailer property**

```swift
var supportedOfficialTrailerURL: URL? {
  guard official == true,
    type.caseInsensitiveCompare("Trailer") == .orderedSame,
    site.caseInsensitiveCompare("YouTube") == .orderedSame,
    !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  else { return nil }
  return URL(string: "https://www.youtube.com/watch?v=\(key)")
}
```

Keep `externalURL` only if another consumer needs it; otherwise replace it to avoid accidental weak-policy use.

- [ ] **Step 4: Remove fallback selection in Details**

Set:

```swift
trailerURL = bundle.videos.lazy.compactMap(\.supportedOfficialTrailerURL).first
```

- [ ] **Step 5: Report external-open failure**

Add `@State private var trailerOpenFailed = false`. Use the `OpenURLAction` completion to set it when the system rejects the URL and show a localized polite live-region message. The message states that the trailer provider is unavailable on this Apple TV; it never suggests stream extraction.

- [ ] **Step 6: Run trailer and Details tests**

Expected: all policy tests PASS, Details compiles, and no YouTube URL reaches `AVPlayer`.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `fix: require official user-initiated trailers`.

### Task 8: Documentation and phase verification

**Files:**
- Modify: `docs/data-sources.md`
- Modify: `docs/home-discovery.md`
- Modify: `docs/release-readiness.md`

- [ ] **Step 1: Document data ownership and cache policy**

Record TMDB as the source of trending metadata/backdrops, Velyra as the source of original fallback art and motion, six-hour fresh metadata, seven-day decorative stale use, and YouTube as an external user-initiated provider only.

- [ ] **Step 2: Run the complete phase suite fresh**

Run project validation, formatter lint, XcodeGen, all onboarding/cache/trailer tests, the complete XCTest suite, full-target build, sideload build, and IPA packaging on GitHub macOS.

- [ ] **Step 3: Perform accessibility review**

On a physical Apple TV verify focus order and restoration, touch-disabled Siri Remote navigation, external keyboard navigation, VoiceOver reading order, static Reduce Motion rendering, solid Reduce Transparency surfaces, and Increase Contrast focus visibility.

- [ ] **Step 4: Perform network-state review**

Test no TMDB configuration, offline with no cache, fresh cache, stale cache, one failing endpoint, corrupt metadata, and invalid image content. Every case must allow onboarding completion.

- [ ] **Step 5: Request review**

Provide test output and screenshots of both stages plus Reduce Motion. Suggest `feat: complete immersive trending onboarding` for a user-managed squash commit.
