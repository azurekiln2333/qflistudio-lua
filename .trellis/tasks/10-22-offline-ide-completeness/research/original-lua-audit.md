# 原共享 Lua 内容审计（R1）

由 `tool/lua_content/audit_original_lua_content.dart` 生成，
执行引擎为仓库内捆绑的 Lua 5.4.8 原生库，
每段代码在独立临时项目中运行，`print`/`io.write` 输出与退出状态逐条比对。

## 清单

| 项目 | 数量 |
| --- | --- |
| 共享 `tutorials.json` 中的 lua 条目 | 100 |
| 共享 `examples.json` 中的 lua 条目 | 100 |
| 实际执行的课时代码 | 100 |
| 实际执行的示例代码 | 100 |
| 不同的标题数 | 124 |
| 去掉编号后的不同标题数 | 24 |
| 不同的代码正文数 | 100 |
| 去掉字面量后的不同代码数 | 1 |
| 与预期输出一致 | 200 |
| 与预期输出不一致或失败 | 0 |

## 结论

- 去掉编号后只剩 24 个主题标题，却铺满 200 条记录：内容是固定周期循环编号，不是 200 个真实主题。
- 去掉字面量后只剩 1 种代码：同一个加权求和片段改一个数字就成了「新条目」，与各自标题（日志、缓存、并发等）没有对应关系。
- 因此这些条目不能算作「有意义的教学内容」，扩容只能靠重新撰写 240 个真实主题，而不是在循环模板上继续加编号。

## 逐条执行结果

| 序号 | 类型 | 条目 | 标题 | 状态码 | 结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | lesson | `lua-tutorial-001/lua-tutorial-001-lesson` | 实现：数据建模与不变量 | 0 | 一致 |
| 2 | lesson | `lua-tutorial-002/lua-tutorial-002-lesson` | 实现：输入校验与错误边界 | 0 | 一致 |
| 3 | lesson | `lua-tutorial-003/lua-tutorial-003-lesson` | 实现：文件格式与编码 | 0 | 一致 |
| 4 | lesson | `lua-tutorial-004/lua-tutorial-004-lesson` | 实现：日志与可观测性 | 0 | 一致 |
| 5 | lesson | `lua-tutorial-005/lua-tutorial-005-lesson` | 实现：缓存与失效策略 | 0 | 一致 |
| 6 | lesson | `lua-tutorial-006/lua-tutorial-006-lesson` | 实现：队列与批处理 | 0 | 一致 |
| 7 | lesson | `lua-tutorial-007/lua-tutorial-007-lesson` | 实现：分页与排序 | 0 | 一致 |
| 8 | lesson | `lua-tutorial-008/lua-tutorial-008-lesson` | 实现：配置与环境隔离 | 0 | 一致 |
| 9 | lesson | `lua-tutorial-009/lua-tutorial-009-lesson` | 实现：并发与资源生命周期 | 0 | 一致 |
| 10 | lesson | `lua-tutorial-010/lua-tutorial-010-lesson` | 实现：测试夹具与回归 | 0 | 一致 |
| 11 | lesson | `lua-tutorial-011/lua-tutorial-011-lesson` | 实现：性能测量与优化 | 0 | 一致 |
| 12 | lesson | `lua-tutorial-012/lua-tutorial-012-lesson` | 实现：安全边界与最小权限 | 0 | 一致 |
| 13 | lesson | `lua-tutorial-013/lua-tutorial-013-lesson` | 实现：网络协议与重试 | 0 | 一致 |
| 14 | lesson | `lua-tutorial-014/lua-tutorial-014-lesson` | 实现：持久化与迁移 | 0 | 一致 |
| 15 | lesson | `lua-tutorial-015/lua-tutorial-015-lesson` | 实现：命令行工具设计 | 0 | 一致 |
| 16 | lesson | `lua-tutorial-016/lua-tutorial-016-lesson` | 实现：模块边界与依赖方向 | 0 | 一致 |
| 17 | lesson | `lua-tutorial-017/lua-tutorial-017-lesson` | 实现：状态机与事件流 | 0 | 一致 |
| 18 | lesson | `lua-tutorial-018/lua-tutorial-018-lesson` | 实现：时间、时区与截止时间 | 0 | 一致 |
| 19 | lesson | `lua-tutorial-019/lua-tutorial-019-lesson` | 实现：文本处理与国际化 | 0 | 一致 |
| 20 | lesson | `lua-tutorial-020/lua-tutorial-020-lesson` | 实现：故障恢复与幂等性 | 0 | 一致 |
| 21 | lesson | `lua-tutorial-021/lua-tutorial-021-lesson` | 实现：资源打包与发布 | 0 | 一致 |
| 22 | lesson | `lua-tutorial-022/lua-tutorial-022-lesson` | 实现：增量计算与差分 | 0 | 一致 |
| 23 | lesson | `lua-tutorial-023/lua-tutorial-023-lesson` | 实现：API 契约与版本兼容 | 0 | 一致 |
| 24 | lesson | `lua-tutorial-024/lua-tutorial-024-lesson` | 实现：真实项目重构练习 | 0 | 一致 |
| 25 | lesson | `lua-tutorial-025/lua-tutorial-025-lesson` | 实现：数据建模与不变量 | 0 | 一致 |
| 26 | lesson | `lua-tutorial-026/lua-tutorial-026-lesson` | 实现：输入校验与错误边界 | 0 | 一致 |
| 27 | lesson | `lua-tutorial-027/lua-tutorial-027-lesson` | 实现：文件格式与编码 | 0 | 一致 |
| 28 | lesson | `lua-tutorial-028/lua-tutorial-028-lesson` | 实现：日志与可观测性 | 0 | 一致 |
| 29 | lesson | `lua-tutorial-029/lua-tutorial-029-lesson` | 实现：缓存与失效策略 | 0 | 一致 |
| 30 | lesson | `lua-tutorial-030/lua-tutorial-030-lesson` | 实现：队列与批处理 | 0 | 一致 |
| 31 | lesson | `lua-tutorial-031/lua-tutorial-031-lesson` | 实现：分页与排序 | 0 | 一致 |
| 32 | lesson | `lua-tutorial-032/lua-tutorial-032-lesson` | 实现：配置与环境隔离 | 0 | 一致 |
| 33 | lesson | `lua-tutorial-033/lua-tutorial-033-lesson` | 实现：并发与资源生命周期 | 0 | 一致 |
| 34 | lesson | `lua-tutorial-034/lua-tutorial-034-lesson` | 实现：测试夹具与回归 | 0 | 一致 |
| 35 | lesson | `lua-tutorial-035/lua-tutorial-035-lesson` | 实现：性能测量与优化 | 0 | 一致 |
| 36 | lesson | `lua-tutorial-036/lua-tutorial-036-lesson` | 实现：安全边界与最小权限 | 0 | 一致 |
| 37 | lesson | `lua-tutorial-037/lua-tutorial-037-lesson` | 实现：网络协议与重试 | 0 | 一致 |
| 38 | lesson | `lua-tutorial-038/lua-tutorial-038-lesson` | 实现：持久化与迁移 | 0 | 一致 |
| 39 | lesson | `lua-tutorial-039/lua-tutorial-039-lesson` | 实现：命令行工具设计 | 0 | 一致 |
| 40 | lesson | `lua-tutorial-040/lua-tutorial-040-lesson` | 实现：模块边界与依赖方向 | 0 | 一致 |
| 41 | lesson | `lua-tutorial-041/lua-tutorial-041-lesson` | 实现：状态机与事件流 | 0 | 一致 |
| 42 | lesson | `lua-tutorial-042/lua-tutorial-042-lesson` | 实现：时间、时区与截止时间 | 0 | 一致 |
| 43 | lesson | `lua-tutorial-043/lua-tutorial-043-lesson` | 实现：文本处理与国际化 | 0 | 一致 |
| 44 | lesson | `lua-tutorial-044/lua-tutorial-044-lesson` | 实现：故障恢复与幂等性 | 0 | 一致 |
| 45 | lesson | `lua-tutorial-045/lua-tutorial-045-lesson` | 实现：资源打包与发布 | 0 | 一致 |
| 46 | lesson | `lua-tutorial-046/lua-tutorial-046-lesson` | 实现：增量计算与差分 | 0 | 一致 |
| 47 | lesson | `lua-tutorial-047/lua-tutorial-047-lesson` | 实现：API 契约与版本兼容 | 0 | 一致 |
| 48 | lesson | `lua-tutorial-048/lua-tutorial-048-lesson` | 实现：真实项目重构练习 | 0 | 一致 |
| 49 | lesson | `lua-tutorial-049/lua-tutorial-049-lesson` | 实现：数据建模与不变量 | 0 | 一致 |
| 50 | lesson | `lua-tutorial-050/lua-tutorial-050-lesson` | 实现：输入校验与错误边界 | 0 | 一致 |
| 51 | lesson | `lua-tutorial-051/lua-tutorial-051-lesson` | 实现：文件格式与编码 | 0 | 一致 |
| 52 | lesson | `lua-tutorial-052/lua-tutorial-052-lesson` | 实现：日志与可观测性 | 0 | 一致 |
| 53 | lesson | `lua-tutorial-053/lua-tutorial-053-lesson` | 实现：缓存与失效策略 | 0 | 一致 |
| 54 | lesson | `lua-tutorial-054/lua-tutorial-054-lesson` | 实现：队列与批处理 | 0 | 一致 |
| 55 | lesson | `lua-tutorial-055/lua-tutorial-055-lesson` | 实现：分页与排序 | 0 | 一致 |
| 56 | lesson | `lua-tutorial-056/lua-tutorial-056-lesson` | 实现：配置与环境隔离 | 0 | 一致 |
| 57 | lesson | `lua-tutorial-057/lua-tutorial-057-lesson` | 实现：并发与资源生命周期 | 0 | 一致 |
| 58 | lesson | `lua-tutorial-058/lua-tutorial-058-lesson` | 实现：测试夹具与回归 | 0 | 一致 |
| 59 | lesson | `lua-tutorial-059/lua-tutorial-059-lesson` | 实现：性能测量与优化 | 0 | 一致 |
| 60 | lesson | `lua-tutorial-060/lua-tutorial-060-lesson` | 实现：安全边界与最小权限 | 0 | 一致 |
| 61 | lesson | `lua-tutorial-061/lua-tutorial-061-lesson` | 实现：网络协议与重试 | 0 | 一致 |
| 62 | lesson | `lua-tutorial-062/lua-tutorial-062-lesson` | 实现：持久化与迁移 | 0 | 一致 |
| 63 | lesson | `lua-tutorial-063/lua-tutorial-063-lesson` | 实现：命令行工具设计 | 0 | 一致 |
| 64 | lesson | `lua-tutorial-064/lua-tutorial-064-lesson` | 实现：模块边界与依赖方向 | 0 | 一致 |
| 65 | lesson | `lua-tutorial-065/lua-tutorial-065-lesson` | 实现：状态机与事件流 | 0 | 一致 |
| 66 | lesson | `lua-tutorial-066/lua-tutorial-066-lesson` | 实现：时间、时区与截止时间 | 0 | 一致 |
| 67 | lesson | `lua-tutorial-067/lua-tutorial-067-lesson` | 实现：文本处理与国际化 | 0 | 一致 |
| 68 | lesson | `lua-tutorial-068/lua-tutorial-068-lesson` | 实现：故障恢复与幂等性 | 0 | 一致 |
| 69 | lesson | `lua-tutorial-069/lua-tutorial-069-lesson` | 实现：资源打包与发布 | 0 | 一致 |
| 70 | lesson | `lua-tutorial-070/lua-tutorial-070-lesson` | 实现：增量计算与差分 | 0 | 一致 |
| 71 | lesson | `lua-tutorial-071/lua-tutorial-071-lesson` | 实现：API 契约与版本兼容 | 0 | 一致 |
| 72 | lesson | `lua-tutorial-072/lua-tutorial-072-lesson` | 实现：真实项目重构练习 | 0 | 一致 |
| 73 | lesson | `lua-tutorial-073/lua-tutorial-073-lesson` | 实现：数据建模与不变量 | 0 | 一致 |
| 74 | lesson | `lua-tutorial-074/lua-tutorial-074-lesson` | 实现：输入校验与错误边界 | 0 | 一致 |
| 75 | lesson | `lua-tutorial-075/lua-tutorial-075-lesson` | 实现：文件格式与编码 | 0 | 一致 |
| 76 | lesson | `lua-tutorial-076/lua-tutorial-076-lesson` | 实现：日志与可观测性 | 0 | 一致 |
| 77 | lesson | `lua-tutorial-077/lua-tutorial-077-lesson` | 实现：缓存与失效策略 | 0 | 一致 |
| 78 | lesson | `lua-tutorial-078/lua-tutorial-078-lesson` | 实现：队列与批处理 | 0 | 一致 |
| 79 | lesson | `lua-tutorial-079/lua-tutorial-079-lesson` | 实现：分页与排序 | 0 | 一致 |
| 80 | lesson | `lua-tutorial-080/lua-tutorial-080-lesson` | 实现：配置与环境隔离 | 0 | 一致 |
| 81 | lesson | `lua-tutorial-081/lua-tutorial-081-lesson` | 实现：并发与资源生命周期 | 0 | 一致 |
| 82 | lesson | `lua-tutorial-082/lua-tutorial-082-lesson` | 实现：测试夹具与回归 | 0 | 一致 |
| 83 | lesson | `lua-tutorial-083/lua-tutorial-083-lesson` | 实现：性能测量与优化 | 0 | 一致 |
| 84 | lesson | `lua-tutorial-084/lua-tutorial-084-lesson` | 实现：安全边界与最小权限 | 0 | 一致 |
| 85 | lesson | `lua-tutorial-085/lua-tutorial-085-lesson` | 实现：网络协议与重试 | 0 | 一致 |
| 86 | lesson | `lua-tutorial-086/lua-tutorial-086-lesson` | 实现：持久化与迁移 | 0 | 一致 |
| 87 | lesson | `lua-tutorial-087/lua-tutorial-087-lesson` | 实现：命令行工具设计 | 0 | 一致 |
| 88 | lesson | `lua-tutorial-088/lua-tutorial-088-lesson` | 实现：模块边界与依赖方向 | 0 | 一致 |
| 89 | lesson | `lua-tutorial-089/lua-tutorial-089-lesson` | 实现：状态机与事件流 | 0 | 一致 |
| 90 | lesson | `lua-tutorial-090/lua-tutorial-090-lesson` | 实现：时间、时区与截止时间 | 0 | 一致 |
| 91 | lesson | `lua-tutorial-091/lua-tutorial-091-lesson` | 实现：文本处理与国际化 | 0 | 一致 |
| 92 | lesson | `lua-tutorial-092/lua-tutorial-092-lesson` | 实现：故障恢复与幂等性 | 0 | 一致 |
| 93 | lesson | `lua-tutorial-093/lua-tutorial-093-lesson` | 实现：资源打包与发布 | 0 | 一致 |
| 94 | lesson | `lua-tutorial-094/lua-tutorial-094-lesson` | 实现：增量计算与差分 | 0 | 一致 |
| 95 | lesson | `lua-tutorial-095/lua-tutorial-095-lesson` | 实现：API 契约与版本兼容 | 0 | 一致 |
| 96 | lesson | `lua-tutorial-096/lua-tutorial-096-lesson` | 实现：真实项目重构练习 | 0 | 一致 |
| 97 | lesson | `lua-tutorial-097/lua-tutorial-097-lesson` | 实现：数据建模与不变量 | 0 | 一致 |
| 98 | lesson | `lua-tutorial-098/lua-tutorial-098-lesson` | 实现：输入校验与错误边界 | 0 | 一致 |
| 99 | lesson | `lua-tutorial-099/lua-tutorial-099-lesson` | 实现：文件格式与编码 | 0 | 一致 |
| 100 | lesson | `lua-tutorial-100/lua-tutorial-100-lesson` | 实现：日志与可观测性 | 0 | 一致 |
| 101 | example | `lua-example-001` | Lua 示例 001: 数据建模与不变量 | 0 | 一致 |
| 102 | example | `lua-example-002` | Lua 示例 002: 输入校验与错误边界 | 0 | 一致 |
| 103 | example | `lua-example-003` | Lua 示例 003: 文件格式与编码 | 0 | 一致 |
| 104 | example | `lua-example-004` | Lua 示例 004: 日志与可观测性 | 0 | 一致 |
| 105 | example | `lua-example-005` | Lua 示例 005: 缓存与失效策略 | 0 | 一致 |
| 106 | example | `lua-example-006` | Lua 示例 006: 队列与批处理 | 0 | 一致 |
| 107 | example | `lua-example-007` | Lua 示例 007: 分页与排序 | 0 | 一致 |
| 108 | example | `lua-example-008` | Lua 示例 008: 配置与环境隔离 | 0 | 一致 |
| 109 | example | `lua-example-009` | Lua 示例 009: 并发与资源生命周期 | 0 | 一致 |
| 110 | example | `lua-example-010` | Lua 示例 010: 测试夹具与回归 | 0 | 一致 |
| 111 | example | `lua-example-011` | Lua 示例 011: 性能测量与优化 | 0 | 一致 |
| 112 | example | `lua-example-012` | Lua 示例 012: 安全边界与最小权限 | 0 | 一致 |
| 113 | example | `lua-example-013` | Lua 示例 013: 网络协议与重试 | 0 | 一致 |
| 114 | example | `lua-example-014` | Lua 示例 014: 持久化与迁移 | 0 | 一致 |
| 115 | example | `lua-example-015` | Lua 示例 015: 命令行工具设计 | 0 | 一致 |
| 116 | example | `lua-example-016` | Lua 示例 016: 模块边界与依赖方向 | 0 | 一致 |
| 117 | example | `lua-example-017` | Lua 示例 017: 状态机与事件流 | 0 | 一致 |
| 118 | example | `lua-example-018` | Lua 示例 018: 时间、时区与截止时间 | 0 | 一致 |
| 119 | example | `lua-example-019` | Lua 示例 019: 文本处理与国际化 | 0 | 一致 |
| 120 | example | `lua-example-020` | Lua 示例 020: 故障恢复与幂等性 | 0 | 一致 |
| 121 | example | `lua-example-021` | Lua 示例 021: 资源打包与发布 | 0 | 一致 |
| 122 | example | `lua-example-022` | Lua 示例 022: 增量计算与差分 | 0 | 一致 |
| 123 | example | `lua-example-023` | Lua 示例 023: API 契约与版本兼容 | 0 | 一致 |
| 124 | example | `lua-example-024` | Lua 示例 024: 真实项目重构练习 | 0 | 一致 |
| 125 | example | `lua-example-025` | Lua 示例 025: 数据建模与不变量 | 0 | 一致 |
| 126 | example | `lua-example-026` | Lua 示例 026: 输入校验与错误边界 | 0 | 一致 |
| 127 | example | `lua-example-027` | Lua 示例 027: 文件格式与编码 | 0 | 一致 |
| 128 | example | `lua-example-028` | Lua 示例 028: 日志与可观测性 | 0 | 一致 |
| 129 | example | `lua-example-029` | Lua 示例 029: 缓存与失效策略 | 0 | 一致 |
| 130 | example | `lua-example-030` | Lua 示例 030: 队列与批处理 | 0 | 一致 |
| 131 | example | `lua-example-031` | Lua 示例 031: 分页与排序 | 0 | 一致 |
| 132 | example | `lua-example-032` | Lua 示例 032: 配置与环境隔离 | 0 | 一致 |
| 133 | example | `lua-example-033` | Lua 示例 033: 并发与资源生命周期 | 0 | 一致 |
| 134 | example | `lua-example-034` | Lua 示例 034: 测试夹具与回归 | 0 | 一致 |
| 135 | example | `lua-example-035` | Lua 示例 035: 性能测量与优化 | 0 | 一致 |
| 136 | example | `lua-example-036` | Lua 示例 036: 安全边界与最小权限 | 0 | 一致 |
| 137 | example | `lua-example-037` | Lua 示例 037: 网络协议与重试 | 0 | 一致 |
| 138 | example | `lua-example-038` | Lua 示例 038: 持久化与迁移 | 0 | 一致 |
| 139 | example | `lua-example-039` | Lua 示例 039: 命令行工具设计 | 0 | 一致 |
| 140 | example | `lua-example-040` | Lua 示例 040: 模块边界与依赖方向 | 0 | 一致 |
| 141 | example | `lua-example-041` | Lua 示例 041: 状态机与事件流 | 0 | 一致 |
| 142 | example | `lua-example-042` | Lua 示例 042: 时间、时区与截止时间 | 0 | 一致 |
| 143 | example | `lua-example-043` | Lua 示例 043: 文本处理与国际化 | 0 | 一致 |
| 144 | example | `lua-example-044` | Lua 示例 044: 故障恢复与幂等性 | 0 | 一致 |
| 145 | example | `lua-example-045` | Lua 示例 045: 资源打包与发布 | 0 | 一致 |
| 146 | example | `lua-example-046` | Lua 示例 046: 增量计算与差分 | 0 | 一致 |
| 147 | example | `lua-example-047` | Lua 示例 047: API 契约与版本兼容 | 0 | 一致 |
| 148 | example | `lua-example-048` | Lua 示例 048: 真实项目重构练习 | 0 | 一致 |
| 149 | example | `lua-example-049` | Lua 示例 049: 数据建模与不变量 | 0 | 一致 |
| 150 | example | `lua-example-050` | Lua 示例 050: 输入校验与错误边界 | 0 | 一致 |
| 151 | example | `lua-example-051` | Lua 示例 051: 文件格式与编码 | 0 | 一致 |
| 152 | example | `lua-example-052` | Lua 示例 052: 日志与可观测性 | 0 | 一致 |
| 153 | example | `lua-example-053` | Lua 示例 053: 缓存与失效策略 | 0 | 一致 |
| 154 | example | `lua-example-054` | Lua 示例 054: 队列与批处理 | 0 | 一致 |
| 155 | example | `lua-example-055` | Lua 示例 055: 分页与排序 | 0 | 一致 |
| 156 | example | `lua-example-056` | Lua 示例 056: 配置与环境隔离 | 0 | 一致 |
| 157 | example | `lua-example-057` | Lua 示例 057: 并发与资源生命周期 | 0 | 一致 |
| 158 | example | `lua-example-058` | Lua 示例 058: 测试夹具与回归 | 0 | 一致 |
| 159 | example | `lua-example-059` | Lua 示例 059: 性能测量与优化 | 0 | 一致 |
| 160 | example | `lua-example-060` | Lua 示例 060: 安全边界与最小权限 | 0 | 一致 |
| 161 | example | `lua-example-061` | Lua 示例 061: 网络协议与重试 | 0 | 一致 |
| 162 | example | `lua-example-062` | Lua 示例 062: 持久化与迁移 | 0 | 一致 |
| 163 | example | `lua-example-063` | Lua 示例 063: 命令行工具设计 | 0 | 一致 |
| 164 | example | `lua-example-064` | Lua 示例 064: 模块边界与依赖方向 | 0 | 一致 |
| 165 | example | `lua-example-065` | Lua 示例 065: 状态机与事件流 | 0 | 一致 |
| 166 | example | `lua-example-066` | Lua 示例 066: 时间、时区与截止时间 | 0 | 一致 |
| 167 | example | `lua-example-067` | Lua 示例 067: 文本处理与国际化 | 0 | 一致 |
| 168 | example | `lua-example-068` | Lua 示例 068: 故障恢复与幂等性 | 0 | 一致 |
| 169 | example | `lua-example-069` | Lua 示例 069: 资源打包与发布 | 0 | 一致 |
| 170 | example | `lua-example-070` | Lua 示例 070: 增量计算与差分 | 0 | 一致 |
| 171 | example | `lua-example-071` | Lua 示例 071: API 契约与版本兼容 | 0 | 一致 |
| 172 | example | `lua-example-072` | Lua 示例 072: 真实项目重构练习 | 0 | 一致 |
| 173 | example | `lua-example-073` | Lua 示例 073: 数据建模与不变量 | 0 | 一致 |
| 174 | example | `lua-example-074` | Lua 示例 074: 输入校验与错误边界 | 0 | 一致 |
| 175 | example | `lua-example-075` | Lua 示例 075: 文件格式与编码 | 0 | 一致 |
| 176 | example | `lua-example-076` | Lua 示例 076: 日志与可观测性 | 0 | 一致 |
| 177 | example | `lua-example-077` | Lua 示例 077: 缓存与失效策略 | 0 | 一致 |
| 178 | example | `lua-example-078` | Lua 示例 078: 队列与批处理 | 0 | 一致 |
| 179 | example | `lua-example-079` | Lua 示例 079: 分页与排序 | 0 | 一致 |
| 180 | example | `lua-example-080` | Lua 示例 080: 配置与环境隔离 | 0 | 一致 |
| 181 | example | `lua-example-081` | Lua 示例 081: 并发与资源生命周期 | 0 | 一致 |
| 182 | example | `lua-example-082` | Lua 示例 082: 测试夹具与回归 | 0 | 一致 |
| 183 | example | `lua-example-083` | Lua 示例 083: 性能测量与优化 | 0 | 一致 |
| 184 | example | `lua-example-084` | Lua 示例 084: 安全边界与最小权限 | 0 | 一致 |
| 185 | example | `lua-example-085` | Lua 示例 085: 网络协议与重试 | 0 | 一致 |
| 186 | example | `lua-example-086` | Lua 示例 086: 持久化与迁移 | 0 | 一致 |
| 187 | example | `lua-example-087` | Lua 示例 087: 命令行工具设计 | 0 | 一致 |
| 188 | example | `lua-example-088` | Lua 示例 088: 模块边界与依赖方向 | 0 | 一致 |
| 189 | example | `lua-example-089` | Lua 示例 089: 状态机与事件流 | 0 | 一致 |
| 190 | example | `lua-example-090` | Lua 示例 090: 时间、时区与截止时间 | 0 | 一致 |
| 191 | example | `lua-example-091` | Lua 示例 091: 文本处理与国际化 | 0 | 一致 |
| 192 | example | `lua-example-092` | Lua 示例 092: 故障恢复与幂等性 | 0 | 一致 |
| 193 | example | `lua-example-093` | Lua 示例 093: 资源打包与发布 | 0 | 一致 |
| 194 | example | `lua-example-094` | Lua 示例 094: 增量计算与差分 | 0 | 一致 |
| 195 | example | `lua-example-095` | Lua 示例 095: API 契约与版本兼容 | 0 | 一致 |
| 196 | example | `lua-example-096` | Lua 示例 096: 真实项目重构练习 | 0 | 一致 |
| 197 | example | `lua-example-097` | Lua 示例 097: 数据建模与不变量 | 0 | 一致 |
| 198 | example | `lua-example-098` | Lua 示例 098: 输入校验与错误边界 | 0 | 一致 |
| 199 | example | `lua-example-099` | Lua 示例 099: 文件格式与编码 | 0 | 一致 |
| 200 | example | `lua-example-100` | Lua 示例 100: 日志与可观测性 | 0 | 一致 |
