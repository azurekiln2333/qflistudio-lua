# Lua toolchain design

## Engine and boundary

Vendor the unmodified official Lua 5.4.8 source and license. A small C bridge owns one `lua_State` per operation and calls the upstream loader, dumper, and VM. Dart calls the bridge through FFI from a worker isolate; the existing `ProgramRunner` translates results into terminal streams.

The C API accepts source/bytecode paths plus a project working directory and returns status, stdout, and stderr. It must close the state and free buffers on every path. Lua's package search paths must resolve project-local modules. Output capture must avoid redirecting process-wide stdout.

## Build

CMake builds one shared library from upstream Lua source plus the bridge. Android Gradle and HarmonyOS hvigor package the corresponding ABI library. Desktop CMake targets should use the same source and exported API. Builds and tests should not rely on a system Lua installation.

## Behavioral contracts

- Run: load a source file or compiled chunk, execute, return output and a nonzero status on a Lua error.
- Check: load only, return syntax diagnostics without executing the program.
- Compile: load source, dump a standard Lua binary chunk to the requested path, return diagnostics.
- Cancellation and runaway programs need a Lua instruction hook or an equivalent bounded execution path before claiming an interactive runtime complete.

## Risks

Flutter and native packaging differ per target. A successful host test alone cannot prove Android or HarmonyOS integration. Existing uncommitted HarmonyOS changes must be preserved and only task-owned changes staged.
