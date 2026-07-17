# Release readiness checklist

This document separates implementation completeness from tasks that require Apple tooling, commercial credentials or licensed content.

## Implemented in source

- GitFlow and modular tvOS architecture.
- Cinematic onboarding, Home, Search, Details, Library, Addons, Player and Settings.
- Four interface languages.
- Accessibility and reduced-motion/transparency behaviour foundations.
- TMDB discovery and regional provider integration contract.
- Complete Trakt client surface with offline queue and cache.
- Addon validation, aggregation, ordering, health and configuration transfer.
- Smart source, audio and subtitle selection with failover.
- Embedded and external text subtitle support.
- Private CloudKit user-state model and lightweight iCloud preferences.
- Image pipeline, shared TMDB response cache, bounded Library enrichment, Home cache, offline network status, opt-in diagnostics, local launch-health monitoring and Top Shelf snapshot/extension.
- Granular iCloud sync management, per-domain conflict resolution and reset tombstones.
- Search filtering by media kind, year, rating and sort order.
- Generated Velyra app icon stacks, static Top Shelf fallbacks and 4K onboarding fallback artwork.
- Immersive onboarding foundation with deterministic, locale-scoped TMDB decorative metadata, independent series/movie refreshes, bounded fresh/stale caching and fallback-first image publication.
- Dynamic onboarding art composed from Velyra-owned fallback artwork, prefetched TMDB backdrops and native SwiftUI motion, with static/stronger-surface behaviour for Reduce Motion and Reduce Transparency.
- Trailer policy that exposes only official TMDB YouTube Trailer metadata with a nonempty key, visible provider attribution and a user-initiated `OpenURL` action; rejection remains recoverable and is announced to VoiceOver.
- XcodeGen project generation from `project.yml` completes and produces `Velyra.xcodeproj` without manual project-file edits.

## Requires external configuration

- Trakt application client identifier and secret.
- TMDB read access token and final credential/build configuration.
- Apple Developer identifiers, app group and CloudKit container.
- Final privacy contact, terms and support URLs.
- Optional external crash-reporting provider, only if a privacy-reviewed opt-in service is selected; local diagnostics already work without one.
- Final App Store screenshots captured on physical Apple TV for the required accessibility/display variants.
- Final rights review for TMDB/provider presentation, original assets and any optional third-party artwork or background loops.

## Requires macOS/Xcode or Apple TV hardware

- Run the generated project through an actual GitHub-hosted or repaired local
  `xcodebuild`. The complete production source already passes a direct Swift 6/tvOS
  17 simulator-SDK type-check and XcodeGen generation, but those checks do not
  replace an Xcode build. Authoritative XCTest and unsigned IPA packaging also
  remain pending on that runner.
- Run XCTest and UI tests; source-level runners and parsers are not substitutes for them.
- Validate physical Apple TV focus with Siri Remote and keyboard input, VoiceOver navigation/announcements, and Top Shelf behaviour.
- Validate Reduce Motion, Reduce Transparency and Increase Contrast on hardware and capture the required screenshots for each supported appearance.
- Validate CloudKit schema and entitlements in the Apple environment.
- Test Dolby Vision, HDR, Atmos, frame-rate matching and real-world streams.
- Sign, archive and deliver through TestFlight, or produce the actual IPA and complete an Apple TV install for the sideload path.

## Onboarding accessibility and network matrix

The source-level status below describes static coverage only. No row claims physical Apple TV verification.

| Scenario | Statically covered in source | External/manual release evidence still pending |
| --- | --- | --- |
| No credential, offline, corrupt/expired cache or locale mismatch | Local fallback remains available and onboarding does not wait for remote decoration | Launch and complete onboarding offline on physical Apple TV, including a credential-free release configuration |
| One TMDB trending endpoint fails | Series and movie requests are isolated and valid results from the other endpoint remain usable | Exercise controlled partial failures with the release credential/configuration |
| Remote image request fails | A backdrop is published only after successful prefetch; original fallback remains underneath | Observe slow, rejected and interrupted requests on hardware |
| Reduce Motion | Drift and animated transitions are disabled and at most one static remote backdrop is used | Validate focus and transitions on physical Apple TV and capture screenshots |
| Reduce Transparency | The centre legibility treatment becomes more opaque | Validate surfaces together with Increase Contrast and capture screenshots |
| VoiceOver and trailer rejection | Controls have accessibility labels/hints; a rejected external trailer action queues the recoverable message | Verify focus order, queued announcement and external-app return with Siri Remote and keyboard |

Release sign-off therefore still requires physical Apple TV focus/Siri Remote/keyboard/VoiceOver testing; Reduce Motion, Reduce Transparency and Increase Contrast screenshots; TMDB credential/config verification; final rights review; and an actual Xcode or GitHub build, IPA generation/signing as applicable, and device installation. Static validation alone cannot close those items.

## Unsigned sideload packaging

- Install the current stable Xcode and XcodeGen with `brew install xcodegen`.
- Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer scripts/build_sideload_ipa.sh`; this avoids changing `xcode-select` and needs no administrator access.
- Use `SIDELOAD_OUTPUT_DIR=/path/to/output` to select another artifact directory.
- Optional `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`, and `TMDB_READ_ACCESS_TOKEN` values are passed through a mode-0600 temporary xcconfig and removed on success or failure. Never print them or pass them as xcodebuild command-line build settings.
- Provider values compiled into a distributed native client are extractable from the public IPA. GitHub Secrets only keep them out of source and logs; use provider-side restrictions and rotation.
- The produced IPA is unsigned. atvloadly owns Personal Team signing and installation, and the user owns renewal before the typical seven-day expiry, including re-signing and reinstalling the app.
- The sideload target stores settings locally and excludes iCloud, CloudKit, App Groups, the Top Shelf extension, and dynamic Top Shelf publication. The full target remains unchanged for a paid Apple Developer release.
- Because this machine currently has an Xcode/DVT framework mismatch, a GitHub-hosted macOS runner is authoritative until the local Xcode installation is repaired.
- Apple credentials, signing certificates, provisioning profiles, atvloadly pairing/state, and private keys must never be stored in the repository or published artifacts.

## Automated GitHub release gate

Repository configuration required before a release:

- GitHub Actions secrets named `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET`, and
  `TMDB_READ_ACCESS_TOKEN`. These protect CI inputs and logs only; the compiled
  native-client values are extractable from the public IPA and must be restricted,
  monitored, and rotatable at the providers.
- Pull-request protection on `main` and `develop`, the required `tvOS Build`
  status check, disabled force-pushes, protected `v*` tags, and least-privilege
  workflow permissions.
- At least one release category label on every release-facing PR. The supported
  labels are `feature`, `enhancement`, `bug`, `fix`, `accessibility`,
  `performance`, `documentation`, `dependencies`, `maintenance`, and `ci`.
  `skip-changelog` is reserved for changes with no user or operator impact;
  otherwise uncategorized changes appear under `Other changes`.

The release branch must update `MARKETING_VERSION`, merge through a normal PR to
`main`, and merge back into `develop`. The user then creates a matching
`vMAJOR.MINOR.PATCH` tag on the `main` commit. The workflow verifies semantic
versioning and `main` ancestry, reruns all CI rather than downloading an earlier
artifact, and publishes only after verifying exactly these outputs:

- unsigned `Velyra-sideload-vMAJOR.MINOR.PATCH.ipa`;
- `Velyra-sideload-vMAJOR.MINOR.PATCH.ipa.sha256`;
- `CHANGELOG-vMAJOR.MINOR.PATCH.md`, with categorized generated release notes.

atvloadly remains responsible for Personal Team signing and installation. The
user owns renewal, re-signing, and reinstallation when the free profile expires.

Failure recovery is transactional around publication: failures before draft
creation produce no release; upload or verification failures leave a draft; and a
rerun of the same tag resumes the draft and replaces its assets. If the release is
already public, the workflow refuses to overwrite it silently. Inspect the draft,
fix the source through GitFlow, and use a new approved semantic version when a
published release requires correction.

## Deliberate technical boundaries

- Velyra does not bundle content or addons.
- Non-AVPlayer-compatible containers may require an independently deployed remux/transmux service.
- Text ASS/SSA is reduced to readable text; advanced styling and image-based subtitles need a separate rendering/remux path.
- Platform-specific audience rankings are only shown as official when an authorised source exists.
