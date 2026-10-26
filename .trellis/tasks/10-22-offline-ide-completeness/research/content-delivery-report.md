# Lua content delivery and factual corrections

Task: `10-22-offline-ide-completeness`. Updated 2026-10-22.

## Current delivery

The product-owned corpus contains 23 chapters, 240 lessons and 240 paired examples.
All 240 titles, programs and expected outputs remain distinct. The source of truth
is `tool/lua_content/topics_*.dart`; `tool/generate_lua_content.dart` produces
both `assets/content/lua_tutorials.json` and `lua_examples.json`.

This correction pass changed 41 lessons, including 12 programs and 8 expected
outputs. Tutorial/example pairs were generated together. Expected outputs were
authored from the intended behavior; they were not copied from runtime captures.
The correction pass changed only the 18 topic files listed below, the two assets,
and this report. It did not modify native code, shared core, platform files,
`main.dart`, profile wiring, runtime adapters, tests or the content generator.

## Factual and portability corrections

| Area | Corrected behavior |
| --- | --- |
| Dates | Fixed timestamps alone do not fix timezone or locale. Numeric formats now use UTC via `!`; no English weekday name or current-time-versus-fixed-date assertion remains. |
| Date tables | UTC fields are displayed with `!*t`. The `os.time` roundtrip separately uses a local `*t` table, preserving `isdst`; a UTC table is never silently interpreted as local. |
| Timing | `os.clock` measures approximate CPU time at platform-dependent resolution. Short tasks can tie; longer loops do not promise a measured ranking. The program checks nonnegative durations and deterministic calculations. |
| Environment | `PATH` and `HOME` are optional. Real lookup checks accept nil or string. Explicit, labelled lookup data demonstrates missing, empty and populated values without requiring a particular device environment. |
| Temporary files | POSIX `os.tmpname` reserves a file; it is false that it never creates one. The caller still opens and removes the path. A protected callback closes its handle with `<close>` before cleanup, and checks deletion failure. OHOS temporary-directory adaptation remains native-owner work. |
| Reading | `read("a")` returns an empty string at EOF. Failed numeric reads may consume input. The empty-line exercise now refers to the newline left after reading two numbers; `read(3)` actually returns `bet`, followed by `a`. |
| Iteration ownership | Lua 5.4 generic `for ... in io.lines(path)` uses the fourth closing value even on early exit. `file:lines()` does not take ownership of an existing file. Iterator factories may return only a closure; three results are not mandatory. |
| Buffering and exit | Flush transfers user-space buffers; it is not physical durability. Standard Lua process exit is distinguished from this app's overridden script exit. The example now actually calls `os.exit(0)` after its output. |
| Randomness and numbers | `math.random(0)` is valid in Lua 5.4 and produces a full-bit integer; the example checks its type. `math.ult`, `%d`, and bitwise operations accept integral floats but do not truncate fractional floats. Integer range checking uses `math.tointeger`. |
| Metamethods | Concatenation looks for `__concat`, not `__tostring`. A vector-length exercise no longer recursively calls `tostring(self)`. The supplied Lua 5.4.8 accepts numeric `__tostring` results, although returning strings is recommended. Lua 5.4 equality does not require both operands to share one `__eq`; `__le` fallback depends on the compatibility build option. |
| Memoization | Zero is truthy; false is the value lost by `if cached`. Tables are valid keys by identity. The unused recursive helper now uses a proper local-function declaration. Nil-result caching needs a separate presence marker. |
| Patterns | A single capture from `match` already returns one value; `gsub` returns text and count. The find loop advances on empty matches and includes an explicit empty-pattern demonstration. Returning nil or false from a replacement preserves the match; an empty string deletes it. |
| UTF-8 | `utf8.len("中", 2)` returns nil plus error position 2, not a length of 2. The repair program preserves valid Chinese around a bad byte. Byte classes depend on the C locale and are not Unicode categories; code points are not grapheme clusters. |
| Serialization | Literal backslashes are escaped before decoding, with a backslash-n roundtrip demonstration. Display serialization preserves array order, sorts only object keys, clears recursion-path marks to distinguish sharing from cycles, escapes control bytes, and clearly rejects unsupported mixed/sparse key shapes. It is explicitly debug text rather than JSON. |
| Other teaching claims | `string.rep` separator support predates 5.4 (available since 5.2); numeric-for limits need not be reached by the step; colon syntax is explicit-self sugar; locals do not make identifier typos impossible; ordinary mutable exports are not read-only; cyclic require does not automatically supply partial exports; default float printing does not promise lossless roundtrips. |

The semantic references are the official Lua 5.4 reference manual (sections 2.4,
3.3.5, 3.3.7, 6.1, 6.4, 6.5, 6.7, 6.8, 6.9) and the retained Lua 5.4.8
`lauxlib.c`, `lvm.c`, `lstrlib.c`, `lmathlib.c`, `liolib.c`,
`loslib.c`, `luaconf.h`, plus this application's `capture_exit` override.
The retained 5.2 manual establishes the older `string.rep` separator support.
The product assets retain their official Lua reference URL and original-content
CC BY 4.0 attribution.

## Correction of earlier provenance claims

The earlier report described
`("keep"):gsub("e", "%%")` yielding `k%%p` versus
`("a-b"):gsub("-", "%%")` yielding `a%b` as an inconsistency.
That was a factual mistake: keep has two matched e characters, while a-b has
one dash. Each replacement string `%%` contributes one literal percent.
Both results follow the same standard rule. There is no runtime inconsistency
and no reason to remove literal-percent replacement from teaching.

The earlier statement that all 200 original aggregate locations matched was
also too broad: it used trailing-newline tolerance. Exact evidence in
`research/baseline-catalog-audit.md` is 202 executed locations including the
two legacy Lua snippets, all returning status 0, but only 2 byte-exact matches.
The 200 aggregate records omit the final LF emitted by print. A tolerant
observation is not strict acceptance and does not establish OHOS execution.
Their 100 examples normalize to one numeric template and 24 repeating title
themes, so they do not constitute 100 meaningful distinct lessons.

## Checks for this correction pass

- Direct cached Dart generator: 240 topics, 23 chapters, 240 lessons/examples,
  240 distinct titles/programs/outputs, failures=0.
- Direct cached Dart analyzer over `tool/lua_content`: No issues found.
- Dart formatter applied to the 18 edited topic files.
- Generated asset inspection confirms paired code/output fields and the intended
  date, environment, temporary-file, UTF-8 and serialization programs.
- No Lua host/native, Flutter, device, cross-build, install or package command
  was run by this correction pass while the root's execution slot was reserved.

Historical 480/480 host execution reports describe the previous corpus and
are not current execution proof for these changed hashes. The root must rerun
the exact-output verifier and scoped tests with the rebuilt native library.
UTC/non-UTC and missing-PATH execution should be checked explicitly when an
appropriate process environment is available. Actual OHOS all-location
execution remains a separate gate. The target audit covers 682 Lua locations
(480 current + 200 original aggregate + 2 legacy), with skips never counted as
passes.

## Generated SHA256

| Asset | SHA256 |
| --- | --- |
| `assets/content/lua_examples.json` | `bc5bbe860024d67ffe2cf0199da2cec35ae39af13cd8db7f52009e97f01b3376` |
| `assets/content/lua_tutorials.json` | `a19779a0de72ef641fe73d9559d6bc202938f5e847ed38aef5046b257d66f5f7` |

## Corrected IDs and fields

Each suffix below identifies both `lua-lesson-<suffix>` and its paired
`lua-example-<suffix>`. Tutorial-only copy changes need not change example bytes.

| Topic suffix | Changed lesson fields |
| --- | --- |
| `lua-start-print-multi` | `exercises` |
| `lua-start-grade-report` | `pitfalls` |
| `lua-values-local-scope` | `exercises` |
| `lua-num-modulo` | `explain` |
| `lua-num-equality` | `pitfalls` |
| `lua-num-floor-mod-table` | `explain` |
| `lua-str-rep` | `pitfalls`, `explain`, `exercises` |
| `lua-str-compare` | `summary`, `explain`, `exercises` |
| `lua-tbl-method` | `pitfalls` |
| `lua-meta-tostring` | `pitfalls`, `explain`, `exercises` |
| `lua-meta-eq-lt` | `pitfalls`, `explain`, `exercises` |
| `lua-loop-numeric-for` | `summary`, `explain` |
| `lua-clo-memoize` | `objective`, `pitfalls`, `explain`, `code`, `exercises` |
| `lua-mod-init` | `pitfalls`, `exercises` |
| `lua-math-integer-limits` | `exercises` |
| `lua-math-ult` | `pitfalls`, `exercises` |
| `lua-math-random-range` | `summary`, `pitfalls`, `explain`, `code`, `output` |
| `lua-stl-trim` | `pitfalls`, `explain`, `exercises` |
| `lua-stl-find-all` | `code`, `output`, `exercises` |
| `lua-os-time-basic` | `pitfalls`, `explain`, `code`, `output`, `exercises` |
| `lua-os-time-table` | `pitfalls`, `explain`, `code`, `output`, `exercises` |
| `lua-os-clock` | `objective`, `concepts`, `pitfalls`, `explain`, `code`, `exercises` |
| `lua-os-getenv` | `pitfalls`, `code`, `output`, `exercises` |
| `lua-io-read-formats` | `pitfalls`, `explain`, `exercises` |
| `lua-io-lines-filter` | `pitfalls`, `explain` |
| `lua-io-tmpfile` | `pitfalls`, `explain`, `code`, `exercises` |
| `lua-io-exit` | `summary`, `pitfalls`, `explain`, `code`, `exercises` |
| `lua-io-buffered-write` | `summary`, `concepts`, `pitfalls`, `explain` |
| `lua-utf8-len` | `pitfalls`, `exercises` |
| `lua-utf8-offset` | `pitfalls` |
| `lua-utf8-validate` | `pitfalls`, `code`, `output`, `exercises` |
| `lua-utf8-count-by-kind` | `pitfalls`, `exercises` |
| `lua-co-iterator-protocol` | `summary`, `explain`, `exercises` |
| `lua-oop-operator-methods` | `pitfalls`, `exercises` |
| `lua-oop-tostring` | `explain` |
| `lua54-integer-division` | `pitfalls` |
| `lua54-bitwise` | `explain` |
| `lua54-env` | `exercises` |
| `lua-proj-serialize` | `pitfalls`, `code`, `output` |
| `lua-pra-template` | `summary`, `objective`, `pitfalls`, `explain`, `exercises` |
| `lua-pra-json-like` | `pitfalls`, `explain`, `code`, `output`, `exercises` |

## Files and remaining integration

Edited topic source files:
`topics_01_start.dart`, `topics_02_values.dart`, `topics_03_numbers.dart`,
`topics_04_strings.dart`, `topics_06_tables.dart`, `topics_08_meta.dart`,
`topics_10_loops.dart`, `topics_12_closures.dart`, `topics_14_modules.dart`,
`topics_15_math.dart`, `topics_16_strlib.dart`, `topics_17_osio.dart`,
`topics_18_utf8.dart`, `topics_19_coroutines.dart`, `topics_20_oop.dart`,
`topics_21_lua54.dart`, `topics_23_project.dart`, `topics_24_practice.dart`.

Existing content integration remains `LuaContentRepository.bundled`, the
registered `assets/content/` directory, and the existing catalog/runner/verifier
APIs. No new dependency is needed. The original generator, repository and
execution tests remain in place. No commit or push was made by this worker.
