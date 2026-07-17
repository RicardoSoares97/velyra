#!/usr/bin/env python3
"""Fast, cross-platform consistency checks for the Velyra source tree."""

from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path

if __package__:
    from .validate_brand_assets import validate_catalog as validate_brand_catalog
else:
    from validate_brand_assets import validate_catalog as validate_brand_catalog

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "VelyraTV/Resources/Localizable.xcstrings"
REQUIRED_LOCALES = ("en", "pt-PT", "es", "fr")
PLISTS = (
    "VelyraTV/Resources/Info.plist",
    "VelyraTV/Resources/VelyraTV.entitlements",
    "VelyraTV/Resources/VelyraTVSideload.entitlements",
    "VelyraTV/Resources/PrivacyInfo.xcprivacy",
    "VelyraTopShelf/Info.plist",
    "VelyraTopShelf/VelyraTopShelf.entitlements",
)
RESTRICTED_SIDELOAD_ENTITLEMENTS = {
    "com.apple.developer.icloud-container-identifiers",
    "com.apple.developer.icloud-services",
    "com.apple.developer.ubiquity-kvstore-identifier",
    "com.apple.security.application-groups",
}


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


def validate_brand_assets() -> None:
    errors = validate_brand_catalog(ROOT / "VelyraTV/Resources/Assets.xcassets")
    if errors:
        fail("invalid brand asset catalog:\n" + "\n".join(errors))


def validate_identifiers() -> None:
    with (ROOT / "VelyraTV/Resources/VelyraTV.entitlements").open("rb") as handle:
        app_entitlements = plistlib.load(handle)
    with (ROOT / "VelyraTV/Resources/VelyraTVSideload.entitlements").open("rb") as handle:
        sideload_entitlements = plistlib.load(handle)
    with (ROOT / "VelyraTopShelf/VelyraTopShelf.entitlements").open("rb") as handle:
        extension_entitlements = plistlib.load(handle)

    expected_group = "group.pt.ricardosoares.velyra"
    app_groups = set(app_entitlements.get("com.apple.security.application-groups", []))
    extension_groups = set(extension_entitlements.get("com.apple.security.application-groups", []))
    if expected_group not in app_groups or expected_group not in extension_groups:
        fail("app and Top Shelf extension must share the Velyra app group")

    restricted = sorted(RESTRICTED_SIDELOAD_ENTITLEMENTS.intersection(sideload_entitlements))
    if restricted:
        fail("sideload entitlements contain restricted capabilities: " + ", ".join(restricted))


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


def yaml_block(text: str, key: str, indent: int, *, required: bool = True) -> str | None:
    """Extract one mapping block from the small, indentation-based project spec."""
    lines = text.splitlines()
    header = re.compile(rf"^ {{{indent}}}{re.escape(key)}\s*:\s*(?:#.*)?$")
    matches = [index for index, line in enumerate(lines) if header.fullmatch(line)]
    if not matches:
        if required:
            fail(f"project.yml missing {key} block")
        return None
    if len(matches) != 1:
        fail(f"project.yml contains duplicate {key} blocks")

    start = matches[0]
    end = len(lines)
    for index in range(start + 1, len(lines)):
        line = lines[index]
        if not line.strip():
            continue
        line_indent = len(line) - len(line.lstrip(" "))
        if line_indent <= indent:
            end = index
            break
    return "\n".join(lines[start : end])


def has_yaml_scalar(text: str, key: str, value: str) -> bool:
    pattern = re.compile(
        rf"^\s*{re.escape(key)}\s*:\s*[\"']?{re.escape(value)}[\"']?\s*(?:#.*)?$",
        re.MULTILINE,
    )
    return pattern.search(text) is not None


def has_yaml_key(text: str, key: str, indent: int) -> bool:
    return re.search(rf"^ {{{indent}}}{re.escape(key)}\s*:", text, re.MULTILINE) is not None


def yaml_path_entries(sources: str) -> dict[str, list[str]]:
    lines = sources.splitlines()
    starts: list[tuple[int, int, str]] = []
    pattern = re.compile(r"^(\s*)-\s*path\s*:\s*([^#]+?)\s*(?:#.*)?$")
    for index, line in enumerate(lines):
        match = pattern.fullmatch(line)
        if match:
            path = match.group(2).strip().strip("\"'")
            starts.append((index, len(match.group(1)), path))

    entries: dict[str, list[str]] = {}
    for start, indent, path in starts:
        end = len(lines)
        for index in range(start + 1, len(lines)):
            line = lines[index]
            if not line.strip():
                continue
            line_indent = len(line) - len(line.lstrip(" "))
            if line_indent <= indent:
                end = index
                break
        entries.setdefault(path, []).append("\n".join(lines[start:end]))
    return entries


def require_resource_entries(target_name: str, target: str, paths: tuple[str, ...]) -> None:
    sources = yaml_block(target, "sources", 4)
    assert sources is not None
    entries = yaml_path_entries(sources)
    for path in paths:
        candidates = entries.get(path, [])
        if len(candidates) != 1 or not has_yaml_scalar(candidates[0], "buildPhase", "resources"):
            fail(f"{target_name} resource must use buildPhase resources: {path}")


def reject_resource_entry(target_name: str, target: str, path: str) -> None:
    sources = yaml_block(target, "sources", 4)
    assert sources is not None
    if yaml_path_entries(sources).get(path):
        fail(f"{target_name} must not include resource: {path}")


def validate_project_spec(project: str) -> None:
    schemes = yaml_block(project, "schemes", 0)
    targets = yaml_block(project, "targets", 0)
    assert schemes is not None and targets is not None

    sideload_scheme = yaml_block(schemes, "VelyraTVSideload", 2)
    sideload = yaml_block(targets, "VelyraTVSideload", 2)
    full = yaml_block(targets, "VelyraTV", 2)
    top_shelf = yaml_block(targets, "VelyraTopShelf", 2)
    tests = yaml_block(targets, "VelyraTVTests", 2)
    assert sideload_scheme is not None and sideload is not None
    assert full is not None and top_shelf is not None and tests is not None

    expected_test_host = "$(BUILT_PRODUCTS_DIR)/Velyra.app/Velyra"
    if not has_yaml_scalar(tests, "TEST_HOST", expected_test_host):
        fail("VelyraTVTests must set TEST_HOST to the Velyra application product")
    if not has_yaml_scalar(full, "PRODUCT_MODULE_NAME", "VelyraTV"):
        fail("VelyraTV must set PRODUCT_MODULE_NAME: VelyraTV")

    app_icon_key = re.compile(
        r"^\s*ASSETCATALOG_COMPILER_APPICON_NAME\s*:", re.MULTILINE
    )
    all_app_icon_keys = app_icon_key.findall(project)
    allowed_app_icon_keys = app_icon_key.findall(full) + app_icon_key.findall(sideload)
    if len(all_app_icon_keys) != len(allowed_app_icon_keys):
        fail(
            "ASSETCATALOG_COMPILER_APPICON_NAME must only be declared inside "
            "VelyraTV and VelyraTVSideload"
        )

    scheme_build = yaml_block(sideload_scheme, "build", 4)
    scheme_run = yaml_block(sideload_scheme, "run", 4)
    scheme_archive = yaml_block(sideload_scheme, "archive", 4)
    assert scheme_build is not None and scheme_run is not None and scheme_archive is not None
    if not has_yaml_scalar(scheme_build, "VelyraTVSideload", "all"):
        fail("VelyraTVSideload scheme must build the sideload target")
    if not has_yaml_scalar(scheme_run, "config", "Debug"):
        fail("VelyraTVSideload scheme run action must use Debug")
    if not has_yaml_scalar(scheme_archive, "config", "Release"):
        fail("VelyraTVSideload scheme archive action must use Release")

    required_settings = {
        "type": "application",
        "platform": "tvOS",
        "PRODUCT_BUNDLE_IDENTIFIER": "pt.ricardosoares.velyra.sideload",
        "PRODUCT_NAME": "Velyra",
        "INFOPLIST_FILE": "VelyraTV/Resources/Info.plist",
        "CODE_SIGN_ENTITLEMENTS": "VelyraTV/Resources/VelyraTVSideload.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
    }
    for key, value in required_settings.items():
        if not has_yaml_scalar(sideload, key, value):
            fail(f"VelyraTVSideload must set {key}: {value}")
    if not re.search(
        r"^\s*SWIFT_ACTIVE_COMPILATION_CONDITIONS\s*:.*\bVELYRA_SIDELOAD\b",
        sideload,
        re.MULTILINE,
    ):
        fail("VelyraTVSideload must define VELYRA_SIDELOAD")
    if has_yaml_key(sideload, "dependencies", 4) or "VelyraTopShelf" in sideload:
        fail("VelyraTVSideload must not depend on VelyraTopShelf")
    if has_yaml_key(sideload, "resources", 4):
        fail("VelyraTVSideload resources must be declared as source entries")

    sideload_sources = yaml_block(sideload, "sources", 4)
    assert sideload_sources is not None
    source_entries = yaml_path_entries(sideload_sources)
    for path in ("VelyraTV", "Shared"):
        if len(source_entries.get(path, [])) != 1:
            fail(f"VelyraTVSideload missing source path: {path}")

    app_resources = (
        "VelyraTV/Resources/Assets.xcassets",
        "VelyraTV/Resources/Localizable.xcstrings",
        "VelyraTV/Resources/PrivacyInfo.xcprivacy",
        "VelyraTV/Resources/Media",
    )
    require_resource_entries("VelyraTV", full, app_resources)
    require_resource_entries("VelyraTVSideload", sideload, app_resources)
    require_resource_entries(
        "VelyraTopShelf", top_shelf, ("VelyraTV/Resources/Localizable.xcstrings",)
    )
    for target_name, target in (("VelyraTV", full), ("VelyraTVSideload", sideload)):
        if not has_yaml_scalar(target, "ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"):
            fail(f"{target_name} must set ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon")
    for target_name, target in (("VelyraTopShelf", top_shelf), ("VelyraTVTests", tests)):
        reject_resource_entry(
            target_name, target, "VelyraTV/Resources/Assets.xcassets"
        )
        if re.search(
            r"^\s*ASSETCATALOG_COMPILER_APPICON_NAME\s*:", target, re.MULTILINE
        ):
            fail(f"{target_name} must not set ASSETCATALOG_COMPILER_APPICON_NAME")
    for target_name, target in (
        ("VelyraTV", full),
        ("VelyraTVSideload", sideload),
        ("VelyraTopShelf", top_shelf),
    ):
        if has_yaml_key(target, "resources", 4):
            fail(f"{target_name} resources must be declared as source entries")


def validate_action_pins(workflow_name: str, workflow: str) -> None:
    uses_lines = re.findall(r"^\s*uses:\s*([^\s#]+)(?:\s+#\s*(.+?))?\s*$", workflow, re.MULTILINE)
    if not uses_lines:
        fail(f"{workflow_name} workflow must use at least one pinned action")
    for action, comment in uses_lines:
        reference = action.rsplit("@", 1)[-1] if "@" in action else ""
        if not re.fullmatch(r"[0-9a-f]{40}", reference):
            fail(f"{workflow_name} workflow action must use an immutable 40-character SHA: {action}")
        if not comment or not re.search(r"\bv\d+(?:\.\d+){0,2}\b", comment):
            fail(f"{workflow_name} workflow action pin must have an adjacent version comment: {action}")


def require_workflow_tokens(workflow_name: str, workflow: str, tokens: tuple[str, ...]) -> None:
    missing = [token for token in tokens if token not in workflow]
    if missing:
        fail(f"{workflow_name} workflow missing required contract: " + ", ".join(missing))


def validate_workflow_contract(build: str, release: str, release_notes: str) -> None:
    """Validate the security and publication ordering of the two GitHub workflows."""
    combined = build + "\n" + release
    if "write-all" in combined.lower():
        fail("workflows must not grant write-all permissions")
    if "pull_request_target" in combined.lower():
        fail("workflows must not use pull_request_target")

    require_workflow_tokens(
        "tvOS build",
        build,
        (
            "workflow_dispatch:",
            "contents: read",
            "concurrency:",
            "cancel-in-progress: true",
            "runs-on: macos-26",
            "xcrun --find swift-format",
            '"$GITHUB_PATH"',
            "scripts/ci_validate_tvos.sh",
            "actions/upload-artifact@",
            "retention-days: 14",
            "compression-level: 0",
            "if-no-files-found: error",
            "github.event.pull_request.head.repo.full_name == github.repository",
        ),
    )
    require_workflow_tokens(
        "tvOS release",
        release,
        (
            "tags:",
            "- 'v*'",
            "contents: write",
            "cancel-in-progress: false",
            "runs-on: macos-26",
            "fetch-depth: 0",
            "xcrun --find swift-format",
            '"$GITHUB_PATH"',
            "scripts/validate_release.py",
            "git merge-base --is-ancestor",
            "origin/main",
            "secrets.TRAKT_CLIENT_ID",
            "secrets.TRAKT_CLIENT_SECRET",
            "secrets.TMDB_READ_ACCESS_TOKEN",
            "scripts/ci_validate_tvos.sh",
            "releases/generate-notes",
            "gh release create",
            "--verify-tag --draft",
            "gh release upload",
            "Velyra-sideload-v$VERSION.ipa",
            "Velyra-sideload-v$VERSION.ipa.sha256",
            "CHANGELOG-$TAG.md",
            "expected-assets.txt",
            "actual-assets.txt",
            "diff -u",
            "gh release edit",
            "--draft=false --latest",
        ),
    )

    validate_action_pins("tvOS build", build)
    validate_action_pins("tvOS release", release)

    if re.search(r"git fetch origin main\s+--depth(?:=|\s)", release):
        fail("release workflow must preserve full history for the main ancestry gate")

    forbidden = {
        "APPLE_ID": "workflows must not contain Apple account credentials",
        "APP_STORE_CONNECT": "workflows must not contain App Store Connect credentials",
        "MATCH_PASSWORD": "workflows must not contain signing credentials",
        "security import": "workflows must not import signing identities",
        "codesign ": "workflows must not execute signing commands",
        "-allowProvisioningUpdates": "workflows must not request provisioning updates",
        "CODE_SIGNING_ALLOWED=YES": "workflows must not enable code signing",
        "CODE_SIGNING_REQUIRED=YES": "workflows must not require code signing",
    }
    for token, message in forbidden.items():
        if token.lower() in combined.lower():
            fail(message)

    if "secrets." in build:
        fail("tvOS build workflow must be read-only and must not reference secrets")
    if re.search(r"^\s*permissions:[ \t]+\S", build, re.MULTILINE):
        fail("tvOS build workflow permissions must use an explicit contents: read mapping")

    for variable in ("TRAKT_CLIENT_ID", "TRAKT_CLIENT_SECRET", "TMDB_READ_ACCESS_TOKEN"):
        assignments = re.findall(rf"^\s*{variable}:\s*(.+?)\s*$", release, re.MULTILINE)
        if not assignments or any(f"${{{{ secrets.{variable} }}}}" != value for value in assignments):
            fail(f"release workflow must source {variable} only from its matching GitHub Secret")

    draft_view = release.find("gh release view \"$TAG\" --json isDraft")
    draft_guard = release.find('test "$IS_DRAFT" = true')
    create = release.find("gh release create")
    upload = release.find("gh release upload")
    verify = release.find("diff -u")
    publish = release.find("gh release edit")
    if draft_view < 0 or draft_guard < draft_view or create < draft_guard:
        fail("release workflow must require an existing release to remain draft")
    if not (create < upload < verify < publish):
        fail("release workflow must create a draft, upload assets, verify assets, then publish")

    if "labels: ['*']" not in release_notes and 'labels: ["*"]' not in release_notes:
        fail("release notes configuration must contain the catch-all category")
    for title in ("Features", "Fixes", "Accessibility", "Performance", "Documentation", "Maintenance", "Other changes"):
        if f"title: {title}" not in release_notes:
            fail(f"release notes configuration missing category: {title}")


def validate_project_configuration() -> None:
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    validate_project_spec(project)

    build_workflow = (ROOT / ".github/workflows/tvos-build.yml").read_text(encoding="utf-8")
    release_workflow = (ROOT / ".github/workflows/tvos-release.yml").read_text(encoding="utf-8")
    release_notes = (ROOT / ".github/release.yml").read_text(encoding="utf-8")
    validate_workflow_contract(build_workflow, release_workflow, release_notes)


def main() -> None:
    validate_plists()
    validate_catalog()
    validate_privacy_manifest()
    validate_brand_assets()
    validate_identifiers()
    validate_source_hygiene()
    validate_project_configuration()
    print("Velyra project validation passed")


if __name__ == "__main__":
    main()
