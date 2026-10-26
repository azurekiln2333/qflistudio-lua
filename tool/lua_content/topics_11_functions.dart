import 'lua_topic.dart';

/// 第十一章：函数与参数。
const List<LuaTopic> topicsFunctions = [
  LuaTopic(
    id: 'lua-fn-define',
    chapter: 'functions',
    title: '定义与调用函数',
    summary: 'function 定义函数，return 返回值，没有 return 时返回 nil。',
    objective: '能定义带参数的函数并正确返回值。',
    level: 'beginner',
    concepts: ['function', 'return', '参数'],
    explain:
        '函数是值，function name(args) ... end 只是把函数赋给 name 的简写。'
        'return 会立刻结束函数；没有 return 时函数返回 nil。'
        '参数按值传递，表作为参数传的是引用。',
    code: r'''local function add(a, b)
  return a + b
end

local function greet(name)
  print("你好，" .. name)
end

local function noReturn(value)
  value = value * 2
end

print(add(2, 3))
greet("小明")
print(noReturn(5))
print(type(add))
print(select("#", noReturn(1)))
''',
    output: '5\n你好，小明\n\nfunction\n0\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数返回两个数中的较大者。',
        hint: '用 if 或 math.max。',
        answer:
            'local function max(a, b) if a > b then return a end return b end',
      ),
      LuaExercise(
        prompt: '为什么 print(noReturn(5)) 输出的是空行而不是 nil？',
        hint: '没有 return 的函数返回几个值？',
        answer:
            '没有 return 的函数返回「零个值」，不是 nil；print 收到零个参数就只输出换行，select("#") 也会得到 0。',
      ),
    ],
    pitfalls: ['忘了 return 会让调用方拿到 nil。', '函数必须先定义后调用（或用 local function 处理递归）。'],
  ),
  LuaTopic(
    id: 'lua-fn-multi-return',
    chapter: 'functions',
    title: '多返回值',
    summary: '一个函数可以返回多个值，调用处按位置接收。',
    objective: '能用多返回值同时返回结果与错误信息，并知道截断规则。',
    level: 'beginner',
    concepts: ['多返回值', '截断', '元组式'],
    explain:
        'return a, b 会返回两个值。'
        '赋值时左侧变量不够会丢弃多余值，变量多余则补 nil。'
        '多返回值只有在表达式末尾或作为唯一参数时才完整展开，'
        '放在括号里或用中间变量会截断成一个值。',
    code: r'''local function minmax(list)
  local low, high = list[1], list[1]
  for _, value in ipairs(list) do
    if value < low then low = value end
    if value > high then high = value end
  end
  return low, high
end

print(minmax({ 3, 1, 4, 1, 5 }))

local low, high = minmax({ 7, 2, 9 })
print(low, high)

local only = minmax({ 7, 2, 9 })
print(only)

print((minmax({ 7, 2, 9 })))
print(string.format("%d-%d", minmax({ 7, 2, 9 })))
''',
    output: '1\t5\n2\t9\n2\n2\n2-9\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数返回两个数的商和余数。',
        hint: '用 // 和 %。',
        answer: 'local function divmod(a, b) return a // b, a % b end',
      ),
      LuaExercise(
        prompt: '为什么 (minmax(t)) 只有一个值？',
        hint: '括号会截断多返回值。',
        answer: '圆括号把表达式调整为一个值，所以只保留第一个返回值。',
      ),
    ],
    pitfalls: ['在表达式中部使用多返回值会被截断成第一个。', '多返回值放在表构造器中间也会被截断，放末尾才全部展开。'],
  ),
  LuaTopic(
    id: 'lua-fn-varargs',
    chapter: 'functions',
    title: '可变参数 ...',
    summary: '用 ... 接收任意个参数，select("#") 得到参数个数。',
    objective: '能写可变参数函数，并区分 nil 参与时的计数问题。',
    level: 'intermediate',
    concepts: ['可变参数', 'select', '计数'],
    explain:
        '参数列表写 ... 表示接收任意个参数，函数体里也用 ... 展开它们。'
        'select("#", ...) 返回参数个数（包含 nil），select(n, ...) 返回从第 n 个开始的参数。'
        '要保留参数请用 table.pack，因为 {...} 在含 nil 时长度不可靠。',
    code: r'''local function count(...)
  return select("#", ...)
end

local function sum(...)
  local total = 0
  for i = 1, select("#", ...) do
    total = total + (select(i, ...) or 0)
  end
  return total
end

print(count(1, 2, 3))
print(count())
print(count(nil, nil))
print(sum(1, 2, nil, 4))
print(select(2, "a", "b", "c"))
print(select(-1, "a", "b", "c"))
''',
    output: '3\n0\n2\n7\nb\tc\nc\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数返回所有参数中的最大值。',
        hint: '遍历 select("#", ...)。',
        answer: '用一个循环配合 select(i, ...) 求最大。',
      ),
      LuaExercise(
        prompt: 'select(-1, ...) 返回什么？',
        hint: '负下标从末尾数。',
        answer: '返回最后一个参数。',
      ),
    ],
    pitfalls: ['用 # {...} 统计参数个数在含 nil 时不准。', '... 只能直接用在可变参数函数或它的直接嵌套块中。'],
  ),
  LuaTopic(
    id: 'lua-fn-default-arg',
    chapter: 'functions',
    title: '默认参数',
    summary: 'Lua 没有默认参数语法，用 or 或显式 nil 判断实现。',
    objective: '能用两种方式实现默认值，并知道 or 无法处理 false。',
    level: 'beginner',
    concepts: ['默认参数', 'or', 'nil 判断'],
    explain:
        '最简写法是 name = name or "默认"。'
        '但如果默认值需要保留 false 这种合法取值，就必须写 if name == nil then。'
        '参数很多的函数更适合用「选项表 + 默认表合并」。',
    code: r'''local function greet(name, greeting)
  name = name or "世界"
  greeting = greeting or "你好"
  return greeting .. "，" .. name
end

print(greet())
print(greet("小明"))
print(greet("小明", "早上好"))

local function enable(flag)
  if flag == nil then flag = true end
  return flag
end
print(tostring(enable()), tostring(enable(false)))

local defaults = { size = 10, color = "black" }
local function draw(options)
  local merged = {}
  for key, value in pairs(defaults) do merged[key] = value end
  for key, value in pairs(options or {}) do merged[key] = value end
  return string.format("%dx%s", merged.size, merged.color)
end
print(draw())
print(draw({ color = "red" }))
''',
    output:
        '你好，世界\n你好，小明\n早上好，小明\ntrue\tfalse\n'
        '10xblack\n10xred\n',
    exercises: [
      LuaExercise(
        prompt: '让 greet 支持把名字设成 false 表示匿名。',
        hint: '改用 == nil 判断。',
        answer: 'if name == nil then name = "世界" end',
      ),
      LuaExercise(
        prompt: '为什么 or 实现默认值会吃掉 false？',
        hint: 'false 在 or 里是假。',
        answer: 'false 触发 or 的右侧，于是默认值覆盖了调用方明确传入的 false。',
      ),
    ],
    pitfalls: ['or 默认值无法表达「显式传 false」。'],
  ),
  LuaTopic(
    id: 'lua-fn-named-args',
    chapter: 'functions',
    title: '命名参数（表）',
    summary: '用一个表传参，调用处用字段名表达意图。',
    objective: '能用选项表实现命名参数，并合并默认值。',
    level: 'intermediate',
    concepts: ['命名参数', '选项表', '合并'],
    explain:
        '参数超过三四个时，位置参数很难记住。'
        '改成传一张表，调用处写 { width = 3, height = 4 }，'
        '可读性立刻提升，新增字段也不会破坏已有调用。'
        '代价是需要在函数里合并默认值。',
    code: r'''local function createWindow(options)
  local settings = { width = 800, height = 600, title = "未命名", resizable = true }
  for key, value in pairs(options or {}) do
    settings[key] = value
  end
  return settings
end

local a = createWindow({ title = "编辑器" })
print(a.title, a.width, a.height)
print(a.resizable)

local b = createWindow({ width = 1024, resizable = false })
print(b.width, b.height, b.resizable)

local c = createWindow()
print(c.title)
''',
    output: '编辑器\t800\t600\ntrue\n1024\t600\tfalse\n未命名\n',
    exercises: [
      LuaExercise(
        prompt: '给 createWindow 增加 x、y 两个默认值。',
        hint: '在 settings 里加字段。',
        answer:
            'local settings = { width = 800, height = 600, x = 0, y = 0, ... }',
      ),
      LuaExercise(
        prompt: '命名参数有什么缺点？',
        hint: '想想每次调用都要建表。',
        answer: '每次调用都会创建一张表，参数很少时反而更啰嗦，也少了一点类型层面的检查。',
      ),
    ],
    pitfalls: ['字段名拼错不会报错，只会得到默认值。', '选项表里的未知字段会被一并复制进去，需要时要做白名单过滤。'],
  ),
  LuaTopic(
    id: 'lua-fn-recursion',
    chapter: 'functions',
    title: '递归',
    summary: '函数调用自身解决规模更小的同类问题，记得写终止条件。',
    objective: '能写递归函数并保证有终止条件，理解调用栈深度的代价。',
    level: 'intermediate',
    concepts: ['递归', '终止条件', '调用栈'],
    explain:
        '递归要有两个部分：把问题缩小一步，以及终止条件。'
        '漏掉终止条件会一直调用下去，直到栈溢出（stack overflow）。'
        'Lua 的默认栈深度有限，深递归要用尾调用或改成迭代。',
    code: r'''local function factorial(n)
  if n <= 1 then return 1 end
  return n * factorial(n - 1)
end
print(factorial(5))

local function fib(n)
  if n < 2 then return n end
  return fib(n - 1) + fib(n - 2)
end
print(fib(10))

local function depthLimit(n, limit)
  if n > limit then return "到达上限" end
  return depthLimit(n + 1, limit)
end
print(depthLimit(0, 5))

local function sumList(list, index)
  index = index or 1
  if index > #list then return 0 end
  return list[index] + sumList(list, index + 1)
end
print(sumList({ 1, 2, 3, 4 }))
''',
    output: '120\n55\n到达上限\n10\n',
    exercises: [
      LuaExercise(
        prompt: '用递归求一个数的各位数字和。',
        hint: 'n % 10 与 n // 10。',
        answer:
            'local function digitSum(n) if n < 10 then return n end return n % 10 + digitSum(n // 10) end',
      ),
      LuaExercise(
        prompt: '为什么简单递归 fib(30) 很慢？',
        hint: '重复子问题。',
        answer: '因为它把同一子问题重复计算了指数次，复杂度是指数级；需要记忆化或改迭代。',
      ),
    ],
    pitfalls: ['缺少终止条件会栈溢出。', '递归深度受限，处理大列表要改成迭代。'],
  ),
  LuaTopic(
    id: 'lua-fn-tail-call',
    chapter: 'functions',
    title: '尾调用优化',
    summary: 'return f(...) 形式的尾调用不增长调用栈。',
    objective: '能把递归改写成尾调用形式，避免深递归爆栈。',
    level: 'advanced',
    concepts: ['尾调用', '栈帧', '优化'],
    explain:
        '当 return 后面只有一个函数调用、没有任何其他运算时，'
        'Lua 会复用当前栈帧（proper tail call），因此可以安全地深递归。'
        '改成尾调用通常要把中间结果作为参数累加传递。',
    code: r'''local function factTail(n, acc)
  if n <= 1 then return acc end
  return factTail(n - 1, n * acc)
end
print(factTail(5, 1))
print(factTail(20, 1))

local function countDown(n)
  if n == 0 then return "结束" end
  return countDown(n - 1)
end
print(countDown(200000))

local function notTail(n)
  if n == 0 then return 0 end
  return 1 + notTail(n - 1)
end
print(notTail(1000))
''',
    output: '120\n2432902008176640000\n结束\n1000\n',
    exercises: [
      LuaExercise(
        prompt: '把求和递归改成尾调用形式。',
        hint: '把累加和作为参数传下去。',
        answer:
            'local function sumTail(list, i, acc) i = i or 1; acc = acc or 0; if i > #list then return acc end; return sumTail(list, i + 1, acc + list[i]) end',
      ),
      LuaExercise(
        prompt: '为什么 return 1 + f(n-1) 不是尾调用？',
        hint: '返回后还要做加法。',
        answer: '因为调用返回后还要执行加法，必须保留当前栈帧，无法复用。',
      ),
    ],
    pitfalls: ['return 后面带运算就不是尾调用。', '多层函数嵌套里的尾调用同样有效，但逻辑上仍要自己保证终止。'],
  ),
  LuaTopic(
    id: 'lua-fn-first-class',
    chapter: 'functions',
    title: '函数是一等值',
    summary: '函数可以存进表、作为参数传递、作为返回值。',
    objective: '能用函数表组织行为，把函数当作数据来组合。',
    level: 'beginner',
    concepts: ['一等值', '高阶函数', '函数表'],
    explain:
        'Lua 的函数和数字、字符串一样是值：'
        '可以赋给变量、放进表、当参数传、当返回值返回。'
        '这让「行为表」成为可能：用名字查函数，按数据驱动执行。',
    code: r'''local operations = {
  add = function(a, b) return a + b end,
  max = function(a, b) return math.max(a, b) end,
}

print(operations.add(2, 3))
print(operations.max(2, 3))

local function apply(fn, value)
  return fn(value)
end

print(apply(function(v) return v * 2 end, 21))

local function makeAdder(step)
  return function(value) return value + step end
end

local add10 = makeAdder(10)
print(add10(5))

local list = { operations.add, operations.max }
print(list[1](1, 2), list[2](4, 9))
''',
    output: '5\n3\n42\n15\n3\t9\n',
    exercises: [
      LuaExercise(
        prompt: '把三个函数放进表里并用循环依次调用。',
        hint: 'for _, fn in ipairs(funcs) do print(fn(2)) end',
        answer: '把函数放进数组，然后 ipairs 遍历调用。',
      ),
      LuaExercise(
        prompt: 'print(operations.add) 会输出什么？',
        hint: '函数也是值。',
        answer: '输出函数地址形式的字符串，说明它本身就是一个值。',
      ),
    ],
    pitfalls: ['函数相等比较的是引用，两个内容相同的函数也不相等。', '直接把函数当表键要保证引用稳定。'],
  ),
  LuaTopic(
    id: 'lua-fn-return-adjust',
    chapter: 'functions',
    title: '多返回值的截断规则',
    summary: '多返回值在表达式中间会被截断，只有末尾位置才完整展开。',
    objective: '能预测什么时候能拿到全部返回值，避免参数错位。',
    level: 'advanced',
    concepts: ['截断', '参数展开', '括号'],
    explain:
        '规则：函数调用作为表达式的最后一个元素、或作为调用的唯一实参时，全部返回值都保留；'
        '其他位置只保留第一个。'
        '这解释了 print(f()) 输出两个值，而 print(f(), "x") 只输出第一个再拼 x 的现象。',
    code: r'''local function three()
  return 1, 2, 3
end

print(three())
print(three(), "x")
print((three()))

local packed = { three() }
print(#packed, packed[1], packed[2], packed[3])

local packedMid = { three(), "x" }
print(#packedMid)

local a, b, c, d = three()
print(a, b, c, d)

print(string.format("%d %d", three()))
''',
    output: '1\t2\t3\n1\tx\n1\n3\t1\t2\t3\n2\n1\t2\t3\tnil\n1 2\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 { three(), "x" } 只有两个元素？',
        hint: '中间位置被截断。',
        answer: '因为 three() 不在末尾，只保留第一个返回值，所以表里是 1 和 "x"。',
      ),
      LuaExercise(
        prompt: '怎么把三个返回值都放进表里？',
        hint: '放末尾或用 table.pack。',
        answer: 'local t = { three() } 或 local t = table.pack(three())。',
      ),
    ],
    pitfalls: ['在函数调用参数中间使用多返回值会静默丢值。'],
  ),
  LuaTopic(
    id: 'lua-fn-table-args',
    chapter: 'functions',
    title: '用表批量传参与返回',
    summary: '把数组展开成参数、把结果打包成表，是处理变长数据的常用手法。',
    objective: '能用 unpack 展开参数，并把多个结果打包返回。',
    level: 'intermediate',
    concepts: ['unpack', '打包', '变长'],
    explain:
        'table.unpack(t) 把数组展开成多个参数，正好用来调用参数个数不固定的函数。'
        '反过来，把多个结果收集成表返回，调用方就能自由遍历、排序或切片，'
        '而不必记住返回值顺序。',
    code: r'''local function sum(...)
  local total = 0
  for _, value in ipairs({ ... }) do total = total + value end
  return total
end

local numbers = { 4, 8, 15, 16, 23, 42 }
print(sum(table.unpack(numbers)))

local function stats(...)
  local list = { ... }
  table.sort(list)
  return {
    count = #list,
    min = list[1],
    max = list[#list],
    middle = list[(#list + 1) // 2],
  }
end

local result = stats(5, 1, 9, 3, 7)
print(result.count, result.min, result.max, result.middle)

print(sum(table.unpack(numbers, 2, 4)))
''',
    output: '108\n5\t1\t9\t5\n39\n',
    exercises: [
      LuaExercise(
        prompt: '只把 numbers 的第 2 到第 3 个元素传给 sum。',
        hint: 'unpack 可以带起止下标。',
        answer: 'print(sum(table.unpack(numbers, 2, 3)))  -- 23',
      ),
      LuaExercise(
        prompt: '为什么 stats 返回表而不是多个返回值？',
        hint: '想想字段可读性。',
        answer: '字段名自带含义，调用方不必记住顺序，也方便以后加字段。',
      ),
    ],
    pitfalls: ['unpack 展开含 nil 的数组会提前截断。', '超长数组一次展开可能触发栈限制。'],
  ),
  LuaTopic(
    id: 'lua-fn-local-recursive',
    chapter: 'functions',
    title: 'local function 与递归可见性',
    summary: 'local function f 让函数在自己的函数体里也能引用自己。',
    objective: '能解释 local f = function() 与 local function f() 的差别。',
    level: 'advanced',
    concepts: ['local function', '递归', '作用域'],
    explain:
        'local function f() ... end 等价于先声明 local f 再赋值，'
        '所以函数体里的 f 指向自己，递归可用。'
        '而 local f = function() ... end 在函数体创建时 f 还不存在，'
        '里面的 f 会解析到外层的同名变量（通常是全局），递归就会静默失败。',
    code: r'''local function recursive(n)
  if n == 0 then return "done" end
  return recursive(n - 1)
end
print(recursive(3))

local broken
broken = function(n)
  if n == 0 then return "done" end
  return broken(n - 1)
end
print(broken(3))

local function outer()
  local inner
  inner = function(n)
    if n <= 0 then return 0 end
    return n + inner(n - 1)
  end
  return inner(4)
end
print(outer())

print(type(recursive))
''',
    output: 'done\ndone\n10\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '把 broken 的写法改成不需要预先声明。',
        hint: '用 local function。',
        answer: 'local function broken(n) ... end',
      ),
      LuaExercise(
        prompt: 'local f = function() return f() end 里的 f 指向哪？',
        hint: '声明时 f 还不存在。',
        answer: '指向外层的 f（通常是全局 null），所以调用会报 attempt to call a nil value。',
      ),
    ],
    pitfalls: ['local f = function() ... f() ... end 会静默引用到外层变量。'],
  ),
  LuaTopic(
    id: 'lua-fn-vararg-forward',
    chapter: 'functions',
    title: '转发可变参数',
    summary: '把 ... 原样转交给下一个函数，不丢失也不多包一层表。',
    objective: '能正确转发可变参数，并保留 nil 的计数信息。',
    level: 'advanced',
    concepts: ['转发', '...', '包装'],
    explain:
        '把参数转发给底层函数时，最忠实的方式是 ... 直接传，'
        '而不是 table.pack 再 unpack（后者在含 nil 时语义不同）。'
        '如果包裹函数需要同时处理参数数量，就用 select("#", ...) 读取。',
    code: r'''local function target(...)
  return select("#", ...), ...
end

local function forward(...)
  return target(...)
end

local function forwardTruncated(...)
  local args = { ... }
  return target(table.unpack(args))
end

print(forward(1, 2, 3))
print(forwardTruncated(1, 2, 3))
print(forward(nil, nil))

local function wrap(list, ...)
  table.insert(list, select("#", ...))
  return target(...)
end
print(wrap({}, "a", "b"))
''',
    output: '3\t1\t2\t3\n3\t1\t2\t3\n2\tnil\tnil\n2\ta\tb\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 forwardTruncated(nil, nil) 与 forward(nil, nil) 不同？',
        hint: '{ ... } 的长度。',
        answer: '因为 { ... } 在含 nil 时长度不确定，unpack 可能展开 0 个参数，而 ... 原样转发保留 2 个。',
      ),
      LuaExercise(
        prompt: '包装函数要统计参数个数应该用什么？',
        hint: 'select。',
        answer: 'select("#", ...)',
      ),
    ],
    pitfalls: ['用表做中转会丢失 nil 的位置信息。'],
  ),
];
