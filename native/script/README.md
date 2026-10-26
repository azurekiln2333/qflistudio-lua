# Offline JavaScript / TypeScript engine

`qfli_script_engine` builds `libqfli_script` from retained QuickJS 2026-06-04
sources. It does not include quickjs-libc, a CLI, Node, browser APIs, OS bindings,
timers, network bindings or a filesystem module loader. The Dart adapter supplies
saved project files as an in-memory map; modules must name their extensions.
Missing, bare, remote and outside-project imports fail with a runtime error.
Relative ES modules, cycles, Promise jobs and top-level await use the real VM.

`assets/runtime/typescript.js` is Microsoft's unmodified TypeScript 5.9.3 compiler.
Only trusted compiler code is evaluated during a TypeScript check. User source is
passed as a string argument to `transpileModule`, never inserted into an eval
wrapper. Diagnostics cover syntax/options; semantic/project type checking is not
provided. Runtime TypeScript and its imported `.ts` modules are actually emitted
to JavaScript and executed by QuickJS.

Each operation owns a fresh runtime with a 256 MiB heap limit, 2 MiB stack limit,
512 KiB input-source limit and 1 MiB limit for each output stream. Runs enforce a
timeout and a cooperative atomic cancellation token; the Dart token survives all
snapshot preparation and the worker operation. Console log/info/debug write
stdout, warn/error write stderr, using JavaScript string conversion. Output and
source use explicit UTF-8 byte lengths, retaining embedded NUL characters.

Checks never execute user chunks or Promise jobs or load imports. The retained
QuickJS compile-only patch suppresses import resolution only for compile-only
evaluation; running modules still resolves and executes dependencies. JavaScript
engine line/column locations are mapped to exact original UTF-16 offsets.
TypeScript diagnostic offsets come from the original source, never emitted JS.
Diagnostics include their source file path, including imported TS modules.

## Build

GCC 9+ or Clang is required. GCC 4.9 miscompiles QuickJS module atoms; the adapter
explicitly rejects it. The native-only legacy GCC/MSVC configuration prints an
actionable warning and produces no Script target, allowing the existing Lua
target to build. A Windows app must import a separately built modern-GCC DLL
or fail its packaging prerequisite; it must not advertise a bundled Script
runtime when that DLL is absent. A missing runtime/compiler is status 127,
never a successful empty syntax result.

Build a separate Windows tree with a modern compiler:

```text
cmake -S native -B native/build/script-windows -G Ninja \
  -DCMAKE_C_COMPILER=<modern-gcc> -DCMAKE_MAKE_PROGRAM=<ninja> \
  -DCMAKE_BUILD_TYPE=Release
cmake --build native/build/script-windows --target qfli_script_engine --parallel 2
python native/script/test_native.py
```

The DLL is `native/build/script-windows/script/libqfli_script.dll`. Windows
links its GCC/pthread support statically; the verified DLL imports only Windows
system KERNEL32/UCRT libraries. Android/OHOS use the same target and sources;
their package, ELF/export checks and target execution are separate gates.
Apple compilation/bundling is not established by the Windows evidence.

`lib/script_toolchain.dart` loads the TypeScript compiler through Flutter assets.
Tests/CLI probes can explicitly supply `typescriptCompilerPath`; production
does not trust a compiler from the process's current directory. Project scanning
skips links, `.git`, `.qfli`, `node_modules` and `build`, with bounds of 256 source
files, 8 MiB and 16384 directory entries. `.js`, `.mjs` and `.ts` are supported.

## ABI and status

`qfli_script_process` accepts source + byte length, filename, project path,
documents JSON + byte length, trusted compiler source + byte length, language,
action, module flag, timeout and optional token. Language is 0 JS / 1 TS; action
is 0 run / 1 check / 2 transpile. Transpile output is emitted JavaScript.
`QfliScriptResult` owns status and output/error/diagnostics pointers followed by
their `size_t` byte lengths; `qfli_script_free` releases it exactly once.

Statuses: 0 actual success, 1 runtime failure, 3 source syntax error, 124 timeout,
127 backend/preparation unavailable, 130 cancellation. Diagnostics contain
`filePath`, half-open UTF-16 `startOffset`/`endOffset`, `message`, `code` and TS
`severity` category (0 warning, 1 error, 2 suggestion, 3 message).

## Provenance and licenses

QuickJS is MIT licensed: `quickjs/LICENSE`, original archive and `SOURCE.json`
are retained. `HASHES.sha256` records build inputs, license, original archive and
the explicit patch; CMake verifies all hashes before building. These sources were
copied from the sibling Web product's retained release, with no additional
upstream source edits.

TypeScript is Apache-2.0 licensed. Its official npm archive SHA1 was verified
against registry metadata; archive/compiler SHA256 and source URL are retained
in `assets/runtime/TYPESCRIPT-SOURCE.json`, alongside the unmodified compiler,
license and third-party notices.
