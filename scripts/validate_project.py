#!/usr/bin/env python3
"""Fast, cross-platform consistency checks for the Velyra source tree."""

from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "VelyraTV/Resources/Localizable.xcstrings"
REQUIRED_LOCALES = ("en", "pt-PT", "es", "fr")
PLISTS = (
    "VelyraTV/Resources/Info.plist",
    "VelyraTV/Resources/VelyraTV.entitlements",
    "VelyraTV/Resources/PrivacyInfo.xcprivacy",
    "VelyraTopShelf/Info.plist",
    "VelyraTopShelf/VelyraTopShelf.entitlements",
)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_plists() -> None:
    for relative in PLISTS:
        path = ROOT / relative
        if not path.exists():
            fail(f"missing plist: {relative}")
        try:
            with path.open("rb") as handle:
                plistlib.load(handle)
        except Exception as error:  # noqa: BLE001
            fail(f"invalid plist {relative}: {error}")


def validate_catalog() -> None:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.get("strings", {})
    if not strings:
        fail("String Catalog contains no strings")

    incomplete: list[str] = []
    for key, value in strings.items():
        localizations = value.get("localizations", {})
        missing = [
            locale
            for locale in REQUIRED_LOCALES
            if not localizations.get(locale, {}).get("stringUnit", {}).get("value")
        ]
        if missing:
            incomplete.append(f"{key}: {', '.join(missing)}")
    if incomplete:
        fail("missing localizations:\n" + "\n".join(incomplete[:50]))

    patterns = (
        re.compile(r'(?:Text|Button|Label|ProgressView)\("([^"]+)"'),
        re.compile(r'String\(localized:\s*"([^"]+)"'),
        re.compile(r'LocalizedStringKey\("([^"]+)"'),
    )
    used: set[str] = set()
    for path in list((ROOT / "VelyraTV").rglob("*.swift")) + list(
        (ROOT / "VelyraTopShelf").rglob("*.swift")
    ):
        source = path.read_text(encoding="utf-8")
        for pattern in patterns:
            used.update(pattern.findall(source))

    ignored = {"", "Velyra", "VELYRA", "+0.5 s", "-0.5 s", "VIP"}
    missing_keys = sorted(
        key
        for key in used
        if key not in strings
        and key not in ignored
        and "\\(" not in key
        and "{" not in key
    )
    if missing_keys:
        fail("literal localization keys missing from catalog: " + ", ".join(missing_keys))


def validate_privacy_manifest() -> None:
    with (ROOT / "VelyraTV/Resources/PrivacyInfo.xcprivacy").open("rb") as handle:
        manifest = plistlib.load(handle)
    categories = {
        entry.get("NSPrivacyAccessedAPIType")
        for entry in manifest.get("NSPrivacyAccessedAPITypes", [])
    }
    if "NSPrivacyAccessedAPICategoryUserDefaults" not in categories:
        fail("Privacy Manifest must declare UserDefaults required-reason API usage")
    if manifest.get("NSPrivacyTracking") is not False:
        fail("Velyra must not enable tracking")


def validate_identifiers() -> None:
    with (ROOT / "VelyraTV/Resources/VelyraTV.entitlements").open("rb") as handle:
        app_entitlements = plistlib.load(handle)
    with (ROOT / "VelyraTopShelf/VelyraTopShelf.entitlements").open("rb") as handle:
        extension_entitlements = plistlib.load(handle)

    expected_group = "group.pt.ricardosoares.velyra"
    app_groups = set(app_entitlements.get("com.apple.security.application-groups", []))
    extension_groups = set(extension_entitlements.get("com.apple.security.application-groups", []))
    if expected_group not in app_groups or expected_group not in extension_groups:
        fail("app and Top Shelf extension must share the Velyra app group")



def validate_source_hygiene() -> None:
    text_paths = [
        ROOT / "README.md",
        ROOT / "project.yml",
        *list((ROOT / "VelyraTV").rglob("*.swift")),
        *list((ROOT / "VelyraTVTests").rglob("*.swift")),
        *list((ROOT / "Shared").rglob("*.swift")),
        *list((ROOT / "VelyraTopShelf").rglob("*.swift")),
        *list((ROOT / "docs").rglob("*.md")),
    ]

    conflict_markers = ("<<<<<<<", "=======", ">>>>>>>")
    forbidden_imdb_integration_tokens = ("IMDbGateway", "IMDB_GATEWAY")

    for path in text_paths:
        if not path.exists() or not path.is_file():
            continue
        source = path.read_text(encoding="utf-8")
        if any(marker in source for marker in conflict_markers):
            fail(f"unresolved merge conflict marker in {path.relative_to(ROOT)}")
        if any(token in source for token in forbidden_imdb_integration_tokens):
            fail(f"IMDb integration is excluded from this release: {path.relative_to(ROOT)}")


def validate_project_configuration() -> None:
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    required_targets = ("VelyraTV:", "VelyraTopShelf:", "VelyraTVTests:")
    missing = [target for target in required_targets if target not in project]
    if missing:
        fail("project.yml missing required targets: " + ", ".join(missing))

    workflow = (ROOT / ".github/workflows/tvos-build.yml").read_text(encoding="utf-8")
    required_steps = ("scripts/validate_project.py", "xcodegen generate", "xcodebuild", "test")
    missing_steps = [step for step in required_steps if step not in workflow]
    if missing_steps:
        fail("tvOS workflow missing required validation steps: " + ", ".join(missing_steps))

def main() -> None:
    validate_plists()
    validate_catalog()
    validate_privacy_manifest()
    validate_identifiers()
    validate_source_hygiene()
    validate_project_configuration()
    print("Velyra project validation passed")


if __name__ == "__main__":
    main()
