import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

/// Executes authored Lua topics through the bundled Lua bridge.
///
/// The catalogue is only trustworthy if every program actually runs and prints
/// exactly what the lesson claims. This test is therefore the guard against
/// hand-written guesses: it never rewrites the authored expectation, it only
/// reports a mismatch.
///
/// The test needs the desktop bridge (a bundled Lua built as a native library),
/// so it is skipped on hosts where the runtimes are unavailable instead of
/// failing the suite.
void main() {
  final bridgeAvailable = _bridgeAvailable();

  List<Map<String, dynamic>> loadEntries(String relative) {
    final file = File(p.join(Directory.current.path, relative));
    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return [
      for (final entry in document['entries'] as List<dynamic>)
        entry as Map<String, dynamic>,
    ];
  }

  Future<_RunOutcome> run(String code, Map<String, String> fixtures) async {
    final directory = await Directory.systemTemp.createTemp('lua_content_run_');
    try {
      for (final entry in fixtures.entries) {
        final target = File(p.join(directory.path, entry.key));
        await target.parent.create(recursive: true);
        await target.writeAsString(entry.value);
      }
      final main = File(p.join(directory.path, 'main.lua'));
      await main.writeAsString(code);
      final result = await const LuaToolchain().run(
        file: main.path,
        projectDirectory: directory.path,
        timeLimit: const Duration(seconds: 20),
      );
      return _RunOutcome(
        status: result.status,
        output: result.output,
        error: result.error,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }

  group('authored Lua topics execute', () {
    test('reports the bridge version', () async {
      if (!bridgeAvailable) {
        markTestSkipped('Lua bridge is not available on this host');
        return;
      }
      final version = const LuaToolchain().version();
      expect(version, contains('Lua'));
    });

    test('every lesson prints its authored output', () async {
      if (!bridgeAvailable) {
        markTestSkipped('Lua bridge is not available on this host');
        return;
      }
      final examples = loadEntries('assets/content/lua_examples.json');
      final fixturesByLesson = {
        for (final example in examples)
          example['sourceLessonId'] as String: {
            for (final entry
                in (example['inputFixtures'] as Map<String, dynamic>).entries)
              entry.key: entry.value as String,
          },
      };

      final lessons = [
        for (final tutorial in loadEntries('assets/content/lua_tutorials.json'))
          for (final lesson in tutorial['lessons'] as List<dynamic>)
            lesson as Map<String, dynamic>,
      ];

      // A sample keeps the suite fast; the dedicated verify tool runs all of
      // them, and `fl_target=LUA_CONTENT_FULL=1` widens this test.
      final full = Platform.environment['LUA_CONTENT_FULL'] == '1';
      final selected = full ? lessons : _sample(lessons, 12);

      final failures = <String>[];
      for (final lesson in selected) {
        final id = lesson['id'] as String;
        final outcome = await run(
          lesson['code'] as String,
          fixturesByLesson[id] ?? const {},
        );
        if (outcome.status != 0) {
          failures.add('$id exited ${outcome.status}: ${outcome.error}');
          continue;
        }
        if (outcome.output != lesson['output']) {
          failures.add(
            '$id output mismatch\n  expected: ${_escape(lesson['output'] as String)}\n'
            '  actual  : ${_escape(outcome.output)}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('every example runs and matches its expected output', () async {
      if (!bridgeAvailable) {
        markTestSkipped('Lua bridge is not available on this host');
        return;
      }
      final examples = loadEntries('assets/content/lua_examples.json');
      final full = Platform.environment['LUA_CONTENT_FULL'] == '1';
      final selected = full ? examples : _sample(examples, 12);

      final failures = <String>[];
      for (final example in selected) {
        final id = example['id'] as String;
        final fixtures = {
          for (final entry
              in (example['inputFixtures'] as Map<String, dynamic>).entries)
            entry.key: entry.value as String,
        };
        final outcome = await run(example['code'] as String, fixtures);
        if (outcome.status != 0) {
          failures.add('$id exited ${outcome.status}: ${outcome.error}');
          continue;
        }
        if (outcome.output != example['expectedOutput']) {
          failures.add(
            '$id output mismatch\n  expected: '
            '${_escape(example['expectedOutput'] as String)}\n'
            '  actual  : ${_escape(outcome.output)}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}

class _RunOutcome {
  const _RunOutcome({
    required this.status,
    required this.output,
    required this.error,
  });

  final int status;
  final String output;
  final String error;
}

/// Evenly spaced sample so all chapters get exercised.
List<Map<String, dynamic>> _sample(
  List<Map<String, dynamic>> entries,
  int size,
) {
  if (entries.length <= size) return entries;
  final step = entries.length ~/ size;
  return [
    for (var index = 0; index < entries.length; index += step) entries[index],
  ].take(size).toList();
}

String _escape(String value) =>
    value.replaceAll('\n', r'\n').replaceAll('\t', r'\t');

/// Cheap probe: the bridge reports its version without executing user code.
bool _bridgeAvailable() {
  try {
    final version = const LuaToolchain().version();
    return version.isNotEmpty;
  } on Object {
    return false;
  }
}
