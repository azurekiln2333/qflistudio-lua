# Native cloud build contract

## 1. Scope / Trigger
Read when changing `.github/workflows/native.yml`, `tools/ci_native_build.py`, native CMake, artifact contents or cloud toolchains.

## 2. Signatures
- `python tools/ci_native_build.py build --platform <platform> --arch <arch> --build-dir <path> --output-dir <path> [--readelf <tool>] [--nm <tool>] -- <cmake-options>`
- `python tools/ci_native_build.py package-ios --output-dir <path>`
- CMake `QFLI_REQUIRE_SCRIPT=ON` rejects a compiler configuration that would silently skip Script. Existing app builds retain the default OFF behavior.
- `CMAKE_SYSTEM_NAME=iOS` produces two static archives and suppresses host test executables. Other current native targets remain shared libraries.

## 3. Contracts
- Native CI does not require Flutter or the sibling core repository. It does not package an application.
- Desktop jobs build both runtimes, inspect native formats and run Lua CTest and the real Script probes before staging libraries.
- Android/OHOS/iOS jobs cross-compile and inspect architecture and bridge symbols. They must retain `device_tests=not_run`.
- Artifacts contain libraries, headers, the root GPL text, upstream licenses, reports, a source-bound `manifest.json` and `SHA256SUMS`. Never upload SDK caches or signing files.
- LICENSE may use checkout-specific CRLF on Windows. Hash the actual packaged bytes and compare normalized text to establish equivalence with the Git blob.
- Windows uses modern GNU tools, static compiler support libraries and explicit static winpthread for QuickJS. Reject undeclared compiler runtime DLL imports.
- iOS reuses `LUA_USE_IOS` and force-includes `ios/Runner/QfliLuaIos.h` only for liolib.c. Keep vendored Lua unchanged and preserve Apple process-symbol contracts.
- Android uses NDK 27.0.12077973 and verifies 64-bit ELF LOAD alignment of at least 16 KiB. This does not verify APK ZIP alignment.
- All Android ABIs target API24, matching the app's FlutterExtension and merged manifests. Lua enables 64-bit file offsets; on ARM32, the NDK only declares the corresponding fseeko/ftello functions at API24. Do not disable large-file support or patch vendored sources to accommodate an incorrect CI API21 target.
- Download the fixed Google NDK r27 archive directly. Verify Google's published SHA1 and record its SHA256 plus source.properties. Do not assume sdkmanager is on the hosted runner PATH.
- macOS hosts target macOS 11.0 even when the ARM runner uses macOS 26. iOS archives target iOS 13.0.
- OHOS pins the public OpenHarmony 5.1.0.107 API18 SDK archive and its SHA256. This is not Huawei HarmonyOS HAP/device acceptance.
- Workflow permissions are contents:read. Uploads retain artifacts for 14 days. Failed builds retain diagnostics and failure metadata.

## 4. Validation & Error Matrix
| Case | Required behavior |
| --- | --- |
| Unsupported Script compiler with require option | Configure fails |
| Missing runtime or bridge export | Build helper fails |
| Wrong architecture or Android alignment | Inspection fails |
| Desktop regression fails | Failed manifest; no staged runtime libraries |
| Cross-compilation succeeds | Explicit cross-compiled status; no runtime test claim |
| SDK checksum differs | Stop before extraction/build |

## 5. Good / Base / Bad Cases
- Base: Windows contains two DLLs and passing Lua/Script reports.
- Good: each platform artifact identifies its exact commit, architecture and verification level.
- Bad: upload a successful-looking archive from an old build tree after current tests fail.

## 6. Tests Required
Run actionlint, Python syntax checks, and a real host build/test/staging path when available. Verify generated hashes and failure manifests. For matrix or toolchain changes, observe an actual Actions run. Configuration review alone cannot establish a platform pass.

## 7. Wrong vs Correct
Wrong: claim native cloud builds remove local Flutter caches or produce installable apps.
Correct: report native artifact evidence separately from local disk measurements and full application packaging.
