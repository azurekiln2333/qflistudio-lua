# peer-review-p5 — Lua offline tools (read-only handover)

Author: p5 (Lua offline tools worker). Status: **stopped writing source/tests**; this file is my
only write. Native worker owns completion of the existing implementation below.

## 1. Files I own and their current state

| Path | Size | Role |
|---|---|---|
| `lib/lua_tools.dart` | 59,333 B | logic: syntax check, bytecode parse, module resolution, literal codec, pattern runner, file controller, `buildLuaToolsTab` |
| `lib/lua_tools_page.dart` | 33,791 B | 5 tool pages + shared project/file picker |
| `test/lua_tools_test.dart` | 18,893 B | 29 logic/native tests — **29/29 pass** |
| `test/lua_tools_page_test.dart` | 11,693 B | 9 widget tests — **7/9 pass, 2 test-side failures (section 4)** |

Nothing else was modified by me. `lib/main.dart`, `pubspec.yaml`, shared core, native sources and
git index are untouched by me; no commits.

Untracked in `git status`: `lib/lua_tools.dart`, `lib/lua_tools_page.dart`,
`test/lua_tools_test.dart`, `test/lua_tools_page_test.dart` (all `??`).

## 2. Integration API (already wired by root)

`lib/main.dart` line 19 imports `lua_tools.dart` and line 46 sets:

```dart
toolsTabBuilder: buildLuaToolsTab,   // StudioProfile.toolsTabBuilder
```

Signature (matches `Widget Function(ProjectStore, VoidCallback)?`):

```dart
Widget buildLuaToolsTab(ProjectStore store, VoidCallback onOpenTerminal);
```

It returns a single `ToolsGrid(onOpenTerminal: ..., sections: [ToolSection(title: 'Lua', ...)])`
with **five individual `ToolDefinition` cards** — no gateway card, no nested `Scaffold`, no nested
tab. Tool pages are pushed by `ToolsGrid` and use `ToolScaffold` (one `Scaffold` + `AppBar`) from
`qfli_studio_core/widgets/tool_widgets.dart`.

Page constructors (all in `lua_tools_page.dart`):

```dart
LuaSyntaxCheckPage({required ProjectStore store, LuaToolchain toolchain})
LuaBytecodePage({required ProjectStore store, LuaToolchain toolchain})
LuaModuleResolverPage({required ProjectStore store, LuaToolchain toolchain})
LuaLiteralPage()
LuaPatternPage({LuaToolchain toolchain})
```

Reusable API in `lua_tools.dart`:

```dart
// syntax
LuaSyntaxReport parseLuaDiagnostic(String diagnostic, {required String file, String? displayFile})
Future<LuaSyntaxReport> checkLuaSource(String source, {String fileName = 'snippet.lua',
    LuaToolchain toolchain, Directory? scratchDirectory})
Future<LuaSyntaxReport> checkLuaFile(String path, {String? relativeTo, LuaToolchain toolchain})

// literals
abstract final class LuaStringLiteral {
  static String encode(String text, {bool escapeNonAscii = false});
  static String encodeLongBracket(String text);
  static LuaLiteralResult decode(String literal);
}

// requires / modules
LuaSourceScan scanLuaSource(String source);              // lexer-based, skips comments+strings
Future<LuaModuleSearch> resolveLuaModules({required String projectDirectory,
    required List<String> modules, LuaToolchain toolchain});   // real package.searchpath
LuaModuleSearch parseModuleSearchOutput(String output);
Future<LuaProjectScan> scanLuaProject({required String projectDirectory,
    LuaToolchain toolchain, int maxFiles = maxProjectFiles});
Future<List<String>> listLuaFiles(String directory, {int maxFiles});
const int maxProjectFiles = 400;

// bytecode
Future<LuaBytecodeChunk> inspectLuaBytecode(String path, {LuaToolchain toolchain});
LuaBytecodeChunk parseLuaBytecode(Uint8List bytes);
class LuaBytecodeFormatException implements Exception

// patterns
LuaPatternExecution startLuaPattern({required String subject, required String pattern,
    String replacement = '', bool plain = false, Duration timeLimit = 5s, LuaToolchain toolchain});
Future<LuaPatternOutcome> runLuaPattern({...});
LuaPatternOutcome parsePatternOutput(String output);

// UI selection state
class LuaProjectFileController extends ChangeNotifier {
  LuaProjectFileController({required ProjectStore store, List<String> extensions});
  List<Project> get projects; Project? get project;
  List<String> get files; String? get file;
  bool get loading; String? get error;
  Future<void> refresh(); void selectProject(String? id); void selectFile(String? path);
  String label(String? path);
}
```

All operations are offline. Nothing logs in, uploads, or spawns a system process; every execution
goes through `LuaToolchain` (bundled Lua 5.4.8) and every scratch file lives in
`Directory.systemTemp` and is deleted in `finally`.

## 3. Commands and actual results (this checkout, 2026-10-22)

```
flutter analyze --no-pub lib/lua_tools.dart lib/lua_tools_page.dart \
    test/lua_tools_test.dart test/lua_tools_page_test.dart
→ No issues found! (2.6 s)

flutter analyze --no-pub lib/main.dart
→ No issues found! (3.1 s)

flutter test --no-pub test/lua_tools_test.dart
→ 00:00 +29: All tests passed!

flutter test --no-pub test/lua_tools_page_test.dart
→ 00:10 +7 -2: Some tests failed.   (see section 4)
```

`dart format` was applied to both lib files and both test files.

Native-backed evidence included in the passing suite (real `libqfli_lua.dll`, no mocks):
- `checkLuaSource` valid/invalid; error line 2 parsed; source line echoed; scratch dir left empty.
- `checkLuaFile` under `中文 项目 (1)/main.lua`.
- `inspectLuaBytecode` header + prototype counts, no leftover `.luac`; compiled chunk re-run gives
  `42\n`; `LuaBytecodeFormatException` for foreign bytes and for a 0x53 version byte.
- `resolveLuaModules` for `util`, `pkg` (`init.lua`), `src/mod.lua` under `中文 模块` + full
  candidate list for a missing module.
- `scanLuaProject`: per-file requires with lines, `nope` unresolved, 1 dynamic require,
  `build/` excluded.
- `runLuaPattern`: 3 matches with captures, `gsub` count 3, invalid pattern, invalid `%9`
  replacement, plain mode with Unicode, 50-match truncation.

## 4. Current failures (both test-side; product code is not implicated)

### F1 — `tools tab opens each tool page from its own card` (`lua_tools_page_test.dart:127`)

```
pumpAndSettle timed out
test/lua_tools_page_test.dart 127:9  (await tester.pumpAndSettle() right after tap)
```

Cause: each of the three store-backed pages calls `unawaited(_files.refresh())` in `initState`;
`LuaProjectFileController.loading` is `true` while the recursive directory listing awaits real I/O,
and `_LuaProjectPicker` then renders `LinearProgressIndicator` (repeating animation). Inside
`testWidgets` fake-async, that listing only finishes through `tester.runAsync`, so
`pumpAndSettle` can never settle. Deterministic — reproduced with `--plain-name` on that test alone.

Suggested fix (test only): replace the two `pumpAndSettle()` calls in that loop with bounded pumps,
e.g. `await tester.pump(); await tester.pump(const Duration(milliseconds: 400));` (route transition
is 300 ms), then assert the `AppBar`, then `pageBack()` + the same bounded pump.

### F2 — `syntax check page reports the real error line and then accepts fixed code` (line 159)

```
Expected: exactly one matching candidate
  Actual: Found 2 widgets with text containing "expected near"
```

The page intentionally shows both the parsed `消息` row (`<name> expected near '='`) and the
`原始输出` row (`...\Temp\qfli_lua_tools_962a2dfe\Lua 项目\broken.lua:2: <name> expected near '='`).
The assertion is too strict.

Suggested fix: `expect(find.textContaining('expected near'), findsWidgets);` (or drop the raw row,
see N2). **Because F2 aborted the test early, the file-switch half (lines 163–169) has never
executed** — that is the main unverified path in this handover.

## 5. Findings the native worker should act on (not fixed by me)

### N1 (important) — host DLL is stale vs the new native source
```
native/src/qfli_lua.c   22,988 B  2026-10-22 11:08
native/src/qfli_lua.h    3,230 B  2026-10-22 11:08
lib/lua_toolchain.dart  13,245 B  2026-10-22 11:13   (modified by terminal worker)
native/build/windows/libqfli_lua.dll 1,033,968 B  2026-10-03 02:00  ← stale
```
`lua_toolchain.dart` now looks up `qfli_lua_run_with_argv`, `qfli_lua_compile_ex`,
`qfli_lua_check_source`, `qfli_lua_copyright`. The DLL on disk predates those. My tools only use
`qfli_lua_run_with_token`, `qfli_lua_check`, `qfli_lua_compile`, `qfli_lua_free`,
`qfli_lua_version`, which is why 29/29 pass — but any argv/compile-script/copyright/`check_source`
path on desktop will fail `lookupFunction` until the DLL is rebuilt. Rebuild before trusting host
runtime evidence; do not treat my passing run as proof for the new symbols.

### N2 (UX/correctness) — raw diagnostic duplicates the parsed message and leaks absolute paths
`checkLuaFile` sets `raw = result.error`, which the page renders verbatim, so the user sees the
absolute project path twice (once as `文件`, once inside `原始输出`). Suggest only showing
`原始输出` when the message could not be parsed (`line == null`), and/or normalising the path.

### N3 (robustness) — `scanLuaProject` silently drops non-UTF-8 `.lua` files
`scanLuaProject` uses `File(path).readAsString()` and skips on `FileSystemException`. Verified
behaviour on Windows/Dart 3.11.5: malformed UTF-8 makes `readAsString` throw
`FileSystemException: Failed to decode data using encoding 'utf-8'` (not `FormatException`), so the
file is skipped and vanishes from the audit without any indication. `checkLuaFile` already does the
right thing. Suggest `utf8.decode(await File(path).readAsBytes(), allowMalformed: true)` plus a
`skipped` counter surfaced in `LuaProjectScan` / the page.

### N4 (dead code, low) — unused members
`LuaPatternOutcome.isMatch` (`lua_tools.dart:1583`), `LuaBytecodeHeader.littleEndian` (set at
`:1326`, never read — the `校验` row reads `integerCheck && numberCheck`), and
`_ByteReader.offset` (`:1448`) have no call sites. Either use them (e.g. show `littleEndian` in the
`校验` row) or delete.

### N5 (verification gap) — unproven paths
- File switching via the picker (F2 above) — never executed.
- Cancellation of a *running* pattern (only "cancel after completion" is tested).
- Timeout path of `startLuaPattern` (the 5 s limit) — not exercised.
- `LuaBytecodePage` "生成 .luac 到项目" button — no test.
- `maxProjectFiles` truncation banner in the resolver page — logic tested via `listLuaFiles`, page
  banner not rendered in any test.
- No OHOS/Android device: all runtime evidence is Windows host only (`hdc`/`adb` empty per task
  baseline), so mobile ABI execution remains unverified.

## 6. Correctness notes for review (verified against upstream sources)

- Bytecode parsing follows Lua 5.4, not 5.3: the chunk header stores only
  `sizeof(Instruction)`, `sizeof(lua_Integer)`, `sizeof(lua_Number)`; `sizeof(int)`=4 and
  `sizeof(size_t)`=8 are implied by the ABI. Counts/positions are **variable-length base-128**
  (`dumpSize` in `ldump.c`), high bit on the last byte — my first fixed-width implementation was
  wrong and is now corrected; verified by round-tripping a real dump and by the 239-byte
  `native/build/windows/hello.luac`.
- `string.gsub` has no plain mode, so the pattern script escapes magic characters with
  `string.gsub(pattern, "%p", "%%%0")` when 纯文本 is on (this was a real bug: `(括号)` was being
  treated as a capture).
- Syntax checking never executes user code (`qfli_lua_check` → `luaL_loadfilex(..., "t")`);
  pasted snippets are written to a temp file, so no project file is touched (tested).
- Module resolution uses the runtime's own `package.searchpath` with the project `package.path`
  that `set_project_path` installs (`?.lua`, `?/init.lua`, `src/?.lua`, `src/?/init.lua`, then the
  runtime defaults), so a hit is exactly what `require` would load. Paths returned by Lua use `/`
  even on Windows; the page normalises them for display only.
- `LuaProjectFileController` guards every async listing with a generation counter and a `_disposed`
  flag, so a slow listing from a previously selected project cannot overwrite the current one, and
  `notifyListeners` is never called after dispose.
