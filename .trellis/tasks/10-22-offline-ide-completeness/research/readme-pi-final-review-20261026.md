# README 三语终审（Pi，2026-10-26）

## 范围与方法

只读复核三份 README：`README.md`、`README.zh-CN.md`、`README.zh-TW.md`。
逐条对照当前源码与任务证据。
初次复核未改任何 README。
随后 root 把两份中文稿交回本会话修复。
本轮只改 `README.zh-CN.md` 与 `README.zh-TW.md`。
未运行 SDK、测试、构建或设备。
机械中文 lint 已运行。

证据基线：`327b7c5`。

## 结论

无阻断级错误。
root 已接受 F1、F2、F3、F4、F5、F8、F9。
两份中文稿已完成对齐修复。
root 更正 F9：1,282 含 682 处 Lua，另含 600 处 JS、TS、Shell。
F6 按授权删除冗余句。
F7 与 F10 未获接受，保留原状。
两份中文稿 lint 全通过。

## 修复状态（本轮）

| 编号 | 状态 | 修复内容 |
|---|---|---|
| F1 | 已修复 | 两份中文稿补两条 Lua 路径事实 |
| F2 | 已修复 | 两份中文稿补全新运行时与四项限额 |
| F3 | 已修复 | 两份中文稿补两个审计入口的 `flutter run -t` 命令 |
| F4 | 已修复 | 两份中文稿补 Shell 查找路径 |
| F5 | 已修复 | 繁体改为「Lua 不另外設定這三項限額」 |
| F9 | 已修复并更正 | 1,282 处写为 682 处 Lua 加 600 处 JS、TS、Shell |
| F8 | 已修复 | 两份中文稿补「仍然失败」与「仍然开放」与「仍待」 |
| F6 | 已按授权删除 | 繁体用途段删除引擎建句与 GCC 行 |
| F7 | 未修复 | 未获接受 |
| F10 | 未修复 | 未获接受 |

### 修复明细

F1：两份中文稿各补「相对路径解析到项目目录」与「不改变进程工作目录」。

F2：两份中文稿各补「全新 QuickJS 运行时」、「堆 256 MiB 与栈 2 MiB」、「源文件 512 KiB」、「项目 256 个源文件与 8 MiB」。
简体稿此前一条限额都没有。繁体稿此前缺项目限额。

F3：两份中文稿的代码块各列两条命令。
`flutter run -t bin/script_acceptance.dart`
`flutter run -t bin/lua_catalog_audit.dart`
两份中文稿各补一句：`dart run` 无法启动这两个入口。

F5：繁体稿原句为绝对说法。新句限定为「不另外設定」。

F9：两份中文稿删除「只含 JS、TS 与 Shell」这句错误表述。
新句写出 682 与 600 的组成。
两份中文稿不再把 1,282 说成只有 Script 语言。

F8：两份中文稿补「整体验证仍然失败」、「验收因此仍然开放」、「仍等新的运行时段」。

F6：繁体用途段的引擎建句与 GCC 行与建置段重复，已删。
Apple 与 MSVC 边界句保留。

## 已检查成立的断言

| 断言 | 证据 |
|---|---|
| 1,282 入口是独立 Flutter 应用 | `bin/script_acceptance.dart:1` 写明 `-t`。`:10` 导入 `flutter/material`。`:141` 有 `main()` |
| 1,282 分母 | `bin/script_acceptance.dart:33` |
| 1,282 等于 682 加 600 | `:283` 记为 600。`:785` 阶段名为 `lua682`。`:841` 用 `682 + done`。`:907-910` 检查 1282、682、600 |
| 组成与规格一致 | `.trellis/spec/backend/script-toolchain.md` 第 6 节写明 682 Lua 与 600 JS、TS、Shell |
| Lua 单独入口 | `bin/lua_catalog_audit.dart:117-118` 只保留 `lua` |
| 345 项主机测试通过 | `research/requirements-evidence.md:16`。`:139` 记录同一运行目录 |
| 整体验证仍失败 | 同上。强制清理残余进程后验收未运行 |
| 离线配置关闭在线接口 | `qfli_studio_core/lib/services/api_client.dart` 的 `_requireOnline()` 抛 `OFFLINE_ONLY` |
| QuickJS 堆 256 MiB | `native/script/qfli_script.c:313` |
| QuickJS 栈 2 MiB | `native/script/qfli_script.c:314` |
| QuickJS 源 512 KiB | `native/script/qfli_script.c:20` |
| QuickJS 输出流 1 MiB | `native/script/qfli_script.c:87` |
| 项目上限 256 文件 / 8 MiB | `lib/script_toolchain.dart:289-292`。`native/script/README.md:60` |
| Lua 输出流 1 MiB | `native/src/qfli_lua.c:31` 的 `MAX_OUTPUT` |
| 默认限时 10 秒 | `native/src/qfli_lua.c:624-626`。负值表示不限时 |
| Lua 不另设堆与栈限额 | `native/src/qfli_lua.c` 无 `SetMemoryLimit`。无 `lua_setcstacklimit` |
| 相对路径解析到项目目录 | `native/src/qfli_lua.c:281-288`。`:435-450` 包装 `io.open`、`io.input`、`io.output`、`io.lines`、`os.remove`、`os.rename`、`loadfile`、`dofile`。`:459-468` 前置 `package.path` |
| 不改变进程工作目录 | `native/src` 全文无 `chdir`。无 `SetCurrentDirectory` |
| Shell 查找路径 | `lib/shell_code_analyzer.dart` 的 `findPosixShell` |
| MSVC 与旧 GCC 只建 Lua | `native/script/CMakeLists.txt:2-4` |
| Apple 只编译 Lua 桥接 | Apple 工程的 `NativeLua.xcconfig`。Apple 工程无 `qfli_script` 引用 |
| Apple 打包未验证 | `native/script/README.md:55` |
| 调试器三种单步 | `lib/lua_studio_debugger.dart:34-36` |
| 变量检查不运行用户代码 | `lib/lua_debugger.dart:83` |
| 240 示例 / 23 教程 | `assets/content/lua_examples.json` 240 条。`lua_tutorials.json` 23 条 |
| 九个工具 | `lib/lua_tools_page.dart:31,37,43,49,55,61,73,79,85` |
| 编辑器两项操作 | `lib/lua_editor_tools.dart:11,18` |
| 内容验证器可用 `dart run` | `tool/verify_lua_content.dart:11`。无 Flutter 导入。`:28` 有 `main()` |
| OHOS 审计脚本建 HAP 并留摘要 | `tools/build_ohos_audit.ps1:229` 与 `:18` |

## 剩余问题

### F7（未获接受）

繁体稿用途段保留一句系统 Lua 说明。
英文稿与简体稿都没有这一句。
该句为真。root 未接受删除。保留原状。

### F10（未获接受）

英文稿用 profile。
两份中文稿用「独立版」。
root 未接受改名。保留原状。

### 备注（已知不对称）

简体稿与繁体稿都未写 Lua 引擎的平台清单。
繁体稿边界段有一句平台清单。
简体稿没有。
英文稿也没有。
本项未获接受。保留原状。

## 机械 lint

| 文件 | 结果 |
|---|---|
| `README.zh-CN.md` | 硬违规 0，JSON `[]`，退出码 0。`--max-chars 25` 退出码 0 |
| `README.zh-TW.md` | 硬违规 0，JSON `[]`，退出码 0。`--max-chars 25` 退出码 0 |

字集检查：简体稿无繁体字。繁体稿无简体字。
语言切换标签例外：简体稿含「繁體中文」。繁体稿含「简体中文」。两者属有意。
繁体禁词人工检查：未命中。
分号与破折号连接：未命中。语态检查通过。

## 置信度词对齐

英文稿 `may` 2 次。
简体稿「也许」2 次。
繁体稿「也許」2 次。
修复后三语仍对齐。

- 移动平台也许没有可用的 shell
- 取消也许无法中断阻塞的原生调用

## 未覆盖项

未运行 SDK、Flutter 测试、CMake、CTest、构建与设备。
1,282 完整验收未重跑。
主机结果不构成 OHOS 通过证据。
本复核只覆盖文档与源码一致性。

## 所有权

本轮已修复 `README.zh-CN.md` 与 `README.zh-TW.md`。
两份中文稿所有权现已释放。
未改英文 README。未改核心仓库与源码。
未改其他文件。未提交、未推送。
不独占仓库。