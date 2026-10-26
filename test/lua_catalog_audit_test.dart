import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

import '../bin/lua_catalog_audit.dart';

void main() {
  Map<String, String> shippedSources() => {
    for (final asset in luaAuditAssets.entries)
      asset.key: File(
        asset.value.startsWith('packages/qfli_studio_core/')
            ? '../qfli_studio_core/${asset.value.substring('packages/qfli_studio_core/'.length)}'
            : asset.value,
      ).readAsStringSync(),
  };

  Map<String, dynamic> decode(String source) =>
      jsonDecode(source) as Map<String, dynamic>;

  Map<String, String> smallSources({bool includeOriginal = true}) {
    final sources = shippedSources();
    for (final prefix in ['current', 'original']) {
      final examples = decode(sources['${prefix}Examples']!);
      final tutorials = decode(sources['${prefix}Tutorials']!);
      final luaExamples = (examples['entries'] as List)
          .where((entry) => entry['type'] == 'lua')
          .take(prefix == 'original' && !includeOriginal ? 0 : 1)
          .toList();
      final luaTutorials = (tutorials['entries'] as List)
          .where((entry) => entry['type'] == 'lua')
          .take(prefix == 'original' && !includeOriginal ? 0 : 1)
          .toList();
      for (final tutorial in luaTutorials) {
        tutorial['lessons'] = (tutorial['lessons'] as List).take(1).toList();
      }
      sources['${prefix}Examples'] = jsonEncode({
        ...examples,
        'entries': luaExamples,
      });
      sources['${prefix}Tutorials'] = jsonEncode({
        ...tutorials,
        'entries': luaTutorials,
      });
    }
    if (!includeOriginal) {
      sources['legacy'] = jsonEncode({
        ...decode(sources['legacy']!),
        'chapters': [],
      });
    }
    return sources;
  }

  test('inventories every shipped Lua location without deduplication', () {
    final inventory = LuaCatalogAuditInventory.fromSources(shippedSources());
    expect(inventory.issues, isEmpty);
    expect(inventory.cases, hasLength(682));
    expect(inventory.counts['currentLessons'], 240);
    expect(inventory.counts['currentExamples'], 240);
    expect(inventory.counts['originalLessons'], 100);
    expect(inventory.counts['originalExamples'], 100);
    expect(inventory.counts['legacyLessons'], 2);
    expect(
      inventory.cases.map((item) => '${item.asset}#${item.id}').toSet(),
      hasLength(682),
    );
    expect(
      inventory.cases.where((item) => item.corpus == 'current').first.code,
      inventory.cases.where((item) => item.kind == 'example').first.code,
    );
  });

  test(
    'missing or truncated assets cannot become passing smaller inventories',
    () {
      final missing = shippedSources()..remove('legacy');
      expect(
        () => LuaCatalogAuditInventory.fromSources(missing),
        throwsFormatException,
      );
      final sources = shippedSources();
      final examples = decode(sources['currentExamples']!);
      (examples['entries'] as List).removeLast();
      sources['currentExamples'] = jsonEncode(examples);
      final inventory = LuaCatalogAuditInventory.fromSources(sources);
      expect(inventory.cases, hasLength(681));
      expect(inventory.issues.join('\n'), contains('expected 240, got 239'));
      expect(inventory.issues.join('\n'), contains('requires one example'));
    },
  );

  test(
    'duplicate identities retain both payloads and fail coverage validation',
    () {
      final sources = shippedSources();
      final examples = decode(sources['currentExamples']!);
      final entries = examples['entries'] as List;
      entries.add({
        ...entries.first as Map,
        'code': 'print("different payload")',
      });
      sources['currentExamples'] = jsonEncode(examples);
      final inventory = LuaCatalogAuditInventory.fromSources(sources);
      expect(inventory.cases, hasLength(683));
      expect(inventory.issues.join('\n'), contains('duplicate'));
      final duplicateId = (entries.first as Map)['id'];
      final retained = inventory.cases.where(
        (item) =>
            item.corpus == 'current' &&
            item.kind == 'example' &&
            item.id == duplicateId,
      );
      expect(retained, hasLength(2));
      expect(
        retained.map((item) => item.code),
        contains('print("different payload")'),
      );
    },
  );

  test('unsafe, colliding and entry-overwriting fixtures are rejected', () {
    for (final fixtures in [
      {'../escape.lua': 'outside'},
      {'main.lua': 'overwrite'},
      {'stdin': 'first', 'input.txt': 'second'},
    ]) {
      final sources = shippedSources();
      final examples = decode(sources['currentExamples']!);
      (examples['entries'] as List).first['inputFixtures'] = fixtures;
      sources['currentExamples'] = jsonEncode(examples);
      final inventory = LuaCatalogAuditInventory.fromSources(sources);
      expect(inventory.issues.join('\n'), contains('fixture'));
    }
  });

  test('strict output matching never trims or rewrites expectations', () {
    const item = LuaCatalogAuditCase(
      corpus: 'current',
      kind: 'example',
      id: 'exact',
      asset: 'test',
      code: 'print("42")',
      expectedOutput: '42\n',
    );
    expect(
      item.matches(const LuaToolResult(status: 0, output: '42\n', error: '')),
      isTrue,
    );
    for (final output in ['42', '42\r\n', '42 \n', '42\n\n']) {
      expect(
        item.matches(LuaToolResult(status: 0, output: output, error: '')),
        isFalse,
      );
    }
    expect(
      item.matches(
        const LuaToolResult(status: 1, output: '42\n', error: 'bad'),
      ),
      isFalse,
    );
  });

  group('actual bundled Lua audit runner', () {
    late Directory temporary;
    late Directory workspace;
    late File reportFile;
    final toolchain = LuaToolchain(
      libraryPath: Platform.environment['QFLI_LUA_LIBRARY'],
    );

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('lua_audit_中文😀_');
      workspace = Directory(p.join(temporary.path, 'cases'));
      reportFile = File(p.join(temporary.path, 'audit.json'));
    });
    tearDown(() async => temporary.delete(recursive: true));

    test(
      'persists raw legacy mismatches, target labels and real diagnostic probes',
      () async {
        final inventory = LuaCatalogAuditInventory.fromSources(
          smallSources(),
          expectedTopics: 1,
          expectedOriginalTopics: 1,
        );
        expect(inventory.issues, isEmpty);
        final progress = <int>[];
        final report = await runLuaCatalogAudit(
          inventory: inventory,
          workspace: workspace,
          reportFile: reportFile,
          toolchain: toolchain,
          onProgress: (completed, total, _) {
            expect(total, 6);
            progress.add(completed);
          },
        );
        expect(progress, [1, 2, 3, 4, 5, 6]);
        expect(report['executionComplete'], isTrue);
        expect(report['executedCases'], 6);
        expect(report['passedCases'], 4);
        expect(report['failedCases'], 2);
        expect(report['allShippedExactGatePassed'], isFalse);
        expect(report['currentCurriculumGatePassed'], isTrue);
        expect(report['deviceGatePassed'], isFalse);
        final observations = (report['caseResults'] as List).cast<Map>();
        final original = observations.where(
          (row) => row['corpus'] == 'original',
        );
        expect(
          original.every((row) => row['legacyTerminalNewlineMatch'] == true),
          isTrue,
        );
        expect(
          original.every((row) => row['exactOutputMatch'] == false),
          isTrue,
        );
        final probe = report['diagnosticsProbe'] as Map;
        expect(probe['ok'], isTrue);
        expect(probe['checks'], hasLength(6));
        expect(
          (probe['checks'] as List).every((check) => check['passed'] == true),
          isTrue,
        );
        expect(jsonDecode(await reportFile.readAsString())['executedCases'], 6);
        expect(File('${reportFile.path}.next').existsSync(), isFalse);
        expect(workspace.listSync(), isEmpty);
      },
    );

    test(
      'dirty Lua diagnostics canonicalize a mixed-separator caller workspace',
      () async {
        final requested = Platform.isWindows
            ? '${workspace.path.replaceAll(r'\', '/')}${p.separator}mixed'
            : p.join(workspace.path, 'mixed');
        final caller = Directory(requested);
        await caller.create(recursive: true);
        if (Platform.isWindows) {
          expect(caller.path, contains('/'));
          expect(caller.path, contains(r'\'));
          expect(caller.path, isNot(p.normalize(caller.path)));
        }
        final report = await runLuaDiagnosticsAudit(
          workspace: caller,
          toolchain: toolchain,
        );
        expect(report['ok'], isTrue, reason: jsonEncode(report));
        expect(report['requestedWorkspacePath'], requested);
        final canonicalProjectPath = report['canonicalProjectPath'] as String;
        expect(p.isAbsolute(canonicalProjectPath), isTrue);
        expect(canonicalProjectPath, p.normalize(canonicalProjectPath));
        expect(
          p.isWithin(await caller.resolveSymbolicLinks(), canonicalProjectPath),
          isTrue,
        );
        final checks = (report['checks'] as List).cast<Map>();
        expect(checks, hasLength(6));
        expect(checks.every((check) => check['passed'] == true), isTrue);
        final dirty = checks
            .where((check) => check['expectedError'] == true)
            .toList();
        expect(dirty, hasLength(2));
        for (final check in dirty) {
          final file = check['activeFile'] as String;
          expect(p.dirname(file), canonicalProjectPath);
          final diagnostic = (check['diagnostics'] as List).single as Map;
          expect(diagnostic['filePath'], file);
          final source = check['source'] as String;
          expect(source, contains('\r\n'));
          expect(check['expectedRange'], [
            source.indexOf('='),
            source.indexOf('=') + 1,
          ]);
          expect([
            diagnostic['startOffset'],
            diagnostic['endOffset'],
          ], check['expectedRange']);
          final snapshots = (check['snapshots'] as List).cast<Map>();
          expect(snapshots, hasLength(2));
          expect(
            snapshots.every(
              (snapshot) =>
                  p.dirname(snapshot['path'] as String) == canonicalProjectPath,
            ),
            isTrue,
          );
        }
        final unchanged = checks.singleWhere(
          (check) => check['id'] == 'source-files-not-written-or-deleted',
        );
        expect(unchanged['afterSha256'], unchanged['beforeSha256']);
        final sideEffects = checks.singleWhere(
          (check) => check['id'] == 'source-side-effects-not-executed',
        );
        expect(sideEffects['activeMarkerExists'], isFalse);
        expect(sideEffects['moduleMarkerExists'], isFalse);
        expect(report['projectRemoved'], isTrue);
        expect(caller.listSync(), isEmpty);
      },
    );

    test(
      'executes lesson and example fixtures including nested files and stdin',
      () async {
        final sources = smallSources(includeOriginal: false);
        final examples = decode(sources['currentExamples']!);
        final tutorials = decode(sources['currentTutorials']!);
        final example = (examples['entries'] as List).single as Map;
        final lesson =
            ((tutorials['entries'] as List).single['lessons'] as List).single
                as Map;
        const code =
            'local f = assert(io.open("nested/input.txt", "r"))\n'
            'print(f:read("l"))\nf:close()\nprint(io.read("l"))\n';
        const expected = 'fixture 中文😀\n42\n';
        example['code'] = lesson['code'] = code;
        example['expectedOutput'] = lesson['output'] = expected;
        example['inputFixtures'] = {
          'nested/input.txt': 'fixture 中文😀\n',
          'stdin': '42\n',
        };
        sources['currentExamples'] = jsonEncode(examples);
        sources['currentTutorials'] = jsonEncode(tutorials);
        final inventory = LuaCatalogAuditInventory.fromSources(
          sources,
          expectedTopics: 1,
          expectedOriginalTopics: 0,
          expectedLegacyLessons: 0,
        );
        expect(inventory.issues, isEmpty);
        final report = await runLuaCatalogAudit(
          inventory: inventory,
          workspace: workspace,
          reportFile: reportFile,
          toolchain: toolchain,
        );
        expect(report['executionComplete'], isTrue);
        expect(report['executedCases'], 2);
        expect(report['passedCases'], 2);
        expect(report['allShippedExactGatePassed'], isTrue);
        final observations = (report['caseResults'] as List).cast<Map>();
        expect(observations.every((row) => row['stdout'] == expected), isTrue);
        expect(workspace.listSync(), isEmpty);
      },
    );
  });
}
