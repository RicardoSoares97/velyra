# Apple platform standards

This document is a mandatory engineering and design contract for Velyra. A feature is not complete merely because it works; it must behave like a native, respectful tvOS feature.

## 1. Native platform behaviour first

- Prefer SwiftUI, AVKit, AVFoundation, CloudKit, Keychain, URLSession and system controls.
- Use `AVPlayerViewController` as the primary playback presentation.
- Do not recreate system playback controls, alerts, menus, pickers or focus behaviour without a documented product need.
- Use SF Symbols where a system symbol communicates the action accurately.
- Follow platform terminology and expected remote-control behaviour.

## 2. Content before chrome

- Artwork and video are the visual foreground.
- Liquid Glass is reserved for navigation, controls and transient surfaces.
- Do not stack translucent surfaces or place glass on every card.
- Keep controls visually distinct from content and remove them when they are not needed.
- Every video background must have a static fallback and a legibility overlay.

## 3. Focus and Siri Remote

- Every interactive element must be reachable with directional navigation.
- Focus order must match the visible layout and remain stable after data refreshes.
- Restore focus when dismissing details, sheets and the player.
- Focus is shown using shape, scale, depth and outline, never colour alone.
- Support the Siri Remote with the touch surface disabled and external keyboard navigation.
- The Menu/Back action always dismisses the nearest temporary layer before leaving a screen.

## 4. Accessibility is a release gate

Every feature must be reviewed with:

- VoiceOver;
- Reduce Motion;
- Reduce Transparency;
- Increase Contrast;
- larger accessibility text where tvOS exposes it;
- audio descriptions, SDH and captions where media provides them;
- colour-independent state communication;
- predictable focus and no time-limited tasks.

Decorative video is silent, hidden from VoiceOver and replaced with a static image under Reduce Motion.

## 5. Playback

- Select the most compatible source before the most impressive label.
- Validate actual playability through AVFoundation; never trust filenames alone.
- Prefer direct HLS/MP4 playback, stable cached sources and secure transport.
- Preserve playback position when switching or failing over between sources.
- Use original audio when metadata identifies it.
- Select subtitles matching the configured content region, with base-language fallback.
- Preserve a user’s manual audio/subtitle choice while switching sources when equivalent tracks exist.
- Expose source, audio and subtitle changes in a concise player options panel.
- Show Dolby Vision, HDR and Dolby Atmos labels only when supported by reliable metadata or inspection.

## 6. Privacy and identity

- Velyra does not require a proprietary user account.
- iCloud settings use the Apple ID already configured on the device.
- OAuth access and refresh tokens remain in Keychain and are never copied to iCloud.
- Store only the minimum data required for the feature.
- Do not track users or create advertising profiles.
- Keep the Privacy Manifest accurate whenever APIs or data collection change.
- The app must continue locally when iCloud is unavailable.

## 7. iCloud and sync

- Use key-value storage only for small preferences.
- Use the user’s private CloudKit database for larger independently editable records.
- Resolve conflicts deterministically and avoid silent data loss.
- Treat account changes and temporary iCloud unavailability as normal states.
- Do not expose or infer the user’s Apple ID email address.

## 8. Localisation

- All user-facing text belongs in String Catalogs.
- English is the development language; Portuguese (Portugal), Spanish and French ship from the start.
- Avoid string concatenation where word order changes by language.
- Localise accessibility labels, errors, dates, numbers, regions and media-language names.
- Test expansion and long titles on a television-sized layout.

## 9. Performance and reliability

- Use lazy rails and cancel work that is no longer visible.
- Cache images and metadata responsibly with bounded storage.
- Avoid simultaneous background video decoding in multiple views.
- Keep expensive blur and glass effects limited to a small number of surfaces.
- Never block the main actor with network, parsing or storage work.
- Provide loading, empty, offline, partial and retry states.
- Use exponential backoff and respect service rate limits.

## 10. Architecture and testing

- Presentation, application, domain and data responsibilities remain separated.
- Domain ranking and selection rules are deterministic and unit tested.
- Services are injected behind protocols where practical.
- New features start from `develop` and return through a pull request.
- Every PR documents focus, accessibility, localisation, privacy and performance impact.
- Releases require a simulator build plus validation on physical Apple TV hardware.

## Pull request acceptance checklist

- [ ] Uses native platform APIs/components wherever available.
- [ ] Correct directional focus order and focus restoration.
- [ ] VoiceOver labels, values, hints and headings reviewed.
- [ ] Reduce Motion, Reduce Transparency and Increase Contrast reviewed.
- [ ] All user-facing strings localised.
- [ ] Empty, loading, failure, offline and retry states covered.
- [ ] Privacy Manifest and entitlements reviewed.
- [ ] Main-actor and cancellation behaviour reviewed.
- [ ] Unit tests added for domain rules.
- [ ] Tested with Siri Remote and on physical Apple TV before release.
