import 'lua_topic.dart';

/// 第一章：第一个 Lua 程序。
const List<LuaTopic> topicsStart = [
  LuaTopic(
    id: 'lua-start-hello',
    chapter: 'start',
    title: '第一行输出：print',
    summary: '用 print 把一段文本输出到控制台，理解「语句从上往下执行」。',
    objective: '能独立写出不带分号的可运行 Lua 程序并看到输出。',
    level: 'beginner',
    concepts: ['print', '字符串', '语句'],
    explain:
        'Lua 的入口文件从上到下逐条执行语句。print 接收任意多个值，把它们转成文本后输出。'
        'Lua 不要求行尾分号，字符串用双引号或单引号包起来都行，但引号本身不会被输出。',
    code: r'''-- 每行一条语句，Lua 不要求分号
print("你好，Lua 5.4")
print('单引号也可以')
''',
    output: '你好，Lua 5.4\n单引号也可以\n',
    exercises: [
      LuaExercise(
        prompt: '把第一行输出改成你的名字，并在第二行输出今天学习 Lua。',
        hint: '修改 print 括号里的字符串内容即可。',
        answer: 'print("我是小明")\nprint("今天学习 Lua")',
      ),
      LuaExercise(
        prompt: '在 print 语句后面加一个分号，程序还能正常运行吗？',
        hint: 'Lua 把分号当作可选的语句分隔符。',
        answer: '可以，print("hi"); 与 print("hi") 等价，输出完全相同。',
      ),
    ],
    pitfalls: [
      '字符串必须成对引号，缺一个引号会在加载阶段就报 unfinished string。',
      'print("a") 输出 a，不会输出引号本身。',
    ],
  ),
  LuaTopic(
    id: 'lua-start-comments',
    chapter: 'start',
    title: '注释：单行与多行',
    summary: '用 -- 和 --[[ ]] 给代码写说明，理解注释里的代码不会执行。',
    objective: '能区分单行注释、行尾注释和长注释，并用注释临时停用一段代码。',
    level: 'beginner',
    concepts: ['注释', '--', '长注释'],
    explain:
        '两个减号开始到行尾都是注释，放在语句后面就是行尾注释。'
        '--[[ 与 ]] 之间可以跨很多行，适合临时停用一整段代码或写较长的说明。'
        '这两种注释在语法分析阶段就被丢弃，里面的内容永远不会执行。',
    code: r'''-- 单行注释：解释下面的语句
print("第一行会执行") -- 行尾注释同样被忽略

--[[
多行注释可以写很多行。
下面这行代码在注释里，所以永远不会执行：
print("永远看不到这一行")
]]
print("注释结束后的这一行会执行")
''',
    output: '第一行会执行\n注释结束后的这一行会执行\n',
    exercises: [
      LuaExercise(
        prompt: '用多行注释把第二行 print 停用，让程序只输出第一行。',
        hint: '把那条 print 包进 --[[ 和 ]] 之间。',
        answer: '--[[\nprint("第二行")\n]]',
      ),
      LuaExercise(
        prompt: '说明为什么注释掉的代码不会出现语法错误。',
        hint: '想想词法分析发生在什么阶段。',
        answer: '词法阶段就把注释整体跳过，注释内容不会进入语法分析，所以语法错误的代码放在注释里也不影响加载。',
      ),
    ],
    pitfalls: [
      '长注释以 ]] 结束，注释内容本身包含 ]] 时会提前结束。',
      '--[==[ ... ]==] 用等号层数来嵌套，内容里有 ]] 时需要用这种写法。',
    ],
  ),
  LuaTopic(
    id: 'lua-start-print-multi',
    chapter: 'start',
    title: 'print 的多个参数与自动格式化',
    summary: '一次 print 多个值时，Lua 用制表符分隔并自动换行。',
    objective: '会用多参数 print 输出对齐的表格行，并知道数字 79.00 会显示成 79.0。',
    level: 'beginner',
    concepts: ['print', '制表符', '数字格式'],
    explain:
        'print 把每个参数转成字符串，之间插入一个制表符，最后补一个换行。'
        '空 print() 只输出一个换行，可以用来空行。'
        '数字按值打印：整数 408 显示 408，写成 79.00 的字面量属于浮点数，显示成 79.0。',
    code: r'''print("书名", "页数", "价格")
print("Lua 程序设计", 408, 79.00)
print()
print("print 用制表符分隔多个参数，末尾自动换行")
''',
    output:
        '书名\t页数\t价格\nLua 程序设计\t408\t79.0\n\n'
        'print 用制表符分隔多个参数，末尾自动换行\n',
    exercises: [
      LuaExercise(
        prompt: '再输出一行你自己的书名、页数和价格。',
        hint: '照着第三行的格式，注意价格写成整数和浮点会显示成不同结果。',
        answer: 'print("我的书", 120, 39)',
      ),
      LuaExercise(
        prompt: '为什么 79.00 显示成 79.0 而不是 79.00？',
        hint: 'Lua 只有整数和浮点两种数字类型，没有定点小数。',
        answer:
            '79.00 是浮点字面量，不保留源码中的尾随零；本运行时的默认浮点格式也不保证所有数值都能无损往返；需要两位小数请用 string.format("%.2f", 79)。',
      ),
    ],
    pitfalls: [
      'print 的默认分隔符是制表符，想要自定义分隔请用 io.write 或 table.concat。',
      '浮点数不会保留你写的尾随零。',
    ],
  ),
  LuaTopic(
    id: 'lua-start-io-write',
    chapter: 'start',
    title: 'io.write：不自动换行的输出',
    summary: '用 io.write 逐段拼接输出，精确控制换行位置。',
    objective: '能在同一行内分多次写出内容，并解释何时该用 io.write 而不是 print。',
    level: 'beginner',
    concepts: ['io.write', '输出控制', '换行'],
    explain:
        'print 每次都会换行，做进度条或一行内拼接时很不方便。'
        'io.write 按顺序写出每个参数，不会自动加换行，也不加分隔符，换行需要自己写 \\n。'
        '它接受字符串和数字，数字会按 Lua 的数字格式转成文本。',
    code: r'''io.write("正在加载")
io.write(".")
io.write(".")
io.write(".\n")
io.write("总数：", 3, "\n")
io.write(string.format("进度：%d%%\n", 42))
''',
    output: '正在加载...\n总数：3\n进度：42%\n',
    exercises: [
      LuaExercise(
        prompt: '用 io.write 在一行里输出 1+2=3 这样的算式结果。',
        hint: '字符串部分用引号，结果直接传数字。',
        answer: 'io.write("1+2=", 1 + 2, "\n")',
      ),
      LuaExercise(
        prompt: '如果最后一行忘了写 \\n 会发生什么？',
        hint: '观察下一行输出是否和它粘在一起。',
        answer: '下一次输出会紧接在同一行末尾，两段内容粘在一起，这就是必须先显式换行的原因。',
      ),
    ],
    pitfalls: [
      'io.write 不加分隔符，写多个值时它们会直接相连。',
      '百分号要写成 %%，否则 string.format 会把它当格式符。',
    ],
  ),
  LuaTopic(
    id: 'lua-start-version-pairs',
    chapter: 'start',
    title: '读取引擎信息并有序输出',
    summary: '把表里的键值整理成有序文本，认识 _VERSION 与 pairs。',
    objective: '能拿到运行时的 Lua 版本，并用 table.sort 让遍历结果稳定。',
    level: 'beginner',
    concepts: ['_VERSION', 'pairs', 'table.sort'],
    explain:
        '_VERSION 是运行时提供的版本字符串，本机是 Lua 5.4。'
        'pairs 遍历表时顺序不保证，所以把每项先拼成字符串放进数组，再用 table.sort 排序，'
        '这样同一份数据每次运行都得到相同的输出——可重复是教学内容的基本要求。',
    code: r'''print(_VERSION)

local parts = {}
for name, value in pairs({ language = "Lua", engine = _VERSION }) do
  parts[#parts + 1] = name .. "=" .. value
end
table.sort(parts)
print(table.concat(parts, "; "))
''',
    output: 'Lua 5.4\nengine=Lua 5.4; language=Lua\n',
    exercises: [
      LuaExercise(
        prompt: '再往表里加一个 version = 5.4 的项，让输出里出现三条。',
        hint: '在表构造器里加一项，然后重新运行。',
        answer:
            'for name, value in pairs({ language = "Lua", engine = _VERSION, version = 5.4 }) do ... end',
      ),
      LuaExercise(
        prompt: '如果不调用 table.sort，输出顺序会变化吗？',
        hint: 'pairs 的顺序由哈希决定。',
        answer: '可能变化，pairs 不保证顺序；排序后才能保证每次运行输出一致。',
      ),
    ],
    pitfalls: ['pairs 的顺序不是插入顺序，不能依赖它做断言。'],
  ),
  LuaTopic(
    id: 'lua-start-grade-report',
    chapter: 'start',
    title: '第一个完整小程序：成绩单',
    summary: '用数组、循环和格式化把一组分数打印成成绩单。',
    objective: '能把数据、遍历、格式化三部分组合成一个可直接运行的小程序。',
    level: 'beginner',
    concepts: ['数组', 'for 循环', 'string.format'],
    explain:
        '这个程序分三步：先把分数放进数组，再用索引循环逐个处理，最后用 string.format 控制小数位。'
        'Lua 数组下标从 1 开始，#scores 得到元素个数，所以循环可以写成 for index = 1, #scores。'
        '整除问题不存在：总分是整数，除以人数得到浮点，正好交给 %.2f 处理。',
    code: r'''local scores = { 92, 78, 65 }
local total = 0

for index = 1, #scores do
  total = total + scores[index]
  print(string.format("第 %d 位同学：%d 分", index, scores[index]))
end

print(string.format("平均分：%.2f", total / #scores))
''',
    output: '第 1 位同学：92 分\n第 2 位同学：78 分\n第 3 位同学：65 分\n平均分：78.33\n',
    exercises: [
      LuaExercise(
        prompt: '再加一位同学 88 分，平均分会变成多少？',
        hint: '总分 323，人数 4。',
        answer: '在数组里加 88，总分 323，平均分输出 80.75。',
      ),
      LuaExercise(
        prompt: '把「第 %d 位同学」改成从 0 开始编号。',
        hint: '只改格式化参数，不要动数组下标。',
        answer:
            'print(string.format("第 %d 位同学：%d 分", index - 1, scores[index]))',
      ),
    ],
    pitfalls: [
      '%d 要求参数能无损转为整数；3.0 可以，3.5 会报错。需要小数请用 %f，不要无意截断。',
      '数组下标从 1 开始，习惯 0 起始的写法会拿到 nil。',
    ],
  ),
];
