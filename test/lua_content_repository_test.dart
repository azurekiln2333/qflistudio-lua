import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_content_repository.dart';
import 'package:qfli_studio_core/content/content_repository.dart';

/// Minimal in-memory [ContentRepository] used as the fallback in these tests.
class _FakeRepository implements ContentRepository {
  _FakeRepository(this._catalog);

  final ContentCatalog _catalog;
  int tutorialCalls = 0;
  int exampleCalls = 0;

  @override
  Future<ContentCatalog> load() async => _catalog;

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async {
    tutorialCalls++;
    return [
      for (final tutorial in _catalog.tutorials)
        if (filter.matches(tutorial)) tutorial,
    ];
  }

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async {
    exampleCalls++;
    return [
      for (final example in _catalog.examples)
        if (filter.matches(example)) example,
    ];
  }
}

String _tutorialJson({
  required String id,
  required String language,
  int lessons = 1,
}) {
  return jsonEncode({
    'schemaVersion': 1,
    'tutorials': [
      {
        'id': id,
        'language': language,
        'type': language,
        'locale': 'zh-CN',
        'level': 'beginner',
        'title': 'Title $id',
        'summary': 'Summary $id',
        'concepts': ['basics', 'syntax'],
        'source': 'test',
        'license': 'CC-BY-4.0',
        'updatedAt': '2026-10-22',
        'lessons': [
          for (var index = 0; index < lessons; index++)
            {
              'id': '$id-l$index',
              'title': 'Lesson $index',
              'summary': 'Lesson summary',
              'concepts': ['basics'],
              'explain': 'Explanation',
              'code': 'print($index)',
              'output': '$index\n',
              'exercises': [
                {'prompt': 'Prompt', 'hint': 'Hint', 'answer': 'Answer'},
              ],
            },
        ],
      },
    ],
  });
}

String _exampleJson({required String id, required String language}) {
  return jsonEncode({
    'schemaVersion': 1,
    'examples': [
      {
        'id': id,
        'language': language,
        'type': language,
        'locale': 'zh-CN',
        'level': 'beginner',
        'title': 'Example $id',
        'summary': 'Example summary',
        'concepts': ['basics'],
        'source': 'test',
        'license': 'CC-BY-4.0',
        'updatedAt': '2026-10-22',
        'code': 'print("hello")',
        'expectedOutput': 'hello\n',
      },
    ],
  });
}

LuaContentRepository _repository({
  ContentRepository? fallback,
  String? luaTutorial,
  String? luaExample,
  int? loaderDelayMs,
}) {
  return LuaContentRepository(
    fallback: fallback,
    loader: (asset) async {
      if (loaderDelayMs != null) {
        await Future<void>.delayed(Duration(milliseconds: loaderDelayMs));
      }
      switch (asset) {
        case LuaContentRepository.tutorialAsset:
          return luaTutorial ??
              _tutorialJson(id: 'lua-a', language: 'lua', lessons: 2);
        case LuaContentRepository.exampleAsset:
          return luaExample ?? _exampleJson(id: 'lua-ex', language: 'lua');
        default:
          throw StateError('unexpected asset $asset');
      }
    },
  );
}

ContentCatalog _otherLanguageCatalog() {
  final tutorials = ContentCatalog.fromJson(
    tutorialsSource: _tutorialJson(id: 'python-a', language: 'python'),
    examplesSource: _exampleJson(id: 'python-ex', language: 'python'),
  );
  return tutorials;
}

void main() {
  group('LuaContentRepository own catalog', () {
    test('loads and exposes the Lua curriculum', () async {
      final repository = _repository();
      final catalog = await repository.load();

      expect(catalog.tutorials, hasLength(1));
      expect(catalog.tutorials.single.language, 'lua');
      expect(luaTopicCount(catalog), 2);
      expect(catalog.examples, hasLength(1));
    });

    test('parses the assets exactly once across many queries', () async {
      final repository = _repository();

      await repository.load();
      await repository.tutorials();
      await repository.examples();
      await repository.tutorials(filter: const ContentFilter(language: 'lua'));

      expect(repository.parseCount, 1);
    });

    test('concurrent first calls share one parse', () async {
      final repository = _repository(loaderDelayMs: 10);

      await Future.wait([
        repository.load(),
        repository.load(),
        repository.tutorials(),
      ]);

      expect(repository.parseCount, 1);
    });

    test('returns Lua tutorials for a Lua language filter', () async {
      final repository = _repository();

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(language: 'lua'),
      );
      final examples = await repository.examples(
        filter: const ContentFilter(language: 'lua'),
      );

      expect(tutorials.map((tutorial) => tutorial.language), ['lua']);
      expect(examples.map((example) => example.language), ['lua']);
    });

    test('yields nothing when the filter names another language', () async {
      final repository = _repository();

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(language: 'python'),
      );

      expect(tutorials, isEmpty);
    });

    test('honours a type filter that excludes lua', () async {
      final repository = _repository();

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(type: 'python'),
      );

      expect(tutorials, isEmpty);
    });

    test('honours a types set that contains lua', () async {
      final repository = _repository();

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(types: {'lua'}),
      );

      expect(tutorials, hasLength(1));
    });

    test('honours a types set without lua', () async {
      final repository = _repository();

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(types: {'python'}),
      );

      expect(tutorials, isEmpty);
    });
  });

  group('LuaContentRepository fallback behaviour', () {
    test('a pure Lua query never touches the fallback', () async {
      final fallback = _FakeRepository(_otherLanguageCatalog());
      final repository = _repository(fallback: fallback);

      await repository.tutorials(filter: const ContentFilter(language: 'lua'));
      await repository.examples(filter: const ContentFilter(language: 'lua'));

      expect(fallback.tutorialCalls, 0);
      expect(fallback.exampleCalls, 0);
    });

    test('another language is served entirely by the fallback', () async {
      final fallback = _FakeRepository(_otherLanguageCatalog());
      final repository = _repository(fallback: fallback);

      final tutorials = await repository.tutorials(
        filter: const ContentFilter(language: 'python'),
      );

      expect(tutorials.map((tutorial) => tutorial.language), ['python']);
      expect(fallback.tutorialCalls, 1);
    });

    test(
      'an unfiltered query merges own content with foreign languages',
      () async {
        final fallback = _FakeRepository(_otherLanguageCatalog());
        final repository = _repository(fallback: fallback);

        final tutorials = await repository.tutorials();

        expect(tutorials.map((tutorial) => tutorial.language).toSet(), {
          'lua',
          'python',
        });
        expect(
          tutorials.where((tutorial) => tutorial.language == 'lua'),
          hasLength(1),
          reason: 'Lua entries must not be duplicated by the fallback',
        );
        expect(fallback.tutorialCalls, 1);
      },
    );

    test(
      'a shared aggregate fallback does not duplicate Lua entries',
      () async {
        // The shared catalog carries Lua entries too; the repository must drop
        // them because it already answers for that language.
        final sharedCatalog = ContentCatalog.fromJson(
          tutorialsSource: jsonEncode({
            'schemaVersion': 1,
            'tutorials': [
              {
                'id': 'lua-shared',
                'language': 'lua',
                'type': 'lua',
                'locale': 'zh-CN',
                'level': 'beginner',
                'title': 'Shared Lua',
                'summary': 'Shared',
                'concepts': ['x'],
                'source': 'shared',
                'license': 'CC-BY-4.0',
                'updatedAt': '2026-10-22',
                'lessons': [
                  {
                    'id': 'lua-shared-l0',
                    'title': 'L0',
                    'summary': 'S',
                    'concepts': ['x'],
                    'explain': 'E',
                    'code': 'print(1)',
                    'output': '1\n',
                    'exercises': [
                      {'prompt': 'p', 'hint': 'h', 'answer': 'a'},
                    ],
                  },
                ],
              },
              {
                'id': 'python-shared',
                'language': 'python',
                'type': 'python',
                'locale': 'zh-CN',
                'level': 'beginner',
                'title': 'Shared Python',
                'summary': 'Shared',
                'concepts': ['y'],
                'source': 'shared',
                'license': 'CC-BY-4.0',
                'updatedAt': '2026-10-22',
                'lessons': [
                  {
                    'id': 'python-shared-l0',
                    'title': 'L0',
                    'summary': 'S',
                    'concepts': ['y'],
                    'explain': 'E',
                    'code': 'print(1)',
                    'output': '1\n',
                    'exercises': [
                      {'prompt': 'p', 'hint': 'h', 'answer': 'a'},
                    ],
                  },
                ],
              },
            ],
          }),
          examplesSource: _exampleJson(id: 'lua-shared-ex', language: 'lua'),
        );
        final fallback = _FakeRepository(sharedCatalog);
        final repository = _repository(fallback: fallback);

        final tutorials = await repository.tutorials();

        expect(
          tutorials.where((tutorial) => tutorial.language == 'lua'),
          hasLength(1),
        );
        expect(
          tutorials.where((tutorial) => tutorial.language == 'python'),
          hasLength(1),
        );
      },
    );

    test(
      'a types filter asks the fallback only for the remaining types',
      () async {
        final fallback = _FakeRepository(_otherLanguageCatalog());
        final repository = _repository(fallback: fallback);

        final tutorials = await repository.tutorials(
          filter: const ContentFilter(types: {'lua', 'python'}),
        );

        expect(tutorials.map((tutorial) => tutorial.language).toSet(), {
          'lua',
          'python',
        });
        expect(fallback.tutorialCalls, 1);
      },
    );

    test('a lua-only types filter skips the fallback entirely', () async {
      final fallback = _FakeRepository(_otherLanguageCatalog());
      final repository = _repository(fallback: fallback);

      await repository.tutorials(filter: const ContentFilter(types: {'lua'}));

      expect(fallback.tutorialCalls, 0);
    });
  });

  group('LuaContentRepository asset validation', () {
    test('reports the asset path when the loader throws', () async {
      final repository = LuaContentRepository(
        loader: (asset) async => throw StateError('missing'),
      );

      await expectLater(
        repository.load(),
        throwsA(
          isA<LuaContentAssetException>().having(
            (error) => error.asset,
            'asset',
            LuaContentRepository.tutorialAsset,
          ),
        ),
      );
    });

    test('rejects a catalog whose entries are not lua', () async {
      final repository = _repository(
        luaTutorial: _tutorialJson(id: 'x', language: 'python'),
      );

      await expectLater(
        repository.load(),
        throwsA(isA<LuaContentAssetException>()),
      );
    });

    test('rejects a tutorial without lessons', () async {
      final repository = _repository(
        luaTutorial: jsonEncode({
          'schemaVersion': 1,
          'tutorials': [
            {
              'id': 'lua-empty',
              'language': 'lua',
              'type': 'lua',
              'locale': 'zh-CN',
              'level': 'beginner',
              'title': 'Empty',
              'summary': 'S',
              'concepts': ['a'],
              'source': 'test',
              'license': 'CC-BY-4.0',
              'updatedAt': '2026-10-22',
              'lessons': <Object>[],
            },
          ],
        }),
      );

      await expectLater(
        repository.load(),
        throwsA(isA<LuaContentAssetException>()),
      );
    });
  });

  group('bundled Lua assets', () {
    late Directory root;

    setUpAll(() {
      root = Directory.current;
    });

    test(
      'the authored assets exist and parse through the repository',
      () async {
        final tutorialFile = File(
          p.join(root.path, LuaContentRepository.tutorialAsset),
        );
        final exampleFile = File(
          p.join(root.path, LuaContentRepository.exampleAsset),
        );

        expect(tutorialFile.existsSync(), isTrue);
        expect(exampleFile.existsSync(), isTrue);

        final sources = {
          LuaContentRepository.tutorialAsset: await tutorialFile.readAsString(),
          LuaContentRepository.exampleAsset: await exampleFile.readAsString(),
        };
        final repository = LuaContentRepository(
          loader: (asset) async => sources[asset]!,
        );

        final catalog = await repository.load();

        expect(luaTopicCount(catalog), greaterThanOrEqualTo(240));
        expect(catalog.examples.length, greaterThanOrEqualTo(240));
      },
    );
  });
}
