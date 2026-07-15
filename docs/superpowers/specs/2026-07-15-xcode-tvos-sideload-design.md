# Xcode tvOS Sideload Design

## Purpose

Prepare Velyra for repeatable Xcode builds and produce a tvOS IPA that atvloadly can sign and install with a free Apple ID, while preserving the existing paid-program architecture for a future App Store, TestFlight, or registered-device release.

## Constraints

- The current machine has Xcode 26.6, Swift 6.3.3, and the tvOS 26.5 SDK.
- The current user cannot change `xcode-select` or authorize installation of additional Xcode packages.
- No tvOS Simulator runtime is installed, so simulator execution and XCTest remain unavailable until an administrator installs one.
- The Apple account is a free Personal Team account. Its provisioning profiles expire after seven days and do not provide the advanced capabilities Velyra currently declares for iCloud, CloudKit, and App Groups.
- atvloadly performs signing and periodic reinstallation separately from the Xcode build process.
- Credentials, Apple account details, signing assets, provider tokens, and provisioning profiles must never enter the repository.

## Goals

1. Generate a valid Xcode project from `project.yml` with XcodeGen.
2. Keep the existing full-capability `VelyraTV` and `VelyraTopShelf` targets intact.
3. Add an explicit sideload target that does not require paid Apple capabilities.
4. Compile the sideload application against the installed tvOS SDK without code signing.
5. Package the unsigned application bundle into a structurally valid IPA for atvloadly.
6. Make the reduced sideload capability set clear inside the application.
7. Provide deterministic validation commands before and after future changes.

## Non-goals

- Installing or configuring atvloadly itself.
- Storing an Apple ID or password in scripts, Xcode settings, or CI.
- Bypassing Apple provisioning restrictions.
- Enabling iCloud, CloudKit, App Groups, or Top Shelf with a free Personal Team.
- Uploading the application to App Store Connect or TestFlight.
- Installing an Xcode simulator runtime without administrator authorization.

## Considered approaches

### Dedicated sideload target

Add `VelyraTVSideload` beside the existing targets. It uses the same application sources and resources but has a distinct bundle identifier, no Top Shelf dependency, an entitlement file with no restricted capabilities, and a `VELYRA_SIDELOAD` compilation condition.

This is the selected approach because the reduced capability boundary is explicit in Xcode and difficult to confuse with the future full release.

### Configuration-only switching

Use one target with build-configuration-specific entitlements and settings. This reduces target duplication but makes conditional extension embedding and archive selection less obvious. A wrongly selected configuration could create an IPA with unsupported entitlements.

### Post-archive entitlement removal

Build the full application and strip entitlements or extensions after archiving. This is rejected because it hides the actual runtime capability set, is fragile across Xcode versions, and can leave signing metadata inconsistent.

## Xcode project structure

`project.yml` will continue to define:

- `VelyraTV`: the full application target;
- `VelyraTopShelf`: the Top Shelf extension;
- `VelyraTVTests`: the unit-test target;
- `VelyraTVSideload`: the new reduced-capability application target.

The sideload target will:

- use the same Swift sources under `VelyraTV` and `Shared` where compatible;
- use the existing String Catalog, Privacy Manifest, and media resources;
- exclude the Top Shelf extension dependency;
- use `pt.ricardosoares.velyra.sideload` as its repository-default bundle identifier;
- set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` to include `VELYRA_SIDELOAD`;
- use `VelyraTV/Resources/VelyraTVSideload.entitlements`;
- support tvOS 17 and later, matching the full target;
- expose a shared `VelyraTVSideload` scheme with Debug, build, and archive actions.

The generated `Velyra.xcodeproj` remains ignored. `project.yml` is the source of truth.

## Runtime capability boundary

A small source-level capability definition will expose whether the current binary supports:

- iCloud preference mirroring;
- private CloudKit user state;
- Top Shelf snapshot publishing.

For the full target, these capabilities remain enabled. For `VELYRA_SIDELOAD`, they are disabled at compile time.

The sideload application will:

- use `LocalPreferencesStore` as its preference store;
- keep playback and addon preferences on the Apple TV;
- avoid creating or querying a CloudKit container;
- avoid reading or writing `NSUbiquitousKeyValueStore`;
- avoid publishing a Top Shelf snapshot;
- keep Trakt OAuth tokens in the application Keychain;
- retain Trakt, addons, Home, Search, Library, Details, playback, subtitles, diagnostics, and local caches.

Existing persisted preferences that request iCloud synchronisation will be normalized to local-only behaviour when loaded by the sideload binary. The full target will not change those semantics.

## User experience

The Settings interface will identify the build as a sideload edition and explain that iCloud synchronisation and Top Shelf require a paid Apple Developer configuration. Controls that would attempt cloud operations will be hidden or disabled for the sideload target.

Onboarding will not promise iCloud synchronisation in the sideload target. It will continue to explain automatic source, audio, and subtitle selection.

All new user-facing text will be added to the String Catalog in English, Portuguese (Portugal), Spanish, and French.

## Tooling

XcodeGen and `swift-format` will be installed through the existing Homebrew installation when permissions allow. No command will modify `xcode-select`.

The repository will expose a build script under `scripts/build_sideload_ipa.sh`. It will:

1. fail with a clear message if XcodeGen or required Apple command-line tools are missing;
2. run `scripts/validate_project.py`;
3. run `swift-format lint` across application, tests, extension, and shared sources;
4. generate `Velyra.xcodeproj` from `project.yml`;
5. compile/archive `VelyraTVSideload` for `generic/platform=tvOS` with code signing disabled;
6. copy the archived `.app` into a temporary `Payload` directory;
7. create an IPA with `/usr/bin/ditto`;
8. inspect the IPA structure and application metadata;
9. place the final artifact under an ignored `artifacts/` directory.

The script will accept build-setting overrides for Trakt and TMDB credentials through the environment or command line without writing them to disk. Blank credentials remain valid for compilation and result in the application's existing unconfigured-service states.

## IPA and signing model

The produced IPA is intentionally unsigned. It contains one tvOS application bundle and no Top Shelf extension. atvloadly is responsible for applying its Personal Team signature, installing the application, and renewing it before the seven-day profile expires.

The build process will verify that the sideload application does not declare:

- `com.apple.developer.icloud-container-identifiers`;
- `com.apple.developer.icloud-services`;
- `com.apple.developer.ubiquity-kvstore-identifier`;
- `com.apple.security.application-groups`.

The application must not rely on atvloadly to remove unsupported entitlements.

## Validation strategy

Validations that do not require a simulator runtime are mandatory:

- `python3 scripts/validate_project.py`;
- Swift syntax parsing for application, extension, shared sources, and tests;
- `swift-format lint` once installed;
- `xcodegen generate`;
- `xcodebuild -list` against the generated project;
- unsigned compilation/archive for `generic/platform=tvOS`;
- IPA ZIP structure inspection;
- Info.plist and entitlement inspection;
- regression compilation of the full `VelyraTV` target with code signing disabled.

`xcodebuild test` will run when a tvOS Simulator runtime becomes available. Until then, inability to execute XCTest is reported explicitly and is not represented as a passing test run.

Physical-device checks after atvloadly installation include:

- launch and onboarding;
- focus navigation with the Siri Remote;
- local preference persistence after relaunch;
- Trakt connection and Keychain session restoration;
- addon installation and discovery;
- source resolution and AVKit playback;
- confirmation that cloud and Top Shelf controls are absent or explanatory;
- application renewal through atvloadly.

## Error handling

The build script stops on the first failed validation and prints the failing stage. Temporary archive and packaging directories are isolated from source files. An incomplete IPA is never left at the final artifact path.

Runtime attempts to access unavailable cloud services are prevented by the capability boundary rather than ignored after CloudKit failures. Network or credential failures retain the application's existing recoverable states.

## Security and privacy

- The repository contains no signing identity, provisioning profile, Apple account credential, device pairing record, or atvloadly state.
- The IPA build does not print Trakt, TMDB, addon, or stream credentials.
- Keychain remains device-local.
- The sideload build does not imply that atvloadly is an Apple-supported distribution channel.
- Users are responsible for using content and third-party services they are authorized to access.

## Future paid-program path

When an Apple Developer Program membership becomes available, the existing full targets remain the starting point. The owner can configure the application identifier, App Group, iCloud container, CloudKit schema, Top Shelf extension, signing certificates, provisioning, archive export, TestFlight, and App Store distribution without undoing the sideload implementation.

The sideload target remains useful as a local-only diagnostic build and must not replace the full release target.

## Acceptance criteria

- XcodeGen generates all four targets and both application schemes without warnings that invalidate the project.
- `VelyraTVSideload` compiles and archives against the installed tvOS SDK with signing disabled.
- The generated IPA contains `Payload/Velyra.app` and no `.appex` bundle.
- The sideload app carries none of the restricted iCloud or App Group entitlements.
- The full target still includes its original iCloud and Top Shelf configuration.
- The sideload UI does not offer cloud actions that cannot succeed.
- Existing static validation and all available build validations pass.
- XCTest results are reported only when a tvOS Simulator runtime is present.
- No secret or local signing artifact is added to the repository.

## GitFlow delivery

Implementation occurs on `feature/xcode-sideload`. After review and successful available validations, the feature is integrated into `develop`. `main` remains untouched.
