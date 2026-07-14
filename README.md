# Velyra

Velyra is a native, cinematic media client for Apple TV. It combines an Apple-first tvOS experience with addon-based discovery, complete Trakt integration, iCloud preference synchronisation and accessible playback.

> Current status: product architecture and interactive tvOS foundation. The project has not yet been compiled on macOS/Xcode.

## Product principles

- Native SwiftUI and AVKit experience designed for the Siri Remote.
- Liquid Glass on tvOS 26+, with accessible material fallbacks on tvOS 17–25.
- Cinematic, silent background loops with restrained blur and strong readability overlays.
- No separate Velyra login: iCloud uses the Apple ID already configured on the device.
- Trakt device authentication, watchlist, history, progress and scrobbling.
- HTTP/JSON addons for authorised catalogues, metadata, streams and subtitles.
- Multi-language interface: English, Portuguese (Portugal), Spanish and French from the first foundation.
- Accessibility, focus restoration and reduced-motion behaviour treated as core requirements.
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

The cinematic foundation has been integrated into `develop`. The current Home and discovery work lives on `feature/home-discovery`.

## Generate the Xcode project

A Mac with the current stable Xcode is required.

```bash
brew install xcodegen
xcodegen generate
open Velyra.xcodeproj
```

## Trakt configuration

Do not commit credentials. Pass the build settings locally or through CI secrets:

```bash
xcodebuild \
  -project Velyra.xcodeproj \
  -scheme VelyraTV \
  TRAKT_CLIENT_ID='...' \
  TRAKT_CLIENT_SECRET='...' \
  TMDB_READ_ACCESS_TOKEN='...' \
  build
```

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

## iCloud

The entitlements expect this container:

```text
iCloud.pt.ricardosoares.velyra
```

Lightweight preferences are mirrored through `NSUbiquitousKeyValueStore`. The architecture reserves private CloudKit records for larger user-owned state. Velyra does not receive the Apple ID email or password.

## Media assets

Copyrighted series or film clips must never be committed without explicit rights. See `VelyraTV/Resources/Media/README.md` for the required background-loop names and accessibility rules.

## Branding

- Product: **Velyra**
- Bundle identifier: `pt.ricardosoares.velyra`
- iCloud container: `iCloud.pt.ricardosoares.velyra`
- Primary colour: `#DD571C`
- Origin line: **Designed in Portugal / Concebida em Portugal**

## Licensing boundary

This repository is an independent clean-room foundation. Do not copy GPL-licensed Nuvio source code into it unless the distribution and licensing strategy is deliberately changed to comply with GPLv3.
