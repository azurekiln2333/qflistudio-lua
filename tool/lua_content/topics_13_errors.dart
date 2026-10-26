import 'lua_topic.dart';

/// 第十三章：错误处理与断言。
const List<LuaTopic> topicsErrors = [
  LuaTopic(
    id: 'lua-err-error',
    chapter: 'errors',
    title: 'error 抛出错误',
    summary: 'error 会中断当前调用并把消息传给上层。',
    objective: '能用 error 表达真正的失败，并写出可读的错误消息。',
    level: 'beginner',
    concepts: ['error', '异常', '消息'],
    explain:
        'error(message) 立刻终止当前函数，把消息作为错误向上传播，'
        '直到遇到 pcall/xpcall 或进程结束。'
        '错误消息要写清楚「发生了什么 + 期望什么」，不要只写 "failed"。'
        '第二参数可以控制错误位置前缀。',
    code: r'''-- 运行时会在消息前面加上来源文件名和行号，展示前先去掉
local function strip(err)
  return (tostring(err):gsub("^.-:%d+: ", ""))
end

local function checkPositive(value)
  if type(value) ~= "number" then
    error("checkPositive 需要数字，收到 " .. type(value))
  end
  if value <= 0 then
    error("checkPositive 需要正数，收到 " .. value)
  end
  return value
end

print(checkPositive(3))

local ok1, err1 = pcall(checkPositive, -1)
print(ok1, strip(err1))

local ok2, err2 = pcall(checkPositive, "abc")
print(ok2, strip(err2))

local ok3, err3 = pcall(function() error({ code = 42 }) end)
print(ok3, type(err3), err3.code)
''',
    output:
        '3\nfalse\tcheckPositive 需要正数，收到 -1\nfalse\t'
        'checkPositive 需要数字，收到 string\nfalse\ttable\t42\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数，参数不是表就抛错。',
        hint: '用 type 加 error。',
        answer: 'if type(t) ~= "table" then error("需要表，收到 " .. type(t)) end',
      ),
      LuaExercise(
        prompt: '为什么错误消息里要带实际收到的值？',
        hint: '想想排查现场。',
        answer: '因为调用方看消息就能定位问题，不必再复现一遍。',
      ),
    ],
    pitfalls: ['error 会中断执行，不要在「可恢复」的路径上滥用。', '错误消息会自动带上文件名和行号，做稳定输出时要先到掉前缀。'],
  ),
  LuaTopic(
    id: 'lua-err-pcall',
    chapter: 'errors',
    title: 'pcall 捕获错误',
    summary: 'pcall 返回 (是否成功, 结果或错误)，不会中断程序。',
    objective: '能用 pcall 把可能失败的操作变成可处理的返回值。',
    level: 'beginner',
    concepts: ['pcall', '保护调用', '返回值'],
    explain:
        'pcall(f, ...) 以保护模式调用 f：成功返回 true 加 f 的所有返回值，'
        '失败返回 false 加错误对象。'
        '这是 Lua 里最常见的错误处理方式，'
        '适合「失败是预期内的一种结果」的场景，例如解析用户输入。',
    code: r'''local function strip(err)
  return (tostring(err):gsub("^.-:%d+: ", ""))
end

local function parseNumber(text)
  local value = tonumber(text)
  if not value then error("不是合法数字：" .. text) end
  return value
end

print(pcall(parseNumber, "42"))

local ok, err = pcall(parseNumber, "abc")
print(ok, strip(err))

local ok2, result = pcall(parseNumber, "3.5")
print(ok2, result)

local ok3, err3 = pcall(function() return nil + 1 end)
print(ok3, type(err3))

print(pcall(function() return 1, 2, 3 end))
''',
    output:
        'true\t42\nfalse\t不是合法数字：abc\ntrue\t3.5\nfalse\tstring\n'
        'true\t1\t2\t3\n',
    exercises: [
      LuaExercise(
        prompt: '用 pcall 安全调用可能不存在的函数。',
        hint: 'pcall 本身不会因为 f 是 nil 而崩溃。',
        answer: 'local ok, err = pcall(possiblyNil)  -- ok 为 false',
      ),
      LuaExercise(
        prompt: '为什么 pcall 的第一个返回值必须检查？',
        hint: '失败时第二个值是错误信息。',
        answer: '不检查会把错误对象当结果用，导致后续更隐蔽的失败。',
      ),
    ],
    pitfalls: [
      'pcall 会吞掉调用栈，排查时配合 xpcall + traceback 更好。',
      'pcall 保护的是调用，不是之后使用结果的代码。',
    ],
  ),
  LuaTopic(
    id: 'lua-err-xpcall',
    chapter: 'errors',
    title: 'xpcall 与 traceback',
    summary: 'xpcall 在错误发生时先调用处理函数，可附加调用栈。',
    objective: '能用 xpcall + debug.traceback 输出带栈的错误报告。',
    level: 'intermediate',
    concepts: ['xpcall', 'traceback', '调用栈'],
    explain:
        'xpcall(f, handler, ...) 出错时先调用 handler(错误对象)，'
        '把它的返回值作为错误结果。'
        'handler 里调用 debug.traceback 就能拿到调用栈，'
        '这是定位「错误到底从哪一层抛出来」的关键手段。',
    code: r'''local function inner()
  error("底层失败")
end

local function middle()
  inner()
end

local ok, report = xpcall(middle, function(err)
  return "捕获：" .. tostring(err) .. "\n" .. debug.traceback("", 2)
end)

print(ok)
print(report:find("^捕获：") ~= nil)
print(report:find("底层失败") ~= nil)
print(report:find("stack traceback") ~= nil)

local ok2, value = xpcall(function() return 7 end, function() end)
print(ok2, value)
''',
    output: 'false\ntrue\ntrue\ntrue\ntrue\t7\n',
    exercises: [
      LuaExercise(
        prompt: '在 handler 里只保留错误消息的第一行。',
        hint: '用 match("^[^\n]*")。',
        answer: 'return (tostring(err):match("^[^\\n]*"))',
      ),
      LuaExercise(
        prompt: 'xpcall 成功时 handler 会被调用吗？',
        hint: '只有出错才调用。',
        answer: '不会，成功时直接返回 true 和函数的返回值。',
      ),
    ],
    pitfalls: ['handler 自己再抛错会导致错误信息丢失。', 'debug.traceback 的层级参数决定从哪一层开始显示。'],
  ),
  LuaTopic(
    id: 'lua-err-assert',
    chapter: 'errors',
    title: 'assert 断言',
    summary: 'assert(条件, 消息) 在条件为假时抛错，成功时原样返回参数。',
    objective: '能用 assert 做前置条件检查，并利用它的透传特性。',
    level: 'beginner',
    concepts: ['assert', '前置条件', '透传'],
    explain:
        'assert 在条件为真时返回所有参数，为假时用第二个参数作为错误消息抛出。'
        '它的返回值透传特性让「校验 + 取值」能写成一行：'
        'local n = assert(tonumber(s), "不是数字")。'
        '注意 0 和空字符串都是真，不会被 assert 拦下。',
    code: r'''local function strip(err)
  return (tostring(err):gsub("^.-:%d+: ", ""))
end

local function needNumber(value)
  -- assert 会把所有参数原样返回，所以只取第一个
  local number = assert(tonumber(value), "需要数字，收到 " .. tostring(value))
  return number
end

print(needNumber("42"))

local ok, err = pcall(needNumber, "abc")
print(ok, strip(err))

local function needPositive(n)
  assert(type(n) == "number", "必须是数字")
  assert(n > 0, "必须为正数")
  return n
end
print(needPositive(5))

local ok2, err2 = pcall(needPositive, 0)
print(ok2, strip(err2))

print(assert(true, "不会用到", "额外返回值"))
''',
    output:
        '42\nfalse\t需要数字，收到 abc\n5\nfalse\t必须为正数\n'
        'true\t不会用到\t额外返回值\n',
    exercises: [
      LuaExercise(
        prompt: '用 assert 校验表必须有 name 字段。',
        hint: 'assert(t.name, "缺少 name")。',
        answer: 'assert(t.name ~= nil, "缺少 name 字段")',
      ),
      LuaExercise(
        prompt: 'assert(0) 会失败吗？',
        hint: '0 是真。',
        answer: '不会，0 在 Lua 里为真，assert 直接通过。',
      ),
    ],
    pitfalls: ['assert 会把条件表达式的结果当作第一个返回值，别误用。', 'assert 的消息在条件为真时根本不会求值。'],
  ),
  LuaTopic(
    id: 'lua-err-error-table',
    chapter: 'errors',
    title: '用表作为错误对象',
    summary: 'error 可以抛任意值，用表能携带错误码和上下文。',
    objective: '能定义结构化错误并在 pcall 之后按 code 分支处理。',
    level: 'intermediate',
    concepts: ['错误对象', '错误码', '结构化'],
    explain:
        '错误不一定只是字符串。'
        '抛一张表 { code = "E_INVALID", field = "age" } 就能让上层按 code 分类处理，'
        '而不用解析字符串。'
        '缺点是 print 出来的表会显示地址，展示前要自己格式化。',
    code: r'''local Errors = {
  invalid = function(field)
    return { code = "E_INVALID", field = field, message = "字段无效：" .. field }
  end,
  missing = function(field)
    return { code = "E_MISSING", field = field, message = "缺少字段：" .. field }
  end,
}

local function validate(user)
  if user.name == nil then error(Errors.missing("name")) end
  if #user.name < 2 then error(Errors.invalid("name")) end
  return true
end

local ok, err = pcall(validate, { name = "x" })
print(ok, type(err))
print(err.code, err.field)
print(err.message)

local ok2, err2 = pcall(validate, {})
print(ok2, err2.code)

local ok3 = pcall(validate, { name = "小明" })
print(ok3)
''',
    output:
        'false\ttable\nE_INVALID\tname\n字段无效：name\nfalse\tE_MISSING\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '增加一个 E_RANGE 错误并用于年龄校验。',
        hint: '照 Errors.invalid 的写法加一个构造函数。',
        answer:
            'range = function(field, min, max) return { code = "E_RANGE", field = field, message = "越界" } end',
      ),
      LuaExercise(
        prompt: '为什么错误表里要同时放 code 和 message？',
        hint: '一个给程序看，一个给人看。',
        answer: 'code 用于程序分支，message 用于展示，职责分开更稳定。',
      ),
    ],
    pitfalls: ['直接 print 错误表只会看到 table 地址，要取字段。', '错误码要用常量，避免各处拼字符串。'],
  ),
  LuaTopic(
    id: 'lua-err-error-level',
    chapter: 'errors',
    title: 'error 的位置层级',
    summary: 'error 的第二个参数决定错误信息里报告哪一层的调用位置。',
    objective: '能控制报错位置指向调用方而不是工具函数内部。',
    level: 'advanced',
    concepts: ['error level', '报错位置', '封装'],
    explain:
        'error(msg, 1)（默认）把位置指向 error 所在行，'
        'level 2 指向调用当前函数的代码，level 0 不附加位置信息。'
        '写校验工具函数时通常用 level 2，'
        '这样用户看到的是自己调用出错的那一行。',
    code: r'''local function levelOne()
  error("level 1", 1)
end

local function levelTwo()
  error("level 2", 2)
end

local function levelZero()
  error("level 0", 0)
end

local function callerOfLevelOne() levelOne() end
local function callerOfLevelTwo() levelTwo() end
local function callerOfLevelZero() levelZero() end

local _, e1 = pcall(callerOfLevelOne)
local _, e2 = pcall(callerOfLevelTwo)
local _, e0 = pcall(callerOfLevelZero)

print(e1:find("main%.lua:%d+: level 1") ~= nil)
print(e2:find("main%.lua:%d+: level 2") ~= nil)
print(e0 == "level 0")
''',
    output: 'true\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '写一个校验函数让报错指向调用方。',
        hint: '用 error(msg, 2)。',
        answer:
            'local function check(v) if not v then error("无效参数", 2) end end',
      ),
      LuaExercise(
        prompt: 'level 0 适合什么场景？',
        hint: '不想暴露内部文件行号时。',
        answer: '适合库对外抛错时不泄露内部路径，或者只想给纯消息。',
      ),
    ],
    pitfalls: ['行号是运行时信息，不要把它写进自动化断言的期望文本。', 'level 过大时位置信息会丢失，效果类似 level 0。'],
  ),
  LuaTopic(
    id: 'lua-err-retry',
    chapter: 'errors',
    title: '重试模式',
    summary: '把「尝试 + 捕获 + 重试」写成通用函数，并限制次数。',
    objective: '能实现带最大次数和退避的重试，且不掩盖最终失败。',
    level: 'advanced',
    concepts: ['重试', '最大次数', '失败传播'],
    explain:
        '重试必须有三件事：最大尝试次数、每次失败的记录、以及最终失败的传播。'
        '缺少最后一条会让程序在持续失败时静默返回 nil。'
        '在离线 IDE 里没有真实网络，但文件读写、解析这类操作同样值得重试。',
    code: r'''local function retry(times, action)
  local lastError
  for attempt = 1, times do
    local ok, result = pcall(action, attempt)
    if ok then return result, attempt end
    lastError = result
  end
  return nil, lastError
end

local attemptsSeen = {}
local value, attempts = retry(3, function(attempt)
  attemptsSeen[#attemptsSeen + 1] = attempt
  if attempt < 3 then error("第 " .. attempt .. " 次失败") end
  return "成功"
end)
print(value, attempts)
print(table.concat(attemptsSeen, ","))

local failedValue, err = retry(2, function() error("总是失败") end)
print(failedValue, (tostring(err):gsub("^.-:%d+: ", "")))

print(retry(1, function() return 42 end))
''',
    output: '成功\t3\n1,2,3\nnil\t总是失败\n42\t1\n',
    exercises: [
      LuaExercise(
        prompt: '让 retry 在最后一次失败时返回「重试 3 次后失败：原因」。',
        hint: '在循环外拼消息。',
        answer:
            'return nil, string.format("重试 %d 次后失败：%s", times, tostring(lastError))',
      ),
      LuaExercise(
        prompt: '重试次数为 0 会怎样？',
        hint: '循环一次都不执行。',
        answer: '直接返回 nil 和 nil，调用方必须处理这种没有错误信息的失败。',
      ),
    ],
    pitfalls: ['无限重试会掩盖真正的错误。', '重试无副作用的操作才安全，写文件要考虑幂等性。'],
  ),
  LuaTopic(
    id: 'lua-err-result-pair',
    chapter: 'errors',
    title: '结果 + 错误 双值返回',
    summary: '用 (value, err) 代替抛错，让调用方显式处理失败。',
    objective: '能写出不抛错的失败路径，并正确区分 nil 结果和错误。',
    level: 'intermediate',
    concepts: ['返回约定', '失败路径', '显式处理'],
    explain:
        '很多 Lua 标准函数用「失败返回 nil + 错误消息」的约定，例如 io.open。'
        '这种风格不中断控制流，适合批量处理。'
        '关键是要在使用结果前检查：'
        'local f, err = io.open(...) 中 f 为 nil 时必须走失败分支。',
    code: r'''local function readValue(source, key)
  if type(source) ~= "table" then
    return nil, "source 不是表"
  end
  local value = source[key]
  if value == nil then
    return nil, "缺少键 " .. tostring(key)
  end
  return value, nil
end

local data = { a = 1 }

local value, err = readValue(data, "a")
print(value, err)

local missing, missingErr = readValue(data, "b")
print(missing, missingErr)

local wrongType, wrongErr = readValue("text", "a")
print(wrongType, wrongErr)

local function useDefault(source, key, fallback)
  local value = readValue(source, key)
  if value == nil then return fallback end
  return value
end
print(useDefault(data, "b", 0))
''',
    output: '1\tnil\nnil\t缺少键 b\nnil\tsource 不是表\n0\n',
    exercises: [
      LuaExercise(
        prompt: '让 readValue 支持点号路径 "user.name"。',
        hint: '用 gmatch 拆分再逐层取值。',
        answer: '用 key:gmatch("[^.]+") 逐层访问，任一层缺失就返回 nil 和错误。',
      ),
      LuaExercise(
        prompt: '为什么 readValue 返回的 err 在成功时是 nil？',
        hint: '统一返回结构。',
        answer: '保持返回值个数一致，调用方可以固定写 local v, err = ...。',
      ),
    ],
    pitfalls: [
      '只判断 value 而不看 err 会把「值本来就是 nil」和「出错了」混为一谈。',
      '双值约定要靠文档或命名统一，否则调用方容易漏判。',
    ],
  ),
  LuaTopic(
    id: 'lua-err-cleanup',
    chapter: 'errors',
    title: '出错后清理资源',
    summary: '用 pcall + 显式清理，或 5.4 的 <close> 保证资源释放。',
    objective: '能在异常路径上仍然关闭文件、释放状态。',
    level: 'advanced',
    concepts: ['资源清理', 'pcall', 'close'],
    explain:
        'Lua 没有 try/finally，出错时 pcall 之后的清理代码不会自动执行。'
        '两种做法：把「操作」和「清理」都放进 pcall 前后手动配对，'
        '或者用 5.4 的 local f <close> 让作用域结束时自动关闭。'
        '下面演示手动配对的写法，并用计数器证明清理确实发生了。',
    code: r'''local openCount, closeCount = 0, 0

local function withResource(action)
  openCount = openCount + 1
  local resource = { open = true }
  local ok, result = pcall(action, resource)
  resource.open = false
  closeCount = closeCount + 1
  return ok, result
end

local ok, result = withResource(function(res)
  return "使用了资源"
end)
print(ok, result, openCount, closeCount)

local ok2, err = withResource(function()
  error("操作失败")
end)
print(ok2, (tostring(err):gsub("^.-:%d+: ", "")), closeCount)

print(openCount == closeCount)
''',
    output: 'true\t使用了资源\t1\t1\nfalse\t操作失败\t2\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '在清理代码里记录关闭时间戳之类的信息。',
        hint: '在 closeCount 累加处同时记录。',
        answer: '在 closeCount = closeCount + 1 旁边记录 os.time() 或 os.clock()。',
      ),
      LuaExercise(
        prompt: '如果 action 内部又抛错，closeCount 还会增加吗？',
        hint: '看 pcall 之后的代码。',
        answer: '会，因为 pcall 捕获了错误，后续清理代码照常执行。',
      ),
    ],
    pitfalls: ['清理代码本身抛错会覆盖原始错误。', '忘记在失败路径上清理会造成句柄泄漏。'],
  ),
  LuaTopic(
    id: 'lua-err-type-message',
    chapter: 'errors',
    title: '参数类型校验与可读报错',
    summary: '统一在函数入口校验类型，并给出「期望 vs 实际」的消息。',
    objective: '能写出统一的参数校验辅助函数，复用到多个接口。',
    level: 'intermediate',
    concepts: ['类型校验', '错误消息', '复用'],
    explain:
        '参数校验的价值在于「早失败、说清楚」。'
        '把校验抽成 checkArg(value, expected, name) 之后，'
        '每个函数只需一行，报错格式也统一，'
        '用户看到的是「参数 age 期望 number，实际 string」这样的信息。',
    code: r'''local function strip(err)
  return (tostring(err):gsub("^.-:%d+: ", ""))
end

local function checkArg(value, expected, name)
  if type(value) ~= expected then
    error(string.format("参数 %s 期望 %s，实际 %s", name, expected, type(value)), 2)
  end
  return value
end

local function createUser(name, age)
  checkArg(name, "string", "name")
  checkArg(age, "number", "age")
  if age < 0 then error("参数 age 不能为负", 2) end
  return { name = name, age = age }
end

local user = createUser("小明", 18)
print(user.name, user.age)

local ok1, err1 = pcall(createUser, 42, 18)
print(ok1, strip(err1))

local ok2, err2 = pcall(createUser, "小明", "18")
print(ok2, strip(err2))

local ok3, err3 = pcall(createUser, "小明", -1)
print(ok3, strip(err3))

print(err1:find("main%.lua:%d+: 参数 name") ~= nil)
''',
    output:
        '小明\t18\nfalse\t参数 name 期望 string，实际 number\nfalse\t'
        '参数 age 期望 number，实际 string\nfalse\t参数 age 不能为负\n'
        'true\n',
    exercises: [
      LuaExercise(
        prompt: '增加「非空字符串」的校验。',
        hint: '在 checkArg 之后判断长度。',
        answer: 'if name == "" then error("参数 name 不能为空", 2) end',
      ),
      LuaExercise(
        prompt: '为什么校验函数里用 level 2？',
        hint: '想想报错应该指向谁。',
        answer: '让错误位置指向调用 createUser 的那一行，而不是校验函数内部。',
      ),
    ],
    pitfalls: ['只校验类型不校验取值范围，仍然会放过非法数据。', '校验函数的报错位置要用 level 2 才有意义。'],
  ),
];
