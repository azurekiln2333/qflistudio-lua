# B 审计：Lua 教程与示例逐项完整性（content-audit）

- 任务：`.trellis/tasks/10-15-lua-store-readiness`（planning）
- 范围：**只审计 Lua 内容**，只读。未修改任何产品/共享资产，未删除数据，未 `task.py start`，未提交。
- 工作区：`D:/MyNewProjects/qfli_lua`（Flutter/QFLIScript，cwd 已确认）
- 共享核心：`D:/MyNewProjects/qfli_studio_core`
- 运行环境（真实执行）：Dart 3.11.5 + 打包内 Lua 5.4.8（`bin/qfli_lua.dart`，`Lua 5.4.8`）
- 生成物：`research/lua-exec-results.json`、`research/_audit*.py`、`research/verify_lua_content.dart`

---

## 1. 结论速览

| 项目 | 结果 |
| --- | --- |
| Lua 教程条目数 | **100**（`lua-tutorial-001..100`） |
| Lua 示例条目数 | **100**（`lua-example-001..100`） |
| 教程实现课节数 | **100**（每条目恰好 1 节 `*-lesson`） |
| 真实 Lua 5.4.8 执行 | **200/200 语法/运行通过**，输出与声明一致 |
| 内容真实性 | **失败**：100 条教程 = 同一加权求和模板，仅数字不同 |
| 主题一致性 | **失败**：100 条中仅 9 条代码与标题主题沾边 |
| 机械重复 | **失败**：`explain` 100/100 相同；`lesson.summary` 100/100 相同；24 个 lesson 标题各重复 4–5 次 |
| 空代码 | 0（但全部为模板重写） |
| 运行时声明 | `lua.json` 仍写 `status: planned`「开发中」，与已可运行的原生后端矛盾 |

**判定：现有 100+100 条属于「可执行但语义为占位」的批量填充内容，不构成从入门到精通的 Lua 教程，必须重建。**

---

## 2. 真实存储位置与加载链（精确边界）

Lua 教程/示例的**运行时真实来源**不是按语言分的文件，而是两份聚合 JSON：

- `D:/MyNewProjects/qfli_studio_core/assets/content/tutorials.json`（3,743,502 B；1620 条，其中 Lua **100**）
- `D:/MyNewProjects/qfli_studio_core/assets/content/examples.json`（1,784,445 B；1620 条，其中 Lua **100**）

加载链：

1. `lib/content/asset_content_repository.dart:11-12` — `tutorialAsset = 'assets/content/tutorials.json'`、`exampleAsset = 'assets/content/examples.json'`，`_parseCatalog` 在 isolate 解析。
2. `lib/content/content_repository.dart` — `ContentCatalog.fromJson`；`ContentFilter(language:'lua')` 或 `ContentFilter.forProduct('script'|'qflistudio')` 过滤。
3. `lib/content/local_content_adapter.dart` — 把聚合条目转成旧页面模型 `Tutorial`/`ExampleCode`（教程每条目 → 一个 chapter + 一个 lesson）。
4. `lib/pages/local_content_pages.dart` — `LocalTutorialsTab` / `ExampleCodeTab` 用 `AssetContentRepository` + `LocalContentAdapter` 渲染。

**遗留备用路径（不影响本次替换，但需知悉）：**

- `lib/services/tutorial_service.dart:33` — `TutorialService` 按 `assets/tutorials/<language>.json` 读取，`bundledLanguages` 含 `lua`。
- `D:/MyNewProjects/qfli_studio_core/assets/tutorials/lua.json`（**2,177 B**，仅 2 章 2 节，`runtime.status: "planned"`）——旧格式单语言文件。
- 页面主路径走聚合 JSON；`lua.json` 是兼容/测试路径。**重建时两份 Lua 数据都要保持字段自洽**（见 §6）。

内容消费端过滤在 `ContentProductTypes.byProduct`（`content_repository.dart`）：`script` → `{lua, javascript, typescript, shell}`，`qflistudio` → all。Lua 产品档 `luaProfile`（`qfli_lua/lib/main.dart:24`）走 `language:'lua'` 过滤。

---

## 3. 占位证据（可复核）

### 3.1 全部 100 条教程的 code 是同一模板

正则 `^local values = \{\d+, \d+, \d+\}\nlocal total = 0\nfor position, value in ipairs\(values\) do total = total \+ value \* position end\nprint\("weighted=" \.\. total\)$`

- 命中 **100/100**；`code` 首行形态统计：`local values = {N, N, N}` × **100**。
- 数值即索引：`lua-tutorial-00k` → `{k, k+2, k+4}`；`output = weighted=<6k+16>`。
- 200 条（教程+示例）去重后的 stdout 仅 **100** 个不同值，全部形如 `weighted=NN`。

样例（`tutorials.json` 内条目）：

| id | level | title | lesson.title | code | output |
| --- | --- | --- | --- | --- | --- |
| lua-tutorial-001 | beginner | Lua 001: 数据建模与不变量 | 实现：数据建模与不变量 | `local values = {1, 3, 5}\nlocal total = 0\nfor position, value in ipairs(values) do total = total + value * position end\nprint("weighted=" .. total)` | `weighted=22` |
| lua-tutorial-002 | beginner | Lua 002: 输入校验与错误边界 | 实现：输入校验与错误边界 | `local values = {2, 4, 6}\n...` | `weighted=28` |
| lua-tutorial-100 | advanced | Lua 100: 日志与可观测性 | 实现：日志与可观测性 | `local values = {100, 102, 104}\n...` | `weighted=616` |

### 3.2 `explain` / `summary` 完全重复

- `lesson.explain` 唯一值数 = **1**（100/100 相同）：
  「先定义契约，再实现主路径，最后用失败输入验证行为不会漂移。……」
- `lesson.summary` 唯一值数 = **1**（100/100 相同）。
- 顶层 `summary` 有 24 个重复值（各出现 4–5 次），对应 24 个被复用的主题词。
- lesson 标题仅 24 种，各重复 4–5 次（`实现：数据建模与不变量` 等）。

### 3.3 标题 ↔ 代码语义不匹配

按 24 个主题关键词（table/assert/io.open/coroutine/pcall/require/os.date/string/...）检查代码：

- 对齐 **9/100**；其余 **91 条** 标题宣称的主题在代码里完全不存在（例：`lua-tutorial-009 并发与资源生命周期` 代码无 `coroutine`；`lua-tutorial-013 网络协议与重试` 无网络；`lua-tutorial-020 故障恢复与幂等性` 无 `pcall`）。
- 所有主题都被同一 `ipairs` 加权求和覆盖。

### 3.4 示例与教程同源、编号造假

- `examples.json` 的 100 条 Lua 与教程一一对应（`sourceLessonId = lua-tutorial-NNN-lesson`），`code`/`expectedOutput` 与教程完全相同。
- `inputFixtures` 全是 `{'case': 'fixture-N', 'mode': 'deterministic'}`，与代码无实际交互（代码不读 stdin）。
- `templateType` 全为 `lua`；`expectedOutput` 100 个唯一值＝加权和数字。

### 3.5 上游生成器旁证

`qfli_studio_core/tool/generate_python_content.dart` 的 `_checkTopics` 明确禁止占位：

```dart
if (t.code.contains('weighted=')) {
  throw StateError('Topic ${t.id} looks like placeholder padding');
}
if (t.code.trim().split('\n').length < 2) { throw ... }
if (!codes.add(t.code)) { throw StateError('Duplicate code body ...'); }
```

Python/Java 有专属主题源（`tool/python_content/*.dart` 186KB、`tool/java_content/*.dart` 127KB）与 `generate_*/verify_*` 工具。**Lua 没有生成器/校验器**，是被批量填入同一个 `weighted=` 模板的语言——正是 Python 工具显式拒绝的形态。

### 3.6 真实执行结果（复核口径）

harness：`research/verify_lua_content.dart`（运行 `Lua 5.4.8`，逐条写临时项目 `main.lua`，必要时写 `input.txt`，5s 超时，比较 stdout 与声明的 `output`/`expectedOutput`）。

```
runtime: Lua 5.4.8
verified=200 ok=200 fail=0
```

→ 占位内容**语法正确且可运行**，问题在语义/课程价值，而非可执行性。重建验收不能只靠「能跑」，必须有主题一致性断言。

### 3.7 运行时元数据过期

`assets/tutorials/lua.json` 的 `runtime.status = "planned"`，`engine = "应用内 Lua 解释器（开发中）"`，`limits = "当前版本只提供编辑器、教程和示例代码，运行后端接入后会更新这里"` —— 但原生后端已接入并验证可用（`native/`、`lib/lua_toolchain.dart`、本次 200/200 执行）。重建时需同步更正为可用状态。

---

## 4. 需修改的精确共享核心资产（重建边界）

> 仅下列 Lua 数据可改；**不得触碰其他语言行**。聚合文件由多语言共用，必须「读活文件、只替换 Lua 行、保留其他行与顶层元数据」。

| 文件 | 操作 | 说明 |
| --- | --- | --- |
| `qfli_studio_core/assets/content/tutorials.json` | **替换** 仅 `language == "lua"` 的 100 行 | 保留其余 1520 行逐字节不变；保留顶层 `schemaVersion/kind`，更新 `updatedAt` |
| `qfli_studio_core/assets/content/examples.json` | **替换** 仅 `language == "lua"` 的 100 行 | 同上 |
| `qfli_studio_core/assets/tutorials/lua.json` | **重建** | 旧格式兼容文件；更新 `runtime` 为可用，章节与聚合数据一致 |
| `qfli_studio_core/tool/`（新增 `generate_lua_content.dart` / `verify_lua_content.dart` / `lua_content/lua_topics*.dart`） | **新增** | 仿 `tool/python_content` 的 Lua 专属主题源 + 生成器 + 校验器（本次审计的 `verify_lua_content.dart` 可迁移为正式校验器） |

**不改动**：`content_repository.dart`、`local_content_adapter.dart`、`local_content_pages.dart`、`asset_content_repository.dart` 等加载/过滤代码（契约已足够，无需改结构）；其他语言资产；`qfli_lua` 产品侧。若 Lua 需要新等级/难度枚举，才评估 `ContentFilter`/校验器改动，并单独列出。

### 4.1 精确替换边界（已实测）

`entries` 数组中 Lua 行是**连续块**，两份文件都在**索引 200..299**（共 100 行）：

| 文件 | 总行数(JSON) | 文件行号(首个/末个 Lua id) | Lua 索引区间 | 连续 |
| --- | --- | --- | --- | --- |
| `assets/content/tutorials.json` | 74851 | 9838 / 14293 | 200..299 | 是 |
| `assets/content/examples.json` | 39855 | 4779 / 7254 | 200..299 | 是 |
| | | | | |
| 前置条目 | `c`×100, `cpp`×100 | | | |
| 后置条目 | python×120, javascript/typescript/shell/rust/go/html/css/dart/sql/json/markdown/java 各×100 | | | |

**非 Lua 行指纹（替换前后必须一致，作为「未串改」证据）：**

- `tutorials.json` 非 Lua 1520 行（按 sort_keys 规范 JSON 顺序哈希）：`d4552b5eb106e36fd93b705b7c477f9c…`
- `examples.json` 非 Lua 1520 行：`a43308e13595294213238a29d0ec6520…`
- 顶层：`schemaVersion=1, kind=tutorials|examples, updatedAt=2026-10-11`（重建时仅更新 `updatedAt`）。

> 生成器实现建议：读取活文件后，用 `entries[200:300]` 定位并只重写 `language == "lua"` 行；即使顺序变化，也按 `language` 过滤而非硬编码下标，并以非 Lua 指纹断言收尾。

---

## 5. 分层主题目录建议（100+ 教程）

目标：真正「从入门到精通」，每主题代码必须体现该主题，且可在 Lua 5.4.8 真实执行。

- **L1 入门基础（~20）**：环境与首程序、`print`/`io.write`、注释、变量与 `local`、类型（nil/boolean/number/string）、算术与关系/逻辑运算、字符串基础与连接、字符串格式化、条件 `if/elseif/else`、`while`/`repeat`、数值 `for`、泛型 `for`、`break`/`goto`、table 构造、数组与 `ipairs`、`pairs` 与字典、`#` 长度、多返回值、可变参数、作用域规则。
- **L2 函数与数据结构（~20）**：函数定义/多返回、闭包与上值、递归、尾调用、函数作为一等值、高阶函数、`table` 库、`string` 库、`math` 库、日期时间 `os.date`/`os.time`、元表 `__index`、`__newindex`、`__call`/`__add` 等运算符、`__tostring`、面向对象（表+方法+`self`）、继承、`__gc`/`__close`、迭代器协议与自定义迭代器、`coroutine` 基础。
- **L3 进阶与工程（~30）**：模块 `require`、`package.path`、错误处理 `pcall`/`xpcall`/`error`、自定义错误对象、`assert` 契约与不变量、文件 I/O（`io.open` 读写、`io.lines`）、序列化、模式匹配（`string.match/gsub/find`）、`string.format` 与编码、受保护资源与 `__close`、标准输入 `io.read` 与 `input.txt`、命令行参数 `arg`、环境与沙箱（`load`/`setfenv` 等价 `_ENV`）、`load`/`loadstring`、字节码 `luac`、`debug` 基础、性能测量 `os.clock`、字符串缓冲优化（`table.concat`）、垃圾回收与弱表、协程调度、C API 概览、UTF-8 库、随机数与确定性测试。
- **L4 精通与实战（~30+）**：状态机、事件循环、队列/批处理、缓存与失效、分页与排序、配置加载、持久化与迁移、增量计算、日志与可观测性、故障恢复与幂等、并发与资源生命周期、网络协议与重试（纯 Lua 建模/离线可跑）、测试夹具与回归、性能剖析与优化、内存与 GC 调优、安全边界与最小权限、API 契约与版本兼容、模块边界与依赖方向、时间/时区/截止时间、文本处理与国际化、错误边界与输入校验、数据建模与不变量、真实项目重构、打包与发布、语言互操作概念。

总量 **100–120**（可按 20/20/30/40 分布），每教程 1 主课 + 1 练习；配 **100+ 示例**，示例标题/代码/期望输出与对应课节主题一致。

---

## 6. 重建与验证方案

### 6.1 生成方式（仿 Python 工具）

- 新增 `tool/lua_content/lua_topic.dart`（模型：id、level、title、summary、concepts、objective、prerequisites、explain、pitfalls、code、output、tasks、inputFixtures）。
- 新增 `tool/lua_content/lua_topics*.dart`（入门/函数/进阶/精通分文件）。
- `tool/generate_lua_content.dart`：
  - `_checkTopics` 强制：≥100、id 连续 1..N、title/code 唯一、code 多行、**禁止 `weighted=`**、每主题 code 必含主题关键 API（可维护 `topicKeyword` 映射断言）。
  - **读活文件**，仅移除并重写 `language == "lua"` 行，原样保留其他语言的 raw map 与顶层字段；同时记录其他语言指纹供校验器比对（防串改）。
  - 同步重写 `assets/tutorials/lua.json`，`runtime.status` 改为 `available`，`engine` 指向 `Lua 5.4.8 原生后端`。

### 6.2 真实执行验证

- 迁移本次 `research/verify_lua_content.dart` 为 `tool/verify_lua_content.dart`：逐条经 `bin/qfli_lua.dart`/`LuaToolchain` 用**打包内 Lua 5.4.8** 真跑，比对 `output`/`expectedOutput` 与 stdin fixture，断言：
  - 全部 status==0；
  - stdout 与声明一致；
  - 主题关键词命中（占位回归防线）；
  - code/标题无重复。
- 追加 `flutter test`：内容校验器（`ContentCatalogValidator.validateForRelease`，每 type ≥100）、页面渲染、导入工作流（沿用既有 `content_*_test.dart` 口径，但**不改这些测试**，只保证 Lua 新数据通过）。
- 其他语言保护：生成前后对非 Lua 行做指纹比对，必须在报告中给出「未变动」证据。

### 6.3 验收标准

- [ ] Lua 教程 ≥100、示例 ≥100，id 连续、title/code 唯一。
- [ ] 每教程代码体现其标题主题（关键词断言通过率 100%）。
- [ ] 200+ 条经真实 Lua 5.4.8 执行，status 0 且输出匹配。
- [ ] `explain`/`summary` 不再全体重复；lesson 标题无 4–5 次机械复用。
- [ ] 非 Lua 内容逐字节未变（指纹证据）。
- [ ] `assets/tutorials/lua.json` 的 `runtime` 与实际后端一致。
- [ ] 无 `weighted=` 占位签名残留。

---

## 7. 影响面 / 风险

- 聚合 JSON 是共享文件，**必须在同一轮内只替换 Lua 行**；其他并行 worker 可能同时改其他语言 → 生成器须「读当前文件」而非从备份恢复。
- 若 Lua 产品不展示某些等级或字段，`ContentFilter`/渲染无需改动（按 `language:'lua'` 过滤，字段均已支持 `objective/prerequisites/pitfalls`，见 `content_repository.dart` 与 `local_content_adapter.dart`）。
- 本次审计未触碰任何产品/资产文件；所有写入仅限 `.trellis/tasks/10-15-lua-store-readiness/research/`。

---

## 8. 复核命令

```powershell
# cwd: D:/MyNewProjects/qfli_lua
$dart = "D:\ProgramFiles\flutter_ohos\bin\cache\dart-sdk\bin\dart.exe"
python .trellis/tasks/10-15-lua-store-readiness/research/_audit1.py   # 数量/重复统计
python .trellis/tasks/10-15-lua-store-readiness/research/_audit3.py   # 模板命中与主题对齐
& $dart run .trellis/tasks/10-15-lua-store-readiness/research/verify_lua_content.dart
# -> verified=200 ok=200 fail=0 ; 结果见 research/lua-exec-results.json
```
