# Performance contract

Performance is a release requirement, especially on Apple TV where focus updates and image-heavy rails must remain immediate.

## Networking

- Deduplicate identical in-flight image, TMDB metadata and addon requests.
- Cancel screen-scoped work when the user navigates away.
- Use pagination and progressive loading for large libraries and searches. TMDB enrichment is processed in bounded batches rather than launching hundreds of concurrent requests.
- Apply stale-while-revalidate behaviour to Home and Trakt snapshots.
- Use per-addon timeouts, health tracking and circuit breakers.
- Poll temporary Stremio linking every three seconds with cancellation, a
  two-minute bound and at most three concurrent manifest validations.
- Respect Trakt rate limiting and back off globally after HTTP 429.
- Reject unexpectedly large JSON, image and subtitle responses before decoding whenever response metadata permits.
- Detect offline transitions without blocking cached navigation and retry pending Trakt mutations when connectivity returns.

## Images and video

- Request artwork close to the displayed size.
- Downsample before decoding into UI images.
- Use bounded memory and disk caches.
- Clear memory-only image state on background or memory pressure.
- Never run multiple decorative background videos simultaneously.
- Stop decorative video when Reduce Motion is enabled or the scene is inactive.

## SwiftUI

- Keep stable identifiers for rails and cards.
- Avoid rebuilding complete Home sections for player progress ticks.
- Use lazy stacks and grids for long collections.
- Keep focusable controls lightweight and restore focus after navigation.
- Load cast, crew, recommendations and provider details only on the Details screen.
- Construct only the active Settings category and keep category grids/lists lazy.
- Coalesce rapid preference changes over 250 ms; backgrounding and explicit sync
  flush the latest complete snapshot immediately.
- Skip Top Shelf writes when IDs, artwork, progress and deep-link metadata are
  semantically unchanged.

## Playback

- Validate likely sources before committing to playback.
- Avoid retrying a failed source during the same playback session.
- Preserve time, audio and subtitle choices across failover.
- Parse external subtitles once and locate cues using indexed or binary-search access.

## Diagnostics

Diagnostics are opt-in and must not contain tokens, full stream URLs, request headers, viewing history or full addon addresses. They may include durations, cache state, source capabilities, anonymised error classes and local unclean-exit counters. Launch-health information remains on the device unless the user deliberately copies the report.
