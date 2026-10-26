import 'lua_topic.dart';

/// 第十七章：os 与 io。
const List<LuaTopic> topicsOsIo = [
  LuaTopic(
    id: 'lua-os-time-basic',
    chapter: 'osio',
    title: 'os.time 与 os.date 基础',
    summary: 'time 返回时间戳，date 把时间戳格式化成可读文本。',
    objective: '能用固定时间戳格式化出稳定的日期文本。',
    level: 'beginner',
    concepts: ['os.time', 'os.date', '时间戳'],
    explain:
        'os.time() 返回当前时间；本应用支持的平台通常以秒表示时间戳。'
        'os.date(fmt, t) 把时间戳按格式转成字符串，'
        '格式符和 C 的 strftime 一致：%Y 年、%m 月、%d 日。'
        '固定时间戳配合 ! 前缀按 UTC 转换，才能避开设备本地时区。'
        '%A 等星期名称还受区域设置影响，稳定输出使用数字格式。',
    code: r'''local fixed = 1792627200
print(os.date("!%Y-%m-%d", fixed))
print(os.date("!%Y/%m/%d %H:%M:%S", fixed))
print(os.date("!%w", fixed))
print(type(os.time()))
print(os.date("!*t", fixed).wday == 5)
print(os.date("!%Y", fixed))
''',
    output: '2026-10-22\n2026/10/22 00:00:00\n4\nnumber\ntrue\n2026\n',
    exercises: [
      LuaExercise(
        prompt: '把固定时间戳格式化成「年月日」。',
        hint: '! 选择 UTC，%Y-%m-%d 选择数字格式。',
        answer: 'print(os.date("!%Y-%m-%d", fixed))',
      ),
      LuaExercise(
        prompt: '固定时间戳为什么还不够保证日期文本稳定？',
        hint: '区分时区与区域设置。',
        answer: '默认按本地时区转换，星期和月份名称还依赖区域设置；这里用 ! 指定 UTC，并只输出数字字段。',
      ),
    ],
    pitfalls: [
      'os.date 默认按本地时区转换，同一时间戳在不同时区输出不同。',
      '不要把当前时间与固定日期的大小关系写成恒真的期望输出。',
    ],
  ),
  LuaTopic(
    id: 'lua-os-time-table',
    chapter: 'osio',
    title: '日期表与 os.time 反向转换',
    summary: 'date("*t") 返回日期表，os.time 可以用日期表反向求时间戳。',
    objective: '能在时间戳和日期表之间双向转换，并读取字段。',
    level: 'intermediate',
    concepts: ['日期表', 'os.time', '字段'],
    explain:
        'os.date("*t", t) 返回含 year/month/day/hour/min/sec 等字段的表。'
        '!*t 返回 UTC 字段；os.time(table) 始终把日期表解释为本地时间。'
        '因此反向转换应使用本地 *t 表，并保留 isdst 字段，不能把 UTC 表直接交给 os.time。'
        'month 是 1 到 12，day 从 1 开始。',
    code: r'''local fixed = 1792627200
local parts = os.date("!*t", fixed)

print(parts.year, parts.month, parts.day)
print(parts.hour, parts.min, parts.sec)
print(parts.wday)

local localParts = os.date("*t", fixed)
local rebuilt = os.time(localParts)

print(rebuilt == fixed)

local tomorrow = os.date("!*t", fixed + 86400)
print(tomorrow.day)
''',
    output: '2026\t10\t22\n0\t0\t0\n5\ntrue\n23\n',
    exercises: [
      LuaExercise(
        prompt: '求固定时间戳的第二天是几号。',
        hint: '加 86400 秒，并明确按 UTC 转换。',
        answer: 'print(os.date("!*t", fixed + 86400).day)',
      ),
      LuaExercise(
        prompt: '为什么加 86400 秒不总是「第二天同一时刻」？',
        hint: '想想夏令时。',
        answer: '因为夏令时切换那天可能只有 23 或 25 小时，按秒加会偏移。',
      ),
    ],
    pitfalls: [
      'os.time 的日期表必须提供 year/month/day，其他字段可选。',
      'UTC 表不是 os.time 的 UTC 输入格式；本地时间回转要保留 isdst，避免夏令时歧义。',
      '跨夏令时按秒加减不等于按日加减。',
    ],
  ),
  LuaTopic(
    id: 'lua-os-clock',
    chapter: 'osio',
    title: '用 os.clock 测量耗时',
    summary: 'clock 返回程序消耗的 CPU 时间，适合做性能对比。',
    objective: '能测量近似 CPU 耗时，并用类型、非负性和计算结果检查程序。',
    level: 'intermediate',
    concepts: ['os.clock', 'CPU 时间', '计时精度'],
    explain:
        'os.clock() 返回底层 C clock 提供的近似进程 CPU 秒数。'
        '两次调用相减可估计一段代码的 CPU 耗时。'
        '分辨率与调度会影响结果，短任务可能都测得 0；更长的循环也不能保证每次测得更长。'
        '示例只检查计时值非负和计算结果，不断言速度排名。',
    code: r'''local start = os.clock()
local total = 0
for i = 1, 200000 do total = total + i end
local elapsed = os.clock() - start

print(type(elapsed))
print(elapsed >= 0)
print(total)

local fastStart = os.clock()
local a = 0
for i = 1, 10000 do a = a + i end
local fastElapsed = os.clock() - fastStart

local slowStart = os.clock()
local b = 0
for i = 1, 300000 do b = b + i end
local slowElapsed = os.clock() - slowStart

print(fastElapsed >= 0 and slowElapsed >= 0)
print(a > 0 and b > a)
''',
    output: 'number\ntrue\n20000100000\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '测量一个循环的 CPU 耗时。',
        hint: 'clock 前后相减。',
        answer:
            'local s = os.clock(); for i = 1, 1000 do end; print(os.clock() - s)',
      ),
      LuaExercise(
        prompt: '为什么不用 os.time 测短耗时？',
        hint: '精度。',
        answer:
            '常见平台的 os.time 只有秒级粒度，短任务可能测得 0，也可能刚好跨秒；os.clock 可估计 CPU 耗时，但同样受计时分辨率影响。',
      ),
    ],
    pitfalls: [
      'CPU 时间不同于经过的实际时间，不适合直接衡量等待 IO 的延迟。',
      '耗时会抖动或相等，不要断言精确数值或固定的快慢关系。',
    ],
  ),
  LuaTopic(
    id: 'lua-os-getenv',
    chapter: 'osio',
    title: '读取环境变量',
    summary: 'os.getenv 读环境变量，读不到返回 nil。',
    objective: '能用 getenv 做可选配置，并区分「未设置」与「空字符串」。',
    level: 'beginner',
    concepts: ['os.getenv', '配置', 'nil'],
    explain:
        'os.getenv("NAME") 返回变量值，不存在时返回 nil（不是空串）。'
        '因此用 or 提供默认值是安全的：'
        '如果变量被显式设成空串，or 不会替换它，这正好符合「空也是值」的语义。',
    code: r'''local path = os.getenv("PATH")
print(path == nil or type(path) == "string")

local function config(name, default, lookup)
  local value = (lookup or os.getenv)(name)
  if value == nil then return default end
  return value
end

-- 用显式数据演示三种情况，不假设设备预置了任何环境变量。
local fixture = { EMPTY = "", LABEL = "configured" }
local function lookup(name) return fixture[name] end
print(config("MISSING", "fallback", lookup))
print(config("EMPTY", "fallback", lookup) == "")
print(config("LABEL", "fallback", lookup))
print(type(config("PATH", "fallback")) == "string")
''',
    output: 'true\nfallback\ntrue\nconfigured\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '读取 QFLI_LABEL，没有就返回 "local"。',
        hint: 'or 的短路。',
        answer: 'local label = os.getenv("QFLI_LABEL") or "local"',
      ),
      LuaExercise(
        prompt: '环境变量设为空字符串时，or 会使用默认值吗？',
        hint: '空字符串的真假。',
        answer:
            '不会，空字符串是真值。getenv 只返回字符串或 nil，所以在这个特定接口中 if not value 和 value == nil 等效。',
      ),
    ],
    pitfalls: [
      '未设置返回 nil，设为空串返回 ""，两者不同。',
      'PATH、HOME 等变量可能未设置，尤其在移动端应用进程中；不能直接对返回值取长度。',
    ],
  ),
  LuaTopic(
    id: 'lua-io-write-read',
    chapter: 'osio',
    title: '写文件再读回来',
    summary: '用 io.open 写文件，再用 lines 或 read("a") 读回内容。',
    objective: '能完成写入、关闭、读取的完整流程，并正确处理打开失败。',
    level: 'beginner',
    concepts: ['io.open', 'io.lines', '关闭文件'],
    explain:
        'io.open(path, "w") 返回文件句柄，失败时返回 nil 和错误消息。'
        '写完后必须 close，否则内容可能还没落盘。'
        '读的时候可以用 f:read("a") 一次读完，也可以用 io.lines 逐行。',
    code: r'''local path = "notes.txt"

local file = assert(io.open(path, "w"))
file:write("第一行\n")
file:write("第二行\n")
file:close()

local reader = assert(io.open(path, "r"))
local content = reader:read("a")
reader:close()

print(content)
print(#content)

local count = 0
for line in io.lines(path) do
  count = count + 1
  print(count, line)
end

local missing, err = io.open("no_such_file_12345.txt", "r")
print(missing == nil, err ~= nil)
''',
    output: '第一行\n第二行\n\n20\n1\t第一行\n2\t第二行\ntrue\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '往文件追加一行而不覆盖原内容。',
        hint: '模式用 "a"。',
        answer:
            'local f = assert(io.open(path, "a")); f:write("追加\\n"); f:close()',
      ),
      LuaExercise(
        prompt: '为什么 open 之后要检查返回值？',
        hint: '权限或路径问题。',
        answer: '因为失败时返回 nil 而不是抛错，直接调用 write 会得到 nil 索引错误，掩盖真正原因。',
      ),
    ],
    pitfalls: ['忘记 close 可能丢数据。', '"w" 会截断文件，"a" 才是追加。'],
  ),
  LuaTopic(
    id: 'lua-io-read-formats',
    chapter: 'osio',
    title: 'read 的各种格式',
    summary: 'read 支持按行、按字节数、按全部内容读取。',
    objective: '能用 "l"、"n"、"a" 和数字参数读取不同粒度的数据。',
    level: 'intermediate',
    concepts: ['read', '格式参数', '文件读取'],
    explain:
        'read("l") 读一行（不含换行），read("n") 读一个数字，'
        'read(5) 读 5 个字节，read("a") 读到末尾。'
        '多个参数可以组合：read("l", "l") 一次读两行。'
        '读不到一行、数字或正数字节数时返回 nil；read("a") 在 EOF 返回空字符串，read(0) 则用于检测 EOF。',
    code: r'''local path = "data.txt"
local writer = assert(io.open(path, "w"))
writer:write("alpha\nbeta\n42 3.5\nrest\n")
writer:close()

local file = assert(io.open(path, "r"))
print(file:read("l"))
print(file:read(3))
print(file:read("l"))
print(file:read("n"), file:read("n"))
print("[" .. file:read("l") .. "]")
print(file:read("a"))
print(#file:read("a"))
file:close()
''',
    output: 'alpha\nbet\na\n42\t3.5\n[]\nrest\n\n0\n',
    exercises: [
      LuaExercise(
        prompt: '一次读两行。',
        hint: '传两个 "l"。',
        answer: 'local a, b = file:read("l", "l")',
      ),
      LuaExercise(
        prompt: '为什么读取两个数字后，紧接着的 read("l") 得到空串？',
        hint: '想想剩下的内容。',
        answer:
            'read("n") 读完 3.5 后，行尾换行仍在输入中；接着 read("l") 读到这段空行尾并消费换行。前面的 read(3) 读掉 bet 后，read("l") 实际返回 a。',
      ),
    ],
    pitfalls: ['"n" 会跳过前导空白；失败时也可能已经消费空白或候选数字前缀，不能假设文件位置不变。', '按字节读会把多字节字符切断。'],
  ),
  LuaTopic(
    id: 'lua-io-lines-filter',
    chapter: 'osio',
    title: '用 io.lines 逐行过滤',
    summary: '边读边处理，避免把大文件整个读进内存。',
    objective: '能用 io.lines 实现过滤、统计和转换，并正确关闭句柄。',
    level: 'intermediate',
    concepts: ['io.lines', '流式处理', '过滤'],
    explain:
        'io.lines(path) 返回迭代器，for 每轮拿到一行。'
        '这种写法不需要保存整个文件，额外内存主要取决于单行长度和自己的处理逻辑。'
        'Lua 5.4 中 for line in io.lines(path) do 会使用第四个关闭值，在正常结束、break、return 或错误时关闭文件。'
        'file:lines() 不接管已有句柄，示例中的 firstMatch 选择手动关闭它。',
    code: r'''local path = "log.txt"
local writer = assert(io.open(path, "w"))
writer:write("INFO start\n")
writer:write("WARN disk 90%\n")
writer:write("INFO running\n")
writer:write("ERROR failed\n")
writer:close()

local warnings = 0
for line in io.lines(path) do
  if line:match("^WARN") then warnings = warnings + 1 end
end
print(warnings)

local levels = {}
for line in io.lines(path) do
  local level = line:match("^(%u+)")
  levels[#levels + 1] = level
end
print(table.concat(levels, ","))

local function firstMatch(path, pattern)
  local file = assert(io.open(path, "r"))
  for line in file:lines() do
    if line:match(pattern) then
      file:close()
      return line
    end
  end
  file:close()
  return nil
end

print(firstMatch(path, "ERROR"))
print(firstMatch(path, "DEBUG") == nil)
''',
    output: '1\nINFO,WARN,INFO,ERROR\nERROR failed\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '统计文件里包含 "INFO" 的行数。',
        hint: 'io.lines + match。',
        answer:
            'local n = 0\nfor line in io.lines(path) do if line:match("INFO") then n = n + 1 end end',
      ),
      LuaExercise(
        prompt: '为什么 firstMatch 要在两个返回点都 close？',
        hint: '提前 return 会跳过什么。',
        answer: '因为提前 return 会跳出函数，若不先 close 就泄漏了文件句柄。',
      ),
    ],
    pitfalls: [
      '把 io.lines(path) 只赋给一个迭代器变量会丢弃第四个关闭值，提前停止时需要自己管理文件。',
      '逐行读会去掉行尾换行符。',
    ],
  ),
  LuaTopic(
    id: 'lua-io-tmpfile',
    chapter: 'osio',
    title: '临时文件与清理',
    summary: '用 os.tmpname 得到临时路径，用完 os.remove 删除。',
    objective: '能写出用完即删的临时文件流程，并在出错时也清理。',
    level: 'intermediate',
    concepts: ['os.tmpname', 'os.remove', '清理'],
    explain:
        'os.tmpname() 返回临时文件名，调用者仍需显式打开文件并检查错误。'
        'POSIX 实现会同时创建文件以预留名称，其他实现可能只返回名称；不能假设文件不存在。'
        '用完必须 os.remove 清理，即使没有写入也一样。'
        '可能出错的操作可放入 pcall；回调使用 <close> 释放句柄后再删除路径。',
    code: r'''local name = os.tmpname()
print(type(name))

local file = assert(io.open(name, "w"))
file:write("temporary\n")
file:close()

local reader = assert(io.open(name, "r"))
local content = reader:read("a")
reader:close()
print(content)

local removed = os.remove(name)
print(removed)
print(os.remove(name) == nil)

local function withTempFile(fn)
  local path = os.tmpname()
  local ok, result = pcall(fn, path)
  local removed, removeError = os.remove(path)
  if not removed then return false, removeError end
  return ok, result
end

local ok, err = withTempFile(function(path)
  local f <close> = assert(io.open(path, "w"))
  f:write("x")
  return path
end)
print(ok, err ~= nil)
''',
    output: 'string\ntemporary\n\ntrue\ntrue\ntrue\ttrue\n',
    exercises: [
      LuaExercise(
        prompt: '用临时文件写一行再读回来。',
        hint: 'tmpname + open + close。',
        answer:
            'local p = os.tmpname()\nlocal f = assert(io.open(p, "w"))\nf:write("hi")\nf:close()\nlocal r = assert(io.open(p, "r"))\nprint(r:read("a"))\nr:close()\nos.remove(p)',
      ),
      LuaExercise(
        prompt: '为什么不能假设 tmpname 调用后文件一定不存在？',
        hint: 'POSIX 与其他实现可能不同。',
        answer: 'POSIX 实现会创建文件来预留名称；所有实现都要求显式打开、检查返回值并负责删除，不应依赖它尚未存在。',
      ),
    ],
    pitfalls: [
      '临时文件位置由运行时决定；目录不可写时 tmpname 会报错。只需要匿名临时句柄时可考虑 io.tmpfile。',
      '删除不存在的文件返回 nil 而不是抛错。',
    ],
  ),
  LuaTopic(
    id: 'lua-io-rename-dir',
    chapter: 'osio',
    title: '重命名、删除与目录操作',
    summary: 'rename 改名，remove 删文件或空目录。',
    objective: '能完成文件改名和清理，并知道 remove 不能删非空目录。',
    level: 'intermediate',
    concepts: ['os.rename', 'os.remove', '目录'],
    explain:
        'os.rename(old, new) 改名，成功返回 true。'
        'os.remove(path) 可以删文件，也可以删空目录。'
        '非空目录无法用 remove 删除，需要逐个删子项，'
        '所以标准 Lua 并没有递归删目录的库函数。',
    code: r'''local original = "original.txt"
local renamed = "renamed.txt"

local f = assert(io.open(original, "w"))
f:write("data\n")
f:close()

print(os.rename(original, renamed))
print(os.rename(original, "another.txt") == nil)

local reader = assert(io.open(renamed, "r"))
print(reader:read("a"))
reader:close()

print(os.remove(renamed))
print(os.remove(renamed) == nil)

print(os.rename(renamed, "x.txt") == nil)
''',
    output: 'true\ntrue\ndata\n\ntrue\ntrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '把 a.txt 改名为 b.txt 再删掉。',
        hint: 'rename 然后 remove。',
        answer: 'assert(os.rename("a.txt", "b.txt"))\nos.remove("b.txt")',
      ),
      LuaExercise(
        prompt: '为什么删除不存在的文件不报错？',
        hint: '看返回值。',
        answer: 'os.remove 失败时返回 nil、错误消息和错误码，不抛异常，需要自己检查返回值。',
      ),
    ],
    pitfalls: ['rename 跨磁盘分区可能失败。', 'remove 不能删非空目录。'],
  ),
  LuaTopic(
    id: 'lua-io-csv-parse',
    chapter: 'osio',
    title: '解析简单 CSV',
    summary: '按逗号切分每行，把文本表格变成表的数组。',
    objective: '能写出简单的 CSV 解析器，并处理首行标题。',
    level: 'intermediate',
    concepts: ['CSV', '切分', '表结构'],
    explain:
        '简单 CSV 可以直接按逗号 split。'
        '第一行当标题时，后续行按下标对应字段名，就能得到记录表。'
        '真实 CSV 还有引号转义、字段内换行等规则，这里只处理最基础的形式。',
    code: r'''local function split(text, sep)
  local parts = {}
  for piece in (text .. sep):gmatch("(.-)" .. sep) do
    parts[#parts + 1] = piece
  end
  return parts
end

local csv = "name,score\n小明,95\n小红,88\n"

local lines = {}
for line in csv:gmatch("[^\n]+") do lines[#lines + 1] = line end
print(#lines)

local header = split(lines[1], ",")
print(header[1], header[2])

local rows = {}
for i = 2, #lines do
  local cells = split(lines[i], ",")
  rows[#rows + 1] = { name = cells[1], score = tonumber(cells[2]) }
end

print(#rows)
print(rows[1].name, rows[1].score)
print(rows[2].name, rows[2].score + 1)

local total = 0
for _, row in ipairs(rows) do total = total + row.score end
print(total)
''',
    output: '3\nname\tscore\n2\n小明\t95\n小红\t89\n183\n',
    exercises: [
      LuaExercise(
        prompt: '求所有学生的平均分。',
        hint: '总和除以人数。',
        answer: 'print(total / #rows)',
      ),
      LuaExercise(
        prompt: '为什么 split 要先把分隔符拼到末尾？',
        hint: '想想最后一段。',
        answer: '因为模式要求匹配到分隔符才捕获，末尾补一个分隔符才能捕获最后一段。',
      ),
    ],
    pitfalls: ['简单切分无法处理带引号的字段。', '字段里有逗号时会切错。'],
  ),
  LuaTopic(
    id: 'lua-io-exit',
    chapter: 'osio',
    title: 'os.exit 与程序退出码',
    summary: '区分标准 Lua 的进程退出与本应用的脚本退出状态。',
    objective: '能说明 exit 与 return 的区别，并用退出码表达成功失败。',
    level: 'intermediate',
    concepts: ['os.exit', '退出码', '终止'],
    explain:
        '标准 Lua 的 os.exit() 调用 C exit 终止进程；第二个参数为 true 时先关闭 Lua 状态。'
        '本应用为保护 IDE，替换了 os.exit：记录退出码并用内部错误结束脚本，宿主在运行结束后返回该状态。'
        '本应用中 exit(true) 表示 0（成功），exit(false) 表示 1（失败），也可直接传数字。'
        '不要依赖捕获内部退出错误后继续运行，这是嵌入式宿主行为，不是标准 Lua 退出协议。'
        '在库里不要随意调用 exit，应把错误返回给调用方。',
    code: r'''local function run(mode)
  if mode == "ok" then return 0 end
  if mode == "bad" then return 1 end
  return 2
end

print(run("ok"), run("bad"), run("other"))

local ok, err = pcall(function() return "继续执行" end)
print(ok, err)

print(type(os.exit))
print(os.exit ~= nil)

local function classify(code)
  if code == 0 then return "成功" end
  if code == 1 then return "用法错误" end
  return "未知错误"
end

print(classify(run("ok")), classify(run("bad")), classify(run("other")))
os.exit(0)
''',
    output: '0\t1\t2\ntrue\t继续执行\nfunction\ntrue\n成功\t用法错误\t未知错误\n',
    exercises: [
      LuaExercise(
        prompt: '为什么脚本里不要用 exit 代替 return？',
        hint: '想想可测试性。',
        answer:
            '标准 Lua 中它终止进程，本应用中它请求结束整次脚本；return 只离开当前函数，所以库函数应用返回值或错误把决定交给调用方。',
      ),
      LuaExercise(
        prompt: 'exit(true) 的退出码是多少？',
        hint: '布尔值的约定。',
        answer: '0，表示成功；exit(false) 是 1。',
      ),
    ],
    pitfalls: [
      '标准 Lua 的 exit 不像普通 return 那样离开词法作用域；不能用它代替明确的资源管理。',
      '宿主可能改写 os.exit；本应用以退出请求记录最终状态，不会关闭整个 IDE 进程。',
    ],
  ),
  LuaTopic(
    id: 'lua-io-buffered-write',
    chapter: 'osio',
    title: '写入缓冲与 flush',
    summary: '写入可能先进入缓冲，flush 把用户态缓冲交给底层文件。',
    objective: '能说明缓冲带来的可见性延迟，并正确使用 flush。',
    level: 'advanced',
    concepts: ['缓冲', 'flush', '文件可见性'],
    explain:
        'write 通常先写进用户态缓冲，缓冲满了或 close 时才真正写文件。'
        '因此另一个进程可能在 close 之前读不到新内容。'
        '需要立即可见时调用 f:flush()。'
        'flush 不等于 fsync，不能保证断电后仍保存；文件用完仍需 close 释放资源。',
    code: r'''local path = "buffered.txt"
local writer = assert(io.open(path, "w"))

writer:write("第一段")
writer:flush()

local reader = assert(io.open(path, "r"))
print(reader:read("a"))
reader:close()

writer:write("第二段")
writer:close()

local again = assert(io.open(path, "r"))
print(again:read("a"))
again:close()

print(type(writer.flush))
os.remove(path)
''',
    output: '第一段\n第一段第二段\nfunction\n',
    exercises: [
      LuaExercise(
        prompt: '为什么写完立刻读可能读不到内容？',
        hint: '想想缓冲。',
        answer: '因为数据还在用户态缓冲里没写到文件，必须先 flush 或 close。',
      ),
      LuaExercise(
        prompt: 'close 之后还能继续写吗？',
        hint: '想想句柄状态。',
        answer: '不能，会报 attempt to use a closed file。',
      ),
    ],
    pitfalls: ['flush 之后新写的数据仍可能留在缓冲中；flush 不保证物理持久化。', '对已关闭的文件调用 flush 会报错。'],
  ),
];
