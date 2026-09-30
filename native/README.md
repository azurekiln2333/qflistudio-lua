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
  retain Flutter's split configuration.
- HarmonyOS hvigor builds the library through
  `ohos/entry/src/main/cpp/CMakeLists.txt` and includes it in the HAP.
  The native configuration supports ARM64 devices and x86_64 simulators; use
  `flutter build hap --release --target-platform ohos-x64` for an x86_64 build.
  The entry Hvigor plugin selects native ABIs from `TARGET_PLATFORM` for each
  Flutter invocation, so an ARM64 HAP does not advertise an x64-only Lua library
  (or the reverse). IDE builds without this parameter retain both native ABIs.
- Windows and Linux Flutter CMake build and bundle the same library.
  The CMake target is `qfli_lua_engine`; its output name is `qfli_lua`, with
  the `lib` prefix retained on Windows. Unix builds enable upstream POSIX
  and dynamic-library support.

For an independent Windows host test with MinGW, configure this directory
with CMake, build it, then run `ctest --test-dir <build-dir> --output-on-failure`.
The Flutter tests load the host library from `native/build/windows` or
`native/build/linux` when run from the checkout.

For desktop use, `dart run bin/qfli_lua.dart version`, `run <file>`,
`check <file>`, and `compile <file> [output.luac]` use the bundled library.
The device probe at `tool/lua_device_probe.dart` is an independent test entry
point; it is not part of the product's startup flow.

Release app builds use `lib/main.dart`. For Android, Release mode currently
uses the project's default test signing key; configure a distribution key
before publishing. The build mode and signing certificate are independent.
