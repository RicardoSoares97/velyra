# Apple-Native Experience Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a cleaner Apple TV-style Velyra interface with reliable focus feedback, category-based Settings, one-screen onboarding, a silent Ribbon Strike launch ident, useful Top Shelf content, safe read-only Stremio addon import, and smoother rendering/persistence.

**Architecture:** Keep the existing SwiftUI/AppState/repository boundaries. Introduce small pure policy types for focus, settings, launch, Top Shelf, and Stremio normalization so deterministic behavior is unit tested. Use native adaptable tab navigation on tvOS 18+ with an editorial rail fallback on tvOS 17, keep Stremio credentials memory-only behind an injected service, and coalesce preference writes without delaying visible state.

**Tech Stack:** Swift 6, SwiftUI, tvOS 17+, TVServices, Foundation/URLSession, XCTest, XcodeGen, String Catalogs.

---

This plan implements
[`2026-07-17-apple-native-experience-refresh-design.md`](../specs/2026-07-17-apple-native-experience-refresh-design.md).
It is intentionally Git-neutral because repository instructions prohibit Git
operations without explicit authorization.

## Task 1: Establish settings and Home display-name models

**Files:**

- Create: `VelyraTV/Features/Settings/SettingsCategory.swift`
- Modify: `VelyraTV/Core/Persistence/AppPreferences.swift`
- Test: `VelyraTVTests/Features/Settings/SettingsCategoryTests.swift`

- [ ] **Step 1: Write the failing settings-category tests**

Create `SettingsCategoryTests.swift`:

```swift
import XCTest
@testable import VelyraTV

final class SettingsCategoryTests: XCTestCase {
  func testCategoryCentreHasStableProductOrder() {
    XCTAssertEqual(
      SettingsCategory.allCases,
      [
        .appearance,
        .experience,
        .playback,
        .audioSubtitles,
        .homeSearch,
        .accountsSync,
        .storageDiagnostics,
        .about,
      ]
    )
  }

  func testEveryCategoryHasLocalizedKeysAndSymbol() {
    for category in SettingsCategory.allCases {
      XCTAssertTrue(category.titleKey.hasPrefix("settings.category."))
      XCTAssertTrue(category.summaryKey.hasPrefix("settings.category."))
      XCTAssertFalse(category.systemImage.isEmpty)
    }
  }

  func testHomeSectionsExposeDisplayKeysInsteadOfRawIdentifiers() {
    XCTAssertEqual(
      HomeSectionPreference.allCases.map(\.displayNameKey),
      [
        "home.continueWatching",
        "home.trendingSeries",
        "home.trendingMovies",
        "home.topSeries",
        "home.topMovies",
        "home.genres",
        "home.providers",
        "home.providerCollections",
      ]
    )
  }
}
```

- [ ] **Step 2: Run the test and verify the red state**

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:VelyraTVTests/SettingsCategoryTests test CODE_SIGNING_ALLOWED=NO
```

Expected: compile failure because `SettingsCategory` and
`HomeSectionPreference.displayNameKey` do not exist.

- [ ] **Step 3: Add the category model**

Implement `SettingsCategory` as `String`, `CaseIterable`, `Identifiable`, and
`Hashable`. Use these exact cases and mappings:

```swift
import Foundation

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
  case appearance
  case experience
  case playback
  case audioSubtitles
  case homeSearch
  case accountsSync
  case storageDiagnostics
  case about

  var id: String { rawValue }
  var titleKey: String { "settings.category.\(rawValue).title" }
  var summaryKey: String { "settings.category.\(rawValue).summary" }

  var systemImage: String {
    switch self {
    case .appearance: "circle.lefthalf.filled"
    case .experience: "sparkles.tv"
    case .playback: "play.rectangle.on.rectangle"
    case .audioSubtitles: "captions.bubble.fill"
    case .homeSearch: "rectangle.stack.badge.play"
    case .accountsSync: "person.2.badge.gearshape"
    case .storageDiagnostics: "externaldrive.badge.checkmark"
    case .about: "info.circle.fill"
    }
  }
}
```

- [ ] **Step 4: Add explicit Home section display keys**

Add a switch-based `displayNameKey` to `HomeSectionPreference`. Do not derive
these strings from `rawValue`; the explicit mapping prevents raw localization
keys from leaking into the UI.

- [ ] **Step 5: Regenerate the project and verify green**

```bash
xcodegen generate
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:VelyraTVTests/SettingsCategoryTests test CODE_SIGNING_ALLOWED=NO
```

Expected: `SettingsCategoryTests` passes.

## Task 2: Make focus, press, and disabled presentation explicit

**Files:**

- Create: `VelyraTV/Core/DesignSystem/VelyraControlVisualState.swift`
- Modify: `VelyraTV/Core/DesignSystem/VelyraGlass.swift`
- Test: `VelyraTVTests/Core/DesignSystem/VelyraControlVisualStateTests.swift`

- [ ] **Step 1: Write the failing visual-state tests**

```swift
import XCTest
@testable import VelyraTV

final class VelyraControlVisualStateTests: XCTestCase {
  func testDisabledWinsOverFocusAndPress() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(isEnabled: false, isFocused: true, isPressed: true),
      .disabled
    )
  }

  func testPressedWinsOverFocus() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(isEnabled: true, isFocused: true, isPressed: true),
      .pressed
    )
  }

  func testFocusAndNormalAreDistinct() {
    XCTAssertEqual(
      VelyraControlVisualState.resolve(isEnabled: true, isFocused: true, isPressed: false),
      .focused
    )
    XCTAssertEqual(
      VelyraControlVisualState.resolve(isEnabled: true, isFocused: false, isPressed: false),
      .normal
    )
  }

  func testReduceMotionRemovesFocusScaleButKeepsHighlight() {
    XCTAssertEqual(VelyraControlVisualState.focused.scale(reduceMotion: true), 1)
    XCTAssertEqual(VelyraControlVisualState.focused.scale(reduceMotion: false), 1.055)
    XCTAssertTrue(VelyraControlVisualState.focused.showsHighlight)
  }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Use the Task 1 `xcodebuild` command with
`-only-testing:VelyraTVTests/VelyraControlVisualStateTests`.

- [ ] **Step 3: Implement the pure resolver**

Create an internal enum with `.normal`, `.focused`, `.pressed`, `.disabled`,
the precedence tested above, `showsHighlight`, `opacity`, and
`scale(reduceMotion:)`. Use scales `1`, `1.055`, `0.985`, and `1` respectively.

- [ ] **Step 4: Drive the glass button style from real focus state**

In `VelyraGlassButtonStyle`:

- read `isFocused`, `isEnabled`, Reduce Motion, and Increase Contrast from the
  environment;
- resolve the four-state enum once inside `makeBody`;
- keep orange as selection/prominence, not the only focus cue;
- add a shape-matched white outline and elevation for `.focused`;
- use solid fallback surfaces through the existing `velyraGlass` modifier;
- animate only scale, shadow, and highlight over 120 ms when Reduce Motion is
  off;
- preserve focus feedback under Reduce Motion by keeping outline/elevation;
- set disabled opacity from the resolver and ensure `.disabled` controls cannot
  receive focus through SwiftUI's existing `disabled` behavior.

- [ ] **Step 5: Run the resolver tests and the existing button-related static checks**

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:VelyraTVTests/VelyraControlVisualStateTests test CODE_SIGNING_ALLOWED=NO
scripts/ci_validate_tvos.sh --static
```

Expected: tests and static validation pass.

## Task 3: Replace the oversized menu with native adaptable tab navigation

**Files:**

- Modify: `VelyraTV/Features/Shell/AppSection.swift`
- Rewrite: `VelyraTV/Features/Shell/AppShellView.swift`
- Create: `VelyraTV/Features/Shell/LegacyEditorialRail.swift`
- Test: `VelyraTVTests/Features/Shell/AppSectionTests.swift`

- [ ] **Step 1: Write tests for stable tab identity and navigation metadata**

Test that all five cases remain in the current order, raw values are unique,
symbols are nonempty, and title keys equal:

```swift
[
  "navigation.home",
  "navigation.search",
  "navigation.library",
  "navigation.addons",
  "navigation.settings",
]
```

- [ ] **Step 2: Run the focused test and record green baseline**

The test should pass for existing metadata. This is a characterization test,
not the red step for the UI rewrite.

- [ ] **Step 3: Build one reusable tab content declaration**

Use `TabView(selection:)` with the current five destinations, `.tag(section)`,
`Label` tab items, and the existing `@SceneStorage` raw value. Do not create a
second copy of each destination for the availability branch.

For tvOS 18 and later, apply:

```swift
.tabViewStyle(.sidebarAdaptable)
```

Keep `AppShellView` responsible for the offline badge and deep-linked details
cover. Remove the floating capsule navigation bar entirely.

- [ ] **Step 4: Add the tvOS 17 editorial fallback**

`LegacyEditorialRail` must:

- render a 96-point collapsed leading rail;
- expand to 320 points only while one of its destination buttons has focus;
- use one opaque/material navigation surface, not nested glass;
- expose icon-only labels when collapsed and icon plus title when expanded;
- keep selected state distinct from focused state;
- reserve safe-area space so the rail never covers content;
- restore the selected destination from `SceneStorage`;
- let Menu/Back leave a detail/modal before affecting top-level navigation.

Use the shared `VelyraGlassButtonStyle` and `VelyraControlVisualState`; do not
reimplement scale/outline logic locally.

- [ ] **Step 5: Regenerate and build both deployment paths**

```bash
xcodegen generate
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:VelyraTVTests/AppSectionTests test CODE_SIGNING_ALLOWED=NO
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'generic/platform=tvOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Expected: tvOS 17 deployment compiles and the SDK availability guard accepts
the tvOS 18 style.

## Task 4: Add the one-shot Ribbon Strike launch ident

**Files:**

- Create: `VelyraTV/App/LaunchIdentPolicy.swift`
- Create: `VelyraTV/App/RibbonStrikeView.swift`
- Modify: `VelyraTV/App/RootView.swift`
- Test: `VelyraTVTests/App/LaunchIdentPolicyTests.swift`

- [ ] **Step 1: Write failing launch-policy tests**

```swift
import XCTest
@testable import VelyraTV

final class LaunchIdentPolicyTests: XCTestCase {
  func testColdLaunchShowsFullIdentOnce() {
    var policy = LaunchIdentPolicy()
    XCTAssertEqual(policy.consumePresentation(reduceMotion: false), .ribbonStrike)
    XCTAssertNil(policy.consumePresentation(reduceMotion: false))
  }

  func testReduceMotionUsesFadeOnce() {
    var policy = LaunchIdentPolicy()
    XCTAssertEqual(policy.consumePresentation(reduceMotion: true), .fade)
    XCTAssertNil(policy.consumePresentation(reduceMotion: true))
  }
}
```

- [ ] **Step 2: Verify the tests fail because the policy does not exist**

Run the focused test target.

- [ ] **Step 3: Implement a value-type one-shot policy**

Define `LaunchIdentPresentation: Equatable` with `.ribbonStrike` and `.fade`.
`LaunchIdentPolicy` stores a private `hasPresented` flag and returns a
presentation only on its first consumption. It must not inspect scene phase or
network/bootstrap state.

- [ ] **Step 4: Build the silent Ribbon Strike view**

`RibbonStrikeView` receives a presentation and completion closure. It:

- starts on black;
- animates a narrow orange vertical strike into the existing Velyra ribbon
  geometry and wordmark;
- completes in approximately 1.5 seconds;
- has no audio resource or audio API;
- uses only opacity for `.fade`;
- exposes a combined accessibility label of `app.loading`;
- calls completion exactly once even if it disappears early.

Reuse `VelyraBrandMark` and existing assets. Do not create Netflix-like letter
geometry, timing, or sound.

- [ ] **Step 5: Decouple ident timing from bootstrap in Root**

Start bootstrap as the app already does, but gate visible root content with a
process-lifetime `@State` ident policy. The ident and bootstrap run concurrently:
after the ident completes, show the existing loading surface only if bootstrap
is still unfinished. Returning from a modal or scene inactivity must not replay
the ident.

- [ ] **Step 6: Run launch tests and build**

Run `LaunchIdentPolicyTests`, then the generic tvOS Simulator build command from
Task 3.

## Task 5: Reduce onboarding to One Promise

**Files:**

- Rewrite: `VelyraTV/Features/Onboarding/OnboardingView.swift`
- Modify: `VelyraTV/Features/Onboarding/ImmersiveOnboardingBackdropView.swift`
- Modify: `VelyraTV/Features/Onboarding/OnboardingMediaViewModel.swift`
- Test: `VelyraTVTests/Features/Onboarding/OnboardingCompletionTests.swift`
- Modify tests: `VelyraTVTests/Features/Onboarding/OnboardingMediaViewModelTests.swift`

- [ ] **Step 1: Add a failing one-action completion test**

Construct `AppState` with the existing in-memory test stores, call
`applyAutomaticSetupAndFinish()`, and assert that onboarding is complete and
automatic source/language setup is enabled. Reuse the test doubles in
`AppStateDistributionTests` rather than adding a second incompatible store API.

- [ ] **Step 2: Run the test and capture current behavior**

If the domain behavior already passes, retain it as a characterization test and
make the UI structure the red change; no new domain flag is needed.

- [ ] **Step 3: Replace the two-stage onboarding UI**

Render exactly:

- Velyra mark;
- localized welcome eyebrow;
- one product promise;
- one explanatory sentence;
- three assurance labels;
- one prominent Start button;
- one quiet privacy/local-use line.

The Start button calls only `applyAutomaticSetupAndFinish()`. Remove inline
Trakt authentication and all welcome/setup stage state. Trakt remains in
Accounts & Sync.

- [ ] **Step 4: Limit the background to one remote image**

Keep the local fallback immediate. Update the view model and backdrop so a
maximum of one remote backdrop is decoded/rendered. Add a central near-black
legibility gradient and cancel remote work when onboarding disappears.

- [ ] **Step 5: Verify onboarding tests and build**

Run all `Features/Onboarding` tests and the generic Simulator build.

## Task 6: Split Settings into a category centre and focused detail screens

**Files:**

- Rewrite: `VelyraTV/Features/Settings/SettingsView.swift`
- Create: `VelyraTV/Features/Settings/SettingsCategoryTile.swift`
- Create: `VelyraTV/Features/Settings/SettingsDetailView.swift`
- Create: `VelyraTV/Features/Settings/SettingsRows.swift`
- Create: `VelyraTV/Features/Settings/Categories/AppearanceSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/ExperienceSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/PlaybackSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/AudioSubtitlesSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/HomeSearchSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/AccountsSyncSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/StorageDiagnosticsSettingsView.swift`
- Create: `VelyraTV/Features/Settings/Categories/AboutSettingsView.swift`
- Modify: `VelyraTV/Features/Settings/TraktSettingsCard.swift`
- Test: `VelyraTVTests/Features/Settings/HomeSectionPresentationTests.swift`

- [ ] **Step 1: Write a failing Home ordering presentation test**

Create a pure `HomeSectionPresentation` value with `titleKey`, `isVisible`, and
move permissions. Test first/middle/last rows and verify every title comes from
`HomeSectionPreference.displayNameKey`, never from `String(describing:)` or the
raw value.

- [ ] **Step 2: Implement the presentation value and make the test green**

Keep it in `SettingsRows.swift`; it accepts the ordered array, hidden set, and
index. It exposes `canMoveUp` and `canMoveDown` without mutating preferences.

- [ ] **Step 3: Build the category centre**

`SettingsView` becomes a `NavigationStack` with a two-column `LazyVGrid` of the
eight `SettingsCategoryTile` values. Each tile has one title, one two-line
summary, one symbol, a single standard surface, and a visible focus state. No
setting controls are instantiated until its detail destination is active.

- [ ] **Step 4: Build reusable readable rows**

`SettingsRows.swift` contains:

- `SettingsToggleRow`;
- `SettingsValueRow`;
- `SettingsStepperRow`;
- `SettingsPickerLinkRow`;
- `SettingsDestructiveRow`.

Each row has a minimum 84-point height, 24-point internal vertical spacing
between groups, full-width focus feedback, a title width that leaves at least
360 points for the value, and multiline descriptions. Replace wide segmented
pickers with Menu/detail pickers.

- [ ] **Step 5: Move every existing option without changing semantics**

Move the current controls into these categories:

- Appearance: theme, interface language, content region;
- Experience: background video, autoplay preview, blur, overlay;
- Playback: source automation, maximum resolution, direct play, cache,
  Dolby Vision, HDR, Atmos, failover;
- Audio & Subtitles: all language and subtitle controls;
- Home & Search: search history and section visibility/order;
- Accounts & Sync: Trakt and iCloud/local status;
- Storage & Diagnostics: diagnostics report and cache actions;
- About: version, attribution, restart onboarding, reset actions.

Use the existing `AppState.updatePreferences` and reset methods. Do not duplicate
preference state inside category views.

- [ ] **Step 6: Consolidate attribution**

Remove repeated “Data by …”/“Dados de …” provider subtitles. Put localized
TMDB/JustWatch attribution once in About and once in the Home footer. Do not
remove legally required attribution.

- [ ] **Step 7: Verify Settings tests, localization references, and build**

Run `SettingsCategoryTests`, `HomeSectionPresentationTests`,
`scripts/ci_validate_tvos.sh --static`, and the generic Simulator build.

## Task 7: Define secure Stremio import models and normalization

**Files:**

- Create: `VelyraTV/Features/Addons/Stremio/StremioImportModels.swift`
- Create: `VelyraTV/Features/Addons/Stremio/StremioAddonImportPlanner.swift`
- Test: `VelyraTVTests/Features/Addons/StremioAddonImportPlannerTests.swift`

- [ ] **Step 1: Write failing URL normalization tests**

Cover:

- HTTPS URL already ending in `manifest.json`;
- HTTPS transport base with `manifest.json` appended;
- trailing slash without a double slash;
- HTTP remote rejection;
- localhost/loopback rejection even over HTTPS;
- URL without a host rejection;
- URL longer than 2,048 characters rejection;
- case-insensitive duplicate elimination.

Representative assertions:

```swift
XCTAssertEqual(
  StremioAddonImportPlanner.normalizedManifestURL(
    from: "https://example.com/addon"
  )?.absoluteString,
  "https://example.com/addon/manifest.json"
)
XCTAssertNil(
  StremioAddonImportPlanner.normalizedManifestURL(
    from: "http://example.com/manifest.json"
  )
)
XCTAssertNil(
  StremioAddonImportPlanner.normalizedManifestURL(
    from: "https://localhost/addon"
  )
)
```

- [ ] **Step 2: Write failing classification and merge tests**

Model statuses as `.new`, `.installed`, and `.incompatible(reason:)`. Assert:

- an installed normalized URL is `.installed`;
- a validated new URL is `.new`;
- validation failures remain individual incompatible candidates;
- selected new URLs append to existing URLs in candidate order;
- existing URLs are never replaced, removed, or reordered;
- duplicates are never appended.

- [ ] **Step 3: Implement immutable import DTOs**

Define:

- `StremioLinkCode` with `code`, `linkURL`, and `expiresAt`;
- `StremioAddonDescriptor` with embedded `AddonManifest` and `transportURL`;
- `StremioAddonCandidate` with redacted display host, manifest, normalized URL,
  status, and `isSelected`;
- `StremioImportPreview`;
- `StremioImportError` with link, expiry, collection, invalid-response, and
  cleanup-safe cases.

Do not give the auth key a `CustomStringConvertible` conformance. Keep its type
internal and make all diagnostics/error text independent of its value.

- [ ] **Step 4: Implement the pure planner**

Normalization must use `URLComponents`, require `https`, reject user info,
localhost, `127.0.0.1`, `::1`, fragments, oversized input, and malformed hosts.
Append `manifest.json` only when it is not already the last path component.
Deduplicate on a lowercased scheme/host plus standardized path key.

Merge only selected `.new` candidates:

```swift
static func merging(
  existing: [String],
  candidates: [StremioAddonCandidate]
) -> [String]
```

Start with `existing`, retain its order, then append unseen candidate absolute
strings.

- [ ] **Step 5: Run the planner tests**

Run only `StremioAddonImportPlannerTests`; expected green with no networking.

## Task 8: Implement official read-only Stremio linking and guaranteed cleanup

**Files:**

- Create: `VelyraTV/Features/Addons/Stremio/StremioAddonImportService.swift`
- Create: `VelyraTV/Features/Addons/Stremio/StremioImportSession.swift`
- Test: `VelyraTVTests/Features/Addons/StremioAddonImportServiceTests.swift`
- Test: `VelyraTVTests/Features/Addons/StremioImportSessionTests.swift`

- [ ] **Step 1: Write failing request-encoding tests**

Using a recording `HTTPClient`, assert these exact endpoints:

- `GET https://link.stremio.com/api/v2/create?type=Create`;
- `GET https://link.stremio.com/api/v2/read?type=Read&code=<percent-encoded-code>`;
- `POST https://api.strem.io/api/addonCollectionGet`;
- `POST https://api.strem.io/api/logout`.

Assert JSON request bodies:

```json
{"type":"AddonCollectionGet","authKey":"temporary-key","update":true}
```

and:

```json
{"type":"Logout","authKey":"temporary-key"}
```

Also assert:

- `Content-Type: application/json`;
- 15-second request timeout;
- create/read response decoding;
- collection decoding from `[manifest, transportUrl, flags]`;
- malformed envelopes produce `StremioImportError.invalidResponse`;
- no request ever contains `addonCollectionSet`.

- [ ] **Step 2: Implement the injected service**

Define a `StremioAddonImportServing: Sendable` protocol and an actor-backed
implementation using `HTTPClient`. The service exposes only:

```swift
func createLink() async throws -> StremioLinkCode
func readLink(code: String) async throws -> StremioAuthorizationState
func addonCollection(authKey: StremioAuthKey) async throws -> [StremioAddonDescriptor]
func logout(authKey: StremioAuthKey) async throws
```

Do not expose a generic endpoint function to UI code. Do not implement a write
method.

- [ ] **Step 3: Write failing bounded-session tests**

Use a scripted fake service and injected clock/sleeper to assert:

- pending polls wait three seconds;
- authorization stops polling immediately;
- expiry and a 120-second maximum stop the session;
- task cancellation stops polling;
- logout is attempted after success, collection failure, and cancellation once
  an auth key exists;
- the in-memory auth key is cleared even if logout itself fails.

- [ ] **Step 4: Implement the import session**

`StremioImportSession` is an actor/state machine. It owns the auth key, never
publishes it, accepts an injected sleeper, and returns descriptors only after
collection fetch. Use an explicit `do/catch` cleanup path plus cancellation
handler. Cleanup must:

1. move the key into a local variable;
2. nil the stored key before network logout;
3. attempt logout;
4. preserve the original import error if logout also fails.

Bound polling to a three-second interval, link expiry, and 120 seconds. The
screen's disappearance cancels the session task.

- [ ] **Step 5: Run service and session tests**

Run both focused test classes. Inspect recorded requests to confirm the test
suite contains no Stremio write endpoint.

## Task 9: Validate candidates with bounded concurrency and build the import UI

**Files:**

- Create: `VelyraTV/Features/Addons/Stremio/StremioImportViewModel.swift`
- Create: `VelyraTV/Features/Addons/Stremio/StremioImportView.swift`
- Modify: `VelyraTV/Features/Addons/AddonsView.swift`
- Modify: `VelyraTV/Features/Settings/Categories/AccountsSyncSettingsView.swift`
- Modify: `VelyraTV/Features/Addons/AddonClient.swift`
- Test: `VelyraTVTests/Features/Addons/StremioImportViewModelTests.swift`

- [ ] **Step 1: Write failing validation/state-transition tests**

With fake session and fake manifest validator, assert transitions:

```text
idle -> creatingLink -> awaitingAuthorization -> validating -> preview -> importing -> complete
```

Also test retry, empty collection, partial validation, selection toggling,
cancel, and error states. Assert maximum concurrent validations never exceeds
three and duplicate normalized URLs cause only one manifest request.

- [ ] **Step 2: Extract a manifest-validation protocol**

Make `AddonClient` conform to a small `AddonManifestValidating` protocol:

```swift
protocol AddonManifestValidating: Sendable {
  func manifest(from manifestURL: URL) async throws -> AddonManifest
}
```

Do not loosen `AddonClient` URL security. Imported remote URLs have already been
restricted further by the Stremio planner.

- [ ] **Step 3: Implement the main-actor view model**

The view model owns the cancellable task and public privacy-safe UI state. Use a
three-permit async limiter or a fixed worker group, cache results by normalized
URL, and preserve one result per candidate. It receives installed URL strings,
then creates a `StremioImportPreview`.

Its confirm method returns merged URL strings from the pure planner; it does not
write preferences directly.

- [ ] **Step 4: Implement the clean TV import flow**

`StremioImportView` has four visual stages:

1. official link and large short code with Cancel;
2. bounded progress while awaiting authorization;
3. preview list with host, addon name, capability summary, and status;
4. imported count and Done.

Use a single modal surface, readable rows, the shared focus-aware button style,
and no text field for Stremio credentials. Never display the auth key or full
configured URL. Explain that the selected manifests become ordinary Velyra
addons and Stremio is not modified.

- [ ] **Step 5: Integrate from Addons and Accounts & Sync**

Both entry points present the same import view. On confirmation:

- call `appState.updatePreferences`;
- replace only `addonManifestURLs` with the planner's merged result;
- let `normalize()` append new URLs to priority;
- dismiss with a localized count;
- refresh the Addons view model when invoked from Addons.

- [ ] **Step 6: Run Stremio tests and build**

Run all three Stremio test classes, then the generic Simulator build and static
validation.

## Task 10: Coalesce rapid preference writes

**Files:**

- Create: `VelyraTV/Core/Persistence/PreferenceWriteCoordinator.swift`
- Modify: `VelyraTV/App/AppState.swift`
- Test: `VelyraTVTests/Core/Persistence/PreferenceWriteCoordinatorTests.swift`
- Modify: `VelyraTVTests/App/AppStateDistributionTests.swift`

- [ ] **Step 1: Write failing coordinator tests**

Use an injected sleeper and recording async sink. Assert:

- three schedules before the sleeper resumes produce one write;
- the written value is the latest complete `AppPreferences`;
- `flush()` writes immediately and cancels the delayed write;
- `cancel()` drops pending work;
- scheduling after a flush starts a new debounce window.

- [ ] **Step 2: Implement a main-actor coordinator**

Create:

```swift
@MainActor
final class PreferenceWriteCoordinator {
  typealias Sink = @Sendable (AppPreferences) async -> Void
  typealias Sleep = @Sendable (Duration) async throws -> Void

  init(
    delay: Duration = .milliseconds(250),
    sleep: @escaping Sleep = { try await Task.sleep(for: $0) },
    sink: @escaping Sink
  )

  func schedule(_ snapshot: AppPreferences)
  func flush() async
  func cancel()
}
```

Store one pending snapshot and one `Task`. Cancel/reschedule on every rapid
change. Clear pending before invoking the sink so reentrant updates are not
lost.

- [ ] **Step 3: Route AppState preference persistence through it**

Visible `preferences` and `cloudState` mutations remain synchronous. Replace the
per-change unbounded `Task` in `updatePreferences` with `schedule`.

Flush before:

- entering background;
- explicit cloud sync;
- onboarding completion where the app immediately changes root screens;
- destructive reset.

Keep the sink responsible for both `preferencesStore.save(snapshot)` and cloud
state persistence. Capture a complete cloud snapshot at flush time so local and
cloud writes correspond to the same preference version.

- [ ] **Step 4: Extend AppState tests**

Inject recording stores and a controllable coordinator/sleeper. Assert immediate
published values plus a single durable write after rapid updates and an
immediate write on background.

- [ ] **Step 5: Run persistence and AppState tests**

Run `PreferenceWriteCoordinatorTests`, `AppPreferencesTests`, and
`AppStateDistributionTests`.

## Task 11: Reduce Home rendering cost and clean visual spacing

**Files:**

- Modify: `VelyraTV/Features/Home/HomeView.swift`
- Modify: `VelyraTV/Features/Home/Components/CinematicHeroView.swift`
- Modify: `VelyraTV/Features/Home/Components/HomeFilterChip.swift`
- Modify: `VelyraTV/Features/Home/Components/HomeSectionView.swift`
- Modify: `VelyraTV/Features/Home/Components/RemoteMediaArtwork.swift`
- Modify: `VelyraTV/Features/Home/Models/HomeModels.swift`
- Test: `VelyraTVTests/Features/Home/HomePresentationTests.swift`

- [ ] **Step 1: Add presentation tests**

Test the consolidated attribution footer text key, stable section IDs, and
provider section subtitles without `Data by`, `Dados de`, `Datos de`, or
`Données par`.

- [ ] **Step 2: Move hero and logos onto the image pipeline**

Replace hero/provider `AsyncImage` uses with `CachedRemoteImage`, passing the
actual geometry size and `.fill`/`.fit` as appropriate. Keep placeholders local
and cancel image work through the existing pipeline lifecycle.

- [ ] **Step 3: Apply the lighter editorial layout**

- reduce Home section spacing from the current oversized 50-point gaps to a
  consistent 34-point section rhythm;
- retain 18–22 points inside headings/rows;
- leave at least 20 points outside focused card bounds;
- remove nested glass from filter chips and cards;
- make chip selection orange-accented while focus adds independent lift/outline;
- constrain hero copy and actions to the safe left content column;
- reserve navigation insets for the tvOS 17 rail.

- [ ] **Step 4: Add one attribution footer**

Render a low-emphasis localized footer after Home content for TMDB and JustWatch.
Remove provider-level attribution subtitles while keeping provider names.

- [ ] **Step 5: Verify Home tests and build**

Run `HomePresentationTests`, static validation, and the generic Simulator build.

## Task 12: Avoid unchanged Top Shelf writes and replace the static fallback

**Files:**

- Modify: `Shared/TopShelfSnapshot.swift`
- Modify: `VelyraTV/Core/TopShelf/TopShelfSnapshot+Home.swift`
- Modify: `VelyraTopShelf/ContentProvider.swift`
- Modify: `scripts/generate_brand_assets.swift`
- Modify generated assets:
  `VelyraTV/Resources/Assets.xcassets/AppIcon.brandassets/Top Shelf Image.imageset/*.png`
- Modify generated assets:
  `VelyraTV/Resources/Assets.xcassets/AppIcon.brandassets/Top Shelf Image Wide.imageset/*.png`
- Test: `VelyraTVTests/Core/TopShelf/TopShelfSnapshotTests.swift`
- Test: `scripts/tests/test_validate_brand_assets.py`

- [ ] **Step 1: Write failing semantic comparison tests**

Assert snapshots are semantically equal when only `updatedAt` differs and are
different when an item's ID, artwork, progress, title, or deep-link metadata
changes. Assert `saveIfChanged` reports `false` and does not replace bytes for an
unchanged snapshot using an injected temporary file URL.

- [ ] **Step 2: Make the store testable and skip unchanged writes**

Inject the store file URL with the app-group URL as its default. Add:

```swift
func hasSameContent(as other: TopShelfSnapshot) -> Bool
func saveIfChanged(_ snapshot: TopShelfSnapshot) throws -> Bool
```

Compare `continueWatching` and `recommendations`, deliberately excluding only
`updatedAt`. Update Home snapshot persistence to call `saveIfChanged`.

- [ ] **Step 3: Keep Resume First semantics in the extension**

Continue Watching stays first when present, followed by recommendations. Use
poster shape consistently, stable deep links, enough items to fill a row, and
return `nil` when no privacy-safe content exists so the system uses static
fallback.

- [ ] **Step 4: Redesign the generated fallback**

Update the existing deterministic asset generator to produce:

- near-black background;
- subtle orange ribbon light at the edge;
- restrained Velyra mark/wordmark;
- no buttons, controls, posters, or third-party imagery;
- the same required 1x/2x dimensions and opaque alpha properties.

Regenerate with:

```bash
swift scripts/generate_brand_assets.swift
```

- [ ] **Step 5: Run Top Shelf and asset validation**

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:VelyraTVTests/TopShelfSnapshotTests test CODE_SIGNING_ALLOWED=NO
python3 -m unittest scripts.tests.test_validate_brand_assets
python3 scripts/validate_brand_assets.py
```

Expected: unchanged semantic snapshots are not rewritten and all generated
assets meet dimension/alpha rules.

## Task 13: Complete localization and project documentation

**Files:**

- Modify: `VelyraTV/Resources/Localizable.xcstrings`
- Modify: `docs/design-system.md`
- Modify: `docs/accessibility.md`
- Modify: `docs/performance.md`
- Modify: `docs/top-shelf.md`
- Modify: `docs/home-discovery.md`
- Modify: `docs/data-sources.md`
- Modify: `docs/feature-matrix.md`
- Modify: `README.md`

- [ ] **Step 1: Add every new key in four languages**

Add English, Portuguese (Portugal), Spanish, and French values for:

- eight category titles and summaries;
- launch/onboarding text;
- Stremio link, pending, preview, status, import, retry, expiry, cancellation,
  empty, privacy, and completion states;
- consolidated attribution;
- Home section display names;
- new focus-safe action labels and picker labels.

Do not use English source strings as temporary values in the other locales.

- [ ] **Step 2: Scan for raw localization keys and removed phrases**

```bash
rg -n 'home\\.section\\.|Data by|Dados de|Datos de|Données par' VelyraTV VelyraTopShelf Shared
```

Expected: no user-facing raw `home.section.*` rendering and no repeated provider
attribution. Test fixtures may contain the phrases only when asserting absence.

- [ ] **Step 3: Update documentation**

Document:

- tvOS 18+ native adaptable sidebar and tvOS 17 fallback;
- conditional accessibility behavior, explicitly off unless system-enabled;
- category Settings structure;
- coalesced persistence and image-pipeline rules;
- Resume First Top Shelf and semantic writes;
- official temporary Stremio linking, read-only endpoint boundary, cleanup, and
  non-goals;
- one-screen onboarding and silent Ribbon Strike.

- [ ] **Step 4: Run static and localization validation**

```bash
scripts/ci_validate_tvos.sh --static
python3 -m unittest discover scripts/tests
```

Expected: all static, project, localization, release, workflow, and asset tests
pass.

## Task 14: Full verification and physical Apple TV handoff

**Files:**

- Modify only if verification reveals a defect in an in-scope file.

- [ ] **Step 1: Ensure required project tooling exists**

```bash
command -v xcodegen || brew install xcodegen
xcodegen generate
```

- [ ] **Step 2: Format and reject accidental changes**

```bash
swift-format format --in-place --recursive VelyraTV VelyraTVTests Shared VelyraTopShelf
scripts/ci_validate_tvos.sh --static
```

- [ ] **Step 3: Run all automated tests**

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  test CODE_SIGNING_ALLOWED=NO
python3 -m unittest discover scripts/tests
python3 scripts/validate_brand_assets.py
```

If the named simulator is unavailable, obtain an available tvOS destination
with `xcrun simctl list devices available` and rerun the same command with its
device ID. Do not treat a missing simulator runtime as a passing test.

- [ ] **Step 4: Build application and Top Shelf extension together**

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV \
  -destination 'generic/platform=tvOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 5: Perform privacy/security scans**

```bash
rg -n 'addonCollectionSet|authKey.*(print|log)|print\\(.*auth|logger.*auth' \
  VelyraTV VelyraTVTests Shared VelyraTopShelf
rg -n 'http://|localhost|127\\.0\\.0\\.1|::1' \
  VelyraTV/Features/Addons/Stremio VelyraTVTests/Features/Addons
```

Expected:

- no production Stremio write endpoint;
- no auth-key logging;
- insecure/local hosts appear only in explicit rejection tests;
- the only collection operation in production is `addonCollectionGet`.

- [ ] **Step 6: Run physical Apple TV acceptance**

On tvOS 17 and a tvOS 18+ device/runtime, verify:

- native/collapsed sidebar and coherent fallback;
- focus restoration, Menu/Back, no clipped rail/card focus;
- normal mode shows full motion/material when accessibility settings are off;
- Reduce Motion, Reduce Transparency, Increase Contrast, and VoiceOver adapt
  only when enabled in system Settings;
- one-shot silent launch ident and one-action onboarding;
- readable Settings at viewing distance;
- phone/computer Stremio link, preview, selective import, cancel, expiry, and
  no changes written to Stremio;
- Home vertical/horizontal focus remains smooth;
- Top Shelf Continue Watching, recommendations, deep links, and static fallback.

Record hardware-only issues separately. Do not claim physical acceptance from
Simulator or unit-test results.

## Definition of done

- [ ] Every acceptance criterion in the approved design specification maps to a
      completed task above.
- [ ] Every new deterministic policy has a red/green unit test.
- [ ] The full app and Top Shelf extension build for the tvOS 17 deployment
      target.
- [ ] Static, Python, focused XCTest, full XCTest, asset, localization, and
      security checks pass.
- [ ] Stremio auth material remains memory-only and all authorized sessions
      attempt cleanup.
- [ ] No Stremio write endpoint exists.
- [ ] Accessibility visual adaptations are conditional on system settings.
- [ ] Physical Apple TV checks are explicitly reported as passed, failed, or
      pending rather than inferred.
