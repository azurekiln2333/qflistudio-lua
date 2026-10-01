# Linux Native Runtime Audit

## Result

The existing Linux build configuration includes the shared Lua 5.4.8 C bridge,
bundles its shared library, and matches the Dart FFI loader. This source review
found no Linux-specific implementation gap for run, syntax check, or bytecode
compilation. It does not establish that a Linux application build or runtime
test passes.

Only this research file was written. Linux, native, and Dart sources were
inspected without modification.

## Build and Packaging Evidence

- `linux/CMakeLists.txt:3` enables both C and C++ in the Flutter runner project.
- `linux/CMakeLists.txt:59` adds `../native` to the application build with a
  separate `qfli_lua_native` build directory.
- `native/CMakeLists.txt:4` requires C11. Lines 7-11 compile the vendored Lua
  sources and `src/qfli_lua.c` into the shared `qfli_lua_engine` target, excluding
  upstream `lua.c` and `luac.c` command-line entry points.
- `native/CMakeLists.txt:16` sets the library artifact name to `qfli_lua`, giving
  Linux `libqfli_lua.so` without colliding with the Flutter executable target.
- `native/CMakeLists.txt:22` enables upstream POSIX and `dlopen` support for
  Unix, and links the math library and CMake's platform dynamic-loader library.
- `linux/CMakeLists.txt:97` installs that exact target artifact into the
  application bundle's `lib/` directory. The runner install RPATH is
  `$ORIGIN/lib` at line 17.
- `lib/lua_toolchain.dart:152` opens the explicit library override if supplied;
  its Linux default is `libqfli_lua.so`. It checks the resolved executable's
  directory, then the executable's `lib/` directory, then
  `native/build/linux/libqfli_lua.so` for development runs. The bundled path and
  installed library path agree.
- `native/src/qfli_lua.h:9` exports bridge functions with default visibility on
  non-Windows platforms. Result layout uses pointer-sized `size_t` lengths,
  mirrored by `@UintPtr()` in Dart.

## Shared C Semantics

- `native/src/qfli_lua.c:417` loads text or bytecode for execution, followed by
  the upstream protected call. It uses a fresh Lua state for every operation.
- `native/src/qfli_lua.c:469` checks text using the upstream loader without
  executing the chunk.
- `native/src/qfli_lua.c:487` loads text and line 495 dumps standard Lua
  bytecode. The output uses binary file mode.
- Linux uses the POSIX monotonic clock (`CLOCK_MONOTONIC`, line 60) and C11
  atomic cancellation tokens (line 36). The instruction hook checks both.
- Per-state project module paths and file wrappers are installed at lines
  399-400. They resolve relative paths without process-wide directory changes.
- Lua closes before the final captured result buffers transfer ownership
  (line 431). Explicit byte lengths preserve embedded NUL output; Dart decodes
  malformed UTF-8 with replacement and frees every result once.
- Timeout and cancellation retain their documented cooperative limits for
  native blocking calls, replaced hooks, and finalizers.

## Local Environment Inventory

Read-only Windows inventory was used. No system or VM was started, no tools
were installed, and no network or device connection was attempted.

- The host is Windows. No `docker` or `podman` command was found on PATH, and no
  Docker/Podman process was visible.
- `bash.exe` resolves to the Windows WSL launcher, not an independent Linux
  execution environment. It was not invoked.
- The WSL registry contains `Ubuntu`, `qfli-terminal-test`,
  `qfli-terminal-al3-clean`, `qfli-terminal-al3-test`, and `qfli-java-build` as
  version 2 registrations. Persisted registrations do not establish current
  access or a usable test environment.
- `WslService` and `vmcompute` are running; `LxssManager` is stopped. Those
  service states also do not establish access to a distribution.
- `qemu-system-x86_64-headless` is visible. Its executable path is inaccessible
  to the current inventory, so it was not classified as a usable Linux host or
  accessed for testing.
- `native/build/linux` and `build/linux` are absent. The checkout contains the
  Linux runner sources but no existing Linux build artifact to inspect.
- The main agent's earlier WSL inventory failed with `E_ACCESSDENIED`; the
  escalated inventory attempt encountered approval service HTTP 503. This
  audit did not retry that action or try alternate WSL launch paths.

No authorized, demonstrably usable Linux execution environment was found.
Linux CTest, Linux Dart/Flutter runtime tests, and Linux application packaging
were therefore not attempted, as required by the user's testing boundary.

## Future Linux Verification

When an accessible Linux environment with a C compiler and CMake is available,
the existing independent native CMake project can build and run
`qfli_lua_test`. That test covers source and bytecode execution, syntax failure,
project files, stdout/stderr capture, embedded NUL bytes, malformed bytes,
warning controls, Lua conversions, exit statuses, timeout, and cancellation.

A Flutter Linux host additionally needs its Linux desktop dependencies
(including GTK development packages). Verify the application install bundle
contains `lib/libqfli_lua.so`, then exercise run, check, compile, and compiled
bytecode execution using the packaged app or a test runner that loads the
bundled library. A Windows C test of shared code is useful cross-platform
evidence, but cannot replace those Linux-specific build and loader checks.
