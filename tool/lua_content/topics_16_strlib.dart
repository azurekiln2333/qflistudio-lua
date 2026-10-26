import 'lua_topic.dart';

/// 第十六章：string 库。
const List<LuaTopic> topicsStrlib = [
  LuaTopic(
    id: 'lua-stl-byte-char',
    chapter: 'strlib',
    title: 'byte 与 char：字节与字符',
    summary: 'byte 取字节值，char 由字节值构造字符串。',
    objective: '能用 byte/char 做字节级处理，并知道它们按字节而非字符工作。',
    level: 'beginner',
    concepts: ['string.byte', 'string.char', '字节'],
    explain:
        's:byte(i) 返回第 i 个字节的数值，可以一次取多个：s:byte(1, 3)。'
        'string.char(...) 用字节值构造字符串。'
        '两者处理的是字节，中文一个字符会对应多个字节。',
    code: r'''print(("ABC"):byte(1))
print(("ABC"):byte(1, 3))
print(string.char(72, 105))
print(string.char(65, 66, 67))

print(("中"):byte(1, -1))
print(#string.char(228, 184, 173))

local codes = { ("Lua"):byte(1, -1) }
print(table.concat(codes, ","))
print(string.char(table.unpack(codes)))
''',
    output:
        '65\n65\t66\t67\nHi\nABC\n228\t184\t173\n3\n'
        '76,117,97\nLua\n',
    exercises: [
      LuaExercise(
        prompt: '把 "QFLI" 转成字节值列表。',
        hint: 'byte(1, -1)。',
        answer: 'local bytes = { ("QFLI"):byte(1, -1) }',
      ),
      LuaExercise(
        prompt: '为什么 #string.char(228,184,173) 是 3？',
        hint: 'char 按字节构造。',
        answer: '因为这三个字节组成一个 UTF-8 汉字，字符串长度按字节算就是 3。',
      ),
    ],
    pitfalls: ['byte 的下标从 1 开始，负下标从末尾数。', 'char 的参数必须在 0..255 之间。'],
  ),
  LuaTopic(
    id: 'lua-stl-format-padding',
    chapter: 'strlib',
    title: '用 format 做定宽排版',
    summary: '组合宽度、对齐和精度，把数据排成固定列宽。',
    objective: '能排出左对齐文本加右对齐数字的表格行。',
    level: 'beginner',
    concepts: ['format', '宽度', '对齐'],
    explain:
        '格式串里 %-10s 表示左对齐占 10 列，%8.2f 表示右对齐占 8 列并保留两位小数。'
        '把每行拼好后用换行连接，就能得到整齐的文本表格。'
        '注意宽度是按字节算的，中文会占更多列。',
    code: r'''local rows = {
  { "apple", 3, 5.5 },
  { "banana", 12, 1.25 },
  { "kiwi", 100, 0.5 },
}

for _, row in ipairs(rows) do
  print(string.format("%-10s%5d%8.2f", row[1], row[2], row[3]))
end

print(string.format("|%10s|%-10s|", "right", "left"))
print(string.format("%.3s", "truncated"))
print(#string.format("%-10s", "abc"))
''',
    output:
        'apple         3    5.50\nbanana       12    1.25\nkiwi        100    0.50\n'
        '|     right|left      |\ntru\n10\n',
    exercises: [
      LuaExercise(
        prompt: '输出一行「名字左对齐 8 列 + 分数右对齐 4 列」。',
        hint: '%-8s%4d。',
        answer: 'print(string.format("%-8s%4d", "小明", 95))',
      ),
      LuaExercise(
        prompt: '%.3s 的作用是什么？',
        hint: '注意是点不是宽度。',
        answer: '按最大长度截断字符串，只保留前 3 个字节。',
      ),
    ],
    pitfalls: ['宽度按字节计算，中文对齐会偏。', '格式符和参数个数不匹配会报错或输出错位。'],
  ),
  LuaTopic(
    id: 'lua-stl-sub-chunks',
    chapter: 'strlib',
    title: '用 sub 切分固定长度块',
    summary: '按固定步长切片，把长字符串拆成等长块。',
    objective: '能写出按块切分的循环，并处理最后一块不足长度的情况。',
    level: 'intermediate',
    concepts: ['sub', '分块', '边界'],
    explain:
        '用 for i = 1, #s, size 遍历起点，每次取 s:sub(i, i + size - 1)。'
        'sub 会自动截断到字符串末尾，所以最后一块不足长度也不用特判。'
        '这是格式化输出十六进制、分行展示长文本的常用手法。',
    code: r'''local function chunk(text, size)
  local parts = {}
  for i = 1, #text, size do
    parts[#parts + 1] = text:sub(i, i + size - 1)
  end
  return parts
end

print(table.concat(chunk("abcdefgh", 3), "|"))
print(table.concat(chunk("abcdefgh", 4), "|"))
print(table.concat(chunk("abc", 10), "|"))
print(#chunk("", 3))

local hex = "0123456789ABCDEF"
for _, group in ipairs(chunk(hex, 4)) do
  io.write(group, " ")
end
print()
''',
    output: 'abc|def|gh\nabcd|efgh\nabc\n0\n0123 4567 89AB CDEF \n',
    exercises: [
      LuaExercise(
        prompt: '把字符串按 2 个字符一组分开。',
        hint: 'chunk(s, 2)。',
        answer: 'print(table.concat(chunk("123456", 2), ","))  -- 12,34,56',
      ),
      LuaExercise(
        prompt: '为什么最后一块不需要特殊处理？',
        hint: 'sub 的边界行为。',
        answer: '因为 sub 的结束下标超过长度时会自动截断到末尾，不会报错。',
      ),
    ],
    pitfalls: ['size 为 0 会导致死循环。'],
  ),
  LuaTopic(
    id: 'lua-stl-trim',
    chapter: 'strlib',
    title: '去除首尾空白',
    summary: '用模式一次匹配掉两端空白，并返回中间内容。',
    objective: '能写出 trim 函数，并区分 trim 与「只去一侧」。',
    level: 'beginner',
    concepts: ['trim', '模式', '空白'],
    explain:
        r's:match("^%s*(.-)%s*$") 用最短匹配捕获中间部分，'
        '两侧的空白被 %s* 吃掉。'
        r'只去一侧时可分别使用 gsub("^%s+", "") 和 gsub("%s+$", "")。'
        '注意 %s 包含空格、制表、换行等所有空白字符。',
    code: r'''local function trim(text)
  return (text:match("^%s*(.-)%s*$"))
end

local function ltrim(text)
  return (text:gsub("^%s+", ""))
end

local function rtrim(text)
  return (text:gsub("%s+$", ""))
end

print("[" .. trim("  你好  ") .. "]")
print("[" .. trim("\t\n lua \r\n") .. "]")
print("[" .. ltrim("  left") .. "]")
print("[" .. rtrim("right  ") .. "]")
print("[" .. trim("") .. "]")
print("[" .. trim("   ") .. "]")
''',
    output: '[你好]\n[lua]\n[left]\n[right]\n[]\n[]\n',
    exercises: [
      LuaExercise(
        prompt: '写一个 trim 并统计去掉了多少个空白字符。',
        hint: '比较前后长度。',
        answer: 'local removed = #text - #trim(text)',
      ),
      LuaExercise(
        prompt: 'trim 里的括号必需吗，ltrim 与 rtrim 里的括号有什么作用？',
        hint: '分别检查 match 的捕获个数与 gsub 的返回值。',
        answer:
            '这里 match 只有一个捕获，本来就只返回一个字符串，括号可以省略；gsub 返回字符串和次数，括号可把后者截断，保证接口只返回字符串。',
      ),
    ],
    pitfalls: [
      'match 返回捕获值；没有捕获时返回完整匹配，只有显式写 () 位置捕获才返回位置。',
      '%s 会去掉换行，处理多行文本时要确认这是否符合预期。',
    ],
  ),
  LuaTopic(
    id: 'lua-stl-find-all',
    chapter: 'strlib',
    title: '找出所有出现位置',
    summary: '用 find 加偏移循环，记录每处匹配的位置。',
    objective: '能写出查找全部匹配位置的循环，并正确推进偏移避免死循环。',
    level: 'intermediate',
    concepts: ['find', '循环偏移', '位置'],
    explain:
        'find 可以带起始位置参数，因此可以用循环不断从上次结束位置之后继续找。'
        '偏移必须至少推进 1，否则零宽匹配会让循环停不下来。'
        '记录位置后可以再做高亮、截取或统计。',
    code: r'''local function findAll(text, pattern)
  local positions = {}
  local start = 1
  while true do
    local first, last = text:find(pattern, start)
    if not first then break end
    positions[#positions + 1] = first
    start = math.max(last + 1, first + 1)
  end
  return positions
end

print(table.concat(findAll("banana", "an"), ","))
print(table.concat(findAll("aaaa", "aa"), ","))
print(#findAll("abc", "z"))

local text = "one, two, three"
local commas = findAll(text, ",")
print(#commas, commas[1], commas[2])
print(table.concat(findAll("ab", ""), ","))
''',
    output: '2,4\n1,3\n0\n2\t4\t9\n1,2,3\n',
    exercises: [
      LuaExercise(
        prompt: '统计字符串里某个词出现的次数。',
        hint: 'findAll 返回的数组长度。',
        answer: 'print(#findAll(text, "lua"))',
      ),
      LuaExercise(
        prompt: '为什么推进位置时还要比较 first + 1？',
        hint: '空匹配的 last 可能是 first - 1。',
        answer:
            '普通匹配从 last + 1 继续；空匹配时这仍是原位置，用 math.max(last + 1, first + 1) 确保至少向前一字节，避免死循环。',
      ),
    ],
    pitfalls: [
      'start 不推进会导致死循环。',
      '这种写法找不到重叠匹配（如 "aaaa" 里的第二个 "aa" 从位置 2 开始的情况）。',
    ],
  ),
  LuaTopic(
    id: 'lua-stl-gsub-count',
    chapter: 'strlib',
    title: 'gsub 的替换次数统计',
    summary: 'gsub 的第二个返回值是替换次数，可直接用于统计。',
    objective: '能用替换次数做统计，并在限制次数时得到部分替换结果。',
    level: 'beginner',
    concepts: ['gsub', '次数', '限制'],
    explain:
        'replaced, count = s:gsub(pat, repl) 中 count 是实际替换次数。'
        '第四个参数可以限制最多替换几次，'
        '配合次数就能实现「只替换前 N 个」的需求。'
        '次数统计比再写一遍 find 循环更简洁。',
    code: r'''local text = "a,b,c,d"

local replaced, count = text:gsub(",", ";")
print(replaced, count)

local partial, partialCount = text:gsub(",", ";", 2)
print(partial, partialCount)

local spaces = ("  a  b  "):gsub("%s", "_")
print(spaces)

local _, spacesCount = ("  a  b  "):gsub("%s", "_")
print(spacesCount)

local _, vowels = ("education"):gsub("[aeiou]", "")
print(vowels)

local _, digits = ("a1b2c3"):gsub("%d", "")
print(digits)
''',
    output: 'a;b;c;d\t3\na;b;c,d\t2\n__a__b__\n6\n5\n3\n',
    exercises: [
      LuaExercise(
        prompt: '统计字符串里有多少个空格。',
        hint: 'gsub 只取次数。',
        answer: 'local _, n = text:gsub(" ", "")',
      ),
      LuaExercise(
        prompt: '为什么可以写 local _, n = ...？',
        hint: '多返回值可以用变量承接任意一个。',
        answer: '_ 是合法的变量名，用来忽略第一个返回值，直接接住第二个。',
      ),
    ],
    pitfalls: ['gsub 返回两个值，用一个变量接会丢掉次数。'],
  ),
  LuaTopic(
    id: 'lua-stl-gmatch-lines',
    chapter: 'strlib',
    title: 'gmatch 按行读取',
    summary: '用 gmatch("[^\n]+") 逐行拆分文本。',
    objective: '能用 gmatch 遍历多行文本的每一行，并跳过空行。',
    level: 'intermediate',
    concepts: ['gmatch', '按行', '空行'],
    explain:
        'gmatch 返回迭代器，配合 for 就能逐段处理。'
        '按行拆分时模式写成 "([^\n]*)" 会保留空行，'
        '写成 "[^\n]+" 会跳过空行。'
        '根据是否需要保留空行选择模式很重要。',
    code: r'''local text = "first\n\nsecond\nthird\n"

local kept = {}
for line in text:gmatch("([^\n]*)") do
  kept[#kept + 1] = "[" .. line .. "]"
end
print(#kept)
print(table.concat(kept, ""))

local skipped = {}
for line in text:gmatch("[^\n]+") do
  skipped[#skipped + 1] = line
end
print(#skipped)
print(table.concat(skipped, "|"))

local numbered = 0
for _ in text:gmatch("[^\n]+") do numbered = numbered + 1 end
print(numbered)
''',
    output: '5\n[first][][second][third][]\n3\nfirst|second|third\n3\n',
    exercises: [
      LuaExercise(
        prompt: '只统计非空行的数量。',
        hint: '用 [^\n]+ 的模式。',
        answer: 'local n = 0\nfor _ in text:gmatch("[^\\n]+") do n = n + 1 end',
      ),
      LuaExercise(
        prompt: '为什么 ([^\n]*) 会多出空项？',
        hint: '想想末尾的换行。',
        answer: '因为 * 允许零长度匹配，末尾换行之后还会匹配到一个空串。',
      ),
    ],
    pitfalls: ['零宽模式会额外产生空匹配，计数时要注意。', 'gmatch 不会自动去掉 \\r，处理 CRLF 时要额外处理。'],
  ),
  LuaTopic(
    id: 'lua-stl-reverse',
    chapter: 'strlib',
    title: '反转字符串',
    summary: '用 byte 和循环把字符串逆序，注意中文要按字符反转。',
    objective: '能反转 ASCII 字符串，并知道中文需要 utf8 版本。',
    level: 'intermediate',
    concepts: ['反转', 'byte', 'utf8'],
    explain:
        'ASCII 字符串可以按字节反转：从末尾取到开头。'
        '中文按字节反转会破坏 UTF-8 编码，得到乱码。'
        '正确的做法是按码点取字符再逆序拼接（见 utf8 章节）。',
    code: r'''local function reverseAscii(text)
  local out = {}
  for i = #text, 1, -1 do
    out[#out + 1] = text:sub(i, i)
  end
  return table.concat(out)
end

print(reverseAscii("lua"))
print(reverseAscii("abc"))
print(reverseAscii(""))

local broken = reverseAscii("中文")
print(#broken, broken == "中文")

local function reverseUtf8(text)
  local chars = {}
  for _, code in utf8.codes(text) do
    chars[#chars + 1] = utf8.char(code)
  end
  local out = {}
  for i = #chars, 1, -1 do out[#out + 1] = chars[i] end
  return table.concat(out)
end

print(reverseUtf8("中文"))
print(reverseUtf8("a中b"))
''',
    output: 'aul\ncba\n\n6\tfalse\n文中\nb中a\n',
    exercises: [
      LuaExercise(
        prompt: '判断字符串是否是回文。',
        hint: '和它的反转比较。',
        answer:
            'local function isPalindrome(s) return s == reverseAscii(s) end',
      ),
      LuaExercise(
        prompt: '为什么按字节反转中文会出错？',
        hint: '想想 UTF-8 的编码结构。',
        answer: '因为一个汉字由多个字节组成，字节顺序被打乱后不再是合法编码。',
      ),
    ],
    pitfalls: ['按字节反转只对单字节编码安全。'],
  ),
  LuaTopic(
    id: 'lua-stl-pack-int',
    chapter: 'strlib',
    title: 'string.pack 与 unpack',
    summary: '把数字打包成二进制字节，或从字节还原数字。',
    objective: '能用 pack/unpack 处理定长整数，并知道格式串的含义。',
    level: 'advanced',
    concepts: ['string.pack', 'string.unpack', '二进制'],
    explain:
        'string.pack("i4", n) 把整数打包成 4 字节小端序列。'
        '"i4" 表示 4 字节有符号整数，">i4" 表示大端。'
        'string.unpack 反过来解析，并额外返回下一个读取位置。'
        '这是处理二进制文件格式的基础。',
    code: r'''local packed = string.pack("i4", 258)
print(#packed)
print(string.byte(packed, 1, -1))

print(string.unpack("i4", packed))

local big = string.pack(">i4", 258)
print(string.byte(big, 1, -1))

local buffer = string.pack("i4i4", 1, 2)
local first, second, position = string.unpack("i4i4", buffer)
print(first, second, position, #buffer)

print(#string.pack("I8", 1))
''',
    output: '4\n2\t1\t0\t0\n258\t5\n0\t0\t1\t2\n1\t2\t9\t8\n8\n',
    exercises: [
      LuaExercise(
        prompt: '把 65535 打包成 2 字节无符号整数。',
        hint: '格式 "I2"。',
        answer: 'print(#string.pack("I2", 65535))  -- 2',
      ),
      LuaExercise(
        prompt: 'unpack 的第三个返回值是什么？',
        hint: '和下一个读取位置有关。',
        answer: '读完这段数据后的下一个字节位置，便于顺序解析多段数据。',
      ),
    ],
    pitfalls: ['端序（< >）会影响字节顺序，跨平台时要显式指定。', '数值超出格式范围会报错。'],
  ),
  LuaTopic(
    id: 'lua-stl-format-table',
    chapter: 'strlib',
    title: '把表格式化成文本',
    summary: '遍历排序后的键，用 format 输出「键 = 值」的稳定文本。',
    objective: '能写一个通用的表格转文本函数，并用于日志与调试。',
    level: 'intermediate',
    concepts: ['格式化', '排序', '调试输出'],
    explain:
        '调试时经常需要把表打印成可读文本。'
        '直接 print(t) 只得到地址，所以要先排序键、再逐行格式化。'
        '这个函数只处理一层，嵌套值用 type 标注，避免无限递归。',
    code: r'''local function dump(source)
  local keys = {}
  for key in pairs(source) do keys[#keys + 1] = key end
  table.sort(keys)

  local lines = {}
  for _, key in ipairs(keys) do
    local value = source[key]
    local shown
    if type(value) == "string" then
      shown = '"' .. value .. '"'
    elseif type(value) == "table" then
      shown = "<table>"
    else
      shown = tostring(value)
    end
    lines[#lines + 1] = string.format("%s = %s", tostring(key), shown)
  end
  return table.concat(lines, "\n")
end

print(dump({ name = "lua", version = 5.4, tags = { "a" }, ok = true }))
print(dump({}))
print(dump({ b = 1, a = 2 }))
''',
    output:
        'name = "lua"\nok = true\ntags = <table>\nversion = 5.4\n\n'
        'a = 2\nb = 1\n',
    exercises: [
      LuaExercise(
        prompt: '让 dump 支持嵌套表的缩进输出。',
        hint: '递归调用并给每行加前缀。',
        answer: '在递归时传入 indent 参数，并在每行前拼 string.rep("  ", indent)。',
      ),
      LuaExercise(
        prompt: '为什么要排序键？',
        hint: 'pairs 的顺序。',
        answer: 'pairs 顺序不固定，排序后输出稳定，便于比对和写测试。',
      ),
    ],
    pitfalls: ['嵌套表直接递归会因循环引用无限递归。'],
  ),
  LuaTopic(
    id: 'lua-stl-match-validate',
    chapter: 'strlib',
    title: '用模式校验格式',
    summary: '把「整段匹配」写成一个校验函数，返回布尔或错误原因。',
    objective: '能写出日期、版本号等格式的校验模式。',
    level: 'intermediate',
    concepts: ['校验', '模式', '锚点'],
    explain:
        r'校验要用 ^...$ 包住整段，否则只要有一段符合就会通过。'
        '把模式写成常量，校验函数只负责匹配和返回原因，'
        '这样错误信息可以统一，也方便为每种格式加注释。',
    code: r'''local function check(text, pattern, label)
  if type(text) ~= "string" then return nil, label .. " 必须是字符串" end
  if not text:match(pattern) then return nil, label .. " 格式不正确：" .. text end
  return text, nil
end

local datePattern = "^%d%d%d%d%-%d%d%-%d%d$"
local versionPattern = "^%d+%.%d+%.%d+$"

print(check("2026-10-22", datePattern, "日期"))
print(check("2026-1-2", datePattern, "日期"))
print(check("5.4.8", versionPattern, "版本"))
print(check("5.4", versionPattern, "版本"))

local ok = check("2026-10-22", datePattern, "日期")
print(ok)
print(check(42, datePattern, "日期"))
''',
    output:
        '2026-10-22\tnil\nnil\t日期 格式不正确：2026-1-2\n5.4.8\tnil\n'
        'nil\t版本 格式不正确：5.4\n2026-10-22\nnil\t日期 必须是字符串\n',
    exercises: [
      LuaExercise(
        prompt: '增加一个「只允许 1-12 月」的月份校验。',
        hint: '先匹配格式，再 tonumber 判断范围。',
        answer:
            '匹配后取 month = tonumber(text:sub(6, 7))，判断 month >= 1 and month <= 12。',
      ),
      LuaExercise(
        prompt: r'为什么模式必须加 ^ 和 $？',
        hint: '不加会怎样。',
        answer: '不加只要求局部匹配，"x2026-10-22y" 也会通过，无法保证整段符合格式。',
      ),
    ],
    pitfalls: ['只校验格式不校验语义（如 2026-99-99 也能通过）。', '中文字符的 %d 不会匹配全角数字。'],
  ),
];
