from __future__ import annotations

import io
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from scripts.validate_project import validate_project_spec


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ValidateProjectSpecTests(unittest.TestCase):
    def test_external_subtitle_controller_isolates_deinit(self) -> None:
        source = (
            REPOSITORY_ROOT / "VelyraTV/Core/Subtitles/ExternalSubtitleController.swift"
        ).read_text(encoding="utf-8")

        self.assertIn("isolated deinit {", source)

    def test_trakt_scrobble_controller_isolates_deinit(self) -> None:
        source = (
            REPOSITORY_ROOT / "VelyraTV/Features/Trakt/TraktScrobbleController.swift"
        ).read_text(encoding="utf-8")

        self.assertIn("isolated deinit {", source)

    def test_top_shelf_provider_matches_async_sdk_contract(self) -> None:
        source = (REPOSITORY_ROOT / "VelyraTopShelf/ContentProvider.swift").read_text(
            encoding="utf-8"
        )

        self.assertIn("@preconcurrency import TVServices", source)
        self.assertIn(
            "override func loadTopShelfContent() async -> TVTopShelfContent?",
            source,
        )
        self.assertNotIn("loadTopShelfContent() async throws", source)

    def test_requires_test_host_to_match_application_product_name(self) -> None:
        project = (REPOSITORY_ROOT / "project.yml").read_text(encoding="utf-8")
        project_with_wrong_test_host = project.replace(
            'TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Velyra.app/Velyra"',
            'TEST_HOST: "$(BUILT_PRODUCTS_DIR)/VelyraTV.app/VelyraTV"',
            1,
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr), self.assertRaises(SystemExit):
            validate_project_spec(project_with_wrong_test_host)

        self.assertIn(
            "VelyraTVTests must set TEST_HOST to the Velyra application product",
            stderr.getvalue(),
        )

    def test_rejects_globally_inherited_app_icon_setting(self) -> None:
        project = (REPOSITORY_ROOT / "project.yml").read_text(encoding="utf-8")
        marker = "  base:\n    SWIFT_VERSION:"
        self.assertEqual(project.count(marker), 1)
        project_with_global_setting = project.replace(
            marker,
            "  base:\n"
            "    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon\n"
            "    SWIFT_VERSION:",
            1,
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr), self.assertRaises(SystemExit):
            validate_project_spec(project_with_global_setting)

        self.assertIn(
            "ASSETCATALOG_COMPILER_APPICON_NAME must only be declared inside "
            "VelyraTV and VelyraTVSideload",
            stderr.getvalue(),
        )


if __name__ == "__main__":
    unittest.main()
