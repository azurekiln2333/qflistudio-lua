# Source gate attempt and repair — October 24, 2026

C464 explicitly released its terminal host window to Lua. Lua465 accepted
source, full suite and full1282 acceptance with a300-second validation budget.
Tool session29986 was polled to terminal exit1. The immutable attempt is:

`build/offline-ide-audit/final-verification/20261024T021029151Z-97999ba811194ae798abf95cc390c92b/run.json`.

- Formatting:74 files,2 changed, exit0. Only the new workspace test and changed
  studio debugger test were normalized.
- Package analysis: exit1,45 issues.43 came from preserved, incomplete Dart
  review copies under ignored `build/offline-ide-audit/prior125-source`;
  two were redundant public API imports in the studio debugger regression.
- Suite and full1282 acceptance: UNRUN after the failed source phase.
- Source phase PID66172 exited1; its Job tree was empty, with no timeout or
  residual-tree termination. Validation elapsed11.527 seconds.
- Automatic publication PID84092 exited0 with an empty Job, appending exact
  terminal/release466 to Note447. Lua retains no reservation from464/465.

The new fingerprint path executed:376 source files, product HEAD327b7c54d04b,
core HEAD36697b04836a. Before/after manifest SHA256 values are
`96966f74b933ac868e4b85c3f14b9754da9cf5d204bacccc88b0672edabb9251` and
`a5a70b21e68b03f587c7b6854754a69cb8941a6bda8bfc9a002101de9dbf8a91`.
The only differences were the two permitted product Dart formatter changes;
core source and both HEADs remained identical. This is evidence for the failed
source attempt, not a passing analysis or test result.

After release, root added `build/**` to the existing analyzer exclusions and
removed the two redundant imports. Historical copies and their raw bytes stay
preserved. The next wrapper also fingerprints `analysis_options.yaml`; its
SHA256 is`d76c68bd58b1275d281c656f3e30ffaba8a12276714f4c1c2c2959e13aa15ffd`.
PowerShell AST parsing passed; the repaired source gate remains UNRUN.

The next request474 is a new source -> full1282 acceptance -> suite gate.
The corpus comes before the newly added UI fixture so an independent corpus
result can be retained if later UI work needs repair. Each phase still records
its exact source fingerprint, result and owned-process cleanup.

The attempted builder SDK/binding/receipt enhancement had not landed before
freeze. Builder SHA256 remained
`7554fd0982eb5e2d4512289e2841232e234f4bb2b1abbcbb01a032eb72d61c8d`.
That enhancement resumed only after terminal release and remains separate
from this failed attempt. Fresh full1282 HAP/signature/current-device gates,
final source review, commits and ordinary pushes remain open.
