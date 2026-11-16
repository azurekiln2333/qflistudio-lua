# Design

Use a native-only GitHub Actions workflow. Desktop jobs compile CMake shared libraries with modern GCC/Clang and execute both existing test suites. Windows uses MinGW because Script is unavailable with MSVC. macOS covers Intel and ARM64 runners where available.

Android cross-compiles with the repository-pinned NDK 27.0.12077973 for arm64-v8a, armeabi-v7a and x86_64. OHOS uses a fixed public OpenHarmony native SDK with verified archive and builds arm64-v8a and x86_64. OpenHarmony compilation is separate from Huawei HarmonyOS app packaging and device acceptance.

iOS CMake gains the minimum platform configuration for static archives. Reuse the existing Lua iOS subprocess adaptation. Compile device ARM64 and simulator ARM64/x86_64. Package XCFrameworks when practical and preserve architecture/symbol reports. Existing Apple Runner packaging stays unchanged.

Each job stages both runtimes, public headers, third-party licenses, source revision, checksums and compiler/test reports. Cross jobs report compilation/inspection only. Retention is explicit. Failed jobs retain diagnostics without presenting them as usable binaries.

Run on relevant pushes, pull requests and manual dispatch. Permissions are read-only. Avoid SDK/build caches in the initial experiment. Push a dedicated CI branch; its push triggers the first run. Never stage signing configuration or unrelated files.

Rollback removes the workflow and small iOS CMake additions. No application ABI or runtime source behavior changes are planned.
