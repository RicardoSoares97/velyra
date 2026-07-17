# Velyra brand assets

This document is the immutable production contract for the approved Velyra identity: the **Fita cinematográfica** mark, the **Radiância escura** icon treatment, and original atmospheric onboarding artwork.

## Canonical identity

- The canonical mark is `docs/brand/velyra-mark.svg`, a deterministic vector master of an abstract V made from a cinematic ribbon of light.
- The primary brand orange is `#DD571C`. Orange is used as light within the Radiância escura direction, not as a flat full-surface fill.
- The mark master view box is exactly `110 × 120` (`viewBox="0 0 110 120"`).
- The vector geometry and gradients in the canonical SVG are authoritative. Do not redraw, trace, or manually alter raster derivatives.
- The tvOS icon contains no wordmark or embedded text.
- In the application, `VELYRA` remains real, localized-accessible SwiftUI text. It must not be baked into raster artwork.

### SVG provenance and rights

- **Authored:** `2026-07-15`.
- **Method:** authored deterministically from the approved exact geometry through a repository text patch; no generative or traced geometry was used.
- **Origin:** original Velyra artwork with no third-party media inputs.
- **Ownership:** project-owned asset. Usage and redistribution are subject to the project owner's terms.
- **Third-party licensing:** no third-party license applies to the SVG artwork.

## Composition and content rules

- Do not pre-round corners and do not apply corner masks. tvOS owns the final icon mask, focus scaling, and parallax crop.
- Icon layers remain rectangular and unmasked. Every icon background is opaque and full bleed; every upper layer is transparent.
- For every icon canvas, center a safe rectangle whose width and height are each `68%` of the final pixel canvas. Aspect-fit and center the complete ribbon inside that rectangle; no ribbon pixel may cross it.
- For the reusable `1024 × 1024` mark, center a safe rectangle whose width and height are each `70%` of the canvas. Aspect-fit and center the complete ribbon inside it.
- Transparent upper layers use hard, clean edges. Do not add baked-in corner treatments.
- Do not use film or series imagery, recognizable franchises, actors, studio marks, film stills, watermarks, UI screenshots, or embedded text.
- Atmospheric bitmap artwork must be original Velyra artwork and must follow the same prohibited-content rules.

## Raster production rules

- All raster exports are generated reproducibly from committed source artwork and generation tooling; they are never manually edited.
- Every raster export uses an `8-bit RGBA sRGB` pixel format.
- Opaque icon backgrounds, Top Shelf images, and onboarding fallback images require `alpha = 255` for every pixel.
- Icon light/mark upper layers and reusable mark exports require real transparency: their alpha channel must contain pixels below `255`, not merely an opaque RGBA channel.
- The three composition roles are an opaque background, an orange light field, and the crisp cinematic-ribbon mark. The Xcode image stack declares them foreground-to-background as `Mark`, `Light`, `Background`.
- Static Top Shelf, onboarding fallback, and reusable in-app mark exports must remain consistent with the canonical vector identity.
- Generated catalog assets are validated for references, dimensions, alpha expectations, color-profile compatibility, and orphaned or duplicate files. Xcode `actool` remains authoritative for catalog compilation.
- Xcode idiom, scale, layer, and slot arrays are emitted from one committed generator table. The generated `Contents.json` files are authoritative, and no filename, slot, scale, or layer ordering decision is made manually.

## Generated export inventory

- `VelyraTV/Resources/Assets.xcassets/AppIcon.brandassets/**`: the layered tvOS small icon stack, large/App Store stack, Top Shelf slot, and wide Top Shelf slot required by the installed Xcode schema.
  - Every icon `.imagestack` declares its layers foreground-to-background as `Mark`, `Light`, `Background`; each role is represented by its own `.imagestacklayer` and nested `.imageset`.
  - Icon PNG names are generated from the role and final pixel canvas using `<role>-<width>x<height>.png`; JSON references use exactly the same generator-table value.
  - Each layer is rendered directly at its final pixel canvas. The official `800 × 480` layout is never upscaled to another required size.
  - Standard Top Shelf exports are `top-shelf-1920x720.png` (`1920 × 720`, 1x) and `top-shelf-3840x1440.png` (`3840 × 1440`, 2x).
  - Wide Top Shelf exports are `top-shelf-wide-2320x720.png` (`2320 × 720`, 1x) and `top-shelf-wide-4640x1440.png` (`4640 × 1440`, 2x).
- `VelyraTV/Resources/Assets.xcassets/OnboardingFallback.imageset/onboarding-fallback-4k.png`: opaque `3840 × 2160` (`16:9`) onboarding fallback without a baked-in mark.
- `VelyraTV/Resources/Assets.xcassets/VelyraMark.imageset/velyra-mark-1024x1024.png`: transparent `1024 × 1024` reusable ribbon mark, centered within the `70%` safe rectangle.

These raster outputs are generated deterministically by `scripts/generate_brand_assets.swift`.

## Atmospheric source provenance

- **Source prompt (verbatim):**

  ```text
  Use case: stylized-concept
  Asset type: original 16:9 4K tvOS onboarding background artwork
  Primary request: create an abstract cinematic environment for Velyra, a premium Apple TV media client designed in Portugal
  Scene/backdrop: deep near-black space with two broad atmospheric fields on the far left and far right, a quiet empty center reserved for white interface copy, subtle ribbons of warm orange light suggesting a film strip without drawing a literal film reel
  Style/medium: polished cinematic digital artwork, restrained, premium, realistic volumetric light with abstract forms only
  Composition/framing: 16:9 landscape, strong negative space in the central 42 percent, visual interest confined to outer thirds, safe for television overscan
  Lighting/mood: dark, calm, elegant, immersive; orange #DD571C accents and soft ember highlights
  Color palette: black, charcoal, burnt orange, restrained warm highlights
  Constraints: no people, faces, characters, recognizable places, film stills, logos, letters, words, interface elements, play icons, posters, brand marks, watermark, hard cuts, flashing patterns, or copyrighted properties
  Avoid: blue-purple streaming-service clichés, neon cyberpunk, excessive particles, busy center, crushed-black detail
  ```

- **Generation date:** `2026-07-15`.
- **Tool mode:** built-in image generation tool mode `stylized-concept` (`image_gen.imagegen`).
- **Original generated dimensions:** `1672 × 941` pixels.
- **Selected source path:** `docs/brand/sources/onboarding-atmosphere-source.png`.
- **SHA-256:** `98ee9e2a66535ccacd39c5dd26de7245cb2285324d298774004b0adc5636588b`.
- **Post-processing commands (verbatim):**

  ```sh
  mkdir -p docs/brand/sources
  cp /Users/ricardo.soares/.codex/generated_images/019f64f3-bdef-7953-a22c-18ff80c1ecfb/exec-100e30e6-8eac-4b7e-8c1d-4d05614a104d.png docs/brand/sources/onboarding-atmosphere-source.png
  ```

No pixel editing or resizing was performed. Original Velyra artwork; no third-party media inputs.
