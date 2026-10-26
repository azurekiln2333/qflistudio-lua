import 'lua_topic.dart';

/// 第二十一章：Lua 5.4 新特性。
const List<LuaTopic> topicsLua54 = [
  LuaTopic(
    id: 'lua54-integer-division',
    chapter: 'lua54',
    title: '整除运算符 //',
    summary: '// 向负无穷取整，整数除整数得到整数。',
    objective: '能预测 // 的结果类型与负数取整方向。',
    level: 'beginner',
    concepts: ['//', '取整', '类型'],
    explain:
        'a // b 是向下取整的除法，负数方向与截断不同。'
        '两个整数相除得到整数，任一为浮点则得到浮点。'
        '除以 0 对整数会报错，对浮点会得到无穷大。',
    code: r'''print(7 // 2, 7 / 2)
print(-7 // 2, -7 / 2)
print(7 // -2)
print(math.type(7 // 2), math.type(7.0 // 2))
print(7.5 // 2)

local ok, err = pcall(function() return 1 // 0 end)
print(ok, err ~= nil)
''',
    output: '3\t3.5\n-4\t-3.5\n-4\ninteger\tfloat\n3.0\nfalse\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '用 // 求平均值并向下取整。',
        hint: '(a + b) // 2。',
        answer: 'print((3 + 4) // 2)  -- 3',
      ),
      LuaExercise(
        prompt: '为什么 -7 // 2 是 -4 而不是 -3？',
        hint: '向下取整的方向。',
        answer: '因为 // 朝负无穷取整，-3.5 向下是 -4，而不是朝零截断成 -3。',
      ),
    ],
    pitfalls: [
      '两边为整数的 // 遇到除数 0 会抛错；/ 始终使用浮点除法，不能混为一谈。',
      '// 与 % 满足 a == (a // b) * b + (a % b)。',
    ],
  ),
  LuaTopic(
    id: 'lua54-bitwise',
    chapter: 'lua54',
    title: '位运算符',
    summary: '与、或、异或、取反和移位都在整数上工作。',
    objective: '能写出位掩码和标志位操作，并注意移位边界。',
    level: 'intermediate',
    concepts: ['&', '|', '~', '<<'],
    explain:
        'Lua 5.3 起支持位运算：& 与、| 或、~ 异或（一元时是取反）、<< 左移、>> 右移。'
        '操作数必须能无损转为整数；1.0 可以，2.9 会报错，不能用位运算隐式截断小数。'
        '移位超出 64 位时结果为 0。',
    code: r'''print(0xF0 & 0x0F)
print(0xF0 | 0x0F)
print(0xFF ~ 0x0F)
print(~0)
print(1 << 4)
print(256 >> 4)
print(1 << 64, 1 >> 64)

local flags = 0
flags = flags | 1
flags = flags | 4
print(flags, flags & 1, flags & 2)
print(flags ~ 1)
print(math.type(2 & 1))

-- 浮点没有精确的整数表示时会报错，不会静默截断
print(pcall(function() return 2.9 & 1 end) == false)
print(3.0 & 1)
''',
    output: '0\n255\n240\n-1\n16\n16\n0\t0\n5\t1\t0\n4\ninteger\ntrue\n1\n',
    exercises: [
      LuaExercise(
        prompt: '用位运算把 0 到 3 号位全部置 1。',
        hint: '(1 << 4) - 1。',
        answer: 'print((1 << 4) - 1)  -- 15',
      ),
      LuaExercise(
        prompt: '为什么 ~0 是 -1？',
        hint: '想想 64 位补码。',
        answer: '因为 0 的 64 位全 0，按位取反后全 1，作为有符号整数就是 -1。',
      ),
    ],
    pitfalls: [
      '浮点必须能精确表示成整数，否则报 number has no integer representation。',
      '移位数过大（≥64）结果是 0，不是回绕。',
    ],
  ),
  LuaTopic(
    id: 'lua54-goto',
    chapter: 'lua54',
    title: 'goto 与标签',
    summary: 'goto 跳到同一函数内的标签，可模拟 continue。',
    objective: '能用 goto 实现 continue 式的跳过，并遵守作用域限制。',
    level: 'intermediate',
    concepts: ['goto', '标签', '作用域'],
    explain:
        'goto label 会跳到同一函数里的 ::label::。'
        'Lua 没有 continue，常见替代是在循环体末尾放 ::continue:: 并 goto 过去。'
        '不能跳进局部变量的作用域，否则编译报错。',
    code: r'''local output = {}
for i = 1, 6 do
  if i % 2 == 0 then goto continue end
  output[#output + 1] = i
  ::continue::
end
print(table.concat(output, ","))

local total = 0
local i = 0
::top::
i = i + 1
total = total + i
if i < 4 then goto top end
print(total, i)

local ok, err = load("local x = 1; goto skip; local y = 2; ::skip::; return y")
print(ok == nil, err ~= nil)
print(ok == nil and err:find("jumps into the scope") ~= nil)
''',
    output: '1,3,5\n10\t4\ntrue\ttrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '用 goto 跳过能被 3 整除的数。',
        hint: '在循环末尾放标签。',
        answer:
            'for i = 1, 9 do if i % 3 == 0 then goto continue end io.write(i, " ") ::continue:: end',
      ),
      LuaExercise(
        prompt: '为什么不能跳进局部变量的作用域？',
        hint: '想想变量是否已初始化。',
        answer: '因为跳过声明会让变量处于未定义状态，Lua 在编译期就禁止这种跳转。',
      ),
    ],
    pitfalls: ['标签名与变量名不冲突，但同一函数内不能重名。', '滥用 goto 会破坏结构，优先用函数封装。'],
  ),
  LuaTopic(
    id: 'lua54-toclose',
    chapter: 'lua54',
    title: 'to-be-closed 变量',
    summary: '用 <close> 声明变量，离开作用域时自动调用 __close。',
    objective: '能用 <close> 自动释放资源，并知道关闭顺序。',
    level: 'advanced',
    concepts: ['<close>', '__close', '资源释放'],
    explain:
        'local f <close> = resource 会在离开作用域（正常返回或出错）时调用 __close。'
        '多个待关闭变量按声明的逆序关闭。'
        '这是 5.4 新增的确定性清理机制，比依赖 GC 更可靠。',
    code: r'''local log = {}

local function newHandle(name)
  return setmetatable({ name = name }, {
    __close = function(self, err)
      log[#log + 1] = self.name .. (err and ":err" or ":ok")
    end,
  })
end

local function scope()
  local first <close> = newHandle("first")
  local second <close> = newHandle("second")
  log[#log + 1] = "body"
  return "done"
end

print(scope())
print(table.concat(log, ","))

local function failing()
  local handle <close> = newHandle("fail")
  error("出错了")
end

local ok, err = pcall(failing)
print(ok, err ~= nil)
print(table.concat(log, ","))

local ok2, err2 = pcall(function()
  local bad <close> = 42
end)
print(ok2, err2 ~= nil)
''',
    output:
        'done\nbody,second:ok,first:ok\nfalse\ttrue\n'
        'body,second:ok,first:ok,fail:err\nfalse\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 <close> 比依赖 GC 可靠？',
        hint: '想想触发时机。',
        answer: '因为它在作用域结束时立即执行，不依赖垃圾回收的时间点，文件句柄不会长时间悬空。',
      ),
      LuaExercise(
        prompt: '__close 的第二个参数是什么？',
        hint: '出错时。',
        answer: '出错时的错误对象；正常离开作用域时是 nil。',
      ),
    ],
    pitfalls: [
      '<close> 的值必须是 nil、false 或带 __close 的对象。',
      '关闭顺序是逆序，有依赖关系时要考虑声明顺序。',
    ],
  ),
  LuaTopic(
    id: 'lua54-const',
    chapter: 'lua54',
    title: 'const 常量声明',
    summary: '用 <const> 声明不可重新赋值的局部变量。',
    objective: '能用 <const> 表达意图，并理解编译期常量的意义。',
    level: 'beginner',
    concepts: ['<const>', '常量', '编译期'],
    explain:
        'local x <const> = 10 之后不能再给 x 赋值，'
        '而且编译器可以把它当成常量做优化。'
        '常量必须在声明时初始化，且不能是可变的值（表内容仍可变）。',
    code: r'''local LIMIT <const> = 3
local NAME <const> = "lua"

print(LIMIT, NAME)
print(type(LIMIT))

local config <const> = { retries = 2 }
config.retries = 5
print(config.retries)

local ok, err = load("local x <const> = 1; x = 2")
print(ok == nil, err ~= nil)

local ok2, err2 = load("local y <const>; return y")
print(ok2 ~= nil)
print(ok2() == nil)

local ok3, err3 = load("local z <const> = 1; z = 2")
print(ok3 == nil)
print(err3 ~= nil)
''',
    output: '3\tlua\nnumber\n5\ntrue\ttrue\ntrue\ntrue\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '把 3.14 声明成常量并打印。',
        hint: 'local ... <const>。',
        answer: 'local PI <const> = 3.14\nprint(PI)',
      ),
      LuaExercise(
        prompt: '为什么 const 表的内容还能改？',
        hint: '想想 const 修饰的是什么。',
        answer: '因为 <const> 只禁止给变量重新赋值，表的内容不受限制。',
      ),
    ],
    pitfalls: [
      '<const> 必须紧跟变量名。',
      '对 const 变量赋值是编译错误，不是运行时错误。',
      '未初始化的 const 变量合法，值为 nil。',
    ],
  ),
  LuaTopic(
    id: 'lua54-load-integers',
    chapter: 'lua54',
    title: 'load 的模式与整数解析',
    summary: 'load 的第三个参数可以限制只接受文本或只接受二进制。',
    objective: '能用 "t"/"b" 模式控制加载来源，并理解默认行为。',
    level: 'advanced',
    concepts: ['load', '模式', '安全'],
    explain:
        'load(chunk, name, mode) 中 mode 可以是 "t"（只接受文本）、'
        '"b"（只接受预编译字节码）或 "bt"（默认，两者都接受）。'
        '只加载文本可以避免执行被篡改的字节码，是安全加固的一环。',
    code: r'''local source = "return 6 * 7"

local textChunk = load(source, "t-only", "t")
print(textChunk())

local binaryRejected = load(source, "b-only", "b")
print(binaryRejected == nil)

local defaultMode = load(source)
print(defaultMode())

local syntaxError = load("return 1 +")
print(syntaxError == nil)

local ok = load("return ...", "varargs")
print(ok(1, 2, 3))
print(type(load("return")) == "function")
''',
    output: '42\ntrue\n42\ntrue\n1\t2\t3\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '只允许加载文本源码。',
        hint: 'mode 参数。',
        answer: 'local f = load(source, "chunk", "t")',
      ),
      LuaExercise(
        prompt: '为什么生产环境默认接受字节码有风险？',
        hint: '想想字节码能做什么。',
        answer: '因为字节码可以携带恶意指令，且无法像文本那样人工审计，限制成 "t" 更安全。',
      ),
    ],
    pitfalls: ['load 失败返回 nil 加错误消息，不抛异常。', 'load 加载的函数默认只有 _ENV，不会继承调用方局部变量。'],
  ),
  LuaTopic(
    id: 'lua54-string-hex-float',
    chapter: 'lua54',
    title: '十六进制浮点字面量',
    summary: '0x1p4 这类写法用二进制指数表示浮点。',
    objective: '能读懂十六进制浮点字面量，并在需要精确表示时使用。',
    level: 'advanced',
    concepts: ['十六进制浮点', 'p 指数', '精度'],
    explain:
        '0x1p4 表示 1 × 2^4 = 16。p 后面是二进制指数。'
        '这种写法能精确表达二进制浮点值，'
        '在需要位级精确或生成测试数据时很有用。',
    code: r'''print(0x1p4)
print(0x1p-1)
print(0xA.8p0)
print(0x1p0, math.type(0x1p0))
print(0.5 == 0x1p-1)

print(tonumber("0x1p4"))
print(tonumber("ff", 16))
print(tonumber("0x10"))

print(string.format("%a", 1.5))
''',
    output: '16.0\n0.5\n10.5\n1.0\tfloat\ntrue\n16.0\n255\n16\n0x1.8p+0\n',
    exercises: [
      LuaExercise(
        prompt: '用十六进制浮点表示 0.25。',
        hint: '2 的 -2 次方。',
        answer: 'print(0x1p-2)  -- 0.25',
      ),
      LuaExercise(
        prompt: '为什么 %a 格式有用？',
        hint: '想想可逆性。',
        answer: '因为它能精确表示浮点的二进制形式，读回来不会有精度损失。',
      ),
    ],
    pitfalls: ['p 是指数分隔符，不是数学里的幂运算。', '十六进制字面量默认是整数，带 p 才是浮点。'],
  ),
  LuaTopic(
    id: 'lua54-env',
    chapter: 'lua54',
    title: '_ENV 与环境隔离',
    summary: '每个函数可以有自己的 _ENV，用来限定它能看到的全局名。',
    objective: '能用 _ENV 白名单限制代码可访问的全局变量。',
    level: 'advanced',
    concepts: ['_ENV', '沙箱', '白名单'],
    explain:
        '全局变量实际上是 _ENV 表的字段。'
        '给函数指定一个受限的 _ENV，它就只能看到白名单里的名字，'
        '访问其他全局名会得到 nil 从而报错。'
        '这是实现沙箱的核心手段。',
    code: r'''local allowed = {
  print = print,
  math = math,
  value = 5,
}

local function sandboxed()
  local _ENV = allowed
  print("value =", value)
  print("floor =", math.floor(2.9))
  return value * 2
end

print(sandboxed())
print(value == nil)

local untrusted = load("return os.time()", "untrusted", "t", allowed)
print(pcall(untrusted) == false)

local safe = load("return value + 1", "safe", "t", allowed)
print(safe())

print(_G.print ~= nil)
''',
    output: 'value =\t5\nfloor =\t2\n10\ntrue\ntrue\n6\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '给受限环境提供 string.sub，而不暴露整个共享 string 表。',
        hint: '在白名单表里加字段。',
        answer:
            'allowed.string = { sub = string.sub }  -- 这是独立导出表，不是自动只读；如需禁止修改还需另设代理。',
      ),
      LuaExercise(
        prompt: '为什么 os.time 在沙箱里不可用？',
        hint: '看看 _ENV 是什么。',
        answer: '因为白名单表里没有 os，_ENV.os 是 nil，索引 nil 就会报错。',
      ),
    ],
    pitfalls: ['_ENV 必须是表，赋成其他值会导致后续全局访问报错。', '白名单里的表本身仍可被修改，需要深度保护时要额外处理。'],
  ),
  LuaTopic(
    id: 'lua54-warn',
    chapter: 'lua54',
    title: 'warn 与警告系统',
    summary: 'warn 输出警告到 stderr，可以用 "@on"/"@off" 控制。',
    objective: '能用 warn 输出诊断信息，并知道它与 print 的区别。',
    level: 'intermediate',
    concepts: ['warn', 'stderr', '控制'],
    explain:
        'warn(msg) 把消息写到标准错误，并自动加换行。'
        'warn("@off") 关闭警告，warn("@on") 打开。'
        '和 print 不同，warn 不写到标准输出，因此不会污染程序的正常输出。',
    code: r'''print(type(warn))
print(warn ~= print)

warn("@off")
warn("这条不会显示")
warn("@on")

print("继续执行")

print(select("#", warn("@off")))
print(pcall(warn) == false)

local function deprecated(name)
  warn("已弃用：" .. name)
end
deprecated("oldApi")
print("完成")
''',
    output: 'function\ntrue\n继续执行\n0\ntrue\n完成\n',
    exercises: [
      LuaExercise(
        prompt: '输出一条弃用警告。',
        hint: 'warn。',
        answer: 'warn("已弃用：oldApi")',
      ),
      LuaExercise(
        prompt: '为什么警告不该用 print？',
        hint: '想想输出通道。',
        answer: '因为 print 混进标准输出会污染程序结果，警告属于诊断信息，应该走 stderr。',
      ),
    ],
    pitfalls: [
      'warn 的输出不会出现在标准输出里，测试断言看不到它。',
      'warn("@off") 之后再 warn 的消息会被丢弃。',
    ],
  ),
  LuaTopic(
    id: 'lua54-utf8-support',
    chapter: 'lua54',
    title: '标准库带来的 UTF-8 支持',
    summary: '5.4 内置 utf8 库，无需第三方就能处理中文。',
    objective: '能说明 5.3/5.4 在字符串处理上的能力边界。',
    level: 'beginner',
    concepts: ['utf8 库', '版本差异', '内置'],
    explain:
        'Lua 5.3 开始内置 utf8 库，5.4 进一步完善。'
        '但 string 库仍然按字节工作，'
        '所以处理中文时要用 utf8.len/codes/offset 而不是 #/sub 的字节语义。',
    code: r'''print(type(utf8))
print(#utf8.charpattern)
print(utf8.charpattern:find("^%[") ~= nil)
print(#"中文")
print(utf8.len("中文"))

local count = 0
for _ in utf8.codes("你好世界") do count = count + 1 end
print(count)

local text = "lua5.4"
print(utf8.len(text), #text)

print(("中文"):sub(1, 3) == "中")
print(utf8.codepoint("中") == 20013)
''',
    output: 'table\n14\ntrue\n6\n2\n4\n6\t6\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '比较中文字符串的字节长度和字符长度。',
        hint: '# 与 utf8.len。',
        answer: 'print(#s, utf8.len(s))',
      ),
      LuaExercise(
        prompt: '为什么 #"中文" 是 6？',
        hint: '想想 UTF-8 编码。',
        answer: '因为每个汉字用 3 个字节表示，# 按字节计算就是 6。',
      ),
    ],
    pitfalls: ['string 库的模式类只对 ASCII 可靠。', 'string.sub 的下标是字节位置。'],
  ),
  LuaTopic(
    id: 'lua54-upgrade-notes',
    chapter: 'lua54',
    title: '版本升级的破坏性变化',
    summary: '从 5.1/5.2 迁移到 5.4 时要注意的几处差异。',
    objective: '能列出至少三类升级时需要检查的兼容性变化。',
    level: 'advanced',
    concepts: ['兼容性', '迁移', '弃用'],
    explain:
        '5.1 的 setfenv/getfenv 已被 _ENV 取代；'
        'math.pow、math.mod 等函数已移除；'
        'table.getn 被 # 取代；'
        'unpack 移到了 table.unpack。'
        '迁移前先跑一遍测试并检查这些名称，能省下大量时间。',
    code: r'''print(type(_ENV))
print(setfenv == nil or type(setfenv) == "function")
print(type(math.mod))
print(type(table.getn))
print(table.unpack ~= nil)
print(type(unpack))
print(type(table.maxn))
print(type(string.gfind))
print(type(loadstring))
print(type(math.pow) == "function" or type(math.pow) == "nil")

print(load("return 1") ~= nil)
print(type(load))
''',
    output:
        'table\ntrue\nnil\nnil\ntrue\nnil\nnil\nnil\nnil\ntrue\ntrue\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '把 unpack(t) 改写成 5.4 的写法。',
        hint: 'table.unpack。',
        answer: 'print(table.unpack(t))',
      ),
      LuaExercise(
        prompt: 'loadstring 应该换成什么？',
        hint: '5.2 起的统一入口。',
        answer: 'load，它的参数语义有变化，但同样可以加载字符串源码。',
      ),
    ],
    pitfalls: [
      '兼容层（如 lua-compat-5.3）能缓解但不该长期依赖。',
      '版本差异会静默返回 nil，导致运行到很后面才报错。',
    ],
  ),
];
