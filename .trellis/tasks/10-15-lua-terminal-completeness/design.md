# Lua 双终端完整性设计

父任务设计见 ../10-15-lua-store-readiness/design.md。

## 已确认缺口

以 ../10-15-lua-store-readiness/research/terminal-audit.md 为证据，采用主任务 research/baseline.md 的复核判定，报告中推测或已纠正项不得直接实施。

## 文件与行为边界

lib/lua_terminal_tools.dart（新增）、lib/main.dart 的委托字段、必要的 lib/lua_toolchain.dart 和 native/src/ 接口及相应 test/。保留已有 runner/startup/stdin 修改，不改核心公共文件与内容资产。

## 兼容与回退

复用现有共享接口，保留已存在的行为与他人修改。只替换明确归属本任务的 patch，按文件提交作为回退点；未通过验证不标记完成。
