import 'lua_topic.dart';

/// 第六章：表的基础用法。
const List<LuaTopic> topicsTables = [
  LuaTopic(
    id: 'lua-tbl-array',
    chapter: 'tables',
    title: '数组：从 1 开始的连续表',
    summary: '用花括号构造数组，下标从 1 开始连续存放。',
    objective: '能构造数组、按下标读写，并知道为什么从 1 开始。',
    level: 'beginner',
    concepts: ['数组', '构造器', '下标'],
    explain:
        'Lua 没有专门的数组类型，数组就是键为连续整数的表。'
        '构造器 {10, 20, 30} 会自动把值放到 1、2、3 三个键上。'
        '下标从 1 开始是 Lua 的传统，写 for i = 1, #t 时非常自然；0 号位置不会被当作数组元素。',
    code: r'''local fruits = { "苹果", "香蕉", "橙子" }
print(fruits[1], fruits[2], fruits[3])
print(#fruits)

fruits[2] = "葡萄"
print(fruits[2])

fruits[4] = "西瓜"
print(#fruits, fruits[4])

local empty = {}
print(#empty)
''',
    output: '苹果\t香蕉\t橙子\n3\n葡萄\n4\t西瓜\n0\n',
    exercises: [
      LuaExercise(
        prompt: '在数组末尾追加 "桃子" 并输出新长度。',
        hint: '用 #fruits + 1 作为新下标。',
        answer: 'fruits[#fruits + 1] = "桃子"\nprint(#fruits)',
      ),
      LuaExercise(
        prompt: '访问 fruits[0] 会得到什么？',
        hint: '数组从 1 开始。',
        answer: 'nil，0 号位置没有值；它不会报错，也不会变成第一个元素。',
      ),
    ],
    pitfalls: ['下标 0 不会自动映射到第一个元素。', '在中间挖空（置 nil）会让 # 的结果不可靠。'],
  ),
  LuaTopic(
    id: 'lua-tbl-map',
    chapter: 'tables',
    title: '字典：任意键的映射',
    summary: '用字符串或数字做键，构造键值对映射。',
    objective: '能用方括号和点号访问字典，并安全处理缺失的键。',
    level: 'beginner',
    concepts: ['字典', '键值对', '方括号'],
    explain:
        '表同时是哈希表：任何非 nil 值都能当键（nil 不行）。'
        't.key 是 t["key"] 的语法糖，只适用于合法的标识符键。'
        '访问不存在的键返回 nil，所以读取前通常要用 or 给默认值。',
    code: r'''local scores = { alice = 90, bob = 85 }
print(scores.alice, scores["bob"])
print(scores.carol)

scores["carol"] = 78
print(scores.carol)

local key = "dave"
scores[key] = 60
print(scores.dave)

print(scores["not exist"] == nil)
''',
    output: '90\t85\nnil\n78\n60\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '给 alice 加分 5 分，若不存在则从 0 开始。',
        hint: '用 (scores.alice or 0)。',
        answer: 'scores.alice = (scores.alice or 0) + 5',
      ),
      LuaExercise(
        prompt: '什么时候必须用方括号而不能用点号？',
        hint: '想想键里有空格的情况。',
        answer: '键不是合法标识符时必须用方括号，例如 t["not exist"]。',
      ),
    ],
    pitfalls: ['用 nil 做键会直接报错。', '点号只接受标识符形式的键，数字键要写 t[1]。'],
  ),
  LuaTopic(
    id: 'lua-tbl-nested',
    chapter: 'tables',
    title: '嵌套表',
    summary: '表里可以放表，用连续下标或字段名逐层访问。',
    objective: '能构造并遍历嵌套表，避免在深层访问时踩 nil。',
    level: 'beginner',
    concepts: ['嵌套', '层级访问', '结构'],
    explain:
        '表的元素可以是任意值，包括另一张表，这就是表示层级数据的方式。'
        '访问时要一层层取：user.address.city，中间任何一层是 nil 都会报错。'
        '不确定时先判断中间层是否存在，或者用「安全取值」的辅助函数。',
    code: r'''local user = {
  name = "小明",
  address = { city = "杭州", zip = "310000" },
  tags = { "lua", "ide" },
}

print(user.name, user.address.city, user.address.zip)
print(user.tags[1], user.tags[2])
print(#user.tags)

local missing = user.contact
print(missing == nil)

local function safeGet(root, ...)
  local current = root
  for _, key in ipairs({ ... }) do
    if type(current) ~= "table" then return nil end
    current = current[key]
  end
  return current
end
print(safeGet(user, "address", "city"))
print(safeGet(user, "contact", "email"))
''',
    output: '小明\t杭州\t310000\nlua\tide\n2\ntrue\n杭州\nnil\n',
    exercises: [
      LuaExercise(
        prompt: '给 user 增加一个 phone 字段并输出。',
        hint: '直接在表构造器或后续赋值里加。',
        answer: 'user.phone = "13800000000"\nprint(user.phone)',
      ),
      LuaExercise(
        prompt: '为什么 user.contact.email 会报错？',
        hint: '想想 contact 是 nil。',
        answer:
            '因为 user.contact 是 nil，再对 nil 取字段会抛 attempt to index a nil value。',
      ),
    ],
    pitfalls: ['深层访问前要保证中间层不是 nil。', '嵌套表的修改会反映到所有引用它的地方（表是引用类型）。'],
  ),
  LuaTopic(
    id: 'lua-tbl-length',
    chapter: 'tables',
    title: '# 长度与空洞',
    summary: '#t 只在序列连续时可靠，中间挖空后结果不确定。',
    objective: '能判断一张表是不是连续序列，并避免在空洞表上用 #。',
    level: 'intermediate',
    concepts: ['长度', '序列', '空洞'],
    explain:
        '#t 返回一个边界：t[#t] 非 nil 且 t[#t+1] 为 nil。'
        '当表是连续序列（1..n 都有值）时这个边界就是元素个数。'
        '一旦中间有 nil，边界可能落在任意位置，所以「有空洞的表」不能用 # 当元素总数。',
    code: r'''local list = { 10, 20, 30 }
print(#list)

list[2] = nil
local length = #list
print(length == 3 or length == 1)

local contiguous = {}
for i = 1, 5 do contiguous[i] = i * i end
print(#contiguous, contiguous[#contiguous])

local holes = { 1, nil, 3 }
print(#holes == 3 or #holes == 1)

local explicit = { n = 3, 10, 20, 30 }
print(#explicit, explicit.n)
''',
    output: '3\ntrue\n5\t25\ntrue\n3\t3\n',
    exercises: [
      LuaExercise(
        prompt: '统计一张可能含空洞的表里非 nil 元素的个数。',
        hint: '用 pairs 计数，而不是 #。',
        answer: 'local count = 0\nfor _ in pairs(t) do count = count + 1 end',
      ),
      LuaExercise(
        prompt: '为什么推荐用显式 n 字段记录数量？',
        hint: '考虑删除元素后 # 的变化。',
        answer: '因为删除中间元素后 # 不再等于元素个数，显式计数与 # 无关，稳定可靠。',
      ),
    ],
    pitfalls: ['把 nil 写进表等于删除该键。', 'table.insert 在含空洞的表上行为不确定。'],
  ),
  LuaTopic(
    id: 'lua-tbl-ipairs',
    chapter: 'tables',
    title: 'ipairs：按顺序遍历数组',
    summary: 'ipairs 从 1 开始连续遍历，遇到 nil 立即停止。',
    objective: '能用 ipairs 遍历数组并知道它为什么会在空洞处停下。',
    level: 'beginner',
    concepts: ['ipairs', '遍历', '数组'],
    explain:
        'ipairs(t) 依次返回 1、2、3…直到遇到 nil 为止，是遍历数组的标准方式。'
        '它不保证能看到所有非 nil 元素：一旦中间有 nil 就提前结束。'
        '遍历字典要用 pairs；遍历数组用 ipairs 更安全，因为它不会访问 0 或字符串键。',
    code: r'''local names = { "甲", "乙", "丙" }
for index, name in ipairs(names) do
  print(index .. ":" .. name)
end

names[2] = nil
for index, name in ipairs(names) do
  print("剩余 " .. index .. ":" .. name)
end

local total = 0
for _, value in ipairs({ 1, 2, 3, 4 }) do
  total = total + value
end
print(total)
''',
    output: '1:甲\n2:乙\n3:丙\n剩余 1:甲\n10\n',
    exercises: [
      LuaExercise(
        prompt: '用 ipairs 求数组元素的最大值。',
        hint: '用 math.max 和局部变量。',
        answer:
            'local max = 0\nfor _, v in ipairs(nums) do max = math.max(max, v) end',
      ),
      LuaExercise(
        prompt: '为什么 names[2] = nil 后只输出了一项？',
        hint: 'ipairs 遇 nil 停止。',
        answer: 'ipairs 在 index 2 读到 nil 就停止迭代，所以后面的 3 也看不到了。',
      ),
    ],
    pitfalls: ['ipairs 会漏掉 nil 之后的元素。', 'ipairs 的第二个返回值是值，不是键值对。'],
  ),
  LuaTopic(
    id: 'lua-tbl-pairs-sorted',
    chapter: 'tables',
    title: 'pairs 遍历与稳定输出',
    summary: 'pairs 能遍历所有键，但顺序不固定，输出前要先排序。',
    objective: '能用 pairs 收集键、排序后稳定输出字典内容。',
    level: 'beginner',
    concepts: ['pairs', '排序', '稳定输出'],
    explain:
        'pairs(t) 遍历所有键值对，顺序由哈希决定，多次运行可能不同。'
        '需要可比较的输出时，先把键收集到数组，用 table.sort 排序，再按顺序取值。'
        '这是让教学内容、测试和日志都可重复的基本手法。',
    code: r'''local inventory = { apple = 3, banana = 12, cherry = 7 }

local keys = {}
for key in pairs(inventory) do
  keys[#keys + 1] = key
end
table.sort(keys)

for _, key in ipairs(keys) do
  print(key .. "=" .. inventory[key])
end

local count = 0
for _ in pairs(inventory) do count = count + 1 end
print("共 " .. count .. " 项")
''',
    output: 'apple=3\nbanana=12\ncherry=7\n共 3 项\n',
    exercises: [
      LuaExercise(
        prompt: '按值从大到小输出 inventory。',
        hint: '排序比较函数里比较两个键对应的值。',
        answer:
            'table.sort(keys, function(a, b) return inventory[a] > inventory[b] end)',
      ),
      LuaExercise(
        prompt: '为什么不能直接用 pairs 的顺序做断言？',
        hint: '哈希顺序不保证。',
        answer: 'pairs 的顺序未定义，可能随键集合或版本变化，断言会不稳定。',
      ),
    ],
    pitfalls: ['遍历时不要新增键，Lua 允许但行为难以预测。', '数字键和字符串键会混在一起遍历。'],
  ),
  LuaTopic(
    id: 'lua-tbl-record',
    chapter: 'tables',
    title: '记录式表：用字段表达对象',
    summary: '用命名字段表示一条记录，可读性远高于下标数组。',
    objective: '能用记录式表组织结构化数据，并写出格式化的输出函数。',
    level: 'beginner',
    concepts: ['记录', '字段', '格式化'],
    explain:
        '一条记录就是一张字段固定的表：{ name = ..., age = ... }。'
        '相比 { "小明", 18 }，字段名让调用方不必记顺序，也方便后续加字段。'
        '配合 string.format 写一个 describe 函数，就能把记录稳定地打印出来。',
    code: r'''local function describe(person)
  return string.format("%s（%d 岁，%s）",
    person.name, person.age, person.city or "未填写")
end

local alice = { name = "Alice", age = 30, city = "上海" }
local bob = { name = "Bob", age = 25 }

print(describe(alice))
print(describe(bob))
print(alice.name, bob.city == nil)
''',
    output: 'Alice（30 岁，上海）\nBob（25 岁，未填写）\nAlice\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '给记录加一个 email 字段并在 describe 里输出。',
        hint: '记得处理缺失值。',
        answer: '在 describe 里加 person.email or "无"，并在表里补 email 字段。',
      ),
      LuaExercise(
        prompt: '为什么记录式表比数组更抗改动？',
        hint: '想想增加字段的影响。',
        answer: '字段名定位，新增字段不会改变已有字段的位置和含义。',
      ),
    ],
    pitfalls: ['字段名拼错会静默得到 nil。', '记录式表不能用 # 取长度，因为它不是序列。'],
  ),
  LuaTopic(
    id: 'lua-tbl-field-access',
    chapter: 'tables',
    title: '点号与方括号等价',
    summary: 't.x 与 t["x"] 是同一件事，构造器里两种写法也能混用。',
    objective: '能在构造器和访问中自由选择两种写法，并理解键的类型要求。',
    level: 'beginner',
    concepts: ['点号', '方括号', '键类型'],
    explain:
        't.x 只是 t["x"] 的语法糖，编译后完全相同。'
        '构造器里 name = value 与 ["name"] = value 也等价。'
        '方括号里可以放变量或表达式，这是点号做不到的；'
        '而键是数字时必须用方括号。',
    code: r'''local t = { x = 1, ["y"] = 2, [3] = "three" }
print(t.x, t.y, t[3])

local field = "x"
print(t[field])

t["z"] = 9
print(t.z)

t[1] = "first"
print(t[1])

local numeric = { [1] = "a", [2] = "b" }
print(#numeric, numeric[1], numeric[2])
''',
    output: '1\t2\tthree\n1\n9\nfirst\n2\ta\tb\n',
    exercises: [
      LuaExercise(
        prompt: '用变量作为键写入并读取。',
        hint: '两边都用方括号。',
        answer: 'local k = "mode"\nt[k] = "fast"\nprint(t[k])',
      ),
      LuaExercise(
        prompt: 't.1 合法吗？',
        hint: '点号后面要求标识符。',
        answer: '不合法，数字键必须写成 t[1]。',
      ),
    ],
    pitfalls: ['t["x"] 和 t.x 访问同一个键，不要以为它们是两个字段。'],
  ),
  LuaTopic(
    id: 'lua-tbl-method',
    chapter: 'tables',
    title: '冒号调用与 self',
    summary: 't:m(args) 等价于 t.m(t, args)，冒号会自动传入自身。',
    objective: '能定义和调用表方法，并知道点号调用时要显式传 self。',
    level: 'intermediate',
    concepts: ['方法', 'self', '冒号'],
    explain:
        '把函数放进表里就是方法。定义时写 function t:m() 等价于 function t.m(self)，'
        '调用时 t:m() 会把 t 作为第一个参数传进去。'
        '用点号调用时必须自己传 self，否则函数里的 self 是 nil。',
    code: r'''local counter = { value = 0 }

function counter:inc(step)
  self.value = self.value + (step or 1)
  return self.value
end

function counter:reset()
  self.value = 0
end

print(counter:inc())
print(counter:inc(5))
counter:reset()
print(counter.value)

print(counter.inc(counter, 2))
print(counter.value)
''',
    output: '1\n6\n0\n2\n2\n',
    exercises: [
      LuaExercise(
        prompt: '用点号调用 inc 并传入 3。',
        hint: '需要显式传 counter。',
        answer: 'counter.inc(counter, 3)',
      ),
      LuaExercise(
        prompt: '如果写成 function counter.inc() 里用 self 会发生什么？',
        hint: '点号定义没有隐式 self 参数。',
        answer: 'self 会是 nil（全局变量），访问 self.value 直接报错。',
      ),
    ],
    pitfalls: [
      '冒号调用 t:m(x) 等价于 t.m(t, x)；点号调用时若显式传入 t 也能正确工作，关键是参数是否匹配。',
      '把方法取出来单独调用（local f = t.m）会丢失 self。',
    ],
  ),
  LuaTopic(
    id: 'lua-tbl-matrix',
    chapter: 'tables',
    title: '二维表：矩阵与网格',
    summary: '用「表里放表」表示二维网格，双重循环处理每个格子。',
    objective: '能构造矩阵、按行列访问，并输出对齐的网格。',
    level: 'intermediate',
    concepts: ['二维表', '矩阵', '双重循环'],
    explain:
        '二维表就是每一行也是一张表：matrix[row][col]。'
        '构造时通常用双重循环逐行生成，这样每行是独立的表，'
        '不会因为共用同一张表而互相影响——这是新手最容易踩的坑。',
    code: r'''local rows, cols = 3, 4
local grid = {}
for row = 1, rows do
  grid[row] = {}
  for col = 1, cols do
    grid[row][col] = row * col
  end
end

for row = 1, rows do
  local line = {}
  for col = 1, cols do
    line[#line + 1] = string.format("%3d", grid[row][col])
  end
  print(table.concat(line, ""))
end

print(grid[2][3])
''',
    output: '  1  2  3  4\n  2  4  6  8\n  3  6  9 12\n6\n',
    exercises: [
      LuaExercise(
        prompt: '计算矩阵所有元素的和。',
        hint: '双重循环累加。',
        answer:
            'local total = 0\nfor r = 1, rows do for c = 1, cols do total = total + grid[r][c] end end',
      ),
      LuaExercise(
        prompt: '为什么不能写 local row = {} 再在循环里 grid[i] = row？',
        hint: '表是引用类型。',
        answer: '那样所有行都指向同一张表，改一行会影响所有行。',
      ),
    ],
    pitfalls: ['复用同一张内层表会导致所有行共享数据。'],
  ),
  LuaTopic(
    id: 'lua-tbl-reference',
    chapter: 'tables',
    title: '表是引用类型',
    summary: '赋值复制的是引用，要独立副本必须逐层拷贝。',
    objective: '能解释两个变量指向同一张表的现象，并写出浅拷贝与深拷贝。',
    level: 'intermediate',
    concepts: ['引用', '浅拷贝', '深拷贝'],
    explain:
        '表是引用类型：b = a 之后两个名字指向同一张表，改 b 就是改 a。'
        '要得到独立副本需要显式拷贝。浅拷贝只复制第一层，'
        '嵌套表仍然共享；深拷贝要递归处理。',
    code: r'''local original = { 1, 2, 3 }
local alias = original
alias[1] = 100
print(original[1])

local function shallowCopy(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

local copy = shallowCopy(original)
copy[2] = 200
print(original[2], copy[2])

local nested = { inner = { value = 1 } }
local shallow = shallowCopy(nested)
shallow.inner.value = 9
print(nested.inner.value)

local function deepCopy(source)
  if type(source) ~= "table" then return source end
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = deepCopy(value)
  end
  return copy
end

local deep = deepCopy(nested)
deep.inner.value = 42
print(nested.inner.value, deep.inner.value)
''',
    output: '100\n2\t200\n9\n9\t42\n',
    exercises: [
      LuaExercise(
        prompt: '验证两个变量是否指向同一张表。',
        hint: '直接比较引用。',
        answer: 'print(original == alias)  -- true，表比较的是引用',
      ),
      LuaExercise(
        prompt: '浅拷贝为什么改不动第一层，却改得动嵌套层？',
        hint: '想想嵌套层存的是什么。',
        answer: '第一层的值被复制成新表，但嵌套层的值仍然是同一个表的引用。',
      ),
    ],
    pitfalls: ['== 比较表时比较引用，不是内容。', '深拷贝遇到循环引用会无限递归，需要记录已访问的表。'],
  ),
];
