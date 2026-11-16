"""Build and stage the native CI artifact without Flutter or application signing."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import traceback


ROOT = Path(__file__).resolve().parents[1]
MACHINES = {"x86_64": 62, "arm64": 183, "arm64-v8a": 183, "armeabi-v7a": 40}


def run(command, log, *, cwd=ROOT):
    """Preserve output and the real exit code, including failed commands."""
    print("+ " + " ".join(map(str, command)), flush=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        stream.write("Command: " + repr(list(map(str, command))) + "\n\n")
        stream.flush()
        result = subprocess.run(
            list(map(str, command)), cwd=cwd, stdout=stream,
            stderr=subprocess.STDOUT, timeout=1200, check=False,
        )
    output = log.read_text(encoding="utf-8", errors="replace")
    if len(output) > 12000:
        print(f"Full output: {log} ({len(output)} characters); last 12000 characters:", flush=True)
    print(output[-12000:], flush=True)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {command[0]}; see {log}")
    return output


def checksums(directory):
    lines = []
    for path in sorted(directory.rglob("*")):
        if path.is_file() and path.name != "SHA256SUMS":
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            lines.append(f"{digest}  {path.relative_to(directory).as_posix()}\n")
    (directory / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")


def inspect_library(library, args, reports, symbol):
    if args.platform in ("android", "ohos", "linux"):
        header = library.read_bytes()[:64]
        if header[:4] != b"\x7fELF" or header[5] != 1:
            raise RuntimeError(f"Not a little-endian ELF library: {library}")
        machine = struct.unpack_from("<H", header, 18)[0]
        if machine != MACHINES[args.arch]:
            raise RuntimeError(f"Wrong ELF machine {machine} for {args.arch}")
        details = run([args.readelf, "-h", "-lW", "-d", library], reports / (library.name + ".elf.txt"))
        if args.platform == "android" and args.arch != "armeabi-v7a":
            loads = [line.split() for line in details.splitlines() if line.strip().startswith("LOAD ")]
            if not loads or any(int(line[-1], 16) < 16384 for line in loads):
                raise RuntimeError("Android 64-bit ELF LOAD alignment is below 16 KiB")
        exports = run([args.nm, "-D", "--defined-only", library], reports / (library.name + ".symbols.txt"))
    elif args.platform == "windows":
        with library.open("rb") as stream:
            if stream.read(2) != b"MZ":
                raise RuntimeError(f"Not a Windows PE library: {library}")
            stream.seek(60)
            pe_offset = struct.unpack("<I", stream.read(4))[0]
            stream.seek(pe_offset)
            if stream.read(4) != b"PE\0\0" or struct.unpack("<H", stream.read(2))[0] != 0x8664:
                raise RuntimeError(f"Not a Windows x86_64 library: {library}")
        exports = run(["objdump", "-p", library], reports / (library.name + ".pe.txt"))
        # -static-libgcc keeps the artifact independent of the compiler install.
        dependencies = [line.split(":", 1)[1].strip().lower() for line in exports.splitlines() if "DLL Name:" in line]
        if any(name.startswith(("libgcc", "libwinpthread", "libstdc++")) for name in dependencies):
            raise RuntimeError(f"Compiler runtime DLL is missing from artifact: {dependencies}")
    else:
        architectures = run(["lipo", "-archs", library], reports / (library.name + ".architectures.txt"))
        expected = ("arm64", "x86_64") if args.arch == "simulator-universal" else (args.arch.removeprefix("device-"),)
        actual = architectures.splitlines()[-1].split()
        if set(actual) != set(expected):
            raise RuntimeError(f"Expected architectures {expected}, got {actual}")
        exports = run(["nm", "-gU", library], reports / (library.name + ".symbols.txt"))
    if symbol not in exports:
        raise RuntimeError(f"Missing public bridge symbol {symbol}: {library}")


def build(args):
    build_dir = Path(args.build_dir).resolve()
    output = Path(args.output_dir).resolve()
    reports = output / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    manifest = {
        "platform": args.platform, "architecture": args.arch,
        "source_commit": os.environ.get("GITHUB_SHA") or subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "status": "failed", "verification": "not_completed",
        "runtime_tests": "not_run", "device_tests": "not_run",
        "application_package": False,
    }
    try:
        run(["cmake", "--version"], reports / "cmake-version.txt")
        extra = args.cmake_args[1:] if args.cmake_args[:1] == ["--"] else args.cmake_args
        run(["cmake", "-S", ROOT / "native", "-B", build_dir, "-G", "Ninja",
             "-DCMAKE_BUILD_TYPE=Release", "-DQFLI_REQUIRE_SCRIPT=ON", *extra], reports / "configure.log")
        targets = ["qfli_lua_engine", "qfli_script_engine"]
        host = args.platform in ("windows", "linux", "macos")
        if host:
            targets.append("qfli_lua_test")
        run(["cmake", "--build", build_dir, "--parallel", "2", "--target", *targets], reports / "build.log")
        suffix = {"windows": ".dll", "macos": ".dylib", "ios": ".a"}.get(args.platform, ".so")
        libraries = [(build_dir / ("libqfli_lua" + suffix), "qfli_lua_version"),
                     (build_dir / "script" / ("libqfli_script" + suffix), "qfli_script_process")]
        for library, symbol in libraries:
            if not library.is_file():
                raise FileNotFoundError(library)
            inspect_library(library, args, reports, symbol)
        manifest["verification"] = "compiled_and_inspected"
        if host:
            manifest["runtime_tests"] = "failed"
            run(["ctest", "--test-dir", build_dir, "--output-on-failure", "--timeout", "120",
                 "--output-junit", reports / "lua-ctest.xml"], reports / "lua-ctest.log")
            run([sys.executable, ROOT / "native/script/test_native.py", libraries[1][0]], reports / "script-probes.log")
            manifest["runtime_tests"] = "passed"
            manifest["verification"] = "compiled_inspected_and_host_tested"
        else:
            manifest["runtime_tests"] = "not_run_cross_compiled"
        for subdir in ("lib", "include", "licenses"):
            (output / subdir).mkdir(exist_ok=True)
        for library, _ in libraries:
            shutil.copy2(library, output / "lib" / library.name)
        for header in (ROOT / "native/src/qfli_lua.h", ROOT / "native/script/qfli_script.h"):
            shutil.copy2(header, output / "include" / header.name)
        shutil.copy2(ROOT / "native/script/quickjs/LICENSE", output / "licenses/QuickJS-LICENSE.txt")
        shutil.copy2(ROOT / "native/third_party/lua-5.4.8/doc/readme.html", output / "licenses/Lua-readme.html")
        manifest["status"] = "passed"
    except Exception as error:
        manifest["error"] = str(error)
        (reports / "failure.txt").write_text(traceback.format_exc(), encoding="utf-8")
        raise
    finally:
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        checksums(output)


def package_ios(args):
    output = Path(args.output_dir).resolve()
    reports = output / "reports"
    for runtime in ("lua", "script"):
        run(["xcodebuild", "-create-xcframework",
             "-library", output / "device-arm64/lib" / f"libqfli_{runtime}.a",
             "-headers", output / "device-arm64/include",
             "-library", output / "simulator-universal/lib" / f"libqfli_{runtime}.a",
             "-headers", output / "simulator-universal/include",
             "-output", output / f"qfli_{runtime}.xcframework"], reports / f"{runtime}-xcframework.log")
    checksums(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    compile_parser = sub.add_parser("build")
    compile_parser.add_argument("--platform", choices=("windows", "linux", "macos", "android", "ohos", "ios"), required=True)
    compile_parser.add_argument("--arch", required=True)
    compile_parser.add_argument("--build-dir", required=True)
    compile_parser.add_argument("--output-dir", required=True)
    compile_parser.add_argument("--readelf", default="readelf")
    compile_parser.add_argument("--nm", default="nm")
    compile_parser.add_argument("cmake_args", nargs=argparse.REMAINDER)
    ios_parser = sub.add_parser("package-ios")
    ios_parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    if args.command == "package-ios":
        package_ios(args)
    else:
        build(args)


if __name__ == "__main__":
    main()
