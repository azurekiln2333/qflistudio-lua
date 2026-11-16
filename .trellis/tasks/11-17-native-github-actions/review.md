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
