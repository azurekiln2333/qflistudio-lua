import 'lua_topic.dart';

/// 第二十二章：debug 库。
const List<LuaTopic> topicsDebug = [
  LuaTopic(
    id: 'lua-dbg-traceback',
    chapter: 'debug',
    title: 'debug.traceback 收集调用栈',
    summary: '在错误处理里附上调用栈，快速定位问题来源。',
    objective: '能在 xpcall 里生成带调用栈的报告，并保证输出稳定。',
    level: 'intermediate',
    concepts: ['debug.traceback', '调用栈', 'xpcall'],
    explain:
        'debug.traceback(msg, level) 返回一段包含调用栈的文本。'
        '放在 xpcall 的处理器里，就能把「错误消息 + 栈」一起留下。'
        '栈里有绝对路径和行号，做自动化断言时只能检查关键字而不是全文。',
    code: r'''local function inner()
  error("底层失败")
end

local function middle()
  inner()
end

local ok, report = xpcall(middle, function(err)
  return "捕获：" .. debug.traceback(err, 2)
end)

print(ok)
print(report:find("^捕获：") ~= nil)
print(report:find("底层失败") ~= nil)
print(report:find("stack traceback") ~= nil)
print(report:find("upvalue 'inner'") ~= nil)
print(type(debug.traceback("x")))
''',
    output: 'false\ntrue\ntrue\ntrue\ntrue\nstring\n',
    exercises: [
      LuaExercise(
        prompt: '在 xpcall 里生成带调用栈的错误报告。',
        hint: '处理器返回 debug.traceback(err, 2)。',
        answer: 'xpcall(fn, function(err) return debug.traceback(err, 2) end)',
      ),
      LuaExercise(
        prompt: '为什么不要断言栈文本的全文？',
        hint: '想想路径和行号。',
        answer: '因为栈里有绝对路径和行号，换个目录或改几行代码就会变，断言全文必然失败。',
      ),
    ],
    pitfalls: ['level 参数决定跳过几层，传错会丢掉关键帧。', '栈文本与平台路径分隔符有关。'],
  ),
  LuaTopic(
    id: 'lua-dbg-getinfo',
    chapter: 'debug',
    title: 'debug.getinfo 检查函数信息',
    summary: 'getinfo 返回函数的定义位置、行数、参数个数等元信息。',
    objective: '能用 getinfo 判断函数来源，并读取 what/source 字段。',
    level: 'intermediate',
    concepts: ['debug.getinfo', 'what', 'source'],
    explain:
        'debug.getinfo(f) 返回一个表，'
        'what 字段区分 "Lua"、"C" 和 "main"，'
        'linedefined/lastlinedefined 给出定义行范围，'
        'source 是定义它的文件（C 函数以 = 或文件路径表示）。',
    code: r'''local function sample(a, b)
  return a + b
end

local info = debug.getinfo(sample)
print(info.what)
print(type(info.linedefined))
print(info.linedefined > 0)
print(info.nparams)

local printInfo = debug.getinfo(print)
print(printInfo.what == "C")
print(debug.getinfo(1, "S").what)
print(type(info.short_src))
print(debug.getinfo(1000) == nil)
''',

    output: 'Lua\nnumber\ntrue\n2\ntrue\nmain\nstring\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '判断一个函数是 Lua 实现还是 C 实现。',
        hint: '看 what 字段。',
        answer:
            'local function isC(f) return debug.getinfo(f, "S").what == "C" end',
      ),
      LuaExercise(
        prompt: '为什么 print 的 what 是 "C"？',
        hint: '想想实现语言。',
        answer: '因为 print 是标准库用 C 实现的函数，没有 Lua 源码定义行。',
      ),
    ],
    pitfalls: ['getinfo 对不存在的栈层返回 nil。', 'source 字段可能带 @ 前缀或 = 前缀，含义不同。'],
  ),
  LuaTopic(
    id: 'lua-dbg-getlocal',
    chapter: 'debug',
    title: '读取局部变量',
    summary: 'debug.getlocal 可以按名字或下标读取当前栈帧的局部变量。',
    objective: '能用 getlocal 遍历局部变量，并说明它对调试的价值。',
    level: 'advanced',
    concepts: ['debug.getlocal', '局部变量', '栈帧'],
    explain:
        'debug.getlocal(level, index) 返回变量名和值，'
        'index 超出范围时返回 nil。'
        '用它可以在不修改代码的情况下检查函数内部状态，'
        '但也会破坏封装，生产代码不要依赖。',
    code: r'''local function inspect(a, b)
  local sum = a + b
  local names = {}
  local index = 1
  while true do
    local name, value = debug.getlocal(1, index)
    if not name then break end
    names[#names + 1] = name .. "=" .. tostring(value)
    index = index + 1
  end
  return names
end

local found = inspect(2, 3)
print(found[1])
print(found[2])
print(found[3])
print(#found >= 3)

local function setLocal()
  local target = 1
  debug.setlocal(1, 1, 2)
  return target
end
print(setLocal())
''',
    output: 'a=2\nb=3\nsum=5\ntrue\n2\n',
    exercises: [
      LuaExercise(
        prompt: '读取第 2 层的第一个局部变量。',
        hint: 'level 参数。',
        answer: 'print(debug.getlocal(2, 1))',
      ),
      LuaExercise(
        prompt: '为什么生产代码不该用 setlocal？',
        hint: '想想可读性。',
        answer: '因为它能在运行时偷偷改变量的值，让行为难以推理，也绕过了正常的赋值路径。',
      ),
    ],
    pitfalls: [
      '局部变量的顺序依赖编译器实现，可能包含额外的内部寄存器位。',
      'getlocal 到末尾返回 nil，要作为循环结束条件。',
    ],
  ),
  LuaTopic(
    id: 'lua-dbg-sethook',
    chapter: 'debug',
    title: 'debug.sethook 统计执行',
    summary: '用钩子函数统计指令数或调用次数，做轻量性能观察。',
    objective: '能用 "count" 或 "call" 钩子统计执行量，并说明开销。',
    level: 'advanced',
    concepts: ['sethook', 'count', '开销'],
    explain:
        'debug.sethook(fn, mask, count) 在每执行 count 条指令后调用 fn。'
        'mask 里 "c" 表示调用、 "r" 表示返回、 "l" 表示按行。'
        '钩子会显著拖慢执行，只适合诊断，不要常开。',
    code: r'''local ticks = 0
debug.sethook(function() ticks = ticks + 1 end, "", 1000)

local total = 0
for i = 1, 50000 do total = total + i end

debug.sethook()
print(ticks > 0)
print(total)

local calls = 0
debug.sethook(function() calls = calls + 1 end, "c")
local function work() return 1 end
work()
work()
work()
debug.sethook()
print(calls >= 3)
print(type(debug.gethook))
''',
    output: 'true\n1250025000\ntrue\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '统计一段循环执行了多少个千指令周期。',
        hint: 'mask 传空串并设置 count。',
        answer: 'debug.sethook(function() n = n + 1 end, "", 1000)',
      ),
      LuaExercise(
        prompt: '为什么钩子不适合常开？',
        hint: '想想每次调用的成本。',
        answer: '因为每次触发都要调用函数，开销远大于正常执行，会让程序慢一个数量级。',
      ),
    ],
    pitfalls: ['忘记调用无参 sethook 关闭钩子会一直影响性能。', '钩子里不要再设钩子，容易嵌套混乱。'],
  ),
  LuaTopic(
    id: 'lua-dbg-registry',
    chapter: 'debug',
    title: 'debug.getregistry 与内建引用',
    summary: '注册表是 C 侧共享的表，脚本里通常只做只读检查。',
    objective: '能说明注册表的用途，并避免把业务数据放进去。',
    level: 'advanced',
    concepts: ['注册表', 'C 交互', '只读'],
    explain:
        'debug.getregistry() 返回 Lua 的注册表，'
        '它由 C 代码使用，存放全局状态和引用。'
        '脚本里读取它可以做诊断，'
        '写入会破坏宿主程序的假设，通常禁止。',
    code: r'''local registry = debug.getregistry()
print(type(registry))

print(debug.getregistry() == registry)
print(registry["_LOADED"] == nil or type(registry["_LOADED"]) == "table")
print(type(debug.getupvalue(print, 1)))

local function withUpvalue()
  local hidden = 42
  return function() return hidden end
end

local closure = withUpvalue()
local name, value = debug.getupvalue(closure, 1)
print(name, value)
print(debug.setupvalue(closure, 1, 7))
print(closure())
''',
    output: 'table\ntrue\ntrue\nstring\nhidden\t42\nhidden\n7\n',
    exercises: [
      LuaExercise(
        prompt: '读取一个闭包的上值。',
        hint: 'debug.getupvalue。',
        answer: 'print(debug.getupvalue(closure, 1))',
      ),
      LuaExercise(
        prompt: '为什么注册表不该放业务数据？',
        hint: '想想谁在用它。',
        answer: '因为 C 侧和标准库依赖注册表里的固定键，写入可能覆盖内部状态导致崩溃或异常行为。',
      ),
    ],
    pitfalls: ['注册表内容与 Lua 版本和宿主实现相关。', '修改上值会让闭包行为不可预期。'],
  ),
  LuaTopic(
    id: 'lua-dbg-assert-debug',
    chapter: 'debug',
    title: '用 debug 增强断言信息',
    summary: '断言失败时自动附带调用位置和函数名。',
    objective: '能写出带上下文的断言函数，缩短排错时间。',
    level: 'intermediate',
    concepts: ['断言', '上下文', 'getinfo'],
    explain:
        '标准 assert 只给消息，没有上下文。'
        '自定义断言可以借助 debug.getinfo 取到当前函数名和行号，'
        '让日志直接指出出错位置，不用再翻代码。',
    code: r'''local function where(level)
  local info = debug.getinfo(level or 2, "Sl")
  if not info then return "?" end
  return string.format("%s:%d", info.short_src, info.currentline)
end

local function check(condition, message)
  if not condition then
    error(string.format("%s 失败（%s）", message, where(3)), 0)
  end
  return condition
end

local function validate(value)
  check(type(value) == "number", "value 必须是数字")
  return value * 2
end

print(validate(3))

local ok, err = pcall(validate, "x")
print(ok)
print(err:find("value 必须是数字") ~= nil)
print(err:find("main%.lua:%d+") ~= nil)
print(type(where(1)))
''',
    output: '6\nfalse\ntrue\ntrue\nstring\n',
    exercises: [
      LuaExercise(
        prompt: '让断言消息带上函数名。',
        hint: 'getinfo 的 name 字段。',
        answer: 'local info = debug.getinfo(2, "nSl"); return info.name',
      ),
      LuaExercise(
        prompt: '为什么 error 的 level 用 0？',
        hint: '想想位置前缀。',
        answer: '因为消息里已经自带位置，用 0 不再叠加前缀，避免出现两段路径。',
      ),
    ],
    pitfalls: ['where 的层级要按调用深度调，写错会指到错误的行。', 'debug 库在受限环境里可能被移除，核心逻辑不要依赖它。'],
  ),
  LuaTopic(
    id: 'lua-dbg-profile',
    chapter: 'debug',
    title: '用钩子做简易采样',
    summary: '按行钩子记录热点行，得到粗略的性能画像。',
    objective: '能收集每行执行次数并排序，找出热点。',
    level: 'advanced',
    concepts: ['行钩子', '采样', '热点'],
    explain:
        'debug.sethook 的 "l" 模式在每进入新行时触发，'
        '用 currentline 计数就能得到每行的执行次数。'
        '这是最简陋的 profiler，'
        '足以看出某个循环是否被执行了几十万次。',
    code: r'''local hits = {}
local function hook()
  local line = debug.getinfo(2, "l").currentline
  hits[line] = (hits[line] or 0) + 1
end

debug.sethook(hook, "l")
local total = 0
for i = 1, 100 do
  total = total + i
end
debug.sethook()

local maxLine, maxHits = nil, 0
for line, count in pairs(hits) do
  if count > maxHits then maxLine, maxHits = line, count end
end

print(total)
print(type(maxLine))
print(maxHits > 100)
print(maxHits >= 100)
''',
    output: '5050\nnumber\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '统计执行次数最多的行号。',
        hint: '遍历 hits 取最大值。',
        answer:
            'for line, n in pairs(hits) do if n > best then bestLine, best = line, n end end',
      ),
      LuaExercise(
        prompt: '为什么行钩子的开销很大？',
        hint: '想想触发频率。',
        answer: '因为每进入一行都要调用一次钩子函数，执行行数越多开销越大。',
      ),
    ],
    pitfalls: ['行钩子统计的是触发次数，不等于真实耗时。', '一定要记得关闭钩子。'],
  ),
  LuaTopic(
    id: 'lua-dbg-traceback-limits',
    chapter: 'debug',
    title: '日志里怎么记录错误',
    summary: '把消息、栈和上下文写进一行日志，便于检索。',
    objective: '能设计可检索的错误日志格式，并避免多行日志。',
    level: 'intermediate',
    concepts: ['日志', '单行', '检索'],
    explain:
        '日志系统通常按行切分，多行栈会被拆散。'
        '常见做法是把换行替换成 \\n 转义或 " | "，'
        '拼成一行带级别、时间、消息和栈的文本。'
        '这样 grep 一次就能拿到完整上下文。',
    code: r'''local function oneLine(text)
  return (text:gsub("\r?\n", " | "))
end

local function logError(scope, err)
  return string.format("[ERROR] %s: %s", scope, oneLine(tostring(err)))
end

local ok, err = xpcall(function() error("数据库连接失败") end, function(e)
  return debug.traceback(e, 2)
end)

local line = logError("db.connect", err)
print(ok)
print(line:find("^%[ERROR%] db%.connect: ") ~= nil)
print(line:find("数据库连接失败") ~= nil)
print(line:find(" | ") ~= nil)
print(line:find("\n") == nil)
print(#line > 20)
''',
    output: 'false\ntrue\ntrue\ntrue\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '把多行栈压成一行。',
        hint: 'gsub 换行。',
        answer: 'local s = (stack:gsub("\\n", " | "))',
      ),
      LuaExercise(
        prompt: '为什么日志要单行？',
        hint: '想想按行采集的工具。',
        answer: '因为多数日志采集按行切分，多行会被拆成多条记录，丢失上下文关联。',
      ),
    ],
    pitfalls: ['gsub 返回两个值，拼进字符串前要加括号。', '栈里可能有敏感路径，外发日志前要脱敏。'],
  ),
  LuaTopic(
    id: 'lua-dbg-sandbox',
    chapter: 'debug',
    title: '受限环境要隐藏 debug',
    summary: 'debug 能让沙箱失效，必须从白名单里剔除。',
    objective: '能说明 debug 为何危险，并在沙箱里彻底移除。',
    level: 'advanced',
    concepts: ['沙箱', 'debug 风险', '白名单'],
    explain:
        'debug 库能读取上值、修改环境、取得注册表，'
        '等于绕过所有封装。'
        '任何执行不可信代码的场景，白名单里都不能包含 debug，'
        '也要检查间接引用（如 getmetatable 暴露的元方法）。',
    code: r'''local function makeSandbox()
  return {
    print = print,
    string = string,
    table = table,
    math = math,
  }
end

local sandbox = makeSandbox()
print(sandbox.debug == nil)
print(sandbox.getfenv == nil)

local dangerous = load("return debug.getregistry()", "d", "t", sandbox)
print(pcall(dangerous) == false)

local alsoDangerous = load("return _G", "g", "t", sandbox)
print(alsoDangerous() == nil)

sandbox.debug = debug
local leaked = load("return debug.getregistry() ~= nil", "l", "t", sandbox)
print(leaked())
''',
    output: 'true\ntrue\ntrue\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '从白名单里去掉 debug 后执行 debug 代码会怎样？',
        hint: '想想索引 nil。',
        answer: '会报 attempt to index a nil value (global \'debug\')。',
      ),
      LuaExercise(
        prompt: '为什么沙箱里连 _G 也不能暴露？',
        hint: '想想 _G 里有什么。',
        answer: '因为 _G 是全局表，暴露它能间接拿到 os、io、debug 等所有库。',
      ),
    ],
    pitfalls: ['只删 debug 不够，还要检查 package、io、os 等危险库。', '通过元表间接引用仍可能绕过白名单。'],
  ),
];
