# Source and full1282 attempt — October 24, 2026

C487 explicitly released a new source/full1282/suite window after publishing
core `2f9039a3ba95449679b17257b0313c1ee3644a2c`. Lua accepted494 and ran
`source -> acceptance -> suite` once. Tool session83679 terminated with exit1;
automatic terminal release495 named Note's new request491. No reservation or
owned live process remains from this attempt.

The durable run is
`build/offline-ide-audit/final-verification/20261024T025852658Z-b8193c11985948ec9c7a042e0eea8561/`.
Its launcher SHA256 was
`d76c68bd58b1275d281c656f3e30ffaba8a12276714f4c1c2c2959e13aa15ffd`.

| Gate | Actual result |
| --- | --- |
| Source formatting | 74 files, zero changes, exit0 |
| Package analysis | `dart analyze .`, `No issues found!`, exit0 |
| Full opt-in acceptance file | 19 tests passed, full1282 test failed at the combined terminal gate |
| Inventory/execution | 1,282 locations, all 1,282 executed and finished; independent coverage/runtime identity gates true |
| Per-case terminal-line/status comparison | 1,282/1,282 true |
| Current Lua exact comparison | 480/480 true |
| All-shipped strict comparison | 482 exact; 800 original final-LF differences retained, strict gate false |
| Direct/shared debugger probes | All checks true, owned project cleanup true |
| Script dirty diagnostics | All checks true; correction, source preservation and no execution true |
| Lua dirty diagnostics | Two path-equality checks false; actual syntax ranges15..16 and messages correct; correction/no-write/no-execution true |
| Full normal suite | UNRUN because the wrapper stopped after acceptance failed |
| Device/native bridge | Not evaluated on Windows; all device gates false |

The combined terminal gate also requires successful probes. Its failure must
remain a failure even though every per-case terminal-line row passed. The Lua
probe compared a mixed-separator caller path directly with the analyzer's
canonical Windows path. The analyzer returned the intended file and exact
UTF-16 range; the fixture still expected the unnormalized string. A narrow
audit-owned canonical-path repair and regression are assigned separately.
This result does not verify that subsequent repair.

Source phase PID80800 exited0; acceptance phase PID71376 exited1. Both private
Jobs were empty, with no timeout or residual-process termination. Publisher
PID84224 exited0 with an empty Job and delivered495. Validation elapsed163.069s.
Both phases recorded zero source drift, stable product/core HEADs and complete
before/after maps; their JSON digests are recorded in `run.json`.

All four report files were copied byte-for-byte into the run's `host-reports/`
before another audit could overwrite the current report names:

| File | SHA256 |
| --- | --- |
| `script-host-current.json` | `c6a702f0d6cf6d0c25283b06f444aba93baf7f3e1c2e4946c6ac9dd4c3745dd6` |
| `script-host-current.json.lua.json` | `206e0861bc3947d9f1b59fc731ed15d5c33e33477d06c951cb688959f42bdaf9` |
| `script-host-current.json.script.json` | `6f56dd575eecf4fb870f978b6d4d898d34650cdc892fb286f4fcf7ece53da662` |
| `script-host-current.json.script.json.cases.jsonl` | `94b5d4d62da2bba4cd4539bd8e9429a14e20b21795027ad7cef69ffab4b57a6f` |

The historical first1282 report remains separately preserved. Neither host
attempt is an installed OHOS pass. The current complete1282 HAP, SDK signature
verification, exact target identity/ABI/access, installed audit/UI workflows,
normal-app restoration, full suite and scoped publication remain open.
Lua494/506 explicitly retained the device defer to SQL122/216 because no current
complete artifact is ready. The old exact127.0.0.1:5555 window is not reused.
