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

The introduction is a product tour, not an authentication form:

1. Velyra identity and cinematic experience.
2. Personalised home and content organisation.
3. Automatic iCloud synchronisation through the Apple ID configured in tvOS.
4. Optional Trakt device-code connection.
5. Completion and entry into the app.

The user can skip Trakt and connect later. iCloud failure must never block use; Velyra falls back to local settings.

## App shell

Top-level sections mirror familiar Apple media patterns while keeping a distinct Velyra identity:

- Home
- Search
- Library
- Addons
- Settings

The navigation floats above content using Liquid Glass where available. Content art and video remain dominant.

## Playback

AVPlayer is the primary engine for the best tvOS integration, accessibility support and Apple HDR/audio pipeline.

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
