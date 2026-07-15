# Release readiness checklist

This document separates implementation completeness from tasks that require Apple tooling, commercial credentials or licensed content.

## Implemented in source

- GitFlow and modular tvOS architecture.
- Cinematic onboarding, Home, Search, Details, Library, Addons, Player and Settings.
- Four interface languages.
- Accessibility and reduced-motion/transparency behaviour foundations.
- TMDB discovery and regional provider integration contract.
- Complete Trakt client surface with offline queue and cache.
- Addon validation, aggregation, ordering, health and configuration transfer.
- Smart source, audio and subtitle selection with failover.
- Embedded and external text subtitle support.
- Private CloudKit user-state model and lightweight iCloud preferences.
- Image pipeline, shared TMDB response cache, bounded Library enrichment, Home cache, offline network status, opt-in diagnostics, local launch-health monitoring and Top Shelf snapshot/extension.
- Granular iCloud sync management, per-domain conflict resolution and reset tombstones.
- Search filtering by media kind, year, rating and sort order.

## Requires external configuration

- Trakt application client identifier and secret.
- TMDB read access token.
- Apple Developer identifiers, app group and CloudKit container.
- Final privacy contact, terms and support URLs.
- Optional external crash-reporting provider, only if a privacy-reviewed opt-in service is selected; local diagnostics already work without one.
- Licensed artwork, app icon, screenshots and background loops.

## Requires macOS/Xcode or Apple TV hardware

- Generate and type-check the Xcode project against the current tvOS SDK.
- Run XCTest and UI tests.
- Validate focus, Siri Remote, VoiceOver and Top Shelf behaviour.
- Validate CloudKit schema and entitlements in the Apple environment.
- Test Dolby Vision, HDR, Atmos, frame-rate matching and real-world streams.
- Sign, archive and deliver through TestFlight.

## Deliberate technical boundaries

- Velyra does not bundle content or addons.
- Non-AVPlayer-compatible containers may require an independently deployed remux/transmux service.
- Text ASS/SSA is reduced to readable text; advanced styling and image-based subtitles need a separate rendering/remux path.
- Platform-specific audience rankings are only shown as official when an authorised source exists.
