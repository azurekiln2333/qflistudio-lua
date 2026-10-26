# Full1282 HAP source readiness — October 24, 2026

> Historical source review. Its readiness, device-queue and missing-export
> assumptions are superseded by
> [Lua acceptance continuation — October 26](lua-acceptance-next-20261026.md).
> Keep the original observations below as dated evidence. They authorize no
> replay, build or device action.

Scope: source/static review and the explicitly assigned inspector repair only.
No build, runtime, Flutter test, HAP inspection, device command, signing change,
private-key inspection, commit or index change was performed in this pass.
The existing125 focused host pass is retained with its original source boundary;
it is not repeated or extended by this note.

## Package inputs and repaired proof boundary

`tools/build_ohos_audit.ps1` selects `bin/script_acceptance.dart` by default.
That entry runs682 Lua locations plus600 original JavaScript/TypeScript/Shell
locations, independently requiring1282 total and480 exact current Lua cases.
It also runs real debugger/shared-debugger/dirty-parser probes and, only on
OHOS,28 native offline bridge refusal checks. All needed shared source asset
files exist and are declared by `qfli_studio_core/pubspec.yaml`. No missing
source input or actual build failure was established by this review.

The original package inspector hashed six product-owned assets but omitted
the three shared documents used by that entry. The inspector now adds:

| Logical Flutter asset key | Source below resolved core root |
| --- | --- |
| `packages/qfli_studio_core/assets/content/tutorials.json` | `assets/content/tutorials.json` |
| `packages/qfli_studio_core/assets/content/examples.json` | `assets/content/examples.json` |
| `packages/qfli_studio_core/assets/tutorials/lua.json` | `assets/tutorials/lua.json` |

The core root is resolved from this app's actual
`.dart_tool/package_config.json`, using the config file URI as the base for
`rootUri`. The current recorded URI is `../../qfli_studio_core`. The inspector
requires a single core package entry, configVersion2, a local file URI, an
existing directory, and canonical equality with the declared sibling
`../qfli_studio_core`. It also checks the app's existing block-form dependency
declaration in `pubspec.yaml`. Unsupported/missing declarations, unreadable or
malformed config, duplicate/missing package entries, nonlocal URIs, unresolved
roots and root mismatches produce an issue and leave the package gate false.
The inspector never falls back to hashing an arbitrary neighboring checkout.

All asset receipts now retain logical key, source path, expected source byte
length/SHA256, archive match count, archive path, packaged bytes/SHA256 and
`sourceMatches`. Missing/unreadable shared files, absent/duplicate archive
matches and byte mismatches fail the package gate. Failed bindings retain
three explicit shared-asset receipts with unavailable source proof. Existing
local asset coverage, all21 Lua plus6 Script required exports, ELF/ABI/alignment
checks, INTERNET refusal and unconditional `deviceGatePassed:false` remain.

Python syntax AST parsing passed; static constant inspection retains exactly
three shared mappings,21 Lua exports and6 Script exports. The resolver,
asset comparisons and a real HAP have not been executed in this pass; actual
package acceptance remains UNRUN pending the explicit host/build grant.

## Build command after an explicit grant

The following is the x64 command, conditional on the root's later target
qualification. It has not been run:

```powershell
& .\tools\build_ohos_audit.ps1 `
  -Target 'bin/script_acceptance.dart' `
  -Platform 'ohos-x64' `
  -LogPath 'build/offline-ide-audit/full1282-ohos-x64-20261024.log' `
  -ReportPath 'build/offline-ide-audit/full1282-ohos-x64-package-20261024.json'
```

For a qualified ARM64 target, change the platform to `ohos-arm64` and use
separate ARM64 log/report names. The old API26 x64 emulator and old exact
`127.0.0.1:5555` reservation do not qualify the current unknown target. Root's
prior read-only observation was `192.168.68.207:46551`; SQL122 must reconcile
identity, ownership and onward queue before any Lua target action.

The finalized builder now resolves Flutter from the single `flutter.sdk` in
OHOS `local.properties`, with an optional explicit `-FlutterSdkRoot` that must
agree with it and the actual Flutter package root. It invokes that SDK's cached
Dart/Flutter snapshot and retains source/HEAD/command/artifact receipts; see
`lua-build-binding-20261024.md`. PATH selection is superseded. This change is
source-ready and AST-checked, not yet exercised by a real build.
`--no-pub` requires a current package config. Preserve the named global build slot: its local
`.build.lock` prevents only another invocation of this product helper, and the
helper itself does not establish a host grant or global deadline.

After inspection, the builder preserves a hash-named
`build/offline-ide-audit/script_acceptance-<first16 SHA256>.hap`. Bind its full
SHA256 to the target, source/core snapshot, dependency configuration, exact
build invocation and log. The historical
`lua_catalog_audit-b0db102354fba64f.hap` remains a682Lua artifact, not full1282
evidence, even though its older package checks passed.

## ABI, offline and signing preservation

The entry Hvigor plugin selects native ABI filters and opposite-ABI exclusions
in memory from the explicit Flutter target. It retains ARM64 as the default;
no checked-in profile rewrite is needed. Shared native CMake includes both Lua
and Script engines. Final inspection checks all packaged libraries, including
Flutter and both bridge libraries, against the requested ABI.

Native `EntryAbility` refuses `openAgreement` and `openUrl` before inspecting
arguments, using exact code `OFFLINE_ONLY`. The current module requests only
READ_PASTEBOARD and no INTERNET permission. The target audit requires actual
native refusal for both device gates; injected host checks cannot provide it.
Other production UI/workspace/offline domains are explicitly not implied by
this runtime audit.

Root signing configuration/references are present. No signing material was
opened. The builder prefers a fresh `*-signed.hap` but permits an unsigned
fallback, so filename selection is not signature proof. SDK verification must
bind the exact preserved HAP SHA256 before installation; this remains UNRUN.
Selected Dart-entry proof likewise belongs to the recorded build invocation
and actual audit marker, not archive filename inference. Existing signing,
icons, startup and device-type WIP must remain intact. The builder restores its
temporary Java options and working directory in `finally`.

## Device report retrieval and remaining gates

Only after SQL reconciliation, a fresh device grant and qualified artifact:

1. Retain the existing production app/package restoration plan and source
   snapshot. Install/launch the exact verified audit HAP within the owned slot.
2. Observe fresh `QFLI_SCRIPT_OFFLINE_PLATFORM` and
   `QFLI_SCRIPT_ACCEPTANCE` markers. The latter supplies the actual report path,
   SHA256, operating system and ABI. Correlate the report's `startedAt` with this
   launch; the top-level report filename is reused across runs.
3. Retrieve the actual app-owned report and its three companions, using only
   the target's explicitly permitted sandbox access:

   ```text
   qfli-script-acceptance.json
   qfli-script-acceptance.json.lua.json
   qfli-script-acceptance.json.script.json
   qfli-script-acceptance.json.script.json.cases.jsonl
   ```

4. Preserve all raw results/checkpoints and host-side hashes. Match the top
   hash to the marker, the Lua subreport hash to its top-level receipt, all
   runtime library hashes to the inspected artifact, and all packaged asset
   hashes to the frozen source receipts. Require actual OHOS identity, complete
   inventory/execution, native offline proof and successful probes. Keep strict
   and terminal-line policies distinct; current480 Lua remains exact in both.
5. Restore the ordinary `lib/main.dart` application through the normal matching
   ABI build/install process, verify startup, publish terminal evidence and
   explicitly release to the coordinated next owner.

The audit page currently exposes selectable paths/summaries but no file export
action. App storage is confirmed via `AppPaths`/`AppPrivateRoots`; the installed
path_provider plugin uses the app's files directory. None of that proves a
host-visible path or permission for `hdc file recv`. Root must qualify permitted
retrieval before spending the full audit window. If direct access is denied,
a separately owned product-only audit export path is needed; no such exporter
was added here. Do not guess sandbox prefixes or treat log summaries as the
full1282 per-case report.

Open gates remain final source/full-suite/full1282 host verification after
subsequent edits, actual repaired-inspector execution, current HAP build and
signature, target ABI/access qualification, installed full audit/probes/report
collection, production restoration and the wider R1–R13 sibling/publication
requirements. This repair closes only the missing shared-asset source-binding
implementation gap.
