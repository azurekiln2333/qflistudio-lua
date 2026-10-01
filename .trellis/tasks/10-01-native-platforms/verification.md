# Native Platform Verification

Recorded on 2026-10-02 on a Windows host. The task covers the existing native
runners; there is no web runner. Device connection, installation, and debugging
were not performed.

## Platform Results

| Platform | Implementation evidence | Local verification |
| --- | --- | --- |
| Windows | Flutter CMake bundles `libqfli_lua.dll` beside the executable; UTF-8 file adapter is compiled only on Windows. | Native CTest, Dart/Flutter integration, and standalone AOT command passed. Full Flutter desktop application build was not run: Visual Studio is unavailable. |
| Android | Gradle builds the shared C bridge for matching Flutter ABIs; NDK 27 flexible page sizes enabled. | Final fresh Release APK passed matching ABI, all nine export, 64-bit ELF alignment, and APK ZIP alignment inspection. No device runtime test. |
| Linux | CMake builds the bridge, installs `lib/libqfli_lua.so`, and agrees with the FFI loader and `$ORIGIN/lib` RPATH. | Source review passed. Build/runtime tests not attempted: WSL access denied; escalated inventory encountered approval service HTTP 503. |
| iOS | Runner compiles the bridge and 32 Lua library files; process-symbol loader, C11, iOS defines, retention/stripping config, and subprocess adaptation are wired. | OpenStep/file/configuration checks passed. No build/runtime test: macOS/Xcode unavailable. |
| macOS | Runner compiles the same 33 C files; process-symbol loader with standalone dylib fallback and correct macOS defines/retention. | OpenStep/file/configuration checks passed. No build/runtime test: macOS/Xcode unavailable. |
| HarmonyOS | Existing shared C integration preserved. | Previously verified integration was not device-debugged in this task. |

## Windows and Shared Runtime

- `ctest --test-dir native/build/windows --output-on-failure`: 1/1 passed.
  `native/build/windows/Testing/Temporary/LastTest.log` records the pass on
  Oct 01 at 23:47.
- Full Flutter test suite: 44 passed.
- Full Flutter analysis: no issues found.
- The native and FFI tests cover source and bytecode execution, syntax errors,
  project modules/relative paths, stdout/stderr, binary/malformed output,
  finalizer output, Lua conversions, exit behavior, timeout, cancellation,
  and Windows non-ASCII filenames.
- The standalone AOT program is
  `build/native-smoke/windows/qfli_lua_cli.exe`, with
  `build/native-smoke/windows/libqfli_lua.dll` beside it. Version, check,
  compile, and compiled-bytecode run succeeded through executable-relative
  loading. Version reported Lua 5.4.8; execution printed `sum` and `55`
  separated by a tab. The compiled chunk is
  `build/native-smoke/windows/hello.luac`.

This establishes shared engine behavior and Windows native loading. It does
not establish a full Windows Flutter app build or another platform's runtime.

## Android Package Verification

The first fresh Release APK had matching `armeabi-v7a`, `arm64-v8a`, and
`x86_64` Lua, Flutter, and AOT application libraries, with all nine bridge
exports. Inspection identified 64-bit Lua ELF LOAD alignment of `0x1000`,
requiring a flexible-page-size rebuild.

`android/app/build.gradle.kts` now passes
`-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON` to NDK 27 CMake. The fresh
replacement Release build completed, and final inspection passed:

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Size: 69,981,813 bytes; local modification time `2026-10-02 00:01:18`.
- SHA-256:
  `4BA28415DE1721CF8F521BD9F6FD60EDE947941613DFB9337A470520495BEC56`.
- Exactly three ABI sets: `armeabi-v7a`, `arm64-v8a`, and `x86_64`, each with
  matching ELF `libapp.so`, `libflutter.so`, and `libqfli_lua.so`. All nine
  APK native entries are uncompressed.
- All nine bridge exports are defined global functions in every Lua ABI.
- ARM64/x86_64 Lua LOAD segments align to `0x4000` (16 KiB); matching
  Flutter/app libraries align to `0x10000` (64 KiB). The 32-bit Lua library
  retains `0x1000`, as the NDK flexible-page-size option targets 64-bit ABIs.
- Android Build Tools 36.1.0 `zipalign -c -P 16 4` passed.

The same release APK was installed on emulator-5560 (Android API 37, x86_64,
16 KiB pages) during the cross-product audit on 2026-10-02. Its ordinary
`lib/main.dart` entry opened a new isolated `LuaNativeAudit` project. The editor
ran `src/main.lua` and printed `Hello, QFLIStudio+!` with exit code 0. The native
file tools reported correct syntax and generated `src/main.luac`. Replacing
the source with `dofile[[src/main.luac]]` and running again reproduced the
compiled program's output with exit code 0, proving bytecode reload through
the actual application runner. No debug probe target was installed.

ARM device execution remains unverified. See
[Android research](research/android-native.md) for the build command, package
inspection and application steps. Screenshots and cross-product evidence are
recorded by qfli_web's active native-runtime-platform-audit task.

## Apple Source Verification

Both full OpenStep project files parsed successfully. Their Runner source
phases match the vendored library source set plus the shared bridge: 33 unique
C files with existing paths, excluding CLI, test, and Windows-only files.
Debug, Profile, and Release each resolve their native config and inherit C11,
correct Apple defines, shared headers, and non-global stripping without a
target-level override. Only iOS `liolib.c` receives its platform compatibility
header. The shared bridge exports have Apple `used` and default visibility.

These checks verify source wiring. Packaged Mach-O symbols and
`DynamicLibrary.process()` resolution still require a macOS/Xcode environment.
See [Apple research](research/apple-native.md).

## Linux Verification Boundary

The existing Linux build, install location, RPATH, and Dart loading paths
agree. The local inventory found no accessible Linux test environment; WSL
registrations or running Windows services do not prove one is usable. No
Linux CTest, Flutter build, or Linux runtime test was attempted. See
[Linux research](research/linux-native.md).
