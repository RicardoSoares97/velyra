# Velyra Design System

## Direction

Velyra is cinematic, calm and premium. It follows Apple platform behaviour without cloning Apple TV artwork or branding. Content occupies the visual foreground; interface chrome floats above it and disappears when not needed.

## Liquid Glass

On tvOS 26 and later, Velyra uses native Liquid Glass for navigation, actions, contextual panels and transient controls. Earlier tvOS versions use a material fallback with equivalent hierarchy.

Glass is not applied everywhere. It is reserved for:

- top-level navigation;
- primary and secondary actions;
- onboarding status panels;
- settings groups;
- temporary player controls.

Rows of artwork remain mostly opaque to preserve image quality and performance.

## Cinematic backgrounds

- Silent, seamless, licensed video loops.
- Minimal blur, normally 4 pt.
- Dark gradient overlays guarantee readable foreground text.
- Videos stop under Reduce Motion.
- Transparency is reduced or removed under Reduce Transparency.
- No rapid flashes, aggressive zooms or frequent hard cuts.
- Background video is decorative and hidden from VoiceOver.

## Colour

| Token | Value | Purpose |
|---|---:|---|
| Primary | `#DD571C` | Main action and brand identity |
| Primary hover | `#F06A2D` | Highlight |
| Primary pressed | `#B74413` | Pressed action |
| Focus ring | `#FF8A55` | High-visibility focus boundary |
| On primary | `#111114` | Accessible foreground on orange |

## Focus

- Every interactive element has a visible focus state.
- Focus uses scale, depth and outline — never colour alone.
- Artwork scale target: 1.05–1.06.
- Focus movement is short and predictable.
- Focus restoration is required when dismissing details or the player.
- Lists preserve their focused item after data refreshes.

## Responsive TV layout

- Horizontal safe padding is proportional with a minimum of 72 pt.
- Hero text is constrained to avoid overlong lines on large televisions.
- Horizontal rails use lazy stacks.
- Navigation and actions remain usable at overscan-safe margins.
- Text uses system typography and supports larger accessibility sizes.

## Origin signature

“Designed in Portugal” / “Concebida em Portugal” appears subtly in onboarding and About. It is never presented as a badge competing with content.
