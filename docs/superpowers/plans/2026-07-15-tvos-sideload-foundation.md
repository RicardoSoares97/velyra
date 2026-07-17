# tvOS Sideload Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a compile-time sideload edition that archives without paid Apple capabilities and preserves user state locally for atvloadly installation.

**Architecture:** Keep the existing full app and Top Shelf extension intact. Add a `VelyraTVSideload` target that shares app sources but selects explicit distribution capabilities, local stores, empty entitlements, and no extension dependency.

**Tech Stack:** Swift 6, SwiftUI, CloudKit, UserDefaults, XCTest, XcodeGen, shell, Python plist validation.

---

This plan supersedes the implementation details in `docs/superpowers/plans/2026-07-15-xcode-tvos-sideload.md`. Repository policy prohibits the agent from running Git commands. Each task therefore ends with a manual user Git checkpoint instead of an agent-executed commit.

## File map

- Create `VelyraTV/Core/Distribution/DistributionCapabilities.swift`: compile-time capability contract.
- Create `VelyraTV/Core/Sync/LocalUserStateStore.swift`: local persistence for the existing `CloudUserState` model.
- Create `VelyraTV/Resources/VelyraTVSideload.entitlements`: deliberately empty entitlement dictionary.
- Create `VelyraTVTests/Core/Distribution/DistributionCapabilitiesTests.swift`: full/sideload capability tests.
- Create `VelyraTVTests/Core/Sync/LocalUserStateStoreTests.swift`: round-trip and deletion tests.
- Create `VelyraTVTests/App/AppStateDistributionTests.swift`: store and cloud behavior tests.
- Create `scripts/build_sideload_ipa.sh`: unsigned archive, package, and inspection entry point.
- Modify `VelyraTV/App/AppState.swift`: inject capabilities and gate cloud/Top Shelf behavior.
- Modify `VelyraTV/Core/Sync/ICloudAccountMonitor.swift`: local-only monitor mode.
- Modify `VelyraTV/Features/Home/HomeView.swift`: gate snapshot writes.
- Modify `VelyraTV/Features/Onboarding/OnboardingView.swift`: local-edition privacy copy.
- Modify `VelyraTV/Features/Settings/SettingsView.swift`: replace cloud controls in sideload mode.
- Modify `VelyraTV/Core/Diagnostics/DiagnosticsReport.swift`: capability-aware diagnostics.
- Modify `VelyraTV/Resources/Localizable.xcstrings`: four-locale sideload strings.
- Modify `project.yml`: target, scheme, resources, and compilation condition.
- Modify `scripts/validate_project.py`: sideload target and entitlement contract.
- Modify `.gitignore`: build, artifact, and visual-companion outputs.
- Modify `README.md` and `docs/release-readiness.md`: build and Personal Team behavior.

### Task 1: Define distribution capabilities

**Files:**
- Create: `VelyraTV/Core/Distribution/DistributionCapabilities.swift`
- Create: `VelyraTVTests/Core/Distribution/DistributionCapabilitiesTests.swift`

- [ ] **Step 1: Write the failing capability tests**

```swift
import XCTest

@testable import VelyraTV

final class DistributionCapabilitiesTests: XCTestCase {
  func testFullEditionEnablesAppleCloudAndTopShelf() {
    XCTAssertTrue(DistributionCapabilities.full.supportsICloudPreferences)
    XCTAssertTrue(DistributionCapabilities.full.supportsCloudKit)
    XCTAssertTrue(DistributionCapabilities.full.supportsTopShelf)
    XCTAssertFalse(DistributionCapabilities.full.isSideload)
  }

  func testSideloadEditionUsesOnlyLocalCapabilities() {
    XCTAssertFalse(DistributionCapabilities.sideload.supportsICloudPreferences)
    XCTAssertFalse(DistributionCapabilities.sideload.supportsCloudKit)
    XCTAssertFalse(DistributionCapabilities.sideload.supportsTopShelf)
    XCTAssertTrue(DistributionCapabilities.sideload.isSideload)
  }
}
```

- [ ] **Step 2: Run the focused test and confirm the expected compile failure**

Run after `xcodegen generate`:

```bash
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV -sdk appletvsimulator \
  -destination 'platform=tvOS Simulator,name=Apple TV,OS=latest' \
  -only-testing:VelyraTVTests/DistributionCapabilitiesTests \
  CODE_SIGNING_ALLOWED=NO test
```

Expected: compilation fails because `DistributionCapabilities` is undefined.

- [ ] **Step 3: Add the immutable capability contract**

```swift
import Foundation

struct DistributionCapabilities: Equatable, Sendable {
  let isSideload: Bool
  let supportsICloudPreferences: Bool
  let supportsCloudKit: Bool
  let supportsTopShelf: Bool

  static let full = DistributionCapabilities(
    isSideload: false,
    supportsICloudPreferences: true,
    supportsCloudKit: true,
    supportsTopShelf: true
  )

  static let sideload = DistributionCapabilities(
    isSideload: true,
    supportsICloudPreferences: false,
    supportsCloudKit: false,
    supportsTopShelf: false
  )

  static var current: DistributionCapabilities {
    #if VELYRA_SIDELOAD
      .sideload
    #else
      .full
    #endif
  }
}
```

- [ ] **Step 4: Run formatter and the focused test**

Run: `swift-format lint VelyraTV/Core/Distribution/DistributionCapabilities.swift VelyraTVTests/Core/Distribution/DistributionCapabilitiesTests.swift`

Expected: no formatter diagnostics. Run the focused XCTest command again; expected: PASS.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit these two files with `feat: define distribution capabilities`.

### Task 2: Persist user state locally

**Files:**
- Create: `VelyraTV/Core/Sync/LocalUserStateStore.swift`
- Create: `VelyraTVTests/Core/Sync/LocalUserStateStoreTests.swift`

- [ ] **Step 1: Write round-trip, corrupt-data, and deletion tests**

```swift
import XCTest

@testable import VelyraTV

final class LocalUserStateStoreTests: XCTestCase {
  func testRoundTripAndDelete() async throws {
    let suite = try XCTUnwrap(UserDefaults(suiteName: #function))
    suite.removePersistentDomain(forName: #function)
    let store = LocalUserStateStore(defaults: suite)
    let state = CloudUserState.initial(preferences: .defaults)

    try await store.save(state)
    XCTAssertEqual(try await store.load(), state)

    try await store.delete()
    XCTAssertNil(try await store.load())
  }

  func testCorruptPayloadIsDiscarded() async throws {
    let suite = try XCTUnwrap(UserDefaults(suiteName: #function))
    suite.removePersistentDomain(forName: #function)
    suite.set(Data("invalid".utf8), forKey: LocalUserStateStore.storageKey)

    XCTAssertNil(try await LocalUserStateStore(defaults: suite).load())
  }
}
```

- [ ] **Step 2: Run the test and confirm the missing-type failure**

Run the simulator XCTest command with `-only-testing:VelyraTVTests/LocalUserStateStoreTests`.

Expected: compilation fails because `LocalUserStateStore` is undefined.

- [ ] **Step 3: Implement the actor**

```swift
import Foundation

actor LocalUserStateStore: CloudUserStateStoring {
  static let storageKey = "velyra.user-state.v2"

  private let defaults: UserDefaults
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
  }

  func load() throws -> CloudUserState? {
    guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
    guard let state = try? decoder.decode(CloudUserState.self, from: data) else {
      defaults.removeObject(forKey: Self.storageKey)
      return nil
    }
    return state
  }

  func save(_ state: CloudUserState) throws {
    defaults.set(try encoder.encode(state), forKey: Self.storageKey)
  }

  func delete() {
    defaults.removeObject(forKey: Self.storageKey)
  }
}
```

- [ ] **Step 4: Run the focused tests**

Expected: both tests PASS and the corrupt value is removed.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `feat: persist sideload user state locally`.

### Task 3: Make AppState distribution-aware

**Files:**
- Modify: `VelyraTV/App/AppState.swift`
- Modify: `VelyraTV/Core/Sync/ICloudAccountMonitor.swift`
- Create: `VelyraTVTests/App/AppStateDistributionTests.swift`

- [ ] **Step 1: Add a local-only monitor test**

```swift
import XCTest

@testable import VelyraTV

@MainActor
final class AppStateDistributionTests: XCTestCase {
  func testLocalOnlyMonitorRemainsUnavailableAfterRefresh() async {
    let monitor = ICloudAccountMonitor.localOnly()
    await monitor.refresh()
    XCTAssertEqual(monitor.status, .unavailable)
  }
}
```

- [ ] **Step 2: Run the focused test and observe the missing factory**

Expected: compilation fails because `localOnly()` does not exist.

- [ ] **Step 3: Add an optional CloudKit container mode**

Change `ICloudAccountMonitor` to store `private let container: CKContainer?`, add this initializer and factory, then guard `refresh()`:

```swift
init(
  container: CKContainer? = CKContainer(identifier: "iCloud.pt.ricardosoares.velyra"),
  initialStatus: Status = .checking
) {
  self.container = container
  status = initialStatus
}

static func localOnly() -> ICloudAccountMonitor {
  ICloudAccountMonitor(container: nil, initialStatus: .unavailable)
}

func refresh() async {
  guard let container else {
    status = .unavailable
    return
  }
  do {
    switch try await container.accountStatus() {
    case .available: status = .available
    case .noAccount: status = .unavailable
    case .restricted: status = .restricted
    case .couldNotDetermine, .temporarilyUnavailable: status = .couldNotDetermine
    @unknown default: status = .couldNotDetermine
    }
  } catch {
    status = .couldNotDetermine
  }
}
```

- [ ] **Step 4: Inject capabilities and optional stores into AppState**

Replace fixed property initialization with initialized properties and an initializer shaped as follows:

```swift
let distributionCapabilities: DistributionCapabilities
let iCloudAccount: ICloudAccountMonitor

init(
  distributionCapabilities: DistributionCapabilities = .current,
  preferencesStore: (any PreferencesStore)? = nil,
  cloudUserStore: (any CloudUserStateStoring)? = nil,
  iCloudAccount: ICloudAccountMonitor? = nil
) {
  self.distributionCapabilities = distributionCapabilities
  if let preferencesStore {
    self.preferencesStore = preferencesStore
  } else if distributionCapabilities.supportsICloudPreferences {
    self.preferencesStore = ICloudPreferencesStore()
  } else {
    self.preferencesStore = LocalPreferencesStore()
  }
  if let cloudUserStore {
    self.cloudUserStore = cloudUserStore
  } else if distributionCapabilities.supportsCloudKit {
    self.cloudUserStore = CloudKitUserStateStore()
  } else {
    self.cloudUserStore = LocalUserStateStore()
  }
  self.iCloudAccount = iCloudAccount
    ?? (distributionCapabilities.supportsCloudKit
      ? ICloudAccountMonitor() : .localOnly())
  // Retain existing observations after every stored property is initialized.
}
```

Only create the `NSUbiquitousKeyValueStore` notification subscription when `supportsICloudPreferences` is true.

- [ ] **Step 5: Load and save local state without cloud guards**

In `bootstrap()`, add a sideload branch before CloudKit loading:

```swift
if !distributionCapabilities.supportsCloudKit {
  if var local = try? await cloudUserStore.load() {
    local.preferences.normalize()
    cloudState = local
    preferences = local.preferences
  } else {
    try? await cloudUserStore.save(cloudState)
  }
} else if loadedPreferences.iCloudSyncEnabled, iCloudAccount.status == .available {
  if var remote = try? await cloudUserStore.load() {
    remote.preferences.normalize()
    let merged = cloudState.merging(with: remote)
    cloudState = merged
    preferences = merged.preferences
    await preferencesStore.save(merged.preferences)
    try? await cloudUserStore.save(merged)
  } else {
    try? await cloudUserStore.save(cloudState)
  }
}
```

Update `persistCloudState()` so sideload always persists locally:

```swift
cloudState.preferences = preferences
if !distributionCapabilities.supportsCloudKit {
  try await cloudUserStore.save(cloudState)
  return
}
guard preferences.iCloudSyncEnabled, iCloudAccount.status == .available else { return }
try await cloudUserStore.save(cloudState)
```

Guard cloud refresh, iCloud notification handling, and cloud deletion with the corresponding capability. In local mode, reset deletes and recreates the local state instead of attempting CloudKit.

- [ ] **Step 6: Extend tests with injected local stores**

Add a test that initializes `AppState(distributionCapabilities: .sideload, preferencesStore: LocalPreferencesStore(defaults: suite), cloudUserStore: LocalUserStateStore(defaults: suite), iCloudAccount: .localOnly())`, calls `bootstrap()`, updates a content playback preference, and verifies the value exists after a second AppState bootstrap.

- [ ] **Step 7: Run focused tests and static validation**

Run the three distribution/local-store test classes, then `python3 scripts/validate_project.py`.

Expected: PASS and `Velyra project validation passed`.

- [ ] **Step 8: Manual Git checkpoint**

Ask the user to commit with `feat: use local state in sideload builds`.

### Task 4: Gate Top Shelf, Settings, onboarding, and diagnostics

**Files:**
- Modify: `VelyraTV/Features/Home/HomeView.swift`
- Modify: `VelyraTV/Features/Onboarding/OnboardingView.swift`
- Modify: `VelyraTV/Features/Settings/SettingsView.swift`
- Modify: `VelyraTV/Core/Diagnostics/DiagnosticsReport.swift`
- Modify: `VelyraTV/Resources/Localizable.xcstrings`

- [ ] **Step 1: Gate the Top Shelf write**

```swift
if appState.distributionCapabilities.supportsTopShelf, let feed = viewModel.feed {
  try? await TopShelfSnapshotStore.shared.save(.make(feed: feed))
}
```

- [ ] **Step 2: Replace cloud controls in sideload Settings**

At the start of `syncSection`, branch on capabilities:

```swift
if appState.distributionCapabilities.isSideload {
  SettingsCard(titleKey: "settings.sideload.title", systemImage: "internaldrive.fill") {
    Text("settings.sideload.body")
      .font(.headline)
      .foregroundStyle(.white.opacity(0.72))
  }
} else {
  SettingsCard(titleKey: "settings.icloud", systemImage: "icloud.fill") {
    SettingsToggle(
      titleKey: "settings.icloudSync",
      subtitleKey: "settings.icloudSync.body",
      isOn: binding(\.iCloudSyncEnabled)
    )
    cloudControls
  }
}
```

Extract the existing status label, sync-now button, delete button, confirmation dialog, message, and error label into `private var cloudControls: some View` without changing their behavior.

- [ ] **Step 3: Make onboarding privacy copy capability-aware**

Use `internaldrive.fill` and `onboarding.sideload.privacy` in sideload mode; retain the current iCloud symbol and `onboarding.simple.privacy` for the full build.

- [ ] **Step 4: Make diagnostics capability-aware**

Set `iCloudEnabled` to `supportsCloudKit && preferences.iCloudSyncEnabled` and `iCloudStatus` to `local-only` when CloudKit is unsupported.

- [ ] **Step 5: Add all four localizations**

Add these exact meanings in `en`, `pt-PT`, `es`, and `fr`:

| Key | English | Portuguese (Portugal) | Spanish | French |
| --- | --- | --- | --- | --- |
| `onboarding.sideload.privacy` | Settings stay privately on this Apple TV in the sideload edition. | Na edição sideload, as definições permanecem privadas nesta Apple TV. | En la edición sideload, los ajustes permanecen privados en este Apple TV. | Dans l’édition sideload, les réglages restent privés sur cet Apple TV. |
| `settings.sideload.title` | Local sideload edition | Edição sideload local | Edición sideload local | Édition sideload locale |
| `settings.sideload.body` | Settings are stored on this Apple TV. iCloud sync and dynamic Top Shelf require a paid Apple Developer configuration. | As definições são guardadas nesta Apple TV. A sincronização iCloud e o Top Shelf dinâmico requerem uma configuração Apple Developer paga. | Los ajustes se guardan en este Apple TV. La sincronización con iCloud y el Top Shelf dinámico requieren una configuración Apple Developer de pago. | Les réglages sont stockés sur cet Apple TV. La synchronisation iCloud et le Top Shelf dynamique nécessitent une configuration Apple Developer payante. |

- [ ] **Step 6: Run localization, formatter, and source parsing checks**

Run:

```bash
python3 scripts/validate_project.py
swift-format lint --recursive VelyraTV VelyraTVTests Shared VelyraTopShelf
```

Expected: both exit 0.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `feat: explain sideload capability limits`.

### Task 5: Add the XcodeGen target and entitlement contract

**Files:**
- Create: `VelyraTV/Resources/VelyraTVSideload.entitlements`
- Modify: `project.yml`
- Modify: `scripts/validate_project.py`
- Modify: `.gitignore`

- [ ] **Step 1: Extend the validator first**

Add the sideload plist to `PLISTS`, require `VelyraTVSideload:` and `VELYRA_SIDELOAD`, and reject these keys:

```python
RESTRICTED_SIDELOAD_ENTITLEMENTS = {
    "com.apple.developer.icloud-container-identifiers",
    "com.apple.developer.icloud-services",
    "com.apple.developer.ubiquity-kvstore-identifier",
    "com.apple.security.application-groups",
}
```

Load `VelyraTVSideload.entitlements`, intersect its keys with this set, and fail with the sorted key names when the intersection is non-empty.

- [ ] **Step 2: Run validation and verify it fails**

Run: `python3 scripts/validate_project.py`

Expected: failure names the missing sideload entitlement or target.

- [ ] **Step 3: Create an empty entitlement plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
```

- [ ] **Step 4: Add the scheme and application target**

Add a shared `VelyraTVSideload` scheme with build, run, and archive actions. Define a tvOS application target using the same `VelyraTV` and `Shared` source paths and ordinary resources, no `VelyraTopShelf` dependency, bundle ID `pt.ricardosoares.velyra.sideload`, the empty entitlements file, and:

```yaml
SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) VELYRA_SIDELOAD"
```

The product name remains `Velyra` so the payload path is stable.

- [ ] **Step 5: Ignore generated outputs**

Append:

```gitignore
# Local sideload and brainstorming outputs
artifacts/
.sideload-build/
.superpowers/
```

- [ ] **Step 6: Validate configuration**

Run:

```bash
plutil -lint VelyraTV/Resources/VelyraTVSideload.entitlements
python3 scripts/validate_project.py
xcodegen generate
```

Expected: every command exits 0 and the generated project contains both application schemes.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `build: add tvOS sideload target`.

### Task 6: Package and inspect the unsigned IPA

**Files:**
- Create: `scripts/build_sideload_ipa.sh`
- Modify: `README.md`
- Modify: `docs/release-readiness.md`

- [ ] **Step 1: Create the strict script skeleton**

```sh
#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_ROOT=${SIDELOAD_BUILD_ROOT:-"$ROOT/.sideload-build"}
OUTPUT_DIR=${SIDELOAD_OUTPUT_DIR:-"$ROOT/artifacts"}
ARCHIVE="$BUILD_ROOT/VelyraSideload.xcarchive"
PACKAGE="$BUILD_ROOT/package"
IPA="$OUTPUT_DIR/Velyra-sideload.ipa"

for tool in python3 xcodegen xcodebuild swift-format; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: missing required tool: $tool" >&2
    exit 1
  }
done
```

- [ ] **Step 2: Add validation, generation, and archive commands**

Run the repository validator, formatter lint, and XcodeGen from `$ROOT`. Archive `VelyraTVSideload` for `generic/platform=tvOS` with `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, and the three optional provider settings read from the environment without echoing them.

- [ ] **Step 3: Package atomically**

Remove only `$BUILD_ROOT`, recreate `$PACKAGE/Payload`, copy `Products/Applications/Velyra.app`, create a temporary IPA with `/usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload`, validate it, then move it to `$IPA` only on success.

- [ ] **Step 4: Add structural inspections**

Use `/usr/bin/unzip -Z1` and `/usr/libexec/PlistBuddy` to require `Payload/Velyra.app/Info.plist`, bundle ID `pt.ricardosoares.velyra.sideload`, no `.appex`, no `embedded.mobileprovision`, and no `_CodeSignature` directory. Use `codesign -d --entitlements :-` only when a signature exists; an unsigned app is the expected result.

- [ ] **Step 5: Emit checksum and machine-readable output**

Run `/usr/bin/shasum -a 256 "$IPA" > "$IPA.sha256"` and print exactly the IPA and checksum paths at the end.

- [ ] **Step 6: Document local and CI usage**

Document `SIDELOAD_OUTPUT_DIR`, optional provider settings, atvloadly signing, Personal Team seven-day expiry, the disabled cloud/dynamic Top Shelf behavior, and the fact that compiled native-client provider configuration is extractable from the IPA.

- [ ] **Step 7: Validate the script**

Run:

```bash
sh -n scripts/build_sideload_ipa.sh
python3 scripts/validate_project.py
scripts/build_sideload_ipa.sh
```

Expected on a healthy Xcode environment: `artifacts/Velyra-sideload.ipa` and `.sha256` exist; every inspection passes. On the current local machine, record the known Xcode framework failure honestly and defer the successful archive proof to GitHub Actions.

- [ ] **Step 8: Manual Git checkpoint**

Ask the user to commit with `build: package unsigned tvOS IPA`.

### Task 7: Phase verification

**Files:**
- Modify only files from Tasks 1–6 when verification reveals a defect.

- [ ] **Step 1: Run all non-Xcode checks fresh**

Run plist lint, Python validation, shell syntax, formatter lint, and `xcodegen generate`.

- [ ] **Step 2: Run available Xcode checks**

Run `xcodebuild -list`, full-target unsigned build, all XCTest, and the sideload packaging script on a healthy GitHub macOS runner. Expected: both targets compile, all tests pass, and IPA inspection succeeds.

- [ ] **Step 3: Inspect sensitive outputs**

Confirm source changes contain no provider values, Apple account values, certificates, provisioning profiles, `.p12` files, or private keys. Confirm the IPA intentionally contains only distributable native-client configuration supplied during release builds.

- [ ] **Step 4: Request review**

Provide the user with validation output, the list of changed files, the manual Apple TV checklist, and the suggested phase commit message `feat: complete tvOS sideload foundation` if they prefer a single squash commit.
