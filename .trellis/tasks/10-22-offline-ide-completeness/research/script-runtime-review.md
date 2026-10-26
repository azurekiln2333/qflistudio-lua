# Script runtime implementation and review — 2026-10-22

Owner: runtime_review. Root explicitly authorized implementing a genuine offline
JS/TS backend after the earlier Lua runtime/debugger review. No shared-core,
Explorer/history, sibling, runner/profile/pubspec or Lua bridge edits in this batch.
Root integrates those paths and owns platform packaging/commits.

## Delivered

- `native/script/**`: real retained QuickJS 2026-06-04, license/archive/hashes,
  compile-only import-resolution patch, bounded native bridge, module snapshot
  loader, console, Promise jobs/rejection/pending handling, timeout/cancellation,
  syntax diagnostics and documented C ABI. Added only the Script subdirectory
  to `native/CMakeLists.txt`.
- `assets/runtime/**`: official Microsoft TypeScript 5.9.3 compiler, provenance,
  Apache-2 license and third-party notices. User TS is an argument to the trusted
  compiler, never evaluated during a syntax check.
- `lib/script_toolchain.dart`: fresh native operation in worker isolate, bounded
  root-owned saved project snapshots, asset compiler load, exact byte decoding,
  lifecycle-safe cancellation including preparation, actual transpilation/run.
- `lib/script_code_analyzer.dart`: frozen shared API, exact unsaved text/revision,
  absolute root ownership, language/extension/duplicate/size checks, UTF-16
  diagnostics and honest unavailable failures. No user execution, source writes,
  filesystem reads or network in analysis.
- Focused tests: `test/script_toolchain_test.dart` (16) and
  `test/script_code_analyzer_test.dart` (10).

## Findings fixed

- Imported TS syntax diagnostics now carry `filePath` and are range-validated
  against their original file, avoiding false invalid-main-range failures.
- TS syntax checks return original-source compiler diagnostics without compiling
  emitted JS into misleading original TS underlines.
- TS syntax errors preserve nonempty stderr for runtime/terminal consumers.
- Native library startup failure returns status 127 from `startRun`, including
  the synchronous load failure, instead of escaping without a result.
- Preparation cancellation is checked after asynchronous directory/file/compiler
  operations and reports 130; tokens remain alive until the worker completes.
- TypeScript's default `checkSource` filename is `editor.ts`; otherwise the
  official compiler correctly rejects type annotations in `editor.js`.
- Compiler loading uses bundled Flutter assets, never an implicit cwd compiler.
- Uppercase `.TS` module extensions receive the genuine TS compiler.
- Pending-async diagnostic preserves its final character; duplicate captures of
  the same runtime exception are suppressed without hiding failing status.
- Local C misleading indentation and Dart brace lints fixed.

## Verification

- Modern-GCC native Release target rebuild: PASS. Actual compiler GNU 16.2.0.
- Strict bridge syntax check: PASS (`-std=c11 -Wall -Wextra -Werror
  -fsyntax-only -isystem native/script/quickjs native/script/qfli_script.c`).
  The vendored header is a system include so its intentional unused inline
  parameters do not obscure adapter warnings; upstream sources are unchanged.
- Native real-library Python probes: **22/22 PASS**. Includes genuine JS closures,
  TS interface/enum/generic lowering, JS/TS modules and dependency locations,
  unresolved/remote imports, no-execution checks, semantic-check limitation,
  async success/rejection/pending, Unicode/NUL, CRLF/UTF16 positions and timeout.
- Focused Flutter tests: **26/26 PASS** using the actual modern-GCC DLL,
  `flutter_tools.snapshot test --no-pub --concurrency=1` on the two new tests.
  Tests ran only after lua_review explicitly released the memory window; window
  returned to root immediately afterward. Cancellation/recovery, output bound,
  missing compiler/library and forged diagnostic results are covered.
- Scoped Dart analyze on both implementation and test files: **No issues found**.
- Format: all four Dart files formatted.
- DLL export/import inspection: six expected public bridge functions, only
  KERNEL32/UCRT system DLL imports (no extra MinGW/pthread distribution DLL).
- DLL artifact: `native/build/script-windows/script/libqfli_script.dll`.
  SHA256 `2e50491c136164c1fa81458a2978430722dcfcd72bde59820b1464a1463846b6`.
- TypeScript compiler SHA256:
  `3ae902c92cc44dace175c0e69e13a4b0899f6983c6121d76b9ab8dd5795e7675`.

## Remaining integration / boundaries (not claimed as passed)

- Root owns combined Lua/JS/TS analyzer routing, runner/terminal/tools/profile,
  Flutter asset declarations and Windows/Linux imported/install targets.
- MSVC/legacy GCC creates no Script target and prints a prerequisite warning;
  root is adding a modern-GCC imported DLL/prerequisite so Windows packaging
  cannot silently omit the Script engine. Runtime absence remains honest 127.
- OHOS build/package/export/ARM64 checks, all-catalog execution and target runs
  are root gates. A host DLL test is not target execution evidence. No phone is
  available in the recorded environment. Apple source/bundling remains unverified.
- The engine offers ECMAScript, not Node/browser APIs. Module extensions are
  explicit; no Node resolution, package manager, filesystem JS APIs or timers.
- TypeScript syntax/options only; no semantic project type checking. Source
  diagnostics intentionally label the provider `TypeScript syntax`.
- Recommend root add `.trellis/spec/backend/script-toolchain.md` plus backend
  index entry from `native/script/README.md`: ABI lengths/token lifetime,
  compile-only no-execution/import invariant, original TS offsets, honest127,
  trusted asset compiler, GCC9+/Clang requirement and separate host/target gates.
  Left shared spec/index ownership to root instead of editing unclaimed files.
