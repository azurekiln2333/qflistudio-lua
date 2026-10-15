# Lua 学习内容重建设计

父任务设计见 ../10-15-lua-store-readiness/design.md。

## 已确认缺口

以 ../10-15-lua-store-readiness/research/content-audit.md 为证据，采用主任务 research/baseline.md 的复核判定，报告中推测或已纠正项不得直接实施。

## 文件与行为边界

共享核心的 Lua 专属 tool/lua_content、Lua 生成与验证脚本、assets/tutorials/lua.json；两份聚合 JSON 仅由主代理最终合并 Lua 条目。不得删除/覆盖其他语言资产或修改加载/UI结构。

## 兼容与回退

复用现有共享接口，保留已存在的行为与他人修改。只替换明确归属本任务的 patch，按文件提交作为回退点；未通过验证不标记完成。
