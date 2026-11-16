# Execution plan

- [x] Audit native entry points, repository state and generated-directory sizes.
- [x] Record the user's platform and artifact choices.
- [ ] Add minimal iOS CMake support and verify desktop compatibility.
- [ ] Add workflow jobs and deterministic artifact staging.
- [ ] Document builds, downloads and storage.
- [ ] Validate YAML with actionlint, helpers and available native tests.
- [ ] Run Trellis check review and fix material findings.
- [ ] Commit task-owned files and push a CI branch to GitHub.
- [ ] Observe Actions, fix genuine workflow failures and inventory artifacts.
- [ ] Update native build contracts and evidence, record session and archive completed work.

Use the modern MinGW tools from native/build/host/CMakeCache.txt in a separate native/build/ci-local tree. Do not overwrite existing build trees. Full Flutter tests are unnecessary for workflow-only changes unless code changes create a reason.

Preserve the distinction between compilation, desktop execution, artifact inspection and device execution. Record remote blockers. Do not delete local caches to claim storage savings.
