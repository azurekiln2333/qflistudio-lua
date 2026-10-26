# Addendum — audit of the expanded Lua content (in-progress snapshot)

Owner: Pi p6 (verification only). Generated: 2026-10-22 10:33.
Artifact: `build/offline-ide-audit/lua-expanded-audit.json`.

While I finished the baseline report, the content owner (Pi p3) began generating
`assets/content/lua_examples.json` and `assets/content/lua_tutorials.json`. I ran
the same verification harness against them without touching the files. This is a
**snapshot of work in progress**, not a completion verdict.

## Result (78 entries executed through bundled Lua 5.4.8)

| Metric | Baseline (core catalog) | Expanded snapshot |
| --- | --- | --- |
| Entries executed | 202 | 78 (39 examples + 39 lessons) |
| Non-zero exit status | 0 | 0 |
| **Byte-exact** output match | 2 / 202 | **78 / 78** |
| Trailing-newline-tolerant match | 202 / 202 | 78 / 78 |
| Distinct example code | 100 strings / **1 template** | **39 / 39 unique** |
| Distinct example titles | 100 strings / 24 topics | **39 / 39 unique** |
| Distinct expected outputs | 100 (arithmetic series) | **39 / 39 unique** |
| Distinct concept lists | ~1 shape | **39 / 39 unique** |

## Why this is a real improvement

- `expectedOutput` now carries the trailing newline, so entries are **byte-exact**
  rather than only newline-tolerant. The baseline's 200/202 exact-mismatch class is gone.
- Topics are real and distinct, e.g. `第一行输出：print`, `io.write：不自动换行的输出`,
  `nil：表示「没有值」`, `布尔值与比较结果`. No arithmetic-series placeholder titles.
- `inputFixtures` is now `{}` rather than a fake `{case: fixture-N, mode: deterministic}`
  label — the misleading fixture metadata is dropped rather than faked.
- Tutorials are restructured from 100 × 1-lesson clones into real chapters:
  `lua-chapter-start` (6), `-values` (10), `-numbers` (11), `-strings` (12) = 39 lessons.

## Gap against R2 (not met yet, expected mid-flight)

R2 asks for **240 distinct paired topics** and **>100 additions** beyond the
original 100. The snapshot has **39** distinct topics. Nothing here proves the
final count or that the remaining generation maintains this quality; re-run the
harness on the final files before claiming R2.

## Command

```powershell
dart run build/offline-ide-audit/lua_baseline_audit.dart `
  --library native/build/windows/libqfli_lua.dll `
  --examples assets/content/lua_examples.json `
  --tutorials assets/content/lua_tutorials.json `
  --out build/offline-ide-audit/lua-expanded-audit.json
```

Note: `--legacy` was omitted; these files are already `{entries: [...]}` documents.
The harness reports `tutorialsAudited: 4` with `lessonsAudited: 39` because the new
documents are chapter-shaped (multiple lessons per tutorial), which the harness
already handles by flattening lessons.
