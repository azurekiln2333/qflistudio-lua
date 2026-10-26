# Product highlighting review

Date: 2026-10-23. Task: `10-22-offline-ide-completeness`, R8.

## Boundary and current result

The missing product evidence was a test connecting the actual `luaProfile`
extension list to the shared editor's selected grammar and real tokenization.
The implementation already selects the required grammars. This change adds
product tests; it does not change shared core, the profile, grammars, or editor
behavior. Source inspection found no missing grammar among the five declared
text extensions. Execution of the new tests remains pending the root's explicit
host slot.

Files owned for this delivery:

- `test/product_highlighting_test.dart`: new product coverage.
- This report.
- `tools/build_ohos_audit.ps1`: separately granted one-line default-target change
  from `bin/lua_catalog_audit.dart` to `bin/script_acceptance.dart`. The existing
  `-Target bin/lua_catalog_audit.dart` override remains available. This edit does
  not produce a new package or prove the 1282-case target gate.

## Production path inspected

Shared core HEAD at inspection:
`e025805b60435fdedafd33e60082dc660afebe5a`; the shared worktree also contains
coordinated changes, so the source paths below identify the inspected behavior.

- `lib/main.dart:44` declares exactly `.lua`, `.luac`, `.js`, `.mjs`, `.ts`, `.sh`.
- `../qfli_studio_core/lib/editor/editor_page.dart:2988` calls
  `HighlightThemes.themeFor(context, open.name, null, settings: ...)` and passes
  the result to `CodeEditorStyle.codeTheme`.
- `../qfli_studio_core/lib/editor/highlight_themes.dart:54` holds the built-in
  extension selection. `themeFor` at line 200 lowercases the extracted extension
  before selecting the grammar and registers its actual `Mode` objects.
- `../qfli_studio_core/lib/editor/editor_controller.dart:71` rejects binary
  bytes before creating an editable `OpenFile`. `_looksBinary` at line 279
  checks for NUL among the first 8192 bytes. The Lua 5.4 binary header includes
  that marker; the test supplies a header fixture without claiming it is a
  complete compiled chunk.

| Declared extension | Built-in language | Cases added |
| --- | --- | --- |
| `.lua` | `lua` | `.lua`, `.Lua`, `.LUA` |
| `.js` | `javascript` | `.js`, `.Js`, `.JS` |
| `.mjs` | `javascript` | `.mjs`, `.Mjs`, `.MJS` |
| `.ts` | `typescript` | `.ts`, `.Ts`, `.TS` |
| `.sh` | `bash` | `.sh`, `.Sh`, `.SH` |
| `.luac` | No text grammar | `.luac`, `.Luac`, `.LUAC`; binary open rejected |

## Assertions added

The new file defines 18 tests: one complete profile-extension inventory test,
15 text extension/case tests, one no-grammar bytecode test, and one actual
binary-file editor-boundary test covering all three bytecode case variants.

Each text case calls the production `HighlightThemes.themeFor` with the same
null-content form used by `EditorPage`, registers the returned modes with the
real `re_highlight` tokenizer, and checks the resulting scoped tokens. It does
not construct a replacement extension selector or import its own grammars.
Representative language features include Lua long-bracket strings, JavaScript
module exports, TypeScript interfaces, and Shell built-ins/variables. Every
sample includes a comment, a string, Unicode including a surrogate pair, and
CRLF; reconstructed rendered text must equal the original source exactly.
The default theme must also provide keyword, string, and comment colors.

The binary test uses `EditorController.openPath` on real temporary files,
requires an explicit rejection, requires no editable tab, and verifies unchanged
bytes. Runnable bytecode support is covered elsewhere; this file makes no
bytecode execution claim.

`re_highlight` is core's existing transitive dependency and is not a direct
product dependency. Its test import has one documented
`depend_on_referenced_packages` suppression so this scoped evidence does not
change the product manifest. The tokenizer and selected modes are the same
implementation used by the editor.

## Checks and remaining gates

- Read current profile, shared selector/editor path, installed Lua/Bash grammar
  sources, existing core token-renderer tests, and product test conventions.
- `git diff --no-index --check -- /dev/null test/product_highlighting_test.dart`
  reported no whitespace errors. Exit 1 represents the new-file diff; Git also
  emitted the repository's expected LF-to-CRLF notice.
- PowerShell AST parse of `tools/build_ohos_audit.ps1` passed. The script was not
  executed.
- No Dart formatter/analyzer, Flutter test, pub, native build, HAP build, or
  device process was launched under this source/static-only assignment.

After host authorization, run the new file with `flutter test --no-pub
--concurrency=1 test/product_highlighting_test.dart`, then include it in the root
analysis/full-suite gate. Until those complete, R8 has added executable coverage
and inspected source evidence, not a new passing test or target UI claim.
