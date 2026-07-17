# Top Shelf

The Top Shelf extension reads a privacy-limited snapshot from the shared app group.

## Sections

- Continue Watching, when Trakt playback items are available.
- Recommendations derived from the current Home feed.

Continue Watching is always first. Snapshot timestamps do not cause writes:
the shared file is replaced only when semantic item content changes.

## Data limits

The shared snapshot contains only the minimum title, artwork, media type, TMDB identifier, progress and Velyra deep link. It contains no Trakt token, addon URL, stream URL, subtitle URL, request header or private account detail.

## Deep links

Top Shelf items open `velyra://details` with stable media identifiers. Invalid or foreign URLs are rejected by the app parser.

## Degraded mode

When no snapshot exists, the extension returns no personalised content instead of inventing recommendations or exposing stale private state.
tvOS then uses the generated near-black Velyra fallback with subtle ribbon
lighting and no implied controls or third-party imagery.
