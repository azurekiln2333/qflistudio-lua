import 'lua_topic.dart';

/// 第二十四章：更多项目实践。
const List<LuaTopic> topicsPractice = [
  LuaTopic(
    id: 'lua-pra-template',
    chapter: 'project',
    title: '模板渲染',
    summary: '用 gsub 把 {{name}} 替换成表里的值，缺失时保留原样或替换为空串。',
    objective: '能实现简单的模板变量替换，并选择缺失变量的处理策略。',
    level: 'beginner',
    concepts: ['模板', 'gsub', '缺失处理'],
    explain:
        '模板变量写成 {{key}}，用 gsub 匹配双花括号并查表替换。'
        '缺失的键有两种策略：保留原文便于发现，或替换成空串。'
        '替换函数返回 nil 或 false 会保留原匹配文本；返回空字符串才会删除匹配。',
    code: r'''local function render(template, values, keepMissing)
  return (template:gsub("{{%s*([%w_]+)%s*}}", function(key)
    local value = values[key]
    if value == nil then
      if keepMissing then return nil end
      return ""
    end
    return tostring(value)
  end))
end

print(render("你好，{{name}}！", { name = "小明" }))
print(render("{{a}} + {{b}} = {{c}}", { a = 1, b = 2, c = 3 }))
print(render("缺失：{{missing}}", {}))
print(render("缺失：{{missing}}", {}, true))
print(render("没有变量", {}))
print(render("{{ name }}", { name = "宽松匹配" }))
''',
    output:
        '你好，小明！\n1 + 2 = 3\n缺失：\n缺失：{{missing}}\n'
        '没有变量\n宽松匹配\n',
    exercises: [
      LuaExercise(
        prompt: '让缺失变量渲染成 "[缺失:key]"。',
        hint: '在 value == nil 分支返回拼接串。',
        answer: 'if value == nil then return "[缺失:" .. key .. "]" end',
      ),
      LuaExercise(
        prompt: 'keepMissing 分支为什么返回 nil 而不是空字符串？',
        hint: 'gsub 如何处理 nil、false 与 ""？',
        answer: 'nil 或 false 表示保留整个原匹配，所以包括花括号在内的文本保持原样；返回 "" 才删除它。',
      ),
    ],
    pitfalls: [
      '替换函数返回 nil 或 false 会保留匹配；即使没有改动文本，这次匹配也会计入 gsub 的次数。',
      '值里含 {{ }} 时不会递归替换。',
    ],
  ),
  LuaTopic(
    id: 'lua-pra-pagination',
    chapter: 'project',
    title: '分页计算',
    summary: '把总数和每页大小换算成页数、起始下标与当前页内容。',
    objective: '能写出不越界的分页函数，并处理空数据与非法页码。',
    level: 'beginner',
    concepts: ['分页', '边界', '取整'],
    explain:
        '页数用 (total + size - 1) // size 向上取整。'
        '页码从 1 开始，超出范围时要钳制，'
        '否则 sub/slice 会返回空表，界面看起来像没数据。',
    code: r'''local function pageCount(total, size)
  if size <= 0 then return 0 end
  return (total + size - 1) // size
end

print(pageCount(10, 3))
print(pageCount(9, 3))
print(pageCount(0, 3))
print(pageCount(5, 0))

local function slice(items, page, size)
  local pages = pageCount(#items, size)
  if page < 1 then page = 1 end
  if pages > 0 and page > pages then page = pages end
  local first = (page - 1) * size + 1
  local last = math.min(first + size - 1, #items)
  local out = {}
  for index = first, last do out[#out + 1] = items[index] end
  return out, pages
end

local items = { "a", "b", "c", "d", "e" }
local first, pages = slice(items, 1, 2)
print(table.concat(first, ","), pages)

local second = slice(items, 2, 2)
print(table.concat(second, ","))

local fixed = slice(items, 99, 2)
print(table.concat(fixed, ","))

print(#slice({}, 1, 2))
''',
    output: '4\n3\n0\n0\na,b\t3\nc,d\ne\n0\n',
    exercises: [
      LuaExercise(
        prompt: '取最后一页并输出内容。',
        hint: '页码传 pageCount 的结果。',
        answer:
            'local pages = pageCount(#items, 2)\nprint(table.concat((slice(items, pages, 2)), ","))',
      ),
      LuaExercise(
        prompt: '为什么页码要钳制？',
        hint: '想想用户输入 99。',
        answer: '因为越界页码会让区间为空，界面显示空白，钳制后至少能显示最后一页。',
      ),
    ],
    pitfalls: ['size 为 0 会导致除零或死循环，必须先校验。', '起始下标算错一位是最常见的分页 bug。'],
  ),
  LuaTopic(
    id: 'lua-pra-event-bus',
    chapter: 'project',
    title: '事件订阅与发布',
    summary: '用表存回调列表，订阅、发布、退订三件事就够了。',
    objective: '能实现同步事件总线，并在发布时避免遍历被修改。',
    level: 'intermediate',
    concepts: ['事件', '回调', '遍历安全'],
    explain:
        'events[名称] 存回调数组，on 追加、emit 逐个调用、off 移除。'
        'emit 遍历时如果回调里又 on/off，可能改到正在遍历的表，'
        '所以先复制一份再遍历。',
    code: r'''local function newBus()
  local events = {}
  local bus = {}

  function bus.on(name, handler)
    events[name] = events[name] or {}
    local list = events[name]
    list[#list + 1] = handler
    return function()
      for index, existing in ipairs(list) do
        if existing == handler then
          table.remove(list, index)
          return
        end
      end
    end
  end

  function bus.emit(name, ...)
    local list = events[name]
    if not list then return 0 end
    local snapshot = {}
    for index, handler in ipairs(list) do snapshot[index] = handler end
    local calls = 0
    for _, handler in ipairs(snapshot) do
      handler(...)
      calls = calls + 1
    end
    return calls
  end

  return bus
end

local bus = newBus()
local log = {}

bus.on("greet", function(name) log[#log + 1] = "A:" .. name end)
local off = bus.on("greet", function(name) log[#log + 1] = "B:" .. name end)

print(bus.emit("greet", "小明"))
print(table.concat(log, ","))

off()
print(bus.emit("greet", "小红"))
print(table.concat(log, ","))
print(bus.emit("unknown"))
''',
    output: '2\nA:小明,B:小明\n1\nA:小明,B:小明,A:小红\n0\n',
    exercises: [
      LuaExercise(
        prompt: '订阅时返回的函数用来做什么？',
        hint: '看看 off 的实现。',
        answer: '它把这次订阅的回调从列表里移除，实现「退订」而不用记下标。',
      ),
      LuaExercise(
        prompt: '为什么 emit 要复制一份列表？',
        hint: '想想回调里 on/off。',
        answer: '因为回调可能在遍历过程中修改列表，直接用原表会跳过元素或越界。',
      ),
    ],
    pitfalls: ['回调里抛错会中断后续订阅者，需要 pcall 隔离。', '忘记退订会让回调越积越多。'],
  ),
  LuaTopic(
    id: 'lua-pra-rate-limit',
    chapter: 'project',
    title: '简易限流',
    summary: '用固定窗口计数限制「每个窗口最多 N 次」。',
    objective: '能实现固定窗口限流，并说明它与滑动窗口的差别。',
    level: 'intermediate',
    concepts: ['限流', '窗口', '计数'],
    explain:
        '固定窗口最常见：记录当前窗口起点和计数，'
        '窗口内计数加一，超过上限就拒绝，'
        '时间越过窗口边界时重置。'
        '缺点是窗口边界处可能出现两倍突发。',
    code: r'''local function newLimiter(limit, windowSeconds)
  local windowStart = 0
  local used = 0

  return function(now)
    if now - windowStart >= windowSeconds then
      windowStart = now
      used = 0
    end
    if used >= limit then return false, used end
    used = used + 1
    return true, used
  end
end

local allow = newLimiter(2, 10)

print(allow(0))
print(allow(1))
print(allow(2))
print(allow(9))
print(allow(10))
print(allow(11))
print(allow(30))
''',
    output: 'true\t1\ntrue\t2\nfalse\t2\nfalse\t2\ntrue\t1\ntrue\t2\ntrue\t1\n',
    exercises: [
      LuaExercise(
        prompt: '把窗口改成 5 秒、上限 3 次并测试跨窗口。',
        hint: '改参数再调用。',
        answer:
            'local a = newLimiter(3, 5); print(a(0), a(0), a(0), a(0), a(5))',
      ),
      LuaExercise(
        prompt: '固定窗口有什么已知缺陷？',
        hint: '想想窗口边界。',
        answer: '在窗口末尾和下一个窗口开头各打满配额时，短时间内会出现两倍于上限的请求。',
      ),
    ],
    pitfalls: ['时间来源要一致，不要混用 os.time 和 os.clock。', '固定窗口不是精确限流，强一致场景要用令牌桶。'],
  ),
  LuaTopic(
    id: 'lua-pra-migration',
    chapter: 'project',
    title: '数据版本迁移',
    summary: '按版本号逐级升级数据，每步只关心相邻版本之间的差异。',
    objective: '能写出可按序执行的迁移链，并跳过已是最新的数据。',
    level: 'advanced',
    concepts: ['迁移', '版本号', '顺序执行'],
    explain:
        '给数据加 version 字段，定义从 v 到 v+1 的迁移函数。'
        '升级时从当前版本一路跑到最新版本，'
        '这样每个迁移只需要处理一小步，也便于逐个测试。',
    code: r'''local migrations = {
  [1] = function(data)
    data.nickname = data.name
    data.name = nil
    return data
  end,
  [2] = function(data)
    data.tags = data.tags or {}
    return data
  end,
  [3] = function(data)
    data.active = true
    return data
  end,
}

local LATEST = 3

local function migrate(data)
  local version = data.version or 0
  local applied = 0
  while version < LATEST do
    version = version + 1
    local step = migrations[version]
    if not step then return nil, "缺少迁移 " .. version end
    data = step(data)
    data.version = version
    applied = applied + 1
  end
  return data, nil, applied
end

local old = { version = 1, nickname = "小明" }
local upgraded, err, applied = migrate(old)
print(upgraded.version, applied)
print(upgraded.nickname == "小明")
print(#upgraded.tags)
print(upgraded.active)

local fresh = { version = 3, active = true }
local same, _, count = migrate(fresh)
print(same.version, count)

local broken = migrate({ version = 2, tags = nil })
print(broken.version, broken.tags ~= nil)
''',
    output: '3\t2\ntrue\n0\ntrue\n3\t0\n3\tfalse\n',
    exercises: [
      LuaExercise(
        prompt: '加一个迁移 4：补 status 字段为 "new"。',
        hint: '写 migrations[4] 并把 LATEST 改成 4。',
        answer: 'migrations[4] = function(d) d.status = "new" return d end',
      ),
      LuaExercise(
        prompt: '为什么从 version=2 开始的数据没有 tags？',
        hint: '想想哪一步负责补 tags。',
        answer:
            '因为补 tags 的是迁移 2，已经 version=2 的数据会跳过它；所以迁移要幂等，或者版本号要如实反映已执行的步数。',
      ),
    ],
    pitfalls: ['迁移顺序错了会把字段改名两次。', '缺少某一步要显式报错，静默跳过会造成数据不一致。'],
  ),
  LuaTopic(
    id: 'lua-pra-inventory',
    chapter: 'project',
    title: '库存扣减与事务',
    summary: '先校验再修改，保证失败时不留半成品状态。',
    objective: '能实现全成或全不成的批量扣减，并返回具体失败原因。',
    level: 'intermediate',
    concepts: ['事务', '校验先行', '回滚'],
    explain:
        '批量操作要先整体校验，全部通过后再统一写入。'
        '如果边校验边写，中途失败就会留下部分扣减的脏数据。'
        '这是最朴素的「两阶段」思想。',
    code: r'''local inventory = { apple = 5, banana = 1, cherry = 0 }

local function deductAll(requests)
  for _, request in ipairs(requests) do
    local stock = inventory[request.item]
    if stock == nil then return nil, "未知商品：" .. request.item end
    if stock < request.count then
      return nil, string.format("%s 库存不足（需要 %d，剩余 %d）",
        request.item, request.count, stock)
    end
  end

  for _, request in ipairs(requests) do
    inventory[request.item] = inventory[request.item] - request.count
  end
  return true, nil
end

print(deductAll({ { item = "apple", count = 2 }, { item = "banana", count = 1 } }))
print(inventory.apple, inventory.banana)

local ok, err = deductAll({ { item = "apple", count = 1 }, { item = "banana", count = 5 } })
print(ok, err)
print(inventory.apple, inventory.banana)

local ok2, err2 = deductAll({ { item = "durian", count = 1 } })
print(ok2, err2)

print(deductAll({}))
''',
    output:
        'true\tnil\n3\t0\nnil\tbanana 库存不足（需要 5，剩余 0）\n3\t0\n'
        'nil\t未知商品：durian\ntrue\tnil\n',
    exercises: [
      LuaExercise(
        prompt: '为什么第二个请求失败后 apple 没有被扣？',
        hint: '看看两段循环。',
        answer: '因为校验阶段就返回了，写入阶段根本没开始，所以不会有部分扣减。',
      ),
      LuaExercise(
        prompt: '空请求列表为什么返回成功？',
        hint: '想想空集合的语义。',
        answer: '因为没有任何操作需要执行，空操作视为成功，这也是事务的常见约定。',
      ),
    ],
    pitfalls: ['边校验边修改会在中途失败时留下脏数据。', '同一请求里重复的商品要合并，否则校验时看到的是旧库存。'],
  ),
  LuaTopic(
    id: 'lua-pra-json-like',
    chapter: 'project',
    title: '输出可读的结构化文本',
    summary: '把嵌套表转成缩进文本，便于对比和人工检查。',
    objective: '能写出带缩进的递归序列化，并处理循环引用。',
    level: 'advanced',
    concepts: ['递归', '缩进', '循环引用'],
    explain:
        '递归序列化要解决三件事：'
        '类型分派（数字/字符串/布尔/表）、'
        '保持序列顺序与排序对象字段、'
        '以及用当前递归路径的 visited 表检测循环引用。'
        '这里只显示连续序列或字符串键对象，输出用于调试，不是 JSON 编码器。',
    code: r'''local function serialize(value, indent, visited)
  indent = indent or 0
  visited = visited or {}
  local pad = string.rep("  ", indent)

  if type(value) == "string" then
    local escapes = { ['\\'] = '\\\\', ['"'] = '\\"',
      ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return '"' .. value:gsub('[%z\1-\31\\"]', function(ch)
      return escapes[ch] or string.format("\\x%02X", string.byte(ch))
    end) .. '"'
  end
  if type(value) ~= "table" then
    return tostring(value)
  end
  if visited[value] then return "<cycle>" end
  visited[value] = true

  local length, count = #value, 0
  local isArray = length > 0
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > length then
      isArray = false
    end
  end
  isArray = isArray and count == length
  local lines = {}
  if isArray then
    for index = 1, length do
      lines[#lines + 1] = string.rep("  ", indent + 1)
        .. serialize(value[index], indent + 1, visited)
    end
  else
    local keys = {}
    for key in pairs(value) do
      assert(type(key) == "string", "对象分支只支持字符串键")
      keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      lines[#lines + 1] = string.rep("  ", indent + 1)
        .. key .. " = " .. serialize(value[key], indent + 1, visited)
    end
  end
  visited[value] = nil

  if #lines == 0 then return "{}" end
  return "{\n" .. table.concat(lines, ",\n") .. "\n" .. pad .. "}"
end

print(serialize({ 1, 2 }))
print(serialize({ name = "lua" }))
print(serialize({ a = { 1 } }))

local cyclic = {}
cyclic.self = cyclic
print(serialize(cyclic))
print(serialize({ s = 'say "hi"' }))
print(serialize({ 10, 2, 1 }))
local shared = { 7 }
local sharedText = serialize({ left = shared, right = shared })
print(sharedText:find("<cycle>", 1, true) == nil)
''',
    output:
        '{\n  1,\n  2\n}\n{\n  name = "lua"\n}\n{\n  a = {\n    1\n  }\n}\n'
        '{\n  self = <cycle>\n}\n{\n  s = "say \\"hi\\""\n}\n'
        '{\n  10,\n  2,\n  1\n}\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '为什么只排序对象的键，不排序序列渲染后的文本？',
        hint: '序列顺序本来就有含义。',
        answer:
            '序列应按 1..n 的下标保留顺序，按文本排序会把 10 排到 2 前面；对象没有数组顺序，所以排序字符串键来获得稳定输出。',
      ),
      LuaExercise(
        prompt: 'visited 表解决什么问题？',
        hint: '想想自引用。',
        answer: '记录当前递归路径上的表，遇到同一表说明成环；返回前清除标记，避免把另一个字段共享同一子表误判为循环。',
      ),
    ],
    pitfalls: [
      '#value > 0 不足以判断序列，还要检查键集合连续；本示例对稀疏数字键和混合键表明确报错。',
      '调试文本不是 JSON；生产序列化还需明确类型、键、数字与转义规范。',
    ],
  ),
];
