# Smart playback

## Product promise

The user presses Play. Velyra handles technical decisions automatically and exposes simple controls only when the user wants to change them.

Default behaviour:

1. rank all available addon sources;
2. prefer compatibility and stability over filename marketing;
3. prefer direct Apple playback, secure URLs and cached sources;
4. select the best resolution allowed by the user and device;
5. prefer Dolby Vision/HDR and Dolby Atmos only among otherwise compatible sources;
6. validate the selected asset with AVFoundation;
7. fail over to the next ranked source while preserving position;
8. select the original audio language when metadata identifies it;
9. select subtitles for the configured content region;
10. allow source, audio and subtitles to be changed in the player.

## Region and iCloud

Apple does not expose an app-readable “country of the Apple ID” value. Velyra uses the device locale/region during first setup, stores the resolved content region in app preferences and synchronises it through iCloud. The user can review or change the region in Settings.

For a device configured for Portugal:

- preferred audio: original language;
- preferred subtitles: `pt-PT`;
- language fallback: `pt` when an exact Portuguese (Portugal) track does not exist.

## Source score

The first implementation gives priority to:

- AVPlayer-compatible containers;
- cached or immediately playable sources;
- HTTPS;
- requested maximum resolution;
- supported HDR/Dolby Vision;
- supported Dolby Atmos;
- healthy availability metadata;
- realistic bitrate;
- rejection of low-quality release labels such as CAM or telesync.

The final decision is still verified through `AVURLAsset.isPlayable`. A source that fails validation triggers automatic failover.

## Media tracks

Embedded audio and subtitle tracks use AVFoundation media-selection groups. Selection rules prefer exact BCP-47 matches, then the base language. Accessibility tracks remain visible and explicitly identified in the player.

Manual choices are session preferences: when the user changes source, Velyra tries to select an equivalent language track in the replacement source.

External addon subtitles will enter the same player-options experience after the subtitle pipeline is implemented. They must be downloaded securely, parsed off the main actor and cleaned up after playback.

## Honest limitations

Addon metadata can be incomplete or inaccurate. Velyra must never promise Dolby Vision, Atmos, original-language audio or a particular subtitle until the media asset or trustworthy metadata confirms it. The automatic selector aims for the best compatible experience, not the largest filename.
