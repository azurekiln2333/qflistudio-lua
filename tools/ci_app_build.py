"""Build complete Flutter applications and retain source-bound CI evidence."""

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import struct
import subprocess
import tarfile
import tempfile
import time
import traceback
import zipfile

from inspect_lua_hap import CORE_ASSETS, REQUIRED_EXPORTS, core_source_binding, elf_info


ROOT = Path(__file__).resolve().parents[1]
CORE_COMMIT = "573d1b6eecf1c2b392ad753264a5a09f62f8335e"
FLUTTER_REPOSITORY = "https://gitcode.com/CPF-Flutter/flutter_flutter.git"
FLUTTER_TAG = "3.41.9+ohos-1.0.2"
FLUTTER_COMMIT = "62357a93d653bf844f730bb1f4b7cc9e2139d14e"
TOOLING_COMMIT = "9d2eaf45940e5042637b3387b18292ed39223a4a"
ENGINE_COMMIT = "42d3d75a56efe1a2e9902f52dc8006099c45d937"
OHOS_ENGINE_COMMIT = "4cbeea6a36f7aea39a60f2c5d57b1ffd84bfd106"
OHOS_SDK_RELEASE = "6.1.1.280"
OHOS_SDK_SHA256 = "3d37eb5a3a81358a9731c35265f4f29d8ecf1028b0bbbb777f2928cd6990aa83"
OHOS_PARTS = {
    "aa": "c9bc62586835cb952094349dfd5857a7387d80b34e72562ab8e930aa9bdae02b",
    "ab": "fb964dc01cd385abc9f4d19eb96fa69f841e3a64b87ac94508ae48a8268cee06",
}
MACHINES = {"x86_64": 62, "arm64": 183, "arm64-v8a": 183, "armeabi-v7a": 40}
SIGNING = {
    "android": "debug_key_for_testing_not_store_release",
    "ios": "unsigned_requires_signing_before_device_installation",
    "ohos": "unsigned_requires_signing_before_device_installation",
    "macos": "ad_hoc_not_notarized",
    "linux": "not_applicable",
    "windows": "unsigned_executable",
    "web": "not_applicable",
}


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def run(command, log, *, cwd=ROOT, env=None, timeout=3600):
    """Keep the complete output and propagate a real command failure."""
    command = [str(part) for part in command]
    print("+ " + " ".join(command), flush=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        stream.write("Command: " + repr(command) + "\n\n")
        stream.flush()
        try:
            result = subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout, check=False)
        finally:
            stream.flush()
            output = log.read_text(encoding="utf-8", errors="replace")
            print(output[-12000:], flush=True)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log.name}")
    # Exclude our command heading, for commands that print machine-readable JSON.
    return output.split("\n\n", 1)[1]


def git_head(directory):
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=directory,
                                   text=True).strip()


def flutter(args):
    return args.flutter_root / "bin" / ("flutter.bat" if os.name == "nt" else "flutter")


def environment():
    result = os.environ.copy()
    result.update({
        "FLUTTER_STORAGE_BASE_URL": "https://storage.googleapis.com",
        "FLUTTER_OHOS_STORAGE_BASE_URL": "https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com",
        "PUB_HOSTED_URL": "https://pub.dev",
        "FLUTTER_SUPPRESS_ANALYTICS": "true",
        "CI": "true",
    })
    return result


def publish_environment(values, paths=()):
    for key, value in values.items():
        os.environ[key] = str(value)
    if paths:
        os.environ["PATH"] = os.pathsep.join(map(str, paths)) + os.pathsep + os.environ["PATH"]
    if "GITHUB_ENV" in os.environ:
        with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as stream:
            for key, value in values.items():
                stream.write(f"{key}={value}\n")
    if "GITHUB_PATH" in os.environ:
        with open(os.environ["GITHUB_PATH"], "a", encoding="utf-8") as stream:
            for path in paths:
                stream.write(str(path) + "\n")


def initialize(args):
    packages = args.output / "packages"
    if packages.exists() and any(packages.iterdir()):
        raise RuntimeError("Refusing to reuse existing application packages; choose a fresh output directory")
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "reports").mkdir(exist_ok=True)
    return {
        "platform": args.platform, "architecture": args.arch,
        "source_commit": git_head(ROOT), "core_commit": CORE_COMMIT,
        "entrypoint": "lib/main.dart", "build_mode": "release",
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "status": "pending", "stage": "initialized", "application_package": False,
        "verification": "not_completed", "runtime_tests": "not_run",
        "device_tests": "not_run", "browser_tests": "not_run",
        "signing": SIGNING[args.platform],
        "flutter": {"repository": FLUTTER_REPOSITORY, "tag": FLUTTER_TAG,
                    "commit": FLUTTER_COMMIT, "engine": ENGINE_COMMIT,
                    "ohos_engine": OHOS_ENGINE_COMMIT,
                    "tooling_dependency_override": TOOLING_COMMIT},
        "packages": [],
    }


def checkout_flutter_release(sdk, reports):
    tag_ref = "refs/tags/" + FLUTTER_TAG
    for attempt in range(3):
        try:
            # Flutter derives its public SDK version from the retained release tag.
            # Fetching only into FETCH_HEAD preserves the commit but loses that version.
            run(["git", "fetch", "--depth", "1", "origin", f"{tag_ref}:{tag_ref}"],
                reports / f"sdk-fetch-{attempt + 1}.log", cwd=sdk, timeout=900)
            break
        except (RuntimeError, subprocess.TimeoutExpired):
            if attempt == 2:
                raise
            time.sleep(5)
    tagged_commit = run(["git", "rev-parse", tag_ref + "^{commit}"],
                        reports / "sdk-tag-commit.log", cwd=sdk).strip()
    if tagged_commit != FLUTTER_COMMIT:
        raise RuntimeError("Flutter tag no longer matches the pinned commit")
    run(["git", "checkout", "--detach", tag_ref], reports / "sdk-checkout.log", cwd=sdk)
    if git_head(sdk) != FLUTTER_COMMIT:
        raise RuntimeError("Flutter checkout differs from the verified release tag")


def validate_flutter_version(version):
    if (version.get("frameworkRevision") != FLUTTER_COMMIT
            or version.get("frameworkVersion") != FLUTTER_TAG
            or not version.get("dartSdkVersion", "").startswith("3.11.5")):
        raise RuntimeError("Bootstrapped Flutter/Dart version differs from the pinned release")


def setup_flutter(args, manifest):
    sdk = args.flutter_root
    reports = args.output / "reports"
    sdk.mkdir(parents=True, exist_ok=True)
    if not (sdk / ".git").exists():
        run(["git", "init", sdk], reports / "sdk-init.log")
        run(["git", "remote", "add", "origin", FLUTTER_REPOSITORY],
            reports / "sdk-remote.log", cwd=sdk)
    checkout_flutter_release(sdk, reports)
    for name, expected in (("engine.version", ENGINE_COMMIT),
                           ("engine.ohos.version", OHOS_ENGINE_COMMIT),
                           ("engine.ohos.har.version", OHOS_ENGINE_COMMIT)):
        if (sdk / "bin/internal" / name).read_text().strip() != expected:
            raise RuntimeError(f"Unexpected Flutter engine identity: {name}")
    overrides = "dependency_overrides:\n"
    for package in ("code_assets", "hooks_runner"):
        overrides += (f"  {package}:\n    git:\n"
                      "      url: https://gitcode.com/openharmony-sig/fluttertpc_dart_native\n"
                      f"      path: pkgs/{package}\n      ref: {TOOLING_COMMIT}\n")
    (sdk / "packages/flutter_tools/pubspec_overrides.yaml").write_text(overrides, encoding="utf-8")
    (reports / "flutter-tool-pubspec-overrides.yaml").write_text(overrides, encoding="utf-8")
    sdk_env = environment()
    publish_environment({"QFLI_FLUTTER_ROOT": sdk}, [sdk / "bin"])
    run([flutter(args), "config", "--no-analytics"], reports / "flutter-config.log", env=sdk_env)
    version = run([flutter(args), "--version", "--machine"], reports / "flutter-version.log", env=sdk_env)
    version_data = json.loads(version)
    validate_flutter_version(version_data)
    manifest["flutter"]["version"] = version_data
    flag = {"windows": "--enable-windows-desktop", "linux": "--enable-linux-desktop",
            "macos": "--enable-macos-desktop", "web": "--enable-web"}.get(args.platform)
    if flag:
        run([flutter(args), "config", flag], reports / "flutter-platform-config.log", env=sdk_env)
    run([flutter(args), "precache", "--" + args.platform], reports / "flutter-precache.log", env=sdk_env)
    resolved_locks = []
    for source in (sdk / "pubspec.lock", sdk / "packages/flutter_tools/pubspec.lock"):
        if source.exists():
            name = "flutter-root-pubspec.lock" if source.parent == sdk else "flutter-tools-pubspec.lock"
            shutil.copy2(source, reports / name)
            resolved_locks.append(source.read_text(encoding="utf-8"))
    for package in ("code_assets", "hooks_runner"):
        blocks = [match.group(1) for lock in resolved_locks
                  for match in re.finditer(r"(?ms)^  " + package + r":\n(.*?)(?=^  [a-zA-Z_]|\Z)", lock)]
        if not any(re.search(r"resolved-ref:\s*[\"']?" + TOOLING_COMMIT, block) for block in blocks):
            raise RuntimeError(f"Flutter tooling lock did not resolve {package} to the pinned override")
    manifest["flutter"]["tooling_overrides_verified_in_lock"] = True


def setup_ohos(args, manifest):
    if args.platform != "ohos":
        raise ValueError("OHOS setup is only valid for the OHOS job")
    reports = args.output / "reports"
    sdk_dir = Path(os.environ["RUNNER_TEMP"]) / "qfli-harmonyos-sdk"
    sdk_dir.mkdir(parents=True, exist_ok=True)
    archive = sdk_dir / "ohos-sdk-linux-amd64.tar.gz"
    base = f"https://github.com/ErBWs/ohos-sdk/releases/download/{OHOS_SDK_RELEASE}"
    with archive.open("wb") as combined:
        for part, expected in OHOS_PARTS.items():
            target = archive.with_name(archive.name + "." + part)
            run(["curl", "--fail", "--location", "--retry", "3", "--max-time", "1800",
                 base + "/" + target.name, "-o", target], reports / f"ohos-download-{part}.log")
            if digest(target) != expected:
                raise RuntimeError(f"OHOS SDK checksum mismatch: part {part}")
            with target.open("rb") as stream:
                shutil.copyfileobj(stream, combined, 1024 * 1024)
            target.unlink()
    if digest(archive) != OHOS_SDK_SHA256:
        raise RuntimeError("Combined OHOS SDK checksum mismatch")
    with tarfile.open(archive, "r:gz") as package:
        package.extractall(sdk_dir, filter="data")
    archive.unlink()
    tools = sdk_dir / "command-line-tools"
    metadata_path = tools / "sdk/default/sdk-pkg.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if "6.1.1" not in json.dumps(metadata):
        raise RuntimeError("OHOS SDK does not contain the expected API24 release")
    write_json(reports / "ohos-sdk-pkg.json", metadata)
    publish_environment({"HOS_SDK_HOME": tools / "sdk", "DEVECO_SDK_HOME": tools / "sdk",
                         "DEVECO_NODE_HOME": tools / "tool/node"},
                        [tools / "bin", tools / "tool/node/bin"])
    run([tools / "bin/ohpm", "--version"], reports / "ohpm-version.log")
    run([tools / "bin/hvigorw", "--version"], reports / "hvigor-version.log")
    manifest["ohos_sdk"] = {"release": OHOS_SDK_RELEASE, "source": base,
                            "provenance": "third_party_repackaged_mirror",
                            "sha256": OHOS_SDK_SHA256, "metadata": metadata}


def unsigned_ohos_profile():
    """Change only a clean ephemeral Actions checkout, never a developer profile."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Unsigned OHOS profile generation requires a GitHub Actions checkout")
    status = subprocess.check_output(["git", "status", "--porcelain", "--", "ohos/build-profile.json5"],
                                     cwd=ROOT, text=True)
    if status.strip():
        raise RuntimeError("Refusing to overwrite a modified OHOS build profile")
    import json5
    path = ROOT / "ohos/build-profile.json5"
    profile = json5.loads(path.read_text(encoding="utf-8"))
    app = profile["app"]
    app["signingConfigs"] = []
    for product in app["products"]:
        product.pop("signingConfig", None)
        if (product.get("targetSdkVersion") != "6.1.1(24)"
                or product.get("compatibleSdkVersion") != "5.1.0(18)"):
            raise RuntimeError("Unexpected OHOS SDK targets; review instead of silently changing them")
    path.write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")


def required_file(path):
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Missing or empty application file: {path}")


def expected_assets(core):
    assets = {p.relative_to(ROOT).as_posix(): p for folder in ("assets/content", "assets/runtime")
              for p in (ROOT / folder).glob("*") if p.is_file()}
    # The browser editor uses the same Flutter asset manifest even without native execution.
    assets.update({"packages/qfli_studio_core/" + name: core / name for name in CORE_ASSETS})
    return assets


def inspect_assets(names, read, core):
    receipts = []
    for key, source in expected_assets(core).items():
        suffix = "/flutter_assets/" + key
        matches = [name for name in names if name.endswith(suffix)]
        if len(matches) != 1:
            raise RuntimeError(f"Expected one packaged asset {key}, found {len(matches)}")
        actual = hashlib.sha256(read(matches[0])).hexdigest()
        expected = digest(source)
        if actual != expected:
            raise RuntimeError(f"Packaged asset differs from source: {key}")
        receipts.append({"path": matches[0], "sha256": actual, "source_matches": True})
    return receipts


def inspect_elf(data, abi, *, android=False):
    if data[:4] != b"\x7fELF" or data[5] != 1:
        raise RuntimeError("Expected little-endian ELF")
    machine = struct.unpack_from("<H", data, 18)[0]
    if machine != MACHINES[abi]:
        raise RuntimeError(f"Wrong ELF machine {machine} for {abi}")
    if data[4] == 2:
        info = elf_info(data)
    elif data[4] == 1 and abi == "armeabi-v7a":
        # ELF32 layouts differ from the existing HAP inspector's ELF64 layout.
        kind = struct.unpack_from("<H", data, 16)[0]
        entry, phoff, shoff = struct.unpack_from("<III", data, 24)
        phsize, phnum, shsize, shnum = struct.unpack_from("<HHHH", data, 42)
        alignments = [struct.unpack_from("<I", data, phoff + i * phsize + 28)[0]
                      for i in range(phnum) if struct.unpack_from("<I", data, phoff + i * phsize)[0] == 1]
        sections = [struct.unpack_from("<IIIIIIIIII", data, shoff + i * shsize) for i in range(shnum)]
        symbols = set()
        for section in sections:
            if section[1] != 11:
                continue
            strings = sections[section[6]]
            names = data[strings[4]:strings[4] + strings[5]]
            for offset in range(section[4], section[4] + section[5], section[9]):
                name, _, _, info, visibility, index = struct.unpack_from("<IIIBBH", data, offset)
                if index and info >> 4 in (1, 2) and (visibility & 3) in (0, 3):
                    symbols.add(names[name:names.find(b"\0", name)].decode("utf-8"))
        info = {"machine": machine, "type": kind, "entry": entry,
                "loadAlignments": alignments, "symbols": sorted(symbols)}
    else:
        raise RuntimeError("Unexpected ELF class")
    if info["type"] != 3 or info["entry"] != 0 or not info["loadAlignments"]:
        raise RuntimeError("Expected a loadable shared library")
    if android and abi != "armeabi-v7a" and min(info["loadAlignments"]) < 16384:
        raise RuntimeError("Android 64-bit library LOAD alignment is below 16 KiB")
    return info


def require_exports(symbols, runtime):
    missing = set(REQUIRED_EXPORTS[f"libqfli_{runtime}.so"]) - set(symbols)
    if missing:
        raise RuntimeError(f"Missing {runtime} bridge exports: {', '.join(sorted(missing))}")


def inspect_pe(path):
    data = path.read_bytes()
    offset = struct.unpack_from("<I", data, 60)[0]
    if (data[:2] != b"MZ" or data[offset:offset + 4] != b"PE\0\0"
            or struct.unpack_from("<H", data, offset + 4)[0] != 0x8664):
        raise RuntimeError(f"Not an x64 PE image: {path.name}")


def inspect_mobile(path, args, core, expected_abis):
    android = args.platform == "android"
    prefix = "base/lib/" if path.suffix == ".aab" else "lib/" if android else "libs/"
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        libraries = [name for name in names if name.startswith(prefix) and name.endswith(".so")]
        actual_abis = {name[len(prefix):].split("/", 1)[0] for name in libraries}
        if actual_abis != set(expected_abis):
            raise RuntimeError(f"Unexpected package ABIs: {sorted(actual_abis)}")
        for abi in expected_abis:
            for library in ("libflutter.so", "libapp.so", "libqfli_lua.so", "libqfli_script.so"):
                if prefix + abi + "/" + library not in libraries:
                    raise RuntimeError(f"Missing {abi}/{library} in {path.name}")
        receipts = []
        for name in libraries:
            abi = name[len(prefix):].split("/", 1)[0]
            data = archive.read(name)
            info = inspect_elf(data, abi, android=android)
            for runtime in ("lua", "script"):
                if name.endswith(f"/libqfli_{runtime}.so"):
                    require_exports(info["symbols"], runtime)
            info.pop("symbols")
            receipts.append({"path": name, "sha256": hashlib.sha256(data).hexdigest(), **info})
        assets = inspect_assets(names, archive.read, core)
        if android:
            required = "base/manifest/AndroidManifest.xml" if path.suffix == ".aab" else "AndroidManifest.xml"
        else:
            required = "module.json"
        if required not in names:
            raise RuntimeError(f"Missing application manifest in {path.name}")
        return {"file": path.name, "libraries": receipts, "assets": assets,
                "device_tests": "not_run"}


def inspect_desktop(bundle, args, core):
    paths = [p for p in bundle.rglob("*") if p.is_file()]
    names = ["bundle/" + p.relative_to(bundle).as_posix() for p in paths]
    assets = inspect_assets(names, lambda name: (bundle / name.removeprefix("bundle/")).read_bytes(), core)
    libraries = []
    if args.platform in ("windows", "linux"):
        windows = args.platform == "windows"
        required = (["qfli_lua.exe", "flutter_windows.dll", "data/app.so", "data/icudtl.dat"]
                    if windows else ["qfli_lua", "lib/libflutter_linux_gtk.so", "lib/libapp.so", "data/icudtl.dat"])
        for name in required:
            required_file(bundle / name)
        if windows:
            inspect_pe(bundle / "qfli_lua.exe")
            inspect_pe(bundle / "flutter_windows.dll")
            inspect_elf((bundle / "data/app.so").read_bytes(), args.arch)
        else:
            for name in ("lib/libflutter_linux_gtk.so", "lib/libapp.so"):
                inspect_elf((bundle / name).read_bytes(), args.arch)
        for runtime in ("lua", "script"):
            library = bundle / (f"libqfli_{runtime}.dll" if windows else f"lib/libqfli_{runtime}.so")
            required_file(library)
            if windows:
                inspect_pe(library)
                loaded = ctypes.CDLL(str(library))
                for symbol in REQUIRED_EXPORTS[f"libqfli_{runtime}.so"]:
                    getattr(loaded, symbol)
                evidence = "host_library_loaded_and_exports_resolved"
            else:
                info = inspect_elf(library.read_bytes(), args.arch)
                require_exports(info["symbols"], runtime)
                evidence = "elf_and_bridge_exports_checked"
            libraries.append({"path": library.relative_to(bundle).as_posix(), "sha256": digest(library),
                              "verification": evidence})
    else:
        info_path = bundle / ("Contents/Info.plist" if args.platform == "macos" else "Info.plist")
        with info_path.open("rb") as stream:
            info = plistlib.load(stream)
        executable = bundle / ("Contents/MacOS" if args.platform == "macos" else "") / info["CFBundleExecutable"]
        required_file(executable)
        frameworks = bundle / ("Contents/Frameworks" if args.platform == "macos" else "Frameworks")
        engine_name = "FlutterMacOS" if args.platform == "macos" else "Flutter"
        required_file(frameworks / f"{engine_name}.framework" / engine_name)
        required_file(frameworks / "App.framework/App")
        reports = args.output / "reports"
        for name in (engine_name, "App"):
            binary = frameworks / f"{name}.framework" / name
            arches = run(["lipo", "-archs", binary], reports / f"{name}-architectures.log").strip().split()
            if args.arch not in arches:
                raise RuntimeError(f"{name} framework does not support {args.arch}: {arches}")
            libraries.append({"path": binary.relative_to(bundle).as_posix(), "sha256": digest(binary),
                              "architectures": arches, "verification": "requested_architecture_present"})
        architectures = run(["lipo", "-archs", executable], reports / "runner-architectures.log").strip().split()
        if architectures != [args.arch]:
            raise RuntimeError(f"Unexpected Runner architectures: {architectures}")
        exports = run(["nm", "-gU", executable], reports / "runner-exports.log")
        symbols = {line.split()[-1].removeprefix("_") for line in exports.splitlines() if line.split()}
        for runtime in ("lua", "script"):
            require_exports(symbols, runtime)
        libraries.append({"path": executable.relative_to(bundle).as_posix(),
                          "sha256": digest(executable), "architectures": architectures,
                          "verification": "both_linked_bridge_export_sets_checked"})
    return {"bundle": bundle.name, "libraries": libraries, "assets": assets,
            "device_tests": "not_run", "runtime_tests": "not_run"}


def archive_directory(directory, destination):
    # Tar retains Apple framework symlinks and Unix executable modes through upload-artifact.
    with tarfile.open(destination, "w:gz", dereference=False) as archive:
        archive.add(directory, arcname=directory.name)


def collect(args, manifest, core):
    reports = args.output / "reports"
    packages = args.output / "packages"
    if packages.exists():
        raise RuntimeError("Refusing to stage into an existing packages directory")
    inventories = []
    pending = []
    if args.platform == "android":
        for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
            path = ROOT / f"build/app/outputs/flutter-apk/app-{abi}-release.apk"
            required_file(path)
            inventories.append(inspect_mobile(path, args, core, [abi]))
            sdk = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"])
            aligners = sorted(sdk.glob("build-tools/*/zipalign"), key=lambda p: tuple(int(x) for x in p.parent.name.split(".") if x.isdigit()))
            if not aligners:
                raise RuntimeError("Android SDK zipalign is unavailable")
            run([aligners[-1], "-c", "-P", "16", "-v", "4", path], reports / f"{abi}-zipalign.log")
            pending.append(path)
        path = ROOT / "build/app/outputs/bundle/release/app-release.aab"
        required_file(path)
        inventories.append(inspect_mobile(path, args, core, ["arm64-v8a", "armeabi-v7a", "x86_64"]))
        pending.append(path)
    elif args.platform == "ohos":
        choices = [ROOT / "build/ohos/hap/entry-default-unsigned.hap",
                   ROOT / "ohos/entry/build/default/outputs/default/entry-default-unsigned.hap"]
        path = next((p for p in choices if p.is_file()), None)
        if path is None:
            raise RuntimeError("Flutter did not produce an unsigned HAP")
        inventories.append(inspect_mobile(path, args, core, ["arm64-v8a"]))
        pending.append(path)
    elif args.platform == "web":
        bundle = ROOT / "build/web"
        for name in ("index.html", "main.dart.js", "flutter_bootstrap.js", "assets/AssetManifest.bin"):
            required_file(bundle / name)
        inventories.append({"bundle": "web", "native_execution": "disabled",
                            "browser_tests": "not_run", "files": len(list(bundle.rglob("*")))})
        pending.append(bundle)
        manifest["web_capabilities"] = {"editing_and_saving": "implemented_requires_browser_acceptance",
                                         "native_execution": "disabled"}
    else:
        locations = {"windows": "build/windows/x64/runner/Release", "linux": "build/linux/x64/release/bundle",
                     "macos": "build/macos/Build/Products/Release/QFLIScript.app", "ios": "build/ios/iphoneos/Runner.app"}
        bundle = ROOT / locations[args.platform]
        inventories.append(inspect_desktop(bundle, args, core))
        pending.append(bundle)
    # Validate every output before publishing any package from this attempt.
    write_json(reports / "package-inspection.json", inventories)
    with tempfile.TemporaryDirectory(prefix="app-package-", dir=args.output.parent) as staging:
        staging = Path(staging)
        receipts = []
        for source in pending:
            if source.is_dir():
                destination = staging / f"qfliscript-{args.platform}-{args.arch}.tar.gz"
                archive_directory(source, destination)
            else:
                destination = staging / source.name
                shutil.copy2(source, destination)
            receipts.append({"path": "packages/" + destination.name,
                             "bytes": destination.stat().st_size, "sha256": digest(destination)})
        # All outputs are complete before their final directory becomes uploadable.
        shutil.move(str(staging), packages)
    manifest["packages"] = receipts
    manifest["application_package"] = True
    manifest["verification"] = "release_compiled_and_package_inspected"


def build(args, manifest):
    if git_head(ROOT.parent / "qfli_studio_core") != CORE_COMMIT:
        raise RuntimeError("Core checkout differs from the pinned revision")
    if git_head(args.flutter_root) != FLUTTER_COMMIT:
        raise RuntimeError("Flutter checkout differs from the pinned revision")
    if args.platform == "ohos":
        unsigned_ohos_profile()
    reports = args.output / "reports"
    build_env = environment()
    if args.platform == "macos":
        build_env.update({"FLUTTER_XCODE_ARCHS": args.arch, "FLUTTER_XCODE_ONLY_ACTIVE_ARCH": "YES",
                          "FLUTTER_XCODE_CODE_SIGN_IDENTITY": "-", "FLUTTER_XCODE_CODE_SIGN_STYLE": "Manual",
                          "FLUTTER_XCODE_CODE_SIGNING_REQUIRED": "NO", "FLUTTER_XCODE_MACOSX_DEPLOYMENT_TARGET": "11.0"})
    run([flutter(args), "pub", "get"], reports / "pub-get.log", env=build_env)
    issues = []
    core, binding = core_source_binding(ROOT, issues)
    write_json(reports / "core-source-binding.json", binding)
    if issues:
        raise RuntimeError("; ".join(issues))
    if (ROOT / "pubspec.lock").exists():
        shutil.copy2(ROOT / "pubspec.lock", reports / "app-pubspec.lock")
    if args.platform == "web":
        run([flutter(args), "test", "--no-pub", "test/web_workspace_test.dart", "test/web_app_test.dart"],
            reports / "web-host-tests.log", env=build_env)
        manifest["runtime_tests"] = "web_model_and_widget_tests_passed"
        run([flutter(args), "test", "--no-pub", "--platform", "chrome", "test/web_browser_test.dart"],
            reports / "web-chrome-tests.log", env=build_env)
        manifest["browser_tests"] = "flutter_chrome_tests_passed"
    common = ["--release", "--target", "lib/main.dart", "--no-pub"]
    commands = {"android": [["apk", *common, "--split-per-abi"], ["appbundle", *common]],
                "ios": [["ios", *common, "--no-codesign"]],
                "ohos": [["hap", *common, "--no-codesign", "--target-platform", "ohos-arm64"]]}
    for command in commands.get(args.platform, [[args.platform, *common]]):
        run([flutter(args), "build", *command], reports / f"build-{command[0]}.log", env=build_env)
    collect(args, manifest, core)
    manifest["status"] = "passed"


def finalize(args, manifest):
    if args.job_status != "success" or manifest.get("status") != "passed":
        manifest["status"] = "failed"
        manifest.setdefault("error", "See the workflow step and retained reports for the failed prerequisite")
        packages = args.output / "packages"
        if packages.exists():
            # This is the output directory created by this attempt. Refuse link traversal.
            if packages.is_symlink() or packages.resolve().parent != args.output.resolve():
                raise RuntimeError("Refusing to clean packages outside this attempt's output directory")
            shutil.rmtree(packages)
        manifest["packages"] = []
        manifest["application_package"] = False
        manifest["verification"] = "failed_see_reports"
    licenses = args.output / "licenses"
    licenses.mkdir(exist_ok=True)
    for source, name in ((ROOT / "LICENSE", "GPL-3.0.txt"),
                         (ROOT / "native/script/quickjs/LICENSE", "QuickJS-LICENSE.txt"),
                         (ROOT / "native/third_party/lua-5.4.8/doc/readme.html", "Lua-readme.html"),
                         (ROOT / "assets/runtime/TYPESCRIPT-LICENSE.txt", "TypeScript-LICENSE.txt"),
                         (ROOT / "assets/runtime/TYPESCRIPT-ThirdPartyNoticeText.txt", "TypeScript-ThirdPartyNotices.txt"),
                         (ROOT.parent / "qfli_studio_core/LICENSE", "Core-LICENSE.txt")):
        if source.is_file():
            shutil.copy2(source, licenses / name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("init", "setup-flutter", "setup-ohos", "build", "finalize"))
    parser.add_argument("--platform", default=os.environ.get("QFLI_PLATFORM"), choices=tuple(SIGNING))
    parser.add_argument("--arch", default=os.environ.get("QFLI_ARCH"))
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--flutter-root", type=Path,
                        default=Path(os.environ.get("QFLI_FLUTTER_ROOT", str(Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir())) / "qfli-flutter-oh"))))
    parser.add_argument("--job-status", default="success", choices=("success", "failure", "cancelled"))
    args = parser.parse_args()
    if not args.platform or not args.arch:
        parser.error("--platform and --arch (or QFLI_PLATFORM/QFLI_ARCH) are required")
    args.output = (args.output_dir or ROOT / f"build/app-artifacts/app-{args.platform}-{args.arch}").resolve()
    manifest_path = args.output / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else initialize(args)
    try:
        manifest["stage"] = args.command
        if args.command == "init":
            manifest = initialize(args)
        elif args.command == "setup-flutter":
            setup_flutter(args, manifest)
        elif args.command == "setup-ohos":
            setup_ohos(args, manifest)
        elif args.command == "build":
            build(args, manifest)
        else:
            finalize(args, manifest)
    except Exception as error:
        manifest["status"] = "failed"
        manifest["error"] = str(error)
        report = args.output / "reports" / f"{args.command}-failure.txt"
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(traceback.format_exc(), encoding="utf-8")
        raise
    finally:
        write_json(manifest_path, manifest)
        if args.command == "finalize":
            paths = sorted(p for p in args.output.rglob("*") if p.is_file() and p.name != "SHA256SUMS")
            (args.output / "SHA256SUMS").write_text("".join(f"{digest(p)}  {p.relative_to(args.output).as_posix()}\n" for p in paths), encoding="utf-8")


if __name__ == "__main__":
    main()
