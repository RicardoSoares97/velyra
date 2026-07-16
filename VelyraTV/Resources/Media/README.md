# Cinematic background media

The generated `OnboardingFallback` asset is the default static-fallback
contract for the immersive onboarding component. `ImmersiveOnboardingBackdropView`
renders it immediately, combines it with native SwiftUI motion when allowed,
and can layer optional prefetched TMDB side backdrops. Remote metadata or image
failure leaves the original fallback intact, and no MP4 is required to build
or run.

The currently wired optional loops are the `videoName` values referenced by
`CinematicBackgroundView`. The app can use these silent MP4 files when the
project has explicit rights to distribute them:

- `home-featured.mp4`
- `ambient-shell.mp4`
- `settings-ambient.mp4`
- `library-ambient.mp4`

Current onboarding is implemented only by `ImmersiveOnboardingBackdropView`;
it does not resolve or play an onboarding MP4. Adding such a loop would require
a future product and rights decision plus an explicit production wiring change.

Requirements:

- no copyrighted film or series footage without an explicit licence;
- no audio track, or audio must be muted at playback;
- short seamless loops, preferably 8–15 seconds;
- HEVC/H.265 or H.264 in an Apple-compatible MP4 container;
- dark enough to keep white text readable;
- avoid rapid flashes, hard cuts and high-frequency motion;
- always provide a static fallback image or gradient;
- test with Reduce Motion, Reduce Transparency and Increase Contrast.

MP4 files are intentionally not committed to the repository. Their absence is
not a build failure: the rendered static fallback and native-motion design
already provide the default licensed-safe onboarding experience.
