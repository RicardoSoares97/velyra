# External subtitles

Velyra supports addon-provided SRT and WebVTT tracks through a restrained overlay above the native AVKit player.

## Automatic behaviour

1. Prefer a matching embedded subtitle track.
2. If no matching embedded track exists, choose an external track matching the content region.
3. Try the exact BCP-47 language first, then the base language.
4. Never download a subtitle over plain HTTP outside localhost development.
5. Limit subtitle downloads to 5 MB.

## Accessibility

Subtitle appearance must remain readable over bright and dark scenes. It uses high-contrast text, a dark backing surface and a maximum line width. The overlay is not announced repeatedly by VoiceOver; users who need spoken content should use an audio-description track when supplied by the source.

## Supported formats

- SubRip (`.srt`)
- WebVTT (`.vtt`)

ASS/SSA styling and image-based subtitles require a future conversion or fallback pipeline and must not be advertised as supported until tested on hardware.
