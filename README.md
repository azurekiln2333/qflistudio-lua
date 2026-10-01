# qfli_lua

This Flutter app is an independent Git repository. Check out `qfli_studio_core` next to it before resolving dependencies.

```text
checkout-parent/
  qfli_studio_core/
  qfli_lua/
```

Run `flutter pub get` here, then `flutter run` for the target device. The shared editor patch is provided by `../qfli_studio_core/vendor/re_editor`.

The native build configurations embed Lua 5.4.8 for Android, HarmonyOS,
Windows, Linux, iOS, and macOS. Execution, syntax checks, and bytecode
compilation all use the shared C bridge and official Lua sources.
The editor's Run button executes Lua source or a compiled `.luac` entry without
requiring a system Lua installation.
The editor's More menu checks the current Lua file and compiles it to a `.luac`
file beside the source, saving the current edits first.
The standalone commands are
`dart run bin/qfli_lua.dart run <file>`, `check <file>`, and
`compile <file> [output.luac]`. Native build, license, and test details are in
[`native/README.md`](native/README.md).

For a quick desktop smoke test, run `dart run bin/qfli_lua.dart run
examples/hello.lua`. It prints `sum` and `55` separated by a tab.

iOS and macOS link the engine into Runner and resolve its symbols through
Dart FFI. Windows and Linux bundle a shared library; Windows also adapts
UTF-8 script and project filenames to the Windows file APIs. No system Lua
installation is required on these targets.

Current verification covers Windows native tests and the packaged standalone
command program, Flutter tests, and static analysis. A full Windows Flutter
app requires Visual Studio. Apple builds require Xcode; Linux builds require
an accessible Linux environment. These platform builds and runtime checks
were unavailable on this Windows host. See the
[platform verification record](.trellis/tasks/10-01-native-platforms/verification.md)
for the Android packaging result and remaining platform verification limits.
