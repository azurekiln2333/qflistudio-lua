# Native CI platform research

## Independent native build

- `native/CMakeLists.txt` builds `qfli_lua_engine` and adds `native/script`.
- The targets need no Flutter SDK or sibling `qfli_studio_core` checkout.
- Lua output: `libqfli_lua.dll`, `libqfli_lua.so`, or `libqfli_lua.dylib`.
- Script output: `script/libqfli_script.dll`, `.so`, or `.dylib`.
- Windows Script requires GCC 9+ or Clang. Current CMake skips it under MSVC.
- Native host checks: `ctest --test-dir <build> --output-on-failure`; `python native/script/test_native.py <script-library>`.
- The Python probe accepts a library path and reads the retained TypeScript compiler from this checkout.

## OHOS public SDK

Choose OpenHarmony 5.1.0.107 / API 18, matching the app's compatible SDK level.

Official release documentation:
`https://raw.githubusercontent.com/openharmony/docs/master/en/release-notes/OpenHarmony-v5.1.0-release.md`

Official package URL:
`https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/ohos-sdk-windows_linux-public.tar.gz`

SHA256 URL:
`https://repo.huaweicloud.com/openharmony/os/5.1.0-Release/ohos-sdk-windows_linux-public.tar.gz.sha256`

Verified checksum:
`8c1f97df34812e45fa4f0e3275987b261e80622abb7c51392bb063f853451344`

HEAD returned 200. Content-Length is 3428583333 bytes. A 1 MiB range request returned 206 and confirmed these initial TAR members:

```text
manifest_tag.xml
ohos-sdk/
ohos-sdk/linux/
ohos-sdk/linux/ets-linux-x64-5.1.0.107-Release.zip
```

Extract the Linux native component with `tar --wildcards -xzf <archive> 'ohos-sdk/linux/native-linux-x64-*.zip'`, then unzip it. Resolve `native/build/cmake/ohos.toolchain.cmake` within the extracted SDK. The complete archive was not downloaded locally.

The installed SDK's official toolchain confirms:

- `-DCMAKE_TOOLCHAIN_FILE=<native>/build/cmake/ohos.toolchain.cmake`
- `-DOHOS_ARCH=arm64-v8a` or `x86_64` (also accepts `armeabi-v7a`)
- Toolchain sets `CMAKE_SYSTEM_NAME=OHOS` and `UNIX=TRUE`.
- Clang targets are `aarch64-linux-ohos`, `x86_64-linux-ohos`, or `arm-linux-ohos`.
- `OHOS_STL=none` is accepted for C-only builds.
- Toolchain discovers its own LLVM and sysroot paths.
- Native targets skip host CTest executable generation on OHOS.

Download once in one job and build both supported app ABIs sequentially. Preserve ELF headers, exports, hashes and build logs. These are OpenHarmony native libraries. This does not prove a Huawei HarmonyOS HAP build or device execution.

## Apple

Official CMake toolchain manual confirms `-DCMAKE_SYSTEM_NAME=iOS`, `-DCMAKE_OSX_SYSROOT=iphoneos` / `iphonesimulator`, `CMAKE_OSX_ARCHITECTURES`, and `CMAKE_OSX_DEPLOYMENT_TARGET`.

Source: `https://raw.githubusercontent.com/Kitware/CMake/master/Help/manual/cmake-toolchains.7.rst`

Recommended native deliverables:

- macOS arm64 and x86_64 shared libraries, with host execution for matching runner architectures.
- iOS arm64 device static archives.
- iOS Simulator arm64 and x86_64 static archives.
- One XCFramework per runtime, with device archive and a combined simulator archive.

Current CMake hardcodes SHARED. Add a narrow static build option for iOS. Suppress host executable tests during cross compilation. The existing iOS runner already uses `LUA_USE_IOS` and force-includes `ios/Runner/QfliLuaIos.h` only for `liolib.c`; CMake iOS compilation must preserve that behavior because iOS has no `popen`. The header redirects the operation to a Lua error without modifying upstream sources.

Suggested packaging command shape:

```sh
xcodebuild -create-xcframework \
  -library <iphoneos/libqfli_lua.a> -headers <lua-public-header-directory> \
  -library <iphonesimulator/libqfli_lua.a> -headers <lua-public-header-directory> \
  -output qfli_lua.xcframework
```

Repeat for Script. Static archives do not establish FFI symbol retention in the final app. Consumers must link the needed symbols; the current Apple app embeds Lua directly.

## Android

Project pins NDK `27.0.12077973`. Native CMake can use its `build/cmake/android.toolchain.cmake` independently of Gradle. Use ABI matrix `armeabi-v7a`, `arm64-v8a`, `x86_64`, `ANDROID_PLATFORM=android-21`, and `ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON`. Both runtime libraries are output for each ABI. Cross compilation and ELF export inspection do not establish device runtime tests.

## Suggested artifacts

Per platform/architecture: both runtime libraries, both public bridge headers, upstream licenses, SHA256 manifest, toolchain/build metadata, build logs, and execution or inspection reports. Distinguish host test results from cross-build inspection. Do not label absent device execution as passed.
