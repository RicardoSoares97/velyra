# Top Shelf evaluation

A Top Shelf extension can surface Continue Watching and one editorial rail without opening Velyra. It is intentionally postponed until real artwork, app-group storage and hardware focus testing exist.

## Acceptance conditions

- Uses an App Group, not private CloudKit access from the extension.
- Reads a small precomputed snapshot; no network requests during rendering.
- Contains no addon URLs, tokens or private technical metadata.
- Respects the selected interface language and content region.
- Falls back cleanly when no history exists.
- Every item deep-links to Details, never directly to an unvalidated stream.
