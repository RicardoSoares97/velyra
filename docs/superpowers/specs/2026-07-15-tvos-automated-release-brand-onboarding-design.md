# Automated tvOS Release, Brand, and Onboarding Design

Status: ready for written review.

## Purpose

Complete the tvOS project foundation needed to build Velyra on GitHub, publish an unsigned sideload IPA automatically through GitFlow, and give the application a complete Apple TV identity and resilient cinematic onboarding.

This design extends the dedicated sideload target and capability boundary defined in `2026-07-15-xcode-tvos-sideload-design.md`. Where the earlier document assumes local packaging, this document makes GitHub Actions the authoritative build and release environment. The full target remains available for a future paid Apple Developer configuration.

## Confirmed product decisions

- Brand mark: **Fita cinematográfica**, an abstract V made from a ribbon of light.
- Onboarding composition: **Palco imersivo**, with content surrounding a centered message and action.
- App icon treatment: **Radiância escura**, using orange as light rather than as a full surface.
- Delivery architecture: hybrid native assets plus live TMDB artwork.
- GitFlow release trigger: an annotated or lightweight semantic-version tag reachable from `main`.
- Third-party trailers never autoplay or play as hidden decorative video.
- Onboarding motion is original, silent, and implemented natively from layered images.

## Constraints

- Local `xcodebuild` is not reliable because the installed Xcode and system developer frameworks do not match, and the user cannot run privileged first-launch or `xcode-select` operations.
- The user has a free Apple Personal Team. The released sideload IPA must not require iCloud, CloudKit, App Groups, or an embedded Top Shelf extension.
- atvloadly performs signing and installation after downloading the unsigned IPA.
- TMDB returns video metadata and provider identifiers, not an AVPlayer-compatible trailer stream.
- YouTube content must not be downloaded, extracted, cached as audiovisual content, or started as hidden background playback.
- Signing assets, Apple account data, provisioning profiles, and private operational credentials must never be committed or uploaded as workflow artifacts. TMDB and Trakt native-client configuration is injected from GitHub Secrets but is necessarily recoverable from a distributed IPA and must be treated as public client configuration.
- The project continues to target tvOS 17 and later and to meet `docs/apple-platform-standards.md`.

## Goals

1. Keep `tvos-build.yml` as continuous validation for GitFlow branches and pull requests.
2. Build a structurally valid unsigned sideload IPA in GitHub Actions.
3. Upload short-lived IPA artifacts from eligible CI runs.
4. Publish a GitHub Release automatically for a valid `vMAJOR.MINOR.PATCH` tag on `main`.
5. Attach the IPA, SHA-256 checksum, and generated Markdown changelog to the release.
6. Add a complete layered tvOS app icon, Top Shelf fallback, brand mark, and onboarding fallback artwork.
7. Enrich onboarding with current TMDB trending backdrops without making network availability a requirement.
8. Preserve focus, localization, accessibility, privacy, and offline behavior.

## Non-goals

- Signing an IPA in GitHub Actions.
- Storing Apple credentials or atvloadly state in GitHub.
- Uploading to App Store Connect or TestFlight.
- Embedding or extracting YouTube trailers.
- Adding a YouTube Data API client or unofficial video resolver.
- Hosting a remote Velyra asset manifest or CDN.
- Replacing the Home, Details, playback, or addon architectures.
- Generating raster UI glyphs when SF Symbols already express the action.

## Distribution architecture

### Full target

`VelyraTV` retains its iCloud, CloudKit, App Group, and `VelyraTopShelf` relationship. It is compiled in CI without signing to prevent regressions, but it is not the IPA distributed for the free-account workflow.

### Sideload target

`VelyraTVSideload` shares application code and ordinary resources with the full target. It has a separate bundle identifier and compile condition, uses local persistence, has no paid-program entitlements, and does not embed `VelyraTopShelf`.

The unsigned artifact contains exactly one application bundle:

```text
Velyra-sideload.ipa
└── Payload/
    └── Velyra.app/
```

Dynamic Top Shelf publication is disabled in sideload mode. Static brand artwork may remain compiled as an application resource because it has no App Group or paid-capability dependency.

## GitFlow and workflow design

### Continuous integration

`.github/workflows/tvos-build.yml` remains the branch and pull-request workflow. It runs for:

- pushes to `develop`, `main`, `release/**`, and `hotfix/**`;
- pull requests targeting `develop` or `main`;
- manual diagnostic runs through `workflow_dispatch`.

Feature branches are validated through pull requests, which avoids consuming duplicate macOS minutes for both a feature push and its PR.

The workflow uses a single concurrency group per branch or pull request and cancels an obsolete in-progress run. It grants read-only repository permissions and performs these stages:

1. Check out the exact revision with full tag metadata when required.
2. Select a supported stable Xcode available on the hosted macOS image.
3. install or resolve the pinned XcodeGen version;
4. run `scripts/validate_project.py` and `swift-format lint`;
5. generate `Velyra.xcodeproj`;
6. resolve an available tvOS Simulator;
7. build and test the full target with code signing disabled;
8. build and inspect the sideload IPA using the repository script;
9. upload the IPA and checksum as a short-lived workflow artifact for non-fork runs.

Provider secrets are not exposed to pull requests from forks. CI compilation and unit tests therefore accept empty provider configuration and use test doubles for network behavior.

Official GitHub actions are pinned to full commit SHAs with a version comment. The implementation uses current Node 24-compatible action generations supported by GitHub-hosted runners rather than the older major versions in the existing workflow.

### Automated release

`.github/workflows/tvos-release.yml` runs on pushed tags matching `v*`. The first step validates that the name strictly matches `vMAJOR.MINOR.PATCH`. Prerelease suffixes are excluded so `MARKETING_VERSION` remains a numeric Apple bundle version. It then verifies:

- the tagged commit is reachable from `origin/main`;
- the tag version equals `MARKETING_VERSION` in `project.yml`;
- the tag does not already identify a conflicting published release.

The release workflow repeats validation, generation, simulator tests, full-target compilation, sideload packaging, and IPA inspection. It never trusts an artifact produced by a different workflow run.

Release builds receive `TMDB_READ_ACCESS_TOKEN`, `TRAKT_CLIENT_ID`, and `TRAKT_CLIENT_SECRET` from encrypted GitHub Actions secrets. A release stops before compilation if required runtime configuration is absent. Values are passed as build settings and are never committed, printed, or cached separately. Because the current application stores them in its compiled `Info.plist`, they are recoverable from the released IPA; only credentials intended for a distributed native client, with provider-side restrictions and rotation procedures, are acceptable.

The workflow then:

1. computes `Velyra-sideload-vX.Y.Z.ipa.sha256`;
2. requests generated release notes from the GitHub Releases API;
3. writes the notes to `CHANGELOG-vX.Y.Z.md` in the temporary artifact directory;
4. creates or resumes a draft GitHub Release;
5. uploads the IPA, checksum, and changelog;
6. verifies all three release assets and their names;
7. publishes the draft only after verification succeeds.

If upload or API access fails, the release remains a draft and can be retried without presenting a partial public release. The workflow has `contents: write` only in the release job.

`.github/release.yml` categorizes merged pull requests using labels such as features, fixes, accessibility, performance, documentation, and maintenance. Uncategorized changes remain visible under a general category. The generated body includes contributors and a full comparison link.

## IPA build contract

`scripts/build_sideload_ipa.sh` is the single packaging entry point for local and CI use. It accepts an output directory and build-setting overrides, but has safe repository-local defaults.

The script:

1. checks required tools without attempting privileged installation;
2. runs static validation and project generation;
3. archives `VelyraTVSideload` for `generic/platform=tvOS` with signing disabled;
4. packages `Products/Applications/Velyra.app` under `Payload/` using Apple tooling;
5. verifies the bundle identifier, marketing version, and minimum tvOS version;
6. rejects embedded `.appex`, provisioning profiles, unexpected signatures, and restricted entitlements;
7. validates the ZIP structure and creates a SHA-256 checksum;
8. moves complete outputs atomically to `artifacts/`.

An incomplete IPA never replaces a previous valid local artifact. CI always builds in a fresh directory.

## Brand system and asset inventory

### Master identity

The Fita cinematográfica mark is maintained as deterministic vector artwork. It is not generated as text inside a raster image. The master contains no wordmark; the product name remains real SwiftUI text for clarity and accessibility.

Atmospheric bitmap artwork is generated as original Velyra artwork, without actors, recognizable franchises, studio marks, film stills, UI screenshots, watermarks, or embedded text. The generation prompts and provenance are documented in `docs/brand/assets.md`.

### Asset catalog

`VelyraTV/Resources/Assets.xcassets` becomes the source of truth for application artwork and is included explicitly by XcodeGen.

The catalog contains:

- a tvOS App Icon and Top Shelf brand asset;
- a three-layer Radiância escura icon stack: opaque background, orange light field, and crisp ribbon mark;
- all sizes required by the selected Xcode/tvOS asset compiler, rendered from vector layers and a high-resolution 5:3 background master while validating the official 800 by 480 layout;
- a static Top Shelf fallback at 2320 by 720 pixels and 4640 by 1440 pixels;
- a 16:9 4K onboarding fallback image;
- a reusable Velyra mark image set for in-app branding where SwiftUI drawing is not appropriate.

The icon layers are rectangular and unmasked. The foreground mark stays inside a conservative safe zone to accommodate tvOS focus scaling and parallax crop. Transparent upper layers use hard, clean edges; the background is opaque and full bleed.

A validation script checks catalog JSON, file presence, pixel dimensions, alpha expectations, color profile compatibility, and duplicate or orphaned files. `actool` validation remains authoritative during Xcode compilation.

### Motion policy

No large onboarding MP4 is required for the first release. The selected Palco imersivo look is produced by native SwiftUI motion:

- slow scale and drift on two independently layered backdrops;
- restrained crossfades after complete image decode;
- a soft orange light sweep derived from the mark;
- no sound, rapid cuts, flashes, or continuous multi-video decoding.

This keeps the IPA small and allows live trending artwork while retaining the visual character of a cinematic loop. The existing optional local MP4 infrastructure remains available for future explicitly licensed media.

## Onboarding media architecture

### Components

`OnboardingMediaProviding` defines one operation that returns a small, presentation-ready set of onboarding media for a language and region. The view model depends on this protocol rather than on `TMDBAPIClient` directly.

`TMDBOnboardingMediaRepository`:

- reuses the existing TMDB trending endpoints and image URL configuration;
- fetches movies and series concurrently;
- interleaves both kinds instead of allowing one list to dominate;
- selects two unique items with valid backdrops;
- stores only the identifiers and metadata needed to reconstruct the presentation;
- uses the existing bounded image pipeline for pixels.

`OnboardingMediaViewModel` owns the loading state and never exposes network errors directly to the initial screen. `ImmersiveOnboardingBackdropView` owns only rendering and accessibility behavior.

The existing `AutomaticSetupService` and `TraktSession` remain responsible for configuration and optional authentication. The media repository never owns user preferences or OAuth state.

### Data flow

The bundled Radiância escura fallback renders immediately. In parallel, the repository loads a fresh result or a cached trending selection, and the image pipeline prefetches its backdrops. The view changes to remote artwork only after at least one complete image is available.

Selection is stable for a calendar day and a language/region pair, preventing the two sides of the stage from changing during repeated launches. Fresh trending metadata is cached for six hours. A previously successful selection may be used as stale presentation data for up to seven days because it is decorative and clearly carries no factual ranking label on onboarding.

After the user activates the central action, the same screen reveals the automatic audio, subtitle, and source summary plus optional Trakt connection. Completion persists through the existing application state.

### Trailer behavior

TMDB video results remain eligible for a user-initiated **View trailer** action in content Details. A candidate must be official, have type `Trailer`, use an explicitly supported provider, and expose a valid external URL.

The app opens the provider URL only after the user activates the action and keeps provider attribution visible. If tvOS cannot open it, a localized recoverable message is shown. The app does not resolve, proxy, cache, download, or feed a YouTube URL to `AVPlayer`.

Onboarding never starts a third-party trailer. A future provider may implement native onboarding video only when it supplies an authorized direct HLS or MP4 URL and an explicit product decision updates this contract.

## User experience and accessibility

The first stage centers the Velyra mark, short message, and primary action between two atmospheric content regions. Content is decorative and hidden from VoiceOver. Text remains real localized SwiftUI content and is never baked into artwork.

The second stage preserves the same visual context while presenting configuration and optional Trakt connection. Focus moves predictably to the first actionable control and returns to a stable element after authentication state changes.

- Reduce Motion uses one static image with no drift or recurring crossfade.
- Reduce Transparency strengthens the legibility overlay and uses solid control surfaces.
- Increase Contrast maintains white text and a stronger orange focus outline.
- VoiceOver reads the brand, purpose, configuration summary, authentication status, and actions in order.
- Offline, unconfigured TMDB, timeout, or invalid remote artwork silently retain the bundled fallback.
- The onboarding can always be completed without TMDB or Trakt.

All new text ships in English, Portuguese (Portugal), Spanish, and French through the existing String Catalog.

## Error handling

- A missing TMDB token in development selects the local fallback and records a privacy-safe diagnostic state.
- Release CI treats missing required provider secrets as a configuration error and does not create a draft release.
- One failed trending endpoint can still yield artwork from the other media kind.
- One invalid image is skipped without resetting already loaded artwork.
- Cache corruption deletes only the onboarding cache record and restores the fallback.
- A simulator-resolution failure prints the installed runtimes and stops CI rather than claiming tests passed.
- Packaging failure removes partial output and preserves no public release.
- Release API or upload failure leaves only a draft release.
- atvloadly signing and seven-day renewal failures remain outside the app and workflow boundary.

## Validation and testing

### Unit tests

Add deterministic tests for:

- movie and series interleaving;
- exclusion of items without backdrops;
- stable daily selection;
- fresh, stale, expired, and corrupt cache behavior;
- fallback behavior for partial and complete network failure;
- trailer ranking and official-provider filtering;
- sideload capability selection and local persistence;
- tag and project-version validation helpers where implemented in Python.

### Repository and build validation

Extend `scripts/validate_project.py` to verify:

- both application targets and schemes;
- sideload entitlements contain no restricted capability;
- required brand catalog structures and source artwork documentation;
- both GitHub workflows and release configuration;
- release workflow permissions and tag checks;
- IPA packaging and inspection script references;
- complete localization entries.

Every CI run performs formatter lint, XcodeGen generation, simulator XCTest, full-target unsigned compilation, sideload archive, and IPA inspection. The workflow does not convert an unavailable simulator into a passing test result.

### Physical Apple TV acceptance

After atvloadly signs and installs the release IPA, verify:

- icon parallax, safe-zone crop, and focused appearance;
- launch and both onboarding stages;
- focus with touch disabled and an external keyboard;
- VoiceOver, Reduce Motion, Reduce Transparency, and Increase Contrast;
- fallback behavior before configuring TMDB and while offline;
- trending artwork after valid provider configuration;
- local preference persistence after relaunch;
- Trakt device authentication and session restoration;
- Home, Details, addon resolution, AVKit playback, and subtitles;
- absence of cloud and dynamic Top Shelf actions in sideload mode;
- atvloadly reinstall and renewal behavior.

## Security, privacy, and licensing

- Workflow permissions follow least privilege.
- Official actions are pinned by commit SHA.
- No pull request from a fork receives provider secrets.
- Build logs and artifact names contain no provider values. The release documentation states that native-client configuration embedded in the IPA is not confidential and can be rotated without changing the application architecture.
- The IPA is unsigned and contains no provisioning profile or developer certificate.
- Generated artwork is original and its prompt provenance is documented.
- TMDB attribution remains visible wherever required by the existing product contract.
- YouTube and other trailer-provider branding remains visible for provider actions.
- Velyra does not bundle, host, index, or redistribute trailer audiovisual content.

## Acceptance criteria

- The selected Fita cinematográfica, Palco imersivo, and Radiância escura directions are represented consistently in the app icon, Top Shelf fallback, and onboarding.
- The tvOS asset catalog compiles without missing-slot, dimension, alpha, or safe-zone defects.
- Onboarding appears immediately offline and upgrades smoothly to cached or fresh trending artwork.
- Reduce Motion prevents decorative animation.
- No third-party trailer autoplays or enters the IPA.
- `tvos-build.yml` tests the full app and produces a validated sideload artifact for eligible runs.
- A valid semantic tag reachable from `main` creates one public GitHub Release only after all checks pass.
- The release contains the versioned IPA, SHA-256 file, generated changelog asset, and categorized release notes.
- The IPA contains one application, no extension, no paid entitlements, no provisioning profile, and the version declared by the tag.
- Missing release secrets, failing tests, or invalid assets prevent publication.
- The full target retains its future paid-program architecture.
- No provider values, signing material, copyrighted film imagery, or undocumented media resolver enters source control. Distributed native-client configuration inside the IPA is explicitly classified as recoverable public configuration.

## Sources

- Apple app icon guidance: <https://developer.apple.com/design/human-interface-guidelines/app-icons/>
- Apple asset catalog configuration: <https://developer.apple.com/documentation/xcode/configuring-your-app-icon/>
- Apple Top Shelf guidance: <https://developer.apple.com/design/human-interface-guidelines/top-shelf>
- Apple tvOS design guidance: <https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos>
- TMDB video reference: <https://developer.themoviedb.org/reference/movie-videos>
- YouTube API Services Developer Policies: <https://developers.google.com/youtube/terms/developer-policies>
- GitHub Releases: <https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases>
- GitHub generated release notes: <https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes>
- GitHub workflow artifacts: <https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts>
