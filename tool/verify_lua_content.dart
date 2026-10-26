/// Executes every shipped Lua lesson and example through the bundled Lua 5.4.8
/// bridge and compares the real stdout with the independently authored
/// expected output.
///
/// Hard rule: this tool never rewrites `expectedOutput`. A mismatch is a
/// defect to diagnose, not data to regenerate — otherwise a broken program
/// would silently become "correct".
///
/// Usage:
///   dart run tool/verify_lua_content.dart [options]
///
///   `--limit <n>`       only run the first n entries of each kind
///   `--only <text>`     only run entries whose id contains `<text>`
///   `--json <path>`     write a machine-readable report
///   `--markdown <path>` write a human-readable report
///   `--quiet`           only print failures and the final summary
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

const String _tutorialAsset = 'assets/content/lua_tutorials.json';
const String _exampleAsset = 'assets/content/lua_examples.json';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final tutorials = _loadEntries(_tutorialAsset);
  final examples = _loadEntries(_exampleAsset);

  // Fixtures live on the example entry, but a lesson runs the same program and
  // therefore needs the same project files.
  final fixturesByLesson = {
    for (final example in examples)
      if (_text(example['sourceLessonId']).isNotEmpty)
        _text(example['sourceLessonId']): _fixtures(example),
  };

  final lessons = <_Case>[
    for (final tutorial in tutorials)
      for (final lesson in _lessons(tutorial))
        _Case(
          kind: 'lesson',
          id: _text(lesson['id']),
          title: _text(lesson['title']),
          code: _text(lesson['code']),
          expected: _text(lesson['output']),
          fixtures: fixturesByLesson[_text(lesson['id'])] ?? const {},
          pairId: _text(tutorial['id']),
        ),
  ];
  final exampleCases = <_Case>[
    for (final example in examples)
      _Case(
        kind: 'example',
        id: _text(example['id']),
        title: _text(example['title']),
        code: _text(example['code']),
        expected: _text(example['expectedOutput']),
        fixtures: _fixtures(example),
        pairId: _text(example['sourceLessonId']),
      ),
  ];

  final pairFailures = _pairFailures(lessons, exampleCases);
  final selected = <_Case>[
    ...lessons.where(options.selects),
    ...exampleCases.where(options.selects),
  ];

  if (!options.quiet) {
    stdout.writeln(
      'loaded lessons=${lessons.length} examples=${exampleCases.length} '
      'selected=${selected.length} lua=${const LuaToolchain().version()}',
    );
  }

  final results = <_RunResult>[];
  final work = await Directory.systemTemp.createTemp('qfli_lua_verify_');
  try {
    for (final testCase in selected) {
      final result = await _execute(work, testCase);
      results.add(result);
      if (!options.quiet && result.passed) {
        stdout.writeln('PASS ${result.testCase.kind} ${result.testCase.id}');
      }
      if (!result.passed) {
        stdout.writeln('FAIL ${result.testCase.kind} ${result.testCase.id}');
        stdout.writeln('  expected: ${_escape(result.testCase.expected)}');
        stdout.writeln('  actual  : ${_escape(result.actual)}');
        if (result.error.isNotEmpty) {
          stdout.writeln('  error   : ${_escape(result.error)}');
        }
        stdout.writeln('  status  : ${result.status}');
      }
    }
  } finally {
    await work.delete(recursive: true);
  }

  final failed = results.where((result) => !result.passed).toList();
  final summary = {
    'lua': const LuaToolchain().version(),
    'lessons': lessons.length,
    'examples': exampleCases.length,
    'executed': results.length,
    'passed': results.length - failed.length,
    'failed': failed.length,
    'pairFailures': pairFailures,
    'failures': [
      for (final result in failed)
        {
          'kind': result.testCase.kind,
          'id': result.testCase.id,
          'title': result.testCase.title,
          'status': result.status,
          'expected': result.testCase.expected,
          'actual': result.actual,
          'error': result.error,
        },
    ],
  };

  if (options.jsonPath != null) {
    final file = File(options.jsonPath!);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(summary)}\n',
    );
    stdout.writeln('json=${options.jsonPath}');
  }
  if (options.markdownPath != null) {
    final file = File(options.markdownPath!);
    await file.parent.create(recursive: true);
    await file.writeAsString(_markdown(summary, pairFailures));
    stdout.writeln('markdown=${options.markdownPath}');
  }

  stdout.writeln(
    'executed=${results.length} passed=${results.length - failed.length} '
    'failed=${failed.length} pairFailures=${pairFailures.length}',
  );
  if (failed.isNotEmpty || pairFailures.isNotEmpty) exitCode = 1;
}

class _Options {
  _Options({
    this.limit,
    this.only,
    this.jsonPath,
    this.markdownPath,
    this.quiet = false,
  });

  final int? limit;
  final String? only;
  final String? jsonPath;
  final String? markdownPath;
  final bool quiet;

  static _Options parse(List<String> arguments) {
    int? limit;
    String? only;
    String? jsonPath;
    String? markdownPath;
    var quiet = false;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      String next() => index + 1 < arguments.length ? arguments[++index] : '';
      switch (argument) {
        case '--limit':
          limit = int.tryParse(next());
        case '--only':
          only = next();
        case '--json':
          jsonPath = next();
        case '--markdown':
          markdownPath = next();
        case '--quiet':
          quiet = true;
        default:
          stderr.writeln('unknown argument: $argument');
      }
    }
    return _Options(
      limit: limit,
      only: only,
      jsonPath: jsonPath,
      markdownPath: markdownPath,
      quiet: quiet,
    );
  }

  /// Applies `--limit`/`--only` per kind so both lists stay comparable.
  bool selects(_Case testCase) {
    final needle = only;
    if (needle != null && needle.isNotEmpty && !testCase.id.contains(needle)) {
      return false;
    }
    final max = limit;
    if (max == null) return true;
    return _counter(testCase.kind) < max;
  }

  final Map<String, int> _seen = {};

  int _counter(String kind) {
    final value = _seen[kind] ?? 0;
    _seen[kind] = value + 1;
    return value;
  }
}

class _Case {
  const _Case({
    required this.kind,
    required this.id,
    required this.title,
    required this.code,
    required this.expected,
    required this.fixtures,
    required this.pairId,
  });

  final String kind;
  final String id;
  final String title;
  final String code;
  final String expected;
  final Map<String, String> fixtures;
  final String pairId;
}

class _RunResult {
  const _RunResult({
    required this.testCase,
    required this.status,
    required this.actual,
    required this.error,
  });

  final _Case testCase;
  final int status;
  final String actual;
  final String error;

  bool get passed =>
      status == 0 && _normalize(actual) == _normalize(testCase.expected);
}

String _normalize(String value) => value.replaceAll('\r\n', '\n').trimRight();

Future<_RunResult> _execute(Directory work, _Case testCase) async {
  final directory = await Directory(
    p.join(work.path, _safeName('${testCase.kind}-${testCase.id}')),
  ).create(recursive: true);
  for (final fixture in testCase.fixtures.entries) {
    final target = File(p.join(directory.path, fixture.key));
    await target.parent.create(recursive: true);
    await target.writeAsString(fixture.value);
  }
  final file = File(p.join(directory.path, 'main.lua'));
  await file.writeAsString(testCase.code);
  try {
    final result = await const LuaToolchain().run(
      file: file.path,
      projectDirectory: directory.path,
      timeLimit: const Duration(seconds: 15),
    );
    return _RunResult(
      testCase: testCase,
      status: result.status,
      actual: result.output,
      error: result.error,
    );
  } catch (error) {
    return _RunResult(
      testCase: testCase,
      status: -1,
      actual: '',
      error: '$error',
    );
  }
}

List<String> _pairFailures(List<_Case> lessons, List<_Case> examples) {
  final lessonById = {for (final lesson in lessons) lesson.id: lesson};
  final failures = <String>[];
  for (final example in examples) {
    final lesson = lessonById[example.pairId];
    if (lesson == null) {
      failures.add(
        'example ${example.id} points at missing lesson ${example.pairId}',
      );
      continue;
    }
    if (_normalize(lesson.code) != _normalize(example.code)) {
      failures.add('example ${example.id} code differs from ${lesson.id}');
    }
    if (_normalize(lesson.expected) != _normalize(example.expected)) {
      failures.add(
        'example ${example.id} expected output differs from ${lesson.id}',
      );
    }
  }
  final examplePairs = {for (final example in examples) example.pairId};
  for (final lesson in lessons) {
    if (!examplePairs.contains(lesson.id)) {
      failures.add('lesson ${lesson.id} has no paired example');
    }
  }
  return failures;
}

String _markdown(Map<String, Object?> summary, List<String> pairFailures) {
  final buffer = StringBuffer()
    ..writeln('# Lua 内容执行验证')
    ..writeln()
    ..writeln('| 项目 | 数值 |')
    ..writeln('| --- | --- |');
  for (final entry in summary.entries) {
    if (entry.value is List) continue;
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('配对问题：${pairFailures.length}');
  for (final failure in pairFailures) {
    buffer.writeln('- $failure');
  }
  final failures = summary['failures'];
  if (failures is List && failures.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## 失败明细')
      ..writeln();
    for (final failure in failures) {
      if (failure is! Map) continue;
      buffer
        ..writeln('### ${failure['kind']} `${failure['id']}`')
        ..writeln()
        ..writeln('预期：')
        ..writeln('```')
        ..writeln(failure['expected'])
        ..writeln('```')
        ..writeln('实际：')
        ..writeln('```')
        ..writeln(failure['actual'])
        ..writeln('```');
      final error = failure['error'];
      if (error is String && error.isNotEmpty) {
        buffer
          ..writeln('错误：')
          ..writeln('```')
          ..writeln(error)
          ..writeln('```');
      }
    }
  }
  return buffer.toString();
}

String _safeName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

List<Map<String, Object?>> _loadEntries(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('missing asset $path; run tool/generate_lua_content.dart');
    exitCode = 1;
    return const [];
  }
  final decoded = jsonDecode(file.readAsStringSync());
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

String _escape(String value) =>
    value.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
