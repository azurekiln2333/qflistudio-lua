import 'lua_topic.dart';

/// 第七章：表库与常用算法。
const List<LuaTopic> topicsTableLib = [
  LuaTopic(
    id: 'lua-tlib-concat',
    chapter: 'tablelib',
    title: 'concat：把数组拼成字符串',
    summary: 'table.concat 用分隔符把数组元素连接起来，比反复 .. 更高效。',
    objective: '能用 concat 拼接数组，并知道它要求元素是字符串或数字。',
    level: 'beginner',
    concepts: ['table.concat', '分隔符', '范围'],
    explain:
        'table.concat(t, sep, i, j) 连接索引 i 到 j 的元素，默认 i=1、j=#t。'
        '它只接受字符串和数字，遇到表或布尔会报错。'
        '拼 SQL、拼 CSV 行、拼日志时都应该用它，而不是在循环里累加字符串。',
    code: r'''local words = { "Lua", "is", "small" }
print(table.concat(words, " "))
print(table.concat(words, ""))
print(table.concat({ 1, 2, 3 }, "-"))
print(table.concat(words, ",", 2, 3))

local empty = {}
print("[" .. table.concat(empty, ",") .. "]")

print(pcall(table.concat, { {}, "x" }, ","))
''',
    output:
        'Lua is small\nLuaissmall\n1-2-3\nis,small\n[]\nfalse\t'
        'invalid value (table) at index 1 in table for \'concat\'\n',
    exercises: [
      LuaExercise(
        prompt: '把数组 {1,2,3} 拼成 "1+2+3"。',
        hint: '分隔符用 +。',
        answer: 'print(table.concat({1, 2, 3}, "+"))',
      ),
      LuaExercise(
        prompt: '为什么不能直接 concat 一张记录表？',
        hint: '想想元素类型。',
        answer: '因为元素不是字符串或数字（记录表的元素可能是 nil 或者非序列），concat 只处理序列里的字符串和数字。',
      ),
    ],
    pitfalls: ['元素里有 nil 会中断连接（按 #t 的范围处理）。', '数字会被转成字符串，浮点会带上 .0。'],
  ),
  LuaTopic(
    id: 'lua-tlib-sort',
    chapter: 'tablelib',
    title: 'sort：默认升序排序',
    summary: 'table.sort 原地排序数组，默认按小于比较。',
    objective: '能用 sort 对数字和字符串数组排序，并注意它不返回新表。',
    level: 'beginner',
    concepts: ['table.sort', '原地修改', '升序'],
    explain:
        'table.sort(t) 把数组按默认顺序（数值大小、字节序）排好，返回 nil。'
        '它是原地排序：调用之后 t 本身变了，不存在「排序后的新表」。'
        '想保留原数组必须先拷贝。',
    code: r'''local numbers = { 3, 1, 4, 1, 5 }
table.sort(numbers)
print(table.concat(numbers, " "))

local words = { "pear", "apple", "fig" }
table.sort(words)
print(table.concat(words, " "))

local original = { 5, 2, 9 }
local copy = { table.unpack(original) }
table.sort(copy)
print(table.concat(original, " "), table.concat(copy, " "))
''',
    output: '1 1 3 4 5\napple fig pear\n5 2 9\t2 5 9\n',
    exercises: [
      LuaExercise(
        prompt: '降序排序一组数字。',
        hint: '传比较函数。',
        answer: 'table.sort(t, function(a, b) return a > b end)',
      ),
      LuaExercise(
        prompt: 'print(table.sort({3,1,2})) 输出什么？',
        hint: 'sort 没有返回值。',
        answer: '输出 nil，但传入的表已经被排序。',
      ),
    ],
    pitfalls: ['sort 原地修改，别指望拿到新表。', '比较函数必须形成严格弱序。'],
  ),
  LuaTopic(
    id: 'lua-tlib-sort-comparator',
    chapter: 'tablelib',
    title: '自定义比较函数',
    summary: '比较函数返回 true 表示第一个参数应排在前面。',
    objective: '能写出符合要求的比较函数，并避免常见的非法比较。',
    level: 'intermediate',
    concepts: ['比较函数', '排序', '严格弱序'],
    explain:
        'table.sort(t, comp) 中 comp(a, b) 为 true 时表示 a 排在 b 前面。'
        '比较函数必须是严格弱序：不能出现 a<b 与 b<a 同时为 true，'
        '也不能对相等元素返回 true。'
        '写错会让 sort 报 invalid order function for sorting。',
    code: r'''local numbers = { 10, 2, 33, 4 }
table.sort(numbers, function(a, b) return a > b end)
print(table.concat(numbers, " "))

local names = { "Bob", "alice", "Carol" }
table.sort(names, function(a, b) return a:lower() < b:lower() end)
print(table.concat(names, " "))

local words = { "ccc", "a", "bb" }
table.sort(words, function(a, b)
  if #a ~= #b then return #a < #b end
  return a < b
end)
print(table.concat(words, " "))
''',
    output: '33 10 4 2\nalice Bob Carol\na bb ccc\n',
    exercises: [
      LuaExercise(
        prompt: '按字符串长度降序排序，长度相同按字典序升序。',
        hint: '长度不同时比较长度。',
        answer:
            'table.sort(t, function(a, b)\n  if #a ~= #b then return #a > #b end\n  return a < b\nend)',
      ),
      LuaExercise(
        prompt: '为什么 return a <= b 会出错？',
        hint: '相等时两个方向都返回 true。',
        answer: '因为 a == b 时 comp(a,b) 和 comp(b,a) 都是 true，不满足严格弱序。',
      ),
    ],
    pitfalls: ['比较函数里用 <= 而不是 <。', '比较函数里修改表会导致不确定行为。'],
  ),
  LuaTopic(
    id: 'lua-tlib-sort-records',
    chapter: 'tablelib',
    title: '排序记录：多字段排序',
    summary: '先按主键排，主键相同再按次键，形成稳定可预期的顺序。',
    objective: '能把排序规则写成先主键后次键的比较函数。',
    level: 'intermediate',
    concepts: ['记录排序', '多字段', '比较函数'],
    explain:
        '记录排序要自己定义「谁在前」。'
        '常见写法是先比较主字段，相等时再比较第二个字段，'
        '这样结果是确定的全序，不会因为原始顺序不同而漂移。'
        '排序后再格式化输出，就能得到稳定可测的报告。',
    code: r'''local scores = {
  { name = "甲", score = 90, age = 20 },
  { name = "乙", score = 90, age = 18 },
  { name = "丙", score = 85, age = 19 },
}

table.sort(scores, function(a, b)
  if a.score ~= b.score then return a.score > b.score end
  return a.age < b.age
end)

for _, item in ipairs(scores) do
  print(string.format("%s %d %d", item.name, item.score, item.age))
end
''',
    output: '乙 90 18\n甲 90 20\n丙 85 19\n',
    exercises: [
      LuaExercise(
        prompt: '改成先按年龄升序，再按分数降序。',
        hint: '交换两个比较的先后。',
        answer:
            'if a.age ~= b.age then return a.age < b.age end\nreturn a.score > b.score',
      ),
      LuaExercise(
        prompt: '如果只比较分数会发生什么？',
        hint: '同分元素的相对顺序。',
        answer: '同分的两人顺序由原始顺序或实现决定，输出不稳定，难以断言。',
      ),
    ],
    pitfalls: ['只比较主键会让同分记录顺序不稳定。'],
  ),
  LuaTopic(
    id: 'lua-tlib-pack-unpack',
    chapter: 'tablelib',
    title: 'pack 与 unpack',
    summary: 'table.pack 记录可变参数个数，table.unpack 把数组展开成参数。',
    objective: '能用 pack 保留 nil 参与计数，用 unpack 批量传参。',
    level: 'intermediate',
    concepts: ['table.pack', 'table.unpack', '可变参数'],
    explain:
        'table.pack(...) 返回表，并在 n 字段记录参数个数，'
        '这样即使参数里有 nil 也能准确知道有几个。'
        'table.unpack(t, i, j) 把 i..j 展开成多个返回值。'
        '两者配合可以在「参数列表」和「数组」之间来回转换。',
    code: r'''local packed = table.pack(1, nil, 3)
print(#packed, packed.n, packed[3])

print(table.unpack({ 1, 2, 3 }))
print(table.unpack({ 1, 2, 3 }, 2))
print(table.unpack({ 1, 2, 3 }, 2, 3))

local function sum(...)
  local values = table.pack(...)
  local total = 0
  for i = 1, values.n do
    total = total + (values[i] or 0)
  end
  return total
end
print(sum(1, nil, 3))
print(table.pack().n)
''',
    output: '3\t3\t3\n1\t2\t3\n2\t3\n2\t3\n4\n0\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 sum 用 values.n 而不是 #values？',
        hint: '参数里有 nil。',
        answer: '因为 #values 对含 nil 的表不可靠，n 才是真实参数个数。',
      ),
      LuaExercise(
        prompt: '把 {10,20,30} 求和并输出所有值。',
        hint: 'unpack 展开后直接传给 sum。',
        answer: 'print(sum(table.unpack({10, 20, 30})))',
      ),
    ],
    pitfalls: [
      'unpack 的默认结束位置是 #t，含 nil 时会截断。',
      'pack 的 n 字段不会被 # 计算进去（它是字符串键）。',
    ],
  ),
  LuaTopic(
    id: 'lua-tlib-move',
    chapter: 'tablelib',
    title: 'table.move 复制片段',
    summary: 'table.move 在表之间搬运区间，可安全处理重叠。',
    objective: '能用 move 在数组内部搬移或复制到另一张表。',
    level: 'intermediate',
    concepts: ['table.move', '区间复制', '重叠'],
    explain:
        'table.move(a, f, e, t, b) 把 a 中 f..e 的元素搬到目标表 b 的 t 位置。'
        '省略 b 表示搬到 a 自己身上，此时它会正确处理区间重叠（相当于 memmove）。'
        '返回值是目标表，方便链式使用。',
    code: r'''local source = { 1, 2, 3, 4, 5 }
local target = {}
table.move(source, 2, 4, 1, target)
print(table.concat(target, ","))

local self = { 1, 2, 3, 4, 5 }
table.move(self, 1, 3, 2)
print(table.concat(self, ","))

local extended = { 1, 2, 3 }
table.move(extended, 1, 3, 4)
print(table.concat(extended, ","))
print(#extended)
''',
    output: '2,3,4\n1,1,2,3,5\n1,2,3,1,2,3\n6\n',
    exercises: [
      LuaExercise(
        prompt: '把数组前三个元素复制到末尾，形成两倍长度的数组。',
        hint: '目标起点设为 #t + 1。',
        answer: 'table.move(t, 1, 3, #t + 1)',
      ),
      LuaExercise(
        prompt: '省略目标表时，move 会返回什么？',
        hint: '返回值是目标表。',
        answer: '返回被修改的表自身，可以接着调用其他方法。',
      ),
    ],
    pitfalls: ['区间参数是闭区间，f..e 都包含。', '目标位置重叠时手写循环很容易写错，move 帮你处理。'],
  ),
  LuaTopic(
    id: 'lua-tlib-insert-remove',
    chapter: 'tablelib',
    title: 'insert 与 remove 的返回值',
    summary: 'insert 追加或插入元素，remove 删除并返回被删元素。',
    objective: '能用 insert/remove 维护数组，并知道 remove 的返回值用法。',
    level: 'beginner',
    concepts: ['table.insert', 'table.remove', '返回值'],
    explain:
        'table.insert(t, v) 追加到末尾，table.insert(t, pos, v) 插到指定位置并后移元素。'
        'table.remove(t) 删除末尾，table.remove(t, pos) 删除指定位置并返回它。'
        'remove 的返回值常用在「取出并删除」的场景，比如队列或随机抽取。',
    code: r'''local queue = { "a", "b", "c" }
table.insert(queue, "d")
print(table.concat(queue, ","))

table.insert(queue, 2, "x")
print(table.concat(queue, ","))

local last = table.remove(queue)
print(last, table.concat(queue, ","))

local first = table.remove(queue, 1)
print(first, table.concat(queue, ","))

print(table.remove({}), table.remove({}, 1))
''',
    output:
        'a,b,c,d\na,x,b,c,d\nd\ta,x,b,c\n'
        'a\tx,b,c\nnil\tnil\n',
    exercises: [
      LuaExercise(
        prompt: '用 insert/remove 实现一个简单的后进先出栈。',
        hint: 'push 用 insert，pop 用 remove。',
        answer: 'table.insert(stack, v)\nlocal top = table.remove(stack)',
      ),
      LuaExercise(
        prompt: '在空表上 remove 会怎样？',
        hint: '观察输出。',
        answer: '返回 nil，不会报错。',
      ),
    ],
    pitfalls: ['insert 到中间要移动元素，位置越靠前代价越大。', 'insert 的位置超出范围会报错。'],
  ),
  LuaTopic(
    id: 'lua-tlib-queue',
    chapter: 'tablelib',
    title: '用表实现队列',
    summary: '用头尾两个下标维护队列，避免每次删除都移动全部元素。',
    objective: '能实现 O(1) 出入队的环形或双下标队列。',
    level: 'advanced',
    concepts: ['队列', '双下标', '均摊复杂度'],
    explain:
        '每次 table.remove(t, 1) 都要把后面所有元素前移，队列长了会很慢。'
        '标准做法是用 head、tail 两个下标在数组里推进，出队只移动 head。'
        '当 head 超过一定规模再整体压缩一次，就能保持均摊 O(1)。',
    code: r'''local Queue = {}
Queue.__index = Queue

function Queue.new()
  return setmetatable({ items = {}, head = 1, tail = 0 }, Queue)
end

function Queue:push(value)
  self.tail = self.tail + 1
  self.items[self.tail] = value
end

function Queue:pop()
  if self.head > self.tail then return nil end
  local value = self.items[self.head]
  self.items[self.head] = nil
  self.head = self.head + 1
  return value
end

function Queue:size()
  return self.tail - self.head + 1
end

local queue = Queue.new()
for i = 1, 3 do queue:push("t" .. i) end
print(queue:size())
print(queue:pop(), queue:pop())
print(queue:size())
queue:push("t4")
print(queue:pop(), queue:pop(), queue:pop())
print(queue:size())
''',
    output: '3\nt1\tt2\n1\nt3\tt4\tnil\n0\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 pop 之后要把 items[head] 置 nil？',
        hint: '想想垃圾回收。',
        answer: '置 nil 才能让已出队的元素被回收，否则表会一直持有它。',
      ),
      LuaExercise(
        prompt: 'head 一直增长会有什么问题？',
        hint: '考虑长时间运行的程序。',
        answer: '下标不断增大、数组前部空洞变多，需要定期压缩或改用环形缓冲。',
      ),
    ],
    pitfalls: ['用 remove(t,1) 做队列在长队列上性能很差。', '忘记置 nil 会保留已出队的对象。'],
  ),
  LuaTopic(
    id: 'lua-tlib-set',
    chapter: 'tablelib',
    title: '用表实现集合运算',
    summary: '把集合表示为「键→true」，并实现并、交、差。',
    objective: '能实现并集、交集、差集，并保持输出顺序稳定。',
    level: 'intermediate',
    concepts: ['集合', '并交差', '去重'],
    explain:
        'Lua 没有内置集合类型，但把元素当键、true 当值就是集合。'
        '判断存在是 O(1)，去重只需赋值。'
        '求交集时用较小的集合遍历更省时间。'
        '输出时把键收集排序，才能得到稳定结果。',
    code: r'''local function set(list)
  local result = {}
  for _, value in ipairs(list) do result[value] = true end
  return result
end

local function union(a, b)
  local result = {}
  for key in pairs(a) do result[key] = true end
  for key in pairs(b) do result[key] = true end
  return result
end

local function intersection(a, b)
  local result = {}
  for key in pairs(a) do
    if b[key] then result[key] = true end
  end
  return result
end

local function difference(a, b)
  local result = {}
  for key in pairs(a) do
    if not b[key] then result[key] = true end
  end
  return result
end

local function show(name, values)
  local list = {}
  for key in pairs(values) do list[#list + 1] = key end
  table.sort(list)
  print(name .. ": " .. table.concat(list, ","))
end

local a = set({ "lua", "c", "go" })
local b = set({ "go", "rust" })
show("并集", union(a, b))
show("交集", intersection(a, b))
show("差集", difference(a, b))
''',
    output: '并集: c,go,lua,rust\n交集: go\n差集: c,lua\n',
    exercises: [
      LuaExercise(
        prompt: '实现「a 与 b 是否相等」的集合比较。',
        hint: '大小相同且互为子集。',
        answer: '两个集合大小相等，且 a 的每个键都在 b 中。',
      ),
      LuaExercise(
        prompt: '为什么集合里存 true 而不是元素下标？',
        hint: '想想查找方式。',
        answer: '存 true 就能用 t[value] 直接判断存在，是 O(1) 查找。',
      ),
    ],
    pitfalls: ['集合不能存 nil（nil 键会报错）。', '用 pairs 遍历集合本身顺序不稳定，输出前要排序。'],
  ),
  LuaTopic(
    id: 'lua-tlib-index',
    chapter: 'tablelib',
    title: '构建索引表加速查找',
    summary: '把数组按某个字段建成索引，重复查找从 O(n) 降到 O(1)。',
    objective: '能为记录数组建立 id 索引，并处理重复键。',
    level: 'intermediate',
    concepts: ['索引', '哈希查找', '重复键'],
    explain:
        '在一组记录里按 id 找元素，如果每次都遍历就是 O(n)。'
        '先建一张「id → 记录」的索引表，之后每次查找都是 O(1)。'
        '建索引时要决定重复 id 的处理策略：覆盖、保留第一个，或收集成列表。',
    code: r'''local users = {
  { id = 1, name = "甲" },
  { id = 2, name = "乙" },
  { id = 3, name = "丙" },
  { id = 2, name = "重复的乙" },
}

local index = {}
for _, user in ipairs(users) do
  index[user.id] = index[user.id] or user   -- 保留第一个
end

print(index[1].name, index[2].name, index[3].name)
print(index[4] == nil)

local lastWins = {}
for _, user in ipairs(users) do
  lastWins[user.id] = user
end
print(lastWins[2].name)

local byId = {}
for _, user in ipairs(users) do
  byId[user.id] = byId[user.id] or {}
  table.insert(byId[user.id], user)
end
print(#byId[2])
''',
    output: '甲\t乙\t丙\ntrue\n重复的乙\n2\n',
    exercises: [
      LuaExercise(
        prompt: '按 name 建索引，并处理同名。',
        hint: '把值改成记录列表。',
        answer:
            'byName[user.name] = byName[user.name] or {}\ntable.insert(byName[user.name], user)',
      ),
      LuaExercise(
        prompt: '索引表的代价是什么？',
        hint: '想想内存和更新。',
        answer: '多占一份内存，且原数据变动后必须同步更新索引，否则会读到旧值。',
      ),
    ],
    pitfalls: ['索引和原数组不同步会导致脏读。', '用 nil 做键的记录无法建索引。'],
  ),
  LuaTopic(
    id: 'lua-tlib-frequency',
    chapter: 'tablelib',
    title: '计数表：统计词频',
    summary: '用「键→次数」的表做频次统计，是日志分析的基础操作。',
    objective: '能统计文本中的频率并按次数排序输出。',
    level: 'intermediate',
    concepts: ['计数', '词频', '排序输出'],
    explain:
        '统计频率的模式是 t[item] = (t[item] or 0) + 1。'
        '得到计数表后，把键收集排序再输出，顺序才稳定。'
        '排序时按次数降序、次数相同按字母升序，可以得到确定的排行榜。',
    code: r'''local function frequency(list)
  local counts = {}
  for _, item in ipairs(list) do
    counts[item] = (counts[item] or 0) + 1
  end
  return counts
end

local text = "to be or not to be"
local words = {}
for word in text:gmatch("%a+") do
  words[#words + 1] = word
end

local counts = frequency(words)
local keys = {}
for key in pairs(counts) do keys[#keys + 1] = key end
table.sort(keys, function(a, b)
  if counts[a] ~= counts[b] then return counts[a] > counts[b] end
  return a < b
end)

for _, key in ipairs(keys) do
  print(string.format("%-4s %d", key, counts[key]))
end
''',
    output: 'be   2\nto   2\nnot  1\nor   1\n',
    exercises: [
      LuaExercise(
        prompt: '统计字符出现次数而不是单词。',
        hint: '用 gmatch(".") 遍历字符。',
        answer:
            'for ch in text:gmatch(".") do counts[ch] = (counts[ch] or 0) + 1 end',
      ),
      LuaExercise(
        prompt: '为什么排序时要在次数相同时再比较键？',
        hint: '稳定输出。',
        answer: '否则同频词的先后由排序实现决定，输出不稳定。',
      ),
    ],
    pitfalls: ['用数字下标做计数和用键做计数是两种不同结构，别混用。', '遍历时修改计数表可能导致意外结果。'],
  ),
];
