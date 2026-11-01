# Terminal polish verification

## Result and scope

The Java work already changed the shared terminal in
`../qfli_studio_core/lib/editor/terminal_pane.dart`: compact Terminal session
tabs, a continuous top-aligned transcript and prompt, silent status 0, and a
concise `exit code N` line for failures. `RunnerService.runProject` forwards
the Lua runner title and streams unchanged into that terminal.

Pi implemented the remaining Lua-specific presentation changes in
`lib/lua_runner.dart` and updated `test/lua_app_test.dart`. Lua source and
bytecode now use `lua <filename>`; desktop script titles identify the selected
command. Host diagnostics are concise English and distinguish runtime
discovery failure from failure to start a selected executable.

Chinese/parentheses in user filenames and output are preserved. The actual
process invocation, output splitting, cancellation, native code, and exit-code
contracts are unchanged. No shared-core or Java product files were modified by
this task. Existing native changes for input.txt were present before this task;
the upstream Lua source and lib/lua_toolchain.dart have no Git diff.

The coordinator used Herdr pane w9:p2, named pi-lua-terminal, and reviewed Pi's
changes. The final Pi implementation is idle and available for follow-up.

## Validation

- Pi: `flutter test test/lua_app_test.dart --no-pub` — 19 passed after final
  review corrections. Includes real native Lua execution, Unicode filename and
  output preservation, bytecode, malformed-byte handling, and cancellation.
- Coordinator: `flutter test --no-pub --reporter expanded --timeout 60s
  ../qfli_studio_core/test/terminal_pane_test.dart` — 12 passed. Covers quiet
  success, visible failures, stream draining, session isolation, history,
  keyboard interaction, cancellation, and short layouts.
- Coordinator: `flutter analyze --no-pub` — no issues.
- Formatter applied to the two source/test files and the temporary render
  harness; `git diff --check` passed for the two source/test paths.

## Visual verification

The temporary harness at `build/terminal-polish/lua_terminal_visual_test.dart`
runs the real Lua runner against a copy of `examples/hello.lua` and its compiled
bytecode, collects the actual output (`sum\t55`), and renders the shared terminal.

Command: `flutter test --no-pub --reporter expanded --timeout 60s
build/terminal-polish/lua_terminal_visual_test.dart` — 3 passed.

Inspected artifacts:
- `build/terminal-polish/lua-terminal-dark.png`
- `build/terminal-polish/lua-terminal-light.png`
- `build/terminal-polish/lua-terminal-short.png`

The dark/light views show commands, their output, and the next prompt without
a success footer or runtime suffix. The short viewport scrolls prior output
while retaining the newest prompt.

## Limits

The missing-host-runtime and selected-executable-start-failure branches were
reviewed in source; no new runtime injection API was added to test those paths.
These are host tests and widget renders, not a newly packaged Android/HarmonyOS
application or a device run. No commit or deployment was made.

