"""Regression tests for package rejection and non-destructive CI boundaries."""

import argparse
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import ci_app_build as ci


class ApplicationPackageTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
