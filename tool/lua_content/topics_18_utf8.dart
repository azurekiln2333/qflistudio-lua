import 'lua_topic.dart';

/// 第十八章：utf8 库。
const List<LuaTopic> topicsUtf8 = [
  LuaTopic(
    id: 'lua-utf8-char-codepoint',
    chapter: 'utf8',
    title: 'utf8.char 与 utf8.codepoint',
    summary: '在码点和字符之间转换，正确处理多字节字符。',
    objective: '能用 char/codepoint 转换单个字符，并知道与 byte/char 的区别。',
    level: 'beginner',
    concepts: ['utf8.char', 'utf8.codepoint', '码点'],
    explain:
        'utf8.codepoint(s, i) 返回第 i 个字节开始的那个字符的码点。'
        'utf8.char(code) 用码点构造字符，与 string.char 只处理单字节不同。'
        '一个汉字的码点通常大于 20000，远超过 255。',
    code: r'''print(utf8.char(65))
print(utf8.char(20013))
print(#utf8.char(20013))

print(utf8.codepoint("中"))
print(utf8.codepoint("A"))
print(utf8.codepoint("中文", 1, -1))

print(pcall(string.char, 20013) == false)
print(utf8.len("中文"))
print(#"中文")
''',
    output: 'A\n中\n3\n20013\n65\n20013\t25991\ntrue\n2\n6\n',
    exercises: [
      LuaExercise(
        prompt: '输出 "Lua" 三个字符的码点。',
        hint: 'codepoint(1, -1)。',
        answer: 'print(utf8.codepoint("Lua", 1, -1))  -- 76 117 97',
      ),
      LuaExercise(
        prompt: '为什么 string.char(20013) 会失败？',
        hint: '参数范围。',
        answer: '因为 string.char 只接受 0..255 的字节值，20013 超出范围。',
      ),
    ],
    pitfalls: [
      'codepoint 的下标是字节位置，不是字符序号。',
      'string.char 与 utf8.char 的适用范围完全不同。',
    ],
  ),
  LuaTopic(
    id: 'lua-utf8-codes-iterate',
    chapter: 'utf8',
    title: '用 utf8.codes 遍历字符',
    summary: 'codes 返回「字节位置, 码点」的迭代器，适合逐字符处理。',
    objective: '能用 codes 遍历字符并同时获得位置信息。',
    level: 'beginner',
    concepts: ['utf8.codes', '遍历', '位置'],
    explain:
        'for position, code in utf8.codes(text) do ... end'
        ' 每轮给出字符起始字节位置和码点。'
        '和 utf8.codepoint 不同，codes 是按字符推进的，'
        '所以处理中文时不会把字节切断。',
    code: r'''local text = "a中b"

for position, code in utf8.codes(text) do
  print(position, code, utf8.char(code))
end

local count = 0
for _ in utf8.codes(text) do count = count + 1 end
print(count, utf8.len(text))

local positions = {}
for position in utf8.codes(text) do positions[#positions + 1] = position end
print(table.concat(positions, ","))
''',
    output: '1\t97\ta\n2\t20013\t中\n5\t98\tb\n3\t3\n1,2,5\n',
    exercises: [
      LuaExercise(
        prompt: '用 codes 数一数字符串有多少个字符。',
        hint: '累加计数器。',
        answer: 'local n = 0\nfor _ in utf8.codes("中文") do n = n + 1 end',
      ),
      LuaExercise(
        prompt: '为什么第二个字符的位置是 2 而不是 2 之后的 3？',
        hint: '位置是起始字节。',
        answer: '因为位置表示该字符的起始字节下标，"中" 占 2、3、4 三个字节，下一个字符从 5 开始。',
      ),
    ],
    pitfalls: [
      'codes 遇到非法 UTF-8 会报错，可用 pcall 或 utf8.len 先行检查。',
      'codes 给出的位置是字节下标，不是字符序号。',
    ],
  ),
  LuaTopic(
    id: 'lua-utf8-len',
    chapter: 'utf8',
    title: 'utf8.len 与非法字节',
    summary: 'len 返回字符数，遇到非法序列返回 nil 和位置。',
    objective: '能用 utf8.len 校验字符串是否合法，并定位非法字节。',
    level: 'beginner',
    concepts: ['utf8.len', '校验', '错误位置'],
    explain:
        'utf8.len(s) 返回字符数（不是字节数）。'
        '如果字符串包含非法 UTF-8 序列，返回 nil 和第一个坏字节的位置。'
        '这是低成本校验外部输入的好办法。',
    code: r'''print(utf8.len("中文"))
print(utf8.len("abc"))
print(utf8.len(""))

local bad = string.char(0xE4, 0xB8)
print(utf8.len(bad))

local broken = "ab" .. string.char(0xFF)
local length, position = utf8.len(broken)
print(length, position)

print(utf8.len("中", 2))
print(utf8.len("中", 1, 3))
print(#"中文" - utf8.len("中文"))
''',
    output: '2\n3\n0\nnil\t1\nnil\t3\nnil\t2\n1\n4\n',
    exercises: [
      LuaExercise(
        prompt: '判断一个字符串是否是合法 UTF-8。',
        hint: '看 len 的返回值。',
        answer: 'local function isValid(s) return (utf8.len(s)) ~= nil end',
      ),
      LuaExercise(
        prompt: '为什么 utf8.len("中", 2) 返回 nil, 2？',
        hint: '从中间字节开始的后果。',
        answer:
            '字节 2 是 UTF-8 续字节，不能作为字符起点，所以第一个返回值是 nil；第二个值 2 指出非法序列的字节位置，不是字符数。',
      ),
    ],
    pitfalls: [
      'start/end 参数是字节位置，从字符中间开始会得到意外结果。',
      'len 成功返回码点个数，失败返回 nil 和错误字节位置；条件本来就只使用第一个值。',
    ],
  ),
  LuaTopic(
    id: 'lua-utf8-offset',
    chapter: 'utf8',
    title: 'utf8.offset 定位字符边界',
    summary: 'offset 把「第 n 个字符」换算成字节位置。',
    objective: '能用 offset 正向和反向定位字符，避免切在字节中间。',
    level: 'intermediate',
    concepts: ['utf8.offset', '边界', '反向'],
    explain:
        'utf8.offset(s, n) 返回第 n 个字符的起始字节位置。'
        'n 为负数时从末尾倒数，0 表示「包含该位置的字符的起始位置」……'
        '配合 utf8.offset 和 string.sub 就能按字符截取。',
    code: r'''local text = "中文abc"

print(utf8.offset(text, 1))
print(utf8.offset(text, 2))
print(utf8.offset(text, 3))
print(utf8.offset(text, 6))
print(utf8.offset(text, 7))

print(utf8.offset(text, -1))
print(utf8.offset(text, -3))

local startPosition = utf8.offset(text, 2)
local endPosition = utf8.offset(text, 3) - 1
print(text:sub(startPosition, endPosition))
''',
    output: '1\n4\n7\n10\nnil\n9\n7\n文\n',
    exercises: [
      LuaExercise(
        prompt: '取字符串的最后一个字符。',
        hint: 'offset(-1)。',
        answer: 'local p = utf8.offset(text, -1)\nprint(text:sub(p))',
      ),
      LuaExercise(
        prompt: '为什么按字符截取要用 offset 而不是 sub 的数字？',
        hint: '想想字节。',
        answer: '因为 sub 的下标是字节位置，直接传字符序号会切在多字节字符中间。',
      ),
    ],
    pitfalls: [
      'offset 可以返回末尾之后的位置 #s + 1，继续超出才返回 nil；起点为续字节且 n 非 0 时会报错。',
      'offset 的位置从 1 开始，和 sub 一致。',
    ],
  ),
  LuaTopic(
    id: 'lua-utf8-substring',
    chapter: 'utf8',
    title: '按字符截取子串',
    summary: '组合 offset 和 sub 实现按字符数的截取与省略号。',
    objective: '能写出按字符截断并补省略号的函数。',
    level: 'intermediate',
    concepts: ['截取', '省略号', '字符数'],
    explain:
        '按字符截取要先把「第 n 个字符之后」的位置换算成字节位置。'
        '截断常用的做法是保留前 n 个字符并追加省略号，'
        '同时要判断是否需要截断，否则短文本也会被加上省略号。',
    code: r'''local function truncate(text, limit)
  local length = utf8.len(text)
  if length <= limit then return text end
  local cut = utf8.offset(text, limit + 1)
  return text:sub(1, cut - 1) .. "..."
end

print(truncate("中文测试文本", 2))
print(truncate("中文", 2))
print(truncate("abcdef", 4))
print(truncate("中文abcdef", 3))

local function takeChars(text, n)
  local cut = utf8.offset(text, n + 1)
  if not cut then return text end
  return text:sub(1, cut - 1)
end

print(takeChars("中文abc", 2))
print(utf8.len(takeChars("中文abc", 2)))
''',
    output: '中文...\n中文\nabcd...\n中文a...\n中文\n2\n',
    exercises: [
      LuaExercise(
        prompt: '实现只保留最后 n 个字符。',
        hint: '从 -n 开始。',
        answer: 'local p = utf8.offset(text, -n) or 1\nreturn text:sub(p)',
      ),
      LuaExercise(
        prompt: '为什么用 limit + 1 而不是 limit？',
        hint: 'offset 返回的是起始位置。',
        answer: '因为要拿到「下一个字符的起点」，减 1 才是第 limit 个字符的最后一个字节。',
      ),
    ],
    pitfalls: ['用 # 判断长度会算错中文，必须用 utf8.len。', 'offset 返回 nil 时直接做减法会报错。'],
  ),
  LuaTopic(
    id: 'lua-utf8-validate',
    chapter: 'utf8',
    title: '校验与修复输入',
    summary: '先用 utf8.len 定位非法字节，再决定报错还是替换。',
    objective: '能写一个校验函数，报告非法位置并给出可读错误。',
    level: 'intermediate',
    concepts: ['校验', '非法字节', '错误报告'],
    explain:
        '处理外部文本输入时，先校验再解析能避免后续报错难以定位。'
        'utf8.len 给出的位置是第一个非法字节，'
        '配合上下文片段就能生成有用的错误消息。',
    code: r'''local function describeInvalid(text)
  local length, position = utf8.len(text)
  if length then return "合法：" .. length .. " 个字符" end
  return string.format("非法：第 %d 个字节", position)
end

print(describeInvalid("中文"))
print(describeInvalid("abc"))
print(describeInvalid("ab" .. string.char(0xFF)))

local function sanitize(text)
  local parts = {}
  local replaced = false
  while true do
    local length, position = utf8.len(text)
    if length then
      parts[#parts + 1] = text
      break
    end
    parts[#parts + 1] = text:sub(1, position - 1)
    parts[#parts + 1] = "?"
    text = text:sub(position + 1)
    replaced = true
  end
  return table.concat(parts), replaced
end

local value, replaced = sanitize("ok")
print(value, replaced)
print(sanitize("中"))
print(#("中"))
print(sanitize("中" .. string.char(0xFF) .. "文"))
''',
    output:
        '合法：2 个字符\n合法：3 个字符\n非法：第 3 个字节\nok\tfalse\n中\tfalse\n3\n中?文\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '写一个函数，非法时返回 nil 和位置。',
        hint: '直接转发 utf8.len 的返回值。',
        answer:
            'local function check(s) local n, p = utf8.len(s); if n then return s end; return nil, p end',
      ),
      LuaExercise(
        prompt: '为什么不能在发现坏字节后，把所有非 ASCII 字节都替换成问号？',
        hint: '同一字符串里可以既有合法中文，也有坏字节。',
        answer: '合法中文也由非 ASCII 字节组成，整段替换会破坏它；这里保留错误之前的合法前缀，只替换当前坏字节，再继续校验。',
      ),
    ],
    pitfalls: [
      'UTF-8 校验不是简单检查字节是否大于 127，不能用非 ASCII 字节模式代替校验。',
      '这个修复器逐个替换坏字节，不保证每个损坏序列只产生一个问号；坏字节很多时重复校验的开销也会增大。',
    ],
  ),
  LuaTopic(
    id: 'lua-utf8-count-by-kind',
    chapter: 'utf8',
    title: '按字符类别统计',
    summary: '组合 codes 和码点范围，统计中文、字母、数字的个数。',
    objective: '能按码点区间分类统计字符，而不是按字节。',
    level: 'advanced',
    concepts: ['码点区间', '分类统计', 'codes'],
    explain:
        'UTF-8 里没有现成的「是不是中文」函数，'
        '可以按码点区间近似判断：基本汉字在 0x4E00 到 0x9FFF 之间。'
        '数字和字母的区间与 ASCII 一致，'
        '所以 codes 遍历后做区间判断即可。',
    code: r'''local function classify(text)
  local counts = { han = 0, digit = 0, alpha = 0, other = 0 }
  for _, code in utf8.codes(text) do
    if code >= 0x4E00 and code <= 0x9FFF then
      counts.han = counts.han + 1
    elseif code >= 48 and code <= 57 then
      counts.digit = counts.digit + 1
    elseif (code >= 65 and code <= 90) or (code >= 97 and code <= 122) then
      counts.alpha = counts.alpha + 1
    else
      counts.other = counts.other + 1
    end
  end
  return counts
end

local result = classify("中文abc123!")
print(result.han, result.alpha, result.digit, result.other)
print(utf8.len("中文abc123!"))

print(classify("").han)
print(classify("中中").han)
''',
    output: '2\t3\t3\t1\n9\n0\n2\n',
    exercises: [
      LuaExercise(
        prompt: '统计字符串里汉字的个数。',
        hint: '分类函数返回表的 han 字段。',
        answer: 'print(classify(text).han)',
      ),
      LuaExercise(
        prompt: '为什么不能直接用 string.match(text, "%a+") 统计字母？',
        hint: '想想 %a 的定义。',
        answer:
            '%a 按当前 C 区域设置分类单个字节，不是 Unicode 字母类别；本例要逐码点区分 ASCII 字母与基本汉字，所以使用 utf8.codes。',
      ),
    ],
    pitfalls: [
      '码点区间判断是近似方案，扩展汉字区不在 0x4E00-0x9FFF 内。',
      '标准 utf8 库处理码点，不处理字素簇；组合音标和某些 emoji 的可见字符数可能不同。',
    ],
  ),
];
