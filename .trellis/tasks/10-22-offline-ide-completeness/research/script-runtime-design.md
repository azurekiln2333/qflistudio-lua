# Offline Script runtime design (2026-10-22)

Root authorizes a genuine offline JS/TS backend for the offered Script language types. Ownership: new native/script/**, script_toolchain.dart, script_code_analyzer.dart, focused tests and assets/runtime/**; native/CMakeLists.txt only for the new target. Root owns runner/profile/terminal/pubspec/platform wiring. No Lua bridge/core/sibling writes.

## Engines, provenance, contracts

Copy QuickJS official2026-06-04 retained sources from qfli_web/vendor/quickjs with its MIT license, source/hash manifest and explicitly documented compile-only-no-module-resolution patch. The patch is needed so syntax analysis never resolves or reads imports. Product adapter is new code; do not share sibling source ownership. Add qfli_script_engine / libqfli_script using GCC9+/Clang (old GCC4.9 is documented by the upstream-owning product as miscompiling module atoms). Compile on Windows in a separate modern-GCC build directory and on OHOS with its Clang toolchain. Legacy GCC/MSVC Lua-only builds must emit an explicit warning that they cannot build the Script target, preserving Lua's existing target.

TypeScript compiler is official npm Microsoft TypeScript5.9.3, fetched from the official registry, archive SHA1 checked against registry metadata and archive/compiler SHA256 retained. Include Apache2 license and third-party notices. Keep compiler source unmodified; no DevEco fork. Compiler is trusted code, user TS is passed as an argument to transpileModule, never injected into an eval string. Report syntax/options diagnostics; transpileModule does not perform project semantic type checking and must not claim it.

Each operation owns a fresh bounded QuickJS runtime/context. Run executes actual ECMAScript, captures console.log/info/debug to stdout and console.warn/error to stderr, drains actual Promise jobs, retains rejected/pending async failures, enforces memory/stack/output limits and interruption timeout/cancel. No quickjs-libc, subprocess, filesystem JS APIs, browser DOM, Node APIs, timers, fetch or network bindings. Modules resolve from an explicit root-owned snapshot map only; relative ES modules supported, missing/bare/remote modules fail honestly. TS modules are genuinely transpiled by the same compiler before loading. Analysis compiles only; it does not evaluate user chunks, jobs or import loaders. Exact source byte lengths retain embedded NUL. Diagnostics use UTF16 half-open offsets in the exact text/CRLF snapshot.

## Additive product API

`const ScriptToolchain({libraryPath, typescriptCompilerPath})`;
`startRun({file, projectDirectory, timeLimit}) -> ScriptExecution(result,cancel)`;
`run(...) -> Future<ScriptToolResult>`;
`checkSource(source,{fileName,typescript,module})`;
`transpile(source,{fileName})`.
Result has status/output/error/diagnostics; diagnostic fields startOffset/endOffset/message/code/severity. Status0 actual success,3 parsed syntax error,124timeout,130cancel,127backend unavailable. Startup errors are availability failures, never clean parses. Source/compilation limits are explicit. Native token survives preparation+worker completion, with cooperative cancellation atomic across isolates. Root can compose ScriptCodeAnalyzer with LuaCodeAnalyzer by language/extension.

C ABI uses opaque cancellation token and owned result with status, stdout/error/diagnostics byte pointers+size_t lengths. One process function takes source+length, filename, root, documents JSON+length, trusted compiler JS+length, language/action/module flags, timeout and token. No native loader reads source files; the Dart provider supplies normalized root-owned document snapshots. Compile-only module patch suppresses resolution only for checks; actual execution resolves the snapshot modules.

## Gates

Verify standard language constructs rather than corpus-shaped special cases: closures/classes/async/collections/destructuring, Unicode/NUL output, JS syntax exact offsets, TS interfaces/enums/generics/type assertions transpiled, malformed TS diagnosed, ES module dependencies/missing imports/remote denial, no user execution during check, syntax-vs-unavailable, bounded timeout/cancel and recovery. Run focused real-library tests when root grants the memory window. Root audits every catalog entry and OHOS cross-build/package/device proof separately.
