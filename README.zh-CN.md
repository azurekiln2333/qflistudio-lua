# qfli_lua

[English](README.md) | 简体中文 | [繁體中文](README.zh-TW.md)

## 用途

本 App 是离线 Script 开发环境。产品名是 QFLIScript。
App 运行 Lua、JavaScript、TypeScript 与 Shell 代码。
Lua 引擎随 App 打包。
JavaScript 与 TypeScript 需要 Script 桥接库。
Apple 项目不含 Script 桥接库。
默认 MSVC 构建也不含此库。
Shell 依赖系统 shell。

本仓库是独立 Git 仓库。请把 `qfli_studio_core` 放在同一层目录。

```text
上级目录/
  qfli_studio_core/
  qfli_lua/
```

在仓库根目录运行 `flutter pub get`。
然后运行 `flutter run` 部署到目标设备。
共用编辑器补丁来自 `../qfli_studio_core/vendor/re_editor`。

## 当前功能

- 「运行」按钮运行 Lua 源码或 `.luac` 字节码。
- 「运行」按钮运行 `.js`、`.mjs` 与 `.ts` 文件。
- 编辑器提供「检查 Lua 语法」操作。
- 编辑器提供「编译 Lua 字节码」操作。
- 工具页列出九个独立工具。
- 终端接受 `lua` 与 `luac` 命令。
- 内容页内置 240 个示例与 23 篇教程。
- 编辑器显示真实语法诊断。诊断带范围与波浪线。
- 问题面板可跳到对应文件位置。
- 侧边栏记住展开状态。工作区可同时打开多个项目。
- 源码调试器支持断点与单步。

工具页的九个工具如下。

| 工具 | 用途 |
|---|---|
| Lua 源码调试 | 断点与单步 |
| Lua 语法检查 | 只解析，不运行 |
| Lua 字节码 | 查看头部、函数与常量 |
| Lua 模块解析 | 显示 `package.path` 与 `require` 依赖 |
| Lua 字符串字面量 | 转换字符串与转义序列 |
| Lua 模式匹配 | 测试模式并显示捕获 |
| JavaScript 语法检查 | 只编译，不运行 |
| TypeScript 转译 | 输出 JavaScript |
| Shell 语法检查 | 报告语法与可移植问题 |

## 离线与运行边界

独立版关闭登录接口。
独立版关闭社区接口。
独立版关闭云端接口。
编辑器与内置语言工具在本地运行。

Lua 使用内置 Lua 5.4.8。源码与字节码都能运行。
源码与字节码必须使用同一个 VM 版本。
每次运行把相对路径解析到项目目录。
桥接不改变进程工作目录。

JavaScript 与 TypeScript 使用内置 QuickJS 与 TypeScript 5.9.3。
QuickJS 不含 Node、浏览器 API、计时器与网络绑定。
模块导入必须写出扩展名。项目外的导入会返回错误。
TypeScript 只报告语法与选项诊断。它不做类型检查。
TypeScript 源码先转译，再由 QuickJS 运行。
每次 Script 操作使用全新的 QuickJS 运行时。
堆上限 256 MiB，栈上限 2 MiB。
单个 QuickJS 源文件上限 512 KiB。
Lua 不另外设定这三项限额。
项目上限 256 个源文件与 8 MiB。

Shell 使用系统 shell。移动平台也许没有可用的 shell。
Android 与 HarmonyOS 查 `/system/bin/sh` 或 `/bin/sh`。
桌面查 `sh` 或 `bash`。
Shell 的 `input.txt` 只接受一般文件。

Lua 与 QuickJS 默认限时 10 秒。
两种引擎的每条输出流上限是 1 MiB。
每次运行可以取消。取消返回状态 130。
缺少运行环境时返回状态 127。
`os.exit` 只返回退出码。它不结束 App 进程。
取消是协作式。它也许无法中断阻塞的原生调用。

终端只提供文件命令与 `lua`、`luac`。
终端不支持管道、重定向、串接与变量展开。
终端对不支持的命令报告原因。它不假装成功。

调试器运行已保存的源码。它在断点处暂停。
变量检查只读基本类型。它不调用用户表达式。
对象内容不可用。

## 构建与检查

请使用支持 HarmonyOS 的 Flutter SDK。
请保持 SDK 路径与 `ohos/local.properties` 一致。
先获取依赖。

```text
flutter pub get
```

再运行静态分析与测试。

```text
flutter analyze
flutter test
```

原生 Lua 桥接用 CMake 构建。主机测试用 CTest。

```text
cmake -S native -B native/build/host -G Ninja
cmake --build native/build/host
ctest --test-dir native/build/host --output-on-failure
```

JavaScript 与 TypeScript 引擎单独构建。
编译器须为 GCC 9 以上或 Clang。
请把编译器路径替换为本机路径。

```text
cmake -S native -B native/build/script-windows -G Ninja -DCMAKE_C_COMPILER=C:/path/to/gcc.exe
cmake --build native/build/script-windows --target qfli_script_engine
python native/script/test_native.py
```

命令行工具使用同一份内置库。

```text
dart run bin/qfli_lua.dart run <file>
dart run bin/qfli_lua.dart check <file>
dart run bin/qfli_lua.dart compile <file> [output.luac]
dart run bin/qfli_lua.dart version
```

桌面快速验证运行 `examples/hello.lua`。
输出是 `sum` 与 `55`，两者以制表符分隔。

内容验证器逐条运行示例。
验证器比对实际输出。

```text
dart run tool/verify_lua_content.dart
```

完整审计覆盖 1,282 处位置。
其中 682 处来自 Lua。600 处来自 JS、TS 与 Shell。
两个审计入口都要用 Flutter 启动。
`dart run` 无法启动这两个入口。

```text
flutter run -t bin/script_acceptance.dart
flutter run -t bin/lua_catalog_audit.dart
```

后一个入口只覆盖 Lua。
OHOS 构建脚本是 `tools/build_ohos_audit.ps1`。
该脚本保留包摘要与检查报告。

构建细节见 [`native/README.md`](native/README.md)。

## 目录

```text
lib/          编辑器、工具链、调试器与工具页
native/       Lua 与 QuickJS 原生桥接
test/         Flutter 测试
bin/          命令行工具与验收脚本
tool/         内容构建与验证脚本
tools/        构建检查脚本
assets/       图标、内容 JSON 与 TypeScript 编译器
examples/     示例程序
scripts/      文档检查脚本
android/ ios/ linux/ macos/ ohos/ web/ windows/   平台项目
```

## 许可证

本仓库根目录没有 LICENSE 文件。

Lua 5.4.8 使用 MIT 许可。原始许可保留在 `native/third_party/lua-5.4.8/`。
QuickJS 使用 MIT 许可。许可文件在 `native/script/quickjs/LICENSE`。
TypeScript 5.9.3 使用 Apache-2.0 许可。
许可文件在 `assets/runtime/TYPESCRIPT-LICENSE.txt`。

## 验收限制

主机检查不等于目标设备通过。
当前没有可连线的 OHOS 目标设备。
HAP 打包检查与设备运行是两个独立关卡。
2026 年 10 月 26 日的主机测试结果如下。
测试通过 373 项。
测试跳过 1 项。
测试没有失败项。
完整审计的 20 项主机断言通过。
审计覆盖 1,282 处位置。
800 处历史末尾换行字节差异仍保留。
这不表示 1,282 处严格字节比对全通过。
OHOS 原生探针为 `not_evaluated`。
本次未打包新的 HAP。
本次未运行目标设备验收。
验证进程已自然结束。
末次终端确认超过 330 秒协调上限。
完整交接时限未通过。
这些结果只适用于当时的源码快照。
后续生产源码修改仍需新的完整验证。
目标设备验收仍然开放。
一次完整的目标验收仍等新的运行时段。
内容验证在主机运行。这是主机证据，不是设备证据。
Windows 完整 App 需要 Visual Studio。
Apple 构建需要 Xcode。Apple 只编译 Lua 桥接。
Linux 构建需要可用的 Linux 环境。
这台 Windows 主机没有运行上述平台构建。
Script 引擎的 Apple 打包尚未验证。
Android 打包结果见
[平台验证记录](.trellis/tasks/10-01-native-platforms/verification.md)。