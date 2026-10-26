import 'lua_topic.dart';

/// 第十四章：模块、环境与加载。
const List<LuaTopic> topicsModules = [
  LuaTopic(
    id: 'lua-mod-require-table',
    chapter: 'modules',
    title: 'require 与模块返回值',
    summary: '模块就是一个返回表的文件，require 负责查找并缓存它。',
    objective: '能写一个模块文件并在入口文件里 require 使用。',
    level: 'intermediate',
    concepts: ['require', '模块', '返回值'],
    explain:
        '约定俗成的模块写法是：文件里声明 local M = {}，把函数挂上去，最后 return M。'
        'require("name") 会在 package.path 里查找 name.lua，执行它并取得返回值。'
        '本项目的运行时会自动把项目目录加入 package.path，'
        '所以同目录下的模块可以直接 require。',
    code: r'''local mathx = require("mathx")
print(mathx.double(21))
print(mathx.clamp(15, 0, 10))

local again = require("mathx")
print(again == mathx)
print(mathx.version)
''',
    output: '42\n10\ntrue\n1.0\n',
    fixtures: {
      'mathx.lua': '''
local M = { version = "1.0" }

function M.double(value)
  return value * 2
end

function M.clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

return M
''',
    },
    exercises: [
      LuaExercise(
        prompt: '再 require 一次同一个模块，会重新执行文件吗？',
        hint: '看两次拿到的表是否相同。',
        answer: '不会，require 会缓存结果，两次得到同一张表。',
      ),
      LuaExercise(
        prompt: '模块里为什么用 local M 而不是全局表？',
        hint: '想想命名污染。',
        answer: '局部表只在模块内部可见，通过 return 暴露，不会往全局表塞名字。',
      ),
    ],
    pitfalls: [
      '模块文件忘写 return 会让 require 返回 true 而不是表。',
      '模块名和文件名必须一致，路径由 package.path 决定。',
    ],
  ),
  LuaTopic(
    id: 'lua-mod-package-path',
    chapter: 'modules',
    title: 'package.path 与查找规则',
    summary: 'require 按 package.path 里的模板依次尝试，找到即用。',
    objective: '能读懂 package.path 的模板形式，并知道子目录模块怎么找。',
    level: 'advanced',
    concepts: ['package.path', '查找规则', '?'],
    explain:
        'package.path 是一串用分号分隔的模板，其中 ? 会被替换成模块名。'
        '例如 "./?.lua" 会让 require("a.b") 查找 "./a/b.lua"。'
        '本项目的运行时会把项目根、根/?.lua、根/src/?.lua 等加入路径，'
        '所以模块既可以放根目录也可以放 src。',
    code: r'''print(type(package.path))
print(package.path:find("%?%.lua") ~= nil)

local util = require("lib.util")
print(util.slug("Hello World"))

print(package.loaded["lib.util"] == util)

local ok, err = pcall(require, "not_exists_module")
print(ok)
print(type(err))
''',
    output: 'string\ntrue\nhello-world\ntrue\nfalse\nstring\n',
    fixtures: {
      'lib/util.lua': '''
local M = {}

function M.slug(text)
  return (text:lower():gsub("%s+", "-"))
end

return M
''',
    },
    exercises: [
      LuaExercise(
        prompt: 'require("lib.util") 会去哪个文件找？',
        hint: '看 ? 的替换规则。',
        answer: '会先尝试项目根下的 lib/util.lua（按 package.path 的模板顺序）。',
      ),
      LuaExercise(
        prompt: 'require 失败时抛出的是什么？',
        hint: '看 type(err)。',
        answer: '一个包含尝试过的路径列表的错误字符串。',
      ),
    ],
    pitfalls: [
      '模块名里的点会被替换成目录分隔符。',
      'Windows 上路径分隔符不同，但 package.path 用 / 也能工作。',
    ],
  ),
  LuaTopic(
    id: 'lua-mod-preload',
    chapter: 'modules',
    title: 'package.preload 内联模块',
    summary: '把模块函数直接注册进 package.preload，不需要真实文件。',
    objective: '能用 preload 注册内联模块，并理解它与 require 的关系。',
    level: 'advanced',
    concepts: ['package.preload', '内联模块', 'require'],
    explain:
        'require 会先查 package.loaded 缓存，再查 package.preload 里的加载器，'
        '最后才去文件系统找。'
        '把函数注册进 package.preload 就能提供「没有文件的模块」，'
        '适合测试替身或把模块内嵌在使用方里。',
    code: r'''package.preload["virtual"] = function(name)
  return { name = name, greet = function() return "hi from " .. name end }
end

local virtual = require("virtual")
print(virtual.name)
print(virtual.greet())

package.preload["counter_module"] = function()
  local n = 0
  return { next = function() n = n + 1; return n end }
end

local a = require("counter_module")
local b = require("counter_module")
print(a.next(), b.next(), a == b)
print(package.loaded["virtual"] ~= nil)
''',
    output: 'virtual\nhi from virtual\n1\t2\ttrue\ntrue\n',
    exercises: [
      LuaExercise(
        prompt: '注册一个返回固定值的模块 "config"。',
        hint: '在 preload 里 return 表。',
        answer:
            'package.preload["config"] = function() return { debug = false } end',
      ),
      LuaExercise(
        prompt: 'preload 和 loaded 的区别是什么？',
        hint: '一个是加载器，一个是结果。',
        answer: 'preload 存加载函数，loaded 存已经加载好的模块值。',
      ),
    ],
    pitfalls: [
      'preload 的函数只会在第一次 require 时调用。',
      '已缓存在 package.loaded 时修改 preload 不生效。',
    ],
  ),
  LuaTopic(
    id: 'lua-mod-env',
    chapter: 'modules',
    title: '_ENV 与受限环境',
    summary: '每个函数都有一个 _ENV 上值，改变它就能改变全局查找的目标。',
    objective: '能构造受限环境运行代码，只暴露允许的函数。',
    level: 'advanced',
    concepts: ['_ENV', '沙箱', '全局查找'],
    explain:
        'Lua 5.2 起，全局变量访问实际上是访问 _ENV 这张表。'
        '把一段代码的 _ENV 设成自定义表，它就看不到真实全局表。'
        '这是实现沙箱、配置 DSL、模板求值的标准做法。',
    code: r'''local sandbox = { print = print, result = 0 }

local chunk = load("result = 6 * 7", "sandbox", "t", sandbox)
print(type(chunk))
print(chunk())
print(sandbox.result)
print(_G.result == nil)

local blocked = load("return os.time()", "blocked", "t", {})
print(pcall(blocked) == false)

local allowed = load("return math.floor(3.9)", "allowed", "t", { math = math })
print(allowed())
''',
    output: 'function\n\n42\ntrue\ntrue\n3\n',
    exercises: [
      LuaExercise(
        prompt: '在沙箱里暴露 string.upper 并调用它。',
        hint: '环境表里放 string。',
        answer:
            'local env = { string = string }\nprint(load("return string.upper(\'a\')", "s", "t", env)())',
      ),
      LuaExercise(
        prompt: '为什么沙箱里访问 os 会失败？',
        hint: '环境里没有 os。',
        answer: '因为全局查找走的是 _ENV，沙箱表里没有 os，于是得到 nil 并调用失败。',
      ),
    ],
    pitfalls: ['沙箱必须同时限制 load 和 dofile，否则能被逃逸。', '给沙箱传真实全局表等于没有沙箱。'],
  ),
  LuaTopic(
    id: 'lua-mod-load-string',
    chapter: 'modules',
    title: 'load 动态编译字符串',
    summary: 'load 把字符串编译成函数，返回函数或 (nil, 错误)。',
    objective: '能用 load 编译运行时拼出的代码，并正确处理语法错误。',
    level: 'advanced',
    concepts: ['load', '动态代码', '语法错误'],
    explain:
        'load(source, chunkname, mode, env) 编译源码并返回函数，'
        '编译失败时返回 nil 和错误消息，而不是抛错。'
        '这是「用户输入公式」类需求的基础，'
        '但要注意：执行任意代码等于给出完整权限，必须有明确边界。',
    code: r'''local f = load("return 1 + 2")
print(f())

local g = load("return ...", "vararg")
print(g(7, 8))

local bad, err = load("return 1 +")
print(bad == nil)
print(type(err))

local h = load("local x = 10 return x * 2")
print(h())

local counter = load("return counter_value", "counter", "t", { counter_value = 99 })
print(counter())
''',
    output: '3\n7\t8\ntrue\nstring\n20\n99\n',
    exercises: [
      LuaExercise(
        prompt: '让用户输入 "2*3" 并求出结果。',
        hint: 'load("return ...")。',
        answer: 'local f = assert(load("return " .. "2*3"))\nprint(f())',
      ),
      LuaExercise(
        prompt: 'load 返回 nil 时第一个错误是什么类型？',
        hint: '看 type(err)。',
        answer: '字符串，内容包含错误位置和原因。',
      ),
    ],
    pitfalls: ['直接 load 用户输入等于执行任意代码，必须限定环境。', 'load 不会自动执行，需要再调用返回的函数。'],
  ),
  LuaTopic(
    id: 'lua-mod-global-min',
    chapter: 'modules',
    title: '减少全局变量',
    summary: '判断哪些名字是全局的，把模块状态收进局部作用域。',
    objective: '能识别全局泄漏，并用局部表替代全局变量。',
    level: 'intermediate',
    concepts: ['全局变量', '_G', '局部化'],
    explain:
        '全局变量是共享的隐式状态：任何模块都能改，'
        '拼错名字只会静默新建而不是报错。'
        '把状态放进模块返回的表里，或写成工厂函数的闭包，'
        '就能让「谁能改」这件事变得明确。',
    code: r'''config_value = 1
print(_G.config_value)

local function leaky()
  counter = 10
end
leaky()
print(_G.counter)

local function clean()
  local state = { counter = 10 }
  return state
end
print(clean().counter, _G.state == nil)

local M = {}
function M.set(value) M.value = value end
M.set(5)
print(M.value)

local before = 0
for name in pairs(_G) do before = before + 1 end
print(type(before))
''',
    output: '1\n10\n10\ttrue\n5\nnumber\n',
    exercises: [
      LuaExercise(
        prompt: '列出 _G 里所有函数类型名字的数量。',
        hint: '遍历 pairs(_G) 判类型。',
        answer:
            'local n = 0\nfor _, v in pairs(_G) do if type(v) == "function" then n = n + 1 end end',
      ),
      LuaExercise(
        prompt: '为什么全局变量拼错很危险？',
        hint: '想想读取 nil 之后的操作。',
        answer: '拼错读会得到 nil 而不是报错，拼错写会新建全局变量，问题会延迟暴露。',
      ),
    ],
    pitfalls: ['遍历 _G 时不要在循环里新增全局变量。'],
  ),
  LuaTopic(
    id: 'lua-mod-dofile',
    chapter: 'modules',
    title: 'dofile 与 loadfile',
    summary: 'dofile 执行文件并返回其返回值，loadfile 只编译不执行。',
    objective: '能区分 require、dofile、loadfile 的职责。',
    level: 'intermediate',
    concepts: ['dofile', 'loadfile', '执行方式'],
    explain:
        'loadfile 编译文件返回函数（失败返回 nil + 错误）；'
        'dofile 相当于 loadfile 立刻调用，并返回脚本的返回值。'
        'require 额外带缓存和搜索路径。'
        '需要「每次执行都重新跑一遍」时用 dofile，需要缓存时用 require。',
    code: r'''print(type(loadfile("script.lua")))

local chunk = loadfile("script.lua")
local first = chunk()
print(first)

print(dofile("script.lua"))

local missing, err = loadfile("no_such_file.lua")
print(missing == nil)
print(type(err))

print(_G.script_ran)
''',
    output: 'function\n第一次运行\n第一次运行\ntrue\nstring\n2\n',
    fixtures: {
      'script.lua': '''
_G.script_ran = (_G.script_ran or 0) + 1
return "第一次运行"
''',
    },
    exercises: [
      LuaExercise(
        prompt: '为什么 dofile 每次都会重新执行文件？',
        hint: '它没有缓存。',
        answer: '因为 dofile 不查 package.loaded，每次都重新编译执行。',
      ),
      LuaExercise(
        prompt: 'loadfile 和 load 的区别？',
        hint: '一个读文件一个读字符串。',
        answer: 'loadfile 从文件读源码，load 从字符串读；两者都返回编译后的函数。',
      ),
    ],
    pitfalls: ['dofile 会阻断式执行文件里的所有代码，出错会直接抛给调用方。', 'dofile 的文件路径受项目目录包装影响。'],
  ),
  LuaTopic(
    id: 'lua-mod-cache',
    chapter: 'modules',
    title: 'require 的缓存语义',
    summary: 'require 把结果放进 package.loaded，重复调用直接命中缓存。',
    objective: '能利用或清除缓存来解决模块热更新与测试隔离。',
    level: 'advanced',
    concepts: ['package.loaded', '缓存', '热更新'],
    explain:
        'require 第一次加载后把返回值存进 package.loaded[name]。'
        '之后再次 require 直接返回缓存，不会重新执行文件。'
        '把该键设为 nil 可以强制重新加载，'
        '这在测试里重置模块状态、或实现开发期热更新时很有用。',
    code: r'''local first = require("stateful")
print(first.value)
first.increment()
print(first.value)

local second = require("stateful")
print(second == first, second.value)

package.loaded["stateful"] = nil
local third = require("stateful")
print(third == first, third.value)
''',
    output: '0\n1\ntrue\t1\nfalse\t0\n',
    fixtures: {
      'stateful.lua': '''
local M = { value = 0 }
function M.increment() M.value = M.value + 1 end
return M
''',
    },
    exercises: [
      LuaExercise(
        prompt: '在测试里如何保证每个用例拿到干净模块？',
        hint: '清除 package.loaded。',
        answer: 'package.loaded["模块名"] = nil 后再 require。',
      ),
      LuaExercise(
        prompt: '为什么缓存能提升性能？',
        hint: '想想重复编译的开销。',
        answer: '避免重复读文件、编译和执行，只做一次哈希查找。',
      ),
    ],
    pitfalls: ['清缓存不会清理模块创建的全局状态。', '其他模块仍持有旧表的引用，热更新可能造成新旧版本共存。'],
  ),
  LuaTopic(
    id: 'lua-mod-init',
    chapter: 'modules',
    title: '子目录模块与 init.lua',
    summary: 'require("pkg") 会先试 pkg.lua，再试 pkg/init.lua。',
    objective: '能用目录式的包结构组织多个相关模块。',
    level: 'intermediate',
    concepts: ['init.lua', '包结构', '模块组织'],
    explain:
        '当模块是一个包（多个文件）时，常写成 pkg/init.lua 作为入口，'
        '内部再用 require("pkg.a") 引用同级文件。'
        'package.path 里通常包含 ?/init.lua 模板，'
        '所以 require("pkg") 能找到 pkg/init.lua。',
    code: r'''local pkg = require("pkg")
print(pkg.name)
print(pkg.sum(1, 2, 3))

local util = require("pkg.util")
print(util.shout("ok"))
print(package.loaded["pkg"] ~= nil, package.loaded["pkg.util"] ~= nil)
''',
    output: 'pkg\n6\nOK\ntrue\ttrue\n',
    fixtures: {
      'pkg/init.lua': '''
local util = require("pkg.util")
local M = { name = "pkg" }

function M.sum(...)
  local total = 0
  for _, value in ipairs({ ... }) do total = total + value end
  return total
end

return M
''',
      'pkg/util.lua': '''
local M = {}
function M.shout(text) return text:upper() end
return M
''',
    },
    exercises: [
      LuaExercise(
        prompt: '给 pkg 增加一个 average 函数。',
        hint: '在 init.lua 里用 sum 和参数个数。',
        answer:
            'function M.average(...) local n = select("#", ...); return M.sum(...) / n end',
      ),
      LuaExercise(
        prompt: '为什么 require("pkg.util") 里用点而不是斜杠？',
        hint: '模块名规则。',
        answer:
            'Lua 文件搜索器会把模块名中的点替换成平台目录分隔符。斜杠可能在部分路径上可用，但不是可移植包名写法，还可能形成不同的缓存键。',
      ),
    ],
    pitfalls: [
      '循环 require 若没有提前注册导出表，可能递归加载直到报错；Lua 不会自动提供部分初始化的模块。',
      'init.lua 里 require 相对模块时要用完整包名。',
    ],
  ),
];
