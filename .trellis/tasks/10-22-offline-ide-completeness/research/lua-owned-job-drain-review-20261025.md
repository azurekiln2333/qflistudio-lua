# Owned-job drain independent review — requested 2026-10-25

Reviewed on 2026-10-26 (Asia/Shanghai). Active task:
`.trellis/tasks/10-22-offline-ide-completeness`.

## Scope and disposition

Independent source/static review of the four ignored audit scripts and
`research/lua-owned-job-drain-20261024.md`. Only this review document was written.
No script, shipping code, common core, test, README, SDK, device or Git state was
changed. No native helper was compiled or invoked and no scenario process was
launched. The parent-assigned README/export workers were not used or overlapped.

The first pass found B1: a successful natural-drain result could use an empty-job
observation made after its drain budget. The root subsequently repaired both
helpers. The narrow follow-up below closes B1 and confirms source readiness for
the next explicitly granted controls step. Original findings and fingerprints
remain below as historical evidence. Compilation and runtime controls remain
unverified. This reviewer did not edit the scripts.

## Finding B1: completion can use an observation outside the drain budget

Locations:

- `build/offline-ide-audit/run_bounded_verification.ps1:477–493`
- `build/offline-ide-audit/run_bounded_hap.ps1:375–391`

The loop can stop because `left <= 0` while its last active-count observation is
nonzero. It then stores `NaturalDrainElapsedMilliseconds` **before** entering
the final locked `Observe` / `ActiveCount` sequence. That later sequence supplies
`ActiveProcessesAfterDrain`. `NaturalDrainCompleted` combines the earlier
elapsed value with the later active count. It does not require a within-budget
empty-job observation.

A permitted execution trace with a 1000 ms drain budget is:

1. Last loop query sees an active child just before the limit.
2. The clock reaches 1000 ms; the `left <= 0` branch ends the loop.
3. The stored elapsed value is 1000 ms, which satisfies `<= budget`.
4. The final enumeration/query runs after 1000 ms; the child retires then.
5. Final active count is zero. The overall phase deadline has time remaining.
6. `NaturalDrainCompleted` becomes true, without forced cleanup or an error.

The same result is possible after a scheduling pause between the elapsed sample
and the final probe. The final `TreeEmpty` confirmation cannot establish when
the tree first became empty. The result therefore can pass the wrapper gates
at validation lines 666–668 and HAP lines 481–485 despite the natural-drain
observation occurring outside the allowed interval. This is a source-level
counterexample, not an observed runtime failure or a new claim about the old
345-test receipt.

Recommended repair: tie completion to an explicit empty-job witness whose
elapsed time is sampled **after that exact probe**, still within the drain and
original deadlines. A final post-loop zero count can remain useful evidence,
but must not manufacture a successful within-budget witness. Alternatively,
include the final locked probe in the measured drain interval and reject an
over-budget observation conservatively. Keep the two native helpers identical.
Do not reset or extend the original timer.

Add a boundary regression that delays the last observation/scheduling past the
drain budget and requires rejection even if the next count is zero. A pure
result-decision test with injected clock/probe values can cover this boundary
without relying on a 1 ms process scheduling race. It must exercise the actual
completion decision rather than duplicate its expression in a test.

## Verified source properties

- Both helpers create a suspended root, assign it to a non-breakaway job, arm
  the timer using remaining original time, then resume it. The job handle is
  noninherited and kill-on-close. Natural drain uses at most the smaller of
  1000 ms and original time remaining; the timer remains armed during drain.
- Deadline and cleanup termination call `TerminateJobObject` on the exact job.
  The sole direct root termination uses the retained process handle when job
  assignment did not succeed. There is no new process-name scan or PID kill.
- Residual PIDs come from the exact job. Each opened identity handle is checked
  with `IsProcessInJob` before image/creation identity is attributed to it.
  Exited, reused or inaccessible identities retain explicit errors. The first
  pre-termination snapshot is preserved under the shared lock.
- The timer callback contains native/C# work only. The asynchronous control
  harness passes a null PowerShell callback to the background helper. Its
  `Task.Factory.StartNew` call has a return-valued anonymous function and the
  generic `Task<ProcessResult>` overload is inferable. Checked numeric casts,
  nullable result fields and `Math.Min/Max` argument types revealed no definite
  C# semantic compiler error on manual inspection. This is not a compile pass.
- Drain, residual identity and cleanup fields are copied into validation and
  HAP stage/publication records. Forced residual cleanup, errors, nonzero exit,
  timeout, unconfirmed empty tree and attempted incomplete drain reject success.
  B1 is the remaining mismatch between the completion flag and its meaning.
- Controls require explicit grant text and first-phase ordering. The enclosing
  helper caps their execution budget at `min(10000, original remaining ms)` at
  validation line 626. `verify_current_source.ps1` routes controls before Dart
  availability or invocation. Nested jobs share the enclosing phase containment.
  The <=10 s limit is the controls execution deadline; the outer helper retains
  its separately documented bounded cleanup budget. Source inspection cannot
  certify a <=10 s wall-clock receipt.

## Controls assessment

`run_bounded_job_controls.ps1` extracts the actual native here-strings using the
PowerShell AST, normalizes namespace/newlines, requires equality and compiles a
fresh namespace for the controls. It does not carry an alternate containment
implementation. The separately owned heartbeat process is a sibling of the
three destructive scenario jobs inside the outer phase job.

The prepared assertions are meaningful for their stated broad cases:

- Finite child: root exits zero, child delays 600 ms, positive successful drain,
  empty job, observed child PID, completion marker, no forced termination.
- Long child: root exits zero, 30 s child remains after the configured 1000 ms
  drain, exact PID/image/creation identity matches, no timeout, forced exact-job
  cleanup and confirmed empty job, no natural completion marker.
- Timeout: 400 ms helper budget, timeout result/exit 124, root identity present,
  termination requested and job empty.
- Sibling: ready PID/creation identity stays unchanged, heartbeat modification
  time advances after each scenario, asynchronous helper remains unfinished,
  then a release marker allows its own helper to confirm clean completion.

The current long-child assertions (lines 241–248) do not check elapsed drain
against the budget. They would not detect an implementation that keeps the
configured budget at 1000 ms but gives up early after the finite child could
have finished. Add an elapsed lower-bound assertion appropriate to the helper's
monotonic millisecond clock. This is a test-strength recommendation; the actual
loop inspected here does wait against its elapsed budget. Neither prepared
child duration covers B1's late-empty observation. All runtime controls remain
unrun and may fail honestly if shell startup/compilation exhausts the outer
10 s window.

## Source fingerprints and static checks

| File | SHA256 | PowerShell AST errors |
| --- | --- | --- |
| `run_bounded_verification.ps1` | `7AB2F8A044C0A045F881ED95F9A961B74C0FC03A3415F586653EAEDC7BB57326` | 0 |
| `run_bounded_hap.ps1` | `AE78D487743C042AE405ED20A66ABE29511FA43E13F0F6FF97B83582B577A256` | 0 |
| `verify_current_source.ps1` | `59E7868876515A955AD498D42F59100CD664F80DFCE65E6F3276FB10D6842BF8` | 0 |
| `run_bounded_job_controls.ps1` | `FA20231DB76D987C74E63FB1488824DB1C865C351BE9734436384519861FA96A` | 0 |

All paths in this table are under `build/offline-ide-audit/`. Independent AST
extraction confirmed native helper equality after namespace/newline
normalization. Only PowerShell parsing, source reading and hashing ran.

## First-pass verification and next owner (superseded)

- PowerShell source syntax: pass, four files, zero AST errors.
- C# compilation/type-check: UNRUN. Manual review found no definite compiler
  blocker; this cannot replace compiling the actual helper.
- Controls/runtime/SDK/build/device tests: UNRUN under the source-only boundary.
- Old forced-cleanup receipt: unchanged and still failed as documented.
- Script fixes: none, per exclusive review scope. B1 needs repair before this
  revision is accepted as meeting the strict natural-drain guarantee.

The parent owns the repair and the next explicitly granted controls window.
After the repair, recheck normalized native equality and run the actual controls
before source/suite/full1282. This review grants no host/device slot and changes
no release ownership. Review-document ownership is released to the parent.

## B1 follow-up — 2026-10-26

**Source-ready for the next explicitly granted controls step. B1 is closed.**
No new concrete blocker was found in the assigned narrow repair.

Independently checked the actual helper bodies at validation lines 471–498 and
HAP lines 369–396. `Stopwatch drain` now remains in scope for the final locked
probe. `Observe` and `ActiveCount` run before
`drain.Elapsed.TotalMilliseconds` is sampled. The success predicate uses that
precise post-probe duration and the configured drain budget. The original
elapsed clock is then checked with `TotalMilliseconds`, and original-deadline
expiry still rejects success. Thus the late empty observation described in B1
can no longer be combined with a stale earlier duration to pass.

Telemetry uses `Math.Ceiling` of the post-probe duration, so a fractional overrun
is not recorded as an in-budget integer. The earlier loop-local elapsed sample
is overwritten by this definitive sample before a successful return. An error
before that assignment still follows the existing rejecting error path. The
change introduces no definite C# scope, nullable-expression, conditional-type,
`Math.Ceiling` overload or cast error by manual inspection. This remains a source
review rather than a compilation result.

The actual long-child assertion now requires
`NaturalDrainElapsedMilliseconds -ge NaturalDrainBudgetMilliseconds` at
`run_bounded_job_controls.ps1:246`. This closes the specifically reported
missing elapsed lower bound. No additional control framework is requested as
a prerequisite for the next granted controls step.

Independent PowerShell AST parsing again found zero errors in all four files.
AST extraction, CRLF normalization and exactly one anchored namespace
replacement per helper confirmed that the actual C# helper bodies match.
Only source reading, parsing and hashing ran; no helper/script was executed.

| File under `build/offline-ide-audit/` | Re-reviewed SHA256 |
| --- | --- |
| `run_bounded_verification.ps1` | `CED8925CBAF5401D2E0BE0EAFE46C3D740E0E8E3BF2E506C78636D22C4921A52` |
| `run_bounded_hap.ps1` | `E45BB9161B6103FD5BC5DD1AB6571B742AD9E39009D87E7F4263A9AACD93594A` |
| `verify_current_source.ps1` | `59E7868876515A955AD498D42F59100CD664F80DFCE65E6F3276FB10D6842BF8` |
| `run_bounded_job_controls.ps1` | `35DC1A6B18A40CE1FF17A3A7511E82BF31AA160DA6221200B3550268E83D9753` |

C# compilation/type-check and actual bounded controls remain UNRUN. This
follow-up does not change the historical failed wrapper receipt, claim a
runtime pass, or grant a host/device window. The parent may proceed to request
and use the next explicit controls grant under the existing ownership rules.
Review-document ownership is released again.
