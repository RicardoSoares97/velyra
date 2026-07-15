# Velyra feature matrix

This matrix is the source-level definition of product completeness. A feature marked **Implemented** exists in the repository and is covered by static validation and/or unit tests where it can be exercised without Apple tooling. It does not imply that the feature has been compiled or validated on an Apple TV.

IMDb integration is deliberately excluded from this release scope.

## Experience and navigation

| Capability | Source status | Notes |
|---|---|---|
| One-screen automatic onboarding | Implemented | No Velyra account or technical setup required. |
| Apple-style tvOS navigation | Implemented | Home, Search, Library, Addons and Settings. |
| Liquid Glass with accessible fallback | Implemented | Native glass on supported tvOS versions; material fallback otherwise. |
| Cinematic silent backgrounds | Implemented | Automatically disabled or reduced for accessibility preferences. |
| Four interface languages | Implemented | English, Portuguese (Portugal), Spanish and French. |
| Deep links | Implemented | Routes to movie, series and episode details. |
| Top Shelf extension | Implemented | Uses a privacy-safe shared snapshot. |

## Home and discovery

| Capability | Source status | Notes |
|---|---|---|
| Continue watching | Implemented | Backed by Trakt playback data and local cache. |
| Trending movies and series | Implemented | TMDB-backed with cached fallback. |
| Genre discovery | Implemented | Regional and localised. |
| Streaming-provider discovery | Implemented | Regional TMDB/JustWatch availability. |
| Regional Velyra Top 10 | Implemented | Clearly identified as a Velyra ranking, not official audience data. |
| Home personalisation | Implemented | Rails can be hidden and reordered, with iCloud sync. |
| Offline degraded Home | Implemented | Last successful feed remains available. |

## Search and details

| Capability | Source status | Notes |
|---|---|---|
| TMDB and addon search | Implemented | Results are merged and deduplicated. |
| Search history and suggestions | Implemented | Stored locally and removable by the user. |
| Media, year, rating and sort filters | Implemented | Applied before presentation and pagination. |
| Film and series details | Implemented | Localised metadata, trailers, cast, crew, recommendations and providers. |
| Seasons and episodes | Implemented | Addon/TMDB metadata is reconciled where available. |
| Trakt actions from details | Implemented | Watchlist, collection, history, watched state and rating. |

## Trakt

| Capability | Source status | Notes |
|---|---|---|
| Device-code authentication | Implemented | Tokens are stored in Keychain. |
| Refresh and revoke | Implemented | Includes expiry recovery. |
| Profile and activities | Implemented | Cached for resilient UI. |
| Playback progress | Implemented | Supports exact episode/media resume. |
| Watchlist, collection and history | Implemented | Paginated read/write operations. |
| Watched state and ratings | Implemented | Optimistic local updates with retry. |
| Personal lists | Implemented | Create, update, delete and mutate list items. |
| Scrobble start, pause and stop | Implemented | Player-linked and protected against duplicate/replaced items. |
| Offline mutation queue | Implemented | Persistent, compacted and retried on connectivity restoration. |
| Rate limiting and retries | Implemented | Shared request gate and bounded backoff. |
| Multi-device reconciliation | Implemented | Local snapshot, Trakt state and iCloud preferences merge deterministically. |

## Addons

| Capability | Source status | Notes |
|---|---|---|
| Manifest installation by URL | Implemented | HTTPS required outside local development. |
| Catalog, metadata, stream and subtitle resources | Implemented | Standard HTTP/JSON addon contract. |
| Aggregation and deduplication | Implemented | Partial addon failure does not block other addons. |
| Enable, disable and priority ordering | Implemented | Synced through private user settings. |
| Health and circuit breaker | Implemented | Shared across Search, Details and Player resolution. |
| Refresh, import and export | Implemented | Export excludes secrets and transient health data. |
| Per-addon diagnostics | Implemented | User-safe and redacted. |
| Arbitrary JavaScript/plugin execution | Not supported | Deliberate security and App Store boundary. |

## Playback

| Capability | Source status | Notes |
|---|---|---|
| Native AVKit playback | Implemented | AVPlayer and AVPlayerViewController are the primary path. |
| Automatic source ranking | Implemented | Compatibility precedes quality labels. |
| 4K, HDR, Dolby Vision and Atmos preference signals | Implemented | Actual format/profile support requires hardware validation. |
| Source validation and failover | Implemented | Preserves playback position and avoids loops. |
| Original audio preference | Implemented | Uses exact and base-language matching. |
| Regional and secondary subtitle languages | Implemented | Embedded tracks preferred before addon subtitles. |
| Manual source, audio and subtitle switching | Implemented | Available from player controls. |
| Subtitle timing and text size | Implemented | Persisted per content where applicable. |
| SRT, WebVTT and basic ASS/SSA text | Implemented | Advanced styling and image subtitles are outside the native text path. |
| MKV/raw torrent remux | External dependency | Requires a separately deployed, authorised remux/transmux service. |

## Library and offline behaviour

| Capability | Source status | Notes |
|---|---|---|
| Continue watching, watchlist, collection and history | Implemented | Searchable, sortable and filterable. |
| Ratings and personal lists | Implemented | Includes list management and item actions. |
| Optimistic mutations | Implemented | Immediate UI state with queued network synchronisation. |
| Connectivity awareness | Implemented | Non-blocking offline indicator and automatic recovery. |
| Cache clearing and granular reset | Implemented | Includes Home, TMDB, images, subtitles, addons and Trakt snapshots. |

## iCloud, privacy and diagnostics

| Capability | Source status | Notes |
|---|---|---|
| Lightweight iCloud preference mirror | Implemented | Uses NSUbiquitousKeyValueStore. |
| Private CloudKit user state | Implemented | Per-domain timestamps and per-content playback preferences. |
| Conflict-safe merging and reset tombstones | Implemented | Older devices cannot silently restore deleted preferences. |
| Keychain token storage | Implemented | OAuth tokens are excluded from CloudKit. |
| User-exportable diagnostics | Implemented | Redacts URLs, headers, credentials and tokens. |
| Local launch-health monitoring | Implemented | No third-party crash service or tracking. |
| Privacy manifest and policy draft | Implemented | Final public URLs and legal review remain external release tasks. |

## Performance and quality

| Capability | Source status | Notes |
|---|---|---|
| Image downsampling and bounded cache | Implemented | Responds to memory pressure. |
| TMDB response cache and request deduplication | Implemented | Uses endpoint-appropriate TTLs. |
| Bounded metadata enrichment | Implemented | Prevents unbounded concurrent work for large libraries. |
| HTTP response-size limits | Implemented | Shared, Trakt, TMDB and subtitle paths are bounded. |
| Task cancellation and stale-while-revalidate patterns | Implemented | Applied to the principal discovery flows. |
| Static validation | Implemented | Local script checks resources, translations, privacy and source hygiene. |
| Unit-test target | Implemented | Covers playback ranking, subtitles, Trakt queue, Cloud merge, addons, cache and diagnostics. |
| macOS/Xcode build and Apple TV validation | Deferred | Explicitly excluded until Apple tooling is available. |

## External configuration still required

The source cannot create or approve third-party accounts on behalf of the project. Before a signed release, the project owner must provide:

- Trakt application credentials;
- a TMDB read-access token;
- Apple Developer identifiers, app group and CloudKit container;
- final privacy, support and terms URLs;
- licensed icon, artwork, screenshots and cinematic background media.

These are configuration, licensing and distribution inputs rather than missing application features.
