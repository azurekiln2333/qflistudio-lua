import 'lua_topic.dart';

/// 第三章：数字与运算符。
const List<LuaTopic> topicsNumbers = [
  LuaTopic(
    id: 'lua-num-integer-div',
    chapter: 'numbers',
    title: '整除 //：向负无穷取整',
    summary: '// 是向下取整的除法，和截断取整的语言不一样。',
    objective: '能预测 // 在正数、负数、浮点上的结果。',
    level: 'beginner',
    concepts: ['整除', '//', '向下取整'],
    explain:
        '// 表示向下取整的除法（floor division），结果朝负无穷方向取整。'
        '两个整数相除得到整数，只要有一边是浮点，结果就是浮点。'
        '这是 Lua 5.3 之后和整数除法语义最容易被忽略的细节：-7 // 2 是 -4，不是 -3。',
    code: r'''print(7 // 2)
print(7.5 // 2)
print(-7 // 2)
print(7 // 2.0)
print(math.type(7 // 2), math.type(7 // 2.0))
print(math.floor(7 / 2), 7 / 2)
''',
    output: '3\n3.0\n-4\n3.0\ninteger\tfloat\n3\t3.5\n',
    exercises: [
      LuaExercise(
        prompt: '计算 -1 // 4 并解释符号。',
        hint: '向下取整意味着往更小的方向走。',
        answer: '-1，因为 -0.25 向下取整是 -1。',
      ),
      LuaExercise(
        prompt: '整数 7 // 0 会怎样？',
        hint: '整数除零不是 inf。',
        answer: '直接报错 attempt to perform \'n//0\'，只有浮点除零才会得到 inf。',
      ),
    ],
    pitfalls: [
      '整数除零报错，浮点除零才得到 inf。',
      '输岀 inf/nan 的文本形式随 C 运行时而变，教学示例不要把它们当作可比对的预期值。',
      '用整除做索引前要确认它不会把 0 变成 -1 之类的问题。',
    ],
  ),
  LuaTopic(
    id: 'lua-num-modulo',
    chapter: 'numbers',
    title: '% 取模：结果的符号跟着除数',
    summary: 'Lua 的取模结果与除数同号，和 // 配合满足 a == (a//b)*b + a%b。',
    objective: '能算出负数取模的结果，并用它做环形索引。',
    level: 'beginner',
    concepts: ['取模', '%', '负数'],
    explain:
        'Lua 的 a % b 定义为 a - (a // b) * b，所以结果符号跟 b 一致。'
        'n 为正整数时，整数对 n 取模会落到 0..n-1，适合做环形下标。'
        '注意浮点也能取模，7.5 % 2 得 1.5。',
    code: r'''print(7 % 3)
print(-7 % 3)
print(7 % -3)
print(7.5 % 2)
print(-6 % 3)
print(10 % 5 == 0 and "整除" or "有余数")
''',
    output: '1\n2\n-2\n1.5\n0\n整除\n',
    exercises: [
      LuaExercise(
        prompt: '把 5 个元素做成环形下标，从 -1 开始取值。',
        hint: '用 (-1) % 5。',
        answer: 'local index = (-1) % 5 + 1  -- 得到 5，指向最后一个元素',
      ),
      LuaExercise(
        prompt: '验证 a % b 与 a // b 的关系。',
        hint: '代入 7 和 3。',
        answer: '7 == (7 // 3) * 3 + 7 % 3，即 7 == 2*3 + 1。',
      ),
    ],
    pitfalls: ['和 C 不同，-7 % 3 在 Lua 是 2 而不是 -1。', '浮点取模有精度误差，比较结果时要用容差。'],
  ),
  LuaTopic(
    id: 'lua-num-power',
    chapter: 'numbers',
    title: '^ 幂运算与浮点结果',
    summary: '^ 总是返回浮点，开方可以用 ^ 0.5 表达。',
    objective: '知道 ^ 的结果类型，并能用 math.sqrt 表达开方意图。',
    level: 'beginner',
    concepts: ['幂', '^', '浮点'],
    explain:
        'Lua 没有 ** 运算符，幂写作 ^。它总是产生浮点数，即使指数是非负整数。'
        '开方可以写 x ^ 0.5，但读代码的人更希望看到 math.sqrt。'
        '负指数得到倒数，2 ^ -1 是 0.5。',
    code: r'''print(2 ^ 10)
print(2 ^ 0.5)
print(9 ^ 0.5)
print(math.sqrt(9))
print(2 ^ -1)
print(math.type(2 ^ 2))
''',
    output: '1024.0\n1.4142135623731\n3.0\n3.0\n0.5\nfloat\n',
    exercises: [
      LuaExercise(
        prompt: '用 ^ 计算 3 的 4 次方，并把结果转成整数。',
        hint: '结果 81.0，用 math.tointeger 或 //1。',
        answer: 'print(math.tointeger(3 ^ 4))  -- 81',
      ),
      LuaExercise(
        prompt: '为什么 2 ^ 10 打印成 1024.0？',
        hint: '看 math.type。',
        answer: '因为 ^ 总是返回浮点，即使数值是整数；需要整数请用 math.tointeger。',
      ),
    ],
    pitfalls: ['^ 是幂，不是异或；位异或要写 ~。'],
  ),
  LuaTopic(
    id: 'lua-num-integer-float',
    chapter: 'numbers',
    title: '整数与浮点是两种子类型',
    summary: 'Lua 5.4 有 64 位整数和双精度浮点，math.type 能区分。',
    objective: '能判断一个 number 是整数还是浮点，并知道运算如何决定结果类型。',
    level: 'intermediate',
    concepts: ['integer', 'float', 'math.type'],
    explain:
        'Lua 5.4 的 number 有两种子类型：64 位有符号整数和 IEEE 双精度浮点。'
        '字面量 1 是整数，1.0 或 1e0 是浮点；/ 总是浮点，// 在两边都是整数时是整数。'
        '混合运算会把整数转成浮点。整数和浮点在数值相等时比较相等，但 math.type 不同。',
    code: r'''print(math.type(1), math.type(1.0), math.type(1e0))
print(1 == 1.0)
print(math.type(1 + 1.0))
print(math.type(6 // 3), math.type(6 / 3))
print(3 / 1)
print(math.type(3 // 1.0))
''',
    output: 'integer\tfloat\tfloat\ntrue\nfloat\ninteger\tfloat\n3.0\nfloat\n',
    exercises: [
      LuaExercise(
        prompt: '怎么把一个浮点值变回整数？',
        hint: '值必须是整数值的浮点。',
        answer: 'math.tointeger(3.0) 得到 3；如果不是整数值会返回 nil。',
      ),
      LuaExercise(
        prompt: 't[1] 和 t[1.0] 访问的是同一个字段吗？',
        hint: '浮点整数键会被规范化。',
        answer: '是同一个字段，Lua 会把整数值的浮点键转成整数键。',
      ),
    ],
    pitfalls: ['string.format("%d", 3.0) 会报错，需要先转整数。', '大整数超出 2^53 后转浮点会丢精度。'],
  ),
  LuaTopic(
    id: 'lua-num-overflow',
    chapter: 'numbers',
    title: '整数上溢与回绕',
    summary: '整数溢出不会报错，而是环绕到另一端。',
    objective: '知道 math.maxinteger 的边界，并能在边界处做保护。',
    level: 'intermediate',
    concepts: ['maxinteger', '上溢', '回绕'],
    explain:
        '整数是 64 位有符号数，范围是 math.mininteger 到 math.maxinteger。'
        '超过最大值再加一会回绕到最小值，不会抛错也不会变成浮点。'
        '如果要避免回绕，可以在运算前判断边界，或者改用浮点接收。',
    code: r'''print(math.maxinteger)
print(math.mininteger)
print(math.maxinteger + 1)
print(math.mininteger - 1)

local function safeAdd(a, b)
  if b > 0 and a > math.maxinteger - b then
    return nil, "整数上溢"
  end
  return a + b
end

print(safeAdd(math.maxinteger, 1))
print(safeAdd(1, 2))
''',
    output:
        '9223372036854775807\n-9223372036854775808\n'
        '-9223372036854775808\n9223372036854775807\nnil\t整数上溢\n3\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 print(2^63) 和 print(math.maxinteger + 1) 不一样？',
        hint: '一个是浮点，一个是整数。',
        answer: '2^63 是浮点 9.2233720368548e+18，而整数回绕得到负数。',
      ),
      LuaExercise(
        prompt: '写一个检测下溢的判断。',
        hint: 'b < 0 时看 a 是否接近最小值。',
        answer:
            'if b < 0 and a < math.mininteger - b then return nil, "整数下溢" end',
      ),
    ],
    pitfalls: ['溢出静默发生，测试用例要覆盖边界值。', '整数和浮点混算会先转浮点，可能丢失精度。'],
  ),
  LuaTopic(
    id: 'lua-num-bitwise',
    chapter: 'numbers',
    title: '位运算：& | ~ << >>',
    summary: '位运算只接受整数，异或写成 ~，取负位运算用 ~x。',
    objective: '能用位掩码做标志位组合与判断。',
    level: 'intermediate',
    concepts: ['位运算', '掩码', '异或'],
    explain:
        'Lua 5.4 用符号表示位运算：& 与、| 或、~ 异或、<< 左移、>> 右移，单目 ~ 是按位取反。'
        '所有位运算都要求整数操作数（整数值的浮点会被接受并转换成整数）。'
        '实践中常用「1 << n」表示第 n 个标志位，再用 & 判断、用 | 组合。',
    code: r'''print(0xF0 & 0x0F, 0xF0 | 0x0F, 0xF0 ~ 0xFF)
print(1 << 4, 256 >> 4)
print(~0)

local READ, WRITE, EXEC = 1 << 0, 1 << 1, 1 << 2
local mode = READ | EXEC
print(mode, mode & READ ~= 0, mode & WRITE ~= 0)

print(2 ^ 3)
''',
    output: '0\t255\t15\n16\t16\n-1\n5\ttrue\tfalse\n8.0\n',
    exercises: [
      LuaExercise(
        prompt: '给 mode 加上写权限并判断是否有写权限。',
        hint: '用 | 组合，用 & 判断。',
        answer: 'mode = mode | WRITE\nprint(mode & WRITE ~= 0)  -- true',
      ),
      LuaExercise(
        prompt: '2 ^ 3 和 2 ~ 3 的区别是什么？',
        hint: '一个求幂，一个异或。',
        answer: '2 ^ 3 是 8.0（浮点幂），2 ~ 3 是 1（位异或）。',
      ),
    ],
    pitfalls: [
      '位运算不能用浮点小数值，会报 number has no integer representation。',
      '~ 既可作二元异或又可作一元取反，看上下文。',
    ],
  ),
  LuaTopic(
    id: 'lua-num-radix',
    chapter: 'numbers',
    title: '十六进制与科学计数法',
    summary: '0x 前缀写十六进制，e 表示十进制指数，p 表示二进制指数。',
    objective: '能读写十六进制、科学计数法和十六进制浮点字面量。',
    level: 'beginner',
    concepts: ['十六进制', '科学计数法', '字面量'],
    explain:
        '0x 开头的字面量是十六进制，大小写皆可。'
        '科学计数法用 e：1e3 是 1000.0，1.5e-3 是 0.0015。'
        '十六进制浮点用 p 表示 2 的幂：0x1p4 是 1 * 2^4 = 16.0。'
        '注意带小数点或指数的都是浮点。',
    code: r'''print(0x10, 0xff, 0xDEAD)
print(1e3, 1.5e-3, 2E2)
print(0x1p4)
print(tonumber("0x1A"))
print(math.type(0x10), math.type(0x1p4))
''',
    output: '16\t255\t57005\n1000.0\t0.0015\t200.0\n16.0\n26\ninteger\tfloat\n',
    exercises: [
      LuaExercise(
        prompt: '用十六进制字面量表示 255，再转成二进制字符串提示。',
        hint: '0xff。',
        answer: 'print(0xff == 255)  -- true',
      ),
      LuaExercise(
        prompt: '0x10 和 0x1p4 都是 16，为什么一个是整数一个是浮点？',
        hint: '看有没有 p 指数。',
        answer: 'p 指数让字面量变成浮点，所以 0x1p4 是 16.0。',
      ),
    ],
    pitfalls: ['0x 后面写错字符会在加载时报物化失败。'],
  ),
  LuaTopic(
    id: 'lua-num-equality',
    chapter: 'numbers',
    title: '数字比较与浮点误差',
    summary: '整数和浮点可以相等比较，但浮点运算有精度误差。',
    objective: '知道 0.1+0.2 ~= 0.3 的原因，并会用容差比较浮点。',
    level: 'intermediate',
    concepts: ['相等比较', '浮点误差', '容差'],
    explain:
        '整数和整数值的浮点比较相等，1 == 1.0 是 true。'
        '但浮点是二进制小数，0.1 和 0.2 都无法精确表示，相加后和 0.3 差一个极小值。'
        '比较浮点结果要写容差：math.abs(a - b) < 1e-12，而不是 ==。',
    code: r'''print(1 == 1.0, 1 < 1.5, 2 >= 2)
print("10" == 10)
print(0.1 + 0.2 == 0.3)
print(math.abs((0.1 + 0.2) - 0.3) < 1e-12)
print(3 ~= 4)

local function nearlyEqual(a, b, epsilon)
  return math.abs(a - b) <= (epsilon or 1e-12)
end
print(nearlyEqual(0.1 + 0.2, 0.3))
''',
    output:
        'true\ttrue\ttrue\nfalse\nfalse\ntrue\ntrue\n'
        'true\n',
    exercises: [
      LuaExercise(
        prompt: '把容差改成 1e-20，结果会怎样？',
        hint: '误差大约是 5.5e-17。',
        answer: '会返回 false，因为误差大于 1e-20。',
      ),
      LuaExercise(
        prompt: '为什么 "10" == 10 是 false？',
        hint: '== 不做类型转换。',
        answer: '字符串和数字是不同类型，相等比较不转换类型，所以为 false。',
      ),
    ],
    pitfalls: [
      '需要近似相等时按误差使用容差；可精确表示的值或需要精确相等的条件仍可使用 ==。',
      '容差不要写死成 1e-6 这种过宽的值，要按量级选。',
    ],
  ),
  LuaTopic(
    id: 'lua-num-conversion',
    chapter: 'numbers',
    title: '进制解析与数值转换',
    summary: 'tonumber 支持 2~36 进制，math.tointeger 只接受整数值。',
    objective: '能解析任意进制文本，并在浮点与整数之间安全转换。',
    level: 'intermediate',
    concepts: ['tonumber', 'math.tointeger', '进制'],
    explain:
        'tonumber(text, base) 把文本按指定进制解析，base 可以是 2 到 36。'
        '不带 base 时会自动识别 0x 前缀和十进制小数。'
        'math.tointeger 只把「值为整数」的浮点或可转整数转换成整数，否则返回 nil，'
        '所以它是安全的降级边界。',
    code: r'''print(tonumber("z", 36))
print(tonumber("101", 2))
print(tonumber("77", 8))
print(math.tointeger(42.0))
print(math.tointeger(42.9))
print(tonumber("42abc"))
print(tonumber("42 ") + 1)
''',
    output: '35\n5\n63\n42\nnil\nnil\n43\n',
    exercises: [
      LuaExercise(
        prompt: '把二进制字符串 "1100" 转成十进制。',
        hint: '用 tonumber(s, 2)。',
        answer: 'print(tonumber("1100", 2))  -- 12',
      ),
      LuaExercise(
        prompt: '"42abc" 为什么解析失败？',
        hint: 'tonumber 要求整段文本合法。',
        answer: 'tonumber 不接受尾随多余字符，整段都必须是合法数字（允许前后空白）。',
      ),
    ],
    pitfalls: [
      'tonumber 会忽略数字后面的空白，但不会忽略字母。',
      'math.tointeger 对 42.9 返回 nil，不会四舍五入。',
    ],
  ),
  LuaTopic(
    id: 'lua-num-precedence',
    chapter: 'numbers',
    title: '运算符优先级与结合性',
    summary: '幂优先于取负且右结合，拼接低于算术。',
    objective: '能不靠括号预测复杂表达式的值，并用括号消除歧义。',
    level: 'intermediate',
    concepts: ['优先级', '结合性', '括号'],
    explain:
        'Lua 的优先级从高到低大致是：^（右结合）、单目 not/#/-/~、* / // %、+ -、.. （右结合）、'
        '比较、and、or。'
        '注意 -2 ^ 2 先算幂再取负，得到 -4.0；2 ^ 3 ^ 2 是 2 ^ (3 ^ 2) = 512。'
        '拼接 .. 的优先级低于算术，所以 1 + 2 .. "" 先算加法。',
    code: r'''print(2 + 3 * 4)
print((2 + 3) * 4)
print(-2 ^ 2)
print(2 ^ 3 ^ 2)
print(1 + 2 .. "")
print(not true == false)
print(2 + 3 .. 4 + 5)
''',
    output: '14\n20\n-4.0\n512.0\n3\ntrue\n59\n',
    exercises: [
      LuaExercise(
        prompt: '为什么 2 + 3 .. 4 + 5 得到 "59"？',
        hint: '两侧的加法先各自求值。',
        answer: '两个加法优先级高于 ..，所以先得 5 和 9，再拼成 "59"。',
      ),
      LuaExercise(
        prompt: '为什么 -2 ^ 2 输出 -4.0 而不是 -4？',
        hint: '^ 总是产生浮点。',
        answer: '因为 2 ^ 2 是浮点 4.0，取负后仍是浮点，所以打印成 -4.0。',
      ),
    ],
    pitfalls: ['not a == b 等价于 (not a) == b。', '.. 的优先级低，容易把数字拼成意外的字符串。'],
  ),
  LuaTopic(
    id: 'lua-num-floor-mod-table',
    chapter: 'numbers',
    title: '整除与取模的配合规律',
    summary: '一次遍历验证四种符号组合下 a == (a//b)*b + a%b 都成立。',
    objective: '能解释负数整除与取模的配对关系，并用它做安全的索引映射。',
    level: 'intermediate',
    concepts: ['整除', '取模', '恒等式'],
    explain:
        '无论正负，Lua 都保证 a == (a // b) * b + a % b，这是「向下取整除法」的定义。'
        '把四种符号组合跑一遍，规律就清楚了：整除总比截断除法小 1（当结果非整数且为负时），'
        '非零的有限取模结果与除数同号；整数除数为 0 时取模会报错。',
    code: r'''local function show(a, b)
  print(string.format("%d // %d = %d, %d %% %d = %d, 校验 %s",
    a, b, a // b, a, b, a % b,
    tostring(a == (a // b) * b + a % b)))
end

show(7, 3)
show(-7, 3)
show(7, -3)
show(-7, -3)
''',
    output:
        '7 // 3 = 2, 7 % 3 = 1, 校验 true\n'
        '-7 // 3 = -3, -7 % 3 = 2, 校验 true\n'
        '7 // -3 = -3, 7 % -3 = -2, 校验 true\n'
        '-7 // -3 = 2, -7 % -3 = -1, 校验 true\n',
    exercises: [
      LuaExercise(
        prompt: '用这条恒等式验证 a = 7, b = 3 时的整除结果。',
        hint: '代入公式。',
        answer: '(7 // 3) * 3 + 7 % 3 = 2 * 3 + 1 = 7，成立。',
      ),
      LuaExercise(
        prompt: '把 -7 % 3 的结果改成与 C 语言一致的 -1 需要怎么做？',
        hint: '用 math.fmod。',
        answer: 'math.fmod(-7, 3) 得到 -1.0，它是截断取模。',
      ),
    ],
    pitfalls: ['不要混用 math.fmod 与 %，两者对负数的定义不同。'],
  ),
];
