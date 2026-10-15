# Lua 双终端完整性

## Goal

使独立终端页和编辑器内终端均能通过内置 Lua 5.4.8 运行真实源代码/字节码、检查和编译，保持输入、路径、错误、超时与取消契约。

## Requirements

lib/lua_terminal_tools.dart（新增）、lib/main.dart 的委托字段、必要的 lib/lua_toolchain.dart 和 native/src/ 接口及相应 test/。保留已有 runner/startup/stdin 修改，不改核心公共文件与内容资产。

主需求与约束见 ../10-15-lua-store-readiness/prd.md；责任人：pi w9:p6。共享工作区多人协作，不得回滚/提交他人修改，任务最终由主代理统一提交。

## Acceptance Criteria

两终端复用同一 profile delegate；lua/luac 的帮助、版本、运行、检查、编译有真实测试；参数传递或不支持选项均明确，不能静默丢弃；Unicode/空格路径、input.txt、模块、取消和超时通过；C ABI 向后兼容。

## Dependencies

与其他子任务的独立文件工作可并行；平台最终构建等待本项验证完成。

## Out of Scope

其他语言产品、无关核心重构、设备卸载/清数据、商店上传与发行密钥替换。
