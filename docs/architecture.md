# Architecture

## Product shape

Velyra is a native tvOS client. It does not use a Velyra username/password account. Identity and synchronisation responsibilities are intentionally separated:

- **Apple ID / iCloud**: app settings, language, themes, addon manifests and Velyra-owned preferences.
- **Trakt**: viewing history, watchlist, watched state, playback progress and scrobbling.
- **Keychain**: OAuth access and refresh tokens.
- **Addon services**: remote catalogues, metadata, streams and subtitles explicitly installed by the user.

## Layers

```text
Presentation
├── SwiftUI screens
├── Liquid Glass and fallback materials
├── Focus-driven TV components
├── Accessibility semantics
└── AVKit player presentation

Application
├── AppState
├── Onboarding flow
├── Navigation state
├── Trakt session and sync coordinator
└── iCloud settings orchestration

Domain
├── Media identity
├── Addon contracts
├── Stream selection rules
├── Playback progress events
└── Sync conflict policies

Data
├── URLSession
├── Trakt API
├── Addon repositories
├── NSUbiquitousKeyValueStore
├── CloudKit private database
├── UserDefaults
└── Keychain
```

## Onboarding without a login

The introduction is one calm decision, not a configuration wizard. It explains that Velyra automatically chooses a compatible source, original audio and regional subtitles. The primary action applies recommended settings and opens the app. Trakt is optional and can be connected on the same screen or later in Settings.

iCloud synchronisation uses the Apple ID already configured in tvOS. iCloud failure never blocks use; Velyra falls back to local settings.

## App shell

Top-level sections mirror familiar Apple media patterns while keeping a distinct Velyra identity:

- Home
- Search
- Library
- Addons
- Settings

The navigation floats above content using Liquid Glass where available. Content art and video remain dominant.

## Playback

AVPlayer and AVPlayerViewController are the primary engine and presentation for native tvOS integration, accessibility, system playback behaviour and Apple HDR/audio pipelines.

The smart-playback domain ranks sources independently from the UI, validates the selected asset through AVFoundation, selects media tracks and preserves position during source failover. See `docs/smart-playback.md`.

The future playback coordinator will choose between:

1. direct AVPlayer playback;
2. an optional remux/transmux companion path;
3. a documented fallback engine for unsupported sources.

Dolby Vision and Dolby Atmos badges must only be shown after format detection. Marketing labels must never be inferred from a filename alone.

## iCloud conflict policy

For lightweight preferences, the most recent complete preferences snapshot wins. Before broader release this will evolve to per-setting timestamps so a language change does not overwrite a newer addon update.

Large or independently editable records will use CloudKit private records with explicit modification dates and deterministic merging.

## Trakt reliability

Trakt integration requires:

- device-code OAuth;
- automatic token refresh;
- Keychain persistence;
- rate-limit handling;
- retry with backoff;
- idempotent progress events;
- local outbound queue when temporarily offline;
- reconciliation on app activation;
- deduplication of start/pause/stop events;
- final watched-state confirmation near completion.

## Metadata fusion

Rich title metadata is normalized from TMDB and addon metadata, while Trakt remains the source of truth for personal state.
