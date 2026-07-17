# Fallback and remux architecture

Direct AVPlayer playback remains the preferred path. Unsupported containers must not silently switch to an opaque third-party engine.

## Planned decision order

1. Direct AVPlayer playback.
2. Server-side or companion-device transmux that does not re-encode compatible video/audio.
3. Optional fallback engine only after legal, App Review, Dolby and accessibility validation.

## Constraints

- No executable addon code is downloaded or run.
- Credentials remain in Keychain.
- A remux service must be user-controlled and explicitly configured.
- The app must state when Dolby Vision, Atmos or subtitle styling may be lost.
- Playback diagnostics must identify the path as Direct, Remux or Fallback without exposing infrastructure addresses.

This feature does not yet implement a remux server. MKV, WebM, torrent hashes and non-web-ready streams remain excluded from automatic direct playback.
