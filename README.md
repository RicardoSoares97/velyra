# Velyra

Velyra is a premium, TV-first media client for Apple TV, focused on a native tvOS experience, addon-based discovery, Trakt synchronisation, and high-quality playback.

> Status: initial architecture and tvOS proof of concept.

## Product principles

- Native Apple TV interaction with excellent focus behaviour.
- AVPlayer-first playback for the best tvOS integration.
- Dolby Vision and Dolby Atmos when the source and device chain are compatible.
- Addon-based catalogues and stream resolution using user-configured services.
- Trakt device authentication, history, watchlist and scrobbling.
- Light and dark themes built around Velyra Orange `#DD571C`.
- No bundled or hosted media content.

## Technology

- Swift 6
- SwiftUI
- tvOS 17+
- AVFoundation / AVKit
- URLSession
- XcodeGen for reproducible Xcode project generation

## Repository structure

```text
VelyraTV/
├── App/
├── Core/
│   ├── DesignSystem/
│   └── Networking/
├── Features/
│   ├── Home/
│   └── Player/
└── Resources/

docs/
├── architecture.md
├── design-system.md
├── legal-boundaries.md
└── roadmap.md
```

## Generate the Xcode project

A Mac with Xcode is required for this step.

```bash
brew install xcodegen
xcodegen generate
open Velyra.xcodeproj
```

## Build

```bash
xcodebuild \
  -project Velyra.xcodeproj \
  -scheme VelyraTV \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  build
```

## Branding

- Product name: **Velyra**
- Repository: `velyra`
- Bundle identifier: `pt.ricardosoares.velyra`
- Primary colour: `#DD571C`

## Important

The project is currently an independent clean-room foundation. Do not copy GPL-licensed Nuvio source code into this repository until the distribution and licensing strategy is explicitly decided.
