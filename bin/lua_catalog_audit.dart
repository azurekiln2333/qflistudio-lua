/// Standalone audit application. Build with -t bin/lua_catalog_audit.dart.
/// This entry never changes product startup or treats a host run as OHOS proof.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_code_analyzer.dart';
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/content/content_validator.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/app_private_roots.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';
import 'package:qfli_studio_core/tools/offline_tools.dart';

const luaAuditAssets = <String, String>{
  'currentTutorials': 'assets/content/lua_tutorials.json',
  'currentExamples': 'assets/content/lua_examples.json',
  'originalTutorials':
      'packages/qfli_studio_core/assets/content/tutorials.json',
  'originalExamples': 'packages/qfli_studio_core/assets/content/examples.json',
  'legacy': 'packages/qfli_studio_core/assets/tutorials/lua.json',
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: LuaCatalogAuditPage()));
}

/// A snippet location, deliberately retained even when another has equal code.
class LuaCatalogAuditCase {
  const LuaCatalogAuditCase({
    required this.corpus,
    required this.kind,
    required this.id,
    required this.asset,
    required this.code,
    required this.expectedOutput,
    this.fixtures = const {},
    this.lessonId,
    this.expectedStatus = 0,
  });

  final String corpus;
  final String kind;
  final String id;
  final String asset;
  final String code;
  final String expectedOutput;
  final Map<String, String> fixtures;
  final String? lessonId;
  final int expectedStatus;

  bool matches(LuaToolResult result) =>
      result.status == expectedStatus && result.output == expectedOutput;

  Map<String, Object?> toJson() => {
    'corpus': corpus,
    'kind': kind,
    'id': id,
    'asset': asset,
    'source': code,
    'sourceSha256': OfflineDigest.sha256(code),
    'expectedOutput': expectedOutput,
    'expectedStatus': expectedStatus,
    'inputFixtures': fixtures,
    'fixtureSha256': {
      for (final fixture in fixtures.entries)
        fixture.key: OfflineDigest.sha256(fixture.value),
    },
    if (lessonId != null) 'sourceLessonId': lessonId,
  };
}

/// Coverage gates are independent of the loaded documents. A truncated package
/// cannot pass merely because all the snippets left inside it execute.
class LuaCatalogAuditInventory {
  LuaCatalogAuditInventory._(this.cases, this.issues, this.counts);

  final List<LuaCatalogAuditCase> cases;
  final List<String> issues;
  final Map<String, int> counts;

  factory LuaCatalogAuditInventory.fromSources(
    Map<String, String> sources, {
    int expectedTopics = 240,
    int expectedOriginalTopics = 100,
    int expectedLegacyLessons = 2,
  }) {
    String source(String key) =>
        sources[key] ?? (throw FormatException('Missing audit asset: $key'));
    final current = ContentCatalog.fromJson(
      tutorialsSource: source('currentTutorials'),
      examplesSource: source('currentExamples'),
    );
    final original = ContentCatalog.fromJson(
      tutorialsSource: source('originalTutorials'),
      examplesSource: source('originalExamples'),
    );
    final legacy = ContentCatalog.fromJson(
      tutorialsSource: source('legacy'),
      examplesSource: '{"entries":[]}',
    );
    final cases = <LuaCatalogAuditCase>[];
    final issues = <String>[
      for (final issue in ContentCatalogValidator.validate(current).issues)
        'current metadata: $issue',
    ];
    final counts = <String, int>{};
    bool isLua(ContentEntry entry) =>
        entry.type.trim().toLowerCase() == 'lua' ||
        entry.language.trim().toLowerCase() == 'lua';

    void addCatalog(ContentCatalog catalog, String corpus, String prefix) {
      final examples = catalog.examples.where(isLua).toList();
      final tutorials = catalog.tutorials.where(isLua).toList();
      final fixturesByLesson = <String, Map<String, String>>{};
      final pairs = <String, List<ExampleContent>>{};
      for (final example in examples) {
        final lessonId = example.sourceLessonId;
        if (lessonId == null) continue;
        pairs.putIfAbsent(lessonId, () => []).add(example);
        fixturesByLesson[lessonId] = example.inputFixtures;
      }
      var lessonCount = 0;
      for (final tutorial in tutorials) {
        for (final lesson in tutorial.lessons) {
          lessonCount++;
          cases.add(
            LuaCatalogAuditCase(
              corpus: corpus,
              kind: 'lesson',
              id: lesson.id,
              asset: luaAuditAssets['${prefix}Tutorials']!,
              code: lesson.code,
              expectedOutput: lesson.output,
              fixtures: fixturesByLesson[lesson.id] ?? const {},
            ),
          );
          if (corpus == 'current') {
            final matching = pairs[lesson.id] ?? const [];
            if (matching.length != 1) {
              issues.add('current lesson ${lesson.id} requires one example');
            } else if (matching.single.code != lesson.code ||
                matching.single.expectedOutput != lesson.output) {
              issues.add('current pair differs at ${lesson.id}');
            }
          }
        }
      }
      for (final example in examples) {
        cases.add(
          LuaCatalogAuditCase(
            corpus: corpus,
            kind: 'example',
            id: example.id,
            asset: luaAuditAssets['${prefix}Examples']!,
            code: example.code,
            expectedOutput: example.expectedOutput,
            fixtures: example.inputFixtures,
            lessonId: example.sourceLessonId,
          ),
        );
      }
      counts['${corpus}Tutorials'] = tutorials.length;
      counts['${corpus}Lessons'] = lessonCount;
      counts['${corpus}Examples'] = examples.length;
    }

    addCatalog(current, 'current', 'current');
    addCatalog(original, 'original', 'original');
    var legacyCount = 0;
    for (final tutorial in legacy.tutorials.where(isLua)) {
      for (final lesson in tutorial.lessons) {
        legacyCount++;
        cases.add(
          LuaCatalogAuditCase(
            corpus: 'legacy',
            kind: 'lesson',
            id: lesson.id,
            asset: luaAuditAssets['legacy']!,
            code: lesson.code,
            expectedOutput: lesson.output,
          ),
        );
      }
    }
    counts['legacyLessons'] = legacyCount;
    for (final expected in {
      'currentLessons': expectedTopics,
      'currentExamples': expectedTopics,
      'originalLessons': expectedOriginalTopics,
      'originalExamples': expectedOriginalTopics,
      'legacyLessons': expectedLegacyLessons,
    }.entries) {
      if (counts[expected.key] != expected.value) {
        issues.add(
          '${expected.key}: expected ${expected.value}, got ${counts[expected.key]}',
        );
      }
    }
    final identities = <String>{};
    for (final item in cases) {
      if (item.id.isEmpty || !identities.add('${item.asset}#${item.id}')) {
        issues.add(
          'missing or duplicate snippet identity: ${item.asset}#${item.id}',
        );
      }
      if (item.code.trim().isEmpty) issues.add('empty source: ${item.id}');
      final fixtureTargets = <String>{};
      for (final key in item.fixtures.keys) {
        final target = key == 'stdin' ? 'input.txt' : key;
        if (!_safeFixture(target) || !fixtureTargets.add(p.normalize(target))) {
          issues.add('unsafe or colliding fixture $key in ${item.id}');
        }
      }
    }
    final currentExamples = cases.where(
      (item) => item.corpus == 'current' && item.kind == 'example',
    );
    final currentLessons = {
      for (final item in cases)
        if (item.corpus == 'current' && item.kind == 'lesson') item.id,
    };
    for (final example in currentExamples) {
      if (!currentLessons.contains(example.lessonId)) {
        issues.add('unpaired current example: ${example.id}');
      }
    }
    return LuaCatalogAuditInventory._(
      List.unmodifiable(cases),
      List.unmodifiable(issues),
      Map.unmodifiable(counts),
    );
  }

  Map<String, Object?> toJson() => {
    'counts': counts,
    'totalSnippetLocations': cases.length,
    'issues': issues,
    'executionPolicy': 'every location independently; no payload deduplication',
  };
}

bool _safeFixture(String path) {
  if (path.isEmpty || path.contains('\u0000') || p.isAbsolute(path)) {
    return false;
  }
  final normalized = p.normalize(path);
  return normalized != 'main.lua' &&
      normalized != '.' &&
      normalized != '..' &&
      !p.split(normalized).contains('..');
}

/// Reads the exact assets from this built application, including the still
/// bundled shared/legacy Lua documents. Missing assets fail instead of skipping.
Future<Map<String, Object?>> auditBundledLuaCatalog({
  required Directory workspace,
  required File reportFile,
  AssetBundle? bundle,
  LuaToolchain toolchain = const LuaToolchain(),
  void Function(int completed, int total, String item)? onProgress,
}) async {
  final assetBundle = bundle ?? rootBundle;
  final sources = <String, String>{};
  final identities = <String, Object?>{};
  for (final asset in luaAuditAssets.entries) {
    final data = await assetBundle.load(asset.value);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    sources[asset.key] = utf8.decode(bytes);
    identities[asset.key] = {
      'key': asset.value,
      'bytes': bytes.length,
      'sha256': _bytesSha256(bytes),
    };
  }
  return runLuaCatalogAudit(
    inventory: LuaCatalogAuditInventory.fromSources(sources),
    workspace: workspace,
    reportFile: reportFile,
    toolchain: toolchain,
    assetIdentities: identities,
    onProgress: onProgress,
  );
}

/// Runs only in the caller's dedicated audit workspace. The entrypoint obtains
/// that workspace from AppPrivateRoots; tests supply a throwaway private root.
/// Reports are flushed after every case, so interrupted target runs retain
/// direct evidence of precisely how much work actually finished.
Future<Map<String, Object?>> runLuaCatalogAudit({
  required LuaCatalogAuditInventory inventory,
  required Directory workspace,
  required File reportFile,
  LuaToolchain toolchain = const LuaToolchain(),
  Map<String, Object?> assetIdentities = const {},
  Duration timeLimit = const Duration(seconds: 15),
  void Function(int completed, int total, String item)? onProgress,
}) async {
  final observations = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'schemaVersion': 1,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'executionComplete': false,
    'ok': false,
    'deviceGatePassed': false,
    'comparison': 'exact stdout and expected status; stderr retained verbatim',
    'legacyCompatibilityComparison':
        'remove one final LF or CRLF only; never used for strict acceptance',
    'assets': assetIdentities,
    'inventory': inventory.toJson(),
    'environment': {
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'abi': Abi.current().toString(),
      'isOhosDeviceEvidence': Platform.operatingSystem == 'ohos',
    },
    'caseResults': observations,
    'reportPath': reportFile.path,
    'workspace': workspace.path,
  };
  Future<void> persist() => _persistReport(reportFile, report);
  await workspace.create(recursive: true);
  await persist();
  var runtimeVerified = false;
  try {
    final version = toolchain.version();
    report['runtime'] = {
      'version': version,
      'expectedVersion': 'Lua 5.4.8',
      'matchesExpectedVersion': version == 'Lua 5.4.8',
      'librarySelection':
          toolchain.libraryPath ?? 'normal packaged library lookup',
    };
    runtimeVerified = version == 'Lua 5.4.8';
  } catch (error, stack) {
    report['runtime'] = {'error': '$error', 'stack': '$stack'};
  }
  await persist();

  var aborted = false;
  for (final (index, item) in inventory.cases.indexed) {
    Map<String, Object?> observation;
    if (aborted) {
      observation = {
        ...item.toJson(),
        'attempted': false,
        'passed': false,
        'status': null,
        'stdout': null,
        'stderr': null,
        'executionFinished': false,
        'reason': 'not_run_after_unfinished_native_execution',
      };
    } else {
      observation = await _runCase(
        item,
        workspace,
        index,
        toolchain,
        timeLimit,
      );
      aborted =
          observation['executionFinished'] != true &&
          observation['nativeExecutionPending'] == true;
    }
    observations.add(observation);
    report['completedCases'] = observations
        .where((row) => row['executionFinished'] == true)
        .length;
    await persist();
    onProgress?.call(index + 1, inventory.cases.length, item.id);
  }

  report['diagnosticsProbe'] = await runLuaDiagnosticsAudit(
    workspace: workspace,
    toolchain: toolchain,
  );
  final probe = report['diagnosticsProbe']! as Map<String, Object?>;
  final complete =
      !aborted && observations.every((row) => row['executionFinished'] == true);
  final current = observations
      .where((row) => row['corpus'] == 'current')
      .toList();
  final currentPassed =
      current.isNotEmpty && current.every((row) => row['passed'] == true);
  final allPassed =
      observations.isNotEmpty &&
      observations.every((row) => row['passed'] == true);
  final inventoryValid = inventory.issues.isEmpty;
  final probesPassed = probe['ok'] == true;
  final isOhos = Platform.operatingSystem == 'ohos';
  final ok =
      complete &&
      inventoryValid &&
      runtimeVerified &&
      allPassed &&
      probesPassed;
  final currentGate =
      complete &&
      inventoryValid &&
      runtimeVerified &&
      currentPassed &&
      probesPassed;
  report.addAll({
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'executionComplete': complete,
    'ok': ok,
    'allShippedExactGatePassed': ok,
    'currentCurriculumGatePassed': currentGate,
    'deviceGatePassed': ok && isOhos,
    'currentCurriculumDeviceGatePassed': currentGate && isOhos,
    'executedCases': observations
        .where((row) => row['executionFinished'] == true)
        .length,
    'passedCases': observations.where((row) => row['passed'] == true).length,
    'failedCases': observations.where((row) => row['passed'] != true).length,
    'corpora': {
      for (final corpus in ['current', 'original', 'legacy'])
        corpus: {
          'locations': observations
              .where((row) => row['corpus'] == corpus)
              .length,
          'executed': observations
              .where(
                (row) =>
                    row['corpus'] == corpus && row['executionFinished'] == true,
              )
              .length,
          'exactPassed': observations
              .where((row) => row['corpus'] == corpus && row['passed'] == true)
              .length,
          'terminalNewlineCompatible': observations
              .where(
                (row) =>
                    row['corpus'] == corpus &&
                    row['legacyTerminalNewlineMatch'] == true,
              )
              .length,
        },
    },
  });
  await persist();
  return report;
}

Future<Map<String, Object?>> _runCase(
  LuaCatalogAuditCase item,
  Directory workspace,
  int index,
  LuaToolchain toolchain,
  Duration timeLimit,
) async {
  final observation = <String, Object?>{
    ...item.toJson(),
    'attempted': true,
    'passed': false,
    'status': null,
    'stdout': null,
    'stderr': null,
  };
  Directory? project;
  var launched = false;
  var receivedResult = false;
  var finished = true;
  final watch = Stopwatch()..start();
  try {
    project = await workspace.createTemp('case-$index-');
    for (final fixture in item.fixtures.entries) {
      final relative = fixture.key == 'stdin' ? 'input.txt' : fixture.key;
      if (!_safeFixture(relative)) {
        throw FormatException('Unsafe fixture: $relative');
      }
      final targetPath = p.normalize(p.join(project.path, relative));
      if (!p.isWithin(project.path, targetPath)) {
        throw FormatException('Fixture leaves its audit project: $relative');
      }
      final file = File(targetPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(fixture.value, flush: true);
    }
    final entry = File(p.join(project.path, 'main.lua'));
    await entry.writeAsString(item.code, flush: true);
    final execution = toolchain.startRun(
      file: entry.path,
      projectDirectory: project.path,
      timeLimit: timeLimit,
    );
    launched = true;
    finished = false;
    final pending = execution.result.whenComplete(() => finished = true);
    LuaToolResult result;
    try {
      result = await pending.timeout(timeLimit + const Duration(seconds: 10));
    } on TimeoutException {
      await execution.cancel();
      observation['watchdogCancellationRequested'] = true;
      result = await pending.timeout(const Duration(seconds: 5));
    }
    receivedResult = true;
    observation.addAll({
      'status': result.status,
      'stdout': result.output,
      'stderr': result.error,
      'actualOutputSha256': OfflineDigest.sha256(result.output),
      'exactOutputMatch': result.output == item.expectedOutput,
      'statusMatch': result.status == item.expectedStatus,
      'legacyTerminalNewlineMatch':
          result.status == item.expectedStatus &&
          _oneFinalNewline(result.output) ==
              _oneFinalNewline(item.expectedOutput),
      'passed':
          item.matches(result) &&
          observation['watchdogCancellationRequested'] != true,
    });
  } catch (error, stack) {
    observation.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    observation['workerStarted'] = launched;
    observation['workerFinished'] = !launched || finished;
    observation['executionFinished'] = receivedResult && finished;
    observation['elapsedMilliseconds'] = watch.elapsedMilliseconds;
    if (project != null) {
      if (finished) {
        try {
          await project.delete(recursive: true);
          observation['projectRemoved'] = true;
        } catch (error) {
          observation['projectCleanupError'] = '$error';
        }
      } else {
        // Cancellation is cooperative. Do not remove source files while a
        // native worker may still use them or start another native run.
        observation['nativeExecutionPending'] = true;
        observation['retainedProjectPath'] = project.path;
      }
    }
  }
  return observation;
}

String _oneFinalNewline(String value) => value.endsWith('\r\n')
    ? value.substring(0, value.length - 2)
    : value.endsWith('\n')
    ? value.substring(0, value.length - 1)
    : value;

String _bytesSha256(List<int> bytes) => OfflineDigest.sha256Bytes(
  bytes,
).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Future<void> _persistReport(
  File destination,
  Map<String, Object?> report,
) async {
  await destination.parent.create(recursive: true);
  final pending = File('${destination.path}.next');
  try {
    await pending.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
      flush: true,
    );
    await pending.rename(destination.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

/// Target probe for the real unsaved-buffer adapter, independent of editor UI.
/// Both files have intentionally different disk and dirty-buffer contents.
/// The corrected snapshots would mutate/delete files if executed; loading them
/// must only parse. Shared-core debounce/stale-result UI behavior is a separate
/// workflow-test gate and is not claimed by this probe.
Future<Map<String, Object?>> runLuaDiagnosticsAudit({
  required Directory workspace,
  LuaToolchain toolchain = const LuaToolchain(),
}) async {
  final checks = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'ok': false,
    'provider': 'LuaCodeAnalyzer using the bundled native source parser',
    'scope':
        'two dirty snapshots, exact UTF-16 ranges, correction, no execution or source writes',
    'checks': checks,
    'requestedWorkspacePath': workspace.path,
    'coreStaleResponseAndUiGate':
        'separate shared-core workflow tests required',
  };
  Directory? project;
  try {
    final created = await workspace.createTemp('diagnostics-中文😀-');
    project = created;
    // Callers may retain mixed separators. Canonicalize our owned directory
    // before constructing requests so exact diagnostic path equality remains
    // meaningful instead of comparing two spellings of the same file.
    project = Directory(p.normalize(await created.resolveSymbolicLinks()));
    report['canonicalProjectPath'] = project.path;
    final active = File(p.join(project.path, '主程序.lua'));
    final module = File(p.join(project.path, '模块.lua'));
    const activeDisk = 'local = "active disk remains malformed"\r\n';
    const moduleDisk = 'local = "module disk remains malformed"\r\n';
    await active.writeAsString(activeDisk, flush: true);
    await module.writeAsString(moduleDisk, flush: true);
    final before = {
      active.path: _bytesSha256(await active.readAsBytes()),
      module.path: _bytesSha256(await module.readAsBytes()),
    };
    final activeMarker = File(p.join(project.path, 'active-must-not-run.txt'));
    final moduleMarker = File(p.join(project.path, 'module-must-not-run.txt'));
    const badActive = '-- 中文😀\r\nlocal = 1\r\n';
    const badModule = '-- 模块🌍\r\nlocal = 2\r\n';
    final fixedActive =
        'local text = "中文😀"\r\n'
        'local f = assert(io.open(${jsonEncode(activeMarker.path)}, "w"))\r\n'
        'f:write(text)\r\nf:close()\r\n'
        'os.remove(${jsonEncode(active.path)})\r\n'
        'require("audit_missing_module_must_not_load")\r\n'
        'error("analysis must never execute this code")\r\n';
    final fixedModule =
        'local text = "模块🌍"\r\n'
        'local f = assert(io.open(${jsonEncode(moduleMarker.path)}, "w"))\r\n'
        'f:write(text)\r\nf:close()\r\nreturn text\r\n';
    final analyzer = LuaCodeAnalyzer(toolchain: toolchain);

    Future<void> analyze({
      required String id,
      required String file,
      required String text,
      required int revision,
      required List<CodeDocumentSnapshot> snapshots,
      required bool expectError,
    }) async {
      final result = await analyzer.analyze(
        CodeAnalysisRequest(
          projectPath: project!.path,
          activeFilePath: file,
          language: 'Lua',
          revision: revision,
          documents: snapshots,
        ),
      );
      final expectedStart = text.indexOf('=');
      final exactError =
          result.diagnostics.length == 1 &&
          result.diagnostics.single.filePath == file &&
          result.diagnostics.single.startOffset == expectedStart &&
          result.diagnostics.single.endOffset == expectedStart + 1;
      checks.add({
        'id': id,
        'passed':
            result.unavailableReason == null &&
            (expectError ? exactError : result.diagnostics.isEmpty),
        'activeFile': file,
        'revision': revision,
        'sourceSha256': OfflineDigest.sha256(text),
        'source': text,
        'expectedError': expectError,
        if (expectError) 'expectedRange': [expectedStart, expectedStart + 1],
        'snapshotRevisions': {
          for (final snapshot in snapshots) snapshot.path: snapshot.revision,
        },
        'snapshots': [
          for (final snapshot in snapshots)
            {
              'path': snapshot.path,
              'revision': snapshot.revision,
              'source': snapshot.text,
              'sourceSha256': OfflineDigest.sha256(snapshot.text),
            },
        ],
        'unavailableReason': result.unavailableReason,
        'diagnostics': [
          for (final diagnostic in result.diagnostics)
            {
              'filePath': diagnostic.filePath,
              'startOffset': diagnostic.startOffset,
              'endOffset': diagnostic.endOffset,
              'message': diagnostic.message,
              'source': diagnostic.source,
              'code': diagnostic.code,
            },
        ],
      });
    }

    final badSnapshots = [
      CodeDocumentSnapshot(path: active.path, text: badActive, revision: 101),
      CodeDocumentSnapshot(path: module.path, text: badModule, revision: 201),
    ];
    await analyze(
      id: 'dirty-active-crlf-unicode-error-range',
      file: active.path,
      text: badActive,
      revision: 101,
      snapshots: badSnapshots,
      expectError: true,
    );
    await analyze(
      id: 'dirty-module-crlf-unicode-error-range',
      file: module.path,
      text: badModule,
      revision: 201,
      snapshots: badSnapshots,
      expectError: true,
    );
    final fixedSnapshots = [
      CodeDocumentSnapshot(path: active.path, text: fixedActive, revision: 102),
      CodeDocumentSnapshot(path: module.path, text: fixedModule, revision: 202),
    ];
    await analyze(
      id: 'corrected-active-unsaved-clean',
      file: active.path,
      text: fixedActive,
      revision: 102,
      snapshots: fixedSnapshots,
      expectError: false,
    );
    await analyze(
      id: 'corrected-module-unsaved-clean',
      file: module.path,
      text: fixedModule,
      revision: 202,
      snapshots: fixedSnapshots,
      expectError: false,
    );
    final after = {
      active.path: await active.exists()
          ? _bytesSha256(await active.readAsBytes())
          : null,
      module.path: await module.exists()
          ? _bytesSha256(await module.readAsBytes())
          : null,
    };
    checks.add({
      'id': 'source-files-not-written-or-deleted',
      'passed': before.entries.every(
        (entry) => after[entry.key] == entry.value,
      ),
      'beforeSha256': before,
      'afterSha256': after,
    });
    final activeRan = await activeMarker.exists();
    final moduleRan = await moduleMarker.exists();
    checks.add({
      'id': 'source-side-effects-not-executed',
      'passed': !activeRan && !moduleRan,
      'activeMarkerExists': activeRan,
      'moduleMarkerExists': moduleRan,
    });
    report['ok'] =
        checks.length == 6 && checks.every((check) => check['passed'] == true);
  } catch (error, stack) {
    report.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    if (project != null) {
      try {
        await project.delete(recursive: true);
        report['projectRemoved'] = true;
      } catch (error) {
        report['projectCleanupError'] = '$error';
      }
    }
  }
  return report;
}

class LuaCatalogAuditPage extends StatefulWidget {
  const LuaCatalogAuditPage({super.key});

  @override
  State<LuaCatalogAuditPage> createState() => _LuaCatalogAuditPageState();
}

class _LuaCatalogAuditPageState extends State<LuaCatalogAuditPage> {
  String _status = 'Preparing packaged Lua audit…';
  String? _reportPath;
  double? _progress;
  Map<String, Object?>? _summary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    File? reportFile;
    try {
      final storage = await AppPaths.storageDirectory();
      if (storage == null) throw StateError('App-owned storage is unavailable');
      await AppPrivateRoots.resolve(storage);
      reportFile = File(p.join(storage, 'qfli-lua-catalog-audit.json'));
      final runs = Directory(p.join(storage, 'qfli-lua-catalog-audit-runs'));
      await runs.create(recursive: true);
      final workspace = await runs.createTemp('run-');
      if (mounted) setState(() => _reportPath = reportFile!.path);
      await _persistReport(reportFile, {
        'schemaVersion': 1,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'executionComplete': false,
        'ok': false,
        'deviceGatePassed': false,
        'phase': 'loading-package-assets',
        'workspace': workspace.path,
      });
      final report = await auditBundledLuaCatalog(
        workspace: workspace,
        reportFile: reportFile,
        onProgress: (completed, total, item) {
          if (!mounted) return;
          setState(() {
            _progress = total == 0 ? 0 : completed / total;
            _status = '$completed / $total  $item';
          });
        },
      );
      final summary = <String, Object?>{
        'finished': true,
        'executionComplete': report['executionComplete'],
        'allShippedExactGatePassed': report['allShippedExactGatePassed'],
        'currentCurriculumGatePassed': report['currentCurriculumGatePassed'],
        'deviceGatePassed': report['deviceGatePassed'],
        'currentCurriculumDeviceGatePassed':
            report['currentCurriculumDeviceGatePassed'],
        'executedCases': report['executedCases'],
        'passedCases': report['passedCases'],
        'failedCases': report['failedCases'],
        'diagnosticsProbePassed': (report['diagnosticsProbe'] as Map)['ok'],
        'operatingSystem': Platform.operatingSystem,
        'abi': Abi.current().toString(),
        'report': reportFile.path,
        'reportSha256': _bytesSha256(await reportFile.readAsBytes()),
      };
      debugPrint('QFLI_LUA_CATALOG_AUDIT ${jsonEncode(summary)}');
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'QFLI_LUA_CATALOG_AUDIT FINISHED';
        _summary = summary;
      });
    } catch (error, stack) {
      final failure = <String, Object?>{
        'finished': true,
        'executionComplete': false,
        'ok': false,
        'deviceGatePassed': false,
        'operatingSystem': Platform.operatingSystem,
        'error': '$error',
        'stack': '$stack',
        'report': reportFile?.path,
      };
      if (reportFile != null) {
        try {
          final checkpoint = await reportFile.exists()
              ? (jsonDecode(await reportFile.readAsString()) as Map)
                    .cast<String, Object?>()
              : <String, Object?>{};
          await _persistReport(reportFile, {
            ...checkpoint,
            'executionComplete': false,
            'ok': false,
            'deviceGatePassed': false,
            'fatalFailure': failure,
          });
        } catch (persistenceError) {
          failure['reportWriteError'] = '$persistenceError';
        }
      }
      debugPrint('QFLI_LUA_CATALOG_AUDIT ${jsonEncode(failure)}');
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'QFLI_LUA_CATALOG_AUDIT FAILED';
        _summary = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lua packaged-content audit')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(_status),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 16),
          if (_reportPath != null) SelectableText('Report: $_reportPath'),
          if (_summary != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(_summary),
            ),
          ],
        ],
      ),
    ),
  );
}
