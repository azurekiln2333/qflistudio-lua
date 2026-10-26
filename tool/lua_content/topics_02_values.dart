import 'lua_topic.dart';

/// 第二章：值、变量与作用域。
const List<LuaTopic> topicsValues = [
  LuaTopic(
    id: 'lua-values-nil',
    chapter: 'values',
    title: 'nil：表示「没有值」',
    summary: '未赋值的变量、表里不存在的键，读出来都是 nil。',
    objective: '能用 nil 判断字段是否存在，并把它和 false 区分开。',
    level: 'beginner',
    concepts: ['nil', 'type', '存在性判断'],
    explain:
        'nil 是 Lua 的第八种类型之外的特殊值，含义是「没有」。'
        'local 声明但未赋值、表里没有的键、函数没有返回值，读出来都是 nil。'
        'nil 与 false 不同：nil 表示缺失，false 表示明确取值为假。判断字段存在要用 ~= nil。',
    code: r'''local missing                 -- 只声明不赋值
print(type(missing))
print(missing == nil)

local config = { debug = true }
print(tostring(config.debug), tostring(config.verbose))
print(type(config.verbose))

if config.verbose ~= nil then
  print("有 verbose 配置")
else
  print("没有 verbose 配置")
end
''',
    output: 'nil\ntrue\ntrue\tnil\nnil\n没有 verbose 配置\n',
    exercises: [
      LuaExercise(
        prompt: '给 config 加上 verbose = false，再判断一次。',
        hint: 'false 不等于 nil，条件仍然成立。',
        answer:
            'local config = { debug = true, verbose = false }，输出变为「有 verbose 配置」，但它本身的取值是 false。',
      ),
      LuaExercise(
        prompt: '为什么不能用 if config.verbose then 判断「配置是否存在」？',
        hint: '想想 false 在条件里的行为。',
        answer: 'false 在条件里同样是假，会把「明确设置为 false」误判成「没有设置」，所以存在性判断必须写 ~= nil。',
      ),
    ],
    pitfalls: ['把 nil 写进表等于删除这个键。', 'nil 不能参与算术和拼接，需要先判断或给默认值。'],
  ),
  LuaTopic(
    id: 'lua-values-boolean',
    chapter: 'values',
    title: '布尔值与比较结果',
    summary: 'true/false 只有两个值，比较和逻辑运算都返回它们。',
    objective: '能区分布尔值和「真值」,知道 Lua 只有 nil 与 false 为假。',
    level: 'beginner',
    concepts: ['boolean', '比较运算', 'not'],
    explain:
        'Lua 的布尔类型只有 true 和 false 两个字面量。'
        '比较运算（== ~= < <= > >=）产生布尔值，not 取反。'
        '在条件里，除 nil 和 false 之外的一切值都算真，包括 0 和空字符串——这一点和 C、Python 都不同。',
    code: r'''local flag = true
local off = false
print(flag, not flag)
print(tostring(off), type(off))

print(1 == 1, 1 == 2)
print(#"" == 0)

if 0 then print("0 也是真") end
if "" then print("空字符串也是真") end
if nil then print("不会执行") else print("nil 是假") end
''',
    output:
        'true\tfalse\nfalse\tboolean\ntrue\tfalse\ntrue\n0 也是真\n'
        '空字符串也是真\nnil 是假\n',
    exercises: [
      LuaExercise(
        prompt: '在 Lua 里判断「字符串非空」应该怎么写？',
        hint: 'if s then 不够，因为空字符串也是真。',
        answer: 'if s ~= nil and s ~= "" then ... end',
      ),
      LuaExercise(
        prompt: 'print(not nil, not 0, not "") 会输出什么？',
        hint: '0 和空字符串都是真。',
        answer: 'true\tfalse\tfalse',
      ),
    ],
    pitfalls: [
      'if 0 then 在 Lua 里是真，和 C 语言相反。',
      'not 的优先级高于比较，写 not a == b 会先算 not a。',
    ],
  ),
  LuaTopic(
    id: 'lua-values-local-scope',
    chapter: 'values',
    title: 'local 与作用域边界',
    summary: 'local 声明的变量只在它所在的块里可见。',
    objective: '能画出变量的可见范围，并在块结束时让变量自然消失。',
    level: 'beginner',
    concepts: ['local', '作用域', 'do 块'],
    explain:
        'local 把变量绑定到当前块（chunk、函数体、do...end、循环体）。'
        '块执行完，这个局部变量就不可见了，也不会污染全局环境。'
        '在需要临时变量的地方用 do...end 包一层，可以让变量的生命周期和用途保持一致。',
    code: r'''local name = "外层"

do
  local name = "内层"
  print(name)
end

print(name)

do
  local total = 0
  for i = 1, 4 do
    total = total + i
  end
  print("临时合计：" .. total)
end

print("全局里没有 total：" .. tostring(total))
''',
    output: '内层\n外层\n临时合计：10\n全局里没有 total：nil\n',
    exercises: [
      LuaExercise(
        prompt: '如果把 do...end 里的 local total 去掉 local，最后一行会输出什么？',
        hint: '那它就成了全局变量。',
        answer: '输出「全局里没有 total：10」，因为 total 变成了全局变量。',
      ),
      LuaExercise(
        prompt: '为什么推荐每个变量都加 local？',
        hint: '想想全局表和误拼写。',
        answer: 'local 限定变量作用域，避免无意污染全局；拼错另一标识符仍可能读到 nil 或写出全局变量，不能代替静态诊断。',
      ),
    ],
    pitfalls: [
      '内层块重复用同名 local 会遮蔽外层，容易误以为改了外层变量。',
      '循环体里用 local 声明的变量，每轮都是新的绑定。',
    ],
  ),
  LuaTopic(
    id: 'lua-values-global-g',
    chapter: 'values',
    title: '全局变量与 _G',
    summary: '不加 local 就是全局变量，能通过 _G 表读写。',
    objective: '知道全局变量存放在 _G 表里，并能有意识地避免使用。',
    level: 'beginner',
    concepts: ['全局变量', '_G', '命名污染'],
    explain:
        'Lua 的全局变量其实是全局表 _G 里的字段：counter = 1 等价于 _G.counter = 1。'
        '因此可以像操作普通表那样遍历或检查全局变量。'
        '工程代码里应尽量不写全局变量，避免不同模块互相覆盖。',
    code: r'''counter = 1
print(counter, _G.counter)

_G.counter = counter + 1
print(counter)

local safe = 5
print(_G.safe == nil)

_G.temp = "调用后清理"
print(_G.temp)
_G.temp = nil
print(_G.temp)
''',
    output: '1\t1\n2\ntrue\n调用后清理\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '用 _G 判断某个全局函数是否存在。',
        hint: '_G.print 就是 print 本身。',
        answer: 'if _G.print then print("print 可用") end',
      ),
      LuaExercise(
        prompt: '把 counter = 1 改成 local counter = 1 后，_G.counter 是什么？',
        hint: 'local 不会写进全局表。',
        answer: '_G.counter 是 nil，因为局部变量不存放在 _G 里。',
      ),
    ],
    pitfalls: ['拼错局部变量名会静默创建全局变量，很难排查。', '给 _G 添加临时字段后记得置 nil 清理。'],
  ),
  LuaTopic(
    id: 'lua-values-multiple-assign',
    chapter: 'values',
    title: '多重赋值与交换',
    summary: '一次给多个变量赋值，右边先求值再统一分配。',
    objective: '能用多重赋值交换变量、处理缺省和多余值。',
    level: 'beginner',
    concepts: ['多重赋值', '交换', '缺省值'],
    explain:
        'a, b = 1, 2 会先把右边的表达式全部求值，再依次赋给左边。'
        '因此 a, b = b, a 可以在没有临时变量的情况下完成交换。'
        '右边的值少于左边时，多出来的变量得到 nil；多于左边时，多余的值被丢弃。',
    code: r'''local a, b = 1, 2
print(a, b)

a, b = b, a
print(a, b)

local x, y, z = 7
print(x, y, z)

local p, q = 1, 2, 3
print(p, q)

local first, second = (function() return 10, 20 end)()
print(first + second)
''',
    output: '1\t2\n2\t1\n7\tnil\tnil\n1\t2\n30\n',
    exercises: [
      LuaExercise(
        prompt: '用多重赋值同时把 a 加 1、b 减 1。',
        hint: '右边可以用当前值做运算。',
        answer: 'a, b = a + 1, b - 1',
      ),
      LuaExercise(
        prompt: 'local x, y = 1 之后 y 是什么？',
        hint: '右边只有一项。',
        answer: 'y 是 nil，值不够时左侧多余的变量补 nil。',
      ),
    ],
    pitfalls: ['右边先求值这一点很重要：a, b = b, a 才成立。', '别把赋值和比较混在一起，a == b 不是赋值。'],
  ),
  LuaTopic(
    id: 'lua-values-type',
    chapter: 'values',
    title: 'type：运行时判断类型',
    summary: 'type 返回八种类型名之一，是写健壮代码的第一步。',
    objective: '能用 type 判定参数类型并按类型分支处理。',
    level: 'beginner',
    concepts: ['type', '类型名', '参数校验'],
    explain:
        'type(x) 返回字符串：nil、boolean、number、string、table、function、thread、userdata。'
        'Lua 不区分整数和浮点（都叫 number），要细分请用 math.type。'
        '函数入口处做一次 type 校验，能把调用方的错误尽早变成可读的报错。',
    code: r'''print(type(nil), type(true), type(42), type(4.5))
print(type("text"), type({}), type(print))

local function describe(value)
  local kind = type(value)
  if kind == "number" then
    return "数字（" .. math.type(value) .. "）"
  end
  return kind
end

print(describe(7))
print(describe(7.0))
print(describe("7"))
''',
    output:
        'nil\tboolean\tnumber\tnumber\nstring\ttable\tfunction\n'
        '数字（integer）\n数字（float）\nstring\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数 safeAdd，两个参数不是 number 就报错。',
        hint: '用 type(x) ~= "number" 判断。',
        answer:
            'local function safeAdd(a, b)\n  assert(type(a) == "number" and type(b) == "number", "safeAdd 需要两个数字")\n  return a + b\nend',
      ),
      LuaExercise(
        prompt: 'type 能把 3 和 3.0 区分开吗？',
        hint: '想想 math.type。',
        answer: '不能，两者都是 number；用 math.type 才能区分 integer 和 float。',
      ),
    ],
    pitfalls: ['type 返回的是字符串，比较时要加引号。', '协程的类型名是 thread，不是 coroutine。'],
  ),
  LuaTopic(
    id: 'lua-values-tostring-tonumber',
    chapter: 'values',
    title: 'tostring 与 tonumber 转换',
    summary: '在文本和数字之间显式转换，并处理转换失败。',
    objective: '能用 tonumber 解析输入并用 nil 表示失败，用 tostring 拼提示。',
    level: 'beginner',
    concepts: ['tostring', 'tonumber', '解析失败'],
    explain:
        'tostring 把任意值转成字符串，tonumber 把字符串转成数字，失败返回 nil。'
        'tonumber 的第二个参数可以指定进制（2~36），用来解析十六进制或二进制文本。'
        '「失败返回 nil」意味着调用方必须显式判断，不能假设一定有值。',
    code: r'''print(tostring(12), tostring(12.0), tostring("12"))
print(tonumber("12"), tonumber("3.5"), tonumber("abc"))
print(tonumber("ff", 16), tonumber("101", 2))
print(tonumber("  42  "))

local text = "12"
if tonumber(text) then
  print("可以当作数字使用：" .. (tonumber(text) + 1))
else
  print("不是数字")
end
''',
    output: '12\t12.0\t12\n12\t3.5\tnil\n255\t5\n42\n可以当作数字使用：13\n',
    exercises: [
      LuaExercise(
        prompt: '把 "abc" 安全地转成数字，失败时输出 0。',
        hint: '用 or 给默认值。',
        answer: 'local value = tonumber("abc") or 0\nprint(value)',
      ),
      LuaExercise(
        prompt: 'tonumber("0x1A") 的结果是几？',
        hint: '前缀 0x 会被自动识别。',
        answer: '26',
      ),
    ],
    pitfalls: [
      'tonumber 成功返回 0 时也是真，所以用 if tonumber(x) 判断在某些写法下会误判；判断失败请写 ~= nil。',
      'tostring 不是格式化工具，保留小数位要用 string.format。',
    ],
  ),
  LuaTopic(
    id: 'lua-values-coercion',
    chapter: 'values',
    title: '隐式转换：算术与拼接',
    summary: '算术会把数字字符串转成数字，拼接会把数字转成文本。',
    objective: '知道哪些运算会隐式转换，并避免在接口边界依赖它。',
    level: 'intermediate',
    concepts: ['隐式转换', '算术运算', '拼接'],
    explain:
        '在算术运算里，能转成数字的字符串会被自动转换："10" + 5 得到 15。'
        '在拼接运算里，数字会被自动转成文本：42 .. "" 得到 "42"。'
        '但 == 不做转换，"10" == 10 是 false。依赖隐式转换会掩盖数据来源问题，'
        '在模块边界上建议显式 tonumber/tostring。',
    code: r'''print("10" + 5)
print("3" * "4")
print(7 .. "")
print("结果：" .. 42)
print(10 / 4, 10 // 4)
print("10" == 10)

local ok, err = pcall(function() return "abc" + 1 end)
print(ok, err ~= nil)
''',
    output: '15\n12\n7\n结果：42\n2.5\t2\nfalse\nfalse\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 "10" + 0 能工作，而 "10" + " 0 " 的结果是什么？',
        hint: 'tonumber 允许前后空白。',
        answer: '结果都是 10，前后空白允许；但 "10a" 会报错。',
      ),
      LuaExercise(
        prompt: '把拼接的结果再转回数字应该怎么写？',
        hint: '拼接得到的是字符串。',
        answer: 'local n = tonumber(7 .. "")  -- 得到数字 7',
      ),
    ],
    pitfalls: ['== 不转换类型，"1" == 1 为 false。', '非数字字符串参与算术会抛错，而不是返回 nil。'],
  ),
  LuaTopic(
    id: 'lua-values-do-block',
    chapter: 'values',
    title: 'do...end 限定临时变量',
    summary: '用 do...end 把临时变量的生命周期收窄到需要的范围。',
    objective: '会在需要中间结果时用块包住，避免变量铺满整个函数。',
    level: 'beginner',
    concepts: ['do', '块', '生命周期'],
    explain:
        'do...end 创建一个新的块，块内声明的 local 在 end 处消失。'
        '把一次性的中间计算包进块里，函数顶层只保留真正需要的结果，'
        '读代码的人不用记一堆只用一次的变量名。',
    code: r'''local total = 0

do
  local step = 2
  total = total + step * 3
  print("块内 total = " .. total)
end

print("块外 total = " .. total)

do
  local doubled = total * 2
  print("再做一次翻倍：" .. doubled)
end

print("total 仍是 " .. total)
''',
    output: '块内 total = 6\n块外 total = 6\n再做一次翻倍：12\ntotal 仍是 6\n',
    exercises: [
      LuaExercise(
        prompt: '把 doubled 的计算放到块外，行为有区别吗？',
        hint: '考虑变量可见范围。',
        answer: '结果相同，但 doubled 会留在函数作用域里，容易被后续代码误用。',
      ),
      LuaExercise(
        prompt: '块内能不能重新声明同名的 total？',
        hint: 'local 可以遮蔽外层。',
        answer: '可以，do local total = 1 ... end 会遮蔽外层 total，块外仍是原值。',
      ),
    ],
    pitfalls: ['块结束时局部变量被销毁，块外访问会得到 nil。'],
  ),
  LuaTopic(
    id: 'lua-values-shadowing',
    chapter: 'values',
    title: '遮蔽：同名变量的优先级',
    summary: '内层同名 local 会遮蔽外层，闭包捕获的是定义时可见的那一层。',
    objective: '能判断一段代码里某个名字最终指向哪个变量。',
    level: 'intermediate',
    concepts: ['遮蔽', '闭包捕获', '同名变量'],
    explain:
        '从内向外查找名字，最先找到的就生效，这就是遮蔽（shadowing）。'
        '函数体里出现的名字在函数定义处就绑定了外层 local；之后外层变量被赋新值，'
        '函数看到的是新值（因为绑定的是变量本身，不是当时的快照）。'
        '内层再声明同名 local 只影响内层。',
    code: r'''local value = 10

local function readOuter()
  return value          -- 捕获外层那个 value
end

value = value + 5
print(readOuter())

do
  local value = 100
  print(value)
end

print(value)
''',
    output: '15\n100\n15\n',
    exercises: [
      LuaExercise(
        prompt: '如果在 readOuter 里写 local value = 1，最后的输出会变吗？',
        hint: '内层 local 遮蔽外层。',
        answer: '会变成 1，因为函数返回的是内层的 value。',
      ),
      LuaExercise(
        prompt: '为什么 readOuter 返回 15 而不是 10？',
        hint: '闭包捕获变量本身。',
        answer: '闭包绑定的是变量，调用时才读取，此时外层 value 已经是 15。',
      ),
    ],
    pitfalls: ['在函数里忘记 local 会意外写入全局变量，而不是遮蔽。', '同名参数也会遮蔽外层变量。'],
  ),
];
