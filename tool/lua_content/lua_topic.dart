/// Authored Lua 5.4 topic model used by the generator, verifier and tests.
///
/// One [LuaTopic] produces exactly one tutorial chapter entry (with one lesson)
/// and one paired example entry, so a topic can never drift between the
/// tutorial and example catalogs.
library;

class LuaTopic {
  const LuaTopic({
    required this.id,
    required this.chapter,
    required this.title,
    required this.summary,
    required this.objective,
    required this.level,
    required this.concepts,
    required this.explain,
    required this.code,
    required this.output,
    required this.exercises,
    this.pitfalls = const [],
    this.prerequisites = const [],
    this.fixtures = const {},
  });

  /// Stable, explicit, human-readable id, e.g. `lua-strings-format`.
  final String id;

  /// Chapter key; [LuaChapters] owns the display titles and order.
  final String chapter;

  /// Lesson/topic title in Chinese.
  final String title;

  /// One-sentence summary shown in the list.
  final String summary;

  /// What the learner can do after this topic.
  final String objective;

  /// `beginner` / `intermediate` / `advanced`.
  final String level;

  /// Searchable concept tags.
  final List<String> concepts;

  /// Tutorial body: why it matters and how it works.
  final String explain;

  /// Runnable Lua source. Executed verbatim by the verifier.
  final String code;

  /// Independently authored expected stdout. Never regenerated from a run.
  final String output;

  final List<LuaExercise> exercises;
  final List<String> pitfalls;
  final List<String> prerequisites;

  /// Project files written before execution, e.g. `{'input.txt': '1 2'}`.
  final Map<String, String> fixtures;
}

class LuaExercise {
  const LuaExercise({
    required this.prompt,
    required this.hint,
    required this.answer,
  });

  final String prompt;
  final String hint;
  final String answer;
}

class LuaChapter {
  const LuaChapter(this.id, this.title, this.summary);

  final String id;
  final String title;

  /// One-sentence chapter summary used as the tutorial entry summary.
  final String summary;
}

/// Chapter order is the reading order of the shipped curriculum.
const List<LuaChapter> luaChapters = [
  LuaChapter('start', '第一章 第一个 Lua 程序', '从 print、注释和文件结构开始，跑通第一段 Lua。'),
  LuaChapter('values', '第二章 值、变量与作用域', '认清 nil/布尔/数字/字符串，掌握 local 的作用域边界。'),
  LuaChapter('numbers', '第三章 数字与运算符', '整数与浮点的差别、整除与取模、位运算与溢出。'),
  LuaChapter('strings', '第四章 字符串基础', '拼接、转义、长字符串、长度与字节，以及格式化输出。'),
  LuaChapter('patterns', '第五章 字符串模式匹配', '用 Lua 自己的模式语法做查找、捕获、替换与切分。'),
  LuaChapter('tables', '第六章 表的基础用法', '数组、字典、嵌套表、长度与安全遍历。'),
  LuaChapter(
    'tablelib',
    '第七章 表库与常用算法',
    'table.insert/remove/sort/concat/move/pack 的真实用法。',
  ),
  LuaChapter('meta', '第八章 元表与运算符重载', '用元表控制索引、调用、比较、长度与算术运算。'),
  LuaChapter('flow', '第九章 条件与分支', 'if/elseif 的求值顺序、真假判定与常见陷阱。'),
  LuaChapter('loops', '第十章 循环与迭代', '数值 for、泛型 for、while、repeat 与 break/goto。'),
  LuaChapter('functions', '第十一章 函数与参数', '多返回值、可变参数、命名参数与函数是一等值。'),
  LuaChapter('closures', '第十二章 闭包与高阶函数', '闭包捕获、柯里化、记忆化与回调组合。'),
  LuaChapter('errors', '第十三章 错误处理与断言', 'error/pcall/xpcall/assert 与失败路径的显式表达。'),
  LuaChapter(
    'modules',
    '第十四章 模块、环境与加载',
    'require、package.path、_ENV、load 与全局表隔离。',
  ),
  LuaChapter('math', '第十五章 math 库', '取整、取模、极值、整数边界与随机数。'),
  LuaChapter(
    'strlib',
    '第十六章 string 库',
    'find/match/gsub/gmatch/format/rep/pack 等常用函数。',
  ),
  LuaChapter('osio', '第十七章 os 与 io', '读写项目文件、按行处理输入、时间与路径。'),
  LuaChapter('utf8', '第十八章 utf8 库', '按码点处理中文，避免把字节当字符。'),
  LuaChapter('coroutines', '第十九章 协程', '用协程表达生成器、状态机与协作式调度。'),
  LuaChapter('oop', '第二十章 面向对象', '用表与元表实现类、继承、封装与多态。'),
  LuaChapter(
    'lua54',
    '第二十一章 Lua 5.4 新特性',
    'to-be-closed、const、整数除法与 5.4 的语法细节。',
  ),
  LuaChapter('debug', '第二十二章 调试与健壮性', 'traceback、xpcall、输入校验与可重复的失败诊断。'),
  LuaChapter('project', '第二十三章 综合小项目', '把前面学到的能力组合成可运行的小工具。'),
];
