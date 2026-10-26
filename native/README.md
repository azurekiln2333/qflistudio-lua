# Bundled Lua runtime

This app embeds the official Lua 5.4.8 release from
`https://www.lua.org/ftp/lua-5.4.8.tar.gz` (released 2025-05-21).
The downloaded archive had SHA-256
`4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae`.
The upstream source and its license are preserved under
`third_party/lua-5.4.8/`; see `doc/readme.html#license`.

`src/qfli_lua.c` is the app bridge. It calls the upstream loader, bytecode
dumper, and VM for `run`, `check`, and `compile`. It also captures standard
output/error, resolves project modules, bounds output to 1 MiB per stream,
and checks cancellation and time limits with an instruction hook. `os.exit` returns a
script exit code without terminating the Flutter process.

Each run resolves relative file paths against its project directory for
`io.open`, `io.input`, `io.output`, `io.lines`, `loadfile`, `dofile`,
`os.remove`, and `os.rename`. Absolute paths retain their meaning. The bridge
does not change the process working directory; commands started by
`os.execute` or `io.popen` inherit the app process's working directory.
On iOS, shell subprocesses are unavailable: upstream Lua prevents
`os.execute` from starting commands, and the iOS build makes `io.popen`
report an unsupported operation.

Each run's default `io.stdin` / `io.read` opens the project's regular
`input.txt`. A missing file supplies immediate EOF through an owned null-device
stream. Other metadata/open errors and non-regular paths fail before execution.
The Lua state closes its input descriptor without reading, redirecting or
closing the application's stdin. Explicit `io.input` selections keep upstream
semantics. All platforms use the same native implementation and unchanged ABI.

Captured `print`, `io.write`, file writes to stdout/stderr, and enabled Lua
warnings remain local to each run. Native result buffers carry explicit byte
lengths, including embedded NUL bytes. Dart decodes malformed UTF-8 with
replacement characters so binary output does not discard the execution result.

## Execution Limits

Cancellation and time limits are cooperative. The instruction hook checks
cancellation and elapsed monotonic time while Lua VM instructions execute.
Lua code can replace the hook through `debug.sethook` or catch its errors;
upstream Lua suppresses hooks in garbage-collection finalizers. Blocking
native calls, including external commands and file reads, cannot be preempted
by the hook. These operations can continue beyond the requested time limit.
`os.exit` requests an exit status without terminating the app process. The
bridge records the requested status, including calls caught by `pcall` or
made from finalizers. It interrupts the calling Lua function with a Lua error;
scripts can catch that error and continue executing subsequent code.

## Builds

- Android Gradle builds `libqfli_lua.so` from `native/CMakeLists.txt` for its
  configured ABIs and includes the result in the APK. For a universal APK,
  native ABI filters follow Flutter's `--target-platform`; split APK builds
  retain Flutter's split configuration. NDK 27 receives
  `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON`, enabling 16 KiB-compatible
  alignment for the 64-bit native libraries. Verify ELF LOAD and APK ZIP
  alignment in the final package after changing native build settings.
- HarmonyOS hvigor builds the library through
  `ohos/entry/src/main/cpp/CMakeLists.txt` and includes it in the HAP.
  IDE builds default to ARM64. Explicit Flutter targets select `ohos-arm64`,
  `ohos-x64`, or both, and the entry Hvigor plugin adjusts native compilation
  and packaging exclusions together. Each selected ABI includes Lua, Script
  and Flutter libraries; dependency HARs cannot introduce an unselected ABI.
  `tools/build_ohos_audit.ps1` builds and preserves a hashed HAP after inspecting
  actual ELF libraries, exports, compiler/content assets and offline permissions.
  A successful package inspection is separate from execution on a target.
- Windows and Linux Flutter CMake build and bundle the same library.
  The CMake target is `qfli_lua_engine`; its output name is `qfli_lua`, with
  the `lib` prefix retained on Windows. Windows installs `libqfli_lua.dll`
  beside the executable; Linux installs `lib/libqfli_lua.so`. Unix builds
  enable upstream POSIX and dynamic-library support.
- iOS and macOS Runner Xcode targets compile the shared bridge and all 32
  Lua library C files directly, excluding the Lua CLI entry points. All
  Debug, Profile, and Release configurations use C11 and the platform's
  upstream `LUA_USE_IOS` or `LUA_USE_MACOSX` definition. Apple bridge
  functions have `used` and default visibility, and Runner stripping keeps
  global symbols for Dart FFI. Only iOS `liolib.c` force-includes
  `ios/Runner/QfliLuaIos.h` to avoid unavailable subprocess APIs; the
  upstream source remains unchanged.

## Windows Filenames

The Windows native build force-includes `src/qfli_lua_windows.h` and adds
`src/qfli_lua_windows.c`. This adapts Lua's `fopen`, `freopen`, `remove`, and
`rename` calls from UTF-8 to the wide-character Windows CRT APIs. Source
loading, bytecode output, and script file operations therefore support
non-ASCII project paths without changing the upstream Lua sources. These
adapters are only compiled on Windows.

## FFI Loading

An explicit library path takes precedence. In the Apple application runners,
the engine is part of the linked process: iOS uses
`DynamicLibrary.process()`, and macOS uses it when `qfli_lua_version` is
present. Production Apple runners do not need a separate Lua dylib.

For desktop standalone/development commands, the loader searches beside the
resolved executable, its `lib/` directory, and then
`native/build/<platform>/`. macOS falls back to `libqfli_lua.dylib` for these
commands; Windows uses `libqfli_lua.dll`, and Linux uses `libqfli_lua.so`.
Android and HarmonyOS load the packaged `libqfli_lua.so` by name.

## Verification

For an independent Windows host test with MinGW, configure this directory
with CMake, build it, then run `ctest --test-dir <build-dir> --output-on-failure`.
The Flutter tests load the host library from `native/build/windows` or
`native/build/linux` when run from the checkout.

Run native and platform checks only when their toolchains are available.
Windows native CTest, Flutter tests/static analysis, and an AOT command
program beside its DLL have been verified. The full Windows Flutter app
requires Visual Studio; Apple builds require Xcode; Linux requires an
accessible Linux environment. Those platform builds/runtime checks were
not run on this host. Android package inspection and the exact task evidence
are recorded in
[`verification.md`](../.trellis/tasks/10-01-native-platforms/verification.md).

The same release APK was installed and run on emulator-5560 (Android API 37,
x86_64, 16 KiB pages). The ordinary editor passed source execution, native
syntax checking, bytecode compilation and subsequent `dofile` loading of the
generated bytecode; both source and compiled execution exited successfully.

For desktop use, `dart run bin/qfli_lua.dart version`, `run <file>`,
`check <file>`, and `compile <file> [output.luac]` use the bundled library.
The device probe at `tool/lua_device_probe.dart` is an independent test entry
point; it is not part of the product's startup flow.

Release app builds use `lib/main.dart`. For Android, Release mode currently
uses the project's default test signing key; configure a distribution key
before publishing. The build mode and signing certificate are independent.
