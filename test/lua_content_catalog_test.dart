import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Structural guarantees for the authored Lua curriculum.
///
/// These assertions protect the catalogue from mechanical padding: every topic
/// must be individually authored, so ids, titles, programs and expected outputs
/// are all unique and the tutorials pair one-to-one with the examples.
void main() {
  late Map<String, dynamic> tutorialDoc;
  late Map<String, dynamic> exampleDoc;
  late List<Map<String, dynamic>> tutorials;
  late List<Map<String, dynamic>> examples;
  late List<Map<String, dynamic>> lessons;

  setUpAll(() {
    final tutorialFile = File(
      p.join(Directory.current.path, 'assets/content/lua_tutorials.json'),
    );
    final exampleFile = File(
      p.join(Directory.current.path, 'assets/content/lua_examples.json'),
    );
    tutorialDoc =
        jsonDecode(tutorialFile.readAsStringSync()) as Map<String, dynamic>;
    exampleDoc =
        jsonDecode(exampleFile.readAsStringSync()) as Map<String, dynamic>;

    tutorials = [
      for (final entry in tutorialDoc['entries'] as List<dynamic>)
        entry as Map<String, dynamic>,
    ];
    examples = [
      for (final entry in exampleDoc['entries'] as List<dynamic>)
        entry as Map<String, dynamic>,
    ];
    lessons = [
      for (final tutorial in tutorials)
        for (final lesson in tutorial['lessons'] as List<dynamic>)
          lesson as Map<String, dynamic>,
    ];
  });

  group('catalog size', () {
    test('carries at least 240 authored topics', () {
      expect(lessons.length, greaterThanOrEqualTo(240));
      expect(examples.length, greaterThanOrEqualTo(240));
    });

    test('every chapter keeps at least five topics', () {
      final perTutorial = {
        for (final tutorial in tutorials)
          tutorial['id'] as String: (tutorial['lessons'] as List).length,
      };
      expect(perTutorial, isNotEmpty);
      for (final entry in perTutorial.entries) {
        expect(
          entry.value,
          greaterThanOrEqualTo(5),
          reason: '${entry.key} has only ${entry.value} topics',
        );
      }
    });
  });

  group('distinctness', () {
    test('topic ids are unique', () {
      final ids = lessons.map((lesson) => lesson['id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('topic titles are unique', () {
      final titles = lessons
          .map((lesson) => lesson['title'] as String)
          .toList();
      expect(titles.toSet(), hasLength(titles.length));
    });

    test('topic programs are unique', () {
      final programs = lessons
          .map((lesson) => lesson['code'] as String)
          .toSet();
      expect(programs, hasLength(lessons.length));
    });

    test('topic expected outputs are unique', () {
      final outputs = lessons
          .map((lesson) => lesson['output'] as String)
          .toSet();
      expect(outputs, hasLength(lessons.length));
    });

    test('example programs are unique', () {
      final programs = examples
          .map((example) => example['code'] as String)
          .toSet();
      expect(programs, hasLength(examples.length));
    });
  });

  group('topic content quality', () {
    test('every topic has teaching copy, concepts and exercises', () {
      for (final lesson in lessons) {
        final id = lesson['id'] as String;
        expect((lesson['explain'] as String).trim(), isNotEmpty, reason: id);
        expect((lesson['objective'] as String).trim(), isNotEmpty, reason: id);
        expect(
          (lesson['concepts'] as List).length,
          greaterThanOrEqualTo(2),
          reason: id,
        );
        expect(
          (lesson['exercises'] as List).length,
          greaterThanOrEqualTo(2),
          reason: id,
        );
        expect((lesson['pitfalls'] as List), isNotEmpty, reason: id);
      }
    });

    test('every program spans several lines', () {
      for (final lesson in lessons) {
        final code = lesson['code'] as String;
        expect(
          code.split('\n').length,
          greaterThanOrEqualTo(2),
          reason: lesson['id'] as String,
        );
      }
    });

    test('no topic falls back to placeholder text', () {
      // Case-sensitive on purpose: identifiers such as `newTodoList` are
      // legitimate, while an all-caps TODO/FIXME marks unfinished work.
      const markers = [
        'TODO',
        'FIXME',
        '待补充',
        '占位',
        '示例文本',
        'lorem',
        'Lorem',
        'placeholder',
        'Placeholder',
      ];
      for (final lesson in lessons) {
        final haystack = [
          lesson['title'],
          lesson['summary'],
          lesson['objective'],
          lesson['explain'],
          lesson['code'],
        ].join(' ');
        for (final marker in markers) {
          expect(
            haystack.contains(marker),
            isFalse,
            reason: '${lesson['id']} contains $marker',
          );
        }
      }
    });

    test('every exercise has a prompt, hint and answer', () {
      for (final lesson in lessons) {
        for (final exercise in lesson['exercises'] as List) {
          final map = exercise as Map<String, dynamic>;
          expect((map['prompt'] as String).trim(), isNotEmpty);
          expect((map['hint'] as String).trim(), isNotEmpty);
          expect((map['answer'] as String).trim(), isNotEmpty);
        }
      }
    });
  });

  group('tutorial and example pairing', () {
    test('every topic has exactly one matching example', () {
      final byLesson = <String, List<String>>{};
      for (final example in examples) {
        final sourceLessonId = example['sourceLessonId'] as String?;
        expect(sourceLessonId, isNotNull, reason: example['id'] as String);
        byLesson
            .putIfAbsent(sourceLessonId!, () => [])
            .add(example['id'] as String);
      }

      for (final lesson in lessons) {
        final id = lesson['id'] as String;
        expect(byLesson[id], hasLength(1), reason: 'no example for $id');
      }
    });

    test('paired entries share code and expected output', () {
      final examplesById = {
        for (final example in examples)
          example['sourceLessonId'] as String: example,
      };

      for (final lesson in lessons) {
        final example = examplesById[lesson['id'] as String];
        expect(example, isNotNull, reason: lesson['id'] as String);
        expect(example!['code'], lesson['code']);
        expect(example['expectedOutput'], lesson['output']);
        expect(example['language'], 'lua');
      }
    });

    test('every catalogue entry is tagged as lua', () {
      for (final tutorial in tutorials) {
        expect(tutorial['language'], 'lua');
        expect(tutorial['type'], 'lua');
      }
      for (final example in examples) {
        expect(example['language'], 'lua');
        expect(example['type'], 'lua');
      }
    });
  });
}
