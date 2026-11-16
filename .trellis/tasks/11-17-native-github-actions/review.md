# Native CI review

## Findings

No blocking source or workflow findings. No reviewer code edits were needed.

The workflow includes four desktop jobs, three Android ABIs, both OHOS ABIs,
and iOS device plus universal simulator archives. Both runtimes are required.
Desktop jobs run the real Lua CTest and Script probes. Cross jobs inspect
libraries and retain `device_tests: not_run` rather than claiming execution.
Libraries are staged only after their required checks pass.

The iOS CMake path preserves the existing `LUA_USE_IOS` and liolib-only
subprocess adaptation. Windows Script statically links winpthread. The default
shared-library behavior is unchanged for the other native targets.

## Verification

- actionlint 1.7.12: passed for `.github/workflows/native.yml`.
- Python compilation: passed for `tools/ci_native_build.py`.
- `git diff --check`: passed; Git only reported existing line-ending notices.
- All four pinned Action commit SHAs match their official release tags.
- Missing-CMake failure-path test: nonzero exit, failed manifest, failure log,
  no staged libraries, and all SHA256SUMS entries verified.
- Implementation evidence: fresh GCC 16.2.0 Release build, Lua CTest 1/1,
  Script 22 probes, PE inspection and artifact staging passed on Windows.

Full platform build acceptance remains pending the real GitHub Actions run.
No Android/OHOS/iOS device execution or full application packaging is claimed.

## Spec sync

Record the `QFLI_REQUIRE_SCRIPT` failure contract, iOS static archive behavior,
Windows static winpthread dependency, artifact verification fields and the
native-only/cloud-versus-local-storage distinction in the native build specs.

## Final cloud evidence review

Reviewed run `43925767369` at source commit
`560eea3841dc78d89551c62f7a550f51565f2eb8` on `ci/native-all-platforms`.
All nine jobs are completed with conclusion `success`. All nine nonempty
artifacts identify the same run and source commit, have SHA-256 digests,
and are unexpired. Their combined compressed size is 15,759,641 bytes.

| Job | Cloud result |
| --- | --- |
| Linux x86_64 | Success |
| Windows x86_64 | Success |
| macOS arm64 | Success |
| macOS x86_64 | Success |
| Android arm64-v8a | Success |
| Android armeabi-v7a | Success |
| Android x86_64 | Success |
| OHOS arm64-v8a + x86_64 | Success |
| iOS device + simulator | Success |

The reviewer downloaded and inspected three complete job logs:

- iOS job `133504671796`: both device archives and both simulator archives
  were compiled and linked. `lipo` and symbol inspection ran. The simulator
  archives contain x86_64 and arm64. Both `qfli_lua.xcframework` and
  `qfli_script.xcframework` were successfully created. The uploader finalized
  `native-ios`, artifact `14255124487`, at 4,308,065 bytes.
- Android ARM32 job `133504671564`: both shared libraries were linked. ELF
  inspection reported ELF32/ARM for both libraries and found the Lua and Script
  bridge symbols. The uploader finalized `native-android-armeabi-v7a`, artifact
  `14256906089`, at 2,244,997 bytes.
- macOS ARM64 job `133504671605`: both dylibs were linked and identified as
  arm64. Lua CTest passed 1/1 and all Script probes passed. The uploader
  finalized `native-macos-arm64`, artifact `14257710865`, at 633,856 bytes.

Local evidence files are `build/native-ci/jobs-round3.json`,
`build/native-ci/artifacts-round3.json`, and the three
`build/native-ci/review-*-round3.log` files. Artifact ZIP byte retrieval was
not independently verified on this host because its Azure Blob TLS connection
failed. The GitHub API records and uploader logs establish successful cloud
upload. This limitation does not negate the successful builds or uploads.

Final native CI quality gate: passed. Mobile device execution and complete
application packaging remain outside this task's acceptance scope.
