# Research: Android release build and APK installation prerequisites

- Query: Build the Android product with debug disabled, then install it through ADB.
- Scope: internal, source-only configuration and installed-tool files
- Date: 2026-10-29

## Findings

### Current build configuration

- `android/settings.gradle.kts:22` selects Android Gradle Plugin 8.11.1; line23 selects Kotlin2.2.20.
- `android/gradle/wrapper/gradle-wrapper.properties:5` pins Gradle8.14.
- `android/app/build.gradle.kts:19` declares namespace/application family `com.azurekiln.qfli.script`; applicationId is at line40.
- `android/app/build.gradle.kts:20` takes compileSdk from the selected Flutter SDK. That local SDK's `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt:23,26,34` currently resolves compileSdk36, minSdk24, targetSdk36.
- `android/app/build.gradle.kts:21` requires NDK27.0.12077973. `android/local.properties:1` resolves SDK `D:/ProgramData/Android/Sdk`; its directories contain platform36, the required NDK, CMake3.22.1, and build-tools35.0.0/36.1.0/37.0.0.
- `pubspec.yaml:4` declares version1.0.0+1. The Android local properties currently match version1.0.0/code1. Do not copy OHOS code1000000 into Android without an explicit version decision.
- `android/app/build.gradle.kts:67` uses the existing Android debug keystore for the **release** variant. A debug signing certificate is separate from application debuggability. Preserve it for replacement compatibility; this is not production-signing qualification.
- `android/app/build.gradle.kts:8-16,56-60` maps explicit Flutter targets to matching NDK ABI filters unless split-per-ABI is enabled. Build only the connected target's supported ABI when known.

### Java and memory

- A local Android Studio JBR exists at `D:/ProgramFiles/Android/Android Studio/jbr`; its `release` file declares Java21.0.10. Prefer this Android-specific JBR for the invocation instead of reusing the preceding OHOS invocation's DevEco JBR25.
- Other installed release files declare Oracle JDK24 and JDK25. This research did not run Gradle or establish their compatibility.
- `android/gradle.properties:1-2` already limits Gradle to2GiB heap,1GiB metaspace and two workers.
- Two pre-existing local crash logs, `android/hs_err_pid18568.log:1-25` and `android/hs_err_pid22880.log:1-25`, explicitly report native memory allocation failures. Their headers identify Java21.0.10; the latter command line records a historical `android-x64` attempt. These are historical failures, not a current build result. Fresh committed-memory observation remains useful; do not concurrently build multiple ABIs or kill unrelated daemons.

### Native runtime packaging

- `android/app/build.gradle.kts:23-27` drives `native/CMakeLists.txt` through externalNativeBuild.
- `native/CMakeLists.txt:7-12` compiles vendored Lua5.4.8 and product bridge as `libqfli_lua.so`, excluding CLI entrypoints. Line36 includes the Script subdirectory.
- `native/script/CMakeLists.txt:19-24` builds `libqfli_script.so` from retained QuickJS sources and product glue. Lines7-18 hash-check the retained sources before configuring.
- `native/script/CMakeLists.txt:37-39` requests 16KiB max-page-size for Android/OHOS. Android Gradle also passes `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON` at `android/app/build.gradle.kts:50`.
- Dart FFI loaders in `lib/lua_toolchain.dart` and `lib/script_toolchain.dart` look for those exact shared-library names.

### Debug and permissions

- `../qfli_studio_core/lib/app.dart:116` already sets `debugShowCheckedModeBanner:false`.
- Build normal `lib/main.dart` with `--release --dart-define=QFLI_DIAG_TABBAR=false --dart-define=QFLI_PERF=false` for the requested debug-off behavior. The two diagnostic flags are compile-time core switches; no common-core edit is necessary.
- The main Android manifest declares the launcher `.MainActivity` and labelQFLIScript. It has no explicit INTERNET permission. The separate debug/profile manifests include INTERNET for Flutter tooling. Verify the **merged release manifest**, as dependencies can contribute permissions.

### Expected parent verification and installation

- The normal universal output is `build/app/outputs/flutter-apk/app-release.apk`; ABI splitting changes the filename.
- Inspect actual APK packageId, version, `debuggable=false`, SDK minimum/target, launcher and native ABI. Require matching `libapp.so`, `libflutter.so`, `libqfli_lua.so`, `libqfli_script.so` and current bundled content/runtime assets. Release AOT should not contain `kernel_blob.bin`.
- Local SDK build-tools36.1.0 contains aapt/aapt2 and apksigner for manifest/badging and signature checks; this researcher did not execute them.
- Root owns actual ADB enumeration, target selection, push/install and package verification. Use the actual current serial, Android API and ABI. Preserve app data with replacement install. If the installed certificate differs, report the incompatibility rather than uninstalling or clearing data without authorization.

## Files Found

- `android/app/build.gradle.kts`: Android identity, ABI selection, native integration and signing.
- `android/settings.gradle.kts`: AGP and Kotlin plugin versions.
- `android/gradle/wrapper/gradle-wrapper.properties`: Gradle distribution pin.
- `android/gradle.properties`: Gradle memory and worker limits.
- `android/app/src/main/AndroidManifest.xml`: ordinary product launcher/application.
- `android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml`: tooling-only INTERNET permission.
- `native/CMakeLists.txt`, `native/script/CMakeLists.txt`: Lua/QuickJS bridge libraries.
- `android/hs_err_pid18568.log`, `android/hs_err_pid22880.log`: historical JVM native-memory failures.

## External References

No network lookup was performed. Tool versions above come from local configuration or installed release files. They do not constitute a new SDK/Gradle run or compatibility test.

## Related Specs

- `.trellis/spec/backend/lua-toolchain.md`: native ownership, Android packaging and current-source verification.
- `.trellis/spec/backend/script-toolchain.md`: Script runtime/assets and platform packaging.
- `.trellis/tasks/10-22-offline-ide-completeness/prd.md`: whole offline IDE scope and preserved peer work.

## Caveats / Not Found

No SDK/runtime/build/ADB/network or Git command was executed. No source, platform configuration, common-core or sibling file was changed. Device presence/authorization/API/ABI, existing installed signature, Gradle cache resolution, fresh host memory, actual build and installation outcomes remain for root to observe. Existing Android release signing uses the debug keystore and must be disclosed when describing the artifact.

## Actual root build and installation — October 29, 2026

This section supersedes the pending observations in the source-only research
above. Root executed the user-authorized build and device installation.

- Command: `flutter build apk --release --no-pub --target lib/main.dart --target-platform android-arm64 --dart-define=QFLI_DIAG_TABBAR=false --dart-define=QFLI_PERF=false`.
- Java21 invocation overrides limited Gradle heap to1024MiB, metaspace512MiB,
  one worker and no daemon. Kotlin compilation used the in-process strategy.
  Project configuration bytes were preserved.
- Gradle assembleRelease succeeded in155.7s. APK size30323678bytes; SHA256
  `0f6cdabe5ff05ca47a5f45e6bb304b565c40051d9c24f1606c0bd19bb3f783de`.
- Original execb25467/session34172 actually terminated0 in poll811d74.
  Exact child root10340/FILETIME134376770138090469 was terminal0 with Jobactive0,
  handles closed and no timeout/errors. Five source/config hashes were unchanged.
- AAPT confirmed package `com.azurekiln.qfli.script`, version1.0.0/code1,
  minSdk24/targetSdk36 and ARM64-only native code. No application-debuggable
  marker was present. The merged release manifest has no INTERNET permission.
- Apksigner cryptographic verification passed APK Signature Schemev2.
  The existing Android Debug certificate signs this release artifact; the
  application remains non-debuggable. No signing identity was replaced.
- Two ADB transports were verified as the same physical Android16 ARM64 device
  before choosing one explicit transport. Identifiers stay in local evidence.
- ADB push succeeded. The remote temporary APK SHA256 exactly matched the local
  artifact. `pm install -r` returned `Success`; no uninstall/data clear occurred.
- Root resolved the installed `base.apk` with `pm path`; its device SHA256 also
  exactly matched the local artifact in verification tool6b9f06.
- Explicit launcher activation returned Statusok. The application process was
  present. Installed metadata confirmed version1.0.0/code1, installed=true and
  flags without DEBUGGABLE. This is an installation/launch smoke check, not a
  full runtime/content acceptance claim.
- The exact owned temporary install APK was removed after success. The delivered
  local artifact remains `build/app/outputs/flutter-apk/app-release.apk`.
- Local request/job/prebuild/postbuild evidence stays under
  `build/lua-android-release-20261028T160333Z`. No OHOS/device/core or production
  source changes were required. The larger offline IDE task remains in_progress.
