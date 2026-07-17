# Xcode tvOS Sideload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and validate a local-only tvOS IPA that atvloadly can sign with a free Apple ID without weakening Velyra's future full-release target.

**Architecture:** Add a compile-time `AppDistributionCapabilities` boundary and a separate XcodeGen application target named `VelyraTVSideload`. The sideload binary uses local preference and per-content state stores, excludes Top Shelf and restricted entitlements, and is archived unsigned by a deterministic packaging script.

**Tech Stack:** Swift 6, SwiftUI, tvOS 17+, XCTest, XcodeGen, Xcode 26.6, Python 3 validation, POSIX shell, Homebrew.

---

### Task 0: Install and verify unprivileged build tools

**Files:**
- Generated and ignored: `Velyra.xcodeproj/`

- [ ] **Step 1: Install XcodeGen and swift-format with Homebrew**

Run:

```bash
brew install xcodegen swift-format
```

Expected: both tools install without changing `xcode-select` or requesting administrator access.

- [ ] **Step 2: Verify versions and generate the baseline project**

Run `xcodegen --version`, `swift-format --version`, and `xcodegen generate`. Expected: version output and a generated ignored `Velyra.xcodeproj`.

- [ ] **Step 3: Confirm the baseline target graph**

Run `xcodebuild -project Velyra.xcodeproj -list`. Expected: the original application, extension, test target, and `VelyraTV` scheme are present before implementation.

### Task 1: Model full and sideload capabilities

**Files:**
- Create: `VelyraTV/App/AppDistributionCapabilities.swift`
- Create: `VelyraTVTests/App/AppDistributionCapabilitiesTests.swift`
- Modify: `VelyraTV/Core/Playback/AutomaticSetupService.swift`

- [ ] **Step 1: Write failing capability tests**

Create tests that verify the full preset supports iCloud, CloudKit, and Top Shelf; the sideload preset supports none of them; and automatic setup disables iCloud when passed sideload capabilities.

```swift
import XCTest
@testable import VelyraTV

final class AppDistributionCapabilitiesTests: XCTestCase {
  func testFullReleaseSupportsAppleServices() {
    XCTAssertTrue(AppDistributionCapabilities.full.supportsICloudPreferences)
    XCTAssertTrue(AppDistributionCapabilities.full.supportsCloudKit)
    XCTAssertTrue(AppDistributionCapabilities.full.supportsTopShelf)
  }

  func testSideloadUsesOnlyLocalServices() {
    XCTAssertFalse(AppDistributionCapabilities.sideload.supportsICloudPreferences)
    XCTAssertFalse(AppDistributionCapabilities.sideload.supportsCloudKit)
    XCTAssertFalse(AppDistributionCapabilities.sideload.supportsTopShelf)
  }

  func testAutomaticSetupDisablesICloudForSideload() {
    let configured = AutomaticSetupService().configuredPreferences(
      from: .defaults,
      locale: Locale(identifier: "pt_PT"),
      capabilities: .sideload
    )
    XCTAssertFalse(configured.iCloudSyncEnabled)
    XCTAssertEqual(configured.contentRegion, "PT")
  }
}
```

- [ ] **Step 2: Verify the new test fails to compile**

Run:

```bash
xcodegen generate
xcodebuild -project Velyra.xcodeproj -target VelyraTVTests -configuration Debug -sdk appletvsimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: build failure because `AppDistributionCapabilities` and the new `configuredPreferences` parameter do not exist.

- [ ] **Step 3: Implement the capability model**

Create an immutable, `Sendable` value with `.full`, `.sideload`, and compile-time `.current` presets:

```swift
struct AppDistributionCapabilities: Equatable, Sendable {
  let supportsICloudPreferences: Bool
  let supportsCloudKit: Bool
  let supportsTopShelf: Bool

  static let full = AppDistributionCapabilities(
    supportsICloudPreferences: true,
    supportsCloudKit: true,
    supportsTopShelf: true
  )

  static let sideload = AppDistributionCapabilities(
    supportsICloudPreferences: false,
    supportsCloudKit: false,
    supportsTopShelf: false
  )

  static var current: AppDistributionCapabilities {
    #if VELYRA_SIDELOAD
      .sideload
    #else
      .full
    #endif
  }
}
```

Extend `AutomaticSetupService.configuredPreferences` with a defaulted `capabilities: AppDistributionCapabilities = .current` parameter and set:

```swift
preferences.iCloudSyncEnabled = capabilities.supportsICloudPreferences
```

- [ ] **Step 4: Parse and validate the implementation**

Run the repository Swift parser command and `python3 scripts/validate_project.py`. Expected: both exit 0.

- [ ] **Step 5: Commit the capability boundary**

```bash
git add VelyraTV/App/AppDistributionCapabilities.swift VelyraTV/Core/Playback/AutomaticSetupService.swift VelyraTVTests/App/AppDistributionCapabilitiesTests.swift
git commit -m "feat: model sideload distribution capabilities"
```

### Task 2: Persist sideload user state locally

**Files:**
- Modify: `VelyraTV/Core/Sync/CloudUserStateStore.swift`
- Modify: `VelyraTV/Core/Sync/ICloudAccountMonitor.swift`
- Create: `VelyraTVTests/Core/Sync/LocalUserStateStoreTests.swift`

- [ ] **Step 1: Write failing local-store tests**

Use an isolated `UserDefaults` suite and verify round-trip and deletion:

```swift
import XCTest
@testable import VelyraTV

final class LocalUserStateStoreTests: XCTestCase {
  func testStatePersistsAcrossStoreInstancesAndCanBeDeleted() async throws {
    let suite = "LocalUserStateStoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    var state = CloudUserState.initial(preferences: .defaults)
    state.contentPlaybackPreferences["movie:42"] = ContentPlaybackPreference(
      audioLanguageCode: "en",
      subtitleLanguageCode: "pt-PT",
      subtitlesEnabled: true,
      preferredSourceAddonID: nil,
      subtitleTimingOffset: 0.5,
      updatedAt: Date(timeIntervalSince1970: 42)
    )

    try await LocalUserStateStore(defaults: defaults).save(state)
    XCTAssertEqual(try await LocalUserStateStore(defaults: defaults).load(), state)

    try await LocalUserStateStore(defaults: defaults).delete()
    XCTAssertNil(try await LocalUserStateStore(defaults: defaults).load())
  }
}
```

- [ ] **Step 2: Implement `LocalUserStateStore`**

Add an actor conforming to `CloudUserStateStoring`, backed by a versioned UserDefaults data key and ISO-8601 JSON dates. Encoding errors propagate; an absent key returns `nil`.

- [ ] **Step 3: Add a disabled iCloud monitor**

Allow `ICloudAccountMonitor` to hold an optional `CKContainer`, add a `static func localOnly() -> ICloudAccountMonitor`, initialize it with `.unavailable`, and make `refresh()` return `.unavailable` without calling CloudKit when no container exists.

- [ ] **Step 4: Parse and validate**

Run Swift parsing and static validation. Expected: exit 0.

- [ ] **Step 5: Commit local state support**

```bash
git add VelyraTV/Core/Sync/CloudUserStateStore.swift VelyraTV/Core/Sync/ICloudAccountMonitor.swift VelyraTVTests/Core/Sync/LocalUserStateStoreTests.swift
git commit -m "feat: persist sideload state locally"
```

### Task 3: Gate cloud and Top Shelf runtime behaviour

**Files:**
- Modify: `VelyraTV/App/AppState.swift`
- Modify: `VelyraTV/Features/Home/HomeView.swift`
- Modify: `VelyraTV/Features/Onboarding/OnboardingView.swift`
- Modify: `VelyraTV/Features/Settings/SettingsView.swift`
- Modify: `VelyraTV/Core/Diagnostics/DiagnosticsReport.swift`
- Modify: `VelyraTV/Resources/Localizable.xcstrings`

- [ ] **Step 1: Inject capabilities and stores into `AppState`**

Expose `let distributionCapabilities`, initialize `iCloudAccount`, `preferencesStore`, and `cloudUserStore` according to the selected capabilities, and retain optional injection for tests. Full mode uses `ICloudPreferencesStore` and `CloudKitUserStateStore`; sideload mode uses `LocalPreferencesStore`, `LocalUserStateStore`, and `ICloudAccountMonitor.localOnly()`.

- [ ] **Step 2: Separate local persistence from cloud synchronization**

During sideload bootstrap, load the local `CloudUserState`, retain the loaded local preferences, and persist per-content state locally. Guard iCloud observers, account refresh, explicit sync, and cloud deletion with `supportsICloudPreferences`/`supportsCloudKit`. Always persist `cloudState` through the selected store so per-content choices survive sideload relaunches.

- [ ] **Step 3: Gate Top Shelf writes**

Only save or clear `TopShelfSnapshotStore` when `supportsTopShelf` is true:

```swift
if appState.distributionCapabilities.supportsTopShelf, let feed = viewModel.feed {
  try? await TopShelfSnapshotStore.shared.save(.make(feed: feed))
}
```

- [ ] **Step 4: Adapt onboarding and Settings**

For sideload, use an `internaldrive.fill` onboarding footer and `onboarding.sideload.privacy`. Replace the iCloud Settings controls with a read-only card using `settings.sideload.title` and `settings.sideload.body`. Full builds retain the existing cloud controls unchanged.

- [ ] **Step 5: Add complete localizations**

Add these values in all required locales:

| Key | English | Portuguese (Portugal) | Spanish | French |
|---|---|---|---|---|
| `onboarding.sideload.privacy` | Settings stay privately on this Apple TV in the sideload edition. | Na edição sideload, as definições permanecem privadas nesta Apple TV. | En la edición sideload, los ajustes permanecen privados en este Apple TV. | Dans l’édition sideload, les réglages restent privés sur cette Apple TV. |
| `settings.sideload.title` | Local sideload edition | Edição sideload local | Edición sideload local | Édition sideload locale |
| `settings.sideload.body` | Settings are stored on this Apple TV. iCloud sync and Top Shelf require a paid Apple Developer configuration. | As definições são guardadas nesta Apple TV. A sincronização iCloud e o Top Shelf requerem uma configuração Apple Developer paga. | Los ajustes se guardan en este Apple TV. La sincronización con iCloud y Top Shelf requieren una configuración Apple Developer de pago. | Les réglages sont stockés sur cette Apple TV. La synchronisation iCloud et Top Shelf nécessitent une configuration Apple Developer payante. |

- [ ] **Step 6: Make diagnostics capability-aware**

Report `iCloudEnabled` as false and `iCloudStatus` as `local-only` when the current distribution does not support iCloud.

- [ ] **Step 7: Validate and commit runtime gating**

Run static validation and Swift parsing, then commit:

```bash
git add VelyraTV/App/AppState.swift VelyraTV/Features/Home/HomeView.swift VelyraTV/Features/Onboarding/OnboardingView.swift VelyraTV/Features/Settings/SettingsView.swift VelyraTV/Core/Diagnostics/DiagnosticsReport.swift VelyraTV/Resources/Localizable.xcstrings
git commit -m "feat: disable paid capabilities in sideload builds"
```

### Task 4: Add the XcodeGen sideload target and contract validation

**Files:**
- Modify: `project.yml`
- Create: `VelyraTV/Resources/VelyraTVSideload.entitlements`
- Modify: `scripts/validate_project.py`
- Modify: `.gitignore`

- [ ] **Step 1: Extend the static validator before the target exists**

Require `VelyraTVSideload`, `VELYRA_SIDELOAD`, the sideload entitlement file, and the IPA build script. Parse the sideload entitlements and fail if any restricted entitlement from the design is present.

- [ ] **Step 2: Run validation and observe the expected failure**

Run `python3 scripts/validate_project.py`. Expected: failure naming the missing sideload target or entitlement file.

- [ ] **Step 3: Create an empty entitlement plist**

Create a valid XML property list whose root dictionary contains no values.

- [ ] **Step 4: Define `VelyraTVSideload` and its scheme**

Mirror the full application's source/resource declarations, omit the `VelyraTopShelf` dependency, set product name `Velyra`, bundle identifier `pt.ricardosoares.velyra.sideload`, use the sideload entitlement file, and add `VELYRA_SIDELOAD` to inherited compilation conditions.

- [ ] **Step 5: Ignore build artifacts**

Add `artifacts/` and `.sideload-build/` to `.gitignore`.

- [ ] **Step 6: Validate and commit project configuration**

Run `plutil -lint`, static validation, and Swift parsing. Expected: exit 0. Commit:

```bash
git add project.yml VelyraTV/Resources/VelyraTVSideload.entitlements scripts/validate_project.py .gitignore
git commit -m "build: add local tvOS sideload target"
```

### Task 5: Build and inspect the unsigned IPA

**Files:**
- Create: `scripts/build_sideload_ipa.sh`
- Modify: `README.md`
- Modify: `docs/release-readiness.md`

- [ ] **Step 1: Implement strict tool checks**

Use `#!/bin/sh` and `set -eu`. Resolve the repository root relative to the script, check `python3`, `xcodegen`, `xcodebuild`, `swift-format`, `/usr/bin/ditto`, `/usr/bin/unzip`, and `/usr/libexec/PlistBuddy`, and print an actionable missing-tool error without attempting privileged installation.

- [ ] **Step 2: Implement validation, generation, and lint**

Run the project validator, Swift formatter lint, and `xcodegen generate --spec project.yml` from the repository root.

- [ ] **Step 3: Implement unsigned archive and packaging**

Archive `VelyraTVSideload` for `generic/platform=tvOS` into `.sideload-build/VelyraSideload.xcarchive` with `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`. Copy `Products/Applications/Velyra.app` to `.sideload-build/package/Payload/Velyra.app`, then package `Payload` into `artifacts/Velyra-sideload.ipa` using `ditto`.

- [ ] **Step 4: Implement artifact validation**

Verify the app exists, no `.appex` directory exists, the IPA lists `Payload/Velyra.app/Info.plist`, the bundle identifier equals `pt.ricardosoares.velyra.sideload`, and the source sideload entitlement plist contains none of the four restricted keys. Remove a partial output before each build.

- [ ] **Step 5: Document local use**

Document Homebrew prerequisites, `xcodegen generate`, opening Xcode without changing `xcode-select`, the build script, artifact path, atvloadly signing responsibility, seven-day Personal Team expiry, disabled sideload capabilities, and the future full-release path.

- [ ] **Step 6: Validate and commit build tooling**

Run `sh -n scripts/build_sideload_ipa.sh`, static validation, and Swift parsing. Commit:

```bash
git add scripts/build_sideload_ipa.sh README.md docs/release-readiness.md
git commit -m "build: package unsigned tvOS sideload IPA"
```

### Task 6: Run available Xcode validations

**Files:**
- Generated and ignored: `Velyra.xcodeproj/`
- Generated and ignored: `.sideload-build/`
- Generated and ignored: `artifacts/Velyra-sideload.ipa`

- [ ] **Step 1: Generate and inspect the Xcode project**

Run `xcodegen generate` and `xcodebuild -project Velyra.xcodeproj -list`. Expected: full, Top Shelf, tests, and sideload targets are listed.

- [ ] **Step 2: Compile the full target without signing**

Run an `xcodebuild build` for `VelyraTV`, `generic/platform=tvOS`, with signing disabled. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Compile and archive sideload**

Run `scripts/build_sideload_ipa.sh`. Expected: `artifacts/Velyra-sideload.ipa` exists and all inspections pass.

- [ ] **Step 4: Attempt the available test path honestly**

Run `xcodebuild test` only if `xcrun simctl list devices available` reports a tvOS device. Otherwise report XCTest as unavailable because no tvOS runtime exists, and run `xcodebuild build-for-testing` against the installed tvOS Simulator SDK if Xcode accepts the generic destination.

### Task 7: Final verification and GitFlow integration

**Files:**
- Modify only if verification reveals defects in files already listed above.

- [ ] **Step 1: Run the complete fresh verification set**

Run static validation, formatter lint, Swift parsing, generated-project listing, full unsigned build, sideload IPA build, plist validation, IPA inspection, and XCTest when available.

- [ ] **Step 2: Inspect repository changes and secrets**

Run `git diff --check`, review `git status --short`, and search tracked changes for Apple IDs, passwords, private keys, provisioning profiles, `.p12` data, and non-empty provider secrets.

- [ ] **Step 3: Commit verification-only fixes if required**

Use a focused Conventional Commit only when a verification fix changed tracked files.

- [ ] **Step 4: Merge the feature into develop**

Switch to `develop`, merge `feature/xcode-sideload` with a merge commit that preserves GitFlow history, and rerun the non-generated validation command. Do not touch `main`.
