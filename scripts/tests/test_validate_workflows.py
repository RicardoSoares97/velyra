from __future__ import annotations

import io
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from scripts.validate_project import validate_workflow_contract


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ValidateWorkflowContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.build = (REPOSITORY_ROOT / ".github/workflows/tvos-build.yml").read_text(encoding="utf-8")
        self.release = (REPOSITORY_ROOT / ".github/workflows/tvos-release.yml").read_text(encoding="utf-8")
        self.notes = (REPOSITORY_ROOT / ".github/release.yml").read_text(encoding="utf-8")

    def assert_contract_failure(self, build: str, release: str, expected: str) -> None:
        stderr = io.StringIO()
        with redirect_stderr(stderr), self.assertRaises(SystemExit):
            validate_workflow_contract(build, release, self.notes)
        self.assertIn(expected, stderr.getvalue())

    def test_accepts_repository_workflows(self) -> None:
        validate_workflow_contract(self.build, self.release, self.notes)

    def test_rejects_missing_existing_draft_gate(self) -> None:
        release = self.release.replace('test "$IS_DRAFT" = true', 'test -n "$IS_DRAFT"', 1)
        self.assert_contract_failure(
            self.build,
            release,
            "release workflow must require an existing release to remain draft",
        )

    def test_rejects_mutable_action_reference(self) -> None:
        build = self.build.replace(
            "actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2",
            "actions/checkout@main",
            1,
        )
        self.assert_contract_failure(
            build,
            self.release,
            "action must use an immutable 40-character SHA",
        )

    def test_requires_xcode_toolchain_swift_format_on_path(self) -> None:
        build = self.build.replace(
            "xcrun --find swift-format", "command -v swift-format", 1
        )
        self.assert_contract_failure(
            build,
            self.release,
            "tvOS build workflow missing required contract: xcrun --find swift-format",
        )

        release = self.release.replace(
            "xcrun --find swift-format", "command -v swift-format", 1
        )
        self.assert_contract_failure(
            self.build,
            release,
            "tvOS release workflow missing required contract: xcrun --find swift-format",
        )

    def test_rejects_publish_before_upload(self) -> None:
        release = self.release.replace(
            "gh release upload",
            "gh release edit \"$TAG\" --draft=false --latest\n          gh release upload",
            1,
        )
        self.assert_contract_failure(
            self.build,
            release,
            "create a draft, upload assets, verify assets, then publish",
        )

    def test_rejects_shallow_main_ancestry_fetch(self) -> None:
        release = self.release.replace(
            "git fetch origin main",
            "git fetch origin main --depth=1",
            1,
        )
        self.assert_contract_failure(
            self.build,
            release,
            "preserve full history for the main ancestry gate",
        )

    def test_rejects_write_all_permission(self) -> None:
        build = self.build.replace("permissions:\n  contents: read", "permissions: write-all", 1)
        self.assert_contract_failure(
            build,
            self.release,
            "write-all",
        )


if __name__ == "__main__":
    unittest.main()
