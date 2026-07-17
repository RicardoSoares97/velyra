from __future__ import annotations

import json
import struct
import tempfile
import unittest
import zlib
from pathlib import Path
from unittest.mock import patch

from scripts.validate_brand_assets import validate_catalog


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = zlib.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def write_rgba_png(
    path: Path,
    width: int,
    height: int,
    *,
    transparent_pixel: bool = False,
) -> None:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            alpha = 0 if transparent_pixel and x == 0 and y == 0 else 255
            rows.extend((221, 87, 28, alpha))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"sRGB", b"\x00")
        + png_chunk(b"IDAT", zlib.compress(bytes(rows)))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def filter_bytes(current: bytes, previous: bytes, filter_type: int) -> bytes:
    encoded = bytearray(len(current))
    for index, value in enumerate(current):
        left = current[index - 4] if index >= 4 else 0
        above = previous[index] if previous else 0
        upper_left = previous[index - 4] if previous and index >= 4 else 0
        if filter_type == 1:
            predictor = left
        elif filter_type == 2:
            predictor = above
        elif filter_type == 3:
            predictor = (left + above) // 2
        elif filter_type == 4:
            estimate = left + above - upper_left
            distances = (
                abs(estimate - left),
                abs(estimate - above),
                abs(estimate - upper_left),
            )
            predictor = (left, above, upper_left)[distances.index(min(distances))]
        else:
            predictor = 0
        encoded[index] = (value - predictor) & 0xFF
    return bytes(encoded)


def write_filtered_rgba_png(path: Path, filter_type: int) -> None:
    rows = [
        bytes((221, 87, 28, 0, 221, 87, 28, 255)),
        bytes((221, 87, 28, 128, 221, 87, 28, 255)),
    ]
    filtered = bytearray()
    previous = b""
    for row in rows:
        filtered.append(filter_type)
        filtered.extend(filter_bytes(row, previous, filter_type))
        previous = row
    ihdr = struct.pack(">IIBBBBB", 2, 2, 8, 6, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"sRGB", b"\x00")
        + png_chunk(b"IDAT", zlib.compress(bytes(filtered)))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def write_oversized_png(path: Path) -> None:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    expanded = b"\x00" + b"\x00" * 4096
    data = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"sRGB", b"\x00")
        + png_chunk(b"IDAT", zlib.compress(expanded))
        + png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def image_set(path: Path, filename: str, *, idiom: str = "universal", scale: str = "1x") -> None:
    write_json(
        path / "Contents.json",
        {
            "images": [{"filename": filename, "idiom": idiom, "scale": scale}],
            "info": {"author": "xcode", "version": 1},
        },
    )


class ValidateBrandAssetsTests(unittest.TestCase):
    def test_rejects_absolute_catalog_reference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Catalog.xcassets"
            outside = Path(directory) / "outside.png"
            write_rgba_png(outside, 1, 1)
            image_set(root / "Absolute.imageset", str(outside))

            original_exists = Path.exists

            def guarded_exists(path: Path) -> bool:
                if path == outside:
                    self.fail("validator accessed an unsafe external reference")
                return original_exists(path)

            with patch.object(Path, "exists", guarded_exists):
                errors = validate_catalog(root)

            self.assertIn(
                f"Absolute.imageset/Contents.json: unsafe filename reference {str(outside)!r}",
                errors,
            )

    def test_rejects_parent_catalog_reference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Catalog.xcassets"
            outside = Path(directory) / "outside.png"
            write_rgba_png(outside, 1, 1)
            image_set(root / "Traversal.imageset", "../outside.png")

            errors = validate_catalog(root)

            self.assertIn(
                "Traversal.imageset/Contents.json: unsafe filename reference '../outside.png'",
                errors,
            )

    def test_rejects_symlink_escape_catalog_reference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Catalog.xcassets"
            outside = Path(directory) / "outside.png"
            write_rgba_png(outside, 1, 1)
            image_set(root / "Linked.imageset", "linked.png")
            (root / "Linked.imageset/linked.png").symlink_to(outside)

            errors = validate_catalog(root)

            self.assertIn(
                "Linked.imageset/Contents.json: unsafe filename reference 'linked.png'",
                errors,
            )

    def test_rejects_oversized_idat_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "Oversized.imageset/oversized.png"
            image_set(output.parent, output.name)
            write_oversized_png(output)

            errors = validate_catalog(root)

            self.assertIn(
                "Oversized.imageset/oversized.png: invalid PNG: "
                "decompressed IDAT exceeds expected 5 bytes",
                errors,
            )

    def test_rejects_bytes_after_iend(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / "Trailing.imageset/trailing.png"
            image_set(output.parent, output.name)
            write_rgba_png(output, 1, 1)
            output.write_bytes(output.read_bytes() + b"trailing")

            errors = validate_catalog(root)

            self.assertIn(
                "Trailing.imageset/trailing.png: invalid PNG: trailing bytes after IEND",
                errors,
            )

    def test_decodes_alpha_for_png_filters_1_through_4(self) -> None:
        for filter_type in range(1, 5):
            with self.subTest(filter_type=filter_type), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                output = (
                    root
                    / "AppIcon.brandassets/Test.imagestack/Mark.imagestacklayer"
                    / "Mark.imageset/filtered.png"
                )
                image_set(output.parent, output.name, idiom="tv")
                write_filtered_rgba_png(output, filter_type)

                errors = validate_catalog(root)

                self.assertFalse(
                    [error for error in errors if output.name in error],
                    errors,
                )

    def test_rejects_missing_catalog_reference(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image_set(root / "Missing.imageset", "missing.png")

            errors = validate_catalog(root)

            self.assertIn("Missing.imageset/missing.png: referenced file is missing", errors)

    def test_rejects_wrong_top_shelf_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            brand = root / "AppIcon.brandassets"
            write_json(
                brand / "Contents.json",
                {
                    "assets": [
                        {
                            "filename": "Top Shelf Image.imageset",
                            "idiom": "tv",
                            "role": "top-shelf-image",
                            "size": "1920x720",
                        }
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
            )
            output = brand / "Top Shelf Image.imageset" / "top-shelf-1920x720.png"
            image_set(output.parent, output.name, idiom="tv")
            write_rgba_png(output, 10, 10)

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/Top Shelf Image.imageset/top-shelf-1920x720.png: "
                "dimensions are 10x10, expected 1920x720",
                errors,
            )

    def test_rejects_transparent_background_layer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = (
                root
                / "AppIcon.brandassets/Test.imagestack/Background.imagestacklayer"
                / "Background.imageset/background.png"
            )
            image_set(output.parent, output.name, idiom="tv")
            write_rgba_png(output, 2, 2, transparent_pixel=True)

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/Test.imagestack/Background.imagestacklayer/"
                "Background.imageset/background.png: expected alpha 255 for every pixel",
                errors,
            )

    def test_rejects_opaque_foreground_layer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = (
                root
                / "AppIcon.brandassets/Test.imagestack/Mark.imagestacklayer"
                / "Mark.imageset/mark.png"
            )
            image_set(output.parent, output.name, idiom="tv")
            write_rgba_png(output, 2, 2)

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/Test.imagestack/Mark.imagestacklayer/Mark.imageset/mark.png: "
                "expected at least one transparent pixel",
                errors,
            )

    def test_rejects_empty_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_json(root / "Contents.json", {"info": {"author": "xcode", "version": 1}})

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/Contents.json: required catalog file is missing",
                errors,
            )

    def test_rejects_incomplete_catalog(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            brand = root / "AppIcon.brandassets"
            write_json(
                brand / "Contents.json",
                {
                    "assets": [
                        {
                            "filename": "App Icon - Small.imagestack",
                            "idiom": "tv",
                            "role": "primary-app-icon",
                            "size": "400x240",
                        }
                    ],
                    "info": {"author": "xcode", "version": 1},
                },
            )
            (brand / "App Icon - Small.imagestack").mkdir()

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/Contents.json: missing required asset "
                "Top Shelf Image Wide.imageset",
                errors,
            )

    def test_rejects_wrong_size_icon_layer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = (
                root
                / "AppIcon.brandassets/App Icon - Small.imagestack/Background.imagestacklayer"
                / "Background.imageset/background-400x240.png"
            )
            image_set(output.parent, output.name, idiom="tv")
            write_rgba_png(output, 10, 10)

            errors = validate_catalog(root)

            self.assertIn(
                "AppIcon.brandassets/App Icon - Small.imagestack/Background.imagestacklayer/"
                "Background.imageset/background-400x240.png: dimensions are 10x10, "
                "expected 400x240",
                errors,
            )

    def test_accepts_generated_catalog(self) -> None:
        catalog = REPOSITORY_ROOT / "VelyraTV/Resources/Assets.xcassets"

        self.assertEqual(validate_catalog(catalog), [])


if __name__ == "__main__":
    unittest.main()
