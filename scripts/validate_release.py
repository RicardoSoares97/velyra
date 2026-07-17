#!/usr/bin/env python3
"""Validate a stable release tag against the XcodeGen project version."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SEMVER = re.compile(
    r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$"
)
PROJECT_VERSION = re.compile(
    r"^\s*MARKETING_VERSION:\s*[\"']?([^\"'\s]+)[\"']?\s*$",
    re.MULTILINE,
)


class ReleaseValidationError(ValueError):
    """Release metadata does not satisfy the stable-version contract."""


def validate_release(tag: str, project_path: Path) -> str:
    if not SEMVER.fullmatch(tag):
        raise ReleaseValidationError(
            f"tag must be a semantic version beginning with v: {tag}"
        )
    if not project_path.is_file():
        raise ReleaseValidationError(f"missing project file: {project_path}")

    try:
        project_text = project_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise ReleaseValidationError(
            f"cannot read project file {project_path}: {error}"
        ) from error

    project_match = PROJECT_VERSION.search(project_text)
    if not project_match:
        raise ReleaseValidationError(
            f"missing MARKETING_VERSION in project file: {project_path}"
        )

    version = tag.removeprefix("v")
    project_version = project_match.group(1)
    if project_version != version:
        raise ReleaseValidationError(
            f"MARKETING_VERSION {project_version} does not match tag {version}"
        )
    return version


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--project", type=Path, default=Path("project.yml"))
    arguments = parser.parse_args()
    try:
        print(validate_release(arguments.tag, arguments.project))
    except ReleaseValidationError as error:
        raise SystemExit(f"ERROR: {error}") from error


if __name__ == "__main__":
    main()
