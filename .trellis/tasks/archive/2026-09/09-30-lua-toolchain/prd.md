# Port Lua interpreter and compiler

## Goal

QFLIScript runs Lua locally from its editor and provides a real Lua source-to-bytecode compiler and related tools, without requiring a separately installed Lua executable.

## Confirmed State

- The current runner only probes `lua` or `luajit` on desktop; mobile reports unavailable.
- Existing tests assert that placeholder behavior instead of executing Lua.
- The app supports Android and HarmonyOS, with desktop Flutter targets in the repository.
- A sibling app documents why mobile execution must happen inside the app process.

## Requirements

- Port an upstream Lua release, retaining version and license provenance.
- Package the same engine for supported targets so Lua source and compiled chunks can be loaded and run locally.
- Expose syntax checking, bytecode compilation, and practical Lua utilities through the app's existing project and editor workflows.
- Show program output, diagnostics, and exit status accurately; remove development-status messaging from the app.
- Keep the script app's existing non-Lua template behavior working until those runtimes are separately delivered.
- Use a conventional git commit for every completed code change, staging only this task's files.

## Acceptance Criteria

- [x] A clean checkout can build the upstream Lua core and app bindings from committed source.
- [x] Real Lua code exercises functions, tables, modules, standard libraries, and errors in automated tests.
- [x] Source syntax checking and source-to-bytecode compilation produce verifiable results; compiled chunks execute.
- [x] Editor Run is wired to bundled Lua and displays actual output/errors in automated workflow tests; Android and HarmonyOS Release packages include the engine without an external `lua` installation.
- [x] Target builds package the engine, and at least one target runtime is exercised end to end.
- [x] No Lua-facing app text calls the runtime unavailable or still in development.
- [x] Each implemented change is committed with a conventional commit message.

## Validation Direction

On 2026-09-30 the user requested no further debugging. Continue local checks and
Release packaging, and stop device/simulator debugging. An earlier HarmonyOS x64
native probe already exercised check, compile, and bytecode execution. The final
product installation and editor interaction on a device will remain unverified
in this session; do not present the earlier probe as a final product UI test.

## Open Questions

- The exact set of additional in-app Lua tools beyond syntax check, compile, and run can grow with the existing editor's affordances; implementation should prefer useful, working commands over placeholder controls.
