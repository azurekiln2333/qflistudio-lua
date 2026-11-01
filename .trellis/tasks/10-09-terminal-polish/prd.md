# Polish shared QFLI terminal and audit Java integration

## Goal

Audit shared Java terminal changes read-only, then clean the Lua runner titles to
conventional English commands by removing host-only verbose Chinese and
parenthesized runtime labels, without changing execution semantics.

## Requirements

- Inspect (read-only) the shared-core terminal (`terminal_pane.dart`,
  `runner_service.dart`, `studio_profile.dart`) and the Java integration to
  confirm how `ProgramRunResult.title` is rendered. Do not modify the shared core
  or any sibling repo.
- Replace Chinese `运行 <file>（<runtime>）` titles in `lib/lua_runner.dart` with
  conventional English command lines, matching the Java/Go product convention
  (`java <MainClass>`, `go run <file>`): a `lua <file>`-style command.
- Remove **host-generated** parenthesized runtime labels (e.g. `（Lua 5.4）`,
  `（JavaScript）`, `（Node.js）`) from every title produced by the Lua runner,
  including the `_notReady` fallback path. This bans host banners only: Chinese
  text or parentheses that are part of a **user filename or user program
  output** must be preserved verbatim.
- Keep host diagnostics concise and accurate: when no runtime is discovered,
  say the language/runtime is unavailable; when the discovered executable
  fails to launch, name the actual selected executable — do not claim a
  different runtime is missing.
- Preserve the emitted stdout/stderr line content; do not alter output
  framing, ordering, or content.
- Preserve exit-code semantics: `kProgramNotRunExitCode` (127) remains the code
  for "program never started" paths; success/failure codes from the native
  toolchain are unchanged.
- Preserve cancel semantics: `LuaExecution.cancel()` still interrupts a running
  Lua program and results in status 130 with a `cancelled` error.
- Keep the scope to `lib/lua_runner.dart` and the Lua tests only. Do not edit
  `native/`, `main.dart`, or other user changes.

## Acceptance Criteria

- [x] No **host-generated** title or host diagnostic from `LuaProgramRunner`
      contains a Chinese banner or a parenthesized runtime label. Parentheses
      and Chinese inside a user filename or user program output are preserved.
- [x] Lua/toolchain titles read as conventional English commands
      (e.g. `lua main.lua`); non-Lua source titles read as their runtime command
      (e.g. `node app.js`, `deno run app.ts`, `sh script.sh`).
- [x] The not-ready fallback title is an English command form and its message
      stream accurately names the unavailable runtime or the actual selected
      executable that failed to launch, without changing the 127 exit code.
- [x] Raw stdout/stderr content and ordering are unchanged, including Unicode
      filenames with parentheses and Chinese program output (verified by a
      real-runtime case that drains both streams and the exit code).
- [x] `flutter test` for the Lua tests passes, including updated title
      assertions.
- [x] Cancel semantics preserved: the toolchain cancel test still yields status
      130 with `cancelled` in the error.

## Notes

- Convention reference: `qfli_java` uses `java $mainClass`; `qfli_go` uses
  `go ${args.join(' ')}`. Titles are rendered by the terminal as a shell-style
  command line, so host-generated prose labels do not belong there.
- Read-only audit of the shared core is a deliverable observation, not a change.
