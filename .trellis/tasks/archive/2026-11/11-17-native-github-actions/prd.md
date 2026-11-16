# Native GitHub Actions builds

## Goal
Build native runtimes on GitHub, provide downloadable libraries and reports, and explain local storage use.

## Background
- The user approved task creation and direct implementation, then selected all-platform coverage and libraries plus test reports.
- Native CMake builds Lua and Script independently of Flutter and qfli_studio_core.
- GitHub remote is azurekiln2333/qflistudio-lua. No workflow exists. Local main is four commits ahead of the observed GitHub main.
- Existing changes in ohos/build-profile.json5 and .tmp_bytecode_block.txt belong to the user and are excluded.
- Generated directories: build 2420.97 MiB, .dart_tool 1016.76 MiB, ohos/build 55.27 MiB, native/build 13.28 MiB, android/.gradle 6.97 MiB.

## Requirements
1. Cover Windows, Linux, macOS, Android, iOS and OHOS native compilation with explicit architectures.
2. Build both runtime libraries; never silently omit Script for an unsupported compiler.
3. Run desktop Lua CTest and Script probes. Distinguish cross-compilation from target execution.
4. Upload libraries, headers/licenses, checksums and useful reports without SDK caches or build intermediates.
5. Push the authorized changes and attempt a real Actions run. Record exact run URLs, conclusions and actual artifacts. Report remote blockers honestly.
6. Document download steps, retention, full-app limitations and local storage.

## Acceptance Criteria
- Every declared matrix entry builds, or has explicit evidence of its blocker.
- Desktop reports prove both runtimes loaded and tested.
- Mobile reports identify target/ABI without claiming device execution.
- Artifact names identify platform and architecture. Checksums identify exact files.
- Final evidence distinguishes measured storage, cloud compilation and app packaging.

## Out of scope
Full Flutter packaging, code signing, publishing Releases, uploading credentials, runtime semantic changes, local cache deletion and local target SDK installation.
