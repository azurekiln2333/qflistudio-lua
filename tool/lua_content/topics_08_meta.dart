import 'lua_topic.dart';

/// 第八章：元表与运算符重载。
const List<LuaTopic> topicsMeta = [
  LuaTopic(
    id: 'lua-meta-index-table',
    chapter: 'meta',
    title: '__index 表回退',
    summary: '读取缺失字段时，Lua 会到 __index 指向的表里继续找。',
    objective: '能用 __index 实现默认值和原型链式共享。',
    level: 'intermediate',
    concepts: ['__index', 'setmetatable', '默认值'],
    explain:
        '访问 t.key 而 t 里没有 key 时，如果 t 有元表且元表有 __index，'
        '就会去 __index 里再查一次。__index 可以是表，也可以是函数。'
        '这是 Lua 实现「默认配置」「原型共享」「简单继承」的核心机制。',
    code: r'''local defaults = { debug = false, theme = "dark" }
local settings = setmetatable({ theme = "light" }, { __index = defaults })

print(settings.theme)
print(settings.debug)
print(settings.missing)

local proto = { greet = function(self) return "hi " .. self.name end }
local user = setmetatable({ name = "小明" }, { __index = proto })
print(user:greet())

print(rawget(user, "greet") == nil)
''',
    output: 'light\nfalse\nnil\nhi 小明\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '给 settings 加一个默认值字段，使其在缺失时返回 "auto"。',
        hint: '在 defaults 里加对应键。',
        answer: 'defaults.mode = "auto"',
      ),
      LuaExercise(
        prompt: 'rawget 为什么拿不到 greet？',
        hint: 'rawget 绕过元表。',
        answer: '因为 greet 不在 user 表里，而是来自 __index 的回退查找。',
      ),
    ],
    pitfalls: ['__index 只处理读取，写入不会写进 __index 表。', '链式 __index 层次太深会拖慢访问。'],
  ),
  LuaTopic(
    id: 'lua-meta-index-function',
    chapter: 'meta',
    title: '__index 函数：动态计算',
    summary: '__index 是函数时，每次缺失访问都会调用它计算返回值。',
    objective: '能用函数 __index 实现动态字段、延迟计算和严格模式。',
    level: 'intermediate',
    concepts: ['__index', '函数', '动态字段'],
    explain:
        '__index 为函数时，参数是 (原表, 缺失的键)，返回值作为访问结果。'
        '这让「字段名即查询」成为可能，例如把 color_red 映射成固定的调色板值。'
        '返回 nil 表示确实没有这个字段。',
    code: r'''local palette = {
  default = "white",
  primary = "blue",
}

local theme = setmetatable({}, {
  __index = function(_, key)
    local name = tostring(key):match("^color_(%a+)$")
    if name then return palette[name] or palette.default end
    return nil
  end,
})

print(theme.color_primary)
print(theme.color_unknown)
print(theme.color_default)
print(theme.other)
''',
    output: 'blue\nwhite\nwhite\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '让 theme.color_ 前缀支持数字键返回编号。',
        hint: '在函数里判断匹配。',
        answer:
            r'local n = tostring(key):match("^color_(%d+)$")  -- 再加一个分支返回编号',
      ),
      LuaExercise(
        prompt: '函数 __index 什么时候会被调用？',
        hint: '只有缺失字段。',
        answer: '只在表中确实没有该键时调用，已有的键不会触发。',
      ),
    ],
    pitfalls: ['__index 函数里对同一张表做缺失访问会无限递归。', '动态字段每次访问都要计算，热点路径要注意性能。'],
  ),
  LuaTopic(
    id: 'lua-meta-newindex',
    chapter: 'meta',
    title: '__newindex 拦截写入',
    summary: '__newindex 在给不存在的键赋值时触发，用于校验或转发。',
    objective: '能用 __newindex 实现只读表、默认值和写入转发。',
    level: 'intermediate',
    concepts: ['__newindex', '写入拦截', '只读'],
    explain:
        '__newindex 只在键还「不存在」时触发：给已有键赋值不会触发。'
        '它可以是表（写入会被转发到那张表）或函数（自行决定怎么处理）。'
        '常见用途是把写操作记录到日志、做类型校验，或者构造只读视图。',
    code: r'''local log = {}
local data = setmetatable({ existing = 1 }, {
  __newindex = function(target, key, value)
    log[#log + 1] = key
    rawset(target, key, value)
  end,
})

data.existing = 2
print(#log)

data.fresh = 3
print(#log, log[1], data.fresh)

local store = {}
local proxy = setmetatable({}, { __newindex = store })
proxy.x = 10
print(proxy.x, store.x, rawget(proxy, "x"))

data.existing = 5
print(#log, data.existing)
''',
    output: '0\n1\tfresh\t3\nnil\t10\tnil\n1\t5\n',
    exercises: [
      LuaExercise(
        prompt: '用 __newindex 禁止新增字段。',
        hint: '不调用 rawset，直接报错或忽略。',
        answer:
            'local ro = setmetatable({}, { __newindex = function() error("只读表") end })',
      ),
      LuaExercise(
        prompt: '为什么给 data.existing 赋值没有写进 log？',
        hint: '已有的键不触发 __newindex。',
        answer: '因为键已存在，Lua 直接更新原表，不经过 __newindex。',
      ),
    ],
    pitfalls: ['给已存在的键赋值不会触发 __newindex。', '在 __newindex 里直接赋值会递归，必须用 rawset。'],
  ),
  LuaTopic(
    id: 'lua-meta-tostring',
    chapter: 'meta',
    title: '__tostring 自定义打印',
    summary: 'print 和 tostring 会使用 __tostring 的返回值。',
    objective: '能让自定义对象打印出可读内容，而不是地址。',
    level: 'beginner',
    concepts: ['__tostring', 'print', '可读输出'],
    explain:
        '默认 print 一张表会输出 table: 0x... 这样的地址。'
        '定义 __tostring 元方法后，print 和 tostring 都会调用它，'
        '应显式返回字符串，避免依赖数字到字符串的隐式转换。'
        '这几乎是每个自定义类型的必备方法。',
    code: r'''local Point = {}
Point.__index = Point
Point.__tostring = function(self)
  return string.format("Point(%d, %d)", self.x, self.y)
end

function Point.new(x, y)
  return setmetatable({ x = x, y = y }, Point)
end

local p = Point.new(3, 4)
print(p)
print(tostring(p))
print("坐标是 " .. tostring(p))
print(type(p))
''',
    output: 'Point(3, 4)\nPoint(3, 4)\n坐标是 Point(3, 4)\ntable\n',
    exercises: [
      LuaExercise(
        prompt: '给 Point 的 __tostring 加上向量长度。',
        hint: '用 sqrt(x*x + y*y)；在 __tostring 内再次 tostring(self) 会递归。',
        answer:
            'return string.format("Point(%d, %d) len=%.2f", self.x, self.y, math.sqrt(self.x * self.x + self.y * self.y))',
      ),
      LuaExercise(
        prompt: '__tostring 返回表会怎样？',
        hint: '返回值必须能直接当作字符串使用。',
        answer: '会报错；Lua 5.4.8 接受可转成字符串的数字，但不接受表，推荐始终返回字符串。',
      ),
    ],
    pitfalls: [
      '__tostring 内调用 tostring(self) 会再次进入同一元方法，造成无限递归。',
      '.. 对表查找的是 __concat，而非 __tostring；没有 __concat 时请显式 tostring。',
    ],
  ),
  LuaTopic(
    id: 'lua-meta-eq-lt',
    chapter: 'meta',
    title: '__eq __lt __le 比较重载',
    summary: '用元方法定义自定义类型的相等与大小比较。',
    objective: '能为值对象实现 ==、<、<=，并让 table.sort 可用。',
    level: 'advanced',
    concepts: ['__eq', '__lt', '__le', '比较'],
    explain:
        '两张表默认只按引用比较相等，< 和 <= 直接报错。'
        '两个不同表的 == 可查找 __eq；< 与 <= 查找对应排序元方法，不要求两边都定义它。应在元方法中检查操作数类型。'
        '实现后 table.sort 里就能直接用 a < b 排序自定义对象。',
    code: r'''local Money = {}
Money.__index = Money
Money.__eq = function(a, b) return a.cents == b.cents end
Money.__lt = function(a, b) return a.cents < b.cents end
Money.__le = function(a, b) return a.cents <= b.cents end
Money.__tostring = function(self) return string.format("%.2f", self.cents / 100) end

local function money(cents) return setmetatable({ cents = cents }, Money) end

print(money(150) == money(150))
print(money(100) < money(200))
print(money(200) <= money(200))
print(money(200) > money(100))

local prices = { money(300), money(99), money(1500) }
table.sort(prices)
print(table.concat({ tostring(prices[1]), tostring(prices[2]), tostring(prices[3]) }, " "))
''',
    output: 'true\ntrue\ntrue\ntrue\n0.99 3.00 15.00\n',
    exercises: [
      LuaExercise(
        prompt: '为什么定义了 __lt 就能用 > 比较？',
        hint: 'Lua 会交换两个操作数。',
        answer: 'a > b 会被解释为 b < a，从而复用 __lt，不需要单独定义 >。',
      ),
      LuaExercise(
        prompt: '只定义 __lt 不定义 __le 时，a <= b 会怎样？',
        hint: 'Lua 5.4 里有回退规则。',
        answer:
            '本应用开启 LUA_COMPAT_5_3，所以缺 __le 时可回退到 not (b < a)；标准 Lua 5.4 不保证这个兼容选项，应显式定义 __le。',
      ),
    ],
    pitfalls: [
      '__eq 可用于两个不同的表或两个不同的完整 userdata；同一对象的 == 直接成立。',
      '相等与排序要一致，否则 table.sort 会混乱。',
    ],
  ),
  LuaTopic(
    id: 'lua-meta-arith',
    chapter: 'meta',
    title: '__add __sub 算术重载',
    summary: '用 __add、__sub、__mul、__div 定义自定义数值类型。',
    objective: '能为向量等类型实现四则运算，并支持数和对象的混合运算。',
    level: 'advanced',
    concepts: ['__add', '__mul', '算术重载'],
    explain:
        '给元表加 __add 等字段后，a + b 会调用它，参数是两个操作数。'
        '当一方是数字时也能工作（Lua 会去找对象那一侧的元方法）。'
        '这种写法适合向量、复数、货币等需要保持语义的类型。',
    code: r'''local Vec = {}
Vec.__index = Vec
Vec.__tostring = function(self) return string.format("(%d, %d)", self.x, self.y) end
Vec.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y }, Vec) end
Vec.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y }, Vec) end
Vec.__mul = function(a, factor)
  if type(a) == "number" then a, factor = factor, a end
  return setmetatable({ x = a.x * factor, y = a.y * factor }, Vec)
end
Vec.__unm = function(a) return setmetatable({ x = -a.x, y = -a.y }, Vec) end
Vec.__eq = function(a, b) return a.x == b.x and a.y == b.y end

local function vec(x, y) return setmetatable({ x = x, y = y }, Vec) end

local a, b = vec(1, 2), vec(3, 4)
print(tostring(a + b))
print(tostring(a - b))
print(tostring(a * 3))
print(tostring(2 * a))
print(tostring(-a))
print(a + b == vec(4, 6))
''',
    output: '(4, 6)\n(-2, -2)\n(3, 6)\n(2, 4)\n(-1, -2)\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '实现向量点积函数 dot(a, b)。',
        hint: '返回 a.x*b.x + a.y*b.y。',
        answer: 'local function dot(a, b) return a.x * b.x + a.y * b.y end',
      ),
      LuaExercise(
        prompt: '为什么 __mul 里要判断哪一边是数字？',
        hint: '2 * a 和 a * 2 的参数顺序不同。',
        answer: '因为 Lua 把两个操作数按原顺序传入，交换后要保证对象在 a 位置。',
      ),
    ],
    pitfalls: ['元方法里返回新对象，不要修改参数。', '缺少 __eq 时 even 相同内容的两个对象也不相等。'],
  ),
  LuaTopic(
    id: 'lua-meta-len-concat',
    chapter: 'meta',
    title: '__len 与 __concat',
    summary: '用 __len 定义长度、用 __concat 定义拼接语义。',
    objective: '能让自定义集合报告长度，并让它支持 .. 拼接。',
    level: 'advanced',
    concepts: ['__len', '__concat', '重载'],
    explain:
        '__len 让 #obj 返回你定义的值，适合包装了内部数组的容器。'
        '__concat 让 a .. b 调用元方法，可以决定拼接顺序和格式。'
        '两者都常用于把「包装对象」表现得像内置类型。',
    code: r'''local Bag = {}
Bag.__index = Bag
Bag.__len = function(self) return self.count end
Bag.__concat = function(a, b)
  local left = type(a) == "table" and a:describe() or tostring(a)
  local right = type(b) == "table" and b:describe() or tostring(b)
  return left .. " + " .. right
end

function Bag.new(items)
  local self = setmetatable({ items = {}, count = 0 }, Bag)
  for _, item in ipairs(items) do self:add(item) end
  return self
end

function Bag:add(item)
  self.count = self.count + 1
  self.items[self.count] = item
end

function Bag:describe()
  return "Bag(" .. self.count .. ")"
end

local bag = Bag.new({ "a", "b" })
print(#bag)
print(bag .. "tail")
print("head " .. bag)
print(bag .. Bag.new({ "c" }))
''',
    output: '2\nBag(2) + tail\nhead  + Bag(2)\nBag(2) + Bag(1)\n',
    exercises: [
      LuaExercise(
        prompt: '给 Bag 加一个 __eq 比较元素个数。',
        hint: '比较 count。',
        answer: 'Bag.__eq = function(a, b) return a.count == b.count end',
      ),
      LuaExercise(
        prompt: '为什么只有一边是 Bag 时也能拼接？',
        hint: 'Lua 会检查两侧的元表。',
        answer: '因为 Lua 会尝试两侧的元方法，只要有一侧提供 __concat 就能生效。',
      ),
    ],
    pitfalls: [
      '# 对表默认返回序列长度，定义 __len 后完全改变语义，要谨慎。',
      '__concat 里要处理「另一边是字符串」的情况。',
    ],
  ),
  LuaTopic(
    id: 'lua-meta-call-pairs',
    chapter: 'meta',
    title: '__call 与 __pairs',
    summary: '让表可以像函数一样调用，也可以自定义 pairs 的遍历方式。',
    objective: '能用 __call 做可调用配置对象，用 __pairs 隐藏内部结构。',
    level: 'advanced',
    concepts: ['__call', '__pairs', '可调用对象'],
    explain:
        '__call 让 t(args) 合法，适合「带状态的函数」或需要携带配置的可调用对象。'
        '__pairs 让 for k, v in pairs(t) 使用你提供的迭代器，'
        '常用于只暴露对外字段、隐藏内部实现细节。',
    code: r'''local multiplier = setmetatable({ factor = 3 }, {
  __call = function(self, value) return value * self.factor end,
})

print(multiplier(5))
print(multiplier(1.5))

local secret = { public = 1, _hidden = 2, visible = 3 }
local view = setmetatable({}, {
  __pairs = function()
    local exposed = {}
    for key, value in pairs(secret) do
      if key:sub(1, 1) ~= "_" then exposed[key] = value end
    end
    return next, exposed, nil
  end,
})

local keys = {}
for key in pairs(view) do keys[#keys + 1] = key end
table.sort(keys)
print(table.concat(keys, ","))
print(view._hidden)
''',
    output: '15\n4.5\npublic,visible\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '让 __call 支持两个参数相加。',
        hint: '元方法签名是 function(self, ...)。',
        answer:
            '__call = function(self, a, b) return (a + b) * self.factor end',
      ),
      LuaExercise(
        prompt: '__pairs 返回的第三个值是什么？',
        hint: '看 next, exposed, nil。',
        answer: '初始控制值，通常传 nil；pairs 会把它作为第一次迭代的起点。',
      ),
    ],
    pitfalls: ['__pairs 只影响 pairs，不影响 ipairs。', '__pairs 返回的函数必须符合迭代器协议。'],
  ),
  LuaTopic(
    id: 'lua-meta-raw',
    chapter: 'meta',
    title: 'rawget / rawset / rawequal',
    summary: 'raw 系列函数绕过元表，直接操作原始数据。',
    objective: '能在元方法内部安全读写，避免递归与误触发。',
    level: 'advanced',
    concepts: ['rawget', 'rawset', '绕过元表'],
    explain:
        'rawget(t, k) 直接取原始值，不查 __index；rawset 直接写，不触发 __newindex；'
        'rawequal 直接比较引用。'
        '在 __newindex 或 __index 的实现里，几乎一定要用 rawset/rawget，'
        '否则会递归调用自己。',
    code: r'''local data = setmetatable({ a = 1 }, {
  __index = function() return "default" end,
  __newindex = function(target, key, value)
    rawset(target, key, value)
  end,
})

print(data.a)
print(data.b)
print(rawget(data, "b"))

data.c = 3
print(rawget(data, "c"), data.c)

local other = setmetatable({ a = 1 }, { __eq = function() return true end })
print(other == setmetatable({ a = 9 }, getmetatable(other)))
print(rawequal(other, other))
''',
    output: '1\ndefault\nnil\n3\t3\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 __newindex 里必须用 rawset？',
        hint: '想想递归。',
        answer: '直接赋值会再次触发 __newindex，形成无限递归。',
      ),
      LuaExercise(
        prompt: 'rawlen 与 # 有什么区别？',
        hint: 'rawlen 忽略 __len。',
        answer: 'rawlen 直接取表的序列长度，不调用 __len 元方法。',
      ),
    ],
    pitfalls: [
      '在元方法里忘记用 raw 版本是最常见的递归崩溃原因。',
      'rawget 拿到 nil 不代表原表真的没有该键？它就是原表结果。',
    ],
  ),
  LuaTopic(
    id: 'lua-meta-readonly',
    chapter: 'meta',
    title: '构造只读表',
    summary: '用代理表加 __newindex/__index 实现不可写的配置视图。',
    objective: '能做出对外只读、对内可写的配置对象。',
    level: 'advanced',
    concepts: ['只读', '代理', '封装'],
    explain:
        '只读表通常做成代理：代理自身不存数据，读走 __index 转发到内部表，'
        '写被 __newindex 拒绝。'
        '内部表仍然可以被持有它的模块修改，'
        '对外暴露的只是只读视图，这就是最简形式的封装。',
    code: r'''local function readOnly(source)
  return setmetatable({}, {
    __index = source,
    __newindex = function(_, key)
      error("配置是只读的，不能修改 " .. tostring(key), 2)
    end,
    __len = function() return #source end,
  })
end

local internal = { mode = "fast", retries = 3 }
local config = readOnly(internal)

print(config.mode, config.retries)
local ok, err = pcall(function() config.mode = "slow" end)
print(ok, (tostring(err):gsub("^.-:%d+: ", "")))
print(config.mode)

internal.mode = "balanced"
print(config.mode)
''',
    output:
        'fast\t3\nfalse\t'
        '配置是只读的，不能修改 mode\nfast\nbalanced\n',
    exercises: [
      LuaExercise(
        prompt: '为什么改 internal.mode 之后 config.mode 也变了？',
        hint: '代理不复制数据。',
        answer: '因为代理只是转发读取，数据仍然只有 internal 一份。',
      ),
      LuaExercise(
        prompt: 'error 的第二个参数 2 有什么作用？',
        hint: '控制报错位置。',
        answer: '把责任位置指向调用方，错误信息里显示的是调用点而不是元方法内部。',
      ),
    ],
    pitfalls: ['只读代理不是安全边界，持有内部表的人仍能修改。'],
  ),
];
