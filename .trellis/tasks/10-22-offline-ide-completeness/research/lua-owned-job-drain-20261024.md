# Lua owned-job natural drain repair — October 24, 2026

## Boundary and immutable failed evidence

This worker owns only the ignored audit launchers
`build/offline-ide-audit/run_bounded_verification.ps1`,
`run_bounded_hap.ps1`, `verify_current_source.ps1`, the new
`run_bounded_job_controls.ps1`, and this note. Shipping Dart, native runtime,
core, product tests, SDK/build/device commands and Git index remain untouched.

The actual C524/Lua530 attempt terminated at global531. Its source phase and
package analysis passed; its whole suite reported 345/345 and root exit 0.
The wrapper nevertheless rejected the suite because its owned job still had
active processes when the root exited, so `residualTreeTerminated` was true.
Acceptance did not run. This remains a failed wrapper gate.

The unchanged report is
`build/offline-ide-audit/final-verification/20261024T040653841Z-2a56c314a50a4ff0970427cd6c3a0641/run.json`.
Read-only SHA256:
`4f421effbfdadbf413a008f8188dd80e68ba683ae50b689ea7c69460cf403f8d`.
The old helper immediately killed the remaining job and recorded historical
PIDs only; it cannot establish which child remained or whether it would have
retired naturally. The repair does not relabel that evidence as passing.

## Narrow helper change

Both launchers retain suspended process creation, assignment before resume,
non-breakaway containment, a noninherited kill-on-close job handle and their
existing bounded cleanup. Their embedded C# helpers are identical after only
namespace/newline normalization.

After a signalled root exit, the helper observes only its exact job for at most
`min(1000 ms, original deadline remaining)`. The original native deadline timer
remains armed throughout this natural drain. It records the root-exit instant
and active count, chosen drain budget, actual drain duration, completion and
post-drain active count. A drain observed beyond its chosen budget is not a
successful drain, even if the job subsequently became empty. Attempted but
incomplete drain, forced residual cleanup, timeout, nonzero root exit,
unconfirmed cleanup or an error all reject success.

Before the first job termination request, the helper snapshots the current
job's process IDs. It opens identity-only handles and confirms membership in
that same job before recording image path and exact creation FILETIME/UTC.
An exit/reuse/access race is reported explicitly; it never attributes an
unconfirmed handle's identity to this job. Cleanup uses the exact job handle;
the existing handle-only cleanup for an unassigned suspended root remains.
No process-name scan, guessed ancestry or PID-based termination was added.

The first pre-termination identity snapshot is retained across timer/cleanup
races. Records also include whether job termination was requested and total
cleanup elapsed time. These fields are copied consistently into validation
phases/publication and HAP build/evidence/publication. Validation record schema
is now 3; HAP wrapper schema is now 2. Inner builder receipt schemas are unchanged.

## Explicit same-grant controls phase

The default validation phases remain `source,focused`. An explicitly requested
`controls` phase must be first and the current grant text must name controls.
The outer helper caps that phase at `min(10000 ms, original shared validation
deadline remaining)`. The later source/suite/acceptance phases share the same
original validation clock. A failed controls phase prevents their execution;
the wrapper retains its existing terminal/release publication path.

`verify_current_source.ps1` routes controls before checking or invoking Dart.
The controls runner requires the enclosing bounded run identity. It uses
PowerShell AST to read the actual native here-strings in both launchers and
requires equality after namespace/newline normalization. It compiles and
exercises that actual identical helper once, with a unique namespace, rather
than carrying a second containment implementation.

Prepared controls, not yet executed:

| Scenario | Required observations |
| --- | --- |
| Root exits 0, child finishes after 600 ms | A nonzero natural drain completes within its <=1000 ms budget; root 0; exact job empty; no termination request or residual identity; child's completion marker exists. |
| Root exits 0, child waits 30 s | Native success is rejected; no timeout; 1000 ms drain incomplete; residual child identity matches its ready PID/image/exact creation time; only that job is terminated and confirmed empty; no natural completion marker. |
| Root waits 30 s under a 400 ms deadline | Native success is rejected; timeout true, root exit 124, pre-termination root identity recorded and exact job confirmed empty. |
| Separately owned heartbeat sibling | Same ready identity and advancing heartbeat survive each inner scenario; finally a release marker allows its own helper to confirm clean exit and empty job. |

Each inner control job is nested within the outer phase job. The independent
heartbeat is a sibling of the destructive scenarios inside that outer phase,
so their cleanup cannot legitimately affect it. The outer exact owned handle
remains the final containment backstop. Ready identities are atomically
published; heartbeat observation reads file modification time to avoid a
truncate/read race. Control logs and `owned-job-controls.json` are retained in
the controls phase directory. There is no additional publisher in the controls
runner.

The coordinator can request `controls,source,suite,acceptance` under a NEW
grant naming controls, suite and full1282, with the existing shared 300-second
validation budget and the coordinated cleanup/publication reservation. The
previous event524 and current readiness message544 are not new grants.

## Static verification and remaining gates

PowerShell AST parsing found zero syntax errors in all four scripts. C# syntax
AST parsing found zero errors in both embedded helpers and in the combined
helper/async-control harness. The three generated PowerShell command templates
also parse after placeholder substitution. Namespace/newline-normalized native
helpers compare exactly equal. These checks parse source only: no helper was
compiled or invoked, and no controls, formatter, analyzer, tests, acceptance,
SDK, HAP, device or index command ran in this worker assignment.

Independent source review and a NEW explicitly named host grant are still
required before real controls and source/suite/full1282 verification. C# syntax
parsing does not establish compilation, Job API behavior or runtime control
success. No new suite, acceptance, package or device pass is claimed here.
