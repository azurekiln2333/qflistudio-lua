import 'lua_topic.dart';

/// 第十二章：闭包与高阶函数。
const List<LuaTopic> topicsClosures = [
  LuaTopic(
    id: 'lua-clo-counter',
    chapter: 'closures',
    title: '计数器闭包',
    summary: '内部变量被返回的函数捕获，从而在多次调用之间保持状态。',
    objective: '能用闭包封装私有状态并对外只暴露操作函数。',
    level: 'intermediate',
    concepts: ['闭包', '私有状态', '工厂函数'],
    explain:
        '闭包是「函数 + 它捕获的变量」。'
        '工厂函数里声明的 local count 在函数返回后依然存活，'
        '因为返回的匿名函数引用了它。'
        '外部无法直接读写 count，只能通过返回的函数操作，这就是最简单的封装。',
    code: r'''local function makeCounter()
  local count = 0
  return {
    inc = function()
      count = count + 1
      return count
    end,
    get = function() return count end,
    reset = function() count = 0 end,
  }
end

local counter = makeCounter()
print(counter.inc(), counter.inc(), counter.get())
counter.reset()
print(counter.get())

local other = makeCounter()
print(other.inc(), counter.get())
''',
    output: '1\t2\t2\n0\n1\t0\n',
    exercises: [
      LuaExercise(
        prompt: '给计数器加一个 dec 方法。',
        hint: '和 inc 对称。',
        answer: 'dec = function() count = count - 1; return count end',
      ),
      LuaExercise(
        prompt: '为什么两个计数器互不影响？',
        hint: '每次调用工厂都创建新的局部变量。',
        answer: '每次 makeCounter() 都创建了一份新的 count，闭包各自捕获自己的那份。',
      ),
    ],
    pitfalls: ['闭包捕获的是变量本身，循环里共享同一个变量时容易出错。', '闭包会让被捕获的对象无法及时回收。'],
  ),
  LuaTopic(
    id: 'lua-clo-shared-state',
    chapter: 'closures',
    title: '多个闭包共享同一状态',
    summary: '同一个作用域里创建的多个函数共享捕获变量。',
    objective: '能用共享状态实现读写分离的接口。',
    level: 'intermediate',
    concepts: ['共享状态', '闭包', '接口分离'],
    explain:
        '只要几个函数是在同一个作用域里创建的，它们捕获的就是同一份变量。'
        '因此可以一个函数写、一个函数读，外部拿不到变量本身。'
        '这也是模块私有状态的常见写法。',
    code: r'''local function makeAccount(initial)
  local balance = initial
  local history = {}

  local function deposit(amount)
    if amount <= 0 then return nil, "金额必须为正" end
    balance = balance + amount
    history[#history + 1] = "+" .. amount
    return balance
  end

  local function withdraw(amount)
    if amount > balance then return nil, "余额不足" end
    balance = balance - amount
    history[#history + 1] = "-" .. amount
    return balance
  end

  local function statement()
    return table.concat(history, " ")
  end

  return { deposit = deposit, withdraw = withdraw, statement = statement }
end

local account = makeAccount(100)
print(account.deposit(50))
print(account.withdraw(30))
print(account.withdraw(500))
print(account.statement())
''',
    output: '150\n120\nnil\t余额不足\n+50 -30\n',
    exercises: [
      LuaExercise(
        prompt: '增加一个 balanceOf 函数只读余额。',
        hint: '返回 balance。',
        answer: 'local function balanceOf() return balance end',
      ),
      LuaExercise(
        prompt: '外部能直接改 balance 吗？',
        hint: '它在闭包里。',
        answer: '不能，balance 是工厂函数的局部变量，外部没有引用。',
      ),
    ],
    pitfalls: ['把 balance 放进返回的表就会失去封装。'],
  ),
  LuaTopic(
    id: 'lua-clo-loop-capture',
    chapter: 'closures',
    title: '循环里的闭包捕获',
    summary: '在循环体内用 local 复制循环变量，才能捕获每一轮的值。',
    objective: '能避免所有闭包共享最后一个循环值的经典错误。',
    level: 'advanced',
    concepts: ['循环捕获', 'local 副本', '经典错误'],
    explain:
        '数值 for 的循环变量在每轮都是新的绑定，所以直接捕获通常是安全的。'
        '但用 while 或手动递增的共享变量时，所有闭包会看到最终值。'
        '稳妥做法是在循环体里先 local copy = value，再让闭包捕获 copy。',
    code: r'''local functions = {}
for i = 1, 3 do
  functions[i] = function() return i end
end
print(functions[1](), functions[2](), functions[3]())

local shared = {}
local value = 1
while value <= 3 do
  shared[#shared + 1] = function() return value end
  value = value + 1
end
print(shared[1](), shared[2](), shared[3]())

local copied = {}
local cursor = 1
while cursor <= 3 do
  local snapshot = cursor
  copied[#copied + 1] = function() return snapshot end
  cursor = cursor + 1
end
print(copied[1](), copied[2](), copied[3]())
''',
    output: '1\t2\t3\n4\t4\t4\n1\t2\t3\n',
    exercises: [
      LuaExercise(
        prompt: '把 shared 的写法改正确。',
        hint: '加 local snapshot。',
        answer: '在 while 循环体里 local snapshot = value，闭包返回 snapshot。',
      ),
      LuaExercise(
        prompt: '为什么数值 for 不会出现 4 4 4？',
        hint: '每轮都是新的局部变量。',
        answer: '数值 for 的循环变量每轮都是新的绑定，闭包各自捕获对应那一轮。',
      ),
    ],
    pitfalls: ['用共享变量做 while 循环时，闭包捕获的是同一个变量。'],
  ),
  LuaTopic(
    id: 'lua-clo-curry',
    chapter: 'closures',
    title: '柯里化',
    summary: '把多参数函数拆成一系列单参数函数，逐步固定参数。',
    objective: '能用闭包实现柯里化，并复用它生成专用函数。',
    level: 'advanced',
    concepts: ['柯里化', '偏应用', '闭包'],
    explain:
        '柯里化把 f(a, b) 变成 f(a)(b)。'
        '每次调用只接收一部分参数，返回的新函数记住已传入的值。'
        '它的实用价值是「生成专用函数」：从通用函数派生出只差一个参数的版本。',
    code: r'''local function curry2(fn)
  return function(a)
    return function(b)
      return fn(a, b)
    end
  end
end

local add = curry2(function(a, b) return a + b end)
print(add(2)(3))

local add10 = add(10)
print(add10(5), add10(-1))

local function curry3(fn)
  return function(a)
    return function(b)
      return function(c)
        return fn(a, b, c)
      end
    end
  end
end

local format3 = curry3(string.format)
print(format3("%s=%d")("count")(7))
''',
    output: '5\n15\t9\ncount=7\n',
    exercises: [
      LuaExercise(
        prompt: '用 curry2 生成一个乘以 3 的函数。',
        hint: '先固定第一个参数。',
        answer:
            'local mul = curry2(function(a, b) return a * b end)\nlocal triple = mul(3)\nprint(triple(4))',
      ),
      LuaExercise(
        prompt: '柯里化和普通默认参数相比有什么取舍？',
        hint: '想想调用形式。',
        answer: '柯里化便于逐步复用和组合，但调用形式更啰嗦，每次都会创建闭包。',
      ),
    ],
    pitfalls: ['柯里化层数多时可读性下降，超过三层要考虑选项表。'],
  ),
  LuaTopic(
    id: 'lua-clo-memoize',
    chapter: 'closures',
    title: '记忆化缓存',
    summary: '用表缓存函数结果，避免重复计算。',
    objective: '能用闭包加缓存表实现单参数记忆化，并区分值相等和引用相同。',
    level: 'advanced',
    concepts: ['记忆化', '缓存', '闭包'],
    explain:
        '记忆化的关键是「参数 → 结果」的缓存表。'
        '示例直接用参数当表键，表也可以作键，但按对象身份而非内容比较。'
        '若希望内容相同的不同表共享结果，需设计规范化键；nil 和 NaN 不能作为键。'
        '缓存会一直增长，长跑程序要加容量限制。',
    code: r'''local function memoize(fn)
  local cache = {}
  return function(n)
    local cached = cache[n]
    if cached ~= nil then return cached, true end
    local value = fn(n)
    cache[n] = value
    return value, false
  end
end

local calls = 0
local function slowFib(n)
  calls = calls + 1
  if n < 2 then return n end
  return slowFib(n - 1) + slowFib(n - 2)
end

local fastFib
fastFib = memoize(function(n)
  if n < 2 then return n end
  return fastFib(n - 1) + fastFib(n - 2)
end)

print(fastFib(20))
print(fastFib(20))
print(calls)

local memoAdd = memoize(function(n) return n + 1 end)
print(memoAdd(1))
print(memoAdd(1))
print(memoAdd(2))
''',
    output: '6765\tfalse\n6765\ttrue\n0\n2\tfalse\n2\ttrue\n3\tfalse\n',
    exercises: [
      LuaExercise(
        prompt:
            '为什么 local fastFib = memoize(function() ... fastFib() ... end) 会报 nil？',
        hint: '声明时 fastFib 还不存在。',
        answer: '函数体里的 fastFib 解析到外层/全局，而不是正在声明的局部变量；先 local fastFib 再赋值才能递归。',
      ),
      LuaExercise(
        prompt: '为什么缓存里用 ~= nil 判断而不是 if cached？',
        hint: '结果可能是 false 或 0。',
        answer:
            'false 是有效结果，但 if cached 会把它当成未命中；0 在 Lua 中是真值，不会漏掉。~= nil 只排除未缓存项。',
      ),
    ],
    pitfalls: [
      '用 if cached then 判断会漏掉 false；本示例也不缓存 nil 结果，需另设存在标记才能支持。',
      '无上限缓存会持续占内存。',
    ],
  ),
  LuaTopic(
    id: 'lua-clo-compose',
    chapter: 'closures',
    title: '函数组合',
    summary: '把两个函数串成一个新函数，数据依次流过它们。',
    objective: '能实现 compose/pipe 并注意执行顺序。',
    level: 'advanced',
    concepts: ['组合', 'pipe', '高阶函数'],
    explain:
        'compose(f, g)(x) 等价于 f(g(x))：先执行 g 再执行 f，从右往左。'
        'pipe(f, g)(x) 则是 g(f(x))，从左往右，读起来更符合数据流。'
        '组合出来的函数仍然是普通函数，可以继续组合。',
    code: r'''local function compose(...)
  local fns = { ... }
  return function(value)
    for i = #fns, 1, -1 do
      value = fns[i](value)
    end
    return value
  end
end

local function pipe(...)
  local fns = { ... }
  return function(value)
    for i = 1, #fns do
      value = fns[i](value)
    end
    return value
  end
end

local double = function(n) return n * 2 end
local increment = function(n) return n + 1 end
local toString = function(n) return "值=" .. n end

print(compose(toString, double)(3))
print(pipe(double, increment)(3))
print(compose(double, increment)(3))
print(pipe(double, toString)(5))
print(compose(toString, increment)(5))
''',
    output: '值=6\n7\n8\n值=10\n值=6\n',
    exercises: [
      LuaExercise(
        prompt: '用 pipe 组合「去空格 → 转小写」。',
        hint: '两个单参数函数。',
        answer:
            r'local normalize = pipe(function(s) return s:match("^%s*(.-)%s*$") end, string.lower)',
      ),
      LuaExercise(
        prompt: 'compose(f, g) 与 pipe(f, g) 的结果何时相同？',
        hint: '想想交换律。',
        answer: '当 f 和 g 可交换时相同，一般情况下不同。',
      ),
    ],
    pitfalls: ['compose 是右到左执行，容易和 pipe 搞反。'],
  ),
  LuaTopic(
    id: 'lua-clo-map-filter',
    chapter: 'closures',
    title: 'map 与 filter',
    summary: '用闭包把「对每个元素做什么」抽象成参数。',
    objective: '能实现不修改原数组的 map/filter，并链式组合。',
    level: 'intermediate',
    concepts: ['map', 'filter', '不可变'],
    explain:
        'map 对每个元素应用函数并收集结果，filter 按谓词筛选元素。'
        '两者都返回新数组，不修改输入，这样可以安全地链式调用。'
        'Lua 没有内置这两个函数，自己实现只要几行。',
    code: r'''local function map(list, fn)
  local out = {}
  for index, value in ipairs(list) do
    out[index] = fn(value, index)
  end
  return out
end

local function filter(list, predicate)
  local out = {}
  for _, value in ipairs(list) do
    if predicate(value) then out[#out + 1] = value end
  end
  return out
end

local numbers = { 1, 2, 3, 4, 5, 6 }
local doubled = map(numbers, function(n) return n * 2 end)
print(table.concat(doubled, ","))

local evens = filter(numbers, function(n) return n % 2 == 0 end)
print(table.concat(evens, ","))

local result = map(filter(numbers, function(n) return n > 3 end),
  function(n) return n * n end)
print(table.concat(result, ","))

print(table.concat(numbers, ","))
''',
    output: '2,4,6,8,10,12\n2,4,6\n16,25,36\n1,2,3,4,5,6\n',
    exercises: [
      LuaExercise(
        prompt: '用 map 把字符串数组全部转成大写。',
        hint: 'fn 里调用 s:upper()。',
        answer: 'map(words, function(s) return s:upper() end)',
      ),
      LuaExercise(
        prompt: '为什么原数组没有被修改？',
        hint: '看 out 表。',
        answer: '因为 map/filter 都新建 out 表写入结果，输入表只读。',
      ),
    ],
    pitfalls: ['filter 用 out[#out + 1] 追加，别用原下标，否则会出现空洞。'],
  ),
  LuaTopic(
    id: 'lua-clo-reduce',
    chapter: 'closures',
    title: 'reduce 聚合',
    summary: '把数组折叠成单个值，是求和、求积、拼接的通用形式。',
    objective: '能实现 reduce 并用它替代重复的累加循环。',
    level: 'advanced',
    concepts: ['reduce', '折叠', '累加器'],
    explain:
        'reduce(list, fn, init) 从初始值开始，把每个元素与累加值交给 fn，'
        '结果作为新的累加值。'
        '求和、求积、最大值、拼字符串都能用同一个 reduce 表达，'
        '区别只在初始值和 fn。',
    code: r'''local function reduce(list, fn, initial)
  local accumulator = initial
  for _, value in ipairs(list) do
    accumulator = fn(accumulator, value)
  end
  return accumulator
end

local numbers = { 1, 2, 3, 4 }
print(reduce(numbers, function(a, b) return a + b end, 0))
print(reduce(numbers, function(a, b) return a * b end, 1))
print(reduce(numbers, function(a, b) return math.max(a, b) end, 0))
print(reduce({ "a", "b", "c" }, function(a, b) return a .. b end, ""))

local function maxOf(list)
  return reduce(list, function(a, b) return math.max(a, b) end, list[1])
end
print(maxOf({ 3, 9, 2 }))
''',
    output: '10\n24\n4\nabc\n9\n',
    exercises: [
      LuaExercise(
        prompt: '用 reduce 统计数组中大于 2 的元素个数。',
        hint: '初始 0，fn 里条件累加。',
        answer:
            'reduce(numbers, function(n, v) if v > 2 then return n + 1 end return n end, 0)',
      ),
      LuaExercise(
        prompt: 'reduce 的初始值可以省略吗？',
        hint: '想想空数组。',
        answer: '省略时通常用第一个元素当初始值，但空数组要单独处理，显式传初始值更安全。',
      ),
    ],
    pitfalls: ['空数组不传初始值会出错，需要单独判断。'],
  ),
  LuaTopic(
    id: 'lua-clo-module-private',
    chapter: 'closures',
    title: '闭包做模块私有状态',
    summary: '用工厂函数返回接口表，把状态完全藏在闭包里。',
    objective: '能写出带私有状态、可创建多实例的模块。',
    level: 'advanced',
    concepts: ['模块', '私有状态', '多实例'],
    explain:
        '与「返回一张带方法的表」相比，闭包方案里状态不是表的字段，'
        '外部拿不到也无法篡改，只能走暴露的方法。'
        '需要多个互不干扰的实例时，这种写法特别合适。',
    code: r'''local function newStore()
  local items = {}
  local reads, writes = 0, 0

  return {
    set = function(key, value)
      writes = writes + 1
      items[key] = value
    end,
    get = function(key)
      reads = reads + 1
      return items[key]
    end,
    stats = function()
      return reads, writes
    end,
  }
end

local store = newStore()
store.set("a", 1)
store.set("b", 2)
print(store.get("a"), store.get("b"), store.get("missing"))

local reads, writes = store.stats()
print(reads, writes)

local other = newStore()
print(other.get("a"))
local otherReads = other.stats()
print(otherReads)
''',
    output: '1\t2\tnil\n3\t2\nnil\n1\n',
    exercises: [
      LuaExercise(
        prompt: '给 store 增加 keys 方法返回排序后的键。',
        hint: '在闭包里访问 items。',
        answer:
            'keys = function() local out = {}; for k in pairs(items) do out[#out+1] = k end; table.sort(out); return out end',
      ),
      LuaExercise(
        prompt: '为什么外部无法直接读 items？',
        hint: '它不是返回表的字段。',
        answer: '因为 items 只存在于闭包中，返回的表里没有任何引用指向它。',
      ),
    ],
    pitfalls: ['闭包方案下每个实例都有独立函数，实例很多时内存开销更高。'],
  ),
];
