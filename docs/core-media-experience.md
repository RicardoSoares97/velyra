# Core media experience

## Scope

This feature connects discovery to playback without expanding the Trakt roadmap:

1. Home and Search select a `MediaItem`.
2. Details enriches the item with TMDB and installed-addon metadata.
3. Series expose addon-provided episodes when available.
4. The playback resolver aggregates streams and subtitles from every compatible addon.
5. The existing source selector ranks direct-play sources.
6. The native AVKit player starts the best compatible source.
7. Audio, embedded subtitles, addon subtitles and source remain changeable in the player.

## Identifiers

The resolver uses identifiers in this order:

1. IMDb (`tt...`), when available;
2. TMDB (`tmdb:<id>`);
3. the original addon identifier.

No identifier is invented when a source does not provide one.

## Error behaviour

- No addons: explain the single action needed instead of displaying a technical error.
- No streams: remain on Details and allow retry or another episode.
- One addon fails: continue with the remaining addons.
- One source fails: the player keeps position and tries the next ranked source.
- TMDB unavailable: Search and Details continue with addon metadata when possible.

## Privacy

The diagnostic panel never displays full stream URLs, request headers, tokens or manifest credentials.
