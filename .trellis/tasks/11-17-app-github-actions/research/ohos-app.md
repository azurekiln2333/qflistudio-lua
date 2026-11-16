# Full OHOS application build research

Research date: 2026-11-17. This research did not install an SDK, modify product
files, or run a full HAP build. HTTP metadata and selected archive members were
read remotely. Cloud execution remains the acceptance test.

## Cloud finding and revised toolchain choice

The initial API24 toolchain choice below is superseded for the pinned Flutter-OH
`62357a93d653bf844f730bb1f4b7cc9e2139d14e` release. Actual run `43947518174`,
job `133581000456`, passed SDK download/hash checks, extraction, tool version
checks, Flutter bootstrap and application dependency resolution. The HAP build
then failed in the Flutter HAR's `OhosAutoFillHelper.ets`, with missing
`autoFillManager.AutoFillType`, `ViewData`, `FillRequest`, `AutoFillCallback`,
`requestAutoFill` and other API26 declarations. The job reported 15 ArkTS errors.

Evidence files:

- `build/app-ci/sdk-audit-jobs-43947518174.json`
- `build/app-ci/sdk-audit-ohos-second.log` (first compiler error at line 895)

The pinned engine source
`engine/src/flutter/shell/platform/ohos/flutter_embedding/flutter/src/main/ets/plugin/editing/OhosAutoFillHelper.ets`
sets `AUTOFILL_SUPPORT_API = 26`. Read-only inspection of the local official
DevEco SDK found `sdk/default/sdk-pkg.json` identifying HarmonyOS26.0.0,
API26 and SDK26.0.0.105. Its public
`sdk/default/openharmony/ets/api/@ohos.app.ability.autoFillManager.d.ts` marks the
missing members `@since 26.0.0`. They are public APIs, not hidden system APIs.
Runtime version guards cannot make the missing types compile against API24.

Use the same published Flutter pin with the fixed API26 command-line SDK
release **26.0.0.821**. Keep application `targetSdkVersion: 6.1.1(24)` and
`compatibleSdkVersion: 5.1.0(18)`. Omit `compileSdkVersion` from the unsigned
profile generated only inside the clean cloud checkout. The fixed bundle and
its checked API26 metadata establish the default compilation SDK.

Actual run 43950009629 invalidated the earlier suggestion to explicitly set
`26.0.0(26)`: Hvigor error 00303313 parsed it as configured version 26, incompatible
with DevEco version 26.0.0. The tool's own diagnostic instructs HarmonyOS projects
to omit that field and use the bundled SDK. Evidence: the complete run log ZIP,
OHOS job 133589672672, build-hap log. Preserve explicit target24/compatible18.

The official SDK-bundled Hvigor schema supports independent versions:

- Read-only source:
  `D:/ProgramFiles/Huawei/DevEco Studio/tools/hvigor/hvigor-ohos-plugin/res/schemas/ohos-project-build-profile-schema.json:1193`.
- `compileSdkVersion` controls APIs/toolchain and defaults to the SDK bundled
  with DevEco for HarmonyOS.
- `targetSdkVersion` controls runtime behavior and defaults to compileSdk only
  when omitted.
- `src/utils/one-sdk-validator.d.ts:43` states the constraint
  `compileSdkVersion >= targetSdkVersion >= compatibleSdkVersion`.

No local SDK files were changed or uploaded. The next cloud run must validate
the exact generated profile and toolchain combination.

### Fixed API26 download identity

Release and primary publisher metadata:

- `https://github.com/ErBWs/ohos-sdk/releases/tag/26.0.0.821`
- `https://api.github.com/repos/ErBWs/ohos-sdk/releases/tags/26.0.0.821`
- `https://raw.githubusercontent.com/ErBWs/ohos-sdk/26.0.0.821/README.md`
- `https://raw.githubusercontent.com/ErBWs/ohos-sdk/26.0.0.821/.github/workflows/action.yml`

The tagged README identifies command-line tools26.0.0.821 and API26. The release
was published on 2026-09-02. Download prefix:
`https://github.com/ErBWs/ohos-sdk/releases/download/26.0.0.821/`.

| Part | Bytes | SHA256 from release asset metadata |
| --- | ---: | --- |
| `ohos-sdk-linux-amd64.tar.gz.aa` | 1572864000 | `4321eb328558169e9531594139910a42b1c88057fb09f852be85ff2487e6adbc` |
| `ohos-sdk-linux-amd64.tar.gz.ab` | 700317187 | `26e9ae251e761fbc9ec4e7ad780b5b291130e7824af2324167530941e11ad592` |

GET of the published `ohos-sdk-linux-amd64.tar.gz.sha256` returned combined hash
`0cbdf7ac5c1be1e42694d448ffaee0c0be0ba9a948197e2bc5b61ca5bdc481f2`.
Pin all three hashes. Preserve the `command-line-tools/` layout and environment
setup documented below. Verify extracted SDK metadata identifies API26.

Provenance remains a third-party repackaged mirror. The tagged publisher workflow
verifies the input ZIP against a supplied checksum, then repacks/splits it. It
does not expose the original official URL/checksum in the release body, so the
fixed artifact hash is identity evidence rather than independent proof of the
original Huawei source. No full API26 archive was downloaded during research.

An alternative complete official Flutter release was inspected but is not the
chosen fix: `3.41.10-ohos-1.0.0` at
`244a0e8abb3085e8675589b13e219af8c41cb7aa` predates `OhosAutoFillHelper`; its
upstream engine is 42d3d75a56, OHOS engine is ab1841593e and HAR is 97a3efd6c9.
The next tag `3.41.10-ohos-1.0.1` already contains the API26 helper. Do not mix
these engine/HAR revisions into the current framework piecemeal.

## Result

A Linux GitHub runner can obtain a complete HarmonyOS command-line toolchain and
run `flutter build hap --release --no-codesign`. This creates an application HAP,
including Dart AOT and the project's native libraries. A standalone OpenHarmony
NDK build is not a substitute for this application build.

The existing committed app profile requires compatible SDK `5.1.0(18)` and target
SDK `6.1.1(24)`. Preserve these values. The project and Hvigor model versions are
`5.1.0`; that is distinct from the target SDK version.

Use a modern, fixed public Flutter-OH commit. Do not copy the locally modified
SDK or infer its contents from its old Git HEAD.

## SDK download choices

### Current project target: API 24

The public GitHub mirror `ErBWs/ohos-sdk` provides release `6.1.1.280`. Its README
at that exact tag identifies SDK `6.1.1.125` and API `6.1.1(24)`.

Source evidence:

- `https://raw.githubusercontent.com/ErBWs/ohos-sdk/6.1.1.280/README.md`
- `https://api.github.com/repos/ErBWs/ohos-sdk/releases/tags/6.1.1.280`
- `https://raw.githubusercontent.com/ErBWs/ohos-sdk/6.1.1.280/.github/workflows/action.yml`
- `https://github.com/ErBWs/ohos-sdk/releases/download/6.1.1.280/ohos-sdk-linux-amd64.tar.gz.sha256`

The Linux download consists of two parts. Both asset URLs and the checksum URL
are publicly accessible. The API reports these asset digests:

| Part | Bytes | SHA256 |
| --- | ---: | --- |
| `ohos-sdk-linux-amd64.tar.gz.aa` | 1572864000 | `c9bc62586835cb952094349dfd5857a7387d80b34e72562ab8e930aa9bdae02b` |
| `ohos-sdk-linux-amd64.tar.gz.ab` | 499393356 | `fb964dc01cd385abc9f4d19eb96fa69f841e3a64b87ac94508ae48a8268cee06` |

The published combined tarball SHA256 is
`3d37eb5a3a81358a9731c35265f4f29d8ecf1028b0bbbb777f2928cd6990aa83`.
Pin that value in the implementation rather than trusting a freshly downloaded
checksum alone.

This is a third-party redistribution, not an official Huawei release endpoint.
Its tagged workflow downloads upstream ZIPs, repackages Linux as tar.gz, and
splits the result. That workflow revision does not record the original URL or
upstream checksum in the release body. The fixed digest identifies the mirror
artifact; it is not an independent proof of upstream provenance.

Example runner-only setup:

```bash
set -euo pipefail
sdk_dir="$RUNNER_TEMP/harmonyos-sdk"
mkdir -p "$sdk_dir"
cd "$sdk_dir"
base="https://github.com/ErBWs/ohos-sdk/releases/download/6.1.1.280"
archive="ohos-sdk-linux-amd64.tar.gz"
curl --fail --location --retry 3 "$base/$archive.aa" -o "$archive.aa"
curl --fail --location --retry 3 "$base/$archive.ab" -o "$archive.ab"
cat "$archive.aa" "$archive.ab" > "$archive"
printf '%s  %s\n' \
  '3d37eb5a3a81358a9731c35265f4f29d8ecf1028b0bbbb777f2928cd6990aa83' \
  "$archive" | sha256sum --check -
tar -xzf "$archive"
rm "$archive" "$archive.aa" "$archive.ab"
tools_dir="$sdk_dir/command-line-tools"
echo "$tools_dir/bin" >> "$GITHUB_PATH"
echo "$tools_dir/tool/node/bin" >> "$GITHUB_PATH"
echo "HOS_SDK_HOME=$tools_dir/sdk" >> "$GITHUB_ENV"
echo "DEVECO_SDK_HOME=$tools_dir/sdk" >> "$GITHUB_ENV"
echo "DEVECO_NODE_HOME=$tools_dir/tool/node" >> "$GITHUB_ENV"
```

Use the SDK-bundled Node runtime. Also provide Java through the runner's existing
Java setup. Validate `sdk/default/sdk-pkg.json`, `ohpm --version`, and
`hvigorw --version` before running Flutter. The cache key must include the fixed
SDK release and digest. The installer must test extracted contents before
treating a restored cache as valid.

The maintained setup action uses the same `command-line-tools/bin`,
`command-line-tools/tool/node/bin`, and `command-line-tools/sdk` paths:
`https://raw.githubusercontent.com/ErBWs/setup-ohos/main/setup.sh`.

### Official HuaweiCloud alternative: API 18 only

This URL was tested with HEAD and ranged GET, returning HTTP 200/206 and a valid
ZIP central directory:

`https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip`

Bytes: `2153496473`.
SHA256: `1dcefa4741dc289277560b2802040e0c45b433898d8db453d711d5376e0478f1`.
The checksum is published at the same URL plus `.sha256`.

Remote archive inspection confirmed:

- `command-line-tools/sdk/default/sdk-pkg.json`: HarmonyOS 5.1.0, API 18,
  SDK version 5.1.0.125.
- `command-line-tools/sdk/default/openharmony/native/oh-uni-package.json`:
  Native API 18, version 5.1.0.125.
- `command-line-tools/bin/ohpm` and `bin/hvigorw` are executable shell wrappers.
- `command-line-tools/tool/node/bin/node` is present.
- The wrapper resolves SDK under `command-line-tools/sdk` and sets
  `DEVECO_SDK_HOME` if absent.

Do not silently use this API 18 package for the committed API 24 target. Reducing
the target would be a separate product change. HuaweiCloud's `ohpm` directory
currently exposes only 5.0.3, 5.0.5 and 5.1.0; attempted 6.1.1 paths returned 404.
The current official developer download SPA includes login and agreement checks.
No public API 24 official direct-download URL was verified in this research.

## Flutter fork and reproducibility

The local SDK directory is `D:/ProgramFiles/flutter_ohos`. Its Git HEAD is
`12587c79e88aacf3172a84e536f226457d037594`, but its working tree has extensive
changes. The cached framework identifies `3.27.5-ohos-1.0.1`, while the Dart SDK
reports `3.11.5`. The cached engine is
`42d3d75a56efe1a2e9902f52dc8006099c45d937`; the engine recorded at Git HEAD is
`e672b006cb34c921db85b8e2f482ed3144a4574b`. These are not reproducible as one
unmodified old release.

The parent investigation confirmed public refs in
`https://gitcode.com/openharmony-tpc/flutter_flutter.git`, including
`3.41.9+ohos-1.0.2` at `62357a93d653bf844f730bb1f4b7cc9e2139d14e`.
Clone an exact verified ref and confirm `flutter --version` satisfies both app
and core Dart constraints (`^3.11.5`) before claiming it is suitable.

The local fork documents this engine artifact host:

```text
FLUTTER_STORAGE_BASE_URL=https://flutter-ohos.obs.cn-south-1.myhuaweicloud.com
```

Do not invent a prebuilt Flutter ZIP URL. Public Git refs provide an alternative
bootstrap route, subject to verifying their engine artifacts and Dart version.

## Unsigned HAP build and outputs

The local Flutter-OH implementation exposes a negatable `codesign` flag in
`packages/flutter_tools/lib/src/commands/build_hap.dart`. Its build command is:

```bash
flutter build hap --release --no-codesign --target-platform ohos-arm64
```

In `ohos/hvigor.dart`, signature validation runs only when `shouldCodesign` is
true. `OhosProject.getSignedFile` selects the `unsigned` filename when false.
The pinned public fork must be checked for the same interface.

The cloud checkout must remove signing configurations and product signing
references from its own profile before build. `--no-codesign` changes Flutter's
expectation, but retaining real signing settings could still cause Hvigor to
attempt signing. Do not upload local certificates, passwords, `local.properties`
or the local user-edited profile. Do not print their contents.

Expected application output:

```text
ohos/entry/build/default/outputs/default/entry-default-unsigned.hap
build/ohos/hap/entry-default-unsigned.hap
```

The plugin-based Flutter builder copies the original module output to
`build/ohos/hap/`; the older builder may leave it in the module output directory.
Collect the actual generated path and fail when no HAP exists. Do not upload a
native `.so` alone as the OHOS application artifact.

Inspect the final HAP as a ZIP for the app's Flutter assets, Dart AOT library,
Flutter engine and both native runtimes (`libqfli_lua.so` and
`libqfli_script.so`). The unsigned HAP cannot be installed on an ordinary device
until signed with an appropriate developer or distribution identity.

Upload the HAP, build metadata and test reports. Exclude SDK archives, SDK
directories, dependency caches and signing material. A successful cloud build
does not validate physical-device startup.
