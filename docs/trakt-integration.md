# Trakt integration

## Scope

Velyra supports device-code authentication, token refresh and revocation, user profile, playback progress, watchlist, collection, history, watched state, ratings, personal lists and scrobbling.

## Offline-first behaviour

- Reads use a persisted snapshot so the Library can open without a network connection.
- Mutations update the local snapshot optimistically.
- Failed mutations are saved to an application-support queue.
- Repeated mutations for the same media and family are compacted so the newest user intent wins.
- Queue items retain attempt count and a privacy-safe error summary.
- The user can retry failed changes from Settings or Library.
- Connectivity restoration automatically retries eligible queued changes and refreshes the cached projection.

## Synchronisation

1. Restore the Keychain session.
2. Show cached state immediately.
3. Drain eligible queued mutations.
4. Fetch paginated remote state.
5. Replace the cache with the reconciled snapshot.
6. Refresh Home, Library and Top Shelf projections.

HTTP 401 invalidates the local authorisation state. HTTP 429 opens a shared request gate using the server retry interval. Transient errors use bounded exponential backoff.

## Scrobbling

- `start` is sent when meaningful playback begins.
- `pause` is sent on a real pause or interruption.
- Periodic progress updates are rate-limited.
- `stop` is sent on completion or exit with the latest progress. End-of-item notifications are scoped to the active player item so decorative or replaced players cannot create false completions.
- Scrobbling must never block local playback.

## Security

OAuth tokens are stored in Keychain and are not copied to iCloud, diagnostics, logs or Top Shelf data.
