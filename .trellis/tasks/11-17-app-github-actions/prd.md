# Build full applications for seven platforms on GitHub

## Goal

Build Flutter applications for OHOS macOS Linux Android iOS Web and Windows, publish artifacts and verify actual cloud runs.

## Requirements

- Build the actual Flutter application for OHOS, macOS, Linux, Android, iOS, Web and Windows on GitHub Actions.
- Include the native runtimes in every supported native application bundle.
- Pin the public core repository's committed revision and a reproducible Flutter SDK.
- Preserve existing user edits in this checkout, the core checkout and the main product checkout.
- Upload app packages, build metadata, licenses and verification reports with explicit signing/runtime limits.
- Prioritize the user's GPL v3 license addition, standard commit message and push before application CI implementation.

## Acceptance Criteria

- Each declared platform produces a complete app bundle or explicit evidence of a blocking prerequisite.
- Native runtime libraries and required Flutter assets are present in native bundles.
- Web uses the actual application entry and reports unsupported native capabilities honestly.
- Web restores saved files after reload. Failed storage writes retain unsaved
  state and show an error. Native run, compile and debug remain unavailable.
- Actual GitHub runs and artifact download URLs are recorded.

## Notes

- Core public commit: 573d1b6eecf1c2b392ad753264a5a09f62f8335e. Local uncommitted core changes are excluded.
- Source uses TargetPlatform.ohos, which requires the OHOS Flutter fork or a deliberate compatibility change.
- Apple currently embeds only Lua. Script integration is required for complete native runtime packaging.
- The user selected browser editing and saving. Web must persist workspace files
  across reloads and explicitly disable native running, debugging and compilation.
- API26 full OHOS toolchain is available through a fixed-hash third-party mirror.
  Cloud compilation requires API26 for the pinned Flutter HAR. Application target
  API24 and compatible API18 remain unchanged.
- GPL v3 alignment was committed and pushed as a2ee30c before app implementation.
- Web must build a usable browser editor, with real persistence and no FFI imports.
