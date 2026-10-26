import 'lua_topic.dart';

/// 第二十三章：综合项目。
const List<LuaTopic> topicsProject = [
  LuaTopic(
    id: 'lua-proj-cli-args',
    chapter: 'project',
    title: '读取命令行参数',
    summary: '用 ... 或 arg 表拿到脚本参数，并校验数量。',
    objective: '能写一个带参数校验的脚本入口。',
    level: 'beginner',
    concepts: ['命令行参数', 'arg', '校验'],
    explain:
        '独立脚本里全局表 arg 存放参数，arg[1] 是第一个参数，'
        'arg[0] 是脚本名，负数下标是解释器选项。'
        '用 ... 也能在主块里拿到参数。'
        '入口函数要先检查参数个数和类型，再继续。',
    code: r'''local function usage(program)
  return string.format("用法：%s <名字>", program)
end

local function main(...)
  local args = { ... }
  if #args == 0 then
    return nil, usage("program")
  end
  return "你好，" .. args[1], nil
end

print(main("小明"))
print(main())

local ok = main("A", "B")
print(ok)

print(type(arg) == "table" or arg == nil)
print(select("#", ...) >= 0)
print(type(usage) == "function")
''',
    output:
        '你好，小明\tnil\nnil\t用法：program <名字>\n你好，A\ntrue\ntrue\n'
        'true\n',
    exercises: [
      LuaExercise(
        prompt: '校验至少传入两个参数否则返回 nil 和提示。',
        hint: '#args < 2。',
        answer: 'if #args < 2 then return nil, "需要两个参数" end',
      ),
      LuaExercise(
        prompt: '为什么入口用 main(...) 而不是直接用 arg？',
        hint: '想想可测试性。',
        answer: '因为 ... 让入口可以直接传参调用，测试时不必伪造全局 arg 表。',
      ),
    ],
    pitfalls: ['arg 是全局变量，被外部改写会导致参数丢失。', '参数都是字符串，需要数字时要显式 tonumber。'],
  ),
  LuaTopic(
    id: 'lua-proj-config',
    chapter: 'project',
    title: '配置合并与默认值',
    summary: '把用户配置覆盖到默认值上，缺省项保持默认。',
    objective: '能写出不修改默认表的安全合并函数。',
    level: 'beginner',
    concepts: ['默认值', '合并', '不修改入参'],
    explain:
        '常见做法是复制默认表再逐项覆盖。'
        '不要在默认表上直接改，否则多次调用会互相污染。'
        '嵌套表要么深拷贝，要么约定只支持一层。',
    code: r'''local defaults = { host = "127.0.0.1", port = 8080, retries = 3 }

local function merge(base, override)
  local result = {}
  for key, value in pairs(base) do result[key] = value end
  for key, value in pairs(override or {}) do result[key] = value end
  return result
end

local config = merge(defaults, { port = 9000 })
print(config.host, config.port, config.retries)
print(defaults.port)

local custom = merge(defaults, { retries = 0 })
print(custom.retries)
print(config.retries)

local emptyConfig = merge(defaults)
print(emptyConfig.port)

print(defaults.port == 8080)
local a = merge(defaults)
a.port = 1
print(defaults.port, a.port)
''',
    output: '127.0.0.1\t9000\t3\n8080\n0\n3\n8080\ntrue\n8080\t1\n',
    exercises: [
      LuaExercise(
        prompt: '让 merge 支持把 nil 视为「使用默认值」。',
        hint: '覆盖时跳过 nil。',
        answer:
            'for key, value in pairs(override or {}) do if value ~= nil then result[key] = value end end',
      ),
      LuaExercise(
        prompt: '为什么不能直接改 defaults？',
        hint: '想想复用。',
        answer: '因为 defaults 是共享的，改了之后后续调用都会受影响，测试之间也会互相污染。',
      ),
    ],
    pitfalls: ['浅合并不处理嵌套表，嵌套配置会整体替换。', 'pairs 顺序不固定，日志输出要先排序。'],
  ),
  LuaTopic(
    id: 'lua-proj-result-type',
    chapter: 'project',
    title: '统一的 Result 返回值风格',
    summary: '约定成功返回数据、失败返回 nil 加错误码，调用方统一处理。',
    objective: '能设计一致的错误返回约定，并写出 unpack 风格的包装。',
    level: 'intermediate',
    concepts: ['错误约定', '返回值', '一致性'],
    explain:
        'Lua 没有异常类型系统，常见约定是：'
        '成功返回 value，失败返回 nil, err, code。'
        '所有函数遵循同一约定，调用方就能用统一模式处理，'
        '也能配合 or 提供默认值。',
    code: r'''local function parsePort(text)
  local number = tonumber(text)
  if not number then return nil, "端口必须是数字", "E_TYPE" end
  if number < 1 or number > 65535 then return nil, "端口超出范围", "E_RANGE" end
  return math.floor(number), nil, nil
end

local function show(...)
  local value, message, code = ...
  if value then return string.format("ok: %s", tostring(value)) end
  return string.format("%s (%s)", message, code)
end

print(show(parsePort("8080")))
print(show(parsePort("abc")))
print(show(parsePort("70000")))

local port = parsePort("8080") or 80
print(port)

local invalid = parsePort("x") or 80
print(invalid)

print(select("#", parsePort("8080")))
''',
    output: 'ok: 8080\n端口必须是数字 (E_TYPE)\n端口超出范围 (E_RANGE)\n8080\n80\n3\n',
    exercises: [
      LuaExercise(
        prompt: '给结果加一个统一的 unwrap：失败就抛错。',
        hint: '判断第一个返回值。',
        answer:
            'local function unwrap(v, err) if not v then error(err, 2) end return v end',
      ),
      LuaExercise(
        prompt: '为什么错误码要用字符串常量？',
        hint: '想想日志与国际化。',
        answer: '因为错误码可以被程序判断、被日志检索，而人类可读的消息可以随时改写或翻译。',
      ),
    ],
    pitfalls: ['只返回 nil 不带原因，调用方无法区分不同失败。', '用 or 提供默认值时失败原因会被丢掉。'],
  ),
  LuaTopic(
    id: 'lua-proj-validate-schema',
    chapter: 'project',
    title: '表结构校验',
    summary: '用一张规则表描述字段类型与必填，再统一校验。',
    objective: '能写出数据驱动的校验器，并收集全部错误而不是只报第一个。',
    level: 'intermediate',
    concepts: ['校验', '规则表', '错误列表'],
    explain:
        '把字段规则写成表：required、type、range。'
        '校验器遍历规则，把所有问题收集进数组，'
        '比「遇到第一个错误就返回」更友好，'
        '用户一次就能看到全部问题。',
    code: r'''local schema = {
  name = { required = true, type = "string" },
  age = { required = true, type = "number", min = 0 },
  email = { type = "string" },
}

local function validate(data, rules)
  local errors = {}
  for field, rule in pairs(rules) do
    local value = data[field]
    if value == nil then
      if rule.required then errors[#errors + 1] = field .. " 必填" end
    else
      if rule.type and type(value) ~= rule.type then
        errors[#errors + 1] = string.format("%s 必须是 %s", field, rule.type)
      elseif rule.min and value < rule.min then
        errors[#errors + 1] = string.format("%s 不能小于 %d", field, rule.min)
      end
    end
  end
  table.sort(errors)
  return #errors == 0, errors
end

local ok, errors = validate({ name = "小明", age = -1 }, schema)
print(ok)
print(#errors)
print(errors[1])

local ok2, errors2 = validate({ name = "小明", age = 18, email = "a@b" }, schema)
print(ok2, #errors2)

local ok3, errors3 = validate({ age = "18" }, schema)
print(ok3, table.concat(errors3, " / "))
''',
    output: 'false\n1\nage 不能小于 0\ntrue\t0\nfalse\tage 必须是 number / name 必填\n',
    exercises: [
      LuaExercise(
        prompt: '给规则加一个「长度至少 N」的检查。',
        hint: '在规则里加 minLength。',
        answer:
            'if rule.minLength and #value < rule.minLength then errors[#errors+1] = field .. " 太短" end',
      ),
      LuaExercise(
        prompt: '为什么先排序错误列表？',
        hint: 'pairs 的顺序。',
        answer: '因为规则表遍历顺序不固定，排序后错误顺序稳定，便于断言和展示。',
      ),
    ],
    pitfalls: ['table.sort 只能排序连续数组，稀疏表会报错。', '只检查类型不检查语义，仍可能放过非法值。'],
  ),
  LuaTopic(
    id: 'lua-proj-memo-cache',
    chapter: 'project',
    title: '带容量上限的缓存',
    summary: '缓存命中要更新访问顺序，超出容量时淘汰最久未用项。',
    objective: '能实现简单的 LRU 缓存，并说明命中率与容量权衡。',
    level: 'advanced',
    concepts: ['LRU', '容量', '淘汰'],
    explain:
        '最简实现：命中时把键移到顺序表末尾，'
        '插入超出容量时删掉表头。'
        '这样末尾是最近使用、表头是最久未用。'
        '代价是每次命中都要做一次线性查找。',
    code: r'''local function newCache(capacity)
  local order = {}
  local values = {}

  local function touch(key)
    for index, existing in ipairs(order) do
      if existing == key then
        table.remove(order, index)
        break
      end
    end
    order[#order + 1] = key
  end

  local cache = {}

  function cache.get(key)
    if values[key] == nil then return nil end
    touch(key)
    return values[key]
  end

  function cache.set(key, value)
    values[key] = value
    touch(key)
    while #order > capacity do
      local evicted = table.remove(order, 1)
      values[evicted] = nil
    end
  end

  function cache.keys()
    return table.concat(order, ",")
  end

  return cache
end

local cache = newCache(2)
cache.set("a", 1)
cache.set("b", 2)
print(cache.get("a"))
cache.set("c", 3)
print(cache.keys())
print(cache.get("b") == nil)
print(cache.get("a"))

cache.set("a", 10)
print(cache.keys())
print(cache.get("a"))
''',
    output: '1\na,c\ntrue\n1\nc,a\n10\n',
    exercises: [
      LuaExercise(
        prompt: '加一个命中计数器。',
        hint: '在 get 命中时累加。',
        answer: '在 get 成功分支里 hits = hits + 1，并提供 cache.hits 函数返回它。',
      ),
      LuaExercise(
        prompt: '为什么 set 已存在的键也要 touch？',
        hint: '想想顺序语义。',
        answer: '因为更新也算一次使用，不更新顺序会让热点键被误淘汰。',
      ),
    ],
    pitfalls: [
      '线性查找让 get 变成 O(n)，大缓存要换成双向链表。',
      'values[key] == nil 无法缓存 nil 值，需要哨兵。',
    ],
  ),
  LuaTopic(
    id: 'lua-proj-word-count',
    chapter: 'project',
    title: '词频统计',
    summary: '切词、计数、排序、输出前 N 名，完整的小数据处理流程。',
    objective: '能组合 gmatch、表计数和自定义排序完成统计任务。',
    level: 'intermediate',
    concepts: ['词频', '计数', '排序'],
    explain:
        '用 gmatch("%a+") 切出单词，统一小写后计数，'
        '再把表转成数组按次数排序。'
        '次数相同时按字母序，保证输出稳定。',
    code: r'''local text = "The cat and the dog and the bird"

local counts = {}
for word in text:gmatch("%a+") do
  local key = word:lower()
  counts[key] = (counts[key] or 0) + 1
end

local ranked = {}
for word, count in pairs(counts) do
  ranked[#ranked + 1] = { word = word, count = count }
end

table.sort(ranked, function(a, b)
  if a.count ~= b.count then return a.count > b.count end
  return a.word < b.word
end)

print(#ranked)
print(ranked[1].word, ranked[1].count)
print(ranked[2].word, ranked[2].count)

for index = 1, 3 do
  io.write(ranked[index].word, "=", ranked[index].count, " ")
end
print()

local top = ranked[1]
print(string.format("最高频：%s(%d)", top.word, top.count))
''',
    output: '5\nthe\t3\nand\t2\nthe=3 and=2 bird=1 \n最高频：the(3)\n',
    exercises: [
      LuaExercise(
        prompt: '忽略长度小于 3 的词。',
        hint: '在计数前判断。',
        answer: 'if #key >= 3 then counts[key] = (counts[key] or 0) + 1 end',
      ),
      LuaExercise(
        prompt: '为什么排序要加字母序的次级条件？',
        hint: '想想次数相同的情况。',
        answer: '因为次数相同时比较结果不确定，加次级条件才能得到稳定输出。',
      ),
    ],
    pitfalls: [
      'gmatch("%a+") 只按 ASCII 切词，中文会被忽略。',
      'table.sort 的比较函数必须严格弱序，否则行为未定义。',
    ],
  ),
  LuaTopic(
    id: 'lua-proj-todo-cli',
    chapter: 'project',
    title: '命令行待办清单',
    summary: '用子命令模式实现 add/list/done，状态保存在内存表里。',
    objective: '能用命令表分派实现小型 CLI，并处理未知命令。',
    level: 'intermediate',
    concepts: ['子命令', '分派', '状态'],
    explain:
        '把每个子命令写成一个函数，放进 commands 表，'
        '主流程只做「查表 + 调用 + 未知命令报错」。'
        '这种写法扩展新命令只需加一个函数，'
        '也方便为每个命令单独写测试。',
    code: r'''local function newTodoList()
  local items = {}
  local nextId = 1

  local commands = {}

  function commands.add(title)
    items[nextId] = { id = nextId, title = title, done = false }
    nextId = nextId + 1
    return "已添加：" .. title
  end

  function commands.list()
    local lines = {}
    for _, item in ipairs(items) do
      local mark = item.done and "[x]" or "[ ]"
      lines[#lines + 1] = string.format("%s %d. %s", mark, item.id, item.title)
    end
    return table.concat(lines, "\n")
  end

  function commands.done(id)
    local item = items[tonumber(id)]
    if not item then return nil, "找不到 " .. tostring(id) end
    item.done = true
    return "已完成：" .. item.title
  end

  return function(name, ...)
    local handler = commands[name]
    if not handler then return nil, "未知命令：" .. tostring(name) end
    return handler(...)
  end
end

local run = newTodoList()
print(run("add", "写文档"))
print(run("add", "跑测试"))
print(run("done", "2"))
print(run("list"))
print(run("remove", "1"))

local ok, err = run("done", "99")
print(ok, err)
''',
    output:
        '已添加：写文档\n已添加：跑测试\n已完成：跑测试\n'
        '[ ] 1. 写文档\n[x] 2. 跑测试\nnil\t未知命令：remove\nnil\t找不到 99\n',
    exercises: [
      LuaExercise(
        prompt: '增加 remove 子命令。',
        hint: '在 commands 表里加函数。',
        answer:
            'function commands.remove(id) local key = tonumber(id); if not items[key] then return nil, "找不到" end; items[key] = nil; return "已删除" end',
      ),
      LuaExercise(
        prompt: '为什么用闭包而不是全局表存 items？',
        hint: '想想多实例。',
        answer: '因为闭包让每份列表都有独立状态，可以同时创建多个互不影响的实例。',
      ),
    ],
    pitfalls: [
      'items 用数字下标且会被删除，ipairs 遇到空洞会提前停止。',
      '子命令参数都是字符串，比较数字前要 tonumber。',
    ],
  ),
  LuaTopic(
    id: 'lua-proj-test-harness',
    chapter: 'project',
    title: '手写测试框架',
    summary: '用断言、用例表与统计输出搭一个最小测试框架。',
    objective: '能写出可复用的测试运行器，并输出通过/失败统计。',
    level: 'intermediate',
    concepts: ['测试框架', '断言', '统计'],
    explain:
        '最小可用测试框架只需要三件事：'
        '收集用例（名字 + 函数）、逐个 pcall 执行、统计并打印失败详情。'
        '把失败用例的消息截断回显，就能一眼看出哪个断言炸了。',
    code: r'''local Runner = {}
Runner.__index = Runner

function Runner.new()
  return setmetatable({ cases = {}, passed = 0, failed = 0 }, Runner)
end

function Runner:test(name, fn)
  self.cases[#self.cases + 1] = { name = name, fn = fn }
  return self
end

function Runner:run()
  for _, case in ipairs(self.cases) do
    local ok, err = pcall(case.fn)
    if ok then
      self.passed = self.passed + 1
    else
      self.failed = self.failed + 1
      print("失败:", case.name, (tostring(err):gsub("^.*main%.lua:%d+: ", "")))
    end
  end
  return self.passed, self.failed
end

local function eq(actual, expected)
  if actual ~= expected then
    error(string.format("期望 %s，实际 %s", tostring(expected), tostring(actual)))
  end
end

local runner = Runner.new()
runner
  :test("加法", function() eq(1 + 1, 2) end)
  :test("字符串", function() eq(("ab"):upper(), "AB") end)
  :test("故意失败", function() eq(1 + 1, 3) end)

local passed, failed = runner:run()
print(passed, failed)
print(#runner.cases)
print(passed + failed)
''',
    output: '失败:\t故意失败\t期望 3，实际 2\n2\t1\n3\n3\n',
    exercises: [
      LuaExercise(
        prompt: '增加一个 assert 为 nil 时的失败用例。',
        hint: 'eq(nil, 1)。',
        answer: 'runner:test("nil 检查", function() eq(nil, 1) end)',
      ),
      LuaExercise(
        prompt: '为什么用 pcall 包住每个用例？',
        hint: '想想一个错会不会影响其他。',
        answer: '因为错误会中断整个运行，用 pcall 隔开后单个用例失败不影响后续用例执行。',
      ),
    ],
    pitfalls: ['assert 失败的消息带路径前缀，断言前要处理。', '用例之间共享状态会导致顺序依赖。'],
  ),
  LuaTopic(
    id: 'lua-proj-pipeline',
    chapter: 'project',
    title: '数据管道',
    summary: '把过滤、映射、聚合拆成独立步骤并串联。',
    objective: '能写出可组合的管道，并说明它与链式循环的取舍。',
    level: 'intermediate',
    concepts: ['管道', '组合', '中间表'],
    explain:
        '把每个变换写成接收数组返回数组的函数，'
        '再用 pipe 依次应用。'
        '好处是每一步都能单独测试，'
        '代价是每步都生成中间表，数据量大时要考虑惰性迭代器版本。',
    code: r'''local function pipe(...)
  local steps = { ... }
  return function(input)
    local value = input
    for _, step in ipairs(steps) do value = step(value) end
    return value
  end
end

local function filter(predicate)
  return function(items)
    local out = {}
    for _, item in ipairs(items) do
      if predicate(item) then out[#out + 1] = item end
    end
    return out
  end
end

local function map(transform)
  return function(items)
    local out = {}
    for _, item in ipairs(items) do out[#out + 1] = transform(item) end
    return out
  end
end

local function sum(items)
  local total = 0
  for _, item in ipairs(items) do total = total + item end
  return total
end

local numbers = { 1, 2, 3, 4, 5, 6 }

local pipeline = pipe(
  filter(function(n) return n % 2 == 0 end),
  map(function(n) return n * n end)
)

local squared = pipeline(numbers)
print(table.concat(squared, ","))
print(sum(squared))
print(sum(pipeline({ 10 })))

print(#numbers)
''',
    output: '4,16,36\n56\n100\n6\n',
    exercises: [
      LuaExercise(
        prompt: '加一步 map 把结果都转成字符串。',
        hint: 'tostring。',
        answer:
            'pipe(filter(...), map(function(n) return n * n end), map(tostring))',
      ),
      LuaExercise(
        prompt: '管道版和单循环版各有什么优劣？',
        hint: '想想可测性与内存。',
        answer: '管道每步可独立测试且可复用，但会生成中间表；单循环内存更省但逻辑耦合难拆。',
      ),
    ],
    pitfalls: ['每一步都新建表，大数据量内存占用会翻倍。', 'pipe 顺序写反容易出错，函数名要能自解释。'],
  ),
  LuaTopic(
    id: 'lua-proj-serialize',
    chapter: 'project',
    title: '可序列化的配置文本',
    summary: '把配置表写成 key=value 文本并可读回，避免依赖第三方库。',
    objective: '能实现简单的序列化与反序列化，并处理转义与类型。',
    level: 'advanced',
    concepts: ['序列化', '解析', '类型恢复'],
    explain:
        '纯 Lua 环境里常需要把配置写进文件。'
        '简单格式是每行 key=value，'
        '读回时统一是字符串，需要按约定恢复类型（如数字）。'
        '值里含换行或等号时要做转义。',
    code: r'''local function escape(value)
  return (tostring(value):gsub("[\\\n=]", function(ch)
    if ch == "\n" then return "\\n" end
    if ch == "\\" then return "\\\\" end
    return "\\="
  end))
end

local function unescape(text)
  return (text:gsub("\\(.)", function(ch)
    if ch == "n" then return "\n" end
    return ch
  end))
end

local function serialize(config, order)
  local lines = {}
  for _, key in ipairs(order) do
    lines[#lines + 1] = key .. "=" .. escape(config[key])
  end
  return table.concat(lines, "\n")
end

local function deserialize(text)
  local result = {}
  for line in text:gmatch("[^\n]+") do
    local key, value = line:match("^([^=]+)=(.*)$")
    if key then result[key] = unescape(value) end
  end
  return result
end

local config = { host = "localhost", port = 8080, note = "a=b" }
local order = { "host", "port", "note" }

local text = serialize(config, order)
print(text)

local parsed = deserialize(text)
print(parsed.host, parsed.port)
print(parsed.note == "a=b")
print(#text > 20)
print(tonumber(parsed.port) + 1)
local literal = [[a\nb]]
print(deserialize(serialize({ note = literal }, { "note" })).note == literal)
''',
    output:
        'host=localhost\nport=8080\nnote=a\\=b\nlocalhost\t8080\ntrue\ntrue\n8081\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '写入含换行的值再读回验证。',
        hint: 'escape/unescape 已处理。',
        answer:
            r'local c = { note = "a\nb" }; print(deserialize(serialize(c, {"note"})).note == "a\nb")',
      ),
      LuaExercise(
        prompt: '为什么序列化要传字段顺序？',
        hint: 'pairs 顺序。',
        answer: '因为 pairs 遍历顺序不固定，显式给出顺序才能得到稳定可 diff 的文本。',
      ),
    ],
    pitfalls: ['反斜杠本身也必须转义，否则原始的反斜杠加 n 会被错误还原成换行。', '反序列化得到全是字符串，类型要另行恢复。'],
  ),
  LuaTopic(
    id: 'lua-proj-refactor',
    chapter: 'project',
    title: '把长函数拆成小函数',
    summary: '识别重复逻辑、命名中间步骤，是重构最稳的起点。',
    objective: '能按「提取函数 + 命名中间值」重构一段难读代码。',
    level: 'intermediate',
    concepts: ['重构', '提取函数', '命名'],
    explain:
        '长函数的问题在于读者要同时跟踪太多状态。'
        '把独立步骤抽成有名字的函数，'
        '主流程就变成一串自解释的调用，'
        '每个小函数也能单独测试。',
    code: r'''-- 重构前：一个函数做三件事
local function reportBefore(rows)
  local total = 0
  for _, row in ipairs(rows) do total = total + row.amount end
  local lines = {}
  for _, row in ipairs(rows) do
    lines[#lines + 1] = string.format("%s:%d", row.name, row.amount)
  end
  return table.concat(lines, ",") .. "|合计" .. total
end

-- 重构后：三步各自命名
local function totalOf(rows)
  local total = 0
  for _, row in ipairs(rows) do total = total + row.amount end
  return total
end

local function renderRows(rows)
  local lines = {}
  for _, row in ipairs(rows) do
    lines[#lines + 1] = string.format("%s:%d", row.name, row.amount)
  end
  return table.concat(lines, ",")
end

local function reportAfter(rows)
  return renderRows(rows) .. "|合计" .. totalOf(rows)
end

local rows = {
  { name = "A", amount = 10 },
  { name = "B", amount = 32 },
}

print(reportBefore(rows))
print(reportAfter(rows))
print(reportBefore(rows) == reportAfter(rows))
print(totalOf(rows))
print(renderRows({}))
print(#renderRows(rows) > 0)
''',
    output: 'A:10,B:32|合计42\nA:10,B:32|合计42\ntrue\n42\n\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '再抽一个「取最大值」的小函数并复用它。',
        hint: '遍历 rows 比较 amount。',
        answer:
            'local function maxOf(rows) local best = 0; for _, r in ipairs(rows) do best = math.max(best, r.amount) end; return best end',
      ),
      LuaExercise(
        prompt: '怎么确认重构没有改变行为？',
        hint: '想想新旧对比。',
        answer: '对同一组输入同时调用新旧函数比较结果，或先补测试再重构。',
      ),
    ],
    pitfalls: ['没有测试就重构容易引入隐性变化。', '拆得过碎会让读者在函数间跳来跳去，按「有意义的步骤」拆即可。'],
  ),
];
