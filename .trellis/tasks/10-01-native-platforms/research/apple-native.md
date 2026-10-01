# Apple Native Integration

## Implementation

Both `ios/Runner.xcodeproj/project.pbxproj` and
`macos/Runner.xcodeproj/project.pbxproj` compile the same existing
`native/src/qfli_lua.c` and all 32 vendored Lua 5.4.8 library translation units
directly in their Runner source phases. The Lua CLI sources (`lua.c`,
`luac.c`), native test, and Windows path adapter are excluded. Paths resolve
to the shared native directory; no upstream files are copied or edited.

The iOS Debug and Release xcconfigs include `Flutter/NativeLua.xcconfig`;
Profile already uses the Release xcconfig. The macOS Runner's three target
configurations use `Runner/Configs/AppInfo.xcconfig`, which includes its
`NativeLua.xcconfig`. Both native configs select GNU C11 for bridge atomics,
inherit prior definitions and include paths, and set `LUA_COMPAT_5_3`.
iOS uses `LUA_USE_IOS`; macOS uses `LUA_USE_MACOSX`. Lua's upstream
`luaconf.h` enables POSIX and DLOPEN for both. Darwin provides the math and
dynamic loader functions through its default system library.

## FFI and Release Retention

The app must load these linked interfaces with `DynamicLibrary.process()`.
No external Lua dylib needs bundling for the production Apple runners.
The main agent updated the bridge's Apple `QFLI_API` to `used` and default
visibility. This preserves unreferenced FFI entry points through compilation
and Mach-O dead stripping. Both Runner native configs use
`STRIP_STYLE = non-global`, preserving public names during final stripping.
Direct source linkage avoids static archive extraction concerns; broad
`-all_load`, `-export_dynamic`, and duplicate undefined-symbol anchors are
unnecessary.

## iOS System Restriction

Lua's `LUA_USE_IOS` already avoids `system()` in `loslib.c`, but the POSIX
branch of `liolib.c` still calls `popen` and `pclose`, unavailable on iOS.
Only that translation unit force-includes `Runner/QfliLuaIos.h`, overriding
Lua's existing customization macros. `io.popen` reports an unsupported
operation; it does not attempt an unavailable subprocess API. This small
platform adaptation keeps the upstream source unchanged and leaves macOS
subprocess behavior intact.

## Verification on 2026-10-01

Host: Windows. `xcodebuild` and macOS/Xcode are unavailable, so no Apple
build, simulator, device, or runtime test was attempted. Apple runtime and
packaged Mach-O symbol resolution remain unverified.

Source/configuration checks passed:

- Both OpenStep project files parse with balanced dictionaries, arrays, and
  quoted values; object keys are unique.
- Each Runner C source phase matches the complete shared 33-file set with
  no duplicates, missing files, or CLI/test/Windows-specific sources.
- Both native groups resolve to the existing shared bridge and Lua files.
- Debug, Release, and Profile resolve their native config includes and
  inherit GNU C11, correct Apple defines, shared headers, and non-global
  stripping without a target-level override.
- Only iOS `liolib.c` receives the forced platform header; macOS has no
  override.
- The current shared header includes Apple `used` plus default visibility.
- `git -c core.whitespace=cr-at-eol diff --check -- ios macos` passed.

The source checks used an in-memory Node OpenStep parser and filesystem
comparison against the vendored library sources. They establish project
wiring, not Apple compilation or runtime success.
