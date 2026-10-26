import 'lua_topic.dart';

/// 第十五章：math 库。
const List<LuaTopic> topicsMath = [
  LuaTopic(
    id: 'lua-math-floor-ceil',
    chapter: 'math',
    title: 'floor 与 ceil 取整',
    summary: 'floor 向负无穷取整，ceil 向正无穷取整，负数方向不同。',
    objective: '能预测负数取整的方向，并知道结果类型可能变化。',
    level: 'beginner',
    concepts: ['math.floor', 'math.ceil', '取整'],
    explain:
        'floor 取不大于参数的最大整数，ceil 取不小于参数的最小整数。'
        '负数最容易出错：floor(-1.2) 是 -2，ceil(-1.2) 是 -1。'
        '参数是整数值浮点时，Lua 5.4 会返回整数。',
    code: r'''print(math.floor(1.9), math.ceil(1.1))
print(math.floor(-1.9), math.ceil(-1.9))
print(math.floor(5), math.ceil(5))
print(math.floor(5.0), math.type(math.floor(5.0)))
print(math.type(math.floor(1.5)))
print(math.floor(-0.5))
''',
    output: '1\t2\n-2\t-1\n5\t5\n5\tinteger\ninteger\n-1\n',
    exercises: [
      LuaExercise(
        prompt: '把 3.7 分别向两个方向取整并输出。',
        hint: 'floor 和 ceil。',
        answer: 'print(math.floor(3.7), math.ceil(3.7))  -- 3 4',
      ),
      LuaExercise(
        prompt: '为什么 floor(-1.2) 不是 -1？',
        hint: '「向下」是数轴方向。',
        answer: '因为 -2 比 -1.2 更小，向下取整朝负无穷方向走。',
      ),
    ],
    pitfalls: ['把取整理解成「去掉小数」会算错负数。'],
  ),
  LuaTopic(
    id: 'lua-math-abs-max-min',
    chapter: 'math',
    title: 'abs / max / min',
    summary: '取绝对值、多个值中的最大值与最小值。',
    objective: '能用 max/min 一次比较多个参数，并注意空参数会报错。',
    level: 'beginner',
    concepts: ['math.abs', 'math.max', 'math.min'],
    explain:
        'abs 返回绝对值，整数返回整数，浮点返回浮点。'
        'max 和 min 可以接收任意多个参数，返回其中最大/最小的一个。'
        '只传一个参数时直接返回它；不传参数会报错。',
    code: r'''print(math.abs(-7), math.abs(7))
print(math.abs(-7.5), math.type(math.abs(-7)))
print(math.max(3, 9, 2))
print(math.min(3, 9, 2))
print(math.max(-1))
print(math.max(1, 1.0), math.type(math.max(1, 1.0)))
print(math.max(1.0, 1), math.type(math.max(1.0, 1)))

local values = { 4, 8, 1, 9 }
print(math.max(table.unpack(values)))
print(pcall(math.max))
''',
    output:
        '7\t7\n7.5\tinteger\n9\n2\n-1\n1\tinteger\n1.0\tfloat\n9\n'
        'false\tbad argument #1 to \'math.max\' (value expected)\n',
    exercises: [
      LuaExercise(
        prompt: '求一组数里的最小值和最大值。',
        hint: 'unpack 后传给 min/max。',
        answer:
            'print(math.min(table.unpack(values)), math.max(table.unpack(values)))',
      ),
      LuaExercise(
        prompt: 'max(1, 1.0) 返回整数还是浮点？',
        hint: '看输出和 math.type。',
        answer: '返回 1（整数），因为两者数值相等时 max 保留先遇到的那个；把参数顺序换成 (1.0, 1) 才得到 1.0。',
      ),
    ],
    pitfalls: ['空参数调用 max/min 会报错。', '整数与浮点混合时返回类型取决于具体值，断言前先确认。'],
  ),
  LuaTopic(
    id: 'lua-math-fmod-modf',
    chapter: 'math',
    title: 'fmod 与 modf',
    summary: 'fmod 是截断取模，modf 把整数部分和小数部分拆开。',
    objective: '能区分 % 与 fmod 的负数行为，并用 modf 拆分浮点。',
    level: 'intermediate',
    concepts: ['math.fmod', 'math.modf', '取模差异'],
    explain:
        'math.fmod(a, b) 的符号跟被除数 a 一致，和 C 的 fmod 相同；'
        '而 % 的符号跟除数 b 一致。'
        'math.modf(x) 返回两个值：向零取整的整数部分和小数部分。',
    code: r'''print(7 % 3, math.fmod(7, 3))
print(-7 % 3, math.fmod(-7, 3))
print(7 % -3, math.fmod(7, -3))

print(math.modf(3.7))
print(math.modf(-3.7))
print(math.modf(5))

local integer, fraction = math.modf(9.25)
print(integer, fraction)
print(math.type(integer), math.type(fraction))
''',
    output:
        '1\t1\n2\t-1\n-2\t1\n3\t0.7\n-3\t-0.7\n5\t0.0\n'
        '9\t0.25\ninteger\tfloat\n',
    exercises: [
      LuaExercise(
        prompt: '用 modf 判断一个数是否整数。',
        hint: '看小数部分是否为 0。',
        answer:
            'local _, fraction = math.modf(value)\nlocal isInteger = fraction == 0.0',
      ),
      LuaExercise(
        prompt: '为什么 fmod(-7, 3) 是 -1 而 -7 % 3 是 2？',
        hint: '一个跟被除数，一个跟除数。',
        answer: 'fmod 保留被除数的符号，% 保留除数的符号，这是两种不同的取模定义。',
      ),
    ],
    pitfalls: ['fmod 在 5.4 里对整数参数返回整数，不要假设一定是浮点。', '两个取模函数不要混用，否则负数结果对不上。'],
  ),
  LuaTopic(
    id: 'lua-math-sqrt-log',
    chapter: 'math',
    title: 'sqrt / exp / log',
    summary: '开方、指数与对数，全部返回浮点。',
    objective: '能用 sqrt 与 log 做几何和指数计算，并知道 log 的底数参数。',
    level: 'intermediate',
    concepts: ['math.sqrt', 'math.log', 'math.exp'],
    explain:
        'sqrt(x) 求平方根，exp(x) 求 e 的 x 次方，log(x) 是自然对数。'
        'log 可以带第二个参数表示底数，例如 log(8, 2) 是 3。'
        '这些函数都返回浮点，即使结果是整数值。',
    code: r'''print(math.sqrt(16))
print(math.sqrt(2))
print(math.exp(0), math.exp(1))
print(math.log(1))
print(math.log(8, 2))
print(math.log(100, 10))
print(math.type(math.sqrt(16)))

local a, b = 3, 4
print(math.sqrt(a * a + b * b))
''',
    output:
        '4.0\n1.4142135623731\n1.0\t2.718281828459\n0.0\n3.0\n2.0\n'
        'float\n5.0\n',
    exercises: [
      LuaExercise(
        prompt: '用 sqrt 求 2 的平方根并保留 4 位小数。',
        hint: 'string.format("%.4f")。',
        answer: 'print(string.format("%.4f", math.sqrt(2)))  -- 1.4142',
      ),
      LuaExercise(
        prompt: 'log(8, 2) 为什么等于 3？',
        hint: '对数的定义。',
        answer: '因为 2 的 3 次方是 8，log 的第二个参数是底数。',
      ),
    ],
    pitfalls: ['sqrt 对负数返回 nan（不同平台打印不同），不要用于可断言的输出。', 'log 的底数是第二个参数，不是第一个。'],
  ),
  LuaTopic(
    id: 'lua-math-pi-trig',
    chapter: 'math',
    title: 'pi 与三角函数',
    summary: '用 math.pi 和 sin/cos/atan 做角度计算。',
    objective: '能用 pi 换算角度弧度，并知道三角函数的返回值范围。',
    level: 'intermediate',
    concepts: ['math.pi', 'sin', 'atan'],
    explain:
        'math.pi 是圆周率常量。'
        'sin/cos/tan 接收弧度，返回值是浮点。'
        'atan(y, x) 可以同时接收两个参数表示象限，比 atan(y/x) 更安全。'
        '把角度转弧度用 degree * math.pi / 180。',
    code: r'''print(math.pi)
print(math.sin(0), math.cos(0))
print(math.sin(math.pi / 2))
print(math.atan(1, 1) * 4)

local degrees = 60
local radians = degrees * math.pi / 180
print(string.format("%.4f", math.sin(radians)))
print(string.format("%.2f", math.deg(math.pi)))
''',
    output: '3.1415926535898\n0.0\t1.0\n1.0\n3.1415926535898\n0.8660\n180.00\n',
    exercises: [
      LuaExercise(
        prompt: '把 90 度转成弧度并求 sin。',
        hint: '先乘 pi/180。',
        answer: 'print(math.sin(90 * math.pi / 180))  -- 1.0',
      ),
      LuaExercise(
        prompt: '为什么 atan 要传两个参数？',
        hint: '想想 y/x 丢失的信息。',
        answer: '两参数形式能正确区分四个象限，单参数只能得到 -pi/2 到 pi/2。',
      ),
    ],
    pitfalls: ['三角函数接收弧度，直接传角度会得到错误结果。', 'sin(pi) 不是精确的 0，浮点比较要用容差。'],
  ),
  LuaTopic(
    id: 'lua-math-integer-limits',
    chapter: 'math',
    title: '整数边界与 math.type',
    summary: '用 maxinteger/mininteger 检查边界，用 math.type 判断子类型。',
    objective: '能在运算前判断溢出风险，并区分整数与浮点。',
    level: 'intermediate',
    concepts: ['maxinteger', 'mininteger', 'math.type'],
    explain:
        '64 位整数的范围是 math.mininteger 到 math.maxinteger。'
        'math.type 返回 "integer"、"float" 或 nil（非数字）。'
        '边界判断要在运算之前做，因为溢出是静默回绕的。',
    code: r'''print(math.maxinteger)
print(math.mininteger)
print(math.type(1), math.type(1.0), math.type("1"))
print(math.type(2 ^ 53))
print(math.type(2 ^ 53 // 1))
print(math.type(math.maxinteger // 1))

local function fitsInteger(value)
  return math.type(value) == "integer"
end
print(fitsInteger(math.maxinteger))
print(fitsInteger(math.maxinteger + 0.0))

print(math.maxinteger + 1 == math.mininteger)
''',
    output:
        '9223372036854775807\n-9223372036854775808\ninteger\tfloat\tnil\n'
        'float\nfloat\ninteger\ntrue\nfalse\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '判断一个数是否能无损转换成 Lua 整数。',
        hint: 'math.tointeger 同时检查范围与整数值。',
        answer: 'local fits = math.tointeger(value) ~= nil',
      ),
      LuaExercise(
        prompt: 'math.type("1") 返回什么？',
        hint: '字符串不是数字。',
        answer: 'nil，因为 math.type 只接受数字，其他类型返回 nil。',
      ),
    ],
    pitfalls: ['math.type 对字符串返回 nil，不会抛错，容易漏判。', '整数溢出不会报错，边界判断要提前做。'],
  ),
  LuaTopic(
    id: 'lua-math-ult',
    chapter: 'math',
    title: 'math.ult 无符号比较',
    summary: 'ult 把整数当成无符号数比较，处理位模式时很有用。',
    objective: '能用 ult 做无符号比较，并理解负数在无符号视角下的值。',
    level: 'advanced',
    concepts: ['math.ult', '无符号', '位模式'],
    explain:
        'math.ult(a, b) 把两个整数按无符号 64 位解释后比较。'
        '因此负数会被当成很大的正数：-1 的无符号值是 2^64-1。'
        '做位运算、哈希、二进制协议解析时会用到这种视角。',
    code: r'''print(math.ult(1, 2))
print(math.ult(2, 1))
print(math.ult(-1, 1))
print(math.ult(1, -1))
print(-1 & 0xFF)

local function unsignedHex(value)
  return string.format("%016X", value)
end
print(unsignedHex(-1))
print(unsignedHex(255))
''',
    output:
        'true\nfalse\nfalse\ntrue\n255\nFFFFFFFFFFFFFFFF\n00000000000000FF\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 math.ult(-1, 1) 是 false？',
        hint: '-1 的无符号值最大。',
        answer: '因为 -1 的无符号解释是 2^64-1，比 1 大得多。',
      ),
      LuaExercise(
        prompt: '用 ult 判断一个值是否落在无符号 32 位范围内。',
        hint: '在本运行时的 64 位整数配置下，与 0x100000000 比较。',
        answer:
            'local fits = math.ult(value, 0x100000000)  -- value 须可转换为整数；无符号比较已经排除负数位模式。',
      ),
    ],
    pitfalls: ['ult 要求参数能无损转为整数；1.0 可以接受，1.5 会报错。'],
  ),
  LuaTopic(
    id: 'lua-math-random-range',
    chapter: 'math',
    title: 'math.random 与范围控制',
    summary: '区分 [0,1) 浮点、闭区间整数和 random(0) 的全位随机整数。',
    objective: '能用 random(m, n) 生成区间随机数，并知道可复现的做法。',
    level: 'beginner',
    concepts: ['math.random', '闭区间', '随机种子'],
    explain:
        'math.random() 返回 [0,1) 的浮点；n 为正整数时 math.random(n) 返回 1..n 的整数；'
        'math.random(m, n) 返回 m..n 的整数，两端都包含。'
        'Lua 5.4 的 math.random(0) 是特殊形式，返回所有位均随机的整数，可能为负。'
        'randomseed 可以固定种子，但具体序列属于实现细节，'
        '教学示例应只断言「落在范围内」而不是具体数值。',
    code: r'''math.randomseed(20261022)

local value = math.random()
print(value >= 0 and value < 1)

local dice = math.random(6)
print(dice >= 1 and dice <= 6)

local inRange = true
for _ = 1, 100 do
  local n = math.random(10, 20)
  if n < 10 or n > 20 then inRange = false end
end
print(inRange)

print(math.type(math.random(1, 3)))
print(math.random(5, 5))
print(math.type(math.random(0)))
''',
    output: 'true\ntrue\ntrue\ninteger\n5\ninteger\n',
    exercises: [
      LuaExercise(
        prompt: '生成 1..100 的随机整数并判断是否偶数。',
        hint: 'random(100)。',
        answer: 'local n = math.random(100)\nprint(n, n % 2 == 0)',
      ),
      LuaExercise(
        prompt: '为什么不要把 random 的具体结果写进期望输出？',
        hint: '想想实现差异。',
        answer: '因为随机序列依赖具体实现和种子，不同版本或平台可能不同，断言会失效。',
      ),
    ],
    pitfalls: [
      'random(m, n) 两端都包含，和很多语言的半开区间不同。',
      'random(0) 不表示空区间；m > n 的 random(m, n) 才是非法空区间。',
    ],
  ),
  LuaTopic(
    id: 'lua-math-huge-inf',
    chapter: 'math',
    title: 'huge 与无穷大',
    summary: 'math.huge 表示正无穷，可用于初始化最小值。',
    objective: '能用 huge 初始化极值累加器，并避免打印 inf 文本。',
    level: 'intermediate',
    concepts: ['math.huge', '无穷', '初始化'],
    explain:
        'math.huge 是浮点正无穷，-math.huge 是负无穷。'
        '求最小值时用它初始化可以正确处理任意大的数据。'
        '注意：不同 C 运行时打印无穷的文本不同（inf 或 1.#INF），'
        '所以不要把它写进可断言的输出，改为比较判断。',
    code: r'''print(math.huge > 1e308)
print(-math.huge < -1e308)
print(math.huge == math.huge)
print(math.huge == math.huge + 1)

local numbers = { 5, 2, 9 }
local lowest = math.huge
for _, value in ipairs(numbers) do
  if value < lowest then lowest = value end
end
print(lowest)

print(1e400 == math.huge)
''',
    output: 'true\ntrue\ntrue\ntrue\n2\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '用 -math.huge 初始化最大值累加器。',
        hint: '比较时取更大者。',
        answer:
            'local highest = -math.huge\nfor _, v in ipairs(numbers) do if v > highest then highest = v end end',
      ),
      LuaExercise(
        prompt: '为什么 math.huge == math.huge + 1 是 true？',
        hint: '无穷加有限数还是无穷。',
        answer: '因为无穷大加任何有限数仍是无穷大，浮点里它们相等。',
      ),
    ],
    pitfalls: ['inf 的打印形式与平台相关，不要写进期望输出。', 'inf - inf 得到 nan，nan 与自身不相等。'],
  ),
  LuaTopic(
    id: 'lua-math-round-custom',
    chapter: 'math',
    title: '自定义四舍五入',
    summary: '用 floor(x + 0.5) 实现半上舍入，并处理负数。',
    objective: '能实现可控方向的舍入，并说明它与 string.format 的区别。',
    level: 'intermediate',
    concepts: ['舍入', 'floor', '边界'],
    explain:
        '常见写法 math.floor(x + 0.5) 对正数是「四舍五入」，'
        '但对负数是朝零方向舍入，行为不对称。'
        '要对称处理，先取符号再对绝对值舍入。'
        '格式化里的 %.0f 由 C 库决定，和这里的手写规则可能不同。',
    code: r'''local function round(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return -math.floor(-value + 0.5)
end

print(round(2.4), round(2.5), round(2.6))
print(round(-2.4), round(-2.5), round(-2.6))

local function roundTo(value, digits)
  local scale = 10 ^ digits
  return round(value * scale) / scale
end

print(roundTo(3.14159, 2))
print(roundTo(1.005, 2))
print(roundTo(-1.005, 2))
''',
    output: '2\t3\t3\n-2\t-3\t-3\n3.14\n1.0\n-1.0\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 round(1.005, 2) 不是 1.01？',
        hint: '想想 1.005 的二进制表示。',
        answer: '因为 1.005 在浮点里略小于真实值，乘 100 后落在 100.4999…，舍入得到 1.0。',
      ),
      LuaExercise(
        prompt: '实现向下舍入到两位小数。',
        hint: '用 floor 而不是 round。',
        answer:
            'local function floorTo(v, d) local s = 10 ^ d; return math.floor(v * s) / s end',
      ),
    ],
    pitfalls: ['浮点误差会让「恰好一半」的舍入结果不可预期。', 'floor(x + 0.5) 对负数不是对称的四舍五入。'],
  ),
  LuaTopic(
    id: 'lua-math-distance',
    chapter: 'math',
    title: '距离与百分比计算',
    summary: '把 sqrt、abs、除法组合成常见的几何与统计计算。',
    objective: '能计算两点距离、百分比与变化率，并格式化输出。',
    level: 'intermediate',
    concepts: ['距离', '百分比', '格式化'],
    explain:
        '两点距离是 sqrt(dx^2 + dy^2)。'
        '百分比是 part / total * 100，输出时用 %.1f 控制精度。'
        '变化率要处理除数为 0 的情况，否则会得到 inf 或 nan。',
    code: r'''local function distance(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

print(distance(0, 0, 3, 4))
print(string.format("%.2f", distance(1, 1, 4, 5)))

local function percent(part, total)
  if total == 0 then return nil, "总量为 0" end
  return part / total * 100, nil
end

print(string.format("%.1f%%", percent(3, 8)))
print(percent(3, 0))

local before, after = 80, 100
print(string.format("增长 %.1f%%", (after - before) / before * 100))
print(string.format("下降 %.1f%%", (before - after) / after * 100))
''',
    output: '5.0\n5.00\n37.5%\nnil\t总量为 0\n增长 25.0%\n下降 -20.0%\n',
    exercises: [
      LuaExercise(
        prompt: '计算 (0,0) 到 (1,1) 的距离并保留 3 位小数。',
        hint: 'sqrt(2)。',
        answer: 'print(string.format("%.3f", distance(0, 0, 1, 1)))  -- 1.414',
      ),
      LuaExercise(
        prompt: '为什么百分比函数要处理总量为 0？',
        hint: '除零结果。',
        answer: '否则会得到 inf 或 nan，后续格式化和比较都会出问题。',
      ),
    ],
    pitfalls: ['除数为 0 时浮点得到 inf，不会抛错，容易一路传下去。', '百分比基数不同（占比 vs 变化率）不能混用。'],
  ),
];
