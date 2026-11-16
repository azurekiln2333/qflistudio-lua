"""Regression tests for package rejection and non-destructive CI boundaries."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import ci_app_build as ci


class ApplicationPackageTests(unittest.TestCase):
    def test_failed_command_annotation_escapes_workflow_data(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "build.log"

            def failed(*args, **kwargs):
                kwargs["stdout"].write("Compiler failed at 50%\n::warning::literal source\n")
                return subprocess.CompletedProcess(args[0], 7)

            with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
                with patch.object(ci.subprocess, "run", side_effect=failed), patch("builtins.print") as printed:
                    with self.assertRaisesRegex(RuntimeError, "Command failed \\(7\\)"):
                        ci.run(["fixture-compiler"], log)
            annotations = [call.args[0] for call in printed.call_args_list
                           if call.args[0].startswith("::error::")]
            self.assertEqual(len(annotations), 1)
            self.assertIn("Compiler failed at 50%25%0A::warning::literal source%0A", annotations[0])
            self.assertNotIn("\n", annotations[0])
            self.assertIn("Compiler failed", log.read_text(encoding="utf-8"))

    def test_failure_annotation_redacts_before_truncation_and_stays_bounded(self):
        output = ("Command: fixture\n\n" + "earlier diagnostics\n" * 500
                  + "password=" + "PRIVATE_VALUE" * 500 + "\n"
                  + "Authorization: Bearer private-bearer\n"
                  + '"storePassword": "private-signing-password"\n'
                  + "https://user:private-userinfo@example.invalid/path?sig=private-signature\n"
                  + "-----BEGIN PRIVATE KEY-----\nprivate-key-body\n-----END PRIVATE KEY-----\n"
                  + "final failure 100%\r\n")
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}), patch("builtins.print") as printed:
            ci.annotate_command_failure(Path("compiler.log"), 1, output)
        annotation = printed.call_args.args[0]
        for secret in ("PRIVATE_VALUE", "private-bearer", "private-signing-password",
                       "private-userinfo", "private-signature", "private-key-body"):
            self.assertNotIn(secret, annotation)
        decoded = annotation.removeprefix("::error::").replace("%0D", "\r").replace("%0A", "\n").replace("%25", "%")
        self.assertLessEqual(len(decoded), 4100)
        self.assertTrue(annotation.endswith("final failure 100%25%0D%0A"))

    def test_successful_and_local_commands_do_not_emit_failure_annotations(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "build.log"

            def succeeded(*args, **kwargs):
                kwargs["stdout"].write("Build succeeded\n")
                return subprocess.CompletedProcess(args[0], 0)

            with patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
                with patch.object(ci.subprocess, "run", side_effect=succeeded), patch("builtins.print") as printed:
                    self.assertEqual(ci.run(["fixture-compiler"], log), "Build succeeded\n")
            self.assertFalse(any(call.args[0].startswith("::error::") for call in printed.call_args_list))
            with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}), patch("builtins.print") as printed:
                ci.annotate_command_failure(log, 1, "Local failure")
            printed.assert_not_called()

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
            with patch.object(sys, "argv", argv), patch.object(ci, "annotate_command_failure") as annotate:
                with self.assertRaisesRegex(RuntimeError, "Refusing to reuse existing application packages"):
                    ci.main()
            annotate.assert_not_called()
            after = {p.relative_to(output): p.read_bytes() for p in output.rglob("*") if p.is_file()}
            self.assertEqual(after, before)

    def test_main_validation_failure_emits_sanitized_annotation(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "artifact"
            (output / "reports").mkdir(parents=True)
            manifest_path = output / "manifest.json"
            ci.write_json(manifest_path, {"status": "pending", "packages": []})
            argv = ["ci_app_build.py", "build", "--platform", "windows", "--arch", "x86_64",
                    "--output-dir", str(output)]
            error = ValueError("Missing native runtime 50%\npassword=private-fixture-value")
            with patch.object(sys, "argv", argv), patch.dict(os.environ, {"GITHUB_ACTIONS": "true"}):
                with patch.object(ci, "build", side_effect=error), patch("builtins.print") as printed:
                    with self.assertRaisesRegex(ValueError, "Missing native runtime"):
                        ci.main()
            annotations = [call.args[0] for call in printed.call_args_list
                           if call.args[0].startswith("::error::")]
            self.assertEqual(len(annotations), 1)
            self.assertIn("build-failure.txt", annotations[0])
            self.assertIn("Missing native runtime 50%25%0A", annotations[0])
            self.assertNotIn("private-fixture-value", annotations[0])
            self.assertNotIn("\n", annotations[0])
            self.assertEqual(json.loads(manifest_path.read_text())["status"], "failed")
            self.assertIn("Missing native runtime", (output / "reports/build-failure.txt").read_text())

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
                product.pop("compileSdkVersion", None)
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

    def test_macos_build_requires_ad_hoc_embedded_framework_signing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            args = argparse.Namespace(platform="macos", arch="x86_64", output=root / "artifact",
                                      flutter_root=root / "sdk")
            manifest = {}
            with patch.object(ci, "ROOT", root), patch.object(ci, "collect"):
                with patch.object(ci, "git_head", side_effect=[ci.CORE_COMMIT, ci.FLUTTER_COMMIT]):
                    with patch.object(ci, "core_source_binding", return_value=(root, {})):
                        with patch.object(ci, "run", return_value="") as run:
                            ci.build(args, manifest)
            build_call = next(call for call in run.call_args_list if "build" in call.args[0])
            env = build_call.kwargs["env"]
            self.assertEqual(env["FLUTTER_XCODE_CODE_SIGNING_REQUIRED"], "YES")
            self.assertEqual(env["FLUTTER_XCODE_CODE_SIGN_IDENTITY"], "-")
            self.assertEqual(env["FLUTTER_XCODE_CODE_SIGN_STYLE"], "Manual")

    def test_macos_package_requires_deep_signature_verification(self):
        for signed in (False, True):
            with self.subTest(signed=signed), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                bundle = root / "build/macos/Build/Products/Release/QFLIScript.app"
                for name in ("MacOS/QFLIScript", "Frameworks/FlutterMacOS.framework/FlutterMacOS",
                             "Frameworks/App.framework/App"):
                    path = bundle / "Contents" / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(b"fixture Mach-O")
                (bundle / "Contents/Info.plist").write_bytes(
                    plistlib.dumps({"CFBundleExecutable": "QFLIScript"}))
                output = root / "artifact"
                (output / "reports").mkdir(parents=True)
                args = argparse.Namespace(platform="macos", arch="x86_64", output=output)
                manifest = {"packages": [], "application_package": False}

                def inspect(command, log):
                    if command[0] == "lipo":
                        return "x86_64\n"
                    if command[0] == "nm":
                        return "\n".join("0000 T _" + symbol for symbols in ci.REQUIRED_EXPORTS.values()
                                         for symbol in symbols)
                    if command[:2] == ["codesign", "--verify"] and not signed:
                        raise RuntimeError("App.framework is not signed at all")
                    return "valid on disk\n"

                with patch.object(ci, "ROOT", root), patch.object(ci, "inspect_assets", return_value=[]):
                    with patch.object(ci, "run", side_effect=inspect) as run:
                        if signed:
                            ci.collect(args, manifest, root)
                        else:
                            with self.assertRaisesRegex(RuntimeError, "not signed at all"):
                                ci.collect(args, manifest, root)
                verify = next(call for call in run.call_args_list
                              if call.args[0][:2] == ["codesign", "--verify"])
                self.assertEqual(verify.args[0], ["codesign", "--verify", "--deep", "--strict",
                                                "--verbose=2", bundle])
                self.assertEqual(verify.args[1], output / "reports/codesign-verification.log")
                self.assertEqual((output / "packages").exists(), signed)
                self.assertEqual(manifest["application_package"], signed)
                if signed:
                    report = json.loads((output / "reports/package-inspection.json").read_text())[0]
                    self.assertEqual(report["signing_verification"],
                                     "deep_strict_verification_passed_not_notarized")

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
