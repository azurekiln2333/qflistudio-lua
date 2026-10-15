# Lua 双终端与原生工具链完整性审计（研究员 A）

- 任务：`.trellis/tasks/10-15-lua-store-readiness`
- 工作区：`D:/MyNewProjects/qfli_lua`（cwd 已确认，仅此工作区；`../qfli_studio_core` 只读）
- 状态：planning（只读 + 非破坏性检查；未改产品代码，未 `task.py start`，未提交）
- 基线：`git status` 有未提交变更（送审时 27 项，后续增至 30 项）。本报告用 `git diff` 区分“基线已提交”与“工作树新增”。
- 修订：v2。按评审意见（2026-10-15）把「确认缺陷」与「既有/有意行为」分离，撤回 4 处过度结论（见 §8）。

---

## 0. 审计范围与方法

被审对象：

| 层 | 文件 |
| --- | --- |
| Dart FFI | `lib/lua_toolchain.dart` |
| 运行后端 | `lib/lua_runner.dart` |
| 编辑器工具 | `lib/lua_editor_tools.dart` |
| 档位/接线 | `lib/main.dart` |
| 原生桥 | `native/src/qfli_lua.c`、`native/src/qfli_lua.h` |
| Windows 适配 | `native/src/qfli_lua_windows.{c,h}` |
| 构建 | `native/CMakeLists.txt` |
| 原生测试 | `native/test/qfli_lua_test.c` |
| 冒烟工具 | `tools/lua_stdin_smoke.dart` |
| 只读共享核心 | `../qfli_studio_core/lib/{services/runner_service.dart,services/studio_profile.dart,editor/terminal_pane.dart,pages/terminax_terminal_page.dart,terminal/shell/sandbox_shell_backend.dart,terminal/shell/local_shell_io.dart,terminal/state/terminal_manager.dart,services/online_program.dart}` |

非破坏性检查命令与结果（全部在本工作区执行，未删除/覆盖任何源文件）：

| 命令 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 通过（No issues found） |
| `flutter test --no-pub test/lua_app_test.dart test/lua_editor_tools_test.dart test/startup_test.dart` | 21 pass / 0 fail |
| `native/build/windows/qfli_lua_test.exe`（预编译 CTest 二进制） | exit 0 |
| `dart run tools/lua_stdin_smoke.dart native/build/windows/libqfli_lua.dll` | exit 0，6/6 check 通过 |
| `cmake` / `gcc` | 本机 PATH 不可用（未重编原生库） |

**二进制冒烟事实（不构成源码一致性证据）**：`native/build/windows/qfli_lua_test.exe` 与 `libqfli_lua.dll` 是**预编译产物**，本次运行通过只说明「该二进制在当前机器上行为正确」。虽然其 mtime 晚于 `qfli_lua.c`，但 **mtime 先后不能证明二进制与当前源码逐字节一致**：无法排除增量构建、手工替换或部分编译。因此本报告**不**据此声称 DLL 含 `install_run_input` 改动；源码一致性的唯一证据是独立重编（本机 `cmake`/`gcc` 不可用，未能执行）。所有关于工作树行为的结论一律以**源码走读 + Dart 层测试**为据；原生预编译产物仅记为冒烟通过。

---

## 1. 执行路径总览（确认接线）

1. 「运行」按钮：`RunnerService.runProject`（core `runner_service.dart:139`）→ 先取 `StudioProfile.current.runner`，非空则调 `LuaProgramRunner.run`。`.lua`/`.luac` 走 `_runLua`，其余脚本扩展名走宿主进程。
2. `_runLua`（`lib/lua_runner.dart:74`）→ `LuaToolchain.startRun`（`lua_toolchain.dart:91`）→ `Isolate.run(_invokeNative(... 'run' ...))` → `qfli_lua_run_with_token`。
3. 编辑器内终端：`terminal_pane.dart:436` `createSandboxShell(..., delegate: StudioProfile.current?.terminalCommandDelegate)`。
4. 独立终端页：`terminax_terminal_page.dart:42,109` 把 `_manager.commandDelegate` 设为同一档位字段。
5. 共享沙盒：`sandbox_shell_backend.dart:59` `delegate` → `runExternal`（:226）先问 delegate，再桌面进程回退，否则报“不支持”。

结论：**同一档位字段同时驱动两处终端**；Lua 能力缺失只会出现在该字段为空这一处，两终端表现应一致。

---

## 2. 确认缺陷（仅列真实缺陷/缺口）

> 定义：确认缺陷 = 有明确源码证据、会造成真实功能/正确性问题的项。下面 D1–D3 属此类；原本列为 D4/D7 的项经复核**不成立**，已移入 §8。

### D1 [高] Lua 档位没有终端命令钩子 → 两处终端都无法执行 lua/luac

- 证据：`lib/main.dart:24-53` 的 `luaProfile` 未设置 `terminalCommandDelegate`。全仓 grep：`lib/` 内无 `terminalCommandDelegate`、无 `runToolchainCommand`（仅 Java/Go 等兄弟项目有）。
- 对照：`qfli_java/lib/main.dart:48` 设了 `terminalCommandDelegate: _javaTerminalDelegate`，并在 `_javaTerminalDelegate` 中 `CommandParser.classify/tokenize` 后处理 `javac`/`java`。
- 后果：在编辑器终端或独立终端输入 `lua main.lua`、`luac -o out.luac main.lua`，落到 `sandbox_shell_backend.dart:226 runExternal`：桌面端被进程回退到真实 shell（若系统装了 lua 则“偶然可用”，但完全绕过 App 内置 5.4.8 与 `input.txt`/超时/取消语义）；移动端（Android/OHOS）无 shell → 只得到“不支持该命令”提示。**内置解释器无法从终端触达**。
- 权限边界：核心 `TerminalCommandDelegate` 类型与注入点已存在，**无需改共享核心**；纯 qfli_lua 侧新增一个 delegate 函数 + 一行档位字段即可。

### D2 [高] 沙盒未识别命令的提示硬编码 “Java 工具链”，对 Lua 产品是错误信息

- 证据：`sandbox_shell_backend.dart:239`
  `'${delegate == null ? '' : '与 Java 工具链'}）。'`
  以及 `:108` helpText `如果宿主应用提供了 Java 工具链，java/javac 也可用。`
- 后果：Lua 产品接入 delegate 后，任何未识别命令都会显示“……沙盒仅提供文件命令与 Java 工具链”，对用户是误导（=R2/R1 的“诊断准确”违约）。
- 权限边界：**属共享核心**。修法需把这段文案泛化（如用 `StudioProfile.current.appTitle`/语言名），属跨仓改动，须与核心工作区协调（R5）。qfli_lua 侧不可自行改。

### D3 [中] 编辑器文件工具仅覆盖 `.lua`，`.luac` 没有对应动作；check/compile 无超时与取消

- 证据：`lib/lua_editor_tools.dart:11,20` 两个 `EditorFileTool.extensions` 均为 `['.lua']`；`LuaEditorTools._check/_compile`（:26,:36）直接 `await` `LuaToolchain().check/compile`。
- 说明（避免过度结论）：`qfli_lua_check`/`qfli_lua_compile` 使用 `luaL_loadfilex(..., "t")`（**text-only**，`qfli_lua.c:533,551`）是**既有且正确的源码语义**——它们面向 `.lua` 源文件。`run` 才是 `"bt"`（`qfli_lua.c:481`）。因此 **".luac 无法 check/compile" 不是缺陷**：对字节码做语法检查/再编译本无意义，且 `supportedFileExtensions` 同时声明 `.luac` 仅表示“可运行”，不要求工具动作覆盖它。本节仅保留真实缺口：
  - `check`/`compile` 走 `Isolate.run` 且**无超时、无取消**（`lua_toolchain.dart:131,136`）；`compile` 调同步 `qfli_lua_compile`，理论上可被 `lua_dump` 长时间占用。属健壮性缺口。
  - `_check/_compile` 形参 `projectPath` 未被使用（`lua_editor_tools.dart:26,36`），编译输出落在 `p.setExtension(file, '.luac')`；行为正常，仅记录。
- 口径：`.luac` 无编辑器工具动作 = **可接受的既有行为**，不列为缺陷；超时/取消缺失 = 缺陷。

### D4 [中] 终端 `lua <file> [args]` 的脚本参数无法透传，且当前 delegate 缺失下会被静默吞掉

- 证据：`native/src/qfli_lua.c:474-477` 构造 `arg` 表时**只** `lua_rawseti(state, -2, 0)` 写入 `arg[0]`（入口文件名），没有任何 `arg[1..]` 注入点；`LuaToolchain.startRun` / `RunnerService.runProject` 也不传脚本参数。`lua_runner.dart` 的标题只渲染文件名。
- 后果与要求（评审明确）：**终端不得静默忽略脚本参数**。修复 D1 时，delegate 对 `lua main.lua foo bar` 必须二选一并**显式告知用户**，不得假装执行成功：
  - 方案 A（推荐）：扩展原生 `arg` 表注入 `arg[1..]`（新 ABI 参数或从 `project_dir` 侧通道传入），完整支持参数；或
  - 方案 B（最小）：delegate 检测到 `lua` 后面除入口外还有参数时，**明确拒绝**并回显 stderr（例如 `lua: script arguments are not supported yet`），返回已处理（`false`→让沙盒报，或 `true` 并自报错），绝不静默丢弃。
- 同理 `luac` 的 `-o`/多输入参数若不能完整支持，也须显式拒绝而非忽略。

### （原 D5–D7 已撤回，见 §8）

### 既有/有意行为（非缺陷，列出以便验收不误判）

- **编辑器终端 vs 独立终端 cwd 起点不同**：`terminax_terminal_page.dart:66-70 _resolveWorkingDirectory()` 返回 `AppPaths.storageDirectory()`（沙盒根），编辑器终端用 `widget.workingDirectory`（项目目录）。属共享核心既有设计；R1 的“两终端一致”应指**执行语义一致**（同一 delegate、同一工具链、同一退出码/取消），而非 cwd 初值相同。
- **`version()` 用法**：`lua_toolchain.dart:143-149` 同步 `_openLibrary` 后取 `qfli_lua_version`，`tools/lua_stdin_smoke.dart` 正常使用，非缺陷。

---

## 3. Lua 工具链功能矩阵（覆盖率，证据 = 源码/测试）

| 能力 | help | version | run | check | compile | 参数 | 模块 | 路径 | 输入 | 输出 | 超时 | 取消 | 错误 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 原生 API | 无 | ✅ `qfli_lua_version` | ✅ `run_with_token` | ✅ `check`(text-only) | ✅ `compile`(text-only) | ⚠️ 仅 `arg[0]`（**D4**） | ✅ `set_project_path` | ✅ `push_project_file` + 非 ASCII | ✅ `install_run_input` | ✅ 长度+NUL | ✅ hook | ✅ token | ✅ status+error |
| Dart FFI | 无 | ✅ `version()` | ✅ `startRun/run` | ✅ `check` | ✅ `compile` | ⚠️ 无脚本参数透传（**D4**） | — | ✅ `projectDirectory` | — | ✅ 精确字节解码 | ✅ `timeLimit`（run） | ✅ `LuaExecution.cancel` | ✅ `LuaToolResult.error` |
| 编辑器终端 | 无 | 无 | ❌ **D1 未接线** | ❌ 未接线 | ❌ 未接线 | ⚠️ **D4** | — | — | — | — | — | — | — |
| 独立终端 | 无 | 无 | ❌ **D1 未接线** | ❌ 未接线 | ❌ 未接线 | ⚠️ **D4** | — | — | — | — | — | — | — |
| 编辑器文件工具 | — | — | — | ✅ `.lua`（text-only，正确） | ✅ `.lua`（text-only，正确）；无超时/取消（**D3**） | — | — | — | — | 生成 `.luac` | ❌（**D3**） | ❌（**D3**） | ✅ 返回 error |

关键读数：
- `luac` 语义在原生层等价于 `qfli_lua_compile`（`luaL_loadfilex(...,"t")` + `lua_dump`），**没有单独的 luac 可执行文件**；因此终端若要支持 `luac`，必须由 delegate 把 `luac -o out.luac src.lua` 解析成 `compile(src, out)`。
- 终端 `lua main.lua` 需把 token 经 `backend.resolveSandboxPath` 映射为 `file` + `projectDirectory: backend.cwd`；脚本参数按 **D4** 处理（支持或显式拒绝）。

---

## 4. 最小修复方案与文件归属

### 4.1 qfli_lua 侧（本仓，可独立改）

1. **新增 `lib/lua_terminal_tools.dart`**（或并入 `lua_runner.dart`）：实现 `TerminalCommandDelegate`，只 `claim` `lua` / `luac`：
   - 用 `CommandParser.classify/tokenize`（与 Java 参考实现一致，`EscapePolicy.backslashLiteral`）；非 `simple` 行返回 `false`（让沙盒报“构造不支持”）。
   - `lua <file> [args]`：映射为 `LuaToolchain.startRun(file: resolved, projectDirectory: backend.cwd, ...)`，用 `backend.runStreams(title: 'lua <file>', stdout, stderr, exitCode, cancel)` 回放。**脚本参数按 D4 处理**：支持透传（方案 A）或对多余参数显式拒绝（方案 B），不得静默丢弃。
   - `luac [-o out] src`：映射 `LuaToolchain.compile(src, out)`，把 status/error 作为一行 stderr 回放，成功则 stdout 打印输出文件名；不支持的参数组合须显式拒绝。
   - 需 `await` 路径解析：`backend.resolveSandboxPath(token)` 得到绝对路径（`sandbox_shell_backend.dart:112` 公开方法）。
2. **`lib/main.dart`**：`luaProfile` 增加 `terminalCommandDelegate: luaTerminalDelegate`（一行）。
3. **`lib/lua_toolchain.dart`**（可选增强，对应 D3 的健壮性项）：给 `check`/`compile` 增加 `Duration timeLimit` 与 `LuaExecution` 式取消；若不加，至少在编辑器工具层加 `timeout`。**不**为 `.luac` 增加 check/compile（text-only 是正确语义）。

### 4.2 共享核心侧（跨仓，需协调）

1. **D2**：`sandbox_shell_backend.dart:239` 与 `:108` 把 “Java 工具链” 泛化。改法建议：用 `StudioProfile` 的语言名或 `label`，或把该句挪成 delegate 可提供的能力名。**归共享核心，qfli_lua 不得私改**。
2. 评估 `helpText` 是否应改为产品可注入（小改，但影响所有语言 App，需核心工作区同意）。

**结论：D1/D3 无需改共享核心；D2 必须改共享核心。既有 JS/TS/sh 兼容（原 D4）保留，不收敛。**

---

## 5. 测试命令与待补验证

已验证（本次）：

```powershell
cd D:/MyNewProjects/qfli_lua
flutter analyze --no-pub
flutter test --no-pub test/lua_app_test.dart test/lua_editor_tools_test.dart test/startup_test.dart
native/build/windows/qfli_lua_test.exe
dart run tools/lua_stdin_smoke.dart native/build/windows/libqfli_lua.dll
```

待补（本环境无 cmake/gcc，需有 CMake 的机器或 CI）：

```powershell
# 重编原生（当前 DLL 是预编译产物，mtime 不能证明源码一致性）
cmake -S native -B native/build/windows -G Ninja
cmake --build native/build/windows
ctest --test-dir native/build/windows --output-on-failure
```

修复 D1 后需新增的测试：
- `test/lua_terminal_tools_test.dart`：用 `SandboxShellBackend`（或 `createSandboxShell` + fake delegate）断言 `lua main.lua` 经内置解释器执行、`luac -o out.luac main.lua` 生成字节码、`lua` 无参/`luac` 参数错误给出清晰 stderr、非 `simple` 行（含管道）返回 false。
- **D4 专属用例**：`lua main.lua foo bar` 必须“支持”或“显式拒绝”，断言**绝不**出现“无错且参数被丢弃”的静默路径。
- 端到端：编辑器终端与独立终端各跑一次 `lua main.lua` + `input.txt` 读取，证明两终端执行语义一致（R1 验收）。

未决技术点（需实测确认，不臆断）：
- 终端 `lua <file> [args]` 的脚本参数透传需在原生 `arg` 表（现仅 `arg[0]`，`qfli_lua.c:474-477`）扩展或加侧通道；属 D4 的方案选择，不是既有缺陷。

---

## 6. 与其他任务/基线的交叉

- **未提交变更归属**：`native/src/qfli_lua.c`、`qfli_lua_windows.{c,h}`、`native/test/qfli_lua_test.c`、`lib/lua_runner.dart`、`lib/main.dart` 有未提交改动（`git diff` 确认 `install_run_input` 系列 + Lua 标题英文化）。本报告不改动这些文件；后续修复须叠加在其之上，不得回滚（R6）。
- `10-09-terminal-polish`：负责 `lua_runner` 标题英文化，已完成（PRD 全 `[x]`）。D1 是其自然延伸但**不在其 PRD 范围**，应在本任务（10-15）落地。
- `10-01-native-platforms`：已 `[x]` 覆盖多平台原生接线；本报告 D1 的“终端触达”是其未覆盖的运行时缺口。
- 本报告不涉及内容/教程审计（R3）与构建产物（R4），仅 A 范围。

---

## 7. 结论摘要

- 内置 Lua 5.4.8 工具链在**原生层与 Dart FFI 层完整**：run/check/compile、模块、路径（含非 ASCII）、input.txt、超时、取消、错误、NUL 保留均有源码与 Dart 层测试证据（原生侧为预编译二进制冒烟，非重编）。
- **两处终端均未接入 Lua delegate（D1）**，是当前最严重的“残缺接线”：内置解释器无法从终端使用；这是 R1 的核心违约。
- **共享核心硬编码 “Java 工具链” 文案（D2）** 会在 Lua 产品上产生错误提示，必须跨仓修复。
- 编辑器 `check`/`compile` 无超时/取消（D3，仅健壮性）；终端脚本参数可能被静默丢弃（D4，需支持或显式拒绝）。
- `.luac` 无编辑器 check/compile、JS/TS/sh 分支保留、5.3 兼容定义——三者均为**既有/有意行为，非缺陷**（详见 §8）。
- 共享核心其余部分（`TerminalCommandDelegate`、`runStreams`、注入点）已具备，D1 是纯 qfli_lua 侧的小改动。

---

## 8. 撤回的过度结论（v2 修订）

| 原编号 | 原结论 | 修正后口径 |
| --- | --- | --- |
| 原 D3 前半 | “`.luac` 无法检查/编译 = 缺陷” | **撤回**。`check`/`compile` 用 `"t"`（text-only，`qfli_lua.c:533,551`）是面向源码的**既有正确语义**；字节码无需语法检查/再编译。`.luac` 无编辑器动作 = 可接受行为。 |
| 原 D4 | “js/ts/sh 分支与离线定位不符，应收敛” | **撤回**。离线≠仅 Lua；`_sourceExtensions`/`_commandFor` 的 JS/TS/sh 兼容是既有设计，**暂不收缩范围**。 |
| §0 基线段 | “DLL mtime 晚于源码 ⇒ 二进制含工作树改动” | **撤回**。mtime 先后不能证明源码一致性。只能说：**预编译二进制冒烟通过**；源码一致性需独立重编（本机不具备）。 |
| 原 D7 | “`LUA_COMPAT_5_3` ⇒ `bit32` 等旧接口可用” | **撤回**。Lua 5.4 的 5.3 兼容层**不**等于 `bit32` 可用（`bit32` 是 5.2 库，5.3 已移除）；兼容定义（`CMakeLists.txt:29`）的具体影响需按 Lua 5.4 手册核对，不得据此断言任何库可用。 |
| 原 §4.1 措辞 / D4 | “`args` 暂不注入 / 忽略” | **改口径**。终端脚本参数**不得静默忽略**，须支持（方案 A）或显式拒绝（方案 B），见 D4。 |

---

报告路径：`.trellis/tasks/10-15-lua-store-readiness/research/terminal-audit.md`
