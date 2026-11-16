# Implementation and validation

1. Complete reproducible Flutter fork bootstrap research. Verify SDK/ref identity.
2. Integrate Script/QuickJS into both Apple Runner projects and process loading.
   Read Lua and Script contracts, preserve vendored source bytes.
3. Add tools/ci_app_build.py and .github/workflows/apps.yml for the seven targets.
   Reuse existing native build/test tooling where applicable. Record real exit
   status and validate complete bundles before staging them.
4. Implement browser editor and persistent workspace behind the conditional
   lib/main.dart entry. Test edits, save failures, restore and unavailable native
   actions. Add build/download documentation that states platform limits.
5. Run Python syntax validation, actionlint, targeted loader tests when feasible,
   and Chinese prose lint. Review all changed paths and artifact boundaries.
6. Commit/push the implementation to the existing GitHub CI branch. Observe real
   cloud execution. Diagnose concrete failures, rerun affected jobs and record
   run/commit/artifact evidence. Do not substitute local dirty dependencies.
7. Perform final independent Trellis check, update native/application CI specs,
   commit verified fixes and document outstanding Web or signing prerequisites.

## Ownership

- Main agent: task artifacts, coordination, cloud execution and final evidence.
- Apple implementer: ios/Runner.xcodeproj/project.pbxproj,
  macos/Runner.xcodeproj/project.pbxproj and lib/script_toolchain.dart.
- CI implementer: .github/workflows/apps.yml, tools/ci_app_build.py and
  application CI documentation. Coordinate CLI contracts before review.
- Reviewer: full-scope compliance, packaging/metadata checks and direct fixes.
- Web implementer: lib/main.dart, lib/app_native.dart, lib/web/ browser modules,
  targeted test/web* tests, pubspec.yaml and pubspec.lock if direct dependencies
  are required. Preserve native profile exports and behavior.

## Validation gates

- git diff --check.
- Python compile validation for changed helper scripts.
- actionlint for application and native workflows.
- dart format/analyze limited to changed source where the local SDK is usable.
- python scripts/ste-lint-zh.py for changed Chinese documentation.
- Actual GitHub application jobs: complete bundle inventory, source manifests,
  checksums, logs and explicitly unrun device/browser acceptance.

No task is marked complete based only on workflow syntax. A blocked platform
must retain its real compiler/setup failure and a concrete next prerequisite.
