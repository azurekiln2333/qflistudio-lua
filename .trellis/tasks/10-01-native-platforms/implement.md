# Implementation

- [x] Inspect current native bridge, platform wiring and prior verification.
- [x] Audit Android configuration and verify available package/runtime paths.
- [x] Wire Lua C sources and exported symbols into Apple Runner targets.
- [x] Implement Apple FFI loading and any confirmed shared portability gaps.
- [x] Rebuild/run available Windows native tests and Dart integration checks.
- [x] Check Linux wiring and record available-toolchain findings.
- [x] Run scoped analysis/regressions and review every platform's final wiring.
- [x] Update specifications, native README and platform verification evidence.

## Completed Verification

- Windows native CTest: 1/1 passed; full Flutter tests: 44 passed; app analysis:
  no issues. The Unicode path regression failed before the UTF-16 CRT adapter
  and passes with it, including module loading, file operations and bytecode.
- A standalone Windows AOT CLI loads the adjacent DLL and passes version,
  syntax check, compilation and compiled-bytecode execution (Lua 5.4.8).
- Apple Runner configuration checks pass for the shared bridge and 32 Lua
  translation units, platform defines, iOS subprocess restriction and release
  symbol retention. Xcode compilation/runtime is unavailable on this host.
- Linux CMake packaging and executable-relative FFI loading match. No confirmed
  Linux source gap; no accessible Linux build/test environment was found.
- Android release rebuild passed with NDK 27 flexible page sizes enabled.
  All three ABIs contain matching Flutter/app/Lua libraries and nine bridge
  exports. The 64-bit Lua LOAD segments now align to 16 KiB; APK ZIP alignment
  verification also passes. A later Android audit installed this release APK
  and passed ordinary-editor source execution, syntax checking, bytecode
  compilation and compiled-bytecode reload on the x86_64 16 KiB emulator.
- The startup follow-up remains intact: HarmonyOS native `Index.ets` matches
  the reference `qflistudio` file byte-for-byte. The signed HAP's compiled ArkTS
  matches the current build output and retains the verified first-frame path.

## Final Review

The full native-task review found no new defects in Apple source linkage,
process-symbol loading, iOS subprocess adaptation, release symbol retention,
Windows UTF-8 adapters, Linux packaging or Android ABI/alignment handling.
It reused the completed analysis and tests; no platform builds were repeated.
`verification.md` distinguishes source checks, actual host execution, package
inspection and skipped platform tests. The initial review did not perform
device operations or commits. The cross-product audit subsequently added
authorized Android application verification and prepared native-only delivery.

## Verification Boundary

Windows has a known local MinGW/CMake installation. Android SDK/build tools
are present. Apple requires Xcode on macOS, unavailable on this Windows host.
The first WSL inventory returned access denied; the approval service returned
503 during the authorized inventory attempt, so Linux availability is currently
unverified. Do not call unavailable platform builds as substitute evidence.
