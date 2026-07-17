#!/usr/bin/env python3
"""Validate Velyra's generated brand asset catalog without Apple tooling."""

from __future__ import annotations

import json
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


@dataclass(frozen=True)
class ExpectedPNG:
    width: int
    height: int
    idiom: str
    scale: str
    alpha: str


EXPECTED_BRAND_ASSETS = {
    "App Icon - Small.imagestack": ("primary-app-icon", "400x240"),
    "App Icon - Large.imagestack": ("primary-app-icon", "1280x768"),
    "Top Shelf Image.imageset": ("top-shelf-image", "1920x720"),
    "Top Shelf Image Wide.imageset": ("top-shelf-image-wide", "2320x720"),
}
EXPECTED_STACK_LAYERS = {
    "AppIcon.brandassets/App Icon - Small.imagestack": ("Mark", "Light", "Background"),
    "AppIcon.brandassets/App Icon - Large.imagestack": ("Mark", "Light", "Background"),
}
EXPECTED_PNGS = {
    "AppIcon.brandassets/App Icon - Small.imagestack/Mark.imagestacklayer/Mark.imageset/mark-400x240.png": ExpectedPNG(400, 240, "tv", "1x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Small.imagestack/Mark.imagestacklayer/Mark.imageset/mark-800x480.png": ExpectedPNG(800, 480, "tv", "2x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Small.imagestack/Light.imagestacklayer/Light.imageset/light-400x240.png": ExpectedPNG(400, 240, "tv", "1x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Small.imagestack/Light.imagestacklayer/Light.imageset/light-800x480.png": ExpectedPNG(800, 480, "tv", "2x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Small.imagestack/Background.imagestacklayer/Background.imageset/background-400x240.png": ExpectedPNG(400, 240, "tv", "1x", "opaque"),
    "AppIcon.brandassets/App Icon - Small.imagestack/Background.imagestacklayer/Background.imageset/background-800x480.png": ExpectedPNG(800, 480, "tv", "2x", "opaque"),
    "AppIcon.brandassets/App Icon - Large.imagestack/Mark.imagestacklayer/Mark.imageset/mark-1280x768.png": ExpectedPNG(1280, 768, "tv", "1x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Large.imagestack/Light.imagestacklayer/Light.imageset/light-1280x768.png": ExpectedPNG(1280, 768, "tv", "1x", "transparent-visible"),
    "AppIcon.brandassets/App Icon - Large.imagestack/Background.imagestacklayer/Background.imageset/background-1280x768.png": ExpectedPNG(1280, 768, "tv", "1x", "opaque"),
    "AppIcon.brandassets/Top Shelf Image.imageset/top-shelf-1920x720.png": ExpectedPNG(1920, 720, "tv", "1x", "opaque"),
    "AppIcon.brandassets/Top Shelf Image.imageset/top-shelf-3840x1440.png": ExpectedPNG(3840, 1440, "tv", "2x", "opaque"),
    "AppIcon.brandassets/Top Shelf Image Wide.imageset/top-shelf-wide-2320x720.png": ExpectedPNG(2320, 720, "tv", "1x", "opaque"),
    "AppIcon.brandassets/Top Shelf Image Wide.imageset/top-shelf-wide-4640x1440.png": ExpectedPNG(4640, 1440, "tv", "2x", "opaque"),
    "OnboardingFallback.imageset/onboarding-fallback-4k.png": ExpectedPNG(3840, 2160, "universal", "1x", "opaque"),
    "VelyraMark.imageset/velyra-mark-1024x1024.png": ExpectedPNG(1024, 1024, "universal", "1x", "transparent-visible"),
}


@dataclass(frozen=True)
class PNGInfo:
    width: int
    height: int
    has_transparent_pixel: bool
    has_visible_pixel: bool
    is_srgb: bool


def relative(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def safe_catalog_target(
    root: Path, contents: Path, filename: str
) -> tuple[Path, Path] | None:
    reference = Path(filename)
    if reference.is_absolute() or ".." in reference.parts:
        return None
    try:
        target = (contents.parent / reference).resolve(strict=False)
    except (OSError, RuntimeError):
        return None
    if not target.is_relative_to(root):
        return None
    return target, target.relative_to(root)


def paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_alpha(raw: bytes, width: int, height: int) -> tuple[bool, bool]:
    row_bytes = width * 4
    expected = height * (row_bytes + 1)
    if len(raw) != expected:
        raise ValueError(f"decoded byte count is {len(raw)}, expected {expected}")

    previous = bytearray(width)
    has_transparent = False
    has_visible = False
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        if filter_type not in range(5):
            raise ValueError(f"unsupported PNG filter {filter_type}")
        scanline = raw[offset : offset + row_bytes]
        offset += row_bytes
        current = bytearray(width)
        for x in range(width):
            encoded = scanline[x * 4 + 3]
            left = current[x - 1] if x else 0
            above = previous[x]
            upper_left = previous[x - 1] if x else 0
            if filter_type == 0:
                alpha = encoded
            elif filter_type == 1:
                alpha = (encoded + left) & 0xFF
            elif filter_type == 2:
                alpha = (encoded + above) & 0xFF
            elif filter_type == 3:
                alpha = (encoded + ((left + above) // 2)) & 0xFF
            else:
                alpha = (encoded + paeth(left, above, upper_left)) & 0xFF
            current[x] = alpha
            has_transparent = has_transparent or alpha < 255
            has_visible = has_visible or alpha > 0
        previous = current
    return has_transparent, has_visible


def read_png(path: Path) -> PNGInfo:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("invalid PNG signature")

    offset = len(PNG_SIGNATURE)
    ihdr: bytes | None = None
    idat: list[bytes] = []
    has_srgb = False
    has_srgb_profile = False
    saw_iend = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated PNG chunk")
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload_start = offset + 8
        payload_end = payload_start + length
        checksum_end = payload_end + 4
        if checksum_end > len(data):
            raise ValueError("truncated PNG chunk payload")
        payload = data[payload_start:payload_end]
        stored_checksum = struct.unpack(">I", data[payload_end:checksum_end])[0]
        actual_checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
        if stored_checksum != actual_checksum:
            raise ValueError(f"invalid {kind.decode('ascii', errors='replace')} CRC")
        if kind == b"IHDR":
            if ihdr is not None:
                raise ValueError("duplicate IHDR")
            ihdr = payload
        elif kind == b"IDAT":
            idat.append(payload)
        elif kind == b"sRGB":
            has_srgb = True
        elif kind == b"iCCP":
            profile_name = payload.split(b"\0", 1)[0].lower()
            has_srgb_profile = b"srgb" in profile_name
        elif kind == b"IEND":
            saw_iend = True
            offset = checksum_end
            if offset != len(data):
                raise ValueError("trailing bytes after IEND")
            break
        offset = checksum_end

    if ihdr is None or len(ihdr) != 13:
        raise ValueError("missing or invalid IHDR")
    if not idat:
        raise ValueError("missing IDAT")
    if not saw_iend:
        raise ValueError("missing IEND")
    width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
        ">IIBBBBB", ihdr
    )
    if width <= 0 or height <= 0:
        raise ValueError("invalid zero PNG dimension")
    if bit_depth != 8:
        raise ValueError(f"bit depth is {bit_depth}, expected 8")
    if color_type != 6:
        raise ValueError(f"color type is {color_type}, expected 6 (RGBA)")
    if compression != 0 or filter_method != 0 or interlace != 0:
        raise ValueError("PNG must use standard compression/filtering and be non-interlaced")
    expected_decoded = height * (width * 4 + 1)
    decompressor = zlib.decompressobj()
    try:
        decoded = decompressor.decompress(b"".join(idat), expected_decoded + 1)
    except (OverflowError, zlib.error) as error:
        raise ValueError(f"invalid IDAT stream: {error}") from error
    if len(decoded) > expected_decoded:
        raise ValueError(
            f"decompressed IDAT exceeds expected {expected_decoded} bytes"
        )
    if decompressor.unconsumed_tail:
        raise ValueError("IDAT stream has unconsumed compressed data")
    if not decompressor.eof:
        raise ValueError("incomplete IDAT stream")
    if decompressor.unused_data:
        raise ValueError("unused data after compressed IDAT stream")
    has_transparent, has_visible = decode_alpha(decoded, width, height)
    return PNGInfo(
        width=width,
        height=height,
        has_transparent_pixel=has_transparent,
        has_visible_pixel=has_visible,
        is_srgb=has_srgb or has_srgb_profile,
    )


def validate_catalog(root: Path) -> list[str]:
    root = Path(root).resolve(strict=False)
    if not root.is_dir():
        return [f"{root.as_posix()}: asset catalog directory is missing"]

    errors: list[str] = []
    documents: dict[Path, object] = {}
    for contents in sorted(root.rglob("Contents.json")):
        try:
            documents[contents] = json.loads(contents.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"{relative(contents, root)}: invalid JSON: {error}")

    referenced: set[Path] = set()
    expected_dimensions: dict[Path, tuple[int, int]] = {}
    must_be_opaque: set[Path] = set()
    must_be_transparent_and_visible: set[Path] = set()

    root_contents = root / "Contents.json"
    if root_contents not in documents:
        errors.append("Contents.json: required catalog file is missing")

    brand_contents_relative = Path("AppIcon.brandassets/Contents.json")
    brand_contents = root / brand_contents_relative
    brand_document = documents.get(brand_contents)
    if brand_document is None:
        errors.append(
            "AppIcon.brandassets/Contents.json: required catalog file is missing"
        )
    elif isinstance(brand_document, dict):
        assets = brand_document.get("assets", [])
        if isinstance(assets, list):
            actual_assets = {
                (item.get("filename"), item.get("role"), item.get("size"))
                for item in assets
                if isinstance(item, dict)
                and all(
                    isinstance(item.get(key), str)
                    for key in ("filename", "role", "size")
                )
            }
            expected_assets = {
                (filename, role, size)
                for filename, (role, size) in EXPECTED_BRAND_ASSETS.items()
            }
            for filename, role, size in sorted(expected_assets - actual_assets):
                errors.append(
                    "AppIcon.brandassets/Contents.json: missing required asset "
                    f"{filename}"
                )
            for filename, role, size in sorted(actual_assets - expected_assets):
                errors.append(
                    "AppIcon.brandassets/Contents.json: unexpected asset "
                    f"{filename} ({role}, {size})"
                )

    for stack_path, expected_roles in EXPECTED_STACK_LAYERS.items():
        stack_contents_relative = Path(stack_path) / "Contents.json"
        stack_document = documents.get(root / stack_contents_relative)
        if stack_document is None:
            errors.append(
                f"{stack_contents_relative.as_posix()}: required catalog file is missing"
            )
            continue
        if isinstance(stack_document, dict):
            layers = stack_document.get("layers", [])
            actual_roles = tuple(
                Path(item["filename"]).stem
                for item in layers
                if isinstance(item, dict) and isinstance(item.get("filename"), str)
            ) if isinstance(layers, list) else ()
            if actual_roles != expected_roles:
                errors.append(
                    f"{stack_contents_relative.as_posix()}: layers must be "
                    + ", ".join(expected_roles)
                )
        for role in expected_roles:
            layer_contents_relative = (
                Path(stack_path) / f"{role}.imagestacklayer/Contents.json"
            )
            if root / layer_contents_relative not in documents:
                errors.append(
                    f"{layer_contents_relative.as_posix()}: required catalog file is missing"
                )

    expected_imagesets: dict[Path, list[tuple[str, ExpectedPNG]]] = {}
    for path_text, specification in EXPECTED_PNGS.items():
        png_relative = Path(path_text)
        expected_dimensions[png_relative] = (specification.width, specification.height)
        if specification.alpha == "opaque":
            must_be_opaque.add(png_relative)
        else:
            must_be_transparent_and_visible.add(png_relative)
        expected_imagesets.setdefault(png_relative.parent, []).append(
            (png_relative.name, specification)
        )
        if not (root / png_relative).is_file():
            errors.append(f"{path_text}: required PNG is missing")

    for imageset_relative, expected_entries in expected_imagesets.items():
        contents_relative = imageset_relative / "Contents.json"
        document = documents.get(root / contents_relative)
        if document is None:
            errors.append(
                f"{contents_relative.as_posix()}: required catalog file is missing"
            )
            continue
        images = document.get("images", []) if isinstance(document, dict) else []
        actual_entries = {
            (item.get("filename"), item.get("idiom"), item.get("scale"))
            for item in images
            if isinstance(item, dict)
        } if isinstance(images, list) else set()
        expected_entry_set = {
            (filename, specification.idiom, specification.scale)
            for filename, specification in expected_entries
        }
        for filename, idiom, scale in sorted(expected_entry_set - actual_entries):
            errors.append(
                f"{(imageset_relative / filename).as_posix()}: required imageset "
                f"reference idiom={idiom} scale={scale} is missing"
            )
        for filename, idiom, scale in sorted(actual_entries - expected_entry_set):
            errors.append(
                f"{contents_relative.as_posix()}: unexpected image slot "
                f"{filename} idiom={idiom} scale={scale}"
            )

    for contents, document in documents.items():
        contents_relative = relative(contents, root)
        if not isinstance(document, dict):
            errors.append(f"{contents_relative}: JSON root must be an object")
            continue
        for collection_name in ("assets", "layers", "images"):
            collection = document.get(collection_name)
            if collection is None:
                continue
            if not isinstance(collection, list):
                errors.append(f"{contents_relative}: {collection_name} must be an array")
                continue
            for item in collection:
                if not isinstance(item, dict):
                    errors.append(f"{contents_relative}: {collection_name} entry must be an object")
                    continue
                filename = item.get("filename")
                if filename is None:
                    continue
                if not isinstance(filename, str) or not filename:
                    errors.append(f"{contents_relative}: filename must be a non-empty string")
                    continue
                resolved_target = safe_catalog_target(root, contents, filename)
                if resolved_target is None:
                    errors.append(
                        f"{contents_relative}: unsafe filename reference {filename!r}"
                    )
                    continue
                target, target_relative = resolved_target
                referenced.add(target_relative)
                if not target.exists():
                    errors.append(f"{target_relative.as_posix()}: referenced file is missing")
                    continue
                if collection_name != "images" or target.suffix.lower() != ".png":
                    continue

                parts = set(target_relative.parts)
                if "Background.imagestacklayer" in parts:
                    must_be_opaque.add(target_relative)
                if "Light.imagestacklayer" in parts or "Mark.imagestacklayer" in parts:
                    must_be_transparent_and_visible.add(target_relative)
                if "VelyraMark.imageset" in parts:
                    must_be_transparent_and_visible.add(target_relative)

    for png in sorted(root.rglob("*.png")):
        png_relative = png.relative_to(root)
        path_text = png_relative.as_posix()
        try:
            png.resolve(strict=False).relative_to(root)
        except (OSError, RuntimeError, ValueError):
            errors.append(f"{path_text}: unsafe PNG path outside asset catalog")
            continue
        if png_relative not in referenced:
            errors.append(f"{path_text}: PNG is not referenced by any Contents.json")
        try:
            info = read_png(png)
        except (OSError, ValueError, struct.error) as error:
            errors.append(f"{path_text}: invalid PNG: {error}")
            continue
        if not info.is_srgb:
            errors.append(f"{path_text}: PNG does not declare an sRGB color space")
        expected = expected_dimensions.get(png_relative)
        if expected is not None and (info.width, info.height) != expected:
            errors.append(
                f"{path_text}: dimensions are {info.width}x{info.height}, "
                f"expected {expected[0]}x{expected[1]}"
            )
        if png_relative in must_be_opaque and info.has_transparent_pixel:
            errors.append(f"{path_text}: expected alpha 255 for every pixel")
        if png_relative in must_be_transparent_and_visible:
            if not info.has_transparent_pixel:
                errors.append(f"{path_text}: expected at least one transparent pixel")
            if not info.has_visible_pixel:
                errors.append(f"{path_text}: expected at least one visible pixel")

    return sorted(set(errors))


def main(argv: list[str] | None = None) -> int:
    arguments = sys.argv[1:] if argv is None else argv
    if len(arguments) > 1:
        print("usage: validate_brand_assets.py [catalog]", file=sys.stderr)
        return 2
    repository_root = Path(__file__).resolve().parents[1]
    catalog = (
        Path(arguments[0])
        if arguments
        else repository_root / "VelyraTV/Resources/Assets.xcassets"
    )
    errors = validate_catalog(catalog)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Velyra brand assets validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
