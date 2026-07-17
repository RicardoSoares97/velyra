# tvOS Brand Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved Fita cinematográfica and Radiância escura identity as a valid layered tvOS icon, Top Shelf fallback, reusable mark, and original onboarding artwork.

**Architecture:** Keep the master mark deterministic and vector-based. Generate raster layers reproducibly from a committed Swift renderer, use AI generation only for the original atmospheric onboarding source, and validate every catalog file before Xcode compilation.

**Tech Stack:** SVG, PNG, Xcode asset catalogs, CoreGraphics, ImageIO, Swift scripting, Python `unittest`, Xcode `actool`, XcodeGen.

---

Repository policy prohibits agent-executed Git commands. Manual checkpoints name the suggested user commit.

## File map

- Create `docs/brand/velyra-mark.svg`: canonical vector Fita cinematográfica mark.
- Create `docs/brand/assets.md`: visual rules, prompts, provenance, and export inventory.
- Create `docs/brand/sources/onboarding-atmosphere-source.png`: selected original raster source generated with the built-in image tool.
- Create `scripts/generate_brand_assets.swift`: deterministic PNG and catalog generator.
- Create `scripts/validate_brand_assets.py`: catalog, dimensions, alpha, and file-reference validator.
- Create `scripts/tests/test_validate_brand_assets.py`: isolated validator tests.
- Create generated `VelyraTV/Resources/Assets.xcassets/**`: brand assets consumed by Xcode.
- Modify `project.yml`: include the asset catalog and configure the icon name.
- Modify `scripts/validate_project.py`: invoke brand validation.
- Modify `VelyraTV/Resources/Media/README.md`: distinguish procedural motion from optional licensed MP4.
- Modify `README.md` and `docs/release-readiness.md`: mark identity assets implemented.

### Task 1: Lock the vector identity and brand rules

**Files:**
- Create: `docs/brand/velyra-mark.svg`
- Create: `docs/brand/assets.md`

- [ ] **Step 1: Create the canonical SVG**

Use this exact geometry and no embedded wordmark:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 110 120" role="img" aria-labelledby="title">
  <title id="title">Velyra cinematic ribbon mark</title>
  <defs>
    <linearGradient id="ribbon" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FF9B60"/>
      <stop offset="1" stop-color="#C8370D"/>
    </linearGradient>
  </defs>
  <path d="M10 16 49 104c2 5 9 5 12 0l39-88H77L55 72 33 16H10Z" fill="url(#ribbon)"/>
  <path d="M33 16h25L45 48 33 16Z" fill="#FFE0CC" fill-opacity=".85"/>
</svg>
```

- [ ] **Step 2: Document immutable brand rules**

`docs/brand/assets.md` must state:

- primary orange `#DD571C`;
- mark master view box `110 × 120`;
- no wordmark inside the tvOS icon;
- no pre-rounded corners or masks;
- no film/series imagery, actors, studio marks, watermarks, or UI screenshots;
- opaque full-bleed icon background and transparent upper layers;
- all raster exports are generated, not manually edited;
- in-app `VELYRA` remains localized-accessible SwiftUI text;
- source prompt, generation date, tool mode, selected filename, and post-processing commands are recorded.

- [ ] **Step 3: Validate the SVG as XML**

Run: `plutil -lint docs/brand/velyra-mark.svg`

If `plutil` does not accept SVG on the current macOS, run `xmllint --noout docs/brand/velyra-mark.svg` when available and record `SVG parse passed`. The authoritative visual check occurs in generated PNG tests and Xcode.

- [ ] **Step 4: Manual Git checkpoint**

Ask the user to commit with `design: define Velyra cinematic ribbon identity`.

### Task 2: Generate and select the atmospheric source

**Files:**
- Create: `docs/brand/sources/onboarding-atmosphere-source.png`
- Modify: `docs/brand/assets.md`

- [ ] **Step 1: Generate a preview with the built-in image generation tool**

Use this prompt exactly as the first pass:

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

- [ ] **Step 2: Inspect the generated preview**

Reject it if the central copy area is busy, it contains text/marks, recognizable entertainment IP, faces, or bright high-frequency detail. Perform at most one targeted regeneration that changes only the failing property.

- [ ] **Step 3: Save the selected source inside the workspace**

Copy the chosen built-in result to `docs/brand/sources/onboarding-atmosphere-source.png`. Do not leave the project source under the image tool's generated-images directory.

- [ ] **Step 4: Record provenance**

Add the final prompt, built-in tool mode, original generated dimensions, selected source path, and the statement `Original Velyra artwork; no third-party media inputs` to `docs/brand/assets.md`.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `design: add original onboarding atmosphere`.

### Task 3: Build a deterministic asset generator

**Files:**
- Create: `scripts/generate_brand_assets.swift`
- Create generated: `VelyraTV/Resources/Assets.xcassets/Contents.json`
- Create generated: `VelyraTV/Resources/Assets.xcassets/AppIcon.brandassets/**`
- Create generated: `VelyraTV/Resources/Assets.xcassets/OnboardingFallback.imageset/**`
- Create generated: `VelyraTV/Resources/Assets.xcassets/VelyraMark.imageset/**`

- [ ] **Step 1: Define deterministic inputs and outputs**

Start the Swift script with:

```swift
#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectory)
let source = root.appendingPathComponent("docs/brand/sources/onboarding-atmosphere-source.png")
let catalog = root.appendingPathComponent("VelyraTV/Resources/Assets.xcassets")
let orange = CGColor(red: 0xDD / 255, green: 0x57 / 255, blue: 0x1C / 255, alpha: 1)

guard FileManager.default.fileExists(atPath: source.path) else {
  fatalError("Missing source artwork: \(source.path)")
}
```

The script must delete and recreate only `Assets.xcassets`, never another resource directory.

- [ ] **Step 2: Implement PNG writing and alpha checks**

Add `makeContext(width:height:opaque:)`, `writePNG(_:to:)`, and a `ribbonPath(in:)` helper that maps the canonical SVG points into a destination rectangle. Use 8-bit RGBA sRGB contexts and `CGImageDestination` with `UTType.png.identifier`.

- [ ] **Step 3: Render the three icon layers**

For every Xcode-required icon canvas size, render:

1. Background: opaque near-black radial gradient with a restrained orange glow at the upper-right.
2. Light: transparent canvas with a soft diagonal orange light field; no opaque border.
3. Mark: transparent canvas with the ribbon path centered inside 68 percent of the safe rectangle and a crisp highlight facet.

Render from vector geometry at each final pixel size; never upscale an 800 × 480 bitmap.

- [ ] **Step 4: Generate the brand asset catalog structure**

Generate `AppIcon.brandassets/Contents.json` with entries for the tvOS small app icon stack, large/App Store stack, Top Shelf image, and wide Top Shelf image as required by the installed Xcode asset schema. Each `.imagestack` contains three ordered `.imagestacklayer` directories, each layer contains a `.imageset`, and every JSON file uses:

```json
{
  "info": { "author": "xcode", "version": 1 }
}
```

plus the correct `assets`, `layers`, or `images` array for that directory. Generate sizes from a single table so filenames and JSON references cannot diverge.

- [ ] **Step 5: Generate Top Shelf and onboarding outputs**

Crop the atmospheric source with aspect-fill and a centered focal point. Export static Top Shelf images at 2320 × 720 and 4640 × 1440, preserving the quiet center and adding the vector mark at the left safe margin without wordmark text. Export `OnboardingFallback.imageset/onboarding-fallback-4k.png` at 3840 × 2160 without the mark so SwiftUI can position the identity responsively.

- [ ] **Step 6: Generate the reusable mark image set**

Render a transparent 1024 × 1024 PNG with the ribbon centered inside 70 percent of the canvas and create `VelyraMark.imageset/Contents.json` with a universal single-scale entry.

- [ ] **Step 7: Run the generator twice and prove determinism**

Run:

```bash
swift scripts/generate_brand_assets.swift
find VelyraTV/Resources/Assets.xcassets -type f -exec shasum -a 256 {} \; | sort > /tmp/velyra-assets-first.sha
swift scripts/generate_brand_assets.swift
find VelyraTV/Resources/Assets.xcassets -type f -exec shasum -a 256 {} \; | sort > /tmp/velyra-assets-second.sha
diff -u /tmp/velyra-assets-first.sha /tmp/velyra-assets-second.sha
```

Expected: `diff` produces no output.

- [ ] **Step 8: Manual Git checkpoint**

Ask the user to commit with `design: generate tvOS brand asset catalog`.

### Task 4: Validate the asset catalog independently

**Files:**
- Create: `scripts/validate_brand_assets.py`
- Create: `scripts/tests/test_validate_brand_assets.py`
- Modify: `scripts/validate_project.py`

- [ ] **Step 1: Write failing Python unit tests**

Use `unittest`, `tempfile.TemporaryDirectory`, `json`, and `struct` to create a minimal PNG fixture. Add five concrete methods named `test_rejects_missing_catalog_reference`, `test_rejects_wrong_top_shelf_dimensions`, `test_rejects_transparent_background_layer`, `test_rejects_opaque_foreground_layer`, and `test_accepts_generated_catalog`. Each test constructs the smallest catalog needed for its condition, calls `validate_catalog`, and asserts either the exact offending relative path in the returned errors or an empty error list for the generated catalog.

- [ ] **Step 2: Run tests and verify the missing-module failure**

Run: `python3 -m unittest scripts.tests.test_validate_brand_assets -v`

Expected: import or missing-function failure.

- [ ] **Step 3: Implement the validator**

Expose `validate_catalog(root: Path) -> list[str]`. Recursively parse every `Contents.json`, verify every filename exists, reject unreferenced PNG files, read PNG width/height/color type from the IHDR chunk, require expected Top Shelf and onboarding dimensions, require the icon background layer to be opaque, and require upper layers to have alpha.

The CLI prints every error to stderr and exits 1; success prints `Velyra brand assets validation passed`.

- [ ] **Step 4: Integrate with the project validator**

Import and call `validate_catalog(ROOT / "VelyraTV/Resources/Assets.xcassets")` from `scripts/validate_project.py`, converting returned errors into the existing `fail()` format.

- [ ] **Step 5: Run unit and project validation**

Run:

```bash
python3 -m unittest scripts.tests.test_validate_brand_assets -v
python3 scripts/validate_brand_assets.py
python3 scripts/validate_project.py
```

Expected: all unit tests PASS and both validators print their success line.

- [ ] **Step 6: Manual Git checkpoint**

Ask the user to commit with `test: validate tvOS brand assets`.

### Task 5: Compile assets through XcodeGen

**Files:**
- Modify: `project.yml`
- Modify: `VelyraTV/Resources/Media/README.md`
- Modify: `README.md`
- Modify: `docs/release-readiness.md`

- [ ] **Step 1: Add the catalog to both application targets**

Add `VelyraTV/Resources/Assets.xcassets` to the full and sideload resource lists and set:

```yaml
ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
```

Do not include the brand catalog in the unit-test or Top Shelf extension target.

- [ ] **Step 2: Update media documentation**

State that the first onboarding release uses `OnboardingFallback` plus native SwiftUI motion, optional MP4 files remain licensed-only, and absent MP4 files are not build failures.

- [ ] **Step 3: Update release readiness**

Move app icon, Top Shelf fallback, and onboarding fallback from external requirements to implemented source assets. Keep App Store screenshots and third-party media rights under external requirements.

- [ ] **Step 4: Generate and compile the catalog**

Run:

```bash
swift scripts/generate_brand_assets.swift
python3 scripts/validate_brand_assets.py
xcodegen generate
xcodebuild -project Velyra.xcodeproj -scheme VelyraTV \
  -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build
```

Expected on a healthy runner: `BUILD SUCCEEDED` with no missing app-icon slot or invalid asset warning.

- [ ] **Step 5: Inspect image quality**

Use Xcode's asset preview or a physical Apple TV to confirm no pre-rounded mask, mark safe-zone crop, clean parallax separation, readable Top Shelf composition, and no generated text/watermark artifacts.

- [ ] **Step 6: Manual Git checkpoint**

Ask the user to commit with `design: integrate Velyra tvOS identity`.

### Task 6: Phase verification

**Files:**
- Modify only files from Tasks 1–5 when verification reveals a defect.

- [ ] **Step 1: Run fresh generation and validation**

Run the generator, determinism check, Python unit tests, brand validator, project validator, formatter lint, and XcodeGen.

- [ ] **Step 2: Run full and sideload builds**

Compile both application schemes with signing disabled and run the sideload packaging script. Expected: both builds succeed and the IPA includes the compiled asset catalog.

- [ ] **Step 3: Review provenance and licensing**

Confirm `docs/brand/assets.md` contains the final prompt, tool mode, source path, transformation commands, and no third-party visual inputs.

- [ ] **Step 4: Request review**

Provide previews of the icon layers, Top Shelf fallback, and onboarding fallback; include validation output and suggest `design: complete Velyra tvOS brand assets` for a user-managed squash commit.
