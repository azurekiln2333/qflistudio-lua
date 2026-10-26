import 'lua_topic.dart';

/// 第九章：条件与分支。
const List<LuaTopic> topicsFlow = [
  LuaTopic(
    id: 'lua-flow-if',
    chapter: 'flow',
    title: 'if / elseif / else',
    summary: '按顺序判断条件，第一个成立的分支执行，其余跳过。',
    objective: '能写出多分支判断，并知道条件是从上到下依次求值的。',
    level: 'beginner',
    concepts: ['if', 'elseif', '分支'],
    explain:
        'if 后面的条件为真就执行对应块，否则继续看 elseif，'
        '都不成立时执行 else。'
        '分支是互斥且有序的：条件一旦成立，后面的条件根本不会被求值。'
        '所以把范围窄、优先级高的判断写在前面。',
    code: r'''local function grade(score)
  if score >= 90 then
    return "优秀"
  elseif score >= 75 then
    return "良好"
  elseif score >= 60 then
    return "及格"
  else
    return "不及格"
  end
end

print(grade(95), grade(80), grade(60), grade(30))
print(grade(90))

local value = 5
if value > 10 then
  print("大于 10")
elseif value > 3 then
  print("大于 3")
else
  print("其他")
end
''',
    output: '优秀\t良好\t及格\t不及格\n优秀\n大于 3\n',
    exercises: [
      LuaExercise(
        prompt: '给 grade 增加 100 分特别优秀的判断。',
        hint: '把最特殊的条件放最前面。',
        answer: 'if score >= 100 then return "满分" elseif score >= 90 then ...',
      ),
      LuaExercise(
        prompt: '为什么 score >= 60 不会在 95 分时被执行？',
        hint: '分支互斥。',
        answer: '第一个条件成立后整条 if 语句就结束了，后续条件不再求值。',
      ),
    ],
    pitfalls: ['把范围宽的条件写在前面会让后面的分支永远不执行。', 'elseif 不是 else if，漏写 end 会报语法错误。'],
  ),
  LuaTopic(
    id: 'lua-flow-truthiness',
    chapter: 'flow',
    title: '真值判断：只有 nil 和 false 为假',
    summary: '0、空字符串、空表在条件里都是真，这是 Lua 与 C 的关键差异。',
    objective: '能避免把 0 或空字符串当成假，写出正确的非空判断。',
    level: 'beginner',
    concepts: ['真值', 'nil', 'false'],
    explain:
        'Lua 的条件判断只看值是不是 nil 或 false，其他一律为真。'
        '0 是真，"" 是真，{} 也是真。'
        '所以「是否非空」要显式比较：字符串用 s ~= ""，表用 next(t) ~= nil 或 #t > 0。',
    code: r'''local function truthy(value)
  if value then return "真" else return "假" end
end

print(truthy(nil), truthy(false))
print(truthy(0), truthy(""))
print(truthy({}))

local text = ""
if text then print("空字符串也进这里") end
if text ~= "" then print("非空") else print("确实是空字符串") end

local emptyTable = {}
print(next(emptyTable) == nil)
''',
    output:
        '假\t假\n真\t真\n真\n空字符串也进这里\n确实是空字符串\n'
        'true\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数判断表是否为空。',
        hint: '用 next(t) == nil。',
        answer: 'local function isEmpty(t) return next(t) == nil end',
      ),
      LuaExercise(
        prompt: '为什么 if #t then 不是可靠的非空判断？',
        hint: '0 也是真。',
        answer: '因为 #t 为 0 时条件仍然为真，必须写 #t > 0。',
      ),
    ],
    pitfalls: ['把 C 的写法 if (x) 直接搬过来会得到错误结果。', '空表在条件里是真，判断空表要用 next。'],
  ),
  LuaTopic(
    id: 'lua-flow-and-or',
    chapter: 'flow',
    title: 'and / or 短路求值',
    summary: 'and 返回第一个假值，or 返回第一个真值，并且会短路。',
    objective: '能用短路特性给默认值、做条件调用，并知道返回值不是布尔。',
    level: 'beginner',
    concepts: ['and', 'or', '短路'],
    explain:
        'a and b 先看 a：a 为假就返回 a，否则返回 b。'
        'a or b 先看 a：a 为真就返回 a，否则返回 b。'
        '两者返回的是操作数本身，不一定是布尔值，'
        '所以可以用 x = y or "default" 给默认值。',
    code: r'''print(nil and 1, nil or 1)
print(false and "x", false or "x")
print(0 or "fallback")
print("" and "非空")

local config = { retries = 0 }
print(config.timeout or 30)
print(config.retries or 30)

local function sideEffect(name)
  print("调用 " .. name)
  return name
end

local result = false and sideEffect("不会执行")
print(result)
local result2 = true or sideEffect("也不会执行")
print(result2)
''',
    output: 'nil\t1\nfalse\tx\n0\n非空\n30\n0\nfalse\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '用 or 给函数参数提供默认值。',
        hint: '注意 false 也会触发默认值。',
        answer: 'local function greet(name) name = name or "世界" ... end',
      ),
      LuaExercise(
        prompt: '为什么 config.retries or 30 返回 0 而不是 30？',
        hint: '0 是真。',
        answer: '0 在 Lua 里为真，所以 or 直接返回 0，默认值不会生效。',
      ),
    ],
    pitfalls: ['or 的默认值写法无法区分 false 和 nil。', 'and/or 返回操作数，不是布尔值，别当作严格布尔用。'],
  ),
  LuaTopic(
    id: 'lua-flow-ternary',
    chapter: 'flow',
    title: '三元表达式惯用法',
    summary: '用 cond and a or b 模拟三元运算，但要注意 a 为假的情况。',
    objective: '能用 and/or 写条件取值，并知道它的边界。',
    level: 'intermediate',
    concepts: ['三元', 'and or', '边界'],
    explain:
        'Lua 没有 ?: 运算符，常见替代是 cond and a or b。'
        '它的原理是：cond 为真时求值 a，若 a 为假则继续走 or 返回 b。'
        '因此当 a 本身可能是 nil 或 false 时，结果会错误地落到 b，'
        '这种情况必须改用显式 if。',
    code: r'''local function label(flag)
  return flag and "开启" or "关闭"
end

print(label(true), label(false))

local value = nil
local safe = value ~= nil and value or "默认"
print(safe)

local function risky(flag)
  return flag and nil or "兜底"
end
print(risky(true))

local function correct(flag)
  if flag then return nil end
  return "兜底"
end
print(correct(true))
''',
    output: '开启\t关闭\n默认\n兜底\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '用 and/or 写出「成绩及格返回通过，否则返回补考」。',
        hint: '条件写 score >= 60。',
        answer: 'return score >= 60 and "通过" or "补考"',
      ),
      LuaExercise(
        prompt: '为什么 risky(true) 没有返回 nil？',
        hint: 'and 返回 nil 后 or 继续求值。',
        answer: '因为 true and nil 得到 nil（假），or 于是返回兜底值。',
      ),
    ],
    pitfalls: ['and/or 三元写法在「真值分支返回 nil/false」时是错误的。'],
  ),
  LuaTopic(
    id: 'lua-flow-not',
    chapter: 'flow',
    title: 'not 与双重否定',
    summary: 'not 把真值取反，双重 not 用来强制转成布尔。',
    objective: '能用 not 写取反条件，用 !! 风格转成严格布尔。',
    level: 'beginner',
    concepts: ['not', '布尔化', '取反'],
    explain:
        'not x 在 x 为 nil 或 false 时返回 true，否则返回 false。'
        '所以 not not x（常写成 !!x 的思路）能把任意值转成布尔值，'
        '这在需要严格布尔返回值的接口里很有用。',
    code: r'''print(not nil, not false, not 0, not "")
print(not not nil, not not 0, not not "x")

local function isReady(flag)
  return not not flag
end

print(isReady(0))
print(isReady(nil))
print(type(isReady(1)))
print(not (1 == 2))
''',
    output:
        'true\ttrue\tfalse\tfalse\nfalse\ttrue\ttrue\ntrue\nfalse\n'
        'boolean\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '把字符串变量转成「是否非空」的布尔值。',
        hint: '用 not not 加比较。',
        answer: 'local hasText = not not (text ~= nil and text ~= "")',
      ),
      LuaExercise(
        prompt: 'not not 0 为什么是 true？',
        hint: '0 是真。',
        answer: '因为 not 0 是 false，再取反就是 true。',
      ),
    ],
    pitfalls: ['not 的优先级高于比较，写 not a == b 会先取反。'],
  ),
  LuaTopic(
    id: 'lua-flow-guard',
    chapter: 'flow',
    title: '输入范围校验',
    summary: '把非法输入挡在业务逻辑之外，并返回可读的原因。',
    objective: '能写出校验函数，返回 (值, 错误) 而不是静默纠正。',
    level: 'intermediate',
    concepts: ['校验', '早返回', '错误信息'],
    explain:
        '校验函数的常见约定是成功返回 (值, nil)，失败返回 (nil, 原因)。'
        '调用方用 local value, err = check(x) 判断，'
        '既不抛异常也不静默修正，错误原因还能直接展示给用户。',
    code: r'''local function checkPort(value)
  local number = tonumber(value)
  if number == nil then return nil, "不是数字" end
  if number ~= math.floor(number) then return nil, "必须是整数" end
  if number < 1 or number > 65535 then return nil, "超出 1-65535" end
  return number, nil
end

local function report(value)
  local port, err = checkPort(value)
  if port then
    print("端口 " .. port)
  else
    print("无效：" .. err)
  end
end

report("8080")
report("80.5")
report("70000")
report("abc")
report(443)
''',
    output:
        '端口 8080\n无效：必须是整数\n无效：超出 1-65535\n'
        '无效：不是数字\n端口 443\n',
    exercises: [
      LuaExercise(
        prompt: '增加「不能是 0」的校验。',
        hint: '在范围判断里调整下界。',
        answer:
            'if number < 1 or number > 65535 then return nil, "超出 1-65535" end 已覆盖 0。',
      ),
      LuaExercise(
        prompt: '为什么校验函数不直接 error？',
        hint: '想想调用方是否需要处理多种输入。',
        answer: '因为校验失败是预期内的正常路径，返回值更容易批量处理，也不会中断整批数据。',
      ),
    ],
    pitfalls: [
      '校验通过后要返回规范化后的值（如 tonumber 结果），不要返回原字符串。',
      '错误信息要具体，避免只返回 false。',
    ],
  ),
  LuaTopic(
    id: 'lua-flow-dispatch',
    chapter: 'flow',
    title: '表驱动分发代替 if 链',
    summary: '把「命令→处理函数」放进表里，消除长 if/elseif 链。',
    objective: '能用分发表实现可扩展的命令处理，并处理未知命令。',
    level: 'intermediate',
    concepts: ['分发表', '函数表', '扩展性'],
    explain:
        '当分支只是「不同名字对应不同动作」时，用表存函数比 if 链更清晰。'
        '新增命令只需加一个键值对，不用改判断逻辑。'
        '查不到时统一走默认分支，错误处理只写一处。',
    code: r'''local handlers = {
  add = function(a, b) return a + b end,
  sub = function(a, b) return a - b end,
  mul = function(a, b) return a * b end,
}

local function dispatch(command, a, b)
  local handler = handlers[command]
  if not handler then
    return nil, "未知命令：" .. tostring(command)
  end
  return handler(a, b)
end

print(dispatch("add", 3, 4))
print(dispatch("mul", 3, 4))
print(dispatch("div", 3, 4))

handlers.mod = function(a, b) return a % b end
print(dispatch("mod", 7, 3))
print(type(handlers.add))
''',
    output: '7\n12\nnil\t未知命令：div\n1\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '加一个 pow 命令。',
        hint: '往 handlers 表里加函数。',
        answer: 'handlers.pow = function(a, b) return a ^ b end',
      ),
      LuaExercise(
        prompt: '表驱动分发比 if 链好在哪？',
        hint: '想想新增分支的改动范围。',
        answer: '新增命令只改数据不改控制流，也便于按配置动态注册。',
      ),
    ],
    pitfalls: ['命令名拼错会静默走到未知分支。', '函数表里的函数如果依赖 self，要注意调用方式。'],
  ),
  LuaTopic(
    id: 'lua-flow-early-return',
    chapter: 'flow',
    title: '早返回减少嵌套',
    summary: '先处理异常和边界，让主逻辑保持在同一层。',
    objective: '能用早返回把深层嵌套改写成线性结构。',
    level: 'intermediate',
    concepts: ['早返回', '嵌套', '可读性'],
    explain:
        '把「不满足条件就立刻返回」写在函数开头，主逻辑就不用包在多层 if 里。'
        '这样代码从左到右读，缩进层级稳定，'
        '也避免了「else 之后的代码」需要回溯条件才能理解。',
    code: r'''local function nested(age, name)
  if age then
    if name then
      if age >= 18 then
        return "成年：" .. name
      else
        return "未成年：" .. name
      end
    else
      return "缺少名字"
    end
  else
    return "缺少年龄"
  end
end

local function early(age, name)
  if not age then return "缺少年龄" end
  if not name then return "缺少名字" end
  if age >= 18 then return "成年：" .. name end
  return "未成年：" .. name
end

print(nested(20, "甲"))
print(early(20, "甲"))
print(nested(nil, "乙"), early(nil, "乙"))
print(early(10, "丙"))
''',
    output: '成年：甲\n成年：甲\n缺少年龄\t缺少年龄\n未成年：丙\n',
    exercises: [
      LuaExercise(
        prompt: '把 nested 改成早返回形式。',
        hint: '每个 if not 都直接 return。',
        answer:
            'if not age then return "缺少年龄" end\nif not name then return "缺少名字" end\nif age >= 18 then return "成年：" .. name end\nreturn "未成年：" .. name',
      ),
      LuaExercise(
        prompt: '早返回会不会让函数更难读？',
        hint: '对比缩进层级。',
        answer: '不会，主路径保持同一缩进层级，异常情况集中在开头，反而更好读。',
      ),
    ],
    pitfalls: ['早返回要保证所有路径都有返回值，否则调用方可能拿到 nil。'],
  ),
  LuaTopic(
    id: 'lua-flow-goto-continue',
    chapter: 'flow',
    title: '用 goto 模拟 continue',
    summary: 'Lua 没有 continue，用 goto 跳到循环末尾的标签实现。',
    objective: '能写出带 ::continue:: 标签的跳过逻辑，并知道作用域限制。',
    level: 'advanced',
    concepts: ['goto', '标签', 'continue'],
    explain:
        'Lua 5.2 起支持 goto 和标签 ::name::。'
        '在循环体末尾放 ::continue::，遇到不需要处理的数据就 goto continue，'
        '等价于其他语言的 continue。'
        'goto 不能跳进局部变量的作用域，也不能跨函数跳转。',
    code: r'''local values = { 1, -2, 3, -4, 5 }
local total = 0

for _, value in ipairs(values) do
  if value < 0 then goto continue end
  total = total + value
  ::continue::
end
print(total)

local count = 0
for i = 1, 10 do
  if i % 2 == 0 then goto skip end
  count = count + 1
  ::skip::
end
print(count)

print("goto 结束")
''',
    output: '9\n5\ngoto 结束\n',
    exercises: [
      LuaExercise(
        prompt: '用 goto 跳过值为 0 的元素并求和。',
        hint: '判断 value == 0 后 goto。',
        answer:
            'if value == 0 then goto continue end\ntotal = total + value\n::continue::',
      ),
      LuaExercise(
        prompt: '为什么标签要放在循环体末尾？',
        hint: '想想跳过之后应该继续下一轮。',
        answer: '因为跳到末尾正好结束本轮迭代，进入下一次循环，效果等同 continue。',
      ),
    ],
    pitfalls: ['goto 不能跳进 local 变量的作用域内。', '标签名在同一块里不能重复。'],
  ),
];
