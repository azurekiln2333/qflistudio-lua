import 'lua_topic.dart';

/// 第四章：字符串基础。
const List<LuaTopic> topicsStrings = [
  LuaTopic(
    id: 'lua-str-concat',
    chapter: 'strings',
    title: '用 .. 拼接字符串',
    summary: '.. 把多个字符串连成一个，数字会自动转文本。',
    objective: '能拼接字符串与数字，并在长列表场景改用 table.concat。',
    level: 'beginner',
    concepts: ['拼接', '..', '数字转文本'],
    explain:
        '.. 是拼接运算符，两边可以是字符串或数字。'
        '它在右侧结合，所以 a .. b .. c 依次拼接。'
        '字符串很多时反复用 .. 会不断创建新字符串，更高效的做法是先放进数组再 table.concat。',
    code: r'''local name = "Lua"
local version = 5.4
print("我是 " .. name .. " " .. version)
print("拼接" .. "没有" .. "空格")

local parts = {}
for i = 1, 4 do
  parts[#parts + 1] = "第" .. i .. "项"
end
print(table.concat(parts, "、"))
''',
    output: '我是 Lua 5.4\n拼接没有空格\n第1项、第2项、第3项、第4项\n',
    exercises: [
      LuaExercise(
        prompt: '把版本号 5.4 显示成 5.4.8 这样的完整版本。',
        hint: '再拼一段字符串。',
        answer: 'print("Lua " .. 5.4 .. ".8")',
      ),
      LuaExercise(
        prompt: '为什么大量拼接推荐 table.concat？',
        hint: '想想每次 .. 都要新建字符串。',
        answer: '先收集到表里再一次拼接，避免产生大量中间字符串，速度和内存都更好。',
      ),
    ],
    pitfalls: [
      'nil 不能参与拼接，会报 attempt to concatenate a nil value。',
      '拼接数字要小心浮点格式，"x" .. 5.0 得到 x5.0。',
    ],
  ),
  LuaTopic(
    id: 'lua-str-escape',
    chapter: 'strings',
    title: '转义序列',
    summary: '在字符串里写换行、制表、引号和各种字节。',
    objective: '能正确转义换行、制表符、引号、反斜杠和字节值。',
    level: 'beginner',
    concepts: ['转义', '\\n', '字节'],
    explain:
        '字符串里的反斜杠开启转义：\\n 换行、\\t 制表、\\\\ 反斜杠、\\" 引号。'
        '用数字可以写任意字节：\\65 表示 ASCII 码 65（字母 A），\\x41 也一样。'
        '要让反斜杠本身出现在字符串里，写成 \\\\。',
    code: r'''print("第一行\n第二行")
print("制表\t分隔")
print("引号：\"双引号\" 与 '单引号'")
print("反斜杠：\\")
print("\65\x42\67")
print(#"\n")
''',
    output:
        '第一行\n第二行\n制表\t分隔\n引号："双引号" 与 \'单引号\'\n'
        '反斜杠：\\\nABC\n1\n',
    exercises: [
      LuaExercise(
        prompt: '用转义序列输出一个制表符分隔的两列文本。',
        hint: '\\t 就是制表符。',
        answer: 'print("姓名\\t分数")',
      ),
      LuaExercise(
        prompt: '\\65 和 "A" 是同一个字符串吗？',
        hint: '数字转义表示字节值。',
        answer: '是，\\65 表示字节 65，即字母 A。',
      ),
    ],
    pitfalls: [
      '在普通引号字符串里写 C 语言的 \\0 会截断？不会，Lua 允许内嵌零字节，但 print 会照原样输出。',
      '写路径时 Windows 的反斜杠要写成 \\\\。',
    ],
  ),
  LuaTopic(
    id: 'lua-str-long',
    chapter: 'strings',
    title: '长字符串 [[ ]]',
    summary: '长字符串保留换行和引号，不需要转义。',
    objective: '会用长字符串写多行文本，并知道开头的换行会被吃掉。',
    level: 'beginner',
    concepts: ['长字符串', '[[ ]]', '多行文本'],
    explain:
        '用 [[ 和 ]] 包住的内容原样保留，引号和反斜杠都不再特殊，'
        '中间可以有任意多行，非常适合内嵌 SQL、脚本或说明文字。'
        '如果 [[ 后面紧跟一个换行，那个换行会被忽略，方便把内容顶格写。'
        '内容里需要 ]] 时，用 [==[ ... ]==] 加等号来避免提前结束。',
    code: r'''local text = [[
第一行
第二行有 "引号" 和 \反斜杠
]]

print(text)
print(#text)

local nested = [==[
里面有 ]] 也不会提前结束
]==]
print(nested)
''',
    output:
        '第一行\n第二行有 "引号" 和 \\反斜杠\n\n47\n'
        '里面有 ]] 也不会提前结束\n\n',
    exercises: [
      LuaExercise(
        prompt: '统计长字符串 text 有几行。',
        hint: '数换行符再加一。',
        answer: 'local _, count = text:gsub("\\n", "\\n")\nprint(count)',
      ),
      LuaExercise(
        prompt: '为什么 text 的第一个字符不是换行？',
        hint: '[[ 后面的第一个换行会被跳过。',
        answer: 'Lua 会忽略 [[ 后紧跟的那个换行，所以内容从「第一行」开始。',
      ),
    ],
    pitfalls: ['长字符串不做转义，\\n 会原样出现两个字符。', '内容里出现 ]] 会提前终止，需要加等号层级。'],
  ),
  LuaTopic(
    id: 'lua-str-length',
    chapter: 'strings',
    title: '# 取长度：字节数不是字符数',
    summary: '#s 得到的是字节数，中文一个字符通常是 3 个字节。',
    objective: '能区分字节长度和字符长度，并知道何时改用 utf8.len。',
    level: 'beginner',
    concepts: ['长度', '#', '字节'],
    explain:
        'Lua 字符串是字节序列，#s 返回字节数。'
        'ASCII 字符一字节一个，但中文在 UTF-8 编码下通常是 3 字节，所以 #"中文" 是 6。'
        '要按用户看到的字符计数，请用 utf8.len（在 utf8 章节详细讲）。',
    code: r'''print(#"abc")
print(#"")
print(#"中文")
print(utf8.len("中文"))
print(#"a中b")
print(utf8.len("a中b"))
''',
    output: '3\n0\n6\n2\n5\n3\n',
    exercises: [
      LuaExercise(
        prompt: '分别输出 "你好世界" 的字节数和字符数。',
        hint: '4 个汉字 = 12 字节。',
        answer: 'print(#"你好世界", utf8.len("你好世界"))  -- 12 4',
      ),
      LuaExercise(
        prompt: '为什么用 #s 判断字符串为空是安全的？',
        hint: '空字符串没有字节。',
        answer: '因为空字符串长度为 0，且 # 对字符串是精确的字节数，不像表还有边界问题。',
      ),
    ],
    pitfalls: ['用 # 计算中文长度会得到三倍的结果。', '截取中文时要按 utf8.offset 计算，不能直接用字节下标。'],
  ),
  LuaTopic(
    id: 'lua-str-format-int',
    chapter: 'strings',
    title: 'format 对齐整数',
    summary: '用 %d、%5d、%-5d、%05d 控制宽度和对齐。',
    objective: '能输出对齐的整数表格，并选对宽度、左对齐和补零。',
    level: 'beginner',
    concepts: ['string.format', '%d', '对齐'],
    explain:
        'string.format 把值按格式串排版。%d 输出整数，%5d 右对齐占 5 列，'
        '%-5d 左对齐，%05d 用 0 填充。'
        '数字宽度固定后，多行输出才能对齐；这也是生成文本表格最常用的手段。',
    code: r'''print(string.format("[%d]", 42))
print(string.format("[%5d]", 42))
print(string.format("[%-5d]", 42))
print(string.format("[%05d]", 42))
print(string.format("%d + %d = %d", 2, 3, 2 + 3))
print(string.format("[%3d][%3d]", 1, 1000))
''',
    output: '[42]\n[   42]\n[42   ]\n[00042]\n2 + 3 = 5\n[  1][1000]\n',
    exercises: [
      LuaExercise(
        prompt: '把数字 7 输出成 3 位、前导零的形式。',
        hint: '%03d。',
        answer: 'print(string.format("%03d", 7))  -- 007',
      ),
      LuaExercise(
        prompt: '%d 碰到 3.5 会怎样？',
        hint: '格式符要求整数。',
        answer:
            '报错 bad argument #2 to format (number has no integer representation)。',
      ),
    ],
    pitfalls: ['%d 不接受非整数值的浮点，先 math.floor 或改用 %s。', '宽度不足时不会截断，只是不再补齐。'],
  ),
  LuaTopic(
    id: 'lua-str-format-float',
    chapter: 'strings',
    title: 'format 小数与百分号',
    summary: '%f 保留 6 位小数，%.2f 指定精度，%% 输出百分号。',
    objective: '能控制小数位数、宽度，并正确输出百分号文本。',
    level: 'beginner',
    concepts: ['%.2f', '精度', '%%'],
    explain:
        '%f 默认保留 6 位小数；%.2f 指定两位，%8.3f 同时指定总宽度和小数位。'
        '要输出字面的百分号必须写 %%，因为 % 是格式符的引导字符。'
        '四舍五入由 C 库完成，遇到 .5 的边界不要依赖结果。',
    code: r'''print(string.format("%f", 3.14159))
print(string.format("%.2f", 3.14159))
print(string.format("%8.3f|", 3.14159))
print(string.format("%.0f", 2.4))
print(string.format("完成度 %d%%", 42))
print(string.format("%.2f", 2 / 3))
''',
    output: '3.141590\n3.14\n   3.142|\n2\n完成度 42%\n0.67\n',
    exercises: [
      LuaExercise(
        prompt: '把 0.5 输出成百分数形式并保留一位小数。',
        hint: '先乘 100 再用 %.1f%%。',
        answer: 'print(string.format("%.1f%%", 0.5 * 100))  -- 50.0%',
      ),
      LuaExercise(
        prompt: '为什么输出百分号要写两个？',
        hint: '% 是格式引导符。',
        answer: '单个 % 会被当作格式符开头，%% 才是字面的百分号。',
      ),
    ],
    pitfalls: [
      '%.0f 对 .5 的舍入依赖底层 C 库，不同平台可能不一致，教学用例请避开 .5 边界。',
      '浮点格式不会保留你写的尾随零以外的信息。',
    ],
  ),
  LuaTopic(
    id: 'lua-str-format-sq',
    chapter: 'strings',
    title: '%s 与 %q：文本与可读源码',
    summary: '%s 输出原样文本，%q 输出可被 Lua 重新读入的转义形式。',
    objective: '能用 %s 拼消息，用 %q 输出带引号和换行的可读源码。',
    level: 'intermediate',
    concepts: ['%s', '%q', '转义输出'],
    explain:
        '%s 直接放入字符串内容。'
        '%q 输出一个能嵌回 Lua 源码的形式：会自动加引号、转义换行和引号，'
        '写代码生成器或调试输出时非常好用。'
        '需要注意 %q 对某些二进制内容会退化成十六进制写法，只适合文本调试。',
    code: r'''print(string.format("名字：%s，年龄：%s", "小明", 18))
print(string.format("%q", "带\"引号\"的文本"))
print(string.format("%q", "第一行\n第二行"))
print(string.format("%q", "反斜杠\\和制表\t"))
''',
    output:
        '名字：小明，年龄：18\n"带\\"引号\\"的文本"\n'
        '"第一行\\\n第二行"\n"反斜杠\\\\和制表\\9"\n',
    exercises: [
      LuaExercise(
        prompt: '用 %q 输出一段带换行的文本，观察结果如何被转义。',
        hint: '直接对比 %s 与 %q 的输出。',
        answer: 'print(string.format("%q", "a\\nb")) 输出 "a\\\nb"，换行被写成反斜杠加真换行。',
      ),
      LuaExercise(
        prompt: '什么时候应该用 %q 而不是 %s？',
        hint: '想想「把值写回代码」。',
        answer: '当输出要被重新解析成 Lua 字符串时用 %q，普通展示用 %s。',
      ),
    ],
    pitfalls: ['%q 的输出是给人或 Lua 解析器看的，不是给最终用户看的。'],
  ),
  LuaTopic(
    id: 'lua-str-case',
    chapter: 'strings',
    title: '大小写转换',
    summary: 'string.upper / string.lower 返回新字符串，不修改原值。',
    objective: '能用大小写转换做不区分大小写的比较。',
    level: 'beginner',
    concepts: ['upper', 'lower', '不区分大小写'],
    explain:
        'string.upper 和 string.lower 返回新建的字符串，原字符串不变（Lua 字符串不可变）。'
        '做不区分大小写的比较时，两边都转成同一个大小写再比。'
        '方法调用写法 s:upper() 等价于 string.upper(s)。',
    code: r'''local word = "Lua"
print(word:upper())
print(word:lower())
print(word)

local a, b = "Hello", "hello"
print(a == b)
print(a:lower() == b:lower())

print(("MiXeD"):upper())
''',
    output: 'LUA\nlua\nLua\nfalse\ntrue\nMIXED\n',
    exercises: [
      LuaExercise(
        prompt: '写一个忽略大小写判断相等的函数。',
        hint: '两边都 lower 再比较。',
        answer: 'local function same(a, b) return a:lower() == b:lower() end',
      ),
      LuaExercise(
        prompt: 'upper 会修改原字符串吗？',
        hint: 'Lua 字符串不可变。',
        answer: '不会，它返回新字符串，原变量仍是原值。',
      ),
    ],
    pitfalls: ['大小写转换只对 ASCII 可靠，非 ASCII 字符需要额外的映射表。'],
  ),
  LuaTopic(
    id: 'lua-str-sub',
    chapter: 'strings',
    title: 'sub 切片与负索引',
    summary: 'string.sub 用 1 起始下标，负数表示从末尾倒着数。',
    objective: '能用正负下标取出前缀、后缀和任意区间。',
    level: 'beginner',
    concepts: ['sub', '负索引', '切片'],
    explain:
        's:sub(i, j) 返回第 i 到第 j 个字节（包含两端）。'
        '下标从 1 开始；负数表示从末尾算：-1 是最后一个字节，-2 是倒数第二个。'
        '省略 j 表示一直到结尾，j 超出范围会被截断到末尾，不会报错。',
    code: r'''local text = "QFLIScript"
print(text:sub(1, 3))
print(text:sub(5))
print(text:sub(-6))
print(text:sub(-6, -2))
print(text:sub(1, 100))
print(text:sub(-100, 3))
print(text:sub(3, 2))
''',
    output: 'QFL\nScript\nScript\nScrip\nQFLIScript\nQFL\n\n',
    exercises: [
      LuaExercise(
        prompt: '取出字符串的最后三个字符。',
        hint: '用负下标。',
        answer: 'print(text:sub(-3))',
      ),
      LuaExercise(
        prompt: '为什么 text:sub(3, 2) 返回空字符串？',
        hint: '起始位置在结束位置之后。',
        answer: 'Lua 规范里 i > j 时返回空字符串，而不是报错。',
      ),
    ],
    pitfalls: ['下标从 1 开始，写 0 等价于 1。', 'sub 按字节切，切中文要按 utf8 的位置算。'],
  ),
  LuaTopic(
    id: 'lua-str-rep',
    chapter: 'strings',
    title: 'rep 重复与分隔符',
    summary: 'string.rep 重复字符串，Lua 5.4 还支持插入分隔符。',
    objective: '能生成分隔线、缩进和重复填充，并控制长度。',
    level: 'beginner',
    concepts: ['rep', '分隔符', '生成文本'],
    explain:
        'string.rep(s, n) 把 s 重复 n 次。'
        'Lua 5.2 起支持第三个参数 sep，可以在每次重复之间插入分隔符，'
        '省掉先拼表再 concat 的步骤。'
        '重复次数为 0 时返回空字符串。',
    code: r'''print(string.rep("ab", 3))
print(string.rep("-", 10))
print(string.rep("a", 3, ","))
print("[" .. string.rep(" ", 5) .. "]")
print(string.rep("x", 0) == "")
print(#string.rep("*", 8))
''',
    output: 'ababab\n----------\na,a,a\n[     ]\ntrue\n8\n',
    exercises: [
      LuaExercise(
        prompt: '生成一条 20 个等号的标题下划线。',
        hint: '用 rep。',
        answer: 'print(string.rep("=", 20))',
      ),
      LuaExercise(
        prompt: '用 rep 输出 "1,2,3" 需要怎么写？',
        hint: 'rep 重复相同内容；不同元素要用 concat。',
        answer:
            'print(string.rep("123", 1)) 不行；正确做法是 table.concat({1,2,3}, ",")。',
      ),
    ],
    pitfalls: [
      '重复次数很大时会占用大量内存，不要用超大次数做测试。',
      'sep 参数从 Lua 5.2 开始支持，不能把它当作 5.4 才有的新特性。',
    ],
  ),
  LuaTopic(
    id: 'lua-str-compare',
    chapter: 'strings',
    title: '字符串比较与排序',
    summary: 'table.sort 可以排序字符串，排序规则受当前区域设置影响。',
    objective: '能预测字符串比较结果，并按自定义规则排序。',
    level: 'intermediate',
    concepts: ['比较', '排序', '字节序'],
    explain:
        '字符串的大小比较遵循当前区域设置；默认 C 区域设置下按字节顺序比较，短串若是长串前缀则更小。'
        '在默认 C 区域设置中，大写 ASCII 字母排在小写之前，所以 "Z" < "a"。'
        'table.sort 默认用这个顺序；想忽略大小写就把比较函数换成 lower 后比较。',
    code: r'''print("apple" < "banana")
print("Z" < "a")
print("abc" < "abcd")
print("a" == "a")

local words = { "pear", "Apple", "banana" }
table.sort(words)
print(table.concat(words, " "))

table.sort(words, function(a, b) return a:lower() < b:lower() end)
print(table.concat(words, " "))
''',
    output: 'true\ntrue\ntrue\ntrue\nApple banana pear\nApple banana pear\n',
    exercises: [
      LuaExercise(
        prompt: '为什么排序前 Apple 排在 banana 前面？',
        hint: '大写字节值更小。',
        answer: '在本例的默认 C 区域设置中，ASCII A 的字节值 65 小于 b 的 98；改变区域设置可能改变排序。',
      ),
      LuaExercise(
        prompt: '按长度从短到长排序一组单词。',
        hint: '比较函数里比 #a 和 #b。',
        answer: 'table.sort(words, function(a, b) return #a < #b end)',
      ),
    ],
    pitfalls: [
      '比较函数必须满足严格弱序，否则 table.sort 会报 invalid order function。',
      '中文排序需要先转成拼音或码点，字节序不等于字典序。',
    ],
  ),
  LuaTopic(
    id: 'lua-str-multiline-report',
    chapter: 'strings',
    title: '组合多行文本报告',
    summary: '把 format、rep、concat 组合成对齐的多行报告。',
    objective: '能生成带标题、分隔线和右对齐数字的多行文本。',
    level: 'intermediate',
    concepts: ['组合', '对齐', '报告'],
    explain:
        '真实输出很少是一行字符串，通常要用多行拼出结构和留白。'
        '这个例子把三样工具组合起来：string.format 对齐每行、string.rep 画分隔线、'
        'table.concat 用换行把行连成一个整体再一次性输出。'
        '一次性输出比逐行 print 更容易测试，因为期望值是单个字符串。'
        '注意 %-6s 是按字节补齐的：一个汉字 3 字节，两个汉字正好占满 6 列，'
        '所以中文名字后面不会有空格，和英文名字的对齐效果并不一样。',
    code: r'''local rows = {
  { name = "苹果", count = 3 },
  { name = "香蕉", count = 12 },
  { name = "橙子", count = 105 },
}

local lines = { "名称   数量", string.rep("-", 12) }
for _, row in ipairs(rows) do
  lines[#lines + 1] = string.format("%-6s%6d", row.name, row.count)
end
print(table.concat(lines, "\n"))
''',
    output: '名称   数量\n------------\n苹果     3\n香蕉    12\n橙子   105\n',
    exercises: [
      LuaExercise(
        prompt: '在报告末尾加一行合计数量。',
        hint: '先求和，再用同样的宽度格式输出。',
        answer: 'lines[#lines + 1] = string.format("%-6s%6d", "合计", 120)',
      ),
      LuaExercise(
        prompt: '为什么 %-6s 对中文会看起来不对齐？',
        hint: '宽度按字节计算。',
        answer: '中文每个字 3 字节，%-6s 按字节补齐，所以视觉宽度和数字对不上。',
      ),
    ],
    pitfalls: ['中英混排的宽度对齐需要考虑字节数与显示宽度不一致的问题。'],
  ),
];
