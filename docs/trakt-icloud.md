# Trakt and iCloud

## Why both exist

Trakt and iCloud solve different problems and must not overwrite each other.

### Trakt owns

- watched history;
- watchlist;
- playback progress;
- scrobbling;
- collection state supported by Trakt.

### iCloud owns

- Velyra theme;
- selected interface language;
- background-video preference;
- playback preferences;
- subtitle and audio language preference;
- installed addon manifest URLs;
- onboarding completion;
- future Velyra-specific layout preferences.

### Keychain owns

- Trakt access token;
- Trakt refresh token;
- future sensitive provider tokens.

Tokens are not placed in CloudKit or ubiquitous key-value storage.

## Apple ID behaviour

Velyra relies on the iCloud account already configured on the Apple TV. There is no custom Apple ID login screen and the app does not receive the account email or password.

If iCloud is unavailable, Velyra remains fully usable with local settings and clearly reports that synchronisation is paused.

## Trakt completion definition

“Trakt complete” means all of the following work reliably:

- device-code authentication;
- token refresh and disconnection;
- watchlist read/write;
- history read/write;
- collection read/write where implemented;
- playback-progress reconciliation;
- scrobble start, pause and stop;
- offline queue and retry;
- rate-limit handling;
- duplicate-event protection;
- multi-device conflict reconciliation;
- privacy controls and clear disconnect behaviour.
