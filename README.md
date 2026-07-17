# Velyra

Velyra is a native, cinematic media client for Apple TV. It combines an Apple-first tvOS experience with addon-based discovery, complete Trakt integration, iCloud preference synchronisation and accessible playback.

> Current status: product architecture and interactive tvOS foundation. The
> complete production source passes a direct Swift 6/tvOS 17 simulator-SDK
> type-check and XcodeGen generation. Authoritative `xcodebuild`, XCTest, unsigned
> IPA packaging, and device evidence remain pending on GitHub-hosted Xcode while
> this Mac has a local Xcode/DVT framework mismatch.

## Product principles

- Native SwiftUI and AVPlayerViewController experience designed for the Siri Remote.
- Liquid Glass on tvOS 26+, with accessible material fallbacks on tvOS 17–25.
- Cinematic, silent background loops with restrained blur and strong readability overlays.
- No separate Velyra login: iCloud uses the Apple ID already configured on the device.
- Trakt device authentication, watchlist, history, progress and scrobbling.
- HTTP/JSON addons for authorised catalogues, metadata, streams and subtitles.
- Multi-language interface: English, Portuguese (Portugal), Spanish and French from the first foundation.
- Accessibility, focus restoration and reduced-motion behaviour treated as release requirements.
- Two-stage immersive onboarding with welcome and setup, including automatic source, original-audio and regional-subtitle defaults.
- Smart source validation and failover that preserves playback position.
- No bundled, hosted or promoted media content.

## Technology

- Swift 6
- SwiftUI
- tvOS 17+
- Liquid Glass APIs on tvOS 26+
- AVFoundation / AVKit
- CloudKit and iCloud key-value storage
- Keychain Services
- URLSession
- String Catalogs (`.xcstrings`)
- XcodeGen

## Architecture

```text
VelyraTV/
├── App/                         # App lifecycle, root state and routing
├── Core/
│   ├── Accessibility/           # Reduced motion and accessible interaction
│   ├── DesignSystem/            # Colour, glass, focus and control tokens
│   ├── Localization/            # Runtime language selection
│   ├── Media/                   # Silent looping background video
│   ├── Networking/              # Shared HTTP layer
│   ├── Persistence/             # Local and iCloud preferences
│   ├── Playback/                # Source ranking, media tracks and failover
│   ├── Security/                # Keychain storage
│   └── Sync/                    # Apple ID / iCloud availability
├── Features/
│   ├── Onboarding/
│   ├── Shell/
│   ├── Home/
│   ├── Search/
│   ├── Library/
│   ├── Addons/
│   ├── Trakt/
│   ├── Player/
│   └── Settings/
└── Resources/
    ├── Assets.xcassets          # Generated app icon, Top Shelf and onboarding assets
    ├── Localizable.xcstrings
    ├── PrivacyInfo.xcprivacy
    ├── VelyraTV.entitlements
    └── Media/
```

## GitFlow

- `main`: App Store/TestFlight release history only.
- `develop`: integration branch for the next release.
- `feature/*`: isolated product work branched from `develop`.
- `release/*`: release hardening and version preparation.
- `hotfix/*`: urgent production fixes branched from `main`.

The cinematic, smart-playback, Home and core media foundations are integrated into `develop`. The active product-completion work extends Trakt, Library, offline resilience, player controls and release readiness.

### Automated tvOS delivery

The `tvOS Build` workflow validates pushes and pull requests across the GitFlow
integration branches. Eligible same-repository runs retain an unsigned sideload
IPA and SHA-256 checksum for 14 days; fork pull requests build and test without
uploading artifacts.

A release starts only from a stable `vMAJOR.MINOR.PATCH` tag on the matching
`main` commit. The tag workflow independently validates and rebuilds the app,
creates or resumes a draft GitHub Release, verifies its complete asset list, and
only then publishes it. Each release contains exactly:

- `Velyra-sideload-vMAJOR.MINOR.PATCH.ipa`, unsigned;
- `Velyra-sideload-vMAJOR.MINOR.PATCH.ipa.sha256`;
- `CHANGELOG-vMAJOR.MINOR.PATCH.md`, alongside categorized generated notes.

Configure the repository secrets `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`, and
`TMDB_READ_ACCESS_TOKEN` before tagging. They must belong to a restricted,
monitored, rotatable distributed native client because their compiled values can
be extracted from the public IPA. Apple credentials and signing material are not
used by either workflow. atvloadly performs Personal Team signing and installation;
the user remains responsible for re-signing and reinstalling when a free profile
expires.

The exact GitFlow release sequence, repository protection, labels, and recovery
procedure are documented in `docs/gitflow.md` and `docs/release-readiness.md`.

## Apple platform contract

`docs/apple-platform-standards.md` defines mandatory acceptance criteria for every feature and pull request. Native components, accessibility, localisation, privacy, focus and performance are release gates.

## Generate the Xcode project

A Mac with the current stable Xcode is required.

```bash
brew install xcodegen
xcodegen generate
open Velyra.xcodeproj
```

## Build the unsigned sideload IPA

A Mac with the current stable Xcode and XcodeGen from Homebrew is required:

```bash
brew install xcodegen
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build_sideload_ipa.sh
```

Setting `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` selects the full Xcode toolchain for this command without administrator access or changing `xcode-select`. Override the artifact directory when needed:

```bash
SIDELOAD_OUTPUT_DIR=/path/to/output scripts/build_sideload_ipa.sh
```

`TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`, and `TMDB_READ_ACCESS_TOKEN` are optional environment settings. The script transfers them through a temporary protected xcconfig and does not print their values. They are native-client configuration: once compiled, they can be extracted from the public IPA. GitHub Secrets keep values out of source and logs, but cannot make compiled values confidential.

The result is an unsigned `Velyra-sideload.ipa` plus its SHA-256 checksum. atvloadly is responsible for Personal Team signing and installation. A free Personal Team profile typically has a seven-day expiry, so the app must be re-signed and reinstalled periodically.

The sideload edition stores settings locally and has no iCloud preferences, CloudKit, App Groups, or dynamic Top Shelf. The full `VelyraTV` target remains available for a paid Apple Developer configuration. The current local Xcode/DVT framework mismatch prevents authoritative local archives; GitHub-hosted macOS is authoritative until the local Xcode installation is repaired.

Never place an Apple credential, signing certificate, provisioning profile or atvloadly state in the repository or build artifacts. Optional distributed provider configuration follows the separate native-client boundary below.

## Trakt configuration

Do not commit credentials. Supply optional Trakt/TMDB provider values only as environment inputs to `scripts/build_sideload_ipa.sh`, using a secret-capable local or CI environment, then invoke the script normally:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build_sideload_ipa.sh
```

The script copies those inputs into a mode-0600 temporary xcconfig, unsets the provider environment variables before invoking validation, XcodeGen and Xcode build tools, and removes the temporary file on success or failure. Provider values are not stored in the repository, not printed to logs, and not published as a standalone xcconfig or intermediate output. They are never passed as xcodebuild command-line settings; do not append them to the command above or invoke `xcodebuild` with them directly.

The values are intentionally embedded in the built app Info.plist and IPA and are therefore extractable from every distributed build. Treat them only as distributed-native credentials: enforce provider-side restrictions, monitor their use and keep them rotatable. A local secret store or CI secret protects the inputs and logs, not the compiled client.

OAuth tokens are stored in Keychain and are deliberately excluded from iCloud synchronisation.

## Home and discovery

The Home architecture now supports:

- cinematic hero artwork and silent video fallback;
- Trakt-powered continue watching;
- movie and series trending rails;
- combined genre filters;
- streaming-service filters scoped to the device region;
- Velyra Top 10 movie and series rails for locally available content;
- mandatory TMDB and JustWatch attribution.

`Velyra Top 10` is an editorial regional ranking, not an official cross-service audience chart. Platform-owned rankings will be identified separately when integrated.

## Core media flow

The current implementation connects:

```text
Home / Search
→ Cinematic Details
→ Installed addon metadata and episodes
→ Aggregated streams and subtitles
→ Automatic Apple-compatible source ranking
→ Native AVKit player
```

The player exposes source, audio, embedded subtitles and addon subtitles without asking users to understand codecs or containers. See `docs/core-media-experience.md`.

## iCloud

The entitlements expect this container:

```text
iCloud.pt.ricardosoares.velyra
```

Lightweight preferences are mirrored through `NSUbiquitousKeyValueStore`, while a private CloudKit record stores the complete user-owned settings state and per-content playback preferences. Conflicts merge by settings domain and timestamp. Velyra does not receive the Apple ID email or password.

## Media assets

The generated asset catalog provides the Velyra app icon, static Top Shelf artwork and `OnboardingFallback`. `ImmersiveOnboardingBackdropView` keeps that original fallback rendered immediately, adds native SwiftUI motion when allowed, and can layer optional prefetched TMDB side backdrops without blocking onboarding. No MP4 is required to build or run. Optional MP4 background loops must never contain copyrighted series or film clips without explicit distribution rights. See `VelyraTV/Resources/Media/README.md` for optional names and accessibility rules.

## Branding

- Product: **Velyra**
- Bundle identifier: `pt.ricardosoares.velyra`
- iCloud container: `iCloud.pt.ricardosoares.velyra`
- Primary colour: `#DD571C`
- Origin line: **Designed in Portugal / Concebida em Portugal**

## Licensing boundary

This repository is an independent clean-room foundation. Do not copy GPL-licensed Nuvio source code into it unless the distribution and licensing strategy is deliberately changed to comply with GPLv3.

## Product-completion status

The source now includes the complete non-IMDb product foundation: paginated Trakt library and mutations, offline queue with connectivity recovery, Search and Library filters, rich Details, shared addon health and transfer, private CloudKit state with conflict-safe resets, bounded metadata enrichment, image and TMDB response caching, diagnostics, Home personalisation, smart playback, external text subtitles and a Top Shelf extension.

Implementation completeness is not the same as Apple-platform validation. See `docs/release-readiness.md` for the exact split between source work, external credentials and tasks deliberately deferred until a Mac/Xcode and Apple TV are available.

Additional operating contracts:

- `docs/data-sources.md`
- `docs/performance.md`
- `docs/trakt-integration.md`
- `docs/top-shelf.md`
- `docs/release-readiness.md`
- `docs/feature-matrix.md`
