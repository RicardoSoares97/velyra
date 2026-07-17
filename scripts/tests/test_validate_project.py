from __future__ import annotations

import io
import re
import unittest
from contextlib import redirect_stderr
from pathlib import Path

from scripts.validate_project import validate_project_spec


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


class ValidateProjectSpecTests(unittest.TestCase):
    def test_main_actor_distribution_test_uses_nonisolated_store_factories(self) -> None:
        source = (
            REPOSITORY_ROOT / "VelyraTVTests/App/AppStateDistributionTests.swift"
        ).read_text(encoding="utf-8")

        self.assertIn(
            "nonisolated private static func makeLocalUserStateStore", source
        )
        self.assertIn(
            "nonisolated private static func makeLocalPreferencesStore", source
        )
        self.assertNotIn(
            "defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName))", source
        )

    def test_user_defaults_cleanup_does_not_retain_actor_fixture(self) -> None:
        offenders: list[str] = []
        retained_fixture = re.compile(
            r"let\s+(\w+)\s*=.*UserDefaults\(suiteName:[^\n]+\)[!)]*\n"
            r"\s*defer\s*\{\s*\1\.removePersistentDomain"
        )
        for test_file in (REPOSITORY_ROOT / "VelyraTVTests").rglob("*.swift"):
            source = test_file.read_text(encoding="utf-8")
            if retained_fixture.search(source):
                offenders.append(str(test_file.relative_to(REPOSITORY_ROOT)))

        self.assertEqual(
            offenders,
            [],
            "Create a separate UserDefaults instance for actor input and cleanup",
        )

    def test_xctest_autoclosures_do_not_contain_await(self) -> None:
        offenders: list[str] = []
        for test_file in (REPOSITORY_ROOT / "VelyraTVTests").rglob("*.swift"):
            for line_number, line in enumerate(
                test_file.read_text(encoding="utf-8").splitlines(), start=1
            ):
                if "XCT" in line and "await" in line:
                    offenders.append(
                        f"{test_file.relative_to(REPOSITORY_ROOT)}:{line_number}"
                    )

        self.assertEqual(
            offenders,
            [],
            "Evaluate async values before passing them to XCTest autoclosures",
        )

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

    def test_requires_testable_application_module_name(self) -> None:
        project = (REPOSITORY_ROOT / "project.yml").read_text(encoding="utf-8")
        project_with_wrong_module = project.replace(
            "PRODUCT_MODULE_NAME: VelyraTV", "PRODUCT_MODULE_NAME: Velyra", 1
        )
        stderr = io.StringIO()

        with redirect_stderr(stderr), self.assertRaises(SystemExit):
            validate_project_spec(project_with_wrong_module)

        self.assertIn(
            "VelyraTV must set PRODUCT_MODULE_NAME: VelyraTV",
            stderr.getvalue(),
        )

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
