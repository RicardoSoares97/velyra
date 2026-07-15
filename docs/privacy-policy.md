# Velyra privacy policy — draft

Velyra is designed to work without a separate Velyra account.

## Data stored by the app

- Preferences and installed addon manifest addresses may be synchronised through the user's private iCloud account.
- Trakt access and refresh tokens are stored in the device Keychain and are not copied into iCloud by Velyra.
- A local cache may contain public media titles, artwork addresses and Home layout data to improve reliability.
- Search history is optional, stored locally and can be cleared independently.
- Velyra stores a local count of detected unclean app exits for opt-in diagnostics; this does not leave the device automatically.
- Playback diagnostics shown to the user omit stream URLs, credentials and request headers.

## External services

When configured by the user, Velyra communicates directly with TMDB, Trakt and installed addon services. Those services process requests under their own privacy terms. Velyra does not sell personal data and does not include advertising or cross-app tracking in this foundation.

## Deletion

Users can remove addons, disconnect Trakt, clear caches, clear search history, delete only the private iCloud record, reset individual settings domains or reset the complete app. The complete reset removes the private CloudKit user-state record, local caches, queued Trakt changes, Top Shelf snapshot, local launch-health information and the Keychain Trakt session managed by Velyra.

This draft still requires legal review plus final operator, support, contact and service-policy details before TestFlight or App Store publication.
