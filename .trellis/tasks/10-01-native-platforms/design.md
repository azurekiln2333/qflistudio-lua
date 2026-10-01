# Design

All platforms share `native/src/qfli_lua.c`, the upstream Lua sources and the
existing `LuaToolchain` FFI contract. Android Gradle and desktop CMake already
include the shared library; verify their build outputs and local runtime.

The missing Apple integration belongs in the existing Runner Xcode targets.
Compile the vendored Lua C files and bridge there, preserve the upstream source,
and make native exports resolvable from Dart. Prefer static linking and
`DynamicLibrary.process()` on iOS; use the same linked-symbol approach on macOS
if it fits its Runner and avoids an unbundled dylib path.

Main agent owns shared C/CMake, Dart loading and common tests/documentation.
Apple worker owns `ios/` and `macos/` build wiring. Android worker owns Android
build/configuration verification and narrowly needed corrections. Linux
reviewer owns source/toolchain investigation and research notes only.

Keep current dirty content/startup changes. Native library naming and Flutter
ABIs must remain consistent. Tests on unavailable Apple/Linux environments are
not attempted; record source-level checks separately from runtime evidence.
