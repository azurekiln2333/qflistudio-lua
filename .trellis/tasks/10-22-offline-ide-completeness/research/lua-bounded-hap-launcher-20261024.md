# Bounded HAP launcher — 2026-10-24

## Boundary and status

Prepared only ignored build/offline-ide-audit/run_bounded_hap.ps1 and this
research note. The shipping builder/inspector, existing validation scripts,
product/core sources, signing material and device state were not modified.
The launcher and all generated children remain UNRUN. This note grants no host
reservation. A new explicit coordinated HAP-build grant is still mandatory.

The inner builder retains SDK/package/core binding, before/after raw source
manifests and HEADs, actual build/inspection command receipts, retained logs,
and preserved-HAP inspection. The outer launcher adds process deadlines and
host handoff orchestration; it does not move those responsibilities into
shipping code or infer the selected Dart entry from an archive.

## Explicit grant and invocation

Required inputs are the NEW grant event and its exact text, explicitly named
successor, the granted ohos-x64 or ohos-arm64 platform, and explicit SDK root.
Grant text must name HAP build scope and that platform. No channel polling,
idle-time inference, device discovery, or default successor is implemented.
Each grant event is locally recorded with CreateNew in bounded-hap/grants/;
that event cannot be reused by this launcher. The marker is a local recording
guard, not authentication of external coordination.

Invoke from PowerShell only after replacing every variable below from the
actual new grant. This is a template, not an executed command:

    $hapArguments = @{
        GrantEvent = $newHapGrantEvent
        GrantText = $exactNewHapGrantText
        NextOwner = $explicitNamedSuccessor
        Platform = $grantedOhosPlatform
        FlutterSdkRoot = 'D:/ProgramFiles/flutter_ohos'
        MaxSeconds = 600
        EvidenceTimeoutSeconds = 15
        PublicationTimeoutSeconds = 10
    }
    & 'D:/MyNewProjects/qfli_lua/build/offline-ide-audit/run_bounded_hap.ps1' @hapArguments

The target is fixed to bin/script_acceptance.dart. The grant's selected
platform must be supplied; the launcher never guesses the current device ABI.
Use a shorter MaxSeconds if that is the coordinated budget. Reserving the
default configuration means <=600 seconds for preparation/build/inner evidence,
up to 15 seconds for receipt indexing, up to 10 seconds for publication, and up
to ten cleanup seconds for each of those three private jobs: process budgets
sum to 655 seconds. Local record/file operations add ordinary small I/O
overhead. run.json records each budget and elapsed time. No sleep or unbounded
native wait is used. Do not apply an old source/suite grant to this build.

## Process containment and release

Copied the native process implementation from the current validation wrapper
SHA256 D76C68BD58B1275D281C656F3E30FFABA8A12276714F4C1C2C2959E13AA15FFD,
changing only its namespace to QfliLuaHapAudit. The helper is embedded rather
than executing/importing the validation wrapper. It creates a child suspended,
assigns it to a private non-breakaway KILL_ON_JOB_CLOSE Job Object, then resumes.
The native timer applies the remaining deadline while PowerShell waits.
Timeout/residual cleanup operates only on that Job; observed PIDs are evidence,
never ownership or kill selectors. A root handle confirms exit and Job
accounting confirms zero active processes before the stage is terminal.

The main builder, receipt collector and Trellis publisher use independent
instances of this containment. There is no process-name scan, global Dart/
Java kill, guessed ancestry, or PID-only cleanup. Each job has bounded cleanup
even when termination fails. If build or collector root/job cleanup remains
unconfirmed, automatic publication is withheld and the named successor must
await explicit reconciliation. A never-started stage has no owned process;
its attempted flag is recorded separately.

After prior work jobs are confirmed terminal/empty, a separately bounded,
owned publisher runs trellis channel send with --text-file. The message names
the exact grant, run, target/platform, stage PIDs/exits/job state, report and
successor. The successor must explicitly accept. Release acknowledgement is
claimed only after publisher root/job cleanup and a matching returned channel
message event (positive seq, kind, speaker and exact text) are confirmed.
Publisher failure may leave an already appended event; no automatic resend or
grant reuse occurs. Root must reconcile that exact log/event rather than infer
success from silence.

## Per-run receipts and failure preservation

Each run uses unique bounded-hap/<UTC-guid>/ paths. It retains the launcher
source reference, actual shell-command JSON/hashes, generated child-script
hashes, stdout/stderr, budgets, process identities and final release event.
The actual builder invocation is recorded with exact target, platform, SDK
and unique caller log/report paths; builder/inspector source hashes are
captured before invocation.

The receipt collector matches BOTH unique caller paths in inner receipt JSON.
It does not select the latest folder, infer ownership from timestamps, or
guess an artifact from a PID. Zero or multiple matches fail. It records the
matched receipt path/digest, before/after source-manifest references, actual
build/inspection command/log/report references and final HAP reference. It
rehashes those evidence files and the two tool sources within its own deadline.
Actual receipt target/platform/SDK/root and success/source/package gates must
agree. Source inputs are bound by the inner manifests; equivalence to an
earlier host-test run is not inferred automatically.

Failed/timed-out invocations still attempt bounded receipt collection after
owned build cleanup. No inner receipt, source manifest, log or HAP is deleted,
rewritten or backfilled. A forced timeout can prevent the inner builder's
finally block from completing; such missing/incomplete evidence is a failure,
not a clean package result. The unique caller paths and outer stage logs remain
available for manual review even when collection itself times out.

Signature verification remains separately pending. Device acceptance stays
false, and this launcher has no device action. No credentials/signing files are
read or written by the launcher/collector. It invokes the existing builder
under its existing signing configuration when a future grant is supplied.

## Static verification and remaining gates

- Launcher PowerShell AST: zero parse errors.
- Both generated child-script literal bodies: zero parse errors.
- Native helper: static exact-text equality to the recorded origin, except
  namespace; no C# compilation or process launch was performed.
- Git confirms the launcher is ignored. PSScriptAnalyzer is unavailable; no
  lint/type-check/runtime pass is claimed.
- Read-only SDK source inspection found assembleHap in
  packages/flutter_tools/lib/src/ohos/hvigor.dart passes --no-daemon and uses
  synchronous ProcessUtils execution. This is source context, not proof of
  which route a future SDK snapshot will execute.
- Open: execute only under a new explicit HAP/platform grant; verify actual
  builder/receipt linkage, deadline cleanup and publisher acknowledgement,
  inspect the current package, then obtain separate signature/device evidence.
