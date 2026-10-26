# qfli_lua

English | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

## Purpose

This app is an offline Script development environment.
The product name is QFLIScript.
The app runs Lua, JavaScript, TypeScript and Shell code.
Lua ships with the app.
JavaScript and TypeScript require the packaged Script bridge.
The Apple projects and the default MSVC build do not include that bridge.
Shell requires an available system shell.

This repository is a standalone Git repository.
Check out `qfli_studio_core` as a sibling directory.

```text
parent/
  qfli_studio_core/
  qfli_lua/
```

Run `flutter pub get` in the repository root.
Then run `flutter run` to deploy to the target device.
The shared editor patch comes from `../qfli_studio_core/vendor/re_editor`.

## Current features

- The Run button executes Lua source or `.luac` bytecode.
- The Run button executes `.js`, `.mjs` and `.ts` files.
- The editor offers a Check Lua syntax action.
- The editor offers a Compile Lua bytecode action.
- The Tools tab lists nine individual tools.
- The terminal accepts `lua` and `luac` commands.
- The content tab bundles 240 examples and 23 tutorials.
- The editor shows real syntax diagnostics with ranges and wavy underlines.
- The Problems panel jumps to the reported file position.
- The sidebar keeps its expansion state. A workspace opens several projects.
- The source debugger supports breakpoints and stepping.

The Tools tab contains these nine tools.

| Tool | Purpose |
|---|---|
| Lua source debugger | Pauses at breakpoints and steps |
| Lua syntax check | Parses the file and never runs it |
| Lua bytecode | Shows header, prototypes and constants |
| Lua module resolver | Shows `package.path` and `require` dependencies |
| Lua string literal | Converts between strings and escape sequences |
| Lua pattern matching | Tests a pattern and shows captures |
| JavaScript syntax check | Compiles only and never runs code |
| TypeScript transpile | Emits JavaScript |
| Shell syntax check | Reports syntax and portability problems |

## Offline and execution boundaries

The standalone profile disables login, community and cloud APIs.
Editing and bundled language tools work locally.

Lua uses the bundled Lua 5.4.8 release.
The app runs both source and bytecode.
Source and bytecode must come from the same VM version.
Each run resolves relative file paths inside its project directory.
The bridge does not change the process working directory.
`os.exit` records a script exit status. It does not terminate the app process.
Cancellation and time limits are cooperative.
They may not interrupt a blocking native call.

JavaScript and TypeScript use the bundled QuickJS and TypeScript 5.9.3.
QuickJS has no Node, browser API, timer or network binding.
A module import must name its file extension.
An import outside the project returns a runtime error.
TypeScript reports syntax and option diagnostics only.
It does not perform type checking.
The app transpiles TypeScript source first, then runs it in QuickJS.

Each Script operation uses a fresh QuickJS runtime.
The heap limit is 256 MiB and the stack limit is 2 MiB.
A QuickJS source file is limited to 512 KiB.
A project is limited to 256 source files and 8 MiB.
Each output stream is limited to 1 MiB.

Shell runs through a real system shell.
On Android and HarmonyOS the app looks for `/system/bin/sh` or `/bin/sh`.
On desktop it looks for `sh` or `bash`.
A mobile platform may have no usable shell.
A Shell project `input.txt` must be a regular file.

Lua and QuickJS use a 10 second time limit by default.
Their output streams are each limited to 1 MiB.
A user can cancel a run. Cancellation returns status 130.
A missing runtime returns status 127.

The terminal offers file commands plus `lua` and `luac`.
The terminal has no pipes, redirection, command chaining or variable expansion.
The terminal reports the reason for an unsupported command.
It never reports a fake success.

The debugger loads saved source files and runs the real VM.
It pauses at breakpoints and supports step into, step over and step out.
Variable inspection reads primitive values only.
It never evaluates user expressions.
Object contents are unavailable.

## Build and checks

Use the Flutter SDK with HarmonyOS support for this checkout.
Keep its path consistent with `ohos/local.properties`.
Fetch the dependencies first.

```text
flutter pub get
```

Then run static analysis and the tests.

```text
flutter analyze
flutter test
```

CMake builds the native Lua bridge. CTest runs the host test.

```text
cmake -S native -B native/build/host -G Ninja
cmake --build native/build/host
ctest --test-dir native/build/host --output-on-failure
```

The JavaScript and TypeScript engine builds separately.
It requires GCC 9 or newer, or Clang.
Replace `C:/path/to/gcc.exe` with the installed compiler path.

```text
cmake -S native -B native/build/script-windows -G Ninja -DCMAKE_C_COMPILER=C:/path/to/gcc.exe
cmake --build native/build/script-windows --target qfli_script_engine
python native/script/test_native.py
```

The command line tool uses the same bundled library.

```text
dart run bin/qfli_lua.dart run <file>
dart run bin/qfli_lua.dart check <file>
dart run bin/qfli_lua.dart compile <file> [output.luac]
dart run bin/qfli_lua.dart version
```

For a quick desktop smoke test, run `examples/hello.lua`.
The output is `sum` and `55` separated by a tab.

The content verifier runs every example and compares the actual output.

```text
dart run tool/verify_lua_content.dart
```

That verifier is host evidence.

The complete 1,282 location audit is a separate Flutter app entry.
It runs 682 Lua locations and 600 JavaScript, TypeScript and Shell locations.
Both audit entries import Flutter material, so `dart run` cannot start them.

```text
flutter run -t bin/script_acceptance.dart
```

`bin/lua_catalog_audit.dart` covers the 682 Lua locations only.
Launch it the same way.

```text
flutter run -t bin/lua_catalog_audit.dart
```

The OHOS package audit is a PowerShell script, not a Dart command.
It builds a HAP and keeps a hashed package report.
See [`tools/build_ohos_audit.ps1`](tools/build_ohos_audit.ps1).
Package inspection stays separate from device execution.

Build details are in [`native/README.md`](native/README.md).

## Layout

```text
lib/          Editor, toolchain, debugger and tool pages
native/       Native Lua and QuickJS bridges
test/         Flutter tests
bin/          Command line tool and acceptance scripts
tool/         Content generation and verification scripts
tools/        Build audit scripts
assets/       Icon, content JSON and the TypeScript compiler
examples/     Example programs
scripts/      Documentation check scripts
android/ ios/ linux/ macos/ ohos/ web/ windows/   Platform projects
```

## License

The repository root has no LICENSE file.

Lua 5.4.8 uses the MIT license.
The original license stays in `native/third_party/lua-5.4.8/`.
QuickJS uses the MIT license.
Its license file is `native/script/quickjs/LICENSE`.
TypeScript 5.9.3 uses the Apache-2.0 license.
Its license file is `assets/runtime/TYPESCRIPT-LICENSE.txt`.

## Acceptance limits

A host check is not a target device pass.
No OHOS target device is currently reachable.
HAP package inspection and device execution are two independent gates.
On October 26, 2026, the host Flutter suite passed 373 tests and skipped 1.
No suite tests failed.
The full 1,282-location audit passed its 20 defined host assertions.
The 800 historical final-LF byte mismatches remain recorded.
These results do not establish strict-byte success at all 1,282 locations.
The OHOS native probe remains `not_evaluated`.
This run produced no new HAP and performed no target device acceptance.
The validation processes exited naturally.
Final terminal confirmation exceeded the 330-second coordination limit.
The complete handoff timing check did not pass.
These results apply only to that source snapshot.
Later production source edits require a new complete verification run.
Target device acceptance remains open.
A full target acceptance still needs a fresh run slot.
Content verification runs on the host. That is host evidence, not device evidence.
A full Windows app build requires Visual Studio.
An Apple build requires Xcode. Apple targets compile the Lua bridge.
Script engine packaging for Apple is not verified.
A Linux build requires a usable Linux environment.
This Windows host did not run those platform builds.
The Android packaging result is in the
[platform verification record](.trellis/tasks/10-01-native-platforms/verification.md).
