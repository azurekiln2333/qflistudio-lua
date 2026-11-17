# Pinned Flutter-OH SDK audit

Audited on 2026-11-17 using primary repository source, Git remote refs, HTTP HEAD and bounded ZIP range reads. No full Flutter artifact cache or application build was downloaded/run.

## Fixed identities

| Component | Identity |
| --- | --- |
| Framework repository | `https://gitcode.com/CPF-Flutter/flutter_flutter.git` |
| Framework tag | `3.41.9+ohos-1.0.2` |
| Framework commit | `62357a93d653bf844f730bb1f4b7cc9e2139d14e` |
| Upstream engine (`bin/internal/engine.version`) | `42d3d75a56efe1a2e9902f52dc8006099c45d937` |
| OHOS engine (`bin/internal/engine.ohos.version`) | `4cbeea6a36f7aea39a60f2c5d57b1ffd84bfd106` |
| OHOS HAR (`bin/internal/engine.ohos.har.version`) | `4cbeea6a36f7aea39a60f2c5d57b1ffd84bfd106` |
| Dart version, four host archives | `3.11.5` |
| Dart revision, four host archives | `ee3baaa7621306ad8eaa2c4961abec5cbf8672a6` |
| Native Dart tooling fork | `https://gitcode.com/openharmony-sig/fluttertpc_dart_native` |
| Tooling fork branch / current commit | `flutter_3.41.9_deps` / `9d2eaf45940e5042637b3387b18292ed39223a4a` |

The local modified SDK has different OHOS revisions. Do not copy its cache or use its Git HEAD as the build identity.

## Download split

Keep the two artifact origins distinct:

```text
FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
FLUTTER_OHOS_STORAGE_BASE_URL=https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com
PUB_HOSTED_URL=https://pub.dev
```

`bin/internal/update_dart_sdk.{sh,ps1}` downloads Dart from the OHOS origin using the OHOS engine revision, on every host. `FlutterSdkOhos` also downloads the host compiler/tester archive from that origin. `FlutterWebSdk` uses the OHOS engine/origin. Both Linux x64 and Windows x64 are provided, as are macOS x64 and ARM64.

Other engine packages continue to use the upstream engine/origin: common Flutter patched SDK, sky_engine/flutter_gpu, Android engine and gen_snapshot, Windows/Linux desktop engines, macOS frameworks/gen_snapshot and iOS artifacts. Setting the ordinary `FLUTTER_STORAGE_BASE_URL` to the OHOS bucket would redirect these and is not required by this pinned version.

Source references at the fixed framework commit:

- `bin/internal/update_engine_version.{sh,ps1}`
- `bin/internal/update_dart_sdk.{sh,ps1}`
- `packages/flutter_tools/lib/src/cache.dart`, `storageBaseUrl` / `ohosStorageBaseUrl`
- `packages/flutter_tools/lib/src/flutter_cache.dart`, `FlutterSdk`, `FlutterSdkOhos`, `FlutterWebSdk`, platform artifact classes
- `packages/flutter_tools/lib/src/commands/precache.dart`
- `packages/flutter_tools/lib/src/commands/build.dart`
- `packages/flutter/lib/src/foundation/{platform.dart,_platform_io.dart}`

The framework contains `TargetPlatform.ohos`. Host detection checks `Platform.operatingSystem == 'ohos'`, rather than requiring a new Dart `Platform.isOhos` getter. Standard Windows, Linux, macOS, iOS, Android and Web build subcommands remain registered. There is no discovered source-level restriction that prohibits these non-OHOS builds.

## Bootstrap recipe

```sh
git clone --depth 1 --branch '3.41.9+ohos-1.0.2' \
  https://gitcode.com/CPF-Flutter/flutter_flutter.git flutter-sdk
git -C flutter-sdk rev-parse HEAD
# Fail unless the result equals 62357a93d653bf844f730bb1f4b7cc9e2139d14e.
# Apply the fixed tooling dependency overrides below before first Flutter invocation.
flutter-sdk/bin/flutter --version --machine
flutter-sdk/bin/flutter config --no-analytics
flutter-sdk/bin/flutter precache --linux
```

Use `flutter.bat` on Windows. Replace the explicit precache flag with `--windows`, `--macos`, `--ios`, `--android`, `--ohos` or `--web` per job. An explicit platform flag selects that platform plus the universal artifacts. Avoid `--all-platforms` for ordinary jobs. Do not run `flutter upgrade` or `flutter channel` in a pinned job.

For CI, a full shallow checkout is the simplest supported choice. This audit used a sparse checkout of `bin`, `packages/flutter_tools` and `packages/flutter/lib/src/foundation` only for source reads. It is not a validated runnable SDK: root `pubspec.yaml` lists workspace packages under `dev/`, `examples/` and `packages/`, and package resolution can require them.

### Pin nested tooling Git dependencies

Framework bootstrap runs `dart pub upgrade`. Its tool pubspec overrides `code_assets` and `hooks_runner` to the mutable branch `flutter_3.41.9_deps`. A framework SHA alone therefore does not pin every tool dependency. Before bootstrap, generate `flutter-sdk/packages/flutter_tools/pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  code_assets:
    git:
      url: https://gitcode.com/openharmony-sig/fluttertpc_dart_native
      path: pkgs/code_assets
      ref: 9d2eaf45940e5042637b3387b18292ed39223a4a
  hooks_runner:
    git:
      url: https://gitcode.com/openharmony-sig/fluttertpc_dart_native
      path: pkgs/hooks_runner
      ref: 9d2eaf45940e5042637b3387b18292ed39223a4a
```

Record this intentional SDK-local override in the build manifest. Archive the resolved tool/app lockfiles as evidence. Other direct tool packages are exact versions in the pinned pubspec; transitive pub resolution still deserves lockfile evidence.

## Availability evidence

All listed paths returned HTTP 200 for HEAD. Base for the first table:
`https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com/flutter_infra_release/flutter/4cbeea6a36f7aea39a60f2c5d57b1ffd84bfd106/`.

| Artifact path | Bytes |
| --- | ---: |
| `dart-sdk-linux-x64.zip` | 202935594 |
| `dart-sdk-windows-x64.zip` | 199103523 |
| `dart-sdk-darwin-x64.zip` | 204045482 |
| `dart-sdk-darwin-arm64.zip` | 202336345 |
| `linux-x64/artifacts.zip` | 34182178 |
| `windows-x64/artifacts.zip` | 35186332 |
| `darwin-x64/artifacts.zip` | 36530423 |
| `darwin-arm64/artifacts.zip` | 40809085 |
| `flutter-web-sdk.zip` | 29265992 |
| `ohos-arm64-release/linux-x64.zip` | 2444418 |
| `ohos-arm64-release/artifacts.zip` | 15396128 |

For each of the four Dart archives, HTTP Range reads of the ZIP directory and `dart-sdk/version` / `dart-sdk/revision` returned the fixed values above. Requests enforced a 2 MB per-range cap and required HTTP 206.

Upstream base:
`https://storage.googleapis.com/flutter_infra_release/flutter/42d3d75a56efe1a2e9902f52dc8006099c45d937/`.

| Artifact path | Bytes |
| --- | ---: |
| `windows-x64-release/windows-x64-flutter.zip` | 69399534 |
| `linux-x64-release/linux-x64-flutter-gtk.zip` | 17630301 |
| `darwin-x64-release/artifacts.zip` | 2761907 |
| `ios-release/artifacts.zip` | 132553080 |
| `android-arm64-release/linux-x64.zip` | 2445335 |
| `flutter_patched_sdk_product.zip` | 3948824 |
| `engine_stamp.json` | 237 |

## Limits

Availability and source inspection support using this fork across the three CI hosts. They do not prove a full app compiles or starts on each target. Actual cloud runs must verify compiler/engine compatibility, plugin integration and app source compatibility. Windows ARM64 and Linux ARM64 were not audited. Apple device signing remains separate from SDK provisioning.

The isolated source checkout is `build/app-ci/sdk-audit`. It contains no downloaded Flutter artifact cache. No existing user checkout or SDK was modified.

## Follow-up: CanvasKit 404 in Windows Chrome tests

The pinned OHOS `flutter-web-sdk.zip` includes both files requested by Chromium:

| ZIP entry | Uncompressed bytes | Compressed bytes |
| --- | ---: | ---: |
| `canvaskit/chromium/canvaskit.js` | 86496 | 27429 |
| `canvaskit/chromium/canvaskit.wasm` | 5693461 | 2159462 |

Bounded HTTP Range reads of the ZIP central directory confirmed these entries. The archive also includes the standard CanvasKit, skwasm, skwasm_heavy and wimp files. The local modified SDK already contains the same Chromium paths; missing downloads do not explain the reported local 404.

The fixed framework source contains a Windows path mismatch in `packages/flutter_tools/lib/src/test/flutter_web_platform.dart:474`:

```dart
final String fullPath = _fileSystem.path.fromUri(request.url);
if (!fullPath.startsWith('canvaskit/')) {
  return shelf.Response.notFound('Not a CanvasKit file request');
}
```

`path.fromUri` uses host filesystem separators. A small check using the project's resolved `package:path` and `Uri.parse('canvaskit/chromium/canvaskit.js')` returned:

```text
windows canvaskit\chromium\canvaskit.js matches=false
posix canvaskit/chromium/canvaskit.js matches=true
```

This explains how existing assets can receive 404 on Windows before the test starts. The same source and correctly extracted Web SDK on the Linux CI runner avoid that separator mismatch. No SDK patch or alternate CanvasKit download is required for the planned Linux Chrome tests based on this finding. Actual CI tests still provide the final evidence.

If Windows-hosted Chrome tests must be supported later, the smallest upstream/toolchain fix is to use `request.url.path` for URL routing, then convert only the remaining file path when locating the local asset. Do not change the user's global SDK for this CI task.

## Cloud follow-up: isolate non-OHOS platform setup

Run `43947518174` at application commit `c81ef0fe85a6d3485f190e3d128a67d6db0dd599` passed Flutter bootstrap on Linux and Web, then failed at `flutter pub get` with `No Hmos SDK found. Try setting the HOS_SDK_HOME environment variable.` Dependency resolution had already completed.

The fixed SDK defaults `enable-ohos` to true. After dependency resolution, `commands/packages.dart:395` calls `project.regeneratePlatformSpecificTooling`. `project.dart:396` requests OHOS setup when `featureFlags.isOhosEnabled && ohos.existsSync()`. OHOS setup then requires the Harmony SDK through `ohos/hvigor_utils.dart:37`.

The concrete `FlutterFeatureFlagsIsEnabled.isOhosEnabled` implementation in `flutter_features.dart:18` reads `flutterOhosFeature`, whose `configSetting` is `enable-ohos`. Therefore the supported fix is to run `flutter config --no-enable-ohos` in every non-OHOS job before application `pub get`, and keep `flutter config --enable-ohos` in the OHOS job. This uses the fork's intended platform configuration and preserves all source directories. Record `flutter config --list` when diagnosing the resolved configuration.
