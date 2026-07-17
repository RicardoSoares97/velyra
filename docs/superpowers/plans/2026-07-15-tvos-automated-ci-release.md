# Automated tvOS CI and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make GitHub Actions validate every GitFlow integration and automatically publish a verified unsigned sideload IPA, checksum, and generated changelog from semantic-version tags on `main`.

**Architecture:** Put build logic in one repository script used by both workflows. Keep branch CI read-only and short-lived, while the tag workflow independently rebuilds, stages a draft release, verifies its assets, and publishes only after every gate passes.

**Tech Stack:** GitHub Actions macOS runners, Xcode, XcodeGen, XCTest, POSIX shell, Python 3, GitHub CLI/API, GitHub Releases.

---

Repository policy prohibits the agent from executing Git commands. This plan may add GitHub workflow commands that GitHub itself runs, while local Git checkpoints remain user actions.

## File map

- Create `scripts/validate_release.py`: semantic tag and `MARKETING_VERSION` validation.
- Create `scripts/tests/test_validate_release.py`: pure release metadata tests.
- Create `scripts/ci_validate_tvos.sh`: shared validation, test, build, and IPA orchestration.
- Create `.github/workflows/tvos-release.yml`: tag-gated draft-to-public release workflow.
- Create `.github/release.yml`: generated release-note categories and exclusions.
- Modify `.github/workflows/tvos-build.yml`: current official actions, concurrency, shared script, and artifacts.
- Modify `scripts/validate_project.py`: workflow and release-contract checks.
- Modify `scripts/build_sideload_ipa.sh`: release-friendly output naming inputs when required.
- Modify `README.md`, `docs/gitflow.md`, `docs/release-readiness.md`, and `CONTRIBUTING.md`: release operation and label contract.

### Task 1: Validate semantic release metadata

**Files:**
- Create: `scripts/validate_release.py`
- Create: `scripts/tests/test_validate_release.py`

- [ ] **Step 1: Write pure unit tests**

```python
import tempfile
import unittest
from pathlib import Path

from scripts.validate_release import ReleaseValidationError, validate_release


class ReleaseValidationTests(unittest.TestCase):
    def project(self, version: str) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "project.yml"
        path.write_text(f'settings:\n  base:\n    MARKETING_VERSION: {version}\n')
        return path

    def missing_project(self) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        return Path(directory.name) / "missing.yml"

    def test_accepts_matching_stable_tag(self):
        self.assertEqual(validate_release("v1.2.3", self.project("1.2.3")), "1.2.3")

    def test_rejects_non_semantic_tag(self):
        with self.assertRaisesRegex(ReleaseValidationError, "semantic version"):
            validate_release("release-1.2", self.project("1.2.0"))

    def test_rejects_project_version_mismatch(self):
        with self.assertRaisesRegex(ReleaseValidationError, "MARKETING_VERSION"):
            validate_release("v1.2.3", self.project("1.2.4"))

    def test_rejects_missing_project_version(self):
        with self.assertRaisesRegex(ReleaseValidationError, "missing project file"):
            validate_release("v1.2.3", self.missing_project())
```

- [ ] **Step 2: Run tests and verify the missing-module failure**

Run: `python3 -m unittest scripts.tests.test_validate_release -v`

Expected: import failure because `scripts.validate_release` does not exist.

- [ ] **Step 3: Implement the validator**

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

SEMVER = re.compile(r"^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
PROJECT_VERSION = re.compile(r"^\s*MARKETING_VERSION:\s*[\"']?([^\"'\s]+)[\"']?\s*$", re.MULTILINE)


class ReleaseValidationError(ValueError):
    pass


def validate_release(tag: str, project_path: Path) -> str:
    match = SEMVER.fullmatch(tag)
    if not match:
        raise ReleaseValidationError(f"tag must be a semantic version beginning with v: {tag}")
    if not project_path.exists():
        raise ReleaseValidationError(f"missing project file: {project_path}")
    project_match = PROJECT_VERSION.search(project_path.read_text(encoding="utf-8"))
    if not project_match:
        raise ReleaseValidationError("missing MARKETING_VERSION in project.yml")
    version = tag.removeprefix("v")
    if project_match.group(1) != version:
        raise ReleaseValidationError(
            f"MARKETING_VERSION {project_match.group(1)} does not match tag {version}"
        )
    return version


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--project", type=Path, default=Path("project.yml"))
    args = parser.parse_args()
    try:
        print(validate_release(args.tag, args.project))
    except ReleaseValidationError as error:
        raise SystemExit(f"ERROR: {error}") from error


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the tests and CLI examples**

Run:

```bash
python3 -m unittest scripts.tests.test_validate_release -v
python3 scripts/validate_release.py --tag v0.1.0 --project project.yml
```

Expected: four tests PASS and the CLI prints `0.1.0`.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `test: validate tvOS release versions`.

### Task 2: Create the shared CI entry point

**Files:**
- Create: `scripts/ci_validate_tvos.sh`
- Modify: `scripts/build_sideload_ipa.sh`

- [ ] **Step 1: Create strict environment and tool checks**

```sh
#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_DIR=${SIDELOAD_OUTPUT_DIR:-"$ROOT/artifacts"}

for tool in python3 xcodegen xcodebuild xcrun swift-format; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: missing required tool: $tool" >&2
    exit 1
  }
done

cd "$ROOT"
python3 scripts/validate_project.py
swift-format lint --recursive VelyraTV VelyraTVTests Shared VelyraTopShelf
xcodegen generate
```

- [ ] **Step 2: Resolve a tvOS simulator without a hard-coded model**

Embed the existing Python `xcrun simctl list devices available -j` logic from `tvos-build.yml`, return the first available tvOS UDID, and fail with the full available-device JSON when none exists.

- [ ] **Step 3: Run XCTest and full-target compilation**

Use the resolved UDID for `xcodebuild test` with code coverage and signing disabled. Then build `VelyraTV` for `generic/platform=tvOS` with signing disabled to validate the device SDK and extension embedding contract.

- [ ] **Step 4: Package the sideload target**

Export `SIDELOAD_OUTPUT_DIR="$OUTPUT_DIR"` and call `scripts/build_sideload_ipa.sh`. Require both `Velyra-sideload.ipa` and `Velyra-sideload.ipa.sha256` to be non-empty files.

- [ ] **Step 5: Add deterministic success output**

Print these final lines and nothing containing provider values:

```sh
echo "Velyra tvOS validation passed"
echo "IPA: $OUTPUT_DIR/Velyra-sideload.ipa"
echo "SHA256: $OUTPUT_DIR/Velyra-sideload.ipa.sha256"
```

- [ ] **Step 6: Validate shell syntax**

Run: `sh -n scripts/ci_validate_tvos.sh scripts/build_sideload_ipa.sh`

Expected: exit 0 with no output.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `build: share tvOS CI validation`.

### Task 3: Modernize branch CI and upload artifacts

**Files:**
- Modify: `.github/workflows/tvos-build.yml`

- [ ] **Step 1: Add manual trigger and concurrency**

Keep current GitFlow push and pull-request branches, add `workflow_dispatch`, and add:

```yaml
permissions:
  contents: read

concurrency:
  group: tvos-build-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

- [ ] **Step 2: Use a supported hosted runner and default Xcode**

Use `runs-on: macos-26`. Remove the third-party Xcode selection action. Add a step that prints `sw_vers`, `xcodebuild -version`, `xcodebuild -showsdks`, and fails unless an AppleTVOS SDK and AppleTVSimulator SDK are listed.

- [ ] **Step 3: Resolve immutable official action SHAs**

For `actions/checkout` and `actions/upload-artifact`, query each selected release tag through the GitHub API, verify the returned commit is associated with the official repository, and put the 40-character SHA in `uses:` with a trailing version comment. Use the current Node 24-compatible generations supported by the hosted runner. Do not leave a mutable `@main`, `@master`, or major-only reference.

- [ ] **Step 4: Install XcodeGen and run the shared script**

```yaml
- name: Install XcodeGen
  run: brew install xcodegen

- name: Validate, test, and package tvOS
  run: scripts/ci_validate_tvos.sh
```

- [ ] **Step 5: Upload eligible short-lived artifacts**

Add an official `upload-artifact` step with:

```yaml
if: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
with:
  name: Velyra-sideload-${{ github.sha }}
  path: |
    artifacts/Velyra-sideload.ipa
    artifacts/Velyra-sideload.ipa.sha256
  if-no-files-found: error
  retention-days: 14
  compression-level: 0
```

- [ ] **Step 6: Validate workflow text contract**

Run `python3 scripts/validate_project.py` and inspect the YAML in GitHub's Actions parser after the user pushes it. Expected: one build job, read-only permissions, no secret references, and artifact upload on eligible runs.

- [ ] **Step 7: Manual Git checkpoint**

Ask the user to commit with `ci: build unsigned tvOS artifacts`.

### Task 4: Categorize generated release notes

**Files:**
- Create: `.github/release.yml`
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Add explicit categories**

```yaml
changelog:
  exclude:
    labels:
      - skip-changelog
  categories:
    - title: Features
      labels: [feature, enhancement]
    - title: Fixes
      labels: [bug, fix]
    - title: Accessibility
      labels: [accessibility]
    - title: Performance
      labels: [performance]
    - title: Documentation
      labels: [documentation]
    - title: Maintenance
      labels: [dependencies, maintenance, ci]
    - title: Other changes
      labels: ['*']
```

- [ ] **Step 2: Document label behavior**

In `CONTRIBUTING.md`, state that every release-facing PR receives at least one category label and that `skip-changelog` is restricted to changes with no user or operator impact.

- [ ] **Step 3: Validate YAML structure through GitHub**

After the user pushes the file on a feature branch, use the GitHub-generated notes preview on a draft release or the API in dry-run context. Expected: uncategorized PRs appear under Other changes rather than disappearing.

- [ ] **Step 4: Manual Git checkpoint**

Ask the user to commit with `chore: categorize generated release notes`.

### Task 5: Build the tag-gated draft release workflow

**Files:**
- Create: `.github/workflows/tvos-release.yml`

- [ ] **Step 1: Define trigger, permissions, and concurrency**

```yaml
name: tvOS Release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

concurrency:
  group: tvos-release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  release:
    runs-on: macos-26
```

- [ ] **Step 2: Check out full history with an immutable official action**

Use the same verified checkout SHA as branch CI and set `fetch-depth: 0`. Print Xcode/SDK diagnostics and install XcodeGen exactly as branch CI does.

- [ ] **Step 3: Validate tag, version, and main ancestry**

```sh
TAG=${GITHUB_REF_NAME}
VERSION=$(python3 scripts/validate_release.py --tag "$TAG" --project project.yml)
COMMIT=$(git rev-parse HEAD)
git fetch origin main --depth=1
git merge-base --is-ancestor "$COMMIT" origin/main || {
  echo "ERROR: release tag commit is not reachable from main" >&2
  exit 1
}
{
  echo "tag=$TAG"
  echo "version=$VERSION"
  echo "commit=$COMMIT"
} >> "$GITHUB_OUTPUT"
```

Give this step `id: release_meta`.

- [ ] **Step 4: Require distributable native-client configuration**

Map the three GitHub Secrets into step environment variables. Check each is non-empty without printing it. Explain in the step summary that these values are recoverable from the public IPA and must belong to a rotatable distributed native client.

- [ ] **Step 5: Rebuild and validate independently**

Set `SIDELOAD_OUTPUT_DIR` to `$RUNNER_TEMP/velyra-release` and run `scripts/ci_validate_tvos.sh`. Do not download or reuse a branch artifact.

- [ ] **Step 6: Version the artifact names and recompute checksum**

```sh
OUT="$RUNNER_TEMP/velyra-release"
VERSION='${{ steps.release_meta.outputs.version }}'
mv "$OUT/Velyra-sideload.ipa" "$OUT/Velyra-sideload-v$VERSION.ipa"
shasum -a 256 "$OUT/Velyra-sideload-v$VERSION.ipa" \
  > "$OUT/Velyra-sideload-v$VERSION.ipa.sha256"
```

- [ ] **Step 7: Generate the Markdown changelog before creating a release**

```sh
OUT="$RUNNER_TEMP/velyra-release"
TAG='${{ steps.release_meta.outputs.tag }}'
gh api --method POST "repos/$GITHUB_REPOSITORY/releases/generate-notes" \
  -f tag_name="$TAG" \
  -f target_commitish='${{ steps.release_meta.outputs.commit }}' \
  --jq .body > "$OUT/CHANGELOG-$TAG.md"
test -s "$OUT/CHANGELOG-$TAG.md"
```

Use `GH_TOKEN: ${{ github.token }}` only for GitHub CLI steps.

- [ ] **Step 8: Create or resume a draft release**

If `gh release view "$TAG" --json isDraft --jq .isDraft` succeeds, require the result to be `true`. Otherwise create a draft with `gh release create "$TAG" --verify-tag --draft --title "Velyra $VERSION" --notes-file "$OUT/CHANGELOG-$TAG.md"`.

- [ ] **Step 9: Upload and verify all assets**

Upload and verify with:

```sh
OUT="$RUNNER_TEMP/velyra-release"
TAG='${{ steps.release_meta.outputs.tag }}'
VERSION='${{ steps.release_meta.outputs.version }}'
gh release upload "$TAG" \
  "$OUT/Velyra-sideload-v$VERSION.ipa" \
  "$OUT/Velyra-sideload-v$VERSION.ipa.sha256" \
  "$OUT/CHANGELOG-$TAG.md" \
  --clobber
printf '%s\n' \
  "CHANGELOG-$TAG.md" \
  "Velyra-sideload-v$VERSION.ipa" \
  "Velyra-sideload-v$VERSION.ipa.sha256" | sort > "$RUNNER_TEMP/expected-assets.txt"
gh release view "$TAG" --json assets --jq '.assets[].name' | sort \
  > "$RUNNER_TEMP/actual-assets.txt"
diff -u "$RUNNER_TEMP/expected-assets.txt" "$RUNNER_TEMP/actual-assets.txt"
```

- [ ] **Step 10: Publish only after verification**

Use `gh release edit "$TAG" --draft=false --latest`. Prerelease tags have already been rejected by the metadata validator. Write the final release URL to the job summary.

- [ ] **Step 11: Manual Git checkpoint**

Ask the user to commit with `ci: publish automated tvOS releases`.

### Task 6: Strengthen repository workflow validation

**Files:**
- Modify: `scripts/validate_project.py`
- Modify: `scripts/tests/test_validate_release.py`

- [ ] **Step 1: Add static workflow assertions**

Require:

- branch workflow contains `workflow_dispatch`, concurrency, shared CI script, artifact upload, retention, and `contents: read`;
- release workflow contains tag trigger, `contents: write`, version validator, main ancestry gate, shared CI script, generated notes API, draft creation, three asset upload, asset verification, and final publish;
- `.github/release.yml` contains the catch-all category;
- every `uses:` line contains a 40-character lowercase hexadecimal SHA and an adjacent version comment;
- neither workflow contains Apple credentials, provider values, `pull_request_target`, or signing commands.

- [ ] **Step 2: Add negative fixture tests**

Extend Python tests with temporary workflow text that omits the draft gate, uses `actions/checkout@main`, publishes before upload, or grants `write-all`. Assert stable errors for each violation.

- [ ] **Step 3: Run static validation**

Run:

```bash
python3 -m unittest discover -s scripts/tests -v
python3 scripts/validate_project.py
```

Expected: every test PASS and the project validator prints its success line.

- [ ] **Step 4: Manual Git checkpoint**

Ask the user to commit with `test: enforce tvOS release workflow contract`.

### Task 7: Document GitFlow release operation

**Files:**
- Modify: `README.md`
- Modify: `docs/gitflow.md`
- Modify: `docs/release-readiness.md`

- [ ] **Step 1: Document the exact release sequence**

State that a release branch updates `MARKETING_VERSION`, returns through the normal `main` PR, is merged back into `develop`, and then receives a `vMAJOR.MINOR.PATCH` tag on the `main` commit. The user performs all Git operations.

- [ ] **Step 2: Document release outputs**

List the versioned IPA, SHA-256 checksum, Markdown changelog, categorized release notes, unsigned status, and atvloadly signing/renewal responsibility.

- [ ] **Step 3: Document repository configuration**

List required GitHub Actions secrets by name, recommended branch protections, required status check `tvOS Build`, PR label categories, and least-privilege workflow permissions. Explicitly state that native-client provider configuration can be extracted from the IPA.

- [ ] **Step 4: Document recovery**

Explain that a failed build creates no release, an upload failure leaves a draft, rerunning the tag workflow resumes the draft and replaces assets, and a published release is never silently overwritten.

- [ ] **Step 5: Manual Git checkpoint**

Ask the user to commit with `docs: describe automated tvOS releases`.

### Task 8: End-to-end verification

**Files:**
- Modify only files from Tasks 1–7 when verification reveals a defect.

- [ ] **Step 1: Run every local static check fresh**

Run release-validator tests, brand-validator tests, project validation, shell syntax, formatter lint, XcodeGen, and release metadata validation for the current project version.

- [ ] **Step 2: Validate branch CI in GitHub**

The user pushes the feature branch and opens a PR to `develop`. Expected: simulator tests pass, full and sideload builds succeed, and an eligible run exposes a 14-day artifact containing IPA plus checksum.

- [ ] **Step 3: Validate failure gates without publishing**

On a temporary test tag or workflow branch, prove invalid version, non-main ancestry, absent secret, failing test, and missing artifact all stop before public publication. Delete any draft created during authorized testing through the GitHub UI; the agent does not perform this external mutation without explicit scope.

- [ ] **Step 4: Validate one authorized release**

After the user completes GitFlow and creates an approved semantic tag, verify the public release contains exactly the versioned IPA, checksum, and changelog; notes are categorized; the checksum matches the downloaded IPA; and the IPA passes the local inspection script.

- [ ] **Step 5: Validate physical installation**

Download the unsigned IPA, let atvloadly sign it with the user's Personal Team, install it on Apple TV, and complete the physical acceptance list from the specification.

- [ ] **Step 6: Request final review**

Provide URLs and evidence for the passing workflow and release, the checksum comparison, the IPA inspection, and physical-device results. Suggest `ci: complete automated tvOS delivery` for a user-managed squash commit if desired.
