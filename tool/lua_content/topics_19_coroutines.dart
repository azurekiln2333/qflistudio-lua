import 'lua_topic.dart';

/// 第十九章：协程。
const List<LuaTopic> topicsCoroutines = [
  LuaTopic(
    id: 'lua-co-create-resume',
    chapter: 'coroutines',
    title: 'create 与 resume 基础',
    summary: 'coroutine.create 制造协程，resume 启动或继续它。',
    objective: '能写出最简单的协程，并说明 resume 的返回值含义。',
    level: 'beginner',
    concepts: ['coroutine.create', 'coroutine.resume', '状态'],
    explain:
        'create 接收一个函数，返回线程对象（type 是 "thread"）。'
        'resume 启动协程，返回 true 加上协程 yield 出来的值；'
        '协程内部出错时返回 false 加错误消息，而不是抛出到调用方。'
        '用 status 可以查询当前状态。',
    code: r'''local co = coroutine.create(function(a, b)
  print("收到", a, b)
  coroutine.yield(a + b)
  return "结束"
end)

print(type(co))
print(coroutine.status(co))

print(coroutine.resume(co, 1, 2))
print(coroutine.status(co))

print(coroutine.resume(co))
print(coroutine.status(co))

print(coroutine.resume(co))
''',
    output:
        'thread\nsuspended\n收到\t1\t2\ntrue\t3\nsuspended\n'
        'true\t结束\ndead\nfalse\tcannot resume dead coroutine\n',
    exercises: [
      LuaExercise(
        prompt: '创建协程并传两个参数，取回它们的和。',
        hint: 'resume(co, a, b)。',
        answer:
            'local co = coroutine.create(function(a, b) coroutine.yield(a + b) end)\nprint(coroutine.resume(co, 2, 3))',
      ),
      LuaExercise(
        prompt: '为什么要检查 resume 的第一个返回值？',
        hint: '协程里可能出错。',
        answer: '因为协程内部错误不会抛给调用方，而是返回 false 和错误消息，不检查就会静默失败。',
      ),
    ],
    pitfalls: [
      'resume 的返回值是 (ok, ...)，协程返回值不会直接成为第一个值。',
      'resume 已结束的协程会返回 false。',
    ],
  ),
  LuaTopic(
    id: 'lua-co-yield-values',
    chapter: 'coroutines',
    title: 'yield 与 resume 的值传递',
    summary: 'yield 把值送给调用方，resume 的参数成为 yield 的返回值。',
    objective: '能实现双向传值的协程，并知道哪一轮传什么。',
    level: 'intermediate',
    concepts: ['yield', '双向传值', '轮次'],
    explain:
        '第一次 resume 的参数传给协程函数的形参；'
        '之后每次 resume 的参数成为上一个 yield 表达式的返回值。'
        '这是理解协程「暂停点」的关键：yield 既产出值，也接收下一轮的输入。',
    code: r'''local co = coroutine.create(function(first)
  print("启动", first)
  local second = coroutine.yield("第一次让出")
  print("收到", second)
  local third = coroutine.yield("第二次让出")
  print("收到", third)
  return "完成"
end)

print(coroutine.resume(co, "A"))
print(coroutine.resume(co, "B"))
print(coroutine.resume(co, "C"))
print(coroutine.status(co))
''',
    output:
        '启动\tA\ntrue\t第一次让出\n收到\tB\ntrue\t第二次让出\n收到\tC\n'
        'true\t完成\ndead\n',
    exercises: [
      LuaExercise(
        prompt: '写一个协程：让出两次，每次收到输入后回显。',
        hint: 'yield 的返回值就是下一次 resume 的参数。',
        answer:
            'local co = coroutine.create(function() local x = coroutine.yield(); print(x) end)',
      ),
      LuaExercise(
        prompt: '为什么第二次 resume 的 "B" 出现在 yield 之后？',
        hint: '想想暂停点。',
        answer: '因为 yield 处暂停，恢复时 resume 的参数作为 yield 表达式的返回值继续执行。',
      ),
    ],
    pitfalls: [
      '第一次 resume 的参数不会成为 yield 的返回值，而是函数形参。',
      '忘记协程已经结束还继续 resume 会得到 false。',
    ],
  ),
  LuaTopic(
    id: 'lua-co-generator',
    chapter: 'coroutines',
    title: '用协程做生成器',
    summary: '把 yield 包成迭代器函数，就能用 for 消费序列。',
    objective: '能写出协程生成器并用泛型 for 遍历。',
    level: 'intermediate',
    concepts: ['生成器', '迭代器', '包装'],
    explain:
        '协程天然适合做生成器：'
        '内部用循环不断 yield，外部用 for 配合包装函数逐个取值。'
        '包装函数里 resume 并检查 ok，取值结束后返回 nil 让 for 停止。',
    code: r'''local function range(n)
  local co = coroutine.create(function()
    for i = 1, n do coroutine.yield(i) end
  end)
  return function()
    local ok, value = coroutine.resume(co)
    if not ok then return nil end
    return value
  end
end

local values = {}
for value in range(5) do values[#values + 1] = value end
print(table.concat(values, ","))
print(#values)

local total = 0
for value in range(100) do total = total + value end
print(total)

local empty = range(0)
print(empty())
''',
    output: '1,2,3,4,5\n5\n5050\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '写一个生成斐波那契数列的协程生成器。',
        hint: '协程里维护 a, b 两个变量。',
        answer:
            'local function fib() local a, b = 0, 1; return coroutine.create(function() while true do coroutine.yield(a); a, b = b, a + b end end) end',
      ),
      LuaExercise(
        prompt: '为什么生成器结束时返回 nil 而不是 false？',
        hint: 'for 怎么判断结束。',
        answer: '因为泛型 for 在第一个值非 nil 时继续，返回 nil 才能正常结束循环。',
      ),
    ],
    pitfalls: ['生成器只能遍历一次，再次遍历需要重新创建协程。', '忘记检查 ok 会把错误当成正常值返回。'],
  ),
  LuaTopic(
    id: 'lua-co-wrap',
    chapter: 'coroutines',
    title: 'coroutine.wrap 的便利与风险',
    summary: 'wrap 返回函数并自动传播错误，省掉手动检查 ok。',
    objective: '能说明 wrap 和 create 的差异，并知道何时不该用 wrap。',
    level: 'intermediate',
    concepts: ['coroutine.wrap', '错误传播', '迭代器'],
    explain:
        'wrap 返回一个函数，调用它就是 resume，但返回值去掉了 ok。'
        '协程内部出错时，错误会直接在调用方抛出，'
        '因此适合「希望错误冒泡」的迭代器场景。'
        '需要区分「迭代结束」和「出错」时要用 create。',
    code: r'''local function wrapRange(n)
  return coroutine.wrap(function()
    for i = 1, n do coroutine.yield(i) end
  end)
end

local function collect(iterator)
  local out = {}
  for value in iterator do out[#out + 1] = value end
  return table.concat(out, "-")
end

print(collect(wrapRange(3)))

local counter = coroutine.wrap(function()
  for i = 1, 2 do coroutine.yield(i) end
end)
print(counter())
print(counter())
print(counter() == nil)

local broken = coroutine.wrap(function() error("内部错误") end)
local ok, err = pcall(broken)
print(ok, (tostring(err):gsub("^.*main%.lua:%d+: ", "")))
print(type(broken))
''',
    output: '1-2-3\n1\n2\ntrue\nfalse\t内部错误\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '用 wrap 实现一个只产出偶数 2..10 的迭代器。',
        hint: 'for i = 2, 10, 2 do yield(i)。',
        answer:
            'local even = coroutine.wrap(function() for i = 2, 10, 2 do coroutine.yield(i) end end)',
      ),
      LuaExercise(
        prompt: '用 wrap 时怎么区分「结束」和「出错」？',
        hint: '想想 wrap 去掉了什么。',
        answer: 'wrap 无法区分，出错会直接抛出、结束返回 nil；需要区分就必须用 create 并检查 ok。',
      ),
    ],
    pitfalls: [
      'wrap 的错误消息带有路径和行号前缀，做稳定输出要先去到前缀。',
      '不要把 wrap 生成的函数跨协程共享使用，它是单实例状态。',
    ],
  ),
  LuaTopic(
    id: 'lua-co-producer-consumer',
    chapter: 'coroutines',
    title: '生产者与消费者',
    summary: '用协程把一个循环的数据按需生产给另一个循环消费。',
    objective: '能用协程解耦生产与消费，并说明它和数组缓冲的区别。',
    level: 'intermediate',
    concepts: ['生产者', '消费者', '按需'],
    explain:
        '生产者协程每次 yield 一个元素，消费者每次 resume 取一个。'
        '好处是不需要一次性生成全部数据，内存占用与数据总量无关。'
        '这本质上就是惰性求值。',
    code: r'''local function producer(items)
  return coroutine.create(function()
    for _, item in ipairs(items) do coroutine.yield(item) end
  end)
end

local co = producer({ "a", "b", "c", "d" })

local consumed = {}
while true do
  local ok, item = coroutine.resume(co)
  if not ok or item == nil then break end
  consumed[#consumed + 1] = item:upper()
end

print(table.concat(consumed, ""))
print(#consumed)
print(coroutine.status(co))
''',
    output: 'ABCD\n4\ndead\n',
    exercises: [
      LuaExercise(
        prompt: '只消费前两个元素就停止。',
        hint: '在循环里计数并 break。',
        answer:
            'local n = 0\nwhile n < 2 do n = n + 1; local ok, v = coroutine.resume(co); print(v) end',
      ),
      LuaExercise(
        prompt: '提前停止消费后协程处于什么状态？',
        hint: '没有跑完的协程。',
        answer: 'suspended，因为它停在 yield 处没有结束。',
      ),
    ],
    pitfalls: ['忘记判断 item == nil 会把 nil 也当成数据。'],
  ),
  LuaTopic(
    id: 'lua-co-status',
    chapter: 'coroutines',
    title: 'coroutine.status 与 isyieldable',
    summary: 'status 返回 suspended/running/normal/dead 四种状态。',
    objective: '能读懂四种状态的含义，并在协程内判断能否 yield。',
    level: 'advanced',
    concepts: ['status', 'running', 'normal'],
    explain:
        'status 对未启动和已让出的协程都返回 "suspended"；'
        '正在运行的协程返回 "running"，'
        '嵌套调用中「父协程」的状态是 "normal"，'
        '结束后是 "dead"。'
        'isyieldable 在不能 yield 的位置（如主线程）返回 false。',
    code: r'''local outer

outer = coroutine.create(function()
  print("outer 里看自己", coroutine.status(outer))
  local inner
  inner = coroutine.create(function()
    print("inner 里看自己", coroutine.status(inner))
    print("inner 里看 outer", coroutine.status(outer))
    coroutine.yield()
  end)
  coroutine.resume(inner)
  print("inner 让出后", coroutine.status(inner))
end)

print("启动前", coroutine.status(outer))
print(coroutine.resume(outer))
print("outer 让出？", coroutine.status(outer))
print("结束", coroutine.status(outer))

print(coroutine.isyieldable())
print(type(coroutine.running()))
print(select("#", coroutine.running()))
''',
    output:
        '启动前\tsuspended\nouter 里看自己\trunning\ninner 里看自己\trunning\n'
        'inner 里看 outer\tnormal\ninner 让出后\tsuspended\ntrue\n'
        'outer 让出？\tdead\n结束\tdead\nfalse\nthread\n2\n',
    exercises: [
      LuaExercise(
        prompt: '在协程内打印自己的状态。',
        hint: 'status 接收线程对象。',
        answer:
            'local co; co = coroutine.create(function() print(coroutine.status(co)) end)',
      ),
      LuaExercise(
        prompt: '为什么主线程 isyieldable 是 false？',
        hint: '想想 yield 需要谁接收。',
        answer: '因为主线程没有调用者可以接收 yield 的值，因此不允许让出。',
      ),
    ],
    pitfalls: ['normal 状态只出现在嵌套协程调用中。', '在主线程调用 yield 会报错。'],
  ),
  LuaTopic(
    id: 'lua-co-close',
    chapter: 'coroutines',
    title: 'coroutine.close 与清理',
    summary: 'close 关闭挂起的协程，触发 to-be-closed 变量的清理。',
    objective: '能用 close 主动释放协程资源，并处理待清理变量的关闭顺序。',
    level: 'advanced',
    concepts: ['coroutine.close', 'to-be-closed', '清理'],
    explain:
        'Lua 5.4 新增 coroutine.close(co)，'
        '它把挂起的协程就地结束，并执行其中所有待关闭变量（<close>）的 __close。'
        '返回 true 表示成功，若清理过程出错则返回 false 加错误。'
        '已结束的协程 close 也返回 true。',
    code: r'''local log = {}

local co = coroutine.create(function()
  local first <close> = setmetatable({}, {
    __close = function() log[#log + 1] = "first" end,
  })
  local second <close> = setmetatable({}, {
    __close = function() log[#log + 1] = "second" end,
  })
  coroutine.yield("挂起")
  log[#log + 1] = "不会执行"
end)

print(coroutine.resume(co))
print(coroutine.status(co))
print(#log)

print(coroutine.close(co))
print(coroutine.status(co))
print(table.concat(log, ","))
print(coroutine.close(co))
''',
    output: 'true\t挂起\nsuspended\n0\ntrue\ndead\nsecond,first\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '创建一个带 <close> 变量的协程，yield 后 close 并观察顺序。',
        hint: '先声明的后关闭。',
        answer: '两个待关闭变量会按声明的逆序关闭，所以先打印后者。',
      ),
      LuaExercise(
        prompt: '能否 close 正在运行的协程？',
        hint: '想想状态。',
        answer: '不能，只能在挂起或已结束的协程上调用。',
      ),
    ],
    pitfalls: [
      'close 已结束的协程不会重复执行清理。',
      'yield 之后不会执行到 return，必须依赖 __close 清理。',
    ],
  ),
  LuaTopic(
    id: 'lua-co-iterator-protocol',
    chapter: 'coroutines',
    title: '协程迭代器与三返回值协议',
    summary: '泛型 for 可使用迭代函数、状态、初始控制值及可选关闭值。',
    objective: '能写出符合 for 协议的协程迭代器，并说明每个返回值的作用。',
    level: 'advanced',
    concepts: ['泛型 for', '三返回值', '协议'],
    explain:
        '泛型 for 的写法 for a in f, s, var do 中，'
        'f 是迭代函数，s 是状态（固定传回），var 是首个控制变量。'
        '每轮调用 f(s, var)，只要第一个返回值非 nil 循环就继续；闭包也可只返回函数并自行保存状态。'
        'Lua 5.4 还允许第四个关闭值。',
    code: r'''local function charIterator(text)
  local co = coroutine.create(function()
    for character in text:gmatch(".") do coroutine.yield(character) end
  end)

  local function step()
    local ok, value = coroutine.resume(co)
    if not ok then return nil end
    return value
  end

  return step, nil, nil
end

local out = {}
for character in charIterator("lua") do out[#out + 1] = character end
print(table.concat(out, "+"))
print(#out)

for character in charIterator("abc") do
  io.write(character:upper(), " ")
end
print()

local function noValues() return nil, "忽略", "忽略" end
local n = 0
for _ in noValues do n = n + 1 end
print(n)
''',
    output: 'l+u+a\n3\nA B C \n0\n',
    exercises: [
      LuaExercise(
        prompt: '迭代器工厂必须返回三个值吗？',
        hint: '闭包可以把状态放在哪里？',
        answer:
            '不必。闭包可只返回迭代函数，并忽略补为 nil 的状态与控制值；普通工厂也可显式返回三者，第四个可选值用于循环结束时关闭资源。',
      ),
      LuaExercise(
        prompt: '第一个返回值为 nil 会怎样？',
        hint: '循环条件。',
        answer: '循环立即结束，所以迭代器用 nil 表示「没有更多元素」。',
      ),
    ],
    pitfalls: ['迭代函数返回值多于一个时，for 只用第一个判断是否继续。'],
  ),
  LuaTopic(
    id: 'lua-co-async-style',
    chapter: 'coroutines',
    title: '协程模拟任务调度',
    summary: '多个协程轮流 resume，模拟协作式多任务。',
    objective: '能实现简单的轮转调度，并说明协作式与抢占式的区别。',
    level: 'advanced',
    concepts: ['调度', '协作式', '轮转'],
    explain:
        '把多个协程放进列表，循环里依次 resume，'
        '每个协程 yield 一次就相当于交还控制权。'
        '这就是协作式多任务：切换点由代码自己决定，'
        '没有抢占，也不用处理数据竞争。',
    code: r'''local function task(name, steps)
  return coroutine.create(function()
    for i = 1, steps do coroutine.yield(name .. i) end
    return name .. "完成"
  end)
end

local tasks = { task("A", 2), task("B", 1), task("C", 3) }
local yielded = {}
local finished = {}
local alive = #tasks

while alive > 0 do
  alive = 0
  for _, co in ipairs(tasks) do
    if coroutine.status(co) ~= "dead" then
      local ok, value = coroutine.resume(co)
      if coroutine.status(co) == "dead" then
        finished[#finished + 1] = value
      else
        yielded[#yielded + 1] = value
        alive = alive + 1
      end
    end
  end
end

print(table.concat(yielded, " "))
print(table.concat(finished, " "))
print(#yielded, #finished)
print(coroutine.status(tasks[2]))
''',
    output: 'A1 B1 C1 A2 C2 C3\nB完成 A完成 C完成\n6\t3\ndead\n',
    exercises: [
      LuaExercise(
        prompt: '为什么这里不需要锁？',
        hint: '想想切换时机。',
        answer: '因为只在 yield 处切换，共享状态不会在中途被另一个协程修改。',
      ),
      LuaExercise(
        prompt: '为什么「完成」和「产出」要分开记录？',
        hint: '想想最后那次 resume 返回什么。',
        answer: '因为协程结束时 resume 返回的是它的 return 值，和 yield 的值混在一起就看不出各自产出了多少。',
      ),
    ],
    pitfalls: [
      '某个协程不 yield 会一直占用直到结束，其他任务得不到执行。',
      'dead 协程要跳过，否则 resume 会一直返回 false。',
    ],
  ),
];
