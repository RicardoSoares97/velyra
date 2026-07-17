# Apple-Native Experience Refresh Design

Status: ready for written review.

## Purpose

Refresh Velyra's tvOS experience as one coherent product feature: adopt current
Apple TV navigation and focus behaviour, simplify onboarding and Settings,
replace the weak static Top Shelf presentation, add safe read-only Stremio addon
import, remove repeated attribution copy, and eliminate the main sources of
focus and scrolling lag.

The result should feel at home on Apple TV without cloning the Apple TV app or
losing Velyra's orange cinematic identity.

## Confirmed product decisions

- Overall direction: **Editorial Rail**, implemented with native adaptable tab
  navigation where the deployed tvOS version supports it.
- Settings direction: **Category Centre**, followed by one focused detail screen
  per category.
- Top Shelf direction: **Resume First**, followed by recommendations.
- Onboarding direction: **One Promise**, with one screen and one primary action.
- Launch ident: **Ribbon Strike**, silent by default and approximately 1.5
  seconds long.
- Stremio scope: read-only, user-initiated addon import. Velyra never writes
  addon changes back to Stremio.
- The full visual experience is the default. Reduce Motion, Reduce Transparency,
  and Increase Contrast only change the presentation when the corresponding
  tvOS system setting is enabled.

## Existing project contracts

This design preserves the boundaries in:

- `docs/apple-platform-standards.md`;
- `docs/accessibility.md`;
- `docs/architecture.md`;
- `docs/design-system.md`;
- `docs/performance.md`;
- `docs/data-sources.md`;
- `docs/top-shelf.md`;
- `docs/home-discovery.md`;
- `docs/legal-boundaries.md`.

The deployment target remains tvOS 17. Velyra continues to use SwiftUI, AVKit,
URLSession, Keychain, local/private cloud preferences, SF Symbols, the existing
addon protocol, and the existing image pipeline.

## Platform research applied

Apple's current tvOS guidance prioritizes:

- the system focus engine, with gentle scale, depth, and immediate feedback;
- edge-to-edge artwork and a small functional navigation layer;
- adaptable `TabView` navigation that appears as a sidebar on tvOS and
  collapses after selection;
- Liquid Glass for navigation and controls, not for the content layer;
- dynamic personalized Top Shelf content, with a static noninteractive fallback;
- directional navigation to every interactive element.

The selected Editorial Rail is therefore implemented as native
`sidebarAdaptable` tab navigation on supported tvOS versions. The tvOS 17
compatibility path reproduces the same collapsed/expanded information hierarchy
with ordinary SwiftUI focus APIs and material, without trying to emulate
unavailable Liquid Glass behaviour.

## Approaches considered

### Overall navigation

1. **Editorial Rail — selected.** Native sidebar structure, strong content
   hierarchy, compact when inactive, and aligned with current Apple examples.
2. Quiet Cinema top bar. Lower implementation risk but too similar to the
   current oversized floating capsule.
3. Bottom focus dock. Visually expressive but conflicts with vertical rails and
   creates longer focus travel.

### Settings

1. **Category Centre — selected.** Best use of TV width, strong overview, and
   only one settings domain rendered at a time.
2. Persistent split panel. Faster switching but creates two adjacent sidebars
   and retains too much simultaneous content.
3. Simple vertical list. Familiar but wastes horizontal space and has a weaker
   visual hierarchy.

### Top Shelf

1. **Resume First — selected.** Useful, personal, lightweight, and consistent
   with Apple's recommendation to help people jump into relevant content.
2. Editorial hero. Cinematic but duplicates the Home hero.
3. Landscape gallery. Legible but mixes resume and discovery intent.

### Onboarding

1. **One Promise — selected.** One calm decision with enough explanation.
2. Explanation plus summary panel. Still too close to a settings form.
3. Cinematic bottom panel. Artwork competes with legibility and focus.

## Navigation and focus

### Top-level shell

The five existing destinations remain:

- Home;
- Search;
- Library;
- Addons;
- Settings.

Each tab uses a short localized label and a filled SF Symbol. The active
destination remains stable across navigation, and each destination preserves its
own navigation/focus state. Selecting a destination collapses the sidebar into
the native compact presentation. Menu/Back dismisses the nearest modal or detail
layer first and returns to the top-level navigation according to the system
interaction.

The content extends beneath the navigation layer so the rail feels attached to
the artwork rather than placed inside a separate opaque column. Safe-area
padding prevents focused artwork from colliding with overscan or the rail.

### Focus states

Every interactive control has four explicit presentation states:

- normal;
- focused;
- pressed;
- disabled.

Focused buttons use a modest scale increase, material lift, shadow, and a
shape-matched highlight. Selected state is independent from focus. Orange is an
accent and selected-state signal, never the only focus signal. Pressed state is
shorter and darker. Disabled controls do not accept focus.

Cards retain a restrained 1.05–1.06 focused scale. Rows use full-row highlight
rather than small rings around individual text. Controls leave enough external
padding for focus expansion, preventing the clipping visible in the current UI.

Normal mode uses the full depth and motion treatment. When Reduce Motion is
active, scale and parallax are removed while outline, contrast, and elevation
remain. No accessibility override is forced by Velyra.

## Visual system

Velyra remains dark, editorial, and content-led. Orange `#DD571C` becomes a
controlled accent rather than a large filled navigation background.

Liquid Glass is limited to:

- top-level navigation;
- focused/transient controls;
- modal panels;
- the active settings surface when appropriate.

Content cards, settings category tiles, and static information rows use opaque or
standard material surfaces. Nested glass panels are removed. Surface contrast
comes from spacing, typography, dividers, and depth rather than large pale
rectangles.

The layout uses a consistent spacing scale with generous gaps between sections
and tighter, regular spacing within a section. Titles, descriptions, values, and
actions have dedicated width constraints so localized text does not truncate
into unreadable fragments.

## Settings information architecture

Settings opens to a concise category centre. Categories are:

1. Appearance — theme, interface language, and region;
2. Experience — background video, previews, blur, and overlay;
3. Playback — source selection, quality, compatibility, HDR/Dolby preferences,
   and failover;
4. Audio & Subtitles — automatic language, preferred/secondary tracks, subtitle
   size, position, and background;
5. Home & Search — recent searches and Home section visibility/order;
6. Accounts & Sync — Trakt, iCloud or local-only status, and Stremio import;
7. Storage & Diagnostics — diagnostics and cache management;
8. About — version, origin, onboarding restart, and destructive reset actions.

Each tile shows one title and one short summary. Activating a tile opens only
that category. The category title, optional explanatory sentence, and rows fit
within the safe area. Values use menus or detail pickers instead of wide
segmented controls that truncate every option.

Home section ordering becomes a dedicated list with localized labels, visible
state, and Move Up/Move Down actions in the focused row. Raw localization keys
can never appear as user-facing fallback text.

Destructive actions remain separated at the end of their category and require
native confirmation.

## Launch ident and onboarding

### Ribbon Strike

On each cold application launch, a black screen presents a vertical orange light
strike. The strike opens into the existing ribbon geometry, resolves into the
Velyra mark and wordmark, then crossfades into Root content. Total duration is
approximately 1.5 seconds. It does not wait for bootstrap, network, TMDB, Trakt,
or addon work; bootstrap can run concurrently.

The ident is silent by default. It does not copy Netflix motion, sound, timing,
or geometry. With Reduce Motion active, the mark uses a short opacity transition
without strike, scale, or drift. The ident does not replay when a temporary
overlay closes or the scene merely becomes active again.

### One-screen onboarding

The onboarding screen contains:

- the Velyra mark;
- one welcome eyebrow;
- one short product promise;
- one sentence explaining automatic source, original audio, and regional
  subtitles;
- three concise assurance labels;
- one primary **Start** action;
- a quiet local/privacy line.

The current welcome/setup stages and inline Trakt authentication panel are
removed. Activating Start applies the existing automatic setup and completes
onboarding in one operation. Trakt remains optional under Accounts & Sync.

The background renders the local Velyra artwork immediately. At most one remote
backdrop may add atmosphere, with a stronger central legibility treatment and no
simultaneous competing side images. Remote loading never delays focus or
completion.

## Home cleanup

The Home information order remains unchanged. This feature changes presentation,
not feed ranking.

- Section spacing becomes consistent and leaves focused cards room to expand.
- The hero uses the shared downsampled image pipeline instead of an independent
  `AsyncImage`.
- Provider logos use the same pipeline and bounded target size.
- Filter chips use system focus depth and a clear selected state.
- The navigation layer never obscures the hero or rails.
- Repeated phrases such as “Data by …” are removed from provider section
  subtitles.

Required TMDB and JustWatch attribution is consolidated into the Home footer and
About screen. It remains visible and localized but no longer repeats beneath
every provider rail.

## Top Shelf

Dynamic Top Shelf uses sectioned content:

1. Continue Watching, when progress exists;
2. Recommendations derived from the current Home snapshot.

Continue Watching items retain their stable deep links and progress metadata.
The system owns focus, motion, and layout. Velyra supplies enough artwork to fill
a row and uses poster images consistently within a section.

The current orange atmospheric static image is removed. The static fallback is
a restrained near-black brand surface with subtle Velyra ribbon lighting and no
implied controls. If the extension has no privacy-safe snapshot, it returns no
personal content and relies on this fallback.

Snapshot writes are skipped when the semantic item content has not changed.
Timestamps alone do not trigger a rewrite.

## Read-only Stremio addon import

### User flow

Accounts & Sync and the Addons screen expose **Import from Stremio**.

1. Velyra requests a temporary linking code from the official Stremio link
   service.
2. The screen shows the official link and code suitable for completion on a
   phone or computer. No Stremio password is typed into Velyra.
3. Velyra polls with a bounded interval until authorization, expiry,
   cancellation, or timeout.
4. The returned auth key is held in memory only.
5. Velyra calls the official read endpoint for the user's addon collection.
6. Descriptors are normalized into candidate HTTPS manifest URLs.
7. Candidates are deduplicated and validated with bounded concurrency.
8. A preview labels each candidate as new, already installed, or incompatible.
9. The user selects new compatible addons and confirms Import.
10. Confirmed addons are appended to the existing Velyra order and persisted
    through the current preferences boundary.
11. Velyra revokes the temporary session and erases the in-memory auth key in a
    guaranteed cleanup path.

### Security and ownership

Velyra never:

- stores a Stremio email or password;
- persists the temporary auth key to UserDefaults, iCloud, diagnostics, or logs;
- calls the write endpoint `addonCollectionSet`;
- removes or reorders the user's Stremio addons;
- replaces the user's existing Velyra addon configuration;
- imports insecure remote HTTP URLs.

Localhost addon descriptors returned by a remote account are marked incompatible
on Apple TV. Configured addon URLs can contain user-specific path data, so the UI
and diagnostics display only redacted host/capability information.

The imported manifest URLs become ordinary user-installed Velyra addons and
follow the existing private preference synchronization policy. The preview makes
this explicit before confirmation.

### Descriptor normalization

Stremio collection entries provide an embedded manifest and `transportUrl`.
Normalization:

- accepts an HTTPS URL ending in `manifest.json`;
- otherwise appends `manifest.json` to an HTTPS transport base;
- rejects non-HTTPS, malformed, oversized, and duplicate values;
- validates the normalized URL through the existing addon client before import;
- uses the embedded manifest only for a fast preview, never as proof that the
  transport remains reachable.

## Performance design

### Rendering

- Only the active settings category is constructed.
- Long lists remain lazy and use stable identifiers.
- Nested glass/material surfaces are removed.
- Decorative video decoding remains limited to one active view.
- Home hero and provider logos use `ImagePipeline` target-size downsampling.
- Focus state changes update local lightweight views instead of rebuilding whole
  feed sections.

### Persistence

Rapid preference changes update visible state immediately but coalesce durable
local/cloud writes over a short debounce window. Entering the background or
explicitly requesting sync flushes the latest snapshot immediately. Only the
latest complete snapshot is saved; no preference change is lost.

### Networking

- Stremio polling is cancellable, bounded, and stops when the screen disappears.
- Addon validation uses a small concurrency limit.
- Identical manifest validation requests are deduplicated.
- Existing response-size limits and URLSession cancellation remain mandatory.
- Partial addon failures are represented individually and do not fail the entire
  import.

### Top Shelf

The app computes a semantic snapshot signature. It writes the shared file only
when IDs, artwork, progress, or deep-link-relevant metadata changes.

## Error handling

### Stremio

- Link creation failure: concise retry action.
- Authorization pending: progress plus cancel; no rapid polling.
- Expired code: request a new code without leaving the flow.
- Collection fetch failure: retry while the temporary session is valid.
- Partial validation: show compatible and incompatible candidates together.
- Empty collection: explain that no importable addons were found.
- Cleanup failure: clear local key material regardless and expose a privacy-safe
  status; never retain the key for an automatic retry.

### Settings and Home

Existing values remain visible during persistence failures. Local use continues
when iCloud is unavailable. Loading, empty, offline, partial, and retry states
remain distinct.

## Accessibility behaviour

Accessibility support is conditional, not a default visual mode.

Normal mode includes the full Ribbon Strike, focus scale/depth, native material,
and standard contrast. Velyra reads system environment values:

- Reduce Motion replaces large custom movement with opacity/highlight changes;
- Reduce Transparency replaces glass with solid surfaces;
- Increase Contrast strengthens borders and foreground contrast.

VoiceOver labels, values, and hints remain present because metadata does not
change the visual mode. Every interactive element remains reachable through
directional focus, touch-disabled Siri Remote operation, and external keyboard
navigation.

## Localization

All new user-facing text ships in:

- English;
- Portuguese (Portugal);
- Spanish;
- French.

Settings categories and Home section names use explicit localized display keys.
No raw key such as `home.section.continueWatching` may appear onscreen.

## Privacy and attribution

The privacy manifest does not gain tracking or advertising declarations.
Stremio link and collection requests are user-initiated network activity.
Temporary auth material is memory-only and excluded from diagnostics.

TMDB/JustWatch attribution remains in Home's consolidated footer and About.
Stremio is identified as the source of an import in the import flow; Velyra does
not imply affiliation or ownership.

## Testing strategy

Implementation follows test-driven development.

### Unit tests

- settings category order, labels, and destination mapping;
- focus presentation state resolution;
- preference write coalescing and background flush;
- Stremio link create/read request encoding and response decoding;
- bounded polling cancellation, expiry, and retry;
- addon collection request encoding;
- transport URL normalization and HTTPS enforcement;
- candidate deduplication and status classification;
- merge that appends selected new addons without replacing existing addons;
- guaranteed temporary-session cleanup on success, failure, and cancellation;
- Top Shelf semantic snapshot comparison and unchanged-write suppression;
- launch ident policy for cold launch and Reduce Motion;
- onboarding completion through one action.

### Repository validation

- static project validation;
- String Catalog completeness;
- XcodeGen project generation;
- Swift type-check with the available tvOS SDK;
- focused XCTest targets, then the complete available test suite;
- brand asset dimension and alpha validation;
- no secrets, auth keys, or raw Stremio URLs in diagnostics fixtures.

### Physical Apple TV acceptance

- native/collapsed sidebar behaviour;
- Menu/Back and focus restoration;
- every button's normal, focused, pressed, and disabled states;
- no clipped focus at the edges of rails;
- Settings readability at television distance;
- cold-launch Ribbon Strike timing and one-shot behaviour;
- normal visual mode with accessibility settings disabled;
- conditional Reduce Motion, Reduce Transparency, Increase Contrast, and
  VoiceOver behaviour;
- Stremio linking from a phone/computer and read-only addon import;
- Top Shelf Continue Watching, recommendation fallback, and static fallback;
- smooth Home vertical navigation and horizontal rail focus.

Hardware acceptance remains required before release and must not be inferred from
source validation on this Mac.

## Non-goals

- Cloning Apple TV artwork, branding, layouts, or private components.
- Cloning Netflix motion, sound, or branding.
- Enabling accessibility preferences on the user's behalf.
- Writing addons back to Stremio or maintaining background two-way sync.
- Importing Stremio library, watch history, progress, account profile, or
  streaming-server settings.
- Changing Trakt, playback ranking, Home ranking, addon execution, or remux
  architecture.
- Bundling third-party film/series imagery.

## Acceptance criteria

- Top-level navigation behaves like a native tvOS sidebar on supported systems
  and has a coherent tvOS 17 fallback.
- Content is never obscured by navigation.
- Every button gives visible focused and pressed feedback.
- Settings presents a category centre and readable category details, not one long
  page.
- Onboarding is one screen with one primary decision.
- Ribbon Strike plays once per cold launch and becomes a fade under Reduce
  Motion.
- Accessibility adjustments are inactive unless the matching system preference
  is enabled.
- Top Shelf prioritizes Continue Watching and no longer uses the current orange
  fallback artwork.
- Repeated “Data by …” copy is removed while required attribution remains
  available.
- Stremio addons can be imported through temporary linking without credentials
  or persistent Stremio auth material.
- Stremio import never calls a write endpoint or replaces existing Velyra addons.
- Settings navigation, focus movement, and Home scrolling are measurably less
  expensive through reduced view/material count, bounded work, image pipeline
  reuse, and coalesced persistence.
- All new deterministic behaviour has tests that fail before implementation and
  pass afterward.

## Sources

- Apple, Designing for tvOS:
  <https://developer.apple.com/design/human-interface-guidelines/designing-for-tvos/>
- Apple, Focus and selection:
  <https://developer.apple.com/design/human-interface-guidelines/focus-and-selection/>
- Apple, Tab bars:
  <https://developer.apple.com/design/human-interface-guidelines/tab-bars/>
- Apple, Adaptable tab navigation:
  <https://developer.apple.com/documentation/swiftui/enhancing-your-app-content-with-tab-navigation>
- Apple, Materials:
  <https://developer.apple.com/design/human-interface-guidelines/materials>
- Apple, Top Shelf:
  <https://developer.apple.com/design/human-interface-guidelines/top-shelf>
- Apple, Motion:
  <https://developer.apple.com/design/human-interface-guidelines/motion>
- Stremio Core request and link models:
  <https://github.com/Stremio/stremio-core>
- Stremio addon client collection format:
  <https://github.com/Stremio/stremio-addon-client>
