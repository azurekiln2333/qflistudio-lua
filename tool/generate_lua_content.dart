/// Generates the product-owned Lua content assets from the authored topics.
///
/// The topics themselves are hand-written Dart data under
/// `tool/lua_content/topics_*.dart`. This tool never invents topic text: it
/// validates the authored data and serialises it into the two aggregate
/// documents the app loads.
///
/// Usage:
///   dart run tool/generate_lua_content.dart [--check]
///
///   --check           validate without writing (used by tests and CI)
///   --force           write assets even when validation fails (local draft
///                     iteration only; tests never use it)
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'lua_content/topics.dart';
import 'lua_content/lua_topic.dart';

const String _updatedAt = '2026-10-22';
const String _source = 'https://www.lua.org/manual/5.4/';
const String _license =
    'Original QFLI curriculum; reference link retained. CC BY 4.0';
const String _tutorialAsset = 'assets/content/lua_tutorials.json';
const String _exampleAsset = 'assets/content/lua_examples.json';

/// Minimum number of authored topics required by the release acceptance.
const int minimumTopicCount = 240;

Future<void> main(List<String> arguments) async {
  final checkOnly = arguments.contains('--check');
  final force = arguments.contains('--force');
  final report = validateTopics(luaTopics);
  stdout.writeln(report.summary);
  if (!report.isValid && !force) {
    stderr.writeln(report.describeFailures());
    exitCode = 1;
    return;
  }
  if (!report.isValid) {
    stderr.writeln(report.describeFailures());
    stderr.writeln('--force: writing assets despite validation failures');
  }
  final tutorials = encodeTutorialDocument(luaTopics);
  final examples = encodeExampleDocument(luaTopics);
  if (checkOnly) {
    stdout.writeln('check-only: assets not written');
    return;
  }
  await _write(_tutorialAsset, tutorials);
  await _write(_exampleAsset, examples);
  stdout.writeln(
    'written $_tutorialAsset (${tutorials.length} chars) and '
    '$_exampleAsset (${examples.length} chars)',
  );
}

Future<void> _write(String path, String content) async {
  final file = File(p.join(Directory.current.path, path));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}

String encodeTutorialDocument(List<LuaTopic> topics) {
  final byChapter = <String, List<LuaTopic>>{};
  for (final topic in topics) {
    byChapter.putIfAbsent(topic.chapter, () => []).add(topic);
  }
  final entries = <Map<String, Object?>>[];
  for (final chapter in luaChapters) {
    final chapterTopics = byChapter[chapter.id];
    if (chapterTopics == null || chapterTopics.isEmpty) continue;
    entries.add({
      'id': 'lua-chapter-${chapter.id}',
      'language': 'lua',
      'type': 'lua',
      'locale': 'zh-CN',
      'level': _chapterLevel(chapterTopics),
      'title': chapter.title,
      'summary': chapter.summary,
      'concepts': _unique([for (final t in chapterTopics) ...t.concepts]),
      'source': _source,
      'license': _license,
      'updatedAt': _updatedAt,
      'lessons': [
        for (final topic in chapterTopics)
          {
            'id': lessonId(topic),
            'title': topic.title,
            'summary': topic.summary,
            'objective': topic.objective,
            'concepts': topic.concepts,
            'prerequisites': topic.prerequisites,
            'pitfalls': topic.pitfalls,
            'explain': topic.explain,
            'code': topic.code,
            'output': topic.output,
            'exercises': [
              for (final exercise in topic.exercises)
                {
                  'prompt': exercise.prompt,
                  'hint': exercise.hint,
                  'answer': exercise.answer,
                },
            ],
          },
      ],
    });
  }
  return _encode({
    'schemaVersion': 2,
    'kind': 'tutorials',
    'language': 'lua',
    'updatedAt': _updatedAt,
    'entries': entries,
  });
}

String encodeExampleDocument(List<LuaTopic> topics) {
  final entries = <Map<String, Object?>>[
    for (final topic in topics)
      {
        'id': exampleId(topic),
        'language': 'lua',
        'type': 'lua',
        'locale': 'zh-CN',
        'level': topic.level,
        'title': topic.title,
        'summary': topic.summary,
        'concepts': topic.concepts,
        'source': _source,
        'license': _license,
        'updatedAt': _updatedAt,
        'code': topic.code,
        'expectedOutput': topic.output,
        'inputFixtures': topic.fixtures,
        'templateType': 'lua',
        'sourceLessonId': lessonId(topic),
      },
  ];
  return _encode({
    'schemaVersion': 2,
    'kind': 'examples',
    'language': 'lua',
    'updatedAt': _updatedAt,
    'entries': entries,
  });
}

String lessonId(LuaTopic topic) => 'lua-lesson-${topic.id}';

String exampleId(LuaTopic topic) => 'lua-example-${topic.id}';

String _encode(Object document) =>
    '${const JsonEncoder.withIndent('  ').convert(document)}\n';

String _chapterLevel(List<LuaTopic> topics) {
  const order = ['beginner', 'intermediate', 'advanced'];
  var index = 0;
  for (final topic in topics) {
    final position = order.indexOf(topic.level);
    if (position > index) index = position;
  }
  return order[index];
}

List<String> _unique(List<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(value)) value,
  ];
}

/// Structural validation of the authored topics.
///
/// This is deliberately about *shape and distinctness*, not about running Lua;
/// `tool/verify_lua_content.dart` owns execution.
TopicReport validateTopics(List<LuaTopic> topics) {
  final failures = <String>[];
  final chapterIds = {for (final chapter in luaChapters) chapter.id};
  final ids = <String, int>{};
  final titles = <String, int>{};
  final normalizedCodes = <String, int>{};
  final outputs = <String, int>{};
  final chapterCounts = <String, int>{};

  if (topics.length < minimumTopicCount) {
    failures.add(
      'topic count ${topics.length} is below the required '
      '$minimumTopicCount',
    );
  }

  for (var index = 0; index < topics.length; index++) {
    final topic = topics[index];
    final where = 'topic[$index] ${topic.id}';
    _require(failures, where, 'id', topic.id);
    _require(failures, where, 'chapter', topic.chapter);
    _require(failures, where, 'title', topic.title);
    _require(failures, where, 'summary', topic.summary);
    _require(failures, where, 'objective', topic.objective);
    _require(failures, where, 'explain', topic.explain);
    _require(failures, where, 'code', topic.code);
    _require(failures, where, 'output', topic.output);
    if (!chapterIds.contains(topic.chapter)) {
      failures.add('$where has unknown chapter "${topic.chapter}"');
    }
    if (!const {'beginner', 'intermediate', 'advanced'}.contains(topic.level)) {
      failures.add('$where has invalid level "${topic.level}"');
    }
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(topic.id)) {
      failures.add('$where id must be a lowercase kebab-case slug');
    }
    if (topic.concepts.length < 2) {
      failures.add('$where needs at least two concepts');
    }
    if (topic.exercises.length < 2) {
      failures.add('$where needs at least two exercises');
    }
    for (final exercise in topic.exercises) {
      _require(failures, where, 'exercise prompt', exercise.prompt);
      _require(failures, where, 'exercise hint', exercise.hint);
      _require(failures, where, 'exercise answer', exercise.answer);
    }
    if (!topic.code.contains('\n')) {
      failures.add('$where code should be a multi-line program');
    }
    if (topic.output.trim().isEmpty) {
      failures.add('$where output must contain at least one line');
    }
    for (final text in [
      topic.title,
      topic.summary,
      topic.explain,
      topic.objective,
      topic.code,
      topic.output,
      for (final exercise in topic.exercises) ...[
        exercise.prompt,
        exercise.hint,
        exercise.answer,
      ],
    ]) {
      final placeholder = _placeholderIn(text);
      if (placeholder != null) {
        failures.add('$where contains placeholder text "$placeholder"');
      }
    }

    final previousId = ids[topic.id];
    if (previousId != null) {
      failures.add('$where duplicates id of topic[$previousId]');
    }
    ids[topic.id] = index;

    final previousTitle = titles[topic.title];
    if (previousTitle != null) {
      failures.add(
        '$where duplicates title "${topic.title}" of topic[$previousTitle]',
      );
    }
    titles[topic.title] = index;

    final normalized = normalizeCode(topic.code);
    final previousCode = normalizedCodes[normalized];
    if (previousCode != null) {
      failures.add(
        '$where has the same program as topic[$previousCode] '
        'after removing literals',
      );
    }
    normalizedCodes[normalized] = index;

    final outputKey = topic.output.trim();
    final previousOutput = outputs[outputKey];
    if (previousOutput != null) {
      failures.add(
        '$where repeats the expected output of topic[$previousOutput]',
      );
    }
    outputs[outputKey] = index;

    chapterCounts[topic.chapter] = (chapterCounts[topic.chapter] ?? 0) + 1;
  }

  for (final chapter in luaChapters) {
    final count = chapterCounts[chapter.id] ?? 0;
    if (count < 5) {
      failures.add(
        'chapter "${chapter.id}" only has $count topics; '
        'every chapter needs at least five',
      );
    }
  }

  return TopicReport(
    topics: topics.length,
    chapters: chapterCounts.length,
    lessons: topics.length,
    examples: topics.length,
    distinctTitles: titles.length,
    distinctPrograms: normalizedCodes.length,
    distinctOutputs: outputs.length,
    failures: failures,
  );
}

String? _placeholderIn(String text) {
  for (final marker in const [
    'TODO',
    'FIXME',
    '待补充',
    '占位',
    '示例文本',
    'lorem',
    'Lorem',
    'xxx',
    'XXX',
  ]) {
    if (text.contains(marker)) return marker;
  }
  return null;
}

void _require(List<String> failures, String where, String field, String value) {
  if (value.trim().isEmpty) failures.add('$where has empty $field');
}

/// Collapses whitespace and literal values so a padded copy of the same
/// program cannot pass the distinctness gate.
String normalizeCode(String code) => code
    .replaceAll(RegExp(r'--[^\n]*'), '')
    .replaceAll(RegExp(r'\d+'), 'N')
    .replaceAll(RegExp(r'"[^"\n]*"'), '"S"')
    .replaceAll(RegExp(r"'[^'\n]*'"), '"S"')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class TopicReport {
  const TopicReport({
    required this.topics,
    required this.chapters,
    required this.lessons,
    required this.examples,
    required this.distinctTitles,
    required this.distinctPrograms,
    required this.distinctOutputs,
    required this.failures,
  });

  final int topics;
  final int chapters;
  final int lessons;
  final int examples;
  final int distinctTitles;
  final int distinctPrograms;
  final int distinctOutputs;
  final List<String> failures;

  bool get isValid => failures.isEmpty;

  String get summary =>
      'topics=$topics chapters=$chapters lessons=$lessons '
      'examples=$examples distinctTitles=$distinctTitles '
      'distinctPrograms=$distinctPrograms distinctOutputs=$distinctOutputs '
      'failures=${failures.length}';

  String describeFailures() => failures.map((line) => 'FAIL $line').join('\n');
}
