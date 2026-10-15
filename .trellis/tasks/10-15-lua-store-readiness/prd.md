# Lua 上架完整性审计

## Goal

完成 QFLIScript（qfli_lua）的离线上架准备，验证独立终端及编辑器终端的 Lua 工具链完整性，检查共享核心功能门控、学习内容与 OHOS/Android 发布构建。

## Requirements

- R1：逐项检查独立终端页与编辑器内终端的运行、语法检查、编译、标准输入、取消、超时、错误输出、文件与路径处理，发现缺失或残缺实现后修复。
- R2：沿 qfli_lua → ../qfli_studio_core 检查 Git、云终端、登录及其他联网场景；离线 Lua 产品不展示这些入口，通用策略归共享核心维护。
- R3：仅替换已确认占位的 Lua 原有内容，重新提供从入门到精通的 120 篇教程与 120 个配套示例，逐项验证主题、代码与预期输出。
- R4：完成相关静态检查、应用/共享核心测试与原生测试，构建 OHOS、Android 发布产物；可用设备尝试安装与功能测试，记录真实结果及阻塞。
- R5：仅协调 Herdr 中 cwd 为 D:/MyNewProjects/qfli_lua 的 3 个 pi，不操作其他子项目的 pi 或内容。共享核心改动先与核心工作区协调。
- R6：保留并审查工作区既有未提交变更；每批修改通过检查后显式按文件提交，使用 Conventional Commits，不做全仓库盲目暂存。
- R7：所有审计、设计、执行步骤、验证证据与剩余阻塞记录到 Trellis。

## Confirmed Facts

- 根目录 D:/MyNewProjects/qfli_lua，Git main；依赖 qfli_studio_core 的实际路径 D:/MyNewProjects/qfli_studio_core。
- 初始 Lua 工作树有 26 项未提交变更；共享核心初始 git status 干净。
- luaProfile 已设置 isOffline: true，Lua 运行时声明 lua-5.4-native。
- 现有任务涉及内容导入、原生多平台、OHPM 锁文件、终端展示，需汇总其证据并核查未结束工作。
- 检测到 Android 设备与 OHOS 网络设备；具体安装与运行能力需验证。
- A 审计确认 `lib/main.dart:24` 未设置 `terminalCommandDelegate`，核心 `editor/terminal_pane.dart:436` 与 `pages/terminax_terminal_page.dart:42` 均依赖该字段。证据：research/terminal-audit.md。
- B 审计确认核心聚合教程和示例各有 100 条 Lua，全部复用加权求和模板；真实执行 200/200 通过仅证明可运行。核心 `assets/tutorials/lua.json` 仍标 planned。证据：research/content-audit.md、research/lua-exec-results.json。
- C 审计确认核心 `lib/editor/editor_page.dart:1585,1598` 漏门控 Git/云拉取，`lib/pages/profile_page.dart:58` 进入设置时未关闭 AI 入口。证据：research/platform-offline-audit.md。
- 本次根目录静态分析通过；完整应用测试 44 通过、2 失败：导入文件名空白校验回归、Windows 测试目录清理占用。须修复后复测。
- OHOS 配置引用的签名文件未在预期路径找到；Android release 当前使用 debug 签名。构建验证与商店签名就绪分别记录，不生成或替换用户发行身份。

## Acceptance Criteria

- 每条审计需求有文件证据、检查命令与明确通过/失败/环境阻塞结论。
- 两类终端通过同一 Lua 工具链执行真实代码与错误、取消、输入等关键场景。
- Lua 产品联网入口不可见且被既有离线策略拦截；其他产品内容与配置未被误修改。
- 120 篇 Lua 教程与 120 个示例无占位，主题一致，每项代码通过真实 Lua 5.4 语法/运行及预期输出验证；重建前后非 Lua 内容指纹一致。
- OHOS/Android 发布构建结果与产物路径、哈希、设备测试证据可复核。
- 新修改均有规范提交；未完成或环境阻塞不会被标记通过。

## Out of Scope

- 其他语言子项目内容重建、产品功能重设计、无关核心重构、商店上传与发布。
- 既有 JS/TS/shell 兼容入口收缩、把源代码检查扩展为字节码编辑工具、对无实际失败证据的生成锁文件路径进行改造。
- 擅自创建/替换 Android 或 OHOS 发行密钥、卸载设备应用、清除用户设备数据。

## Task Map

- `10-15-lua-terminal-completeness`：pi `w9:p6`；终端命令与原生工具链。
- `10-15-lua-learning-content`：pi `w9:p4`；Lua 学习内容及校验。
- `10-15-lua-offline-mobile-release`：pi `w9:p7`；离线门控和平台验证。最终平台构建依赖前两项及核心集成完成。
- 主任务负责共享核心集中集成、既有任务核验、分批提交和最终验收。规划已落盘，尚待用户批准最终规划后激活实施。
