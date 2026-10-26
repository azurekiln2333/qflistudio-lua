# Lua terminal observer independent source review — 2026-10-26

Current disposition: **SOURCE-READY for the revised python-owned-command-v1
observer**, pending explicit coordinator approval of the final observer/bridge
hashes and a later named execution grant. This closes the earlier native
observer Job-retention blocker by replacing that ownership layer with exact
Python private Jobs. Runtime and process controls remain UNRUN. Earlier review
findings remain below as repair history.

Scope: exclusive ignored `build/offline-ide-audit/run_granted_verification_observer.ps1`
and this report. Other orchestration scripts, shipping code and core were
untouched. This is a source-only review under protocol717. No Add-Type, SDK,
compiler, runtime control, test, build or device command ran.

## Findings fixed

### F1 — Post-record-write timing was not part of readiness proof

The old final block set coordinationBudgetPassed/nextSdkGrantReady and recorded
elapsed before its final Save. Slow disk IO could therefore finish after330s
with a true record. The repair reserves1s for final record IO, samples the clock
AFTER Save and writes a failure correction when that completed write exceeded
the total. A successful consumer must additionally observe the final stdout
`finalEvidenceCheckedMilliseconds` after that durable write; the channel text
now says a pending/on-disk record alone is insufficient. This avoids pretending
one file can durably certify the duration of its own future write.

The final stdout check value is not falsely claimed to have been included in
the preceding successful Save. On an overrun, the correction records it. An
IO hang is still a hang, not a hard-stop guarantee; it cannot produce the final
post-write readiness observation. The proof excludes later console transport
or model scheduling time and must not be described as observer self-terminal.

### F2 — Direct ACK output drain had an unbounded wait

After waiting3s for the ACK root, the old code unconditionally called
ReadToEndAsync.GetResult on both redirected streams. A descendant retaining an
inherited pipe could leave those calls blocked indefinitely even after root
exit. Both tasks now have an explicit1s combined closure wait. Failure records
HOLD and launches no helper/compiler/SDK work. EOF still is not Job proof.

### F3 — Historical grants could pass the preflight equality lookup

Matching an existing coordinator event is not new authority. The source now
requires exact approved protocol717 and a later grant event. It atomically
creates a durable per-event grant claim with CreateNew before ACK. Existing
claims are never deleted/reused; an interrupted or failed claimed attempt
requires a newly named grant. Actual current coordinated authority still
belongs to C/root; this is a replay rejection guard, not a prose grant detector.

### F4 — Frozen-file loops missed pre-phase additions and declared HEAD drift

The old checks iterated only candidate.paths/core.files. A new test added after
freeze but before the first phase snapshot could silently join Flutter suite
discovery. Complete inventory preflight now compares exact relevant file sets
and hashes for product and core, with the same source/cache/binary exclusions
as phase manifests. Product and core HEADs are also checked. Candidate HEAD and
its existing Git tree object are checked before ACK.

Preparation schema1 now additionally REQUIRES `product{manifest,sha256}`.
That product manifest must contain `head` and a `files` object covering
lib/test/tool/tools/bin/native/assets plus pubspec.yaml/pubspec.lock/
analysis_options.yaml under those declared exclusions. The core manifest must
cover lib/assets plus pubspec.yaml and include actual HEAD. Root must regenerate
both manifests against C's later tested checkpoint. Listing only modified
candidate paths is insufficient. Missing fields reject before ACK.

### F5 — An unproven ACK descendant tree could become next-SDK readiness

The direct pre-helper ACK used only a retained Process root. It had no private
Job. Successful root exit plus output EOF does not prove all descendants have
retired. The old observer could still publish RELEASE and set readiness true.
The source now records `descendantsTerminalAndEmpty=false` honestly and refuses
BEFORE Add-Type or SDK work. Defensive checks also reject final relay/readiness
without actual ACK tree proof. This intentionally prevents execution until the
remaining architectural gap is repaired; do not replace this field with true
based only on root exit or pipe EOF.

## Remaining blocker requiring root architectural choice

The existing constraint compiles the native Job helper only AFTER ACK. That
same helper is necessary to create/assign a private ACK Job before its sender
can spawn children. The current direct Process ACK cannot satisfy both rules.

A source-ready solution needs a reviewed way to own the ACK tree from creation.
One possible route is a separately granted, frozen precompiled helper artifact:
prepare/hash it, load that exact assembly without compilation, then run ACK in
its own Job before SDK work. Another route requires an explicit revised
coordination boundary for pre-ACK helper preparation. This reviewer did not
invent that approval or compile an artifact. The current observer must not be
executed as a successful host gate or advertised READY.

Add-Type also lacks a hard interruption deadline. Its elapsed time is charged
to the clock, and later SDK work can be refused, but the source does not prove
a compiler hang will stop within330s. Report this as an honest limitation,
never a hard end-to-end deadline guarantee. Resolving the ACK helper boundary
may also remove this later unowned compiler step.

## Other reviewed boundaries

The validation child is created suspended inside the reused exact owned-Job
helper. Its Process handle and creation time are captured before resume. The
observer checks actual terminal/exit, empty outer Job, report identity/grant,
inner payload cleanup and pending publisher cleanup before final relay. Its
run.json path is restricted to the explicit final-verification directory.
The final sender uses its own bounded owned Job and retained identity, and a
unique delivered matching event is required. No self-terminal claim exists.

The native helper extraction remains anchored to one actual nativeSource block
and one exact namespace. Its namespace replacement does not alter the helper
body. Validation and final-sender executions reserve cleanup time; actual
native helper execution/cleanup remains unrun. The final control-plane observer
is intentionally allowed to remain alive under717.

## Verification

- PowerShell AST parse: zero errors after changes.
- Static helper anchors: exactly one nativeSource block and one reviewed
  QfliLuaAudit namespace anchor.
- Source probes confirm CreateNew claim, complete-inventory calls, post-Save
  clock observation and pre-compiler ACK proof rejection.
- No runtime, Add-Type/compiler, analyzer, SDK, tests, build or device commands.
- All other script/source/core files remained unchanged by this reviewer.

Reviewed observer SHA256:
`3d571a59d6ebe17bda7fec7b86c1368e2bfb7e517875cb3377ce40d421b6f01c`.


## Independent re-review after Python ACK bridge integration

The original direct-ACK architecture finding is closed in source. The Python
bridge verifies frozen Python/helper/request hashes, creates the ACK root
suspended, assigns its private Job before resume and retains HANDLE/FILETIME.
It bounds normal polling, attempts exact-Job cleanup on timeout, and keeps
uncertain handles alive with HOLD until actual root terminal and Job active0.
Errors/timing failures remain recorded and prevent later promotion. The
observer separately retains the bridge identity and requires its actual
terminal success before Add-Type/SDK. The helper is byte-identical to C's
`baseline_200_owned_job.py`, SHA2565c3dc4d0.

The frozen product/core exact inventory checks, HEAD checks, grant claim and
post-write final-observation guards remain present. Python executables and all
six scripts are bound before ACK. No broad process search or termination was
introduced. Runtime remains UNRUN.

### Additional mechanical lifecycle fixes in this re-review

1. An evidence-write failure while the bridge tried to persist uncertain
   cleanup could unwind it before its retention loop. That could abandon
   retained ownership based on a disk error. The bridge now catches that
   persistence failure, records it in memory and continues exact retention.
   It can never become passed because that error remains in the report.
2. Observer finally previously disposed the bridge even if an earlier Save
   exception interrupted the normal10s-overrun retention loop. Finalization
   now retains the exact bridge and waits for its actual terminal. No SDK or
   successor is launched while it waits.
3. `Invoke-Owned` previously disposed its separately retained Process even if
   the helper returned while that exact root was live. It now records HOLD
   and retains/waits for the root before disposal. This repairs root-handle
   ownership only; it cannot repair the private Job issue below.

### Remaining concrete blocker: native helper drops an uncertain private Job

`run_bounded_verification.ps1`'s reused C# BoundedProcess finally samples
TreeEmpty after bounded cleanup and then unconditionally closes its Job handle,
even when TreeEmpty is false. The observer copies that body with namespace-only
substitution. `Invoke-Owned` therefore receives a false proof after the only
Job handle has already been closed. Retaining the callback's separate root
Process does not retain the private Job or permit an active-count recheck.
Job kill-on-close is a termination request, not observed terminal/active0.

The observer correctly refuses final RELEASE/readiness on the false result,
so this is not a demonstrated false-success path. It nevertheless cannot
satisfy protocol717's retained-child/Job HOLD requirement or later prove exact
cleanup on that path. **Do not advertise this implementation as source-ready
for all717 lifecycle paths.**

Fixing it requires an explicit observer-specific native ownership change or
using the Python exact-Job controller for validation and final sending too.
The upstream launcher/helper is frozen and outside this review's file scope;
this reviewer did not silently modify it or change the promised namespace-only
reuse into an unreviewed native variant. Root must select that change boundary
and re-review the final identity. Add-Type's lack of hard interruption also
remains an honest limitation rather than a330s hard-stop proof.

### Actual verification and released bytes

- PowerShell AST parse: zero errors.
- Python AST parse of bridge and helper: pass without importing/executing them.
- Copied helper byte comparison with C's source: identical.
- No SDK, Add-Type, compiler, runtime control, tests, build or device execution.
- Changes confined to observer, bridge and this report. Exact helper untouched.

SHA256:

- observer: `0aa79353f89b995ad93d4020ae497bcd9cd526fd54ed27195f3b7773fd0bc5d2`
- bridge: `e03245d6420267b3fa683b624dd44e8456e2a520118ab6d147f6bf867d2ab981`
- helper: `5c3dc4d0bdaaa26233212560968b58d02e215eb27c29e9e88be4c99d212ce116`


## Final independent re-review: python-owned-command-v1

The observer now uses the same exact Python OwnedJob bridge for ACK,
validation-outer and final publisher. No Add-Type or native-helper extraction
remains in the observer. The bridge owns each root and private Job until actual
terminal/active0; uncertain cleanup retains exact handles and HOLD. Parent
retains each bridge independently until actual terminal. The old inner launcher
is unchanged and executes inside the new outer private Job, so its own failed
cleanup cannot escape that outer ownership observation.

Lifecycle success is separate from child exit status: generic command lifecycle
can pass after a nonzero application result, while ACK and final publisher must
also exit0. The observer reports failed validation honestly and can release
ownership after all required cleanup, without promoting the validation gate.

The Windows QPC deadline passed to each bridge shares the parent's clock and
reserves. File/hash/startup preparation consumes that absolute deadline. The
final record still requires a post-write stdout observation. A slow/unproven
HOLD is never promoted to a historical within-budget pass. Frozen inventories,
HEADs, per-grant atomic claims, requests and script/Python hashes remain bound.
The seven-section host ownership spec is consistent with this hierarchy.

### Narrow findings fixed in final review

- The protocol gate previously accepted any later coordinator event with a
  prepared hash, even if its text did not name this architecture or source.
  The actual event must now name python-owned-command-v1 and contain both full
  prepared observer/bridge hashes. Their hashes come from preparation, avoiding
  circular source literals. The event must be later than717 and the actual
  named grant later than that approval.
- Job creation/output-file IO could exhaust the absolute deadline after the
  initial clock check. There is now a second refusal immediately before child
  creation. Final time is sampled after membership observation; a late
  terminal/active0 observation is classified timedOut rather than a clean pass.
- Payload image evidence previously repeated only the bound command. The
  bridge now queries the actual image through its retained handle and compares
  it with the bound command. Parent verifies that image against its selected
  shell. HANDLE/PID/creation are captured by the exact helper before resume;
  imageCapturedAfterResume labels the separate later image query honestly.

### Verification and remaining gates

PowerShell AST parse is clean. Both Python AST parses pass without imports or
execution. The copied helper remains byte-identical to C's frozen helper.
No SDK, compiler, Add-Type, runtime process/control, tests, build or device
command ran. No shipping/core/inner-launcher file changed.

This is a source-readiness disposition only. The new process hierarchy has not
yet received the required explicit coordinator approval. Approval must name
these final hashes, followed by a NEW named execution grant. Current manifests
must be regenerated after these source/report/spec edits. Actual Windows
natural/timeout/sibling/nested-Job behavior and final publication remain UNRUN.

Final SHA256:

- `run_granted_verification_observer.ps1`: `b4c8eee6b7f5e4142f0541a4696b09fb259fb2735f39f9a577a4b973a3bd8891`

- `ack_job_bridge.py`: `0feba72ef50019cabd47a7d68d69ececc409b7ad75ac4d90215a0dcd1a56eb8b`

- `ack_owned_job.py`: `5c3dc4d0bdaaa26233212560968b58d02e215eb27c29e9e88be4c99d212ce116`


### Custodian-retention addendum after JSON776/root follow-up

The generic bridge timeout initially terminated the validation wrapper's whole
Job. That wrapper is itself custodian for inner payload/publisher Jobs, so this
could destroy its retained inner cleanup observations. The final source now
binds `preservesCustodian=true` specifically for validation-outer requests.
After assignment, timeout OR exception marks failure/HOLD and never terminates
that custodian Job. The bridge retains exact handles until natural actual
terminal/active0, and parent retains the bridge. Earlier timeout/errors remain,
so eventual cleanup cannot become an earlier success. Pre-assignment failed
creation can still terminate its own never-resumed root. ACK and final sender
retain their ordinary exact-Job timeout cleanup.

This retention can exceed330s while HOLD remains active; it is explicitly not
a bounded-success guarantee. No successor is authorized during that interval.
The actual new coordinator approval must name both python-owned-command-v1
and preservesCustodian and pin the final observer/bridge hashes. Protocol717
alone and an arbitrary later event cannot authorize this revised hierarchy.
Source-ready is conditional on this approval and a subsequent fresh named grant.

Final released SHA256 (supersedes all preceding observer/bridge hashes):

- `run_granted_verification_observer.ps1`: `0f30ce6953eeeddec6e50a1ee8bb0df966b7e1387404a2d5d89bbc48a76adfb0`

- `ack_job_bridge.py`: `7b2846ac2f03edb6d11910b666e286dece28e67a8f1cf19e4ee4b8304f3e7b6f`

- `ack_owned_job.py`: `5c3dc4d0bdaaa26233212560968b58d02e215eb27c29e9e88be4c99d212ce116`
