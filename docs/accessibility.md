# Accessibility

Accessibility is a release requirement for every Velyra feature.

## Visual

- System fonts and Dynamic Type where supported.
- Minimum readable contrast over every video frame through overlays.
- Focus is never represented by colour alone.
- Respect Increase Contrast and Reduce Transparency.
- Avoid thin orange text on bright backgrounds.
- Subtitle styling must support size, background and edge contrast.

## Motion

- Respect Reduce Motion globally.
- Replace background video with a static fallback.
- Remove parallax, large scale changes and morphing transitions where necessary.
- Avoid flashes and repeated rapid cuts.

## VoiceOver

- Decorative video is hidden.
- Media cards expose title, secondary information, progress and action hint.
- Device activation codes are read as explicit values.
- Navigation communicates selected state.
- Buttons use meaningful labels rather than icon names.

## Hearing

- Background previews are muted.
- Player supports subtitle and SDH selection.
- Audio-description tracks must be identifiable where metadata allows it.
- Playback controls must expose the current audio and subtitle track.

## Motor and cognitive accessibility

- Stable focus order.
- Large targets and generous spacing.
- No time-limited onboarding actions.
- Clear language and one primary action per decision.
- Errors include recovery actions and do not discard user input.

## Test matrix

Before each release:

- VoiceOver on Apple TV hardware;
- Reduce Motion;
- Reduce Transparency;
- Increase Contrast;
- light and dark appearance;
- large text settings supported by the current tvOS;
- Siri Remote directional navigation;
- remote with touch surface disabled;
- external keyboard navigation.

## Smart playback and onboarding

- Onboarding is a single screen with one primary action; no technical configuration is required.
- Automatic selections are explained in plain language before they are applied.
- Audio descriptions, SDH and transcription tracks remain visible and are labelled as accessibility tracks.
- The player options panel reports the selected source, audio and subtitle choice through both visual state and accessibility values.
- Source failover preserves playback position and does not require a timed response.
