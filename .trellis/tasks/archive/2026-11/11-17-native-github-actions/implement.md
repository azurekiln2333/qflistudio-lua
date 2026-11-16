# Execution plan

- [x] Audit native entry points, repository state and generated-directory sizes.
- [x] Record the user's platform and artifact choices.
- [x] Add minimal iOS CMake support and verify desktop compatibility.
- [x] Add workflow jobs and deterministic artifact staging.
- [x] Document builds, downloads and storage.
- [x] Validate YAML with actionlint, helpers and available native tests.
- [x] Run Trellis check review and fix material findings.
- [x] Commit task-owned files and push a CI branch to GitHub.
- [x] Observe Actions, fix genuine workflow failures and inventory artifacts.
- [x] Update native build contracts and evidence.
- [ ] Record session and archive completed work.

The old MinGW tools from native/build/host/CMakeCache.txt no longer existed. Use the installed w64devkit GCC16 tools instead, with separate native/build/ci-local and build/native-ci/helper-local trees. Full Flutter tests are unnecessary for workflow-only changes unless code changes create a reason.

Preserve the distinction between compilation, desktop execution, artifact inspection and device execution. Record remote blockers. Do not delete local caches to claim storage savings.
