# Cloud application build evidence

Repository: azurekiln2333/qflistudio-lua. Branch: ci/native-all-platforms.
Evidence date: 2026-11-17 (Asia/Shanghai).

## Final result

[Application run 43954515357](https://github.com/azurekiln2333/qflistudio-lua/actions/runs/43954515357)
passed all eight jobs across seven platforms. Both macOS architectures are included.
[Native run 43954515341](https://github.com/azurekiln2333/qflistudio-lua/actions/runs/43954515341)
passed all nine jobs. Both runs use source
`6cb5aa99ddef523678d7bd996a237347e40295ca`.

The jobs API initially returned an old queued snapshot for Apple. A fresh-query
jobs request, recent-runs response, individual check runs and completed logs all
confirm success. Do not infer a runner outage from one stale polling response.

| Application artifact | ID | Uploaded bytes | Result |
| --- | ---: | ---: | --- |
| app-windows-x86_64 | 14269159182 | 27066304 | Passed; unsigned |
| app-linux-x86_64 | 14271051428 | 30601463 | Passed |
| app-macos-arm64 | 14274457499 | 16268558 | Passed; ad-hoc signature verified |
| app-macos-x86_64 | 14271333403 | 17219312 | Passed; ad-hoc signature verified |
| app-android-universal | 14271492382 | 147396821 | Passed; testing signature |
| app-ios-arm64 | 14272474877 | 14537457 | Passed; unsigned |
| app-ohos-arm64-v8a | 14272011720 | 52901095 | Passed; unsigned |
| app-web-browser | 14272541093 | 16403350 | Passed; native execution disabled |

Download links and package descriptions are in `docs/APP_CI.zh-CN.md`.
Artifacts expire on 2026-12-01, approximately 04:56-05:41 Asia/Shanghai.
They are Actions artifacts, not GitHub Releases.

Windows compilation now passes MSVC with the owned UTF-8 header fix. Android
provides ARM64/ARMv7/x64 APKs (30,111,766 / 28,242,382 / 31,129,134 bytes)
and an AAB (57,677,260 bytes). Architecture, bridge exports, 64-bit ELF alignment
and uncompressed APK library ZIP alignment passed.

OHOS produces `entry-default-unsigned.hap`, 52,698,046 bytes, SHA256
`40b4660a7d7cbdfb0046e881bf7f4f43dbe30a55c4994a7ab15d4474003080fc`.
Its bundle contains Lua, Script, libc++, Flutter and Dart AOT libraries. SDK26
is the bundled compilation default; target24 and compatible18 are preserved.

Both macOS logs report `valid on disk` and `satisfies its Designated Requirement`
from `codesign --verify --deep --strict --verbose=2`. Identity reports show
`Signature=adhoc`, with no TeamIdentifier. All three Apple jobs verify the expected
Runner/framework architecture and both native bridge export sets.

Web passes twelve model/widget tests, one real Chrome persistence test and release
compilation. Native execution remains disabled. Release-bundle browser acceptance,
OS file-picker/download end-to-end checks and native app startup remain unrun.

Downloaded Windows, Android, Linux, OHOS and Web artifacts passed all root checksum
entries (42, 32, 26, 30 and 28 respectively). Windows also passed 16 nested native
prerequisite checksum entries. Their manifests all match the source and passed
status. The project GPL text matches the root license: Windows checkout uses CRLF
and has SHA256 `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809`;
normalizing line endings yields the Git blob hash
`3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`.
The other four downloaded licenses match that Git blob byte-for-byte.

All three Apple ZIPs also downloaded and passed their complete checksum lists:
32 entries per macOS artifact and 29 for iOS. Package hashes, GPL bytes, nine
Mach-O binary architectures and executable modes, assets and bridge exports
matched their reports. Both macOS tar archives retain 12 resolvable symlinks.
All eight archive sizes and digests match GitHub artifact metadata.

The fourth native Linux and Windows artifacts downloaded and passed 18 and 16
checksum entries respectively. Both contain the project GPL and record Lua CTest
1/1 plus 22 passing Script probes. The remaining seven native artifacts passed
their cloud jobs but were not independently downloaded in this final check.

`artifact-verification.json` records exact artifact/package hashes, URLs, license
line-ending differences and verification limits. It remains with this task after
local verification-download ZIPs are removed.

## Earlier attempts

| Run | Source | Result | Evidence |
| --- | --- | --- | --- |
| 43945934915 | c95351adda65b83eee650f39590418973478b945 | Cancelled after shared setup failure | Release tag missing locally; Flutter reported 0.0.0-unknown. |
| 43947518174 | c81ef0fe85a6d3485f190e3d128a67d6db0dd599 | Failure | Non-OHOS pub get attempted Harmony tooling; OHOS HAR required API26 autofill declarations absent from API24. |
| 43950009629 | 3348b1bd3bcc9ab3551291dbec74d49c41f89d53 | Failure | Android, Linux, Web, iOS and macOS ARM64 succeeded. Windows, OHOS and macOS x64 have concrete failures described below. |
| 43954515357 | 6cb5aa99ddef523678d7bd996a237347e40295ca | Success, 8/8 jobs | MSVC header ordering, HarmonyOS bundled SDK default and macOS nested signatures fixed and verified. |

## Run 43950009629 artifacts observed so far

| Artifact | Job result | Artifact ID | Uploaded bytes |
| --- | --- | --- | --- |
| app-android-universal | Success | 14266952897 | 147393343 |
| app-linux-x86_64 | Success | 14266562209 | 30597964 |
| app-web-browser | Success | 14267591933 | 16400331 |
| app-ios-arm64 | Success, unsigned | 14269320646 | 14534391 |
| app-macos-arm64 | Success, ad-hoc signing | 14267619207 | 16401842 |
| app-windows-x86_64 | Failure, reports only | 14267902204 | 2975166 |
| app-ohos-arm64-v8a | Failure, reports only | 14267366907 | 201095 |

The GitHub jobs API confirms the outcomes above. Initial artifact downloads and
completed job logs failed TLS handshakes to the Azure storage host from this local
network. Python and curl with normal certificate verification both fail. No TLS
verification was disabled. Local inspection was unavailable at that point.
The iOS job log downloaded successfully through its separate storage endpoint.
It confirms a 45.3 MB Runner app, ARM64 Runner/Flutter/App binaries and both
complete bridge export sets. It does not establish device startup. iOS artifact
upload SHA256: 81c04ede7c6dedf9b46e2669f32a2beeb45496e6586b46f2e2cb93dcf4bb902f.

After the run completed, its combined log ZIP downloaded successfully. It proves:

- Web: twelve model/widget tests, one actual Chrome storage test and Release
  compilation all passed. Native browser execution remains disabled.
- Windows: MSVC C2375 arose when forced UTF-8 wrapper macros rewrote CRT io.h
  declarations. Include io.h before defining the macros in the owned wrapper.
- OHOS: Hvigor rejected explicit compileSdkVersion=26.0.0(26). Its diagnostic
  requires the HarmonyOS bundled SDK default; metadata already confirms API26.
- macOS Intel: CodeSign rejected unsigned nested App.framework. The helper set
  CODE_SIGNING_REQUIRED=NO, causing Flutter to skip nested ad-hoc signatures.

macOS ARM64 log confirms a 50.4 MB app, ARM64 app/engine/Runner binaries and both
bridge export sets. Signature verification was not present in this attempt.
Artifact upload SHA256: ea3fe1cb868713357903edaa833d9ccbbb0ae7f8c543e078491a0aa9da5d2d28.

The iOS and macOS ARM64 ZIPs subsequently downloaded successfully. Local checks
matched every SHA256SUMS entry (29 and 30 respectively), both package hashes/sizes
and the exact root GPL hash. Both manifests bind to source 3348b1b with passed
status. The macOS tar retains 12 symlinks and 5 executable files; the iOS tar
retains 5 executable files. This confirms packaging, not application execution.

Successful native-only baseline: run 43925767369 at source
560eea3841dc78d89551c62f7a550f51565f2eb8. All nine jobs passed. Its artifacts
are runtime libraries, headers and reports, not full applications.
Native regression run 43954515341 uses source 6cb5aa99ddef523678d7bd996a237347e40295ca
and also includes the project GPL text in every packaged library artifact.

Full application artifacts retain packages, reports, checksums, licenses and a
source-bound manifest. A failed job can upload reports with an app-prefixed
artifact name; inspect its manifest before treating it as an application package.
Artifact retention is 14 days. These workflow runs do not create a Release.
