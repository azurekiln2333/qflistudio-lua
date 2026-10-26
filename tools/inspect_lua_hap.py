"""Inspect an actual Script HAP; never substitute source settings for payload proof."""
import argparse
import hashlib
import json
import pathlib
import re
import struct
import urllib.parse
import urllib.request
import zipfile


# Keep the package gate aligned with the symbols actually looked up by
# LuaToolchain, LuaDebugger and ScriptToolchain. A version symbol alone does not
# prove that syntax checks, cancellation, result release or debugging can start.
REQUIRED_EXPORTS = {
    "libqfli_lua.so": (
        "qfli_lua_version", "qfli_lua_run_with_token", "qfli_lua_run_with_argv",
        "qfli_lua_token_new", "qfli_lua_token_cancel", "qfli_lua_token_free",
        "qfli_lua_check", "qfli_lua_check_source", "qfli_lua_compile",
        "qfli_lua_compile_ex", "qfli_lua_free", "qfli_lua_debug_new",
        "qfli_lua_debug_resume", "qfli_lua_debug_pause", "qfli_lua_debug_stop",
        "qfli_lua_debug_free", "qfli_lua_debug_state",
        "qfli_lua_debug_set_breakpoints", "qfli_lua_debug_frame",
        "qfli_lua_debug_local", "qfli_lua_debug_output",
    ),
    "libqfli_script.so": (
        "qfli_script_token_new", "qfli_script_token_cancel",
        "qfli_script_token_free", "qfli_script_process", "qfli_script_free",
        "qfli_script_version",
    ),
}

CORE_ASSETS = (
    "assets/content/tutorials.json",
    "assets/content/examples.json",
    "assets/tutorials/lua.json",
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def core_source_binding(root, issues):
    """Bind shared payload expectations to this app's actual local dependency."""
    config_file = root / ".dart_tool/package_config.json"
    pubspec = root / "pubspec.yaml"
    expected = root.parent / "qfli_studio_core"
    binding = {"package": "qfli_studio_core", "packageConfig": str(config_file),
               "pubspec": str(pubspec), "expectedDependencyPath": "../qfli_studio_core",
               "expectedRoot": str(expected), "rootUri": None,
               "resolvedRoot": None, "matched": False}
    try:
        expected = expected.resolve(strict=True)
        binding["expectedRoot"] = str(expected)
        # Deliberately accept the project's existing block dependency form only.
        # Unsupported/changed declarations fail the proof instead of silently
        # assuming that a neighboring checkout is still the built dependency.
        declaration = re.search(
            r"(?ms)^dependencies:[ \t]*\r?\n(?P<body>.*?)(?=^[^\s#]|\Z)",
            pubspec.read_text(encoding="utf-8"))
        dependencies = declaration.group("body") if declaration else ""
        core_blocks = list(re.finditer(
            r"(?m)^  qfli_studio_core:[ \t]*\r?\n"
            r"(?P<body>(?:^    [^\r\n]*(?:\r?\n|\Z)|^[ \t]*\r?\n)*)",
            dependencies))
        if (len(core_blocks) != 1 or
                len(re.findall(r"(?m)^    path:", core_blocks[0].group("body"))) != 1 or
                not re.search(
                r"(?m)^    path:[ \t]*(?:\.\./qfli_studio_core|"
                r"'\.\./qfli_studio_core'|\"\.\./qfli_studio_core\")"
                r"[ \t]*(?:#[^\r\n]*)?\r?$", core_blocks[0].group("body"))):
            raise ValueError("pubspec must declare qfli_studio_core path ../qfli_studio_core")
        config = json.loads(config_file.read_text(encoding="utf-8"))
        if not isinstance(config, dict) or config.get("configVersion") != 2:
            raise ValueError("package_config must use configVersion 2")
        packages = config.get("packages")
        if not isinstance(packages, list):
            raise ValueError("package_config packages is not a list")
        matches = [package for package in packages if isinstance(package, dict)
                   and package.get("name") == "qfli_studio_core"]
        if len(matches) != 1:
            raise ValueError("package_config must contain exactly one qfli_studio_core")
        root_uri = matches[0].get("rootUri")
        binding["rootUri"] = root_uri
        if not isinstance(root_uri, str) or not root_uri:
            raise ValueError("qfli_studio_core rootUri is missing or invalid")
        resolved_uri = urllib.parse.urlsplit(urllib.parse.urljoin(
            config_file.resolve().as_uri(), root_uri))
        if (resolved_uri.scheme != "file" or
                resolved_uri.netloc not in ("", "localhost") or
                resolved_uri.query or resolved_uri.fragment):
            raise ValueError("qfli_studio_core rootUri must resolve to a local file directory")
        resolved = pathlib.Path(urllib.request.url2pathname(resolved_uri.path)).resolve(strict=True)
        binding["resolvedRoot"] = str(resolved)
        if resolved != expected or not resolved.is_dir():
            raise ValueError("package_config qfli_studio_core root differs from the declared sibling dependency")
        binding["matched"] = True
        return resolved, binding
    except (OSError, ValueError, RuntimeError) as error:
        binding["unavailableReason"] = str(error)
        issues.append(f"Cannot bind qfli_studio_core source: {error}")
        return None, binding


def inspect_asset(archive, names, key, source, result):
    matches = [name for name in names if name.endswith("/flutter_assets/" + key)]
    receipt = {"key": key, "path": matches[0] if len(matches) == 1 else None,
               "archiveMatchCount": len(matches), "sourcePath": str(source) if source else None,
               "expectedBytes": None, "expectedSha256": None,
               "bytes": None, "sha256": None, "sourceMatches": False}
    result["assets"].append(receipt)
    if source is None:
        receipt["unavailableReason"] = "Shared source root binding is unavailable"
    else:
        try:
            source_bytes = source.read_bytes()
            receipt["expectedBytes"] = len(source_bytes)
            receipt["expectedSha256"] = digest(source_bytes)
        except OSError as error:
            receipt["unavailableReason"] = str(error)
            result["issues"].append(f"Cannot read source asset {key}: {error}")
    if len(matches) != 1:
        result["issues"].append(f"Expected one bundled asset: {key}")
        return
    data = archive.read(matches[0])
    receipt["bytes"] = len(data)
    receipt["sha256"] = digest(data)
    receipt["sourceMatches"] = receipt["expectedSha256"] == receipt["sha256"]
    if receipt["expectedSha256"] is not None and not receipt["sourceMatches"]:
        result["issues"].append(f"Stale bundled asset: {key}")


def elf_info(data):
    if data[:6] != b"\x7fELF\x02\x01":
        raise ValueError("Expected little-endian ELF64")
    kind, machine = struct.unpack_from("<HH", data, 16)
    entry, phoff, shoff = struct.unpack_from("<QQQ", data, 24)
    phsize, phnum, shsize, shnum = struct.unpack_from("<HHHH", data, 54)
    alignments = []
    for i in range(phnum):
        offset = phoff + i * phsize
        if struct.unpack_from("<I", data, offset)[0] == 1:
            alignments.append(struct.unpack_from("<Q", data, offset + 48)[0])
    sections = [struct.unpack_from("<IIQQQQIIQQ", data, shoff + i * shsize)
                for i in range(shnum)]
    symbols = set()
    for section in sections:
        if section[1] != 11:
            continue
        strings = sections[section[6]]
        names = data[strings[4]:strings[4] + strings[5]]
        for offset in range(section[4], section[4] + section[5], section[9]):
            name, info, visibility, index = struct.unpack_from("<IBBH", data, offset)
            if index and info >> 4 in (1, 2) and (visibility & 3) in (0, 3):
                symbols.add(names[name:names.find(b"\0", name)].decode("utf-8"))
    return {"machine": machine, "type": kind, "entry": entry,
            "loadAlignments": alignments, "symbols": sorted(symbols)}


def inspect(hap, root, abis):
    result = {"hap": str(hap.resolve()), "sha256": digest(hap.read_bytes()),
              "bytes": hap.stat().st_size, "abis": abis, "libraries": [],
              "assets": [], "issues": []}
    issues = result["issues"]
    core_root, result["coreSourceBinding"] = core_source_binding(root, issues)
    machines = {"arm64-v8a": 183, "x86_64": 62}
    with zipfile.ZipFile(hap) as archive:
        names = archive.namelist()
        libraries = [name for name in names if name.startswith("libs/") and name.endswith(".so")]
        for abi in abis:
            for library in ("libflutter.so", "libqfli_lua.so", "libqfli_script.so"):
                if f"libs/{abi}/{library}" not in libraries:
                    issues.append(f"Missing {abi}/{library}")
        for name in libraries:
            data = archive.read(name)
            abi = name.split("/")[1]
            try:
                elf = elf_info(data)
                if abi not in abis or elf["machine"] != machines.get(abi):
                    issues.append(f"Wrong ABI: {name}")
                if elf["type"] != 3 or elf["entry"] != 0:
                    issues.append(f"Not a shared library: {name}")
                # Current OHOS SDK x64 Flutter/C++ binaries use 4 KiB pages.
                # Record 16 KiB compatibility separately; do not reject a valid
                # x64 emulator package using an unrelated Android ARM64 gate.
                elf["supports16KiBLoadAlignment"] = bool(elf["loadAlignments"]) and min(elf["loadAlignments"]) >= 16384
                if not elf["loadAlignments"] or min(elf["loadAlignments"]) < 4096:
                    issues.append(f"Insufficient LOAD alignment: {name}")
                required = REQUIRED_EXPORTS.get(name.rsplit("/", 1)[-1], ())
                for symbol in required:
                    if symbol not in elf["symbols"]:
                        issues.append(f"Missing symbol {symbol}: {name}")
                result["libraries"].append({"path": name, "bytes": len(data),
                                            "sha256": digest(data), **elf})
            except (ValueError, struct.error, IndexError) as error:
                issues.append(f"Invalid ELF {name}: {error}")
        local_assets = [*sorted((root / "assets/content").glob("*.json")),
                        *sorted((root / "assets/runtime").glob("*"))]
        assets = [(asset.relative_to(root).as_posix(), asset)
                  for asset in local_assets if asset.is_file()]
        assets.extend(("packages/qfli_studio_core/" + relative,
                       core_root / relative if core_root is not None else None)
                      for relative in CORE_ASSETS)
        for key, source in assets:
            inspect_asset(archive, names, key, source, result)
        modules = [name for name in names if name == "module.json"]
        if len(modules) != 1:
            issues.append("Missing module.json")
        else:
            module = json.loads(archive.read(modules[0]))
            result["bundleName"] = module.get("app", {}).get("bundleName")
            permissions = module.get("module", {}).get("requestPermissions", [])
            result["permissions"] = [item["name"] for item in permissions]
            if "ohos.permission.INTERNET" in result["permissions"]:
                issues.append("Offline package requests INTERNET")
    result["packageGatePassed"] = not issues
    result["deviceGatePassed"] = False
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("hap", type=pathlib.Path)
    parser.add_argument("--abis", default="x86_64")
    parser.add_argument("--report", required=True, type=pathlib.Path)
    args = parser.parse_args()
    report = inspect(args.hap, pathlib.Path(__file__).resolve().parents[1], args.abis.split(","))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("hap", "sha256", "abis", "issues", "packageGatePassed")}))
    raise SystemExit(0 if report["packageGatePassed"] else 1)
