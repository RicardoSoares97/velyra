from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from scripts.validate_release import ReleaseValidationError, validate_release


class ReleaseValidationTests(unittest.TestCase):
    def project(self, version: str) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "project.yml"
        path.write_text(
            f"settings:\n  base:\n    MARKETING_VERSION: {version}\n",
            encoding="utf-8",
        )
        return path

    def missing_project(self) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        return Path(directory.name) / "missing.yml"

    def project_without_version(self, filename: str = "project.yml") -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / filename
        path.write_text("settings:\n  base: {}\n", encoding="utf-8")
        return path

    def invalid_utf8_project(self) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "project.yml"
        path.write_bytes(b"\xff")
        return path

    def test_accepts_matching_stable_tag(self) -> None:
        self.assertEqual(validate_release("v1.2.3", self.project("1.2.3")), "1.2.3")

    def test_rejects_non_stable_semantic_tag(self) -> None:
        for tag in ("release-1.2", "v1.2.3-rc.1", "v1.2.3+build.4"):
            with self.subTest(tag=tag), self.assertRaisesRegex(
                ReleaseValidationError, "semantic version"
            ):
                validate_release(tag, self.project("1.2.3"))

    def test_rejects_unicode_digit_tag_even_when_project_version_matches(self) -> None:
        unicode_version = "1.2.3\N{ARABIC-INDIC DIGIT FOUR}"

        with self.assertRaisesRegex(ReleaseValidationError, "semantic version"):
            validate_release(f"v{unicode_version}", self.project(unicode_version))

    def test_rejects_project_version_mismatch(self) -> None:
        with self.assertRaisesRegex(ReleaseValidationError, "MARKETING_VERSION"):
            validate_release("v1.2.3", self.project("1.2.4"))

    def test_rejects_missing_project_file(self) -> None:
        with self.assertRaisesRegex(ReleaseValidationError, "missing project file"):
            validate_release("v1.2.3", self.missing_project())

    def test_rejects_missing_project_version(self) -> None:
        project = self.project_without_version("custom-project.yml")

        with self.assertRaises(ReleaseValidationError) as context:
            validate_release("v1.2.3", project)

        self.assertEqual(
            str(context.exception),
            f"missing MARKETING_VERSION in project file: {project}",
        )

    def test_rejects_invalid_utf8_project_content(self) -> None:
        project = self.invalid_utf8_project()

        with self.assertRaisesRegex(
            ReleaseValidationError, f"cannot read project file {project}"
        ):
            validate_release("v1.2.3", project)


if __name__ == "__main__":
    unittest.main()
