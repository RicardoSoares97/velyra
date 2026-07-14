# Architecture

## Initial approach

Velyra starts as a native SwiftUI tvOS application. The first proof of concept keeps the architecture intentionally small while preserving clear boundaries for future growth.

```text
Presentation
├── SwiftUI screens
├── TV focus components
└── AVKit player presentation

Domain
├── Addon models and use cases
├── Stream selection rules
├── Trakt synchronisation
└── Playback decisions

Data
├── URLSession HTTP client
├── Addon repositories
├── Trakt API
└── Local persistence
```

## Playback strategy

AVPlayer is the primary playback engine because it offers the best integration with tvOS, system controls and Apple's HDR/audio pipeline.

A future playback coordinator will inspect each source and choose between:

1. direct AVPlayer playback;
2. remux/transmux through an optional companion service;
3. an alternative player fallback for unsupported containers.

Dolby Vision and Dolby Atmos are source-, profile-, device- and HDMI-chain-dependent. Velyra must report the detected format honestly rather than displaying a generic Dolby badge.

## Addons

The first supported addon model should be remote HTTP/JSON endpoints. The application must not download or execute arbitrary third-party code.

Expected capabilities:

- manifest;
- catalogues;
- metadata;
- stream resolution;
- subtitle resolution.

## Trakt

Use device-code authentication, which is appropriate for television interfaces. Tokens should be stored in Keychain and refreshed automatically.

Initial features:

- watchlist;
- history;
- watched state;
- playback progress;
- scrobble start, pause and stop.

## Future sharing with Android TV

Do not introduce Kotlin Multiplatform until the tvOS proof of concept is validated. Once the domain model is stable, evaluate whether addon and Trakt logic should become a shared KMP module.
