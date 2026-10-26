# Baseline catalog audit — Lua (R1) — Pi p6

Owner: Pi p6 (verification artifacts only).
Generated: 2026-10-22.
Status: **complete for the pre-expansion baseline.** Host evidence only; see
"Device / target gap" for what this does *not* prove.

## Engine identity

| Item | Value |
| --- | --- |
| Runner | `build/offline-ide-audit/lua_baseline_audit.dart` (this task, Pi p6) |
| FFI entry points | `qfli_lua_run` / `qfli_lua_free` / `qfli_lua_version` (same as `lib/lua_toolchain.dart`) |
| Library under test | `native/build/windows/libqfli_lua.dll` |
| Library size / mtime | 1,033,968 bytes, 2026-10-03 02:00:52 |
| Library SHA256 | `3DFEEF048A82F8F093971B4818EE3169B4E39C58BADF4FCC7CB1C9A969006F11` |
| Resolved engine version | `Lua 5.4.8` |
| Host | Windows, Dart 3.11.5 |
| Machine-readable result | `build/offline-ide-audit/lua-baseline-report.json` |

Every entry ran in its own throwaway project directory (`main.lua` + separate
`project_dir`), never in the user project, one fresh Lua state per run.

## Baseline inventory and results

| Item | Count |
| --- | --- |
| `examples.json` Lua entries executed | 100 |
| `tutorials.json` Lua tutorials | 100 |
| `tutorials.json` Lua lesson bodies executed | 100 (exactly 1 lesson per tutorial) |
| `assets/tutorials/lua.json` legacy lessons executed | 2 |
| Total entries actually executed | 202 |
| Non-zero exit status | 0 |
| Matches expected output (trailing-newline tolerant) | 202 / 202 |
| Matches expected output (byte exact) | 2 / 202 |

The 200 byte-level mismatches are **not** content failures: `expectedOutput` /
`output` are authored without the trailing `\n` that `print` emits. Confirmed on
`lua-example-001` (`expected="weighted=22"`, `stdout="weighted=22\n"`). Nothing
in the product compares the two at runtime — see "No verification exists".

## Finding 1 (critical): the 100 examples are one template with a changed constant

`lua-example-001`, `-050` and `-100` are byte-identical except the seed array:

```lua
local values = {1, 3, 5}            -- 001
local values = {50, 52, 54}         -- 050
local values = {100, 102, 104}      -- 100
local total = 0
for position, value in ipairs(values) do total = total + value * position end
print("weighted=" .. total)
```

- 100 distinct code strings, but **1 distinct code template** once literals are removed.
- Titles advertise 24 topics (数据建模与不变量, 缓存与失效策略, 并发与资源生命周期 …)
  but each topic just cycles over the same weighted-sum body. Topic frequency is
  4–5 occurrences each across 100 entries.
- `expectedOutput` is a strictly increasing series `weighted=22, 28, 34 … 616`,
  i.e. the seed number, not a topic result.

Identical pattern in `tutorials.json`: 100 tutorials × 1 lesson, distinct lesson
codes = 100, distinct lesson templates = 1, same `weighted=22 … 616` series.
`lua-tutorial-050`'s lesson body is character-for-character `lua-example-050`'s body.

**Consequence for R2:** the existing 100 examples + 100 tutorials are 2 copies of
one 4-line snippet. A ">100 additions" target cannot be met by appending more
numbers to this cycle; the 200 baseline entries cannot count as meaningful topics.

## Finding 2: `inputFixtures` are decorative, not fixtures

All 100 examples carry exactly `{"case": "fixture-<n>", "mode": "deterministic"}`.
No entry carries a `stdin` key.

`ContentCatalog._inputFixtures` (core, `lib/content/content_repository.dart`) only
feeds stdin when a value is keyed `stdin` (or `input`). So **no bundled Lua entry
ever receives stdin**, and no fixture is actually exercised. Every example is
self-contained by construction, which is why every expected output is a pure
literal echo. `mode: "deterministic"` is a claim, not an executed fixture.

## Finding 3: no verification exists in the product

`expectedOutput` reaches the UI only as display text
(`lib/content/local_content_adapter.dart:81` → `local_content_pages.dart:401,510`,
labelled 预期输出). There is no code path that runs an entry and compares it to
`expectedOutput`. The 202/202 agreement above is **my** harness, not a product
guarantee, and it proves only that the numbers currently agree — not that any
content is meaningful.

## Pairing integrity (clean)

`sourceLessonId` for all 100 examples resolves to a real lesson; 0 dangling links.
Ids are stable and explicit (`lua-example-001…100`, `lua-tutorial-001…100` +
`lua-tutorial-NNN-lesson`). No duplicate ids. Release minimum (100 per type) is met
only because the cycle is padded, so the validator's `releaseMinimumPerType` gate
**passes while the content is not real** — a gate-blindness issue worth noting for R2.

## Legacy per-language document

`assets/tutorials/lua.json` declares `language/type: lua`, `schemaVersion`,
`runtime`, and 2 chapters × 1 lesson (`basics`, `values`). Both lessons execute and
match (`Hello, Lua!`). This document is not the shipped source — the HAP ships the
aggregate `examples.json` + `tutorials.json` (verified below) — but the parser still
accepts it as a legacy fallback.

## Cross-check with the content owner

Pi p3 independently produced `research/original-lua-audit.md` (+
`tool/lua_content/audit_original_lua_content.dart`) reaching the same conclusions:
24 topics after stripping numbering, 1 code template after stripping literals,
200/200 output agreement. Two independent harnesses agreeing raises confidence;
our counts are consistent (p3 reports 124 distinct titles from 100 tutorials +
100 examples with `实现：` prefixes, I measured 100 tutorial + 100 example titles
with 24 distinct topics on each side).

## No verification exists / device gap

**Host checks are not device proof.** Explicitly not proven by this report:

- No device was available: `hdc list targets` → `[Empty]`, `adb devices` → empty list
  (hdc 3.2.0c; adb present at `D:\ProgramFiles\platform-tools\adb.exe`).
- Nothing was executed on OHOS. All 202 runs are **host x86_64 Windows** runs against
  the MinGW-built DLL, not the ARM64 `.so`.
- `native/build/windows/` is a `Debug` build from Dev-Cpp MinGW64 gcc, generator
  `MinGW Makefiles`. The last recorded `Testing/Temporary/LastTest.log` run
  (2026-10-17 15:50) shows `qfli_lua_test` **Passed** — that is a prior recorded run,
  not mine.
- I did **not** rebuild native or re-run CTest: a `cmake` process and `flutter_tester`
  were live at audit time (2026-10-22 10:28), so a source/build writer peer was
  active and the shared `native/build/windows` tree was off-limits per this brief.

## Reproduce

```powershell
dart run build/offline-ide-audit/lua_baseline_audit.dart `
  --library native/build/windows/libqfli_lua.dll `
  --examples  ../qfli_studio_core/assets/content/examples.json `
  --tutorials ../qfli_studio_core/assets/content/tutorials.json `
  --legacy    ../qfli_studio_core/assets/tutorials/lua.json `
  --out       build/offline-ide-audit/lua-baseline-report.json
```
