# Cloud application build evidence

Repository: azurekiln2333/qflistudio-lua. Branch: ci/native-all-platforms.
Evidence date: 2026-11-17 (Asia/Shanghai).

| Run | Source | Result | Evidence |
| --- | --- | --- | --- |
| 43945934915 | c95351adda65b83eee650f39590418973478b945 | Cancelled after shared setup failure | Release tag missing locally; Flutter reported 0.0.0-unknown. |
| 43947518174 | c81ef0fe85a6d3485f190e3d128a67d6db0dd599 | Failure | Non-OHOS pub get attempted Harmony tooling; OHOS HAR required API26 autofill declarations absent from API24. |
| 43950009629 | 3348b1bd3bcc9ab3551291dbec74d49c41f89d53 | Failure | Android, Linux, Web, iOS and macOS ARM64 succeeded. Windows, OHOS and macOS x64 have concrete failures described below. |

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

The GitHub jobs API confirms the outcomes above. Artifact downloads and completed
job logs currently fail TLS handshakes to the Azure storage host from this local
network. Python and curl with normal certificate verification both fail. No TLS
verification was disabled. These artifacts have not yet been inspected locally.
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

Successful native-only baseline: run 43925767369 at source
560eea3841dc78d89551c62f7a550f51565f2eb8. All nine jobs passed. Its artifacts
are runtime libraries, headers and reports, not full applications.

Full application artifacts retain packages, reports, checksums, licenses and a
source-bound manifest. A failed job can upload reports with an app-prefixed
artifact name; inspect its manifest before treating it as an application package.
Artifact retention is 14 days. These workflow runs do not create a Release.
