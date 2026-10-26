import 'lua_topic.dart';

/// 第二十章：面向对象。
const List<LuaTopic> topicsOop = [
  LuaTopic(
    id: 'lua-oop-dot-vs-colon',
    chapter: 'oop',
    title: '点号与冒号的区别',
    summary: '冒号调用会自动传 self，点号不会。',
    objective: '能说明 obj:method() 等价于 obj.method(obj)，并在混用时定位错误。',
    level: 'beginner',
    concepts: ['冒号', 'self', '语法糖'],
    explain:
        'obj:method(args) 是 obj.method(obj, args) 的语法糖。'
        '用点号调用带 self 的方法时，第一个参数会被当成 self，'
        '导致后面的参数整体错位，或者 self 变成 nil。'
        '定义时用冒号的人必须用冒号调用。',
    code: r'''local counter = { value = 0 }

function counter:add(step)
  self.value = self.value + step
  return self.value
end

print(counter:add(3))
print(counter:add(4))

function counter.addPlain(other, step)
  other.value = other.value + step
  return other.value
end

print(counter.addPlain(counter, 1))
print(counter.value)

print(counter.add == counter["add"])
local ok, err = pcall(function() return counter.addPlain(1) end)
print(ok, err ~= nil)
''',
    output: '3\n7\n8\n8\ntrue\nfalse\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '用点号调用 counter:add 会怎样？',
        hint: 'self 变成什么。',
        answer: 'counter.add(1) 会把 1 当作 self，然后 self.value 索引数字导致错误。',
      ),
      LuaExercise(
        prompt: '把 obj:method() 改写成等价形式。',
        hint: '语法糖展开。',
        answer: 'obj.method(obj)',
      ),
    ],
    pitfalls: [
      '定义用冒号、调用用点号是最常见的错误来源：函数里写 self.speak() 就丢掉了 self。',
      'self 只是普通形参名，可以改名但会破坏冒号语法糖。',
    ],
  ),
  LuaTopic(
    id: 'lua-oop-class-basic',
    chapter: 'oop',
    title: '用表加元表定义类',
    summary: '类就是表，实例用 setmetatable 把自己的 __index 指向类。',
    objective: '能写出构造函数和实例方法，并理解查找链。',
    level: 'beginner',
    concepts: ['类', '__index', '构造函数'],
    explain:
        'Lua 没有 class 关键字，常用做法：'
        '类本身是一个表存放方法，构造函数 new 创建实例表并设置 __index 指向类。'
        '访问实例上不存在的字段时，会沿着 __index 到类里找，方法就是这样被找到的。',
    code: r'''local Account = {}
Account.__index = Account

function Account.new(owner, balance)
  local self = setmetatable({}, Account)
  self.owner = owner
  self.balance = balance or 0
  return self
end

function Account:deposit(amount)
  self.balance = self.balance + amount
  return self
end

function Account:describe()
  return string.format("%s 有 %d 元", self.owner, self.balance)
end

local account = Account.new("小明", 100)
account:deposit(50):deposit(25)
print(account:describe())
print(account.balance)
print(getmetatable(account) == Account)
print(account.describe == Account.describe)
''',
    output: '小明 有 175 元\n175\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '给 Account 加一个 withdraw 方法。',
        hint: '和 deposit 反向操作。',
        answer:
            'function Account:withdraw(amount) self.balance = self.balance - amount return self end',
      ),
      LuaExercise(
        prompt: '为什么每个实例不需要复制方法？',
        hint: '想想 __index。',
        answer: '因为方法只存在类表里，实例通过 __index 查找，共享同一份函数。',
      ),
    ],
    pitfalls: ['忘记设置 __index 会导致实例上找不到方法。', '__index 指向类表本身，而不是实例。'],
  ),
  LuaTopic(
    id: 'lua-oop-inheritance',
    chapter: 'oop',
    title: '继承与 super 调用',
    summary: '子类的 __index 指向父类，方法里可显式调用父类实现。',
    objective: '能建立两层继承，并在子类方法里调用父类方法。',
    level: 'intermediate',
    concepts: ['继承', '__index 链', 'super'],
    explain:
        '子类继承父类只需两件事：'
        '把子类的 __index 指向父类，并让子类元表的 __index 也指向父类（这样构造时能找到父类方法）。'
        '子类方法里调用父类实现要显式写出父类表名：Base.method(self, ...)。',
    code: r'''local Animal = {}
Animal.__index = Animal

function Animal.new(name)
  return setmetatable({ name = name }, Animal)
end

function Animal:speak()
  return self.name .. " 发出声音"
end

function Animal:describe()
  return "动物：" .. self:speak()
end

local Dog = setmetatable({}, { __index = Animal })
Dog.__index = Dog

function Dog.new(name)
  local self = Animal.new(name)
  return setmetatable(self, Dog)
end

function Dog:speak()
  return self.name .. " 汪汪"
end

local dog = Dog.new("旺财")
print(dog:speak())
print(dog:describe())
print(getmetatable(dog) == Dog)

function Dog:describe()
  return "狗：" .. Animal.describe(self)
end
print(dog:describe())
''',
    output: '旺财 汪汪\n动物：旺财 汪汪\ntrue\n狗：动物：旺财 汪汪\n',
    exercises: [
      LuaExercise(
        prompt: '加一个 Cat 子类，speak 返回「喵」。',
        hint: '复制 Dog 的结构。',
        answer:
            'local Cat = setmetatable({}, { __index = Animal }); Cat.__index = Cat; function Cat:speak() return self.name .. " 喵" end',
      ),
      LuaExercise(
        prompt: '为什么子类要设置两层 __index？',
        hint: '一个给实例，一个给子类表。',
        answer: '实例的 __index 指向子类以找到子类方法，子类表的 __index 指向父类以便找不到时继续向上找。',
      ),
    ],
    pitfalls: ['子类 new 里要先构造父类实例再改元表。', '父类方法里用 self 才能正确分派到子类重写的方法。'],
  ),
  LuaTopic(
    id: 'lua-oop-private-closure',
    chapter: 'oop',
    title: '用闭包实现私有字段',
    summary: '把状态放进闭包，只暴露方法，实现真正不可直接访问的字段。',
    objective: '能用闭包封装私有状态，并说明它与约定的区别。',
    level: 'intermediate',
    concepts: ['闭包', '私有字段', '封装'],
    explain:
        'Lua 的表字段全部是公开的，'
        '想要真正的私有状态，就把变量声明在构造函数外层的局部作用域里，'
        '只有闭包方法能访问它。'
        '代价是无法直接序列化或反射这些字段。',
    code: r'''local function newCounter(start)
  local value = start or 0
  local history = {}

  return {
    increment = function(step)
      step = step or 1
      value = value + step
      history[#history + 1] = step
      return value
    end,
    get = function() return value end,
    steps = function() return #history end,
  }
end

local counter = newCounter(10)
print(counter.get())
print(counter.increment())
print(counter.increment(5))
print(counter.get())
print(counter.steps())
print(counter.value == nil)

local other = newCounter()
print(other.get(), counter.get())
''',
    output: '10\n11\n16\n16\n2\ntrue\n0\t16\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 counter.value 是 nil？',
        hint: '想想局部变量。',
        answer: '因为 value 是闭包里的局部变量，不是表的字段，外部无法通过索引访问。',
      ),
      LuaExercise(
        prompt: '两个实例会共享 status 吗？',
        hint: '想想每次调用 newCounter。',
        answer: '不会，每次调用 newCounter 都创建新的局部变量，各自独立。',
      ),
    ],
    pitfalls: ['闭包方案无法实现继承。', '每个实例都会创建一份方法，实例很多时内存开销更大。'],
  ),
  LuaTopic(
    id: 'lua-oop-operator-methods',
    chapter: 'oop',
    title: '给对象定义运算符',
    summary: '用 __add、__lt 等元方法让自定义类型支持运算。',
    objective: '能定义算术和比较元方法，并保持语义一致。',
    level: 'intermediate',
    concepts: ['__add', '__lt', '__le'],
    explain:
        '元方法让表支持 +、-、< 等运算。'
        '注意 __lt 和 __le 必须严格对应，'
        '否则排序结果会自相矛盾。'
        '实现时要先检查类型，避免与非本类型混算。',
    code: r'''local Vec = {}
Vec.__index = Vec

function Vec.new(x, y)
  return setmetatable({ x = x, y = y }, Vec)
end

Vec.__add = function(a, b)
  return Vec.new(a.x + b.x, a.y + b.y)
end

Vec.__eq = function(a, b)
  return a.x == b.x and a.y == b.y
end

Vec.__lt = function(a, b)
  return a.x * a.x + a.y * a.y < b.x * b.x + b.y * b.y
end

Vec.__le = function(a, b)
  return a.x * a.x + a.y * a.y <= b.x * b.x + b.y * b.y
end

Vec.__tostring = function(v)
  return string.format("(%d,%d)", v.x, v.y)
end

local a = Vec.new(1, 2)
local b = Vec.new(3, 4)
print(tostring(a + b))
print(a == Vec.new(1, 2))
print(a < b, b < a)
print(a <= Vec.new(1, 2))
print(tostring(a + b + Vec.new(1, 1)))
''',
    output: '(4,6)\ntrue\ntrue\tfalse\ntrue\n(5,7)\n',
    exercises: [
      LuaExercise(
        prompt: '给 Vec 加 __mul 表示数乘。',
        hint: '检查第二个参数是数字。',
        answer:
            'Vec.__mul = function(v, k) return Vec.new(v.x * k, v.y * k) end',
      ),
      LuaExercise(
        prompt: 'Lua 5.4 要求两个表共享同一个 __eq 才会调用它吗？',
        hint: '区分早期 Lua 版本的限制。',
        answer:
            '不要求。两个不同的表比较时先查左侧的 __eq，没有再查右侧；完整 userdata 也有类似规则，表与数字等不同类型比较不调用它。',
      ),
    ],
    pitfalls: [
      '本应用的 Lua 5.3 兼容选项支持 __le 向 __lt 回退；可移植 Lua 5.4 代码应显式定义 __le。',
      'Lua 5.4 的 __eq 不要求双方共享元方法，需自行校验另一操作数并保持相等关系对称。',
    ],
  ),
  LuaTopic(
    id: 'lua-oop-getter-setter',
    chapter: 'oop',
    title: '用元表实现校验的 setter',
    summary: '在 __newindex 里做校验，把非法赋值挡在门外。',
    objective: '能实现带类型检查的字段赋值，并说明何时该用函数代替。',
    level: 'intermediate',
    concepts: ['__newindex', '校验', '赋值拦截'],
    explain:
        '__newindex 只在字段不存在时触发，'
        '所以要配合一个内部表存放真实数据。'
        '这样可以在赋值时校验类型或范围。'
        '但过度使用会让代码难懂，简单场景用 setXxx 函数更直观。',
    code: r'''local function strictRecord(initial)
  local data = {}
  local proxy = {}

  local guard = {
    __newindex = function(_, key, value)
      if key == "age" and type(value) ~= "number" then
        error("age 必须是数字", 2)
      end
      if key == "age" and value < 0 then
        error("age 不能为负", 2)
      end
      data[key] = value
    end,
    __index = function(_, key)
      return data[key]
    end,
  }

  setmetatable(proxy, guard)
  for key, value in pairs(initial or {}) do proxy[key] = value end
  return proxy
end

local person = strictRecord({ age = 18 })
print(person.age)

person.age = 30
print(person.age)

local ok, err = pcall(function() person.age = -1 end)
print(ok, (tostring(err):gsub("^.-:%d+: ", "")))

local ok2, err2 = pcall(function() person.age = "x" end)
print(ok2, (tostring(err2):gsub("^.-:%d+: ", "")))

person.name = "小明"
print(person.name)
''',
    output: '18\n30\nfalse\tage 不能为负\nfalse\tage 必须是数字\n小明\n',
    exercises: [
      LuaExercise(
        prompt: '加上「name 必须是字符串」的校验。',
        hint: '在 __newindex 里判断。',
        answer:
            'if key == "name" and type(value) ~= "string" then error("name 必须是字符串", 2) end',
      ),
      LuaExercise(
        prompt: '为什么不直接用 __index 指向 data？',
        hint: '想想 __newindex 的触发条件。',
        answer: '因为 __newindex 只在键不存在于代理自身时才触发，用函数形式才能统一拦截所有写入。',
      ),
    ],
    pitfalls: [
      '代理表不能提前写入同名键，否则 __newindex 不再触发。',
      'error 的 level 2 才能把位置指向调用方。',
    ],
  ),
  LuaTopic(
    id: 'lua-oop-class-factory',
    chapter: 'oop',
    title: '类工厂与 instanceof',
    summary: '写一个通用的 class 工厂，自动处理 __index 与父子关系。',
    objective: '能用工厂减少重复样板，并实现 instanceof 判断。',
    level: 'advanced',
    concepts: ['工厂', '样板代码', 'instanceof'],
    explain:
        '每个类都要写 __index、new、继承设置，重复度高。'
        '工厂把这些收进一个函数，返回建好的类表。'
        '还要提供 instanceof：沿元表链向上找，看是否能到达目标类。',
    code: r'''local function class(parent)
  local cls = {}
  cls.__index = cls
  if parent then setmetatable(cls, { __index = parent }) end
  cls.super = parent
  return cls
end

local function instanceof(object, cls)
  local meta = getmetatable(object)
  while meta do
    if meta == cls then return true end
    local parentMeta = getmetatable(meta)
    meta = parentMeta and parentMeta.__index
  end
  return false
end

local Shape = class()
function Shape:new(name)
  local self = setmetatable({}, self)
  self.name = name
  return self
end
function Shape:area() return 0 end

local Square = class(Shape)
function Square:new(side)
  local self = Shape.new(self, "square")
  self.side = side
  return self
end
function Square:area() return self.side * self.side end

local square = Square:new(3)
print(square:area())
print(square.name)
print(instanceof(square, Square), instanceof(square, Shape))
print(instanceof(Shape:new("x"), Square))
print(getmetatable(square) == Square)
''',
    output: '9\nsquare\ntrue\ttrue\nfalse\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '用工厂加一个 Circle，area 用 3.14*r*r。',
        hint: '继承 Shape。',
        answer:
            'local Circle = class(Shape); function Circle:area() return 3.14 * self.radius * self.radius end',
      ),
      LuaExercise(
        prompt: 'instanceof 为什么要循环？',
        hint: '想想多级继承。',
        answer: '因为继承可能有多层，需要沿元表链一直向上比较，直到没有父类为止。',
      ),
    ],
    pitfalls: [
      'Shape.new(self, ...) 里的 self 是子类表，才能构造出子类实例。',
      'instanceof 依赖元表链，用闭包实现的对象无法判断。',
    ],
  ),
  LuaTopic(
    id: 'lua-oop-mixin',
    chapter: 'oop',
    title: '混入（mixin）复用行为',
    summary: '把方法表复制进类，实现不相关的横向复用。',
    objective: '能用 mixin 给类补充能力，并处理命名冲突。',
    level: 'intermediate',
    concepts: ['mixin', '复制', '冲突'],
    explain:
        '当多个不相关的类都需要同一组方法时，'
        '继承不合适，可以把方法逐个复制到目标类。'
        '复制时要决定冲突策略：跳过已有方法，还是由 mixin 覆盖。',
    code: r'''local Loggable = {}

function Loggable:log(message)
  return string.format("[%s] %s", self.tag, message)
end

function Loggable:tagWith(tag)
  self.tag = tag
  return self
end

local Serializable = {}

function Serializable:toPair()
  local keys = {}
  for key in pairs(self) do keys[#keys + 1] = key end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = key .. "=" .. tostring(self[key])
  end
  return table.concat(parts, "&")
end

local function mixin(target, ...)
  for _, source in ipairs({ ... }) do
    for key, value in pairs(source) do
      if target[key] == nil then target[key] = value end
    end
  end
  return target
end

local Service = {}
mixin(Service, Loggable, Serializable)

local service = setmetatable({ tag = "api" }, { __index = Service })
print(service:log("启动"))
print(service:toPair())

local Custom = { log = function(self, m) return "自定义:" .. m end }
mixin(Custom, Loggable)
print(Custom:log("消息"))
''',
    output: '[api] 启动\ntag=api\n自定义:消息\n',
    exercises: [
      LuaExercise(
        prompt: '让 mixin 允许覆盖已有方法。',
        hint: '去掉 nil 判断。',
        answer: '把 if target[key] == nil 去掉，直接 target[key] = value。',
      ),
      LuaExercise(
        prompt: '为什么 mixin 不需要 __index？',
        hint: '想想复制的作用。',
        answer: '因为方法被直接复制进目标表，查找时不需要再经过元表。',
      ),
    ],
    pitfalls: ['mixin 之后改源表不会影响已混入的类。', '复制顺序决定冲突时的胜者。'],
  ),
  LuaTopic(
    id: 'lua-oop-tostring',
    chapter: 'oop',
    title: '可读的 tostring 与调试输出',
    summary: '定义 __tostring 让 print 输出对象内容而不是地址。',
    objective: '能给对象定义稳定的 tostring 输出，并知道 print 与 format 的差异。',
    level: 'beginner',
    concepts: ['__tostring', '调试', '稳定输出'],
    explain:
        '默认 print 表只打印地址，无法定位问题。'
        '定义 __tostring 后，tostring(obj) 与 print 都会用你的格式化结果。'
        '应显式返回字符串；Lua 5.4.8 也接受可转为字符串的数字，但表等返回值会报错。',
    code: r'''local Point = {}
Point.__index = Point

function Point.new(x, y)
  return setmetatable({ x = x, y = y }, Point)
end

Point.__tostring = function(p)
  return string.format("Point(%d, %d)", p.x, p.y)
end

local p = Point.new(1, 2)
print(p)
print(tostring(p))

local ok, err = pcall(function()
  return string.format("%s", p)
end)
print(ok)

print(select("#", tostring(p)))
print(type(tostring(p)) == "string")

Point.__tostring = function(p) return { p.x } end
local ok2, err2 = pcall(tostring, p)
print(ok2, err2 ~= nil)
''',
    output: 'Point(1, 2)\nPoint(1, 2)\ntrue\n1\ntrue\nfalse\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '给 Point 的 tostring 加上类型名。',
        hint: '在格式串里加字面量。',
        answer: 'return string.format("Point<%d,%d>", p.x, p.y)',
      ),
      LuaExercise(
        prompt: '为什么 __tostring 返回表会报错，返回数字却不会？',
        hint: '想想 tostring 会把数字转成什么。',
        answer: '因为最终要被当成字符串使用：数字会被自动转成字符串，而表没有可用的字符串形式，于是报错。',
      ),
    ],
    pitfalls: [
      '__tostring 返回表会报错，返回数字虽能成功但会丢失自定义格式。',
      'string.format("%s", obj) 也会调用 __tostring，可以得到同样结果。',
    ],
  ),
  LuaTopic(
    id: 'lua-oop-call-operator',
    chapter: 'oop',
    title: '__call 让对象可调用',
    summary: '定义 __call 后，对象可以像函数一样被调用。',
    objective: '能用 __call 实现可调用对象，并保持参数语义清晰。',
    level: 'advanced',
    concepts: ['__call', '可调用对象', '参数'],
    explain:
        '元方法 __call(self, ...) 让 table 支持 f(args) 语法，'
        '第一个参数是被调用的对象本身。'
        '适合实现「带状态的函数」，'
        '但要小心可读性：调用方可能不知道它其实是个表。',
    code: r'''local function newMultiplier(factor)
  return setmetatable({ factor = factor }, {
    __call = function(self, value)
      return self.factor * value
    end,
  })
end

local triple = newMultiplier(3)
print(triple(5))
print(triple(0))
print(type(triple))
print(triple.factor)

local function newAccumulator()
  local total = 0
  return setmetatable({}, {
    __call = function(self, value)
      if value then total = total + value end
      return total
    end,
  })
end

local add = newAccumulator()
print(add(5))
print(add(7))
print(add())

local ok = pcall(function() return triple(1, 2, 3) end)
print(ok)
''',
    output: '15\n0\ntable\n3\n5\n12\n12\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '用 __call 实现一个把字符串重复 n 次的调用器。',
        hint: '内部调用 string.rep。',
        answer:
            'setmetatable({ n = 2 }, { __call = function(self, s) return s:rep(self.n) end })',
      ),
      LuaExercise(
        prompt: '为什么 __call 的第一个参数是表？',
        hint: '和冒号调用类比。',
        answer: '因为 __call 被设计成方法形式，第一个参数固定是被调用的对象，实际参数从第二个开始。',
      ),
    ],
    pitfalls: ['__call 的第一个参数是对象，容易和普通函数混淆。', '可调用对象对调用方不够直观，除非确实需要携带状态。'],
  ),
  LuaTopic(
    id: 'lua-oop-composition',
    chapter: 'oop',
    title: '组合优于继承',
    summary: '用持有子对象代替继承，降低层级耦合。',
    objective: '能用组合搭建能力，并说明它相对继承的优势。',
    level: 'intermediate',
    concepts: ['组合', '委托', '耦合'],
    explain:
        '继承是「是一个」，组合是「有一个」。'
        '当类需要另一组能力时，把它当成字段持有并委托调用，'
        '可以避免脆弱的继承金字塔，也更容易替换实现。',
    code: r'''local function newClock()
  return {
    now = function() return "2026-10-22" end,
  }
end

local function newLogger(prefix)
  local lines = 0
  return {
    log = function(message)
      lines = lines + 1
      return string.format("%s %s", prefix, message)
    end,
    count = function() return lines end,
  }
end

local function newService(clock, logger)
  local service = {}

  function service:checkIn(user)
    logger.log("签到 " .. user)
    return clock.now() .. " " .. user
  end

  function service:stats()
    return logger.count()
  end

  return service
end

local service = newService(newClock(), newLogger("[info]"))
print(service:checkIn("小明"))
print(service:checkIn("小红"))
print(service:stats())

local fake = newService(
  { now = function() return "固定日期" end },
  newLogger("[test]")
)
print(fake:checkIn("测试"))
''',
    output: '2026-10-22 小明\n2026-10-22 小红\n2\n固定日期 测试\n',
    exercises: [
      LuaExercise(
        prompt: '为什么组合让测试更容易？',
        hint: '看看 fake 的构造。',
        answer: '因为可以传入假的 clock 和 logger，不用修改被测代码就能替换依赖。',
      ),
      LuaExercise(
        prompt: '继承版本要怎么改才能注入假时钟？',
        hint: '想想重写。',
        answer: '得新建子类重写 now 方法，层级越来越深，还不如组合直接替换字段。',
      ),
    ],
    pitfalls: ['组合会增加一层间接调用，热路径上要注意开销。'],
  ),
  LuaTopic(
    id: 'lua-oop-state-machine',
    chapter: 'oop',
    title: '用表实现状态机',
    summary: '状态表 + 转移函数，把散落的 if 收敛成数据。',
    objective: '能用表驱动状态转移，并报告非法转移。',
    level: 'advanced',
    concepts: ['状态机', '表驱动', '非法转移'],
    explain:
        '把「当前状态 + 事件 → 新状态」写成嵌套表，'
        '转移函数只做一次查表和校验。'
        '这样新增状态或事件只改数据，不改逻辑，'
        '非法转移也能统一报错。',
    code: r'''local transitions = {
  idle = { start = "running", stop = "idle" },
  running = { pause = "paused", stop = "idle" },
  paused = { start = "running", stop = "idle" },
}

local Machine = {}
Machine.__index = Machine

function Machine.new()
  return setmetatable({ state = "idle", history = {} }, Machine)
end

function Machine:send(event)
  local allowed = transitions[self.state]
  local nextState = allowed and allowed[event]
  if not nextState then
    return nil, string.format("%s 状态不能处理 %s", self.state, event)
  end
  self.history[#self.history + 1] = event
  self.state = nextState
  return nextState, nil
end

local machine = Machine.new()
print(machine:send("start"))
print(machine:send("pause"))
print(machine:send("start"))
print(machine:send("stop"))
print(machine:send("pause"))

print(machine.state)
print(table.concat(machine.history, ","))
''',
    output:
        'running\tnil\npaused\tnil\nrunning\tnil\nidle\tnil\nnil\tidle 状态不能处理 pause\nidle\nstart,pause,start,stop\n',
    exercises: [
      LuaExercise(
        prompt: '增加 error 状态：任何事件都能 stop 到 idle。',
        hint: '在 transitions 里加一项。',
        answer: 'transitions.error = { stop = "idle" }',
      ),
      LuaExercise(
        prompt: '为什么把转移写成数据而不是 if 链？',
        hint: '想想新增事件的成本。',
        answer: '因为数据可以集中查看和修改，新增状态不用改判断逻辑，也不容易漏分支。',
      ),
    ],
    pitfalls: ['状态名写错时会变成「非法转移」，报错信息要能看出是拼写问题。', '历史记录会无限增长，长期运行要限制长度。'],
  ),
];
