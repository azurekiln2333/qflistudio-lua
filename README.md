# qfli_lua

This Flutter app is an independent Git repository. Check out `qfli_studio_core` next to it before resolving dependencies.

```text
checkout-parent/
  qfli_studio_core/
  qfli_lua/
```

Run `flutter pub get` here, then `flutter run` for the target device. The shared editor patch is provided by `../qfli_studio_core/vendor/re_editor`.

Lua 5.4.8 is built into the app for Android, HarmonyOS, Windows, and Linux.
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
