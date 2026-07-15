# Data sources and ownership boundaries

Velyra keeps public metadata, personal state, playback sources and device preferences deliberately separate. This prevents duplicate information, contradictory state and unnecessary data sharing.

## Source responsibilities

| Domain | Primary source | Local responsibility |
| --- | --- | --- |
| Discovery, artwork, genres, trailers and regional providers | TMDB / provider attribution data | Cache, localisation and presentation |
| Personal history, playback progress, watchlist, ratings, collection and lists | Trakt | Offline queue, optimistic UI and reconciliation |
| Catalogues, metadata extensions, streams and subtitles | User-installed HTTP/JSON addons | Validation, aggregation, health, priority and deduplication |
| Theme, language, Home layout and playback preferences | Velyra | Local persistence and private iCloud synchronisation |
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
