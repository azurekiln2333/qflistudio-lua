import 'lua_topic.dart';

/// 第十章：循环与迭代。
const List<LuaTopic> topicsLoops = [
  LuaTopic(
    id: 'lua-loop-numeric-for',
    chapter: 'loops',
    title: '数值 for 与步长',
    summary: 'for 按步长迭代，终点是包含在内的上界或下界。',
    objective: '能用步长控制方向，并知道边界包含规则。',
    level: 'beginner',
    concepts: ['for', '步长', '边界'],
    explain:
        '数值 for 的三个值分别是起点、终点、步长（默认 1）。'
        '初值满足边界才进入循环，终点只有恰好被步长到达时才执行；for i = 1, 3 会跑 3 次，而 1, 4, 2 只产生 1 和 3。'
        '步长可以是负数表示倒序，也可以是小数，但浮点步长会有累积误差。',
    code: r'''for i = 1, 3 do io.write(i, " ") end
print()

for i = 1, 10, 3 do io.write(i, " ") end
print()

for i = 3, 1, -1 do io.write(i, " ") end
print()

for i = 0, 1, 0.25 do io.write(i, " ") end
print()

local count = 0
for i = 10, 1 do count = count + 1 end
print(count)
''',
    output: '1 2 3 \n1 4 7 10 \n3 2 1 \n0 0.25 0.5 0.75 1 \n0\n',
    exercises: [
      LuaExercise(
        prompt: '输出 1 到 20 之间的偶数。',
        hint: '起点 2、步长 2。',
        answer: 'for i = 2, 20, 2 do print(i) end',
      ),
      LuaExercise(
        prompt: '为什么 for i = 10, 1 一次都不执行？',
        hint: '默认步长是正数。',
        answer: '默认步长为 1，起点大于终点且步长为正，循环条件一开始就不成立。',
      ),
    ],
    pitfalls: [
      '浮点步长会累积误差，需要精确计数时用整数循环再乘系数。',
      '循环变量在循环体内不应手动修改。',
      'io.write 不保留浮点的 .0（打印 1），print 才写 1.0，对比输出时要区分。',
    ],
  ),
  LuaTopic(
    id: 'lua-loop-while',
    chapter: 'loops',
    title: 'while 循环',
    summary: 'while 先判断条件再执行，条件为假时一次都不进。',
    objective: '能用 while 处理「不知道循环次数」的场景，并避免死循环。',
    level: 'beginner',
    concepts: ['while', '条件循环', '死循环'],
    explain:
        'while 每轮开始前判断条件，为真才执行循环体。'
        '适合「循环次数由数据决定」的场景，比如反复取数直到为空。'
        '必须在循环体里改变条件相关的变量，否则会死循环——'
        '在 IDE 里死循环会撞上执行超时保护。',
    code: r'''local value = 27
local steps = 0
while value > 1 do
  if value % 2 == 0 then
    value = value // 2
  else
    value = 3 * value + 1
  end
  steps = steps + 1
end
print(steps, value)

local queue = { "a", "b", "c" }
while #queue > 0 do
  local item = table.remove(queue, 1)
  io.write(item)
end
print()

local n = 0
while n < 3 do
  n = n + 1
end
print(n)
''',
    output: '111\t1\nabc\n3\n',
    exercises: [
      LuaExercise(
        prompt: '用 while 求 1 到 100 的和。',
        hint: '维护累加和与计数器。',
        answer:
            'local i, sum = 1, 0\nwhile i <= 100 do sum = sum + i; i = i + 1 end',
      ),
      LuaExercise(
        prompt: '如果 while 循环里忘了改条件变量会怎样？',
        hint: '想想执行超时。',
        answer: '会无限循环，最终被运行时的执行超时或取消机制打断并报错。',
      ),
    ],
    pitfalls: ['忘记推进条件变量导致死循环。', 'while 条件为假时循环体一次都不执行。'],
  ),
  LuaTopic(
    id: 'lua-loop-repeat',
    chapter: 'loops',
    title: 'repeat / until',
    summary: 'repeat 先执行一次再判断条件，条件为真时停止。',
    objective: '能用 repeat 表达「至少执行一次」的重试逻辑。',
    level: 'beginner',
    concepts: ['repeat', 'until', '至少一次'],
    explain:
        'repeat ... until cond 先执行循环体，再判断 cond，为真就结束。'
        '因此循环体至少执行一次，适合「先尝试再检查」的场景，比如重试、'
        '以及读取输入直到合法。'
        '注意 until 的条件写在末尾，布尔方向与 while 相反。',
    code: r'''local attempts = 0
repeat
  attempts = attempts + 1
until attempts >= 3
print(attempts)

local inputs = { "abc", "42" }
local index = 0
local value
repeat
  index = index + 1
  value = tonumber(inputs[index])
until value ~= nil or index > #inputs
print(index, value)

local runOnce = 0
repeat
  runOnce = runOnce + 1
until true
print(runOnce)
''',
    output: '3\n2\t42\n1\n',
    exercises: [
      LuaExercise(
        prompt: '用 repeat 实现最多 3 次重试，成功就退出。',
        hint: '条件写 success or attempts >= 3。',
        answer:
            'repeat attempts = attempts + 1; success = try() until success or attempts >= 3',
      ),
      LuaExercise(
        prompt: 'repeat ... until true 会执行几次？',
        hint: '先执行再判断。',
        answer: '执行一次，因为循环体总是先跑一遍。',
      ),
    ],
    pitfalls: [
      'until 的条件为真才停止，与 while 相反。',
      '循环体里声明的 local 在 until 条件里可见，这与 while 不同。',
    ],
  ),
  LuaTopic(
    id: 'lua-loop-break',
    chapter: 'loops',
    title: 'break 提前结束',
    summary: 'break 立即跳出当前循环，只跳一层。',
    objective: '能在找到目标后立刻结束循环，避免多余遍历。',
    level: 'beginner',
    concepts: ['break', '提前结束', '单层'],
    explain:
        'break 会立刻终止最内层循环，并继续执行循环之后的语句。'
        '嵌套循环里它只跳出一层，需要跳出多层时要配合标志变量或改用函数返回。'
        '搜索类循环找到目标后应该立刻 break，避免无效遍历。',
    code: r'''local target = 7
local numbers = { 3, 5, 7, 9 }
local foundAt

for index, value in ipairs(numbers) do
  if value == target then
    foundAt = index
    break
  end
end
print(foundAt)

local found
for i = 1, 3 do
  for j = 1, 3 do
    if i * j == 6 then
      found = i .. "x" .. j
      break
    end
  end
  if found then break end
end
print(found)

local checked = 0
for _, value in ipairs(numbers) do
  checked = checked + 1
  if value > 5 then break end
end
print(checked)
''',
    output: '3\n2x3\n3\n',
    exercises: [
      LuaExercise(
        prompt: '在数组里找第一个负数并记录下标。',
        hint: '找到就 break。',
        answer:
            'for i, v in ipairs(nums) do if v < 0 then index = i; break end end',
      ),
      LuaExercise(
        prompt: 'break 能跳出两层循环吗？',
        hint: '它只作用于最内层。',
        answer: '不能，需要用标志变量在每层判断，或把内层抽成函数用 return。',
      ),
    ],
    pitfalls: ['break 只能用于循环体，不能用在 if 里单独使用。', '嵌套循环里 break 只跳出一层，容易漏跳。'],
  ),
  LuaTopic(
    id: 'lua-loop-accumulate',
    chapter: 'loops',
    title: '循环累加与聚合',
    summary: '用累加器收集求和、计数、最大值等聚合结果。',
    objective: '能用一个循环同时算出多个聚合值。',
    level: 'beginner',
    concepts: ['累加', '聚合', '最大值'],
    explain:
        '聚合的通用模式是先初始化（求和用 0，最大值用第一个元素或 -math.huge），'
        '然后在一轮循环里更新所有统计量。'
        '一次遍历算多个指标比多次遍历更清晰，也避免重复扫描数据。',
    code: r'''local scores = { 88, 92, 57, 100, 73 }
local total, count, best, worst = 0, 0, nil, nil

for _, score in ipairs(scores) do
  total = total + score
  count = count + 1
  if best == nil or score > best then best = score end
  if worst == nil or score < worst then worst = score end
end

print(count, total, best, worst)
print(string.format("均值 %.2f", total / count))

local passed = 0
for _, score in ipairs(scores) do
  if score >= 60 then passed = passed + 1 end
end
print(passed)
''',
    output: '5\t410\t100\t57\n均值 82.00\n4\n',
    exercises: [
      LuaExercise(
        prompt: '再统计高于平均分的个数。',
        hint: '先算平均，再遍历一次。',
        answer:
            'local avg = total / count\nlocal above = 0\nfor _, s in ipairs(scores) do if s > avg then above = above + 1 end end',
      ),
      LuaExercise(
        prompt: '为什么最大值初始化用 nil 而不是 0？',
        hint: '想想全是负数的数组。',
        answer: '用 0 初始化时全负数组会得到错误的最大值 0；用 nil 或 -math.huge 才正确。',
      ),
    ],
    pitfalls: ['最大值初始化成 0 在负数数据上会出错。', '空数组求平均会除以 0，需要先判断 count。'],
  ),
  LuaTopic(
    id: 'lua-loop-nested-table',
    chapter: 'loops',
    title: '嵌套循环生成表格',
    summary: '外层控制行、内层控制列，是输出网格数据的标准写法。',
    objective: '能写出乘法表等二维输出，并保证每行独立拼接。',
    level: 'beginner',
    concepts: ['嵌套循环', '乘法表', '行拼接'],
    explain:
        '生成表格时，外层循环负责一行，内层把这一行的所有格子拼起来，'
        '最后打印整行。'
        '这种结构让「行的内容」和「列的格式」各归各位，'
        '改列宽只需要动内层格式化。',
    code: r'''for row = 1, 4 do
  local line = {}
  for col = 1, 4 do
    line[#line + 1] = string.format("%4d", row * col)
  end
  print(table.concat(line))
end

local triangle = {}
for row = 1, 4 do
  triangle[#triangle + 1] = string.rep("*", row)
end
print(table.concat(triangle, "|"))
''',
    output:
        '   1   2   3   4\n   2   4   6   8\n   3   6   9  12\n'
        '   4   8  12  16\n*|**|***|****\n',
    exercises: [
      LuaExercise(
        prompt: '只输出下半三角（col <= row）。',
        hint: '内层循环上限改成 row。',
        answer: 'for col = 1, row do ... end',
      ),
      LuaExercise(
        prompt: '为什么每行都要新建 line 表？',
        hint: '引用类型。',
        answer: '复用同一张表会让所有行指向同一份数据，最终只留下最后一次的内容。',
      ),
    ],
    pitfalls: ['每行复用同一个表会互相覆盖。'],
  ),
  LuaTopic(
    id: 'lua-loop-manual-iterator',
    chapter: 'loops',
    title: '手写无状态迭代器',
    summary: '迭代器就是每次调用返回下一个值的函数，可以自己写。',
    objective: '能写出 for 循环能用的迭代器函数，并理解 (状态, 控制变量) 协议。',
    level: 'advanced',
    concepts: ['迭代器', '泛型 for', '协议'],
    explain:
        '泛型 for 的协议是：for 变量 in f, s, var 中，f(s, var) 返回下一个控制值；'
        '返回 nil 表示结束。'
        '如果迭代器不需要共享状态，可以直接返回「下一个值」，'
        '靠闭包或表来记住位置。',
    code: r'''local function range(n)
  local i = 0
  return function()
    i = i + 1
    if i <= n then return i end
  end
end

for value in range(4) do io.write(value, " ") end
print()

local function chars(text)
  local i = 0
  return function()
    i = i + 1
    if i <= #text then return i, text:sub(i, i) end
  end
end

for index, ch in chars("lua") do
  print(index, ch)
end
''',
    output: '1 2 3 4 \n1\tl\n2\tu\n3\ta\n',
    exercises: [
      LuaExercise(
        prompt: '写一个倒序迭代器 rangeDown(n)。',
        hint: '从 n 开始递减到 1。',
        answer:
            'local i = n + 1\nreturn function() i = i - 1; if i >= 1 then return i end end',
      ),
      LuaExercise(
        prompt: '迭代器返回 nil 意味着什么？',
        hint: 'for 的终止条件。',
        answer: '表示序列结束，for 循环立刻停止。',
      ),
    ],
    pitfalls: ['迭代器必须最终返回 nil，否则 for 不会停。', '闭包状态在每次创建迭代器时都要重置。'],
  ),
  LuaTopic(
    id: 'lua-loop-stateful-iterator',
    chapter: 'loops',
    title: '带状态的迭代器与 pairs 协议',
    summary: '完整实现 (迭代函数, 状态, 初始值) 三件套，理解 next 的用法。',
    objective: '能写出符合完整协议的迭代器，并用 next 手动遍历表。',
    level: 'advanced',
    concepts: ['next', '迭代协议', '状态'],
    explain:
        'pairs(t) 实际返回 next, t, nil 三个值。'
        'for 每轮调用 next(t, 上一个键)，返回下一个键和值，直到返回 nil。'
        '理解这一点就能自定义遍历顺序，比如只遍历匹配前缀的键。',
    code: r'''local data = { a = 1, b = 2, c = 3 }
local function sortedPairs(source)
  local keys = {}
  for key in pairs(source) do keys[#keys + 1] = key end
  table.sort(keys)
  local i = 0
  return function()
    i = i + 1
    local key = keys[i]
    if key ~= nil then return key, source[key] end
  end
end

for key, value in sortedPairs(data) do
  io.write(key, "=", value, " ")
end
print()

local hand = next(data, nil)
print(type(hand))

local function prefixPairs(source, prefix)
  local keys = {}
  for key in pairs(source) do
    if key:sub(1, #prefix) == prefix then keys[#keys + 1] = key end
  end
  table.sort(keys)
  local i = 0
  return function()
    i = i + 1
    local key = keys[i]
    if key ~= nil then return key, source[key] end
  end
end

local config = { db_host = "local", db_port = 5432, cache = true }
for key, value in prefixPairs(config, "db_") do
  io.write(key, ":", tostring(value), " ")
end
print()
''',
    output: 'a=1 b=2 c=3 \nstring\ndb_host:local db_port:5432 \n',
    exercises: [
      LuaExercise(
        prompt: '用 next 手动遍历一次 data 并计数。',
        hint: 'while key ~= nil do key = next(data, key) end。',
        answer:
            'local key, count = next(data), 0\nwhile key ~= nil do count = count + 1; key = next(data, key) end',
      ),
      LuaExercise(
        prompt: 'for 循环里第三个值（初始控制变量）有什么作用？',
        hint: '它是第一次调用 next 的起点。',
        answer: '它作为迭代函数的第二个参数传入，决定从哪开始；pairs 传 nil 表示从头开始。',
      ),
    ],
    pitfalls: [
      'next 的键必须存在于表中，否则报 invalid key to next。',
      '遍历过程中删除当前键是允许的，但新增键行为不确定。',
    ],
  ),
];
