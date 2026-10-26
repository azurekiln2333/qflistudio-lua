// R1 audit of the *pre-existing* shared Lua content.
//
// Reads the shared aggregate catalog shipped by qfli_studio_core, keeps only
// `type == "lua"` entries, and executes every lesson body and every example
// body through the bundled Lua 5.4.8 bridge. Expected output is never
// rewritten: the report records authored vs actual so the difference stays
// visible.
//
// Usage:
//   dart run tool/lua_content/audit_original_lua_content.dart [reportPath]
//
// Default report path is the task research directory so the evidence lands
// next to the plan instead of inside product source.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

const _defaultCoreContent = '../qfli_studio_core/assets/content';
const _defaultReport =
    '.trellis/tasks/10-22-offline-ide-completeness/research/original-lua-audit.md';

Future<void> main(List<String> arguments) async {
  final contentDirectory = arguments.isNotEmpty
      ? arguments[0]
      : _defaultCoreContent;
  final reportPath = arguments.length > 1 ? arguments[1] : _defaultReport;

  final tutorials = _loadEntries(
    p.join(contentDirectory, 'tutorials.json'),
  ).where(_isLua).toList(growable: false);
  final examples = _loadEntries(
    p.join(contentDirectory, 'examples.json'),
  ).where(_isLua).toList(growable: false);

  stdout.writeln(
    'lua tutorials=${tutorials.length} examples=${examples.length}',
  );

  final work = await Directory.systemTemp.createTemp('qfli_lua_audit_');
  final runs = <_AuditRun>[];
  try {
    for (final tutorial in tutorials) {
      for (final lesson in _lessons(tutorial)) {
        runs.add(
          await _execute(
            work,
            kind: 'lesson',
            id: '${tutorial['id']}/${lesson['id']}',
            title: _text(lesson['title']),
            code: _text(lesson['code']),
            expected: _text(lesson['output']),
            fixtures: _fixtures(lesson),
          ),
        );
      }
    }
    for (final example in examples) {
      runs.add(
        await _execute(
          work,
          kind: 'example',
          id: _text(example['id']),
          title: _text(example['title']),
          code: _text(example['code']),
          expected: _text(example['expectedOutput']),
          fixtures: _fixtures(example),
        ),
      );
    }
  } finally {
    await work.delete(recursive: true);
  }

  final report = _buildReport(
    tutorials: tutorials,
    examples: examples,
    runs: runs,
  );
  final file = File(reportPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(report);
  stdout.writeln('report=$reportPath');
  final mismatched = runs.where((run) => !run.matches).length;
  stdout.writeln(
    'runs=${runs.length} matched=${runs.length - mismatched} '
    'mismatched=$mismatched',
  );
}

bool _isLua(Map<String, Object?> entry) =>
    _text(entry['type']).toLowerCase() == 'lua' ||
    _text(entry['language']).toLowerCase() == 'lua';

List<Map<String, Object?>> _loadEntries(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) return const [];
  final entries = decoded['entries'];
  if (entries is! List) return const [];
  return [
    for (final entry in entries)
      if (entry is Map) entry.cast<String, Object?>(),
  ];
}

List<Map<String, Object?>> _lessons(Map<String, Object?> tutorial) {
  final lessons = tutorial['lessons'];
  if (lessons is! List) return const [];
  return [
    for (final lesson in lessons)
      if (lesson is Map) lesson.cast<String, Object?>(),
  ];
}

Map<String, String> _fixtures(Map<String, Object?> entry) {
  final value = entry['inputFixtures'];
  if (value is! Map) return const {};
  return {
    for (final pair in value.entries)
      if (pair.key is String && pair.value is String)
        pair.key as String: pair.value as String,
  };
}

String _text(Object? value) => value is String ? value : '';

Future<_AuditRun> _execute(
  Directory work, {
  required String kind,
  required String id,
  required String title,
  required String code,
  required String expected,
  required Map<String, String> fixtures,
}) async {
  final directory = await Directory(
    p.join(work.path, _safeName(id)),
  ).create(recursive: true);
  final stdin = fixtures['stdin'];
  if (stdin != null) {
    await File(p.join(directory.path, 'input.txt')).writeAsString(stdin);
  }
  final file = File(p.join(directory.path, 'main.lua'));
  await file.writeAsString(code);
  LuaToolResult result;
  try {
    result = await const LuaToolchain().run(
      file: file.path,
      projectDirectory: directory.path,
    );
  } catch (error) {
    result = LuaToolResult(status: -1, output: '', error: '$error');
  }
  return _AuditRun(
    kind: kind,
    id: id,
    title: title,
    code: code,
    expected: expected,
    actual: result.output,
    error: result.error,
    status: result.status,
  );
}

String _safeName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

class _AuditRun {
  const _AuditRun({
    required this.kind,
    required this.id,
    required this.title,
    required this.code,
    required this.expected,
    required this.actual,
    required this.error,
    required this.status,
  });

  final String kind;
  final String id;
  final String title;
  final String code;
  final String expected;
  final String actual;
  final String error;
  final int status;

  bool get matches => status == 0 && actual.trimRight() == expected.trimRight();
}

String _buildReport({
  required List<Map<String, Object?>> tutorials,
  required List<Map<String, Object?>> examples,
  required List<_AuditRun> runs,
}) {
  final lessonRuns = runs.where((run) => run.kind == 'lesson').toList();
  final exampleRuns = runs.where((run) => run.kind == 'example').toList();
  final titles = <String>{};
  final codes = <String>{};
  final normalizedCodes = <String>{};
  final normalizedTitles = <String>{};
  for (final run in runs) {
    titles.add(run.title);
    codes.add(run.code.trim());
    // Numbers are stripped so "the same program with a different literal"
    // cannot look like a distinct topic in the report.
    normalizedCodes.add(
      run.code
          .replaceAll(RegExp(r'\d+'), 'N')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    );
    normalizedTitles.add(_normalizedTitle(run.title));
  }
  final passed = runs.where((run) => run.matches).toList();
  final failed = runs.where((run) => !run.matches).toList();

  final buffer = StringBuffer()
    ..writeln('# 原共享 Lua 内容审计（R1）')
    ..writeln()
    ..writeln('由 `tool/lua_content/audit_original_lua_content.dart` 生成，')
    ..writeln('执行引擎为仓库内捆绑的 ${const LuaToolchain().version()} 原生库，')
    ..writeln('每段代码在独立临时项目中运行，`print`/`io.write` 输出与退出状态逐条比对。')
    ..writeln()
    ..writeln('## 清单')
    ..writeln()
    ..writeln('| 项目 | 数量 |')
    ..writeln('| --- | --- |')
    ..writeln('| 共享 `tutorials.json` 中的 lua 条目 | ${tutorials.length} |')
    ..writeln('| 共享 `examples.json` 中的 lua 条目 | ${examples.length} |')
    ..writeln('| 实际执行的课时代码 | ${lessonRuns.length} |')
    ..writeln('| 实际执行的示例代码 | ${exampleRuns.length} |')
    ..writeln('| 不同的标题数 | ${titles.length} |')
    ..writeln('| 去掉编号后的不同标题数 | ${normalizedTitles.length} |')
    ..writeln('| 不同的代码正文数 | ${codes.length} |')
    ..writeln('| 去掉字面量后的不同代码数 | ${normalizedCodes.length} |')
    ..writeln('| 与预期输出一致 | ${passed.length} |')
    ..writeln('| 与预期输出不一致或失败 | ${failed.length} |')
    ..writeln();

  buffer
    ..writeln('## 结论')
    ..writeln()
    ..writeln(
      '- 去掉编号后只剩 ${normalizedTitles.length} 个主题标题，却铺满 ${runs.length} 条记录：'
      '内容是固定周期循环编号，不是 ${runs.length} 个真实主题。',
    )
    ..writeln(
      '- 去掉字面量后只剩 ${normalizedCodes.length} 种代码：'
      '同一个加权求和片段改一个数字就成了「新条目」，'
      '与各自标题（日志、缓存、并发等）没有对应关系。',
    )
    ..writeln(
      '- 因此这些条目不能算作「有意义的教学内容」，'
      '扩容只能靠重新撰写 240 个真实主题，而不是在循环模板上继续加编号。',
    )
    ..writeln();

  buffer
    ..writeln('## 逐条执行结果')
    ..writeln()
    ..writeln('| 序号 | 类型 | 条目 | 标题 | 状态码 | 结果 |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  var index = 0;
  for (final run in runs) {
    index++;
    final verdict = run.matches ? '一致' : '不一致';
    buffer.writeln(
      '| $index | ${run.kind} | `${run.id}` | ${_escape(run.title)} | '
      '${run.status} | $verdict |',
    );
  }
  buffer.writeln();

  if (failed.isNotEmpty) {
    buffer
      ..writeln('## 不一致明细')
      ..writeln();
    for (final run in failed) {
      buffer
        ..writeln('### ${run.kind} `${run.id}`')
        ..writeln()
        ..writeln('状态码：${run.status}')
        ..writeln()
        ..writeln('预期输出：')
        ..writeln('```')
        ..writeln(run.expected)
        ..writeln('```')
        ..writeln('实际输出：')
        ..writeln('```')
        ..writeln(run.actual)
        ..writeln('```');
      if (run.error.isNotEmpty) {
        buffer
          ..writeln('错误：')
          ..writeln('```')
          ..writeln(run.error)
          ..writeln('```');
      }
    }
  }
  return buffer.toString();
}

String _escape(String value) => value.replaceAll('|', r'\|');

/// Drops the trailing sequence number and any leading `实现：` prefix so the
/// report counts real themes instead of padded titles.
String _normalizedTitle(String title) => title
    .replaceFirst(RegExp(r'^Lua[^:]*\d+:\s*'), '')
    .replaceFirst(RegExp(r'^实现：'), '')
    .trim();
