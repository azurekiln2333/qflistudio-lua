# Complete native Lua support across platforms

## Goal

Audit and complete native Lua interpreter, syntax check and bytecode compilation on every existing non-OHOS platform; run only verification supported by the current environment.

## Requirements

- Keep Lua 5.4.8 execution, syntax checking and bytecode compilation in the
  shared C layer on all existing native application targets.
- Audit Android, Windows, Linux, iOS and macOS beyond the already working
  HarmonyOS integration. Implement missing build, packaging or FFI loading.
- Preserve the interpreter's result ownership, project paths, output capture,
  cancellation and timeout behavior.
- Run real native/runtime checks where the current machine supports them.
  Skip unavailable platform tests and record the missing environment.
- Preserve the existing content/startup work and avoid HarmonyOS device
  connection, installation or debugging.

## Acceptance Criteria

- [x] Every existing native platform has application build configuration that
  includes the shared C bridge and Lua library sources.
- [x] FFI loading matches each platform's packaged library or linked symbols,
  including Apple static linking where required.
- [x] Available native tests and Dart/Flutter runtime integration checks pass
  for source execution, checking and compiled bytecode execution.
- [x] Available Android packaging verification proves the Lua ABI matches
  the packaged Flutter/application libraries.
- [x] Unsupported local test environments are identified before trying to
  run platform tests; untested platforms are explicitly recorded.
- [x] Applicable specifications and platform documentation match the result.

## Notes

- This task covers the existing Android/OHOS/desktop/Apple runner directories.
  The repository has no web runner or browser-native runtime target.
- The user explicitly requested implementation and supported local tests.
