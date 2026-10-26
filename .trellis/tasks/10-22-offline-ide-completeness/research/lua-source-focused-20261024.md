# Source and focused verification — October 24, 2026

Java's explicit terminal release at global401 was accepted by Lua406. The
reviewed Windows Job Object wrapper ran once, tool session96266, and exited0.
Its exact record is
`build/offline-ide-audit/final-verification/20261023T224253822Z-6c3990bff49f4b629912a2c35ff96ba6/run.json`.
The UTC run crossed no local date boundary: it ran October24 in Asia/Shanghai.

| Gate | Actual evidence |
| --- | --- |
| Changed Dart formatting | 73 files, 22 changed; command PID79764, exit0 |
| Package analysis | `dart analyze .`, PID79296, exit0, `No issues found!` |
| Seven focused test files | 125/125 PASS; empty stderr; focused phase PID52752, exit0 |
| Owned-process completion | Source phase PID61504 and focused phase PID52752: both job trees empty, no timeout or residual cleanup |
| Publication | Automatic terminal/release event410; wrapper/publication exit0; validation elapsed29.513s |

The seven files were `lua_code_analyzer_test.dart`, `lua_debugger_page_test.dart`,
`lua_studio_debugger_test.dart`, `lua_debugger_test.dart`,
`lua_offline_platform_test.dart`, `product_highlighting_test.dart` and
`script_acceptance_test.dart`. They exercise real local engines/debugger and
dirty snapshot probes as well as controlled error paths. The offline channel
vectors are host unit evidence; the actual OHOS bridge remains unevaluated.

Global405/411 and Note408 crossed the launch's recorded historical next owner.
Root413 explicitly corrected release410 to C, then JSON → Note → ready Web.
C415 accepted and C416 subsequently released. Lua retains no grant or process
from401 and did not start another validation command after terminal completion.

This pass does not cover subsequent initialization-cleanup error preservation
edits. That review found that a cleanup rejection during launch could replace
the original initialization error. The assigned repair must preserve the
original error/stack and retain a reachable stopping session if cleanup has not
completed. The new regression and final whole suite require a fresh named slot.

Full1282 host rerun, a fresh complete audit HAP, current installed OHOS examples,
native offline refusal, debugger/editor target verification, normal-app restore,
scoped commits and ordinary pushes remain open. The previous full1282 execution
took156.53s and failed only the recorded mixed-separator diagnostic comparisons;
its failure report is retained. The historical682Lua HAP is not the complete
product audit.

Read-only `hdc list targets` on October24 returned `192.168.68.207:46551`, a
different identity from the previous `127.0.0.1:5555` reservation. Lua426 asked
SQL122 to reconcile ownership and identity. Lua issued no target shell,
installation, launch, stop, reset, daemon or data mutation.
