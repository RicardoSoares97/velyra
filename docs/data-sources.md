# Data sources and ownership boundaries

Velyra keeps public metadata, personal state, playback sources and device preferences deliberately separate. This prevents duplicate information, contradictory state and unnecessary data sharing.

## Source responsibilities

| Domain | Primary source | Local responsibility |
| --- | --- | --- |
| Discovery, trending metadata and backdrops, genres, trailer metadata and regional providers | TMDB / provider attribution data | Cache, localisation, policy enforcement and presentation; Velyra does not redistribute trailer or video bytes |
| Personal history, playback progress, watchlist, ratings, collection and lists | Trakt | Offline queue, optimistic UI and reconciliation |
| Catalogues, metadata extensions, streams and subtitles | User-installed HTTP/JSON addons | Validation, aggregation, health, priority and deduplication |
| Stremio addon collection | Official Stremio link v2 and `addonCollectionGet` read endpoint | User-initiated preview and selective manifest import; no collection writes |
| Theme, language, Home layout and playback preferences | Velyra | Local persistence and private iCloud synchronisation |
| Onboarding fallback artwork and motion | Velyra | Original art plus native SwiftUI composition and motion |
| Authentication tokens | Trakt | Device Keychain only |

## Merge rules

1. Personal state from Trakt never overwrites public metadata fields.
2. Addon metadata fills missing fields but does not silently replace a complete TMDB result.
3. Ratings always retain their source label.
4. User playback preferences win over automatic defaults for the same content.
5. iCloud settings merge independently by domain (appearance, localisation, playback, addons, Home and privacy), while per-content playback preferences merge by their own timestamps. A reset timestamp prevents deleted playback preferences from reappearing from an older device.
6. Duplicate media are matched by stable external identifiers before title/year fallback.

## Attribution

TMDB and regional provider availability attribution must remain visible where their data is used. Velyra Top 10 is identified as a Velyra editorial ranking rather than an official cross-service audience chart.

## Onboarding decorative trends

TMDB supplies the daily trending series/movie metadata and remote backdrops used as optional decorative onboarding layers. Velyra owns the original `OnboardingFallback` artwork and the native SwiftUI motion that composes those layers. The local fallback is rendered first, so onboarding does not depend on TMDB, a configured credential, cached metadata or a successful image request.

The onboarding metadata cache is scoped to language and region:

- a matching snapshot is fresh for up to and including six hours;
- after six hours and up to and including seven days, it is an eligible stale snapshot whenever refresh produces no usable candidates, whether from endpoint errors, empty or filtered responses, or missing usable backdrops;
- corrupt snapshots are deleted when decoding fails, and expired snapshots are deleted after the seven-day limit; a locale mismatch returns missing for the current request but retains the stored snapshot for its matching language/region; an unconfigured credential or an offline refresh can still use a fresh matching snapshot or eligible stale snapshot, but none of these states ever blocks onboarding;
- metadata alone is not displayed: remote image pixels are published to the onboarding view only after the corresponding backdrop prefetch succeeds.

When a refresh is needed, daily series and movie requests fail independently. Successful results are converted only when they have a usable backdrop, then series and movie candidates are interleaved. The repository makes a deterministic selection from that combined list using the seed `UTC day|language|region`; the view publishes at most the first successfully prefetched item. A failure of one endpoint can therefore still supply decoration from the other. If refresh yields no usable candidates, the repository returns an eligible stale snapshot when available; otherwise it returns no remote metadata.

Fresh or stale metadata during an unconfigured/offline run may still produce a remote layer when the corresponding image pixels are available to the prefetch path from the image cache. If metadata is unavailable, prefetch fails, or pixels are not cached, only the bundled original fallback is shown.

Decorative motion follows a fallback-first accessibility policy. Reduce Motion removes drifting and animated transitions and shows at most one static remote backdrop over the original fallback. Reduce Transparency strengthens the central opaque treatment used to protect legibility. If remote content is absent or rejected, the original art remains the complete experience.

## Stremio addon import boundary

Velyra requests a temporary code from
`https://link.stremio.com/api/v2/create`, reads authorization through the
matching v2 read endpoint, and fetches only `addonCollectionGet`. The temporary
auth key stays in memory, is cleared before logout is attempted, and is never
written to preferences, iCloud, diagnostics or logs. Imported HTTPS manifest
URLs are appended to existing Velyra addons after preview and validation.
Velyra has no Stremio collection-write API.

## Trailer provider policy

TMDB supplies trailer metadata only. YouTube is an external provider, identified visibly in the user-initiated trailer action. A video is eligible only when TMDB marks its type as `Trailer`, `official` is `true`, its site is `YouTube`, and its key is nonempty after trimming. The app then constructs the provider URL and submits it through SwiftUI `OpenURL`.

Velyra does not use `AVPlayer` for trailers and does not extract, proxy, download, cache, redistribute or bypass provider video bytes or controls. If the system rejects the external URL, Details keeps the failure recoverable: it displays the provider-unavailable message and queues the same message as a VoiceOver announcement. Trailer metadata never feeds background video or autoplay.
