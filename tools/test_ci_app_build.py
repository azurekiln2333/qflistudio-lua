"""Regression tests for package rejection and non-destructive CI boundaries."""

import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import ci_app_build as ci


class ApplicationPackageTests(unittest.TestCase):
    def test_init_refusal_preserves_an_existing_successful_run(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact"
            (output / "packages").mkdir(parents=True)
            (output / "packages/previous.tar.gz").write_bytes(b"previous successful package")
            (output / "manifest.json").write_bytes(b'{"status":"passed","application_package":true}\n')
            (output / "SHA256SUMS").write_bytes(b"previous checksums\n")
            before = {p.relative_to(output): p.read_bytes() for p in output.rglob("*") if p.is_file()}
            argv = ["ci_app_build.py", "init", "--platform", "android", "--arch", "universal",
                    "--output-dir", str(output)]
            with patch.object(sys, "argv", argv):
                with self.assertRaisesRegex(RuntimeError, "Refusing to reuse existing application packages"):
                    ci.main()
            after = {p.relative_to(output): p.read_bytes() for p in output.rglob("*") if p.is_file()}
            self.assertEqual(after, before)

    def test_sdk_fetch_preserves_release_tag_for_git_version_discovery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            upstream = root / "upstream"
            sdk = root / "sdk"
            upstream.mkdir()
            sdk.mkdir()

            def git(cwd, *args):
                return subprocess.check_output(["git", *args], cwd=cwd, text=True,
                                               stderr=subprocess.STDOUT).strip()

            git(upstream, "init")
            git(upstream, "-c", "user.name=CI Test", "-c", "user.email=ci@example.invalid",
                "commit", "--allow-empty", "-m", "Create release fixture")
            git(upstream, "tag", ci.FLUTTER_TAG)
            expected = git(upstream, "rev-parse", "HEAD")
            git(sdk, "init")
            git(sdk, "remote", "add", "origin", str(upstream))
            with patch.object(ci, "FLUTTER_COMMIT", expected):
                ci.checkout_flutter_release(sdk, root / "reports")
            self.assertEqual(git(sdk, "describe", "--tags", "--exact-match"), ci.FLUTTER_TAG)
            self.assertEqual(git(sdk, "rev-parse", "refs/tags/" + ci.FLUTTER_TAG + "^{commit}"), expected)
            self.assertEqual(ci.git_head(sdk), expected)

    def test_sdk_version_rejects_unknown_despite_correct_revision(self):
        version = {"frameworkRevision": ci.FLUTTER_COMMIT,
                   "frameworkVersion": "0.0.0-unknown", "dartSdkVersion": "3.11.5"}
        with self.assertRaisesRegex(RuntimeError, "differs from the pinned release"):
            ci.validate_flutter_version(version)
        version["frameworkVersion"] = ci.FLUTTER_TAG
        ci.validate_flutter_version(version)

    def test_mobile_package_rejects_missing_script_before_staging(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "app-arm64-v8a-release.apk"
            with zipfile.ZipFile(package, "w") as archive:
                for library in ("libflutter.so", "libapp.so", "libqfli_lua.so"):
                    archive.writestr("lib/arm64-v8a/" + library, b"not-yet-inspected")
            with self.assertRaisesRegex(RuntimeError, "Missing arm64-v8a/libqfli_script.so"):
                ci.inspect_mobile(package, argparse.Namespace(platform="android"), Path(directory), ["arm64-v8a"])

    def test_mobile_package_rejects_unrequested_abi(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "app.apk"
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr("lib/x86_64/libflutter.so", b"not-yet-inspected")
            with self.assertRaisesRegex(RuntimeError, "Unexpected package ABIs"):
                ci.inspect_mobile(package, argparse.Namespace(platform="android"), Path(directory), ["arm64-v8a"])

    def test_android_rejects_4k_arm64_load_alignment(self):
        data = bytearray(120)
        data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<HH", data, 16, 3, 183)
        struct.pack_into("<QQQ", data, 24, 0, 64, 120)
        struct.pack_into("<HHHH", data, 54, 56, 1, 64, 0)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<Q", data, 112, 4096)
        with self.assertRaisesRegex(RuntimeError, "below 16 KiB"):
            ci.inspect_elf(data, "arm64-v8a", android=True)
        self.assertEqual(ci.inspect_elf(data, "arm64-v8a")["machine"], 183)

    def test_packaged_assets_must_match_current_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "example.lua"
            source.write_text("print('current')", encoding="utf-8")
            with patch.object(ci, "expected_assets", return_value={"example.lua": source}):
                with self.assertRaisesRegex(RuntimeError, "differs from source"):
                    ci.inspect_assets(["data/flutter_assets/example.lua"], lambda _: b"old", Path(directory))

    def test_ohos_profile_refuses_local_developer_execution(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaisesRegex(RuntimeError, "requires a GitHub Actions checkout"):
                ci.unsigned_ohos_profile()

    def test_ohos_metadata_requires_structured_api26(self):
        for version in (26, "26"):
            ci.validate_ohos_sdk_metadata({"data": {"apiVersion": version}})
        for metadata in ({"data": {"apiVersion": 24}, "description": "API26"},
                         {"apiVersion": 26}, {"data": []}, {}, None):
            with self.subTest(metadata=metadata):
                with self.assertRaisesRegex(RuntimeError, "expected API26"):
                    ci.validate_ohos_sdk_metadata(metadata)

    def test_ohos_unsigned_profile_preserves_targets_and_unrelated_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "ohos/build-profile.json5"
            path.parent.mkdir()
            profile = {
                "app": {
                    "signingConfigs": [{"name": "fixture", "material": "synthetic-only"}],
                    "products": [
                        {"name": "default", "signingConfig": "fixture",
                         "targetSdkVersion": "6.1.1(24)", "compatibleSdkVersion": "5.1.0(18)",
                         "runtimeOS": "HarmonyOS", "buildOption": {"strictMode": True}},
                        {"name": "alternate", "compileSdkVersion": "6.1.1(24)",
                         "targetSdkVersion": "6.1.1(24)", "compatibleSdkVersion": "5.1.0(18)"},
                    ],
                    "buildModeSet": [{"name": "release"}],
                },
                "modules": [{"name": "entry", "srcPath": "./entry"}],
            }
            ci.write_json(path, profile)
            expected = json.loads(json.dumps(profile))
            expected["app"]["signingConfigs"] = []
            for product in expected["app"]["products"]:
                product.pop("signingConfig", None)
                product["compileSdkVersion"] = "26.0.0(26)"
            # Fixtures use JSON, a JSON5 subset. Keep non-OHOS test runners free
            # of the parser installed only in the real OHOS build job.
            with patch.dict(sys.modules, {"json5": json}), patch.object(ci, "ROOT", root):
                with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
                    with patch.object(ci.subprocess, "check_output", return_value="") as status:
                        ci.unsigned_ohos_profile()
            status.assert_called_once_with(
                ["git", "status", "--porcelain", "--", "ohos/build-profile.json5"],
                cwd=root, text=True)
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), expected)

    def test_ohos_profile_rejection_preserves_existing_bytes(self):
        for modified in (True, False):
            with self.subTest(modified=modified), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / "ohos/build-profile.json5"
                path.parent.mkdir()
                before = (b'{"app":{"signingConfigs":[{"name":"synthetic"}],"products":['
                          b'{"targetSdkVersion":"5.1.0(18)","compatibleSdkVersion":"5.1.0(18)"}]}}\r\n')
                path.write_bytes(before)
                status = " M ohos/build-profile.json5\n" if modified else ""
                error = "modified OHOS build profile" if modified else "Unexpected OHOS SDK targets"
                with patch.dict(sys.modules, {"json5": json}), patch.object(ci, "ROOT", root):
                    with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
                        with patch.object(ci.subprocess, "check_output", return_value=status):
                            with self.assertRaisesRegex(RuntimeError, error):
                                ci.unsigned_ohos_profile()
                self.assertEqual(path.read_bytes(), before)

    def test_bridge_check_requires_debugger_and_cancellation_exports(self):
        with self.assertRaisesRegex(RuntimeError, "qfli_lua_debug_new"):
            ci.require_exports(["qfli_lua_version"], "lua")
        with self.assertRaisesRegex(RuntimeError, "qfli_script_token_cancel"):
            ci.require_exports(["qfli_script_version", "qfli_script_process"], "script")

    def test_failed_job_retains_reports_without_success_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact"
            (output / "packages").mkdir(parents=True)
            (output / "packages/app.apk").write_bytes(b"partial")
            (output / "reports").mkdir()
            report = output / "reports/build.log"
            report.write_text("actual failure", encoding="utf-8")
            manifest = {"status": "passed", "application_package": True,
                        "packages": [{"path": "packages/app.apk"}], "verification": "passed"}
            ci.finalize(argparse.Namespace(output=output, job_status="failure"), manifest)
            self.assertFalse((output / "packages").exists())
            self.assertEqual(report.read_text(), "actual failure")
            self.assertEqual(manifest["packages"], [])
            self.assertFalse(manifest["application_package"])
            self.assertEqual(manifest["status"], "failed")

    def assert_late_finalization_failure(self, fault):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "LICENSE").write_text("License fixture", encoding="utf-8")
            output = root / "artifact"
            (output / "packages").mkdir(parents=True)
            (output / "packages/app.apk").write_bytes(b"candidate package")
            (output / "reports").mkdir()
            (output / "reports/build.log").write_text("Build succeeded", encoding="utf-8")
            (output / "SHA256SUMS").write_text("stale checksums", encoding="utf-8")
            manifest_path = output / "manifest.json"
            ci.write_json(manifest_path, {"status": "passed", "application_package": True,
                                         "packages": [{"path": "packages/app.apk"}],
                                         "verification": "release_compiled_and_package_inspected"})
            argv = ["ci_app_build.py", "finalize", "--platform", "android", "--arch", "universal",
                    "--output-dir", str(output)]
            target = ci.shutil if fault == "copy2" else ci
            with patch.object(ci, "ROOT", root), patch.object(sys, "argv", argv):
                with patch.object(target, fault, side_effect=OSError("injected " + fault + " failure")):
                    with self.assertRaisesRegex(OSError, "injected " + fault + " failure"):
                        ci.main()
            actual = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(actual["status"], "failed")
            self.assertFalse(actual["application_package"])
            self.assertEqual(actual["verification"], "failed_see_reports")
            self.assertEqual(actual["packages"], [])
            self.assertFalse((output / "packages").exists())
            self.assertFalse((output / "SHA256SUMS").exists())
            self.assertIn("injected " + fault + " failure", (output / "reports/finalize-failure.txt").read_text())
            self.assertEqual((output / "reports/build.log").read_text(), "Build succeeded")

    def test_license_copy_failure_revokes_package_success(self):
        self.assert_late_finalization_failure("copy2")

    def test_checksum_failure_revokes_package_success(self):
        self.assert_late_finalization_failure("digest")

    def test_web_report_distinguishes_source_suite_from_release_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / "build/web"
            (bundle / "assets").mkdir(parents=True)
            for name in ("index.html", "main.dart.js", "flutter_bootstrap.js", "assets/AssetManifest.bin"):
                (bundle / name).write_bytes(b"fixture")
            output = root / "artifact"
            (output / "reports").mkdir(parents=True)
            manifest = {"browser_tests": "flutter_chrome_tests_passed", "release_bundle_browser_tests": "not_run"}
            args = argparse.Namespace(output=output, platform="web", arch="browser")
            with patch.object(ci, "ROOT", root):
                ci.collect(args, manifest, root / "unused-core")
            report = json.loads((output / "reports/package-inspection.json").read_text())[0]
            self.assertEqual(report["browser_tests"], manifest["browser_tests"])
            self.assertEqual(report["release_bundle_browser_tests"], "not_run")
            self.assertEqual(manifest["release_bundle_browser_tests"], "not_run")


if __name__ == "__main__":
    unittest.main()
