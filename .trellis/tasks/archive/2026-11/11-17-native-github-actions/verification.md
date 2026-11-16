# Native CI verification

## Result
Run `43925767369` completed successfully for source commit `560eea3841dc78d89551c62f7a550f51565f2eb8` on branch `ci/native-all-platforms`.

Run URL: https://github.com/azurekiln2333/qflistudio-lua/actions/runs/43925767369

GitHub timestamps are UTC: 2026-11-16 18:08:57 through 18:19:56, corresponding to 2026-11-17 02:08:57 through 02:19:56 in Asia/Shanghai.

All nine jobs passed: Windows x86_64, Linux x86_64, macOS arm64/x86_64, Android arm64-v8a/armeabi-v7a/x86_64, OHOS arm64-v8a plus x86_64, and iOS device arm64 plus universal simulator.

`cloud-verification.json` preserves exact run/job/artifact IDs, source revision, artifact digests and expiration dates returned by GitHub. The nine uploads total about 15 MiB. They expire on 2026-12-01 in Asia/Shanghai (2026-11-30 UTC).

## Validation
- Local Windows Release: Lua CTest 1/1 and all 22 Script probes passed.
- Local helper: PE architecture/exports/dependencies, staging, manifest and every checksum passed.
- Missing-tool failure check: nonzero exit, failed manifest, diagnostic log and no staged runtime library.
- actionlint 1.7.12, Python compilation, diff whitespace and controlled-Chinese lint passed.
- Cloud desktop jobs ran Lua CTest and the actual Script library probes.
- Cloud mobile jobs cross-compiled and inspected target libraries. iOS packaged both XCFrameworks.
- Mobile device execution and full Flutter application packaging were not attempted.

GitHub confirmed successful uploads with artifact hashes and sizes. A local artifact download attempt hit a TLS connection failure to Azure Blob storage. GitHub job logs were retrievable. Do not claim local inspection of downloaded ZIP contents.

## Corrections from real runs
1. Run 43922693351: Android runner did not expose sdkmanager. Download the pinned official NDK directly and verify its published digest.
2. Run 43924142099: ARM32 API21 could not declare Lua's 64-bit-offset fseeko/ftello. Align all Android targets with the app's actual API24 minimum.
3. ARM macOS runner queues delayed Apple jobs. Current workflow uses macos-26 for ARM desktop tests and macos-15-intel for iOS cross-compilation. macOS deployment remains 11.0 and iOS remains 13.0.

## Storage and repository state
Before this task, the workspace used approximately 4.193 GiB. Main consumers were build/ 2420.97 MiB, .dart_tool/ 1016.76 MiB and ohos/ 802.90 MiB. Native build output was only 13.28 MiB before new verification trees. No local caches were deleted.

The published workflow lives on the CI branch; main was not merged. Existing user changes in ohos/build-profile.json5 and .tmp_bytecode_block.txt were excluded from all commits. Local native-ci specs were updated under the repository's ignored .trellis/spec directory.
