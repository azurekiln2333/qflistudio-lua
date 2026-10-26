# Lua terminal and debugger boundary

The existing sandbox terminal offers a product-owned command delegate but Lua
does not supply one. Implement the delegate in `lib/lua_terminal_commands.dart`,
using the real bundled Lua library, `SandboxShellBackend.runStreams`, its path
resolver and its command parser. Root owns the profile wiring. Preserve the
existing runner and native stdin changes.

The native bridge currently creates only `arg[0]`. Add
`qfli_lua_run_with_args(file, project_dir, timeout_ms, token, argc, argv)` and
keep every existing export intact. Arguments populate both `arg[1..n]` and the
main chunk's varargs. Add `qfli_lua_compile_ex(file, nullable_output, strip)` to
parse source/bytecode without execution or dump a compatible chunk; the
existing check/compile exports retain their text-only behavior. Dart owns
argument buffers until the worker's native call returns.

Supported terminal commands: `lua file [arguments]`, `lua -v`, `lua --help`,
`lua -- file`, `luac -p file...`, `luac [-s] [-o output] file`, and compiler
version/help. Explicitly reject interactive stdin, -e/-l/-i, bytecode listings,
multiple-file linking, shell expansion and piping. No subprocess or network
service is introduced. stdin is the current directory's input.txt and modules
resolve relative to that directory, as with the existing embedded runner.

## Real debugger proposal for root review

The bundled Lua 5.4.8 VM exposes line/call/return/count hooks and stack/local
inspection. The current bridge only uses a count hook for cancellation and
timeouts; it has no suspended VM, debugger transport, breakpoint store or
inspection protocol. Product UI cannot truthfully offer step/breakpoints yet.

An additive implementation can use an opaque `QfliLuaDebugSession` owned until
the worker finishes, with all VM access confined to the worker thread:

```c
QfliLuaDebugSession *qfli_lua_debug_new(void);
int qfli_lua_debug_breakpoints(QfliLuaDebugSession *, const char *json);
void qfli_lua_debug_command(QfliLuaDebugSession *, int command);
char *qfli_lua_debug_poll(QfliLuaDebugSession *); /* owned JSON event or NULL */
QfliLuaResult *qfli_lua_debug_run(QfliLuaDebugSession *, const char *file,
    const char *project_dir, int timeout_ms, int argc, const char *const *argv);
void qfli_lua_debug_string_free(char *);
void qfli_lua_debug_free(QfliLuaDebugSession *);
```

Commands: pause, continue, stepInto, stepOver, stepOut, stop. Breakpoints are
canonical project-local source paths plus positive 1-based lines. Events carry
session/revision IDs and running/paused/terminated state; paused events include
source/line, bounded call frames and primitive local/upvalue values. The VM
hook checks pending commands and blocks on a native condition variable only
when paused. Inspect state inside that worker hook, never from Dart's UI
thread. Continue/stop signals wake the condition. Account active execution
time separately so user pause time cannot consume the runtime deadline.

Keep debugger control synchronization separate from Lua allocation and output
locks; never call lua_* through a UI-thread FFI command. Install line/call/
return/count hooks together and track call depth for over/out. Compile with
debug information; stripped bytecode cannot provide reliable source stops.
Native calls, disabled/replaced hooks, finalizers, and caught cancellation
remain cooperative limits. Coroutines require explicit per-thread hook
installation and identity in events. Evaluate expressions only via a separately
approved design because arbitrary evaluation can mutate or resume the program.

Required tests before advertising: real pause before a line executes,
breakpoint removal while paused, nested step in/over/out, coroutine behavior,
stop while paused, error/EOF, stale session events, and native symbol/package
checks on ARM64. No debugger code or decorative controls are added by this
terminal assignment.

## Approved implementation: cooperative source debugger (2026-10-22)

Root explicitly authorized implementation after the runtime review. Use upstream Lua 5.4 coroutine `lua_resume` plus line/count-hook `lua_yield` (zero values, no continuation), rather than a native blocked thread. Upstream `luaG_traceexec` skips the just-yielded hook on resume, so the paused instruction executes once. Vendored Lua stays unchanged.

A `QfliLuaDebugSession` owns one VM, one root coroutine, capture buffers, breakpoints, atomic pause and existing cancellation token. Only a persistent Dart worker isolate creates/resumes/inspects/frees the VM. The UI may call the atomic request-pause/request-stop functions while resume is blocked. The worker keeps the session allocated until explicit dispose, preventing control-pointer races. Each resume starts a new elapsed-time interval; deduct execution only, excluding paused time.

Additive C API: debug_new(file,project,timeout); debug_resume(action: continue/into/over/out); debug_pause; debug_stop; debug_set_breakpoints(paths,lines,count); debug_state (ready/paused/terminated), debug_output (owned QfliLuaResult), debug_frame and debug_local (borrowed primitive metadata copied immediately on worker), debug_free. Existing exports retain signatures and behavior. Bound frames to64 and locals/frame to128. Local inspection uses only lua_type/lua_tolstring on strings and primitive conversion; never __tostring or evaluation.

Initial resume steps to the first source line before it executes. Breakpoints compare complete normalized absolute source paths and positive lines; line events at matching stack depths implement step into/over/out. Tail calls follow the VM's actual available frames. Main entry must be a `.lua` text file inside its owning project; binary main chunks are rejected. Breakpoints only apply to actual source locations, and stripped/dynamically generated bytecode may lack line information. User coroutine create/resume/wrap/yield and replacement of the debug hook are explicitly rejected in debugger mode; normal Run still supports them. Native I/O/C calls/finalizers remain cooperative limits. No expression evaluation, networking, decorative controls or shared core edits.

Dart surface: `LuaDebugger.start(file:,projectDirectory:,libraryPath:,timeLimit:)`, `updates`, `snapshot`, `resume(LuaDebugAction)`, `setBreakpoints`, `pause`, `stop`, `dispose`. LuaDebuggerPage(store: store) selects saved project source; optional projectPath/initialFile supports a direct owned project. Page shows source lines/real breakpoint controls, current line, stack, primitive locals, output, status and explicit limits. Root owns adding its individual Tools card.

Verification: real-library tests stop before source side effects; exact locals/stack; into/over/out; breakpoint removal; pause/stop of a running infinite loop; stop while paused; source errors/EOF; active timeout excludes pause; unsupported coroutine/bytecode; disposal/restart; narrow page control tests. Rebuild default DLL and repeat existing terminal/native checks. ARM64/device proof remains a separate root gate.
