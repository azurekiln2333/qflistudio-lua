import 'lua_topic.dart';

/// 第五章：字符串模式匹配。
const List<LuaTopic> topicsPatterns = [
  LuaTopic(
    id: 'lua-pat-find',
    chapter: 'patterns',
    title: 'find：定位子串',
    summary: 'string.find 返回起止位置，找不到返回 nil。',
    objective: '能用 find 判断子串是否存在，并拿到精确的字节区间。',
    level: 'beginner',
    concepts: ['find', '位置', 'nil'],
    explain:
        's:find(pat) 在 s 中查找模式，找到时返回起止下标（从 1 开始），否则返回 nil。'
        '默认把 pat 当作模式处理，所以 . * + 等字符有特殊含义；要按字面查找请把第四个参数设为 true。'
        '位置是字节下标，可以直接交给 string.sub 使用。',
    code: r'''print(("hello world"):find("wor"))
print(("hello world"):find("lua"))
print(("hello world"):find("o", 6))

local startIndex, endIndex = ("hello world"):find("world")
print(("hello world"):sub(startIndex, endIndex))

print(("a.b"):find(".", 1, true))
''',
    output: '7\t9\nnil\n8\t8\nworld\n2\t2\n',
    exercises: [
      LuaExercise(
        prompt: '判断字符串里是否包含 "error"。',
        hint: 'find 返回 nil 表示不存在。',
        answer: 'if text:find("error", 1, true) then print("包含") end',
      ),
      LuaExercise(
        prompt: '为什么 "a.b":find(".") 和 "a.b":find(".", 1, true) 结果不同？',
        hint: '点号是模式里的通配符。',
        answer: '前者把 . 当通配符，匹配到第一个字符 a；后者按字面查找点号，得到位置 2。',
      ),
    ],
    pitfalls: ['find 的返回是起止两个值，只接第一个会丢掉结束位置。', '忘记第四个参数 true 会让含特殊字符的查找结果出错。'],
  ),
  LuaTopic(
    id: 'lua-pat-match-capture',
    chapter: 'patterns',
    title: 'match：捕获分组',
    summary: 'match 返回捕获到的内容，而不是位置。',
    objective: '能用括号捕获分组并一次取出多个字段。',
    level: 'beginner',
    concepts: ['match', '捕获', '分组'],
    explain:
        's:match(pat) 匹配成功时返回捕获到的内容：没有括号就返回整个匹配，'
        '有括号就按顺序返回各分组。'
        '这正是解析 key=value、日期、日志行的核心手段。'
        '匹配失败返回 nil，因此可以直接用 local a, b = s:match(...) 加判空。',
    code: r'''print(("key=value"):match("(%w+)=(%w+)"))
print(("2026-10-22"):match("(%d+)-(%d+)-(%d+)"))

local name, version = ("lua-5.4.8"):match("(%a+)%-(%d+%.%d+%.%d+)")
print(name, version)

local function parsePair(text)
  local key, value = text:match("^([%w_]+)%s*=%s*(.+)$")
  if not key then return nil, "格式不正确" end
  return { key = key, value = value }
end

local pair = parsePair("mode = fast")
print(pair.key, pair.value)
print(parsePair("no equals sign"))
''',
    output: 'key\tvalue\n2026\t10\t22\nlua\t5.4.8\nmode\tfast\nnil\t格式不正确\n',
    exercises: [
      LuaExercise(
        prompt: '从 "width=640" 里取出数字 640。',
        hint: '用 %d+ 捕获。',
        answer: 'local n = ("width=640"):match("=(%d+)")  -- "640" 字符串',
      ),
      LuaExercise(
        prompt: r'为什么要在模式里加 ^ 和 $？',
        hint: '不加只要求局部匹配。',
        answer: r'加 ^$ 要求整段文本完全符合格式，避免在多余内容里「碰巧匹配」而误判成功。',
      ),
    ],
    pitfalls: ['match 返回的是字符串，参与算术前要 tonumber。', '捕获过多时返回值个数要一一对应，否则容易错位。'],
  ),
  LuaTopic(
    id: 'lua-pat-charclass',
    chapter: 'patterns',
    title: '字符类 %a %d %s %w',
    summary: '用字符类描述「哪一类字符」，配合大写形式取反。',
    objective: '能读懂 %a %d %s %w %p 和大写取反形式。',
    level: 'beginner',
    concepts: ['字符类', '%d', '%s'],
    explain:
        'Lua 模式内置字符类：%a 字母、%d 数字、%s 空白、%w 字母数字、%p 标点、%l 小写、%u 大写。'
        '把它们写成大写就是取反：%D 非数字、%S 非空白。'
        '方括号里可以自定义集合，例如 [%w_] 表示字母数字加下划线。',
    code: r'''print(("abc123"):match("%a+"))
print(("abc123"):match("%d+"))
print(("  padded  "):match("^%s*(.-)%s*$"))
print(("a1_b2"):match("[%w_]+"))
print(("x 1 y 2"):gsub("%d", "#"))
print(("no digits"):match("%d") == nil)
''',
    output: 'abc\n123\npadded\na1_b2\nx # y #\t2\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '取出字符串里的第一段连续空白。',
        hint: '用 %s+。',
        answer: 'local blank = text:match("%s+")',
      ),
      LuaExercise(
        prompt: '%w 包含下划线吗？',
        hint: '想想变量名的组成。',
        answer: '不包含，所以要写 [%w_] 才能匹配下划线。',
      ),
    ],
    pitfalls: ['%w 不包含下划线，这是最常见的误解。', '在方括号里 % 仍然生效，字面百分号要写成 %%。'],
  ),
  LuaTopic(
    id: 'lua-pat-quantifier',
    chapter: 'patterns',
    title: '量词 + * - ?',
    summary: '四种量词决定重复次数，其中 - 是最短匹配。',
    objective: '能根据需求选择贪婪、最短、零次或一次的量词。',
    level: 'intermediate',
    concepts: ['量词', '贪婪', '最短匹配'],
    explain:
        '+ 表示一次或多次（贪婪），* 表示零次或多次（贪婪），? 表示零次或一次，'
        '- 也表示零次或多次，但取最短匹配。'
        '解析带分隔符的文本时，.-\n 往往比 .* 更合适，因为它在第一个可能的位置就停下。',
    code: r'''print(("<b>粗体</b>"):match("<b>(.*)</b>"))
print(("<b>粗体</b><b>斜体</b>"):match("<b>(.*)</b>"))
print(("<b>粗体</b><b>斜体</b>"):match("<b>(.-)</b>"))
print(("aaab"):match("a-b"))
print(("color"):match("colou?r"))
print(("colour"):match("colou?r"))
''',
    output: '粗体\n粗体</b><b>斜体\n粗体\naaab\ncolor\ncolour\n',
    exercises: [
      LuaExercise(
        prompt: '为什么只有一个 </b> 时，.* 和 .- 结果相同？',
        hint: '贪婪只能在有多个可选结束位置时才能「多吃」。',
        answer: '因为匹配完内容后必须找到字面的 </b>，两者都只能停在同一个位置；有多段结束标记时才会分开。',
      ),
      LuaExercise(
        prompt: 'a-b 为什么匹配到 b 而不是空串？',
        hint: '模式要求后面还有 b。',
        answer: 'a- 最短匹配空，但后面必须紧跟 b，所以只能吃掉三个 a 才能匹配到 b。',
      ),
    ],
    pitfalls: ['贪婪量词在有多段匹配时会一路吞到最后一个。', '? 修饰的是前一个字符或字符类，不是整组。'],
  ),
  LuaTopic(
    id: 'lua-pat-anchors',
    chapter: 'patterns',
    title: r'锚点 ^ 与 $',
    summary: r'^ 锚定开头，$ 锚定结尾，用来做整段格式校验。',
    objective: '能用锚点把「包含」升级成「完全符合」。',
    level: 'intermediate',
    concepts: ['锚点', '^', r'$'],
    explain:
        '模式默认在任意位置尝试匹配，所以 "abc123":match("%d+") 会成功。'
        r'加 ^ 要求从第一个字节开始，加 $ 要求匹配到最后一个字节。'
        '两者同时使用时就是整段校验，这在解析用户输入时非常关键。',
    code: r'''print(("abc123"):match("^%d+"))
print(("123abc"):match("^%d+"))
print(("123abc"):match("%d+$"))
print(("123"):match("^%d+$"))
print((" 123 "):match("^%d+$") == nil)
print(("2026-10-22"):match("^%d%d%d%d%-%d%d%-%d%d$"))
''',
    output: 'nil\n123\nnil\n123\ntrue\n2026-10-22\n',
    exercises: [
      LuaExercise(
        prompt: '写一个只接受 4 位数字年份的校验模式。',
        hint: r'用 ^%d%d%d%d$。',
        answer: r'local ok = year:match("^%d%d%d%d$") ~= nil',
      ),
      LuaExercise(
        prompt: r'为什么 "^%d+$" 对 " 123 " 失败？',
        hint: '空格也是字节。',
        answer: r'前后空格不在模式允许的范围内，需要先 trim 或把模式写成 ^%s*%d+%s*$。',
      ),
    ],
    pitfalls: ['^ 在方括号里表示取反，不是锚点。', r'$ 在模式中间没有特殊含义，只匹配字面美元符号。'],
  ),
  LuaTopic(
    id: 'lua-pat-frontier',
    chapter: 'patterns',
    title: '%f 边界模式',
    summary: '用 %f[set] 匹配「前一个字符不在集合里、当前在集合里」的边界。',
    objective: '能用边界模式做整词匹配，而不误伤单词内部。',
    level: 'advanced',
    concepts: ['%f', '边界', '整词匹配'],
    explain:
        '%f[set] 是 frontier 模式：要求前一个字符不属于 set、当前字符属于 set，'
        '但两个字符都不会被消耗。'
        '用它可以在不破坏原文本的情况下匹配「单词开头」，'
        '这是纯模式匹配做整词替换的关键技巧。',
    code: r'''local text = "cat concat cat.cat"
print(text:gsub("%f[%w]cat%f[%W]", "dog"))
print(text:gsub("cat", "dog"))

local count = 0
for _ in text:gmatch("%f[%a]cat%f[%A]") do
  count = count + 1
end
print(count)
''',
    output: 'dog concat dog.dog\t3\ndog condog dog.dog\t4\n3\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 "concat" 里的 cat 没有被第一种写法替换？',
        hint: '前面还有字母，不满足边界条件。',
        answer:
            '因为 c 前面的字符 n 属于 %w，不满足 %f[%w] 的边界条件；而普通 gsub("cat") 不做边界判断，会把 concat 改成 condog。',
      ),
      LuaExercise(
        prompt: '把整词匹配换成数字开头的边界。',
        hint: '把集合换成 %d。',
        answer: 'text:gsub("%f[%d]%d+%f[%D]", "#")',
      ),
    ],
    pitfalls: ['%f 只能用在字符集上，不能直接跟字符串。', '边界模式不消耗字符，所以写 gsub 时要注意替换范围。'],
  ),
  LuaTopic(
    id: 'lua-pat-balanced',
    chapter: 'patterns',
    title: '%b 平衡匹配',
    summary: '用 %b() 匹配成对的括号，处理嵌套结构。',
    objective: '能提取括号内的内容，包括内部还有括号的情况。',
    level: 'advanced',
    concepts: ['%b', '括号匹配', '嵌套'],
    explain:
        '%bxy 匹配以 x 开头、以 y 结尾且内部成对平衡的文本。'
        '最常见的用法是 %b() 提取函数调用参数，它能正确跳过内部嵌套的括号。'
        '这比手写括号计数简单得多，但只支持单字符分隔符。',
    code: r'''print(("f(a, b)"):match("%b()"))
print(("f(g(x), y)"):match("%b()"))
print(("outer [inner [deep]] end"):match("%b[]"))

local code = "call(alpha, beta(gamma))"
local args = code:match("%b()")
print(args)
print(#args)
''',
    output: '(a, b)\n(g(x), y)\n[inner [deep]]\n(alpha, beta(gamma))\n20\n',
    exercises: [
      LuaExercise(
        prompt: '提取方括号里的内容。',
        hint: '用 %b[]。',
        answer: 'local inner = text:match("%b[]")',
      ),
      LuaExercise(
        prompt: '把括号去掉只留内容。',
        hint: '用 sub 去掉首尾字符。',
        answer: 'local inner = text:match("%b()"):sub(2, -2)',
      ),
    ],
    pitfalls: [
      '%b 只处理单字符分隔符，不能匹配 "begin ... end" 这种多字符结构。',
      '如果括号本身不配对，%b 会匹配失败返回 nil。',
    ],
  ),
  LuaTopic(
    id: 'lua-pat-gsub-string',
    chapter: 'patterns',
    title: 'gsub：替换与替换次数',
    summary: 'gsub 返回替换后的新字符串和实际替换次数。',
    objective: '能完成全局替换，并利用第二返回值判断是否命中。',
    level: 'beginner',
    concepts: ['gsub', '替换', '次数'],
    explain:
        's:gsub(pat, repl) 把所有匹配替换掉，返回两个值：新字符串和替换次数。'
        '第四个参数可以限制最多替换几次。'
        '原字符串不会被修改，因为 Lua 字符串不可变。',
    code: r'''print(("hello world"):gsub("o", "0"))
print(("hello world"):gsub("o", "0", 1))
print(("aaa"):gsub("a", "b"))
print(("no match here"):gsub("zzz", "x"))

local replaced, count = ("a-b-c"):gsub("%-", "_")
print(replaced, count)

print(("john smith"):gsub("(%a+) (%a+)", "%2 %1"))
''',
    output:
        'hell0 w0rld\t2\nhell0 world\t1\nbbb\t3\nno match here\t0\n'
        'a_b_c\t2\nsmith john\t1\n',
    exercises: [
      LuaExercise(
        prompt: '把 "Lua 5.4" 改成 "5.4 Lua"。',
        hint: '用两个捕获加 %2 %1。',
        answer: 'print(("Lua 5.4"):gsub("(%a+) (%d+%.%d+)", "%2 %1"))',
      ),
      LuaExercise(
        prompt: '替换串里写 %1 是什么意思？',
        hint: '和模式里的括号有关。',
        answer: '%1 引用第一个捕获的内容，%2 引用第二个，%0 代表整个匹配。',
      ),
    ],
    pitfalls: [
      '替换串里的 % 是特殊字符（用于引用捕获），需要字面百分号时代码可读性会变差，建议改用其他字符或 string.rep。',
      'gsub 返回两个值，直接赋值给一个变量会丢掉次数。',
    ],
  ),
  LuaTopic(
    id: 'lua-pat-gsub-function',
    chapter: 'patterns',
    title: 'gsub 用函数生成替换',
    summary: '替换参数可以是函数，按捕获内容计算替换结果。',
    objective: '能用函数替换实现条件替换和数值变换。',
    level: 'intermediate',
    concepts: ['gsub', '函数替换', '捕获'],
    explain:
        '当第二个参数是函数时，gsub 会把每次匹配的捕获作为参数调用它，'
        '用返回值作为替换文本；返回 nil 表示保留原样。'
        '这让「把匹配到的数字加倍」「只替换满足条件的部分」变得非常直接。',
    code: r'''print(("a1 b2 c3"):gsub("%d", function(d)
  return tostring(tonumber(d) * 2)
end))

print(("x=1, y=2"):gsub("(%a)=(%d)", function(key, value)
  return key .. ":" .. value
end))

print(("keep drop keep"):gsub("drop", function()
  return nil
end))

local words = ("one two three"):gsub("%a+", function(word)
  return word:upper()
end)
print(words)   -- 只接一个变量，所以替换次数被丢掉了

local upperAll, replaced = ("one two three"):gsub("%a+", string.upper)
print(upperAll, replaced)
''',
    output:
        'a2 b4 c6\t3\nx:1, y:2\t2\nkeep drop keep\t1\nONE TWO THREE\n'
        'ONE TWO THREE\t3\n',
    exercises: [
      LuaExercise(
        prompt: '把所有数字替换成它的平方。',
        hint: '函数里 return tostring(n * n)。',
        answer:
            'text:gsub("%d+", function(n) return tostring(tonumber(n) ^ 2) end)',
      ),
      LuaExercise(
        prompt: '函数返回 nil 时，那次匹配算不算替换？',
        hint: '看第二返回值和输出文本。',
        answer: '文本保持原样，但匹配本身仍计入替换次数，所以 keep drop keep 输出 1。',
      ),
    ],
    pitfalls: ['函数必须返回字符串或数字，返回其他类型会报错。', '捕获个数要和函数参数个数对应。'],
  ),
  LuaTopic(
    id: 'lua-pat-gsub-table',
    chapter: 'patterns',
    title: 'gsub 用表做映射',
    summary: '替换参数是表时，用匹配到的文本作为键查表。',
    objective: '能用映射表批量替换模板变量，实现简单模板。',
    level: 'intermediate',
    concepts: ['gsub', '表替换', '模板'],
    explain:
        '第二个参数传表时，gsub 用匹配到的文本查表，查到就替换，查不到保留原样。'
        '这正是轻量模板引擎的做法：把 {{name}} 这样的模板变量映射成实际值。'
        '它比函数替换更声明式，配置写在表里一目了然。',
    code: r'''local values = { name = "小明", lang = "Lua" }
local template = "你好 {{name}}，欢迎学习 {{lang}}"
print((template:gsub("{{(%w+)}}", values)))

local mapping = { apple = "苹果", banana = "香蕉" }
print(("apple and banana and cherry"):gsub("%a+", mapping))

local missing = ("{{unknown}}"):gsub("{{(%w+)}}", values)
print(missing)
''',
    output: '你好 小明，欢迎学习 Lua\n苹果 and 香蕉 and cherry\t5\n{{unknown}}\n',
    exercises: [
      LuaExercise(
        prompt: '为什么模板替换那一行没有输出替换次数？',
        hint: '看代码里那个额外的括号。',
        answer: '因为调用外面又包了一层圆括号，把多返回值截断成一个，所以只输出字符串。',
      ),
      LuaExercise(
        prompt: '为什么映射表替换时输出 5 次？',
        hint: '%a+ 会匹配每个单词，包括 and。',
        answer: 'apple、and、banana、and、cherry 共 5 次匹配，and 在表里没有键所以保持原样但会计次。',
      ),
    ],
    pitfalls: ['表替换只按整个匹配文本查键，不做捕获展开；要捕获请用函数。', '键必须与匹配文本完全一致，包括大小写。'],
  ),
  LuaTopic(
    id: 'lua-pat-gmatch',
    chapter: 'patterns',
    title: 'gmatch：迭代所有匹配',
    summary: 'gmatch 返回迭代器，配合 for 逐个处理匹配结果。',
    objective: '能用 gmatch 遍历所有匹配，并统计或重组数据。',
    level: 'beginner',
    concepts: ['gmatch', '迭代器', '统计'],
    explain:
        's:gmatch(pat) 返回一个迭代器，每次调用给出下一个匹配。'
        '它比反复 find 加偏移更简洁，也不会因为替换而改变原字符串。'
        '常见用途是统计单词、提取所有数字、按分隔符拆分。',
    code: r'''local text = "one two three two one"
local counts = {}
for word in text:gmatch("%a+") do
  counts[word] = (counts[word] or 0) + 1
end

local keys = {}
for word in pairs(counts) do keys[#keys + 1] = word end
table.sort(keys)
for _, word in ipairs(keys) do
  print(word .. "=" .. counts[word])
end

local numbers = {}
for n in ("a1 b22 c333"):gmatch("%d+") do
  numbers[#numbers + 1] = n
end
print(table.concat(numbers, ","))
''',
    output: 'one=2\nthree=1\ntwo=2\n1,22,333\n',
    exercises: [
      LuaExercise(
        prompt: '统计文本中一共有多少个单词。',
        hint: '在 gmatch 循环里累加计数。',
        answer:
            'local total = 0\nfor _ in text:gmatch("%a+") do total = total + 1 end',
      ),
      LuaExercise(
        prompt: 'gmatch 能不能同时返回多个捕获？',
        hint: '模式里有几个括号就有几个返回值。',
        answer: '可以，for k, v in s:gmatch("(%w+)=(%w+)") 会逐个给出两个捕获。',
      ),
    ],
    pitfalls: ['gmatch 是惰性迭代，循环体里修改原字符串不会影响迭代结果。', '空匹配可能导致无限循环，模式要确保能推进位置。'],
  ),
  LuaTopic(
    id: 'lua-pat-split',
    chapter: 'patterns',
    title: '用模式切分字符串',
    summary: 'Lua 没有 split，需要自己用 gmatch 或 find 实现。',
    objective: '能写出保留空字段的切分函数，并理解为什么不能只用 gmatch。',
    level: 'intermediate',
    concepts: ['切分', 'gmatch', '空字段'],
    explain:
        'Lua 标准库没有 split，通常用 gmatch 抓取「非分隔符片段」。'
        '但这种写法会丢掉连续分隔符产生的空字段，例如 "a,,b" 只得到 a 和 b。'
        '需要保留空字段时要手写循环，用 find 找分隔符并切片。',
    code: r'''local function splitSimple(text, sep)
  local out = {}
  for piece in text:gmatch("([^" .. sep .. "]+)") do
    out[#out + 1] = piece
  end
  return out
end

local function splitKeepEmpty(text, sep)
  local out, position = {}, 1
  while true do
    local found = text:find(sep, position, true)
    if not found then
      out[#out + 1] = text:sub(position)
      return out
    end
    out[#out + 1] = text:sub(position, found - 1)
    position = found + #sep
  end
end

print(table.concat(splitSimple("a,,b", ","), "|"))
print(#splitSimple("a,,b", ","))
print(table.concat(splitKeepEmpty("a,,b", ","), "|"))
print(#splitKeepEmpty("a,,b", ","))
print(table.concat(splitKeepEmpty("a,b,", ","), "|"))
''',
    output: 'a|b\n2\na||b\n3\na|b|\n',
    exercises: [
      LuaExercise(
        prompt: 'splitKeepEmpty("", ",") 应该返回什么？',
        hint: '空字符串也有一段。',
        answer: '返回 { "" }，长度 1，因为空文本本身就是一个空字段。',
      ),
      LuaExercise(
        prompt: '为什么 splitSimple 会丢掉空字段？',
        hint: '它的模式要求至少一个非分隔符字符。',
        answer: '因为 [^,]+ 要求至少一个字符，连续分隔符之间没有字符可匹配。',
      ),
    ],
    pitfalls: ['把分隔符拼进字符类时要转义特殊字符。', '多字符分隔符不能用字符类，必须用 find(sep, pos, true)。'],
  ),
];
