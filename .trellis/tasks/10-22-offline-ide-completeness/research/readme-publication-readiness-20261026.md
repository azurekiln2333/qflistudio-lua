# README publication readiness — 2026-10-26

Scope: release check of the three root READMEs against the source candidate
`build/offline-ide-audit/source-candidate-20261025T204929599078Z/`, plus the
root-released English parity repair recorded in section 3a.
Method: `git cat-file`/`git ls-files -s` reads of HEAD and the candidate index,
worktree byte hashes, `git hash-object --path` checkout-filter hashing, and static
comparison of README claims with candidate blobs. No SDK, tests, build, device,
network or Git-write operation ran.
Writes were limited to `README.md` (section 3a) and this file.

## 1. Candidate identity and coverage

| Field | Value |
| --- | --- |
| manifest createdAt | 2026-10-25T20:49:30.463145+00:00 (=2026-10-26 04:49:30, UTC+8) |
| head | 327b7c54d04bc184e03171f52da942c2157083b1 |
| candidateTree | e8745d672ab60289455128722c6484c0e7bcc9b5 |
| candidateIndex | `.../source-candidate-20261025T204929599078Z/index` (497 entries) |
| actualIndexUnchanged | true |
| manifest paths | 207 |
| verification field | "SOURCE REVIEW CANDIDATE ONLY; final tests/build/device/push remain open" |

The superseded candidate `source-candidate-20261025T185636541761Z` had tree
`68c9944b` and 203 paths. The current candidate adds 4 paths and removes none:

- `.trellis/tasks/10-22-offline-ide-completeness/research/readme-publication-readiness-20261026.md`
- `.trellis/tasks/10-22-offline-ide-completeness/research/readme-pi-final-review-20261026.md`
- `.trellis/tasks/10-22-offline-ide-completeness/research/audit-export-ui-status-review-20261026.md`
- `.trellis/tasks/10-22-offline-ide-completeness/research/lua-full-scope-source-check-20261026.md`

## 2. The candidate contains the three READMEs and the Chinese lint script

Confirmed twice: the manifest path list and the candidate Git index.

| Path | Manifest candidateBlob | Candidate index blob | Worktree sha256 (16) |
| --- | --- | --- | --- |
| `README.md` | `49bbed31b42ff2a2212ecdb7e109ad410e8f25a0` | `49bbed31b42ff2a2212ecdb7e109ad410e8f25a0` | `2a8dc08238403dbb` |
| `README.zh-CN.md` | `aee5a5173a775b12a883b71e344ec80d3c6ca197` | `aee5a5173a775b12a883b71e344ec80d3c6ca197` | `e069cc03075da6b3` |
| `README.zh-TW.md` | `34b8c6c40ae8a98dc7c0fdb30f62aa2fa0769136` | `34b8c6c40ae8a98dc7c0fdb30f62aa2fa0769136` | `189eb3b5b99fd6d2` |
| `scripts/ste-lint-zh.py` | `89ae07fb6ac419544dcefc8f3c62c221be632da3` | `89ae07fb6ac419544dcefc8f3c62c221be632da3` | `4571e2c4c1c8d790` |

For all four paths the manifest `candidateBlob` equals the candidate index blob
and equals `git hash-object --path=<path> <path>`, the checkout-filtered hash of
the current worktree file. The binding is exact.

The worktree READMEs use CRLF because `core.autocrlf=true`, while the stored
blobs use LF. A raw byte hash of the worktree file therefore differs from the
blob. Compare with the checkout filter, as above, and not with raw bytes.

## 3. Candidate rebind: current snapshot binds exactly

The current candidate `20261025T204929599078Z` matches the worktree for all three
READMEs and for the linter. Section 2 records the matching blobs. The earlier
staleness finding is closed.

| File | superseded candidate worktreeSha256 (16) | current worktree (16) | current candidate |
| --- | --- | --- | --- |
| `README.md` | `ef3cdaeb137d00b9` | `2a8dc08238403dbb` | matches |
| `README.zh-CN.md` | `d1155d22ac784807` | `e069cc03075da6b3` | matches |
| `README.zh-TW.md` | `2e2a8a7f7ea7da1e` | `189eb3b5b99fd6d2` | matches |

Superseded history, kept for provenance only. The old candidate took its
snapshot at 02:56:37, before three later README edits:

- 02:58:37: the compiler-path note in all three files.
- 03:59:55: p7 rewrote both Chinese files with the same `682`/`600` split.
- 04:00:15: this worker's English parity repair (section 3a).

Those edits are now inside the current candidate. The prior review
`readme-final-review-20261026.md` still records `ef3cdaeb`/`d1155d22`/`2e2a8a7f`.
Those values are historical, not current. Do not use them to stage files.

## 3a. English parity repair (2026-10-26, this check)

Root released the English README to this worker. The repair changed only the
audit paragraph and one Acceptance-limits sentence. No Chinese, core, source or
other file was touched. New `README.md` worktree sha256:
`2a8dc08238403dbbd7ae746fb7ffcfd8d8ae649f73c6fa58d3c50a603b607e60`.

Corrected facts, with primary evidence:

- The full `1,282` audit is `682 Lua` plus `600 JavaScript/TypeScript/Shell`
  locations. `.trellis/spec/backend/script-toolchain.md` section 6 states the
  exact split: "682 Lua and 600 JavaScript/TypeScript/Shell, with no code
  deduplication".
- `bin/script_acceptance.dart` fixes the denominator at
  `scriptAcceptanceExpectedLocations = 1282`, holds
  `_scriptLanguages = ['javascript', 'typescript', 'shell']`, and composes the
  Lua run through `lua_audit.auditBundledLuaCatalog`. Its phases are `lua682`
  and `script600` (`682 + done`), and its gate reads `luaRows.length == 682`
  and `inventory.cases.length == 600`.
- `ScriptAcceptanceInventory` owns only the `600` Script locations
  ("Script locations: expected600"). `runScriptAcceptance` composes Lua and Script.
- `bin/lua_catalog_audit.dart` is an explicit Lua-only target for the 682 Lua
  locations.

Wording decisions kept:

- The English names all four languages and the exact `682 + 600` split. It never
  describes `1,282` as JavaScript/TypeScript/Shell only.
- Both audit entries import Flutter material. The README shows
  `flutter run -t bin/script_acceptance.dart` and
  `flutter run -t bin/lua_catalog_audit.dart`, and states that `dart run` cannot
  start either.
- `may` confidence is preserved (blocking native call, mobile shell).
- The dated `October 24, 2026` `345` host pass, the failed forced-cleanup
  containment gate and the pending current-source gate stay as written.
- "A full target acceptance still needs a fresh run slot." now matches the
  Chinese wording that a fresh run window is pending.

Cross-language parity after both repairs, verified by grep:

- `README.zh-CN.md` line 153 states the `682 Lua` and `600 JS/TS/Shell` split.
- `README.zh-TW.md` line 153 states the same split.
- `README.md` line 162: "It runs 682 Lua locations and 600 JavaScript, TypeScript
  and Shell locations."
- All three keep the dated `345` host pass, the forced-cleanup failure and the
  pending fresh target slot. All three show both `flutter run -t` entries.

## 4. README link targets

Local Markdown links across the three READMEs, and their status at HEAD.

| Link target | In HEAD | In candidate | Note |
| --- | --- | --- | --- |
| `README.md` | yes | yes | self/cross link |
| `README.zh-CN.md` | no | yes | new file |
| `README.zh-TW.md` | no | yes | new file |
| `native/README.md` | yes | yes | resolves; HEAD content differs (see 6) |
| `.trellis/tasks/10-01-native-platforms/verification.md` | yes | no | already published |
| `tools/build_ohos_audit.ps1` | no | yes | untracked today |

`ohos/local.properties` also appears in the READMEs. It is gitignored
(`ohos/.gitignore:3:/local.properties`) and stays a machine-local file. Correct
for prose use; it is not a publication link.

## 5. README-dependent files that are not published at HEAD

"Unpublished" = absent from HEAD, present in the working tree and in the
candidate. These are the source files the READMEs' commands, links, counts and
license claims depend on.

Commands, audits and scripts:

- `tool/verify_lua_content.dart`
- `bin/script_acceptance.dart` (the full packaged 1,282 audit)
- `bin/lua_catalog_audit.dart` (the 682 Lua subset)
- `bin/script_report_export.dart`
- `native/script/test_native.py`
- `native/script/CMakeLists.txt`
- `native/script/qfli_script.c`, `native/script/qfli_script.h`
- `scripts/ste-lint-zh.py`
- `tools/build_ohos_audit.ps1`, `tools/inspect_lua_hap.py`, `tools/lua_stdin_smoke.dart`
- `tool/generate_lua_content.dart`, `tool/lua_content/*` (24 topic files)

Nine-tool, terminal, debugger, analyzer and content code:

- `lib/lua_code_analyzer.dart`, `lib/lua_content_repository.dart`
- `lib/lua_debugger.dart`, `lib/lua_debugger_page.dart`
- `lib/lua_studio_debugger.dart`
- `lib/lua_terminal_commands.dart`
- `lib/lua_tools.dart`, `lib/lua_tools_page.dart`
- `lib/product_code_analyzer.dart`
- `lib/script_code_analyzer.dart`, `lib/script_toolchain.dart`, `lib/script_tools_page.dart`
- `lib/shell_code_analyzer.dart`

Content and license assets:

- `assets/content/lua_examples.json` (240 entries), `assets/content/lua_tutorials.json` (23 entries)
- `assets/runtime/typescript.js`, `assets/runtime/TYPESCRIPT-LICENSE.txt`
- `assets/runtime/TYPESCRIPT-SOURCE.json`, `assets/runtime/TYPESCRIPT-ThirdPartyNoticeText.txt`
- `native/script/quickjs/LICENSE`, `native/script/quickjs/SOURCE.json`, `native/script/quickjs/*`

Also uncommitted today: the modified tracked `lib/main.dart`, `pubspec.yaml`,
`native/CMakeLists.txt`, `native/src/qfli_lua.c`, `native/windows` CMake files,
`test/lua_app_test.dart`, and the untracked `.gitattributes`. The working tree
holds 63 untracked entries and 26 modified tracked files.

Every one of these paths is covered by HEAD plus the candidate. Rechecked against
the current candidate (`e8745d67`, 207 paths): no dependency path is missing from
both. The candidate is complete for a full-source push.

## 6. Verdict: a docs-only push to main is not safe

A docs-only push would add `README.zh-CN.md` and `README.zh-TW.md` and update
`README.md`. `scripts/ste-lint-zh.py` and the arbitrary source are left out.

Missing link:

- `tools/build_ohos_audit.ps1` stays untracked, so the `README.md` link
  `[...](tools/build_ohos_audit.ps1)` returns 404 on `main`.

Commands that would fail on `main`:

- `dart run tool/verify_lua_content.dart` — file absent at HEAD.
- `flutter run -t bin/script_acceptance.dart` — file absent at HEAD.
- `bin/lua_catalog_audit.dart` — file absent at HEAD.
- `python native/script/test_native.py` and the `qfli_script_engine` target — absent.
- The Lua host build path is present, so `native/CMakeLists.txt` still builds the
  Lua bridge only.

Fact and code inconsistency at HEAD. The READMEs describe behavior that the
published tree does not contain:

| README claim | HEAD reality |
| --- | --- |
| nine individual tools | `HEAD:lib/main.dart` has no `toolsTabBuilder`; `runtimeKind: 'lua-5.4-native'` |
| terminal accepts `lua`/`luac` | `HEAD:lib/main.dart` has no `terminalCommandDelegate` |
| 240 examples, 23 tutorials | `HEAD:pubspec.yaml` lists only `assets/app_icon.png`; `assets/content/` absent |
| Lua debugger with stepping | `HEAD:lib/main.dart` has no `debugger` factory |
| packaged QuickJS/TypeScript and Script limits | `HEAD` tree has no `native/script/` entry |
| editor diagnostics and Problems navigation | `HEAD:lib/main.dart` has no `codeAnalyzer` |
| QuickJS and TypeScript licenses | `native/script/quickjs/LICENSE` and `assets/runtime/TYPESCRIPT-LICENSE.txt` absent |
| "Build details are in native/README.md" | `HEAD:native/README.md` has no QuickJS or Script engine section |

So a docs-only push yields one broken link, several failing commands and a
README that contradicts the published source. It would also strand the two new
Chinese files as the only documentation of features that do not exist on `main`.

## 7. Verdict: the current candidate matches the READMEs

Static checks of the README claims against the candidate blobs all pass:

| README claim | Candidate evidence |
| --- | --- |
| nine individual tools, no gateway card | `lib/lua_tools_page.dart` has 9 `ToolDefinition(` and the no-gateway note |
| Tools tab, terminal, content, debugger wiring | `lib/main.dart` has `toolsTabBuilder`, `terminalCommandDelegate`, `contentRepositoryFactory`, `debugger`, `isOffline: true` |
| 240 examples, 23 tutorials | `assets/content/*.json` `entries` = 240 and 23 |
| QuickJS 256 MiB heap, 2 MiB stack | `native/script/qfli_script.c` `JS_SetMemoryLimit`/`JS_SetMaxStackSize` |
| Lua 1 MiB per stream | `native/src/qfli_lua.c` `MAX_OUTPUT` |
| full audit vs Lua subset | `bin/script_acceptance.dart` "Full packaged Script acceptance" (`682 Lua` + `600` Script); `bin/lua_catalog_audit.dart` "Standalone audit application" (Lua-only `682`) |
| `assets/content/` and `assets/runtime/` bundled | `pubspec.yaml` lists both |

The current candidate is a valid full-source set, and its README/linter blobs now
bind exactly to the worktree. One condition remains before a standard commit and
push:

1. Run the complete current-source verification, which the manifest itself leaves
   open. Acceptance stays open regardless: the forced-cleanup failure, the
   un-rerun 1,282 audit and the absent OHOS target are unchanged.

Do not ship the READMEs alone. Section 6 still holds.

## 8. Caveats and not-found

- This review wrote no source, index or script byte and made no commit or push.
  The only content write is the root-released English repair in section 3a.
- The comparison used the HEAD tree and the candidate index only. No remote ref
  was queried, so remote `main` content is not asserted here.
- The candidate manifest's own `verification` field stays authoritative: tests,
  build, device and push are open. Do not read this file as an acceptance.
- `.trellis/tasks/10-01-native-platforms/verification.md` is already on `main`,
  so its README link resolves. Its Android-package content is dated evidence,
  not current-source proof.
- No README claim was validated by execution. Counts, wiring and limits were read
  from bytes only.

## 9. Primary files read

- `build/offline-ide-audit/source-candidate-20261025T204929599078Z/manifest.json`
- `build/offline-ide-audit/source-candidate-20261025T204929599078Z/index`
- `build/offline-ide-audit/source-candidate-20261025T185636541761Z/manifest.json` (superseded)
- `README.md`, `README.zh-CN.md`, `README.zh-TW.md`
- `.trellis/tasks/10-22-offline-ide-completeness/research/readme-final-review-20261026.md`
- HEAD blobs: `lib/main.dart`, `pubspec.yaml`, `native/README.md`, `lib/lua_editor_tools.dart`
- Candidate blobs listed in sections 5 and 7
- `ohos/.gitignore` (for the `local.properties` rule)
- `.trellis/spec/backend/script-toolchain.md` section 6 (the `682`/`600` split)
- `bin/script_acceptance.dart`, `bin/lua_catalog_audit.dart` (audit denominators)

## 10. Root next actions

1. The current candidate `e8745d672ab60289455128722c6484c0e7bcc9b5` already binds
the three READMEs and `scripts/ste-lint-zh.py` exactly. Rebind is complete; a new
candidate is needed only if a README or linter byte changes again.
2. Include the README dependencies from section 5 in the same scoped candidate.
   Never publish the READMEs alone.
3. Run the remaining current-source gates, then stage and review the exact file
   list, commit conventionally and push without force.
4. Leave R1-R13 active. The 1,282 acceptance, the OHOS device run and the
   Apple/Script packaging evidence remain open.