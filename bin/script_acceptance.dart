/// Full packaged Script acceptance. Build with -t bin/script_acceptance.dart.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_debugger.dart';
import 'package:qfli_lua/lua_studio_debugger.dart';
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_lua/script_code_analyzer.dart';
import 'package:qfli_lua/script_toolchain.dart';
import 'package:qfli_lua/shell_code_analyzer.dart';
import 'package:qfli_studio_core/content/content_repository.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/app_private_roots.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';
import 'package:qfli_studio_core/services/debug_session.dart';
import 'package:qfli_studio_core/tools/offline_tools.dart';

import 'lua_catalog_audit.dart' as lua_audit;
import 'script_report_export.dart';

const scriptAcceptanceAssets = {
  'tutorials': 'packages/qfli_studio_core/assets/content/tutorials.json',
  'examples': 'packages/qfli_studio_core/assets/content/examples.json',
};
const scriptAcceptanceExpectedLocations = 1282;
const _scriptLanguages = ['javascript', 'typescript', 'shell'];
const _compilerSha256 =
    '3ae902c92cc44dace175c0e69e13a4b0899f6983c6121d76b9ab8dd5795e7675';

typedef ScriptPlatformCall =
    Future<Object?> Function(String method, Object? arguments);

/// Checks the real OHOS bridge; injected calls are test evidence only.
Future<Map<String, Object?>> runScriptOfflinePlatformProbe({
  String? operatingSystem,
  ScriptPlatformCall? invokePlatform,
  Duration callTimeout = const Duration(seconds: 2),
}) async {
  if (callTimeout <= Duration.zero) {
    throw ArgumentError.value(callTimeout, 'callTimeout', 'Must be positive');
  }
  final system = operatingSystem ?? Platform.operatingSystem;
  final injected = operatingSystem != null || invokePlatform != null;
  final checks = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'ok': false,
    'evaluated': false,
    'status': 'not_evaluated',
    'nativeEvidence': false,
    'evidenceKind': 'not_evaluated',
    'operatingSystem': system,
    'channel': 'qflistudio/platform',
    'requiredErrorCode': 'OFFLINE_ONLY',
    'callTimeoutMilliseconds': callTimeout.inMilliseconds,
    'checks': checks,
  };
  if (system != 'ohos') {
    report['reason'] =
        'OHOS native platform bridge is not evaluated on this host';
    return report;
  }
  const channel = MethodChannel('qflistudio/platform');
  final ScriptPlatformCall call =
      invokePlatform ??
      (method, arguments) => channel.invokeMethod<Object?>(method, arguments);
  final vectors = <(String, Object?)>[
    (
      'https',
      {
        'url': 'https://example.com/qfli-offline-probe',
        'title': 'Offline probe',
      },
    ),
    ('http', {'url': 'http://example.com/qfli-offline-probe'}),
    ('network-path', {'url': '//example.com/qfli-offline-probe'}),
    ('mailto', {'url': 'mailto:offline-probe@example.com'}),
    ('tel', {'url': 'tel:+10000000000'}),
    ('custom-scheme', {'url': 'qfli-offline-probe://rejected'}),
    ('javascript', {'url': 'javascript:void(0)'}),
    ('file', {'url': 'file:///qfli-offline-probe.txt'}),
    ('data', {'url': 'data:text/plain,qfli-offline-probe'}),
    ('malformed-url', {'url': '://'}),
    ('missing-arguments', null),
    ('missing-url', <String, Object?>{}),
    ('wrong-url-type', {'url': 42}),
    ('wrong-arguments-type', 42),
  ];
  report.addAll({
    'evaluated': true,
    'status': 'failed',
    'evidenceKind': injected ? 'injected' : 'native_channel',
    'expectedChecks': 2 * vectors.length,
  });
  for (final method in ['openAgreement', 'openUrl']) {
    for (final (id, arguments) in vectors) {
      final check = <String, Object?>{
        'method': method,
        'vector': id,
        'arguments': arguments,
        'passed': false,
      };
      try {
        final result = await call(method, arguments).timeout(callTimeout);
        check.addAll({'outcome': 'unexpected_success', 'result': '$result'});
      } on PlatformException catch (error) {
        check.addAll({
          'outcome': 'platform_exception',
          'errorCode': error.code,
          'message': error.message,
          'passed': error.code == 'OFFLINE_ONLY',
        });
      } on MissingPluginException catch (error) {
        check.addAll({'outcome': 'not_implemented', 'error': '$error'});
      } on TimeoutException catch (error) {
        check.addAll({'outcome': 'timeout', 'error': '$error'});
      } catch (error) {
        check.addAll({'outcome': 'error', 'error': '$error'});
      }
      checks.add(check);
    }
  }
  final passed =
      checks.length == 2 * vectors.length &&
      checks.every((check) => check['passed'] == true);
  report.addAll({
    'ok': passed,
    'status': passed ? 'passed' : 'failed',
    'nativeEvidence': passed && !injected && Platform.operatingSystem == 'ohos',
  });
  return report;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: ScriptAcceptancePage()));
}

class ScriptAcceptanceCase {
  const ScriptAcceptanceCase({
    required this.language,
    required this.kind,
    required this.id,
    required this.asset,
    required this.source,
    required this.expectedOutput,
    this.fixtures = const {},
    this.fixtureOrigin = 'entry',
    this.expectedStatus = 0,
  });
  final String language, kind, id, asset, source, expectedOutput, fixtureOrigin;
  final Map<String, String> fixtures;
  final int expectedStatus;
  String get entryName =>
      'main.${switch (language) {
        'javascript' => 'js',
        'typescript' => 'ts',
        'shell' => 'sh',
        _ => throw ArgumentError('Unsupported Script language: $language'),
      }}';
  Map<String, Object?> toJson() => {
    'language': language,
    'corpus': 'original',
    'kind': kind,
    'id': id,
    'asset': asset,
    'source': source,
    'sourceSha256': OfflineDigest.sha256(source),
    'expectedOutput': expectedOutput,
    'expectedStatus': expectedStatus,
    'inputFixtures': fixtures,
    'fixtureOrigin': fixtureOrigin,
    'fixtureSha256': {
      for (final item in fixtures.entries)
        item.key: OfflineDigest.sha256(item.value),
    },
  };
}

/// Counts are independent of the documents: truncated assets cannot pass.
class ScriptAcceptanceInventory {
  ScriptAcceptanceInventory._(this.cases, this.counts, this.issues);
  final List<ScriptAcceptanceCase> cases;
  final Map<String, int> counts;
  final List<String> issues;

  factory ScriptAcceptanceInventory.fromSources(Map<String, String> sources) {
    final catalog = ContentCatalog.fromJson(
      tutorialsSource:
          sources['tutorials'] ??
          (throw const FormatException('Missing tutorials asset')),
      examplesSource:
          sources['examples'] ??
          (throw const FormatException('Missing examples asset')),
    );
    final cases = <ScriptAcceptanceCase>[];
    final counts = <String, int>{};
    final issues = <String>[];
    for (final language in _scriptLanguages) {
      final examples = catalog.examples
          .where((entry) => entry.type.trim().toLowerCase() == language)
          .toList();
      final pairs = <String, ExampleContent>{};
      for (final example in examples) {
        final lesson = example.sourceLessonId;
        if (lesson != null && pairs.containsKey(lesson)) {
          issues.add('Duplicate lesson fixture link: $language#$lesson');
        }
        if (lesson != null) pairs[lesson] = example;
        cases.add(
          ScriptAcceptanceCase(
            language: language,
            kind: 'example',
            id: example.id,
            asset: scriptAcceptanceAssets['examples']!,
            source: example.code,
            expectedOutput: example.expectedOutput,
            fixtures: example.inputFixtures,
          ),
        );
      }
      var lessons = 0;
      for (final tutorial in catalog.tutorials.where(
        (entry) => entry.type.trim().toLowerCase() == language,
      )) {
        for (final lesson in tutorial.lessons) {
          lessons++;
          final linked = pairs[lesson.id];
          final ownFixtures = lesson.inputFixtures.isNotEmpty;
          cases.add(
            ScriptAcceptanceCase(
              language: language,
              kind: 'lesson',
              id: lesson.id,
              asset: scriptAcceptanceAssets['tutorials']!,
              source: lesson.code,
              expectedOutput: lesson.output,
              fixtures: ownFixtures
                  ? lesson.inputFixtures
                  : linked?.inputFixtures ?? const {},
              fixtureOrigin: ownFixtures
                  ? 'lesson'
                  : linked == null
                  ? 'none'
                  : 'linked example ${linked.id}',
            ),
          );
        }
      }
      counts['${language}Examples'] = examples.length;
      counts['${language}Lessons'] = lessons;
      if (examples.length != 100) {
        issues.add('$language examples: expected100, got${examples.length}');
      }
      if (lessons != 100) {
        issues.add('$language lessons: expected100, got$lessons');
      }
    }
    final identities = <String>{};
    for (final item in cases) {
      if (item.id.isEmpty || !identities.add('${item.asset}#${item.id}')) {
        issues.add(
          'Missing or duplicate location identity: ${item.asset}#${item.id}',
        );
      }
      if (item.source.trim().isEmpty) issues.add('Empty source: ${item.id}');
      final targets = <String>{};
      for (final key in item.fixtures.keys) {
        final target = key == 'stdin' ? 'input.txt' : key;
        if (!_safeFixture(target, item.entryName) ||
            !targets.add(p.canonicalize(target))) {
          issues.add('Unsafe or colliding fixture: ${item.id}#$key');
        }
      }
    }
    if (cases.length != 600) {
      issues.add('Script locations: expected600, got${cases.length}');
    }
    return ScriptAcceptanceInventory._(
      List.unmodifiable(cases),
      Map.unmodifiable(counts),
      List.unmodifiable(issues),
    );
  }

  Map<String, Object?> toJson() => {
    'counts': counts,
    'issues': issues,
    'expectedLocations': 600,
    'locations': cases.length,
    'policy':
        'every location independently; identical payloads are not deduplicated',
  };
}

/// Matches terminal line rendering only. Never trims or drops empty lines.
bool scriptTerminalLinesMatch(String actual, String expected) {
  final a = const LineSplitter().convert(actual);
  final b = const LineSplitter().convert(expected);
  return a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
}

bool _safeFixture(String path, String entry) {
  if (path.isEmpty || path.contains('\u0000') || p.isAbsolute(path)) {
    return false;
  }
  final normalized = p.normalize(path);
  return normalized != '.' &&
      normalized != '..' &&
      !p.equals(normalized, entry) &&
      !p.split(normalized).contains('..');
}

String _hashBytes(List<int> bytes) => OfflineDigest.sha256Bytes(
  bytes,
).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Future<void> _persist(File file, Map<String, Object?> report) async {
  await file.parent.create(recursive: true);
  final pending = File('${file.path}.next');
  try {
    await pending.writeAsString('${jsonEncode(report)}\n', flush: true);
    await pending.rename(file.path);
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

/// Small callers may pass a fixture list. Only the full bundled entry applies
/// the independent1282 coverage gate; this function never claims that gate.
Future<Map<String, Object?>> runScriptContentAudit({
  required List<ScriptAcceptanceCase> cases,
  required Directory workspace,
  required File reportFile,
  ScriptToolchain toolchain = const ScriptToolchain(),
  String? shellPath,
  Map<String, Object?> runtimeIdentities = const {},
  Duration timeLimit = const Duration(seconds: 15),
  void Function(int completed, int total, String id)? onProgress,
}) async {
  await workspace.create(recursive: true);
  final journal = File('${reportFile.path}.cases.jsonl');
  await journal.parent.create(recursive: true);
  await journal.writeAsString('', flush: true);
  final rows = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'scope': 'supplied JS/TS/Shell cases',
    'expectedCases': cases.length,
    'executionComplete': false,
    'ok': false,
    'caseJournal': journal.path,
    'completedCases': 0,
    'caseResults': rows,
  };
  await _persist(reportFile, report);
  var nativePending = false;
  for (final (index, item) in cases.indexed) {
    final row = nativePending
        ? <String, Object?>{
            ...item.toJson(),
            'attempted': false,
            'executionFinished': false,
            'passed': false,
            'reason': 'not_run_after_unfinished_native_execution',
          }
        : await _runScriptCase(
            item,
            workspace,
            index,
            toolchain,
            shellPath,
            timeLimit,
          );
    row['runtime'] =
        runtimeIdentities[item.language == 'shell' ? 'shell' : 'script'];
    nativePending = nativePending || row['nativeExecutionPending'] == true;
    rows.add(row);
    await journal.writeAsString(
      '${jsonEncode(row)}\n',
      mode: FileMode.append,
      flush: true,
    );
    // The journal is authoritative per-case evidence; checkpoint a bounded
    // summary instead of rewriting every previous source after every snippet.
    await _persist(reportFile, {
      ...report,
      'caseResults': null,
      'completedCases': rows
          .where((row) => row['executionFinished'] == true)
          .length,
      'lastCase': item.id,
      'nativeExecutionPending': nativePending,
    });
    onProgress?.call(index + 1, cases.length, item.id);
  }
  report.addAll({
    'executionComplete':
        !nativePending && rows.every((row) => row['executionFinished'] == true),
    'completedCases': rows
        .where((row) => row['executionFinished'] == true)
        .length,
    'ok': cases.isNotEmpty && rows.every((row) => row['passed'] == true),
    'exactPassedCases': rows.where((row) => row['passed'] == true).length,
    'terminalLinePassedCases': rows
        .where((row) => row['terminalLinePassed'] == true)
        .length,
  });
  await _persist(reportFile, report);
  return report;
}

Future<Map<String, Object?>> _runScriptCase(
  ScriptAcceptanceCase item,
  Directory workspace,
  int index,
  ScriptToolchain toolchain,
  String? shell,
  Duration limit,
) async {
  final row = <String, Object?>{
    ...item.toJson(),
    'attempted': true,
    'executionFinished': false,
    'passed': false,
  };
  Directory? project;
  var finished = true;
  final watch = Stopwatch()..start();
  try {
    project = await workspace.createTemp('script-case-$index-');
    for (final fixture in item.fixtures.entries) {
      final relative = fixture.key == 'stdin' ? 'input.txt' : fixture.key;
      if (!_safeFixture(relative, item.entryName)) {
        throw FormatException('Unsafe fixture: $relative');
      }
      final target = File(p.normalize(p.join(project.path, relative)));
      if (!p.isWithin(project.path, target.path)) {
        throw FormatException('Fixture escapes project: $relative');
      }
      await target.parent.create(recursive: true);
      await target.writeAsString(fixture.value, flush: true);
    }
    final file = File(p.join(project.path, item.entryName));
    await file.writeAsString(item.source, flush: true);
    row['writtenSourceSha256'] = _hashBytes(await file.readAsBytes());
    ScriptToolResult result;
    if (item.language == 'shell') {
      result = shell == null
          ? const ScriptToolResult(
              status: 127,
              error: 'No actual local POSIX shell found',
            )
          : await _runShell(
              shell,
              file.path,
              project.path,
              item.fixtures['stdin'] ?? '',
              limit,
              row,
            );
    } else {
      final execution = toolchain.startRun(
        file: file.path,
        projectDirectory: project.path,
        timeLimit: limit,
      );
      finished = false;
      final pending = execution.result.whenComplete(() => finished = true);
      try {
        result = await pending.timeout(limit + const Duration(seconds: 10));
      } on TimeoutException {
        row['watchdogCancellationRequested'] = true;
        await execution.cancel();
        result = await pending.timeout(const Duration(seconds: 5));
      }
    }
    final statusMatch = result.status == item.expectedStatus;
    final exact = result.output == item.expectedOutput;
    final lines = scriptTerminalLinesMatch(result.output, item.expectedOutput);
    row.addAll({
      'status': result.status,
      'stdout': result.output,
      'stderr': result.error,
      'actualOutputSha256': OfflineDigest.sha256(result.output),
      'exactOutputMatch': exact,
      'terminalLinesMatch': lines,
      'statusMatch': statusMatch,
      'passed':
          exact && statusMatch && row['watchdogCancellationRequested'] != true,
      'terminalLinePassed':
          lines && statusMatch && row['watchdogCancellationRequested'] != true,
      'executionFinished': true,
      'runtimeStarted': item.language == 'shell'
          ? shell != null
          : result.status != 127,
    });
  } catch (error, stack) {
    if (error is _UnfinishedShell) finished = false;
    row.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    row['elapsedMilliseconds'] = watch.elapsedMilliseconds;
    if (project != null && finished) {
      try {
        await project.delete(recursive: true);
        row['projectRemoved'] = true;
      } catch (error) {
        row['cleanupError'] = '$error';
      }
    } else if (project != null) {
      row.addAll({
        'nativeExecutionPending': true,
        'retainedProjectPath': project.path,
      });
    }
  }
  return row;
}

class _UnfinishedShell implements Exception {
  const _UnfinishedShell(this.pid);
  final int pid;
  @override
  String toString() =>
      'Shell process/streams did not finish after cancellation (pid $pid)';
}

Future<ScriptToolResult> _runShell(
  String shell,
  String file,
  String project,
  String input,
  Duration limit,
  Map<String, Object?> observation,
) async {
  final process = await Process.start(shell, [file], workingDirectory: project);
  final stdout = BytesBuilder(copy: false), stderr = BytesBuilder(copy: false);
  var statusOverride = 0;
  void collect(BytesBuilder target, List<int> bytes) {
    final remaining = 1024 * 1024 - target.length;
    target.add(bytes.take(remaining).toList());
    if (bytes.length > remaining) {
      statusOverride = 1;
      observation['outputTruncated'] = true;
      process.kill();
    }
  }

  final outSubscription = process.stdout.listen(
    (bytes) => collect(stdout, bytes),
  );
  final errSubscription = process.stderr.listen(
    (bytes) => collect(stderr, bytes),
  );
  final outDone = outSubscription.asFuture<void>();
  final errDone = errSubscription.asFuture<void>();
  final timer = Timer(limit, () {
    statusOverride = 124;
    observation['watchdogCancellationRequested'] = true;
    process.kill();
  });
  try {
    process.stdin.add(utf8.encode(input));
    await process.stdin.close().timeout(limit + const Duration(seconds: 5));
    final status = await process.exitCode.timeout(
      limit + const Duration(seconds: 5),
    );
    await Future.wait([outDone, errDone]).timeout(const Duration(seconds: 5));
    return ScriptToolResult(
      status: statusOverride == 0 ? status : statusOverride,
      output: utf8.decode(stdout.takeBytes(), allowMalformed: true),
      error: utf8.decode(stderr.takeBytes(), allowMalformed: true),
    );
  } on TimeoutException {
    process.kill();
    await outSubscription.cancel();
    await errSubscription.cancel();
    throw _UnfinishedShell(process.pid);
  } finally {
    timer.cancel();
  }
}

Future<Map<String, Object?>> _binaryIdentity(
  String name,
  String? explicit, {
  bool script = false,
}) async {
  final suffix = Platform.isWindows
      ? 'dll'
      : Platform.isMacOS
      ? 'dylib'
      : 'so';
  final basename = 'libqfli_$name.$suffix';
  final candidates = <String>[];
  if (explicit != null) {
    candidates.add(explicit);
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final executable = p.dirname(Platform.resolvedExecutable);
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isLinux
        ? 'linux'
        : 'macos';
    candidates.addAll([
      p.join(executable, basename),
      p.join(executable, 'lib', basename),
      p.join(Directory.current.path, 'native', 'build', platform, basename),
      if (script)
        p.join(
          Directory.current.path,
          'native',
          'build',
          'script-$platform',
          'script',
          basename,
        ),
    ]);
  }
  // Self maps identify the actual loaded package library on OHOS/Android/Linux.
  if (!Platform.isWindows) {
    try {
      for (final line in await File('/proc/self/maps').readAsLines()) {
        final pathStart = line.indexOf('/');
        if (pathStart >= 0) {
          final mapped = line.substring(pathStart);
          if (p.basename(mapped) == basename) candidates.add(mapped);
        }
      }
    } catch (_) {
      /* Identity remains explicitly unavailable when inaccessible. */
    }
  }
  for (final path in candidates) {
    try {
      final file = File(path);
      if (await file.exists()) {
        return {
          'path': p.normalize(p.absolute(path)),
          'sha256': _hashBytes(await file.readAsBytes()),
          'selection': explicit == null
              ? 'adapter candidate or self mapping'
              : 'explicit',
        };
      }
    } catch (_) {
      /* Try another actual mapped/selected file. */
    }
  }
  return {
    'sha256': null,
    'unavailableReason': 'Loaded library file path/hash unavailable',
    'libraryName': basename,
    'selection': explicit ?? 'normal packaged lookup',
  };
}

/// Full1282 entry; component runners below can also be used for small fixtures.
Future<Map<String, Object?>> auditBundledScriptAcceptance({
  required Directory workspace,
  required File reportFile,
  AssetBundle? bundle,
  LuaToolchain luaToolchain = const LuaToolchain(),
  ScriptToolchain scriptToolchain = const ScriptToolchain(),
  Map<String, Object?> additionalDomainReports = const {},
  void Function(int completed, int total, String id)? onProgress,
}) async {
  await workspace.create(recursive: true);
  final assets = bundle ?? rootBundle;
  final report = <String, Object?>{
    'schemaVersion': 1,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'executionComplete': false,
    'ok': false,
    'deviceGatePassed': false,
    'terminalLineDeviceGatePassed': false,
    'offlinePlatformGatePassed': false,
    'expectedLocations': scriptAcceptanceExpectedLocations,
    'reportPath': reportFile.path,
    'workspace': workspace.path,
    'environment': {
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'abi': Abi.current().toString(),
      'isOhosDeviceEvidence': Platform.operatingSystem == 'ohos',
    },
    'comparisonPolicy': {
      'strict': 'exact stdout and expected status',
      'terminal':
          'LineSplitter lists with identical line count/content; no trimming or blank-line removal',
      'current480Lua': 'exact stdout required for both gates',
    },
    'additionalDomainReports': additionalDomainReports,
    'additionalDomainReportsSupplied': additionalDomainReports.keys.toList(),
    'unprovidedDomains': 'not evaluated by this runtime acceptance entry',
  };
  await _persist(reportFile, report);
  final offlinePlatform = await runScriptOfflinePlatformProbe();
  final offlinePlatformGate =
      offlinePlatform['ok'] == true &&
      offlinePlatform['nativeEvidence'] == true;
  report.addAll({
    'offlinePlatformProbe': offlinePlatform,
    'offlinePlatformGatePassed': offlinePlatformGate,
  });
  await _persist(reportFile, report);
  final offlinePlatformSummary = <String, Object?>{
    for (final key in [
      'evaluated',
      'status',
      'ok',
      'nativeEvidence',
      'evidenceKind',
    ])
      key: offlinePlatform[key],
    'checks': (offlinePlatform['checks'] as List).length,
  };
  debugPrint(
    'QFLI_SCRIPT_OFFLINE_PLATFORM ${jsonEncode(offlinePlatformSummary)}',
  );
  final sources = <String, String>{};
  final assetIdentities = <String, Object?>{};
  for (final asset in {
    ...scriptAcceptanceAssets,
    'compiler': 'assets/runtime/typescript.js',
  }.entries) {
    final data = await assets.load(asset.value);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    assetIdentities[asset.key] = {
      'key': asset.value,
      'bytes': bytes.length,
      'sha256': _hashBytes(bytes),
    };
    if (asset.key != 'compiler') sources[asset.key] = utf8.decode(bytes);
  }
  final inventory = ScriptAcceptanceInventory.fromSources(sources);
  final runtime = <String, Object?>{};
  String? luaVersion, scriptVersion;
  try {
    luaVersion = luaToolchain.version();
  } catch (error) {
    runtime['luaLoadError'] = '$error';
  }
  try {
    scriptVersion = scriptToolchain.version();
  } catch (error) {
    runtime['scriptLoadError'] = '$error';
  }
  runtime['lua'] = {
    'version': luaVersion,
    'binary': await _binaryIdentity('lua', luaToolchain.libraryPath),
  };
  runtime['script'] = {
    'version': scriptVersion,
    'binary': await _binaryIdentity(
      'script',
      scriptToolchain.libraryPath,
      script: true,
    ),
    'typescriptCompiler': assetIdentities['compiler'],
  };
  final shell = await findPosixShell();
  runtime['shell'] = shell == null
      ? {'available': false, 'unavailableReason': 'No local POSIX shell found'}
      : {
          'available': true,
          'path': shell,
          'binary': {'sha256': _hashBytes(await File(shell).readAsBytes())},
        };
  report.addAll({
    'assets': assetIdentities,
    'runtime': runtime,
    'scriptInventory': inventory.toJson(),
    'phase': 'lua682',
  });
  await _persist(reportFile, report);
  final luaReportFile = File('${reportFile.path}.lua.json');
  Map<String, Object?> lua;
  try {
    lua = await lua_audit.auditBundledLuaCatalog(
      workspace: Directory(p.join(workspace.path, 'lua')),
      reportFile: luaReportFile,
      bundle: assets,
      toolchain: luaToolchain,
      onProgress: (done, _, id) =>
          onProgress?.call(done, scriptAcceptanceExpectedLocations, 'Lua $id'),
    );
  } catch (error, stack) {
    lua = {
      'executionComplete': false,
      'ok': false,
      'error': '$error',
      'stack': '$stack',
      'caseResults': <Object?>[],
    };
  }
  report.addAll({
    'runtime': runtime,
    'phase': 'script600',
    'luaReportPath': luaReportFile.path,
    if (await luaReportFile.exists())
      'luaReportSha256': _hashBytes(await luaReportFile.readAsBytes()),
  });
  await _persist(reportFile, report);
  final luaPending = (lua['caseResults'] as List? ?? const []).any(
    (row) => (row as Map)['nativeExecutionPending'] == true,
  );
  final script = luaPending
      ? <String, Object?>{
          'caseResults': [
            for (final item in inventory.cases)
              {
                ...item.toJson(),
                'attempted': false,
                'executionFinished': false,
                'passed': false,
                'reason': 'not_run_after_unfinished_Lua_execution',
              },
          ],
        }
      : await runScriptContentAudit(
          cases: inventory.cases,
          workspace: Directory(p.join(workspace.path, 'script')),
          reportFile: File('${reportFile.path}.script.json'),
          toolchain: scriptToolchain,
          shellPath: shell,
          runtimeIdentities: runtime,
          onProgress: (done, _, id) => onProgress?.call(
            682 + done,
            scriptAcceptanceExpectedLocations,
            id,
          ),
        );
  final pendingRuntime =
      luaPending ||
      (script['caseResults'] as List).any(
        (row) => (row as Map)['nativeExecutionPending'] == true,
      );
  report['phase'] = 'debugger-and-dirty-analysis';
  report['scriptReportPath'] = '${reportFile.path}.script.json';
  await _persist(reportFile, report);
  final debugger = pendingRuntime
      ? <String, Object?>{
          'ok': false,
          'reason': 'not_run_after_unfinished_runtime_execution',
        }
      : await runScriptDebuggerProbe(
          workspace: workspace,
          libraryPath: luaToolchain.libraryPath,
        );
  report['debuggerProbe'] = debugger;
  await _persist(reportFile, report);
  final studioDebugger = pendingRuntime
      ? <String, Object?>{
          'ok': false,
          'reason': 'not_run_after_unfinished_runtime_execution',
        }
      : await runScriptStudioDebuggerProbe(
          workspace: workspace,
          libraryPath: luaToolchain.libraryPath,
        );
  report['studioDebuggerProbe'] = studioDebugger;
  await _persist(reportFile, report);
  final diagnostics = pendingRuntime
      ? <String, Object?>{
          'ok': false,
          'reason': 'not_run_after_unfinished_runtime_execution',
        }
      : await runScriptDiagnosticsProbe(
          workspace: workspace,
          toolchain: scriptToolchain,
          shellPath: shell,
        );
  final rows = <Map<String, Object?>>[
    for (final raw in (lua['caseResults'] as List? ?? const []))
      {
        ...(raw as Map).cast<String, Object?>(),
        'language': 'lua',
        'runtime': runtime['lua'],
        'terminalLinePassed':
            raw['statusMatch'] == true &&
            raw['watchdogCancellationRequested'] != true &&
            raw['executionFinished'] == true &&
            scriptTerminalLinesMatch(
              raw['stdout'] as String? ?? '',
              raw['expectedOutput'] as String? ?? '',
            ),
      },
    for (final raw in script['caseResults']! as List)
      (raw as Map).cast<String, Object?>(),
  ];
  final luaRows = rows.where((row) => row['language'] == 'lua').toList();
  final current = luaRows.where((row) => row['corpus'] == 'current').toList();
  final luaInventory = lua['inventory'] as Map?;
  final coverage =
      rows.length == scriptAcceptanceExpectedLocations &&
      luaRows.length == 682 &&
      current.length == 480 &&
      inventory.cases.length == 600 &&
      inventory.issues.isEmpty &&
      (luaInventory?['issues'] as List? ?? ['missing Lua inventory']).isEmpty;
  final complete =
      rows.length == scriptAcceptanceExpectedLocations &&
      rows.every((row) => row['executionFinished'] == true);
  final compilerHash = (assetIdentities['compiler'] as Map)['sha256'];
  final runtimeVerified =
      (lua['runtime'] as Map?)?['version'] == 'Lua 5.4.8' &&
      scriptVersion == 'QuickJS2026-06-04 / TypeScript5.9.3 transpileModule' &&
      shell != null &&
      compilerHash == _compilerSha256 &&
      ['lua', 'script', 'shell'].every(
        (name) => ((runtime[name] as Map)['binary'] as Map)['sha256'] != null,
      );
  final probes =
      debugger['ok'] == true &&
      studioDebugger['ok'] == true &&
      diagnostics['ok'] == true &&
      (lua['diagnosticsProbe'] as Map?)?['ok'] == true;
  final currentExact =
      current.length == 480 && current.every((row) => row['passed'] == true);
  final exact =
      coverage &&
      complete &&
      runtimeVerified &&
      probes &&
      rows.every((row) => row['passed'] == true);
  final terminal =
      coverage &&
      complete &&
      runtimeVerified &&
      probes &&
      currentExact &&
      rows.every((row) => row['terminalLinePassed'] == true);
  final ohos = Platform.operatingSystem == 'ohos';
  report.addAll({
    'phase': 'finished',
    'finishedAt': DateTime.now().toUtc().toIso8601String(),
    'executionComplete': complete,
    'coverageGatePassed': coverage,
    'runtimeIdentityGatePassed': runtimeVerified,
    'ok': exact,
    'allShippedExactGatePassed': exact,
    'allShippedTerminalLineGatePassed': terminal,
    'current480LuaExactGatePassed': coverage && currentExact,
    'deviceGatePassed': exact && ohos && offlinePlatformGate,
    'terminalLineDeviceGatePassed': terminal && ohos && offlinePlatformGate,
    'diagnosticsProbe': diagnostics,
    'caseResults': rows,
    'totalLocations': rows.length,
    'executedCases': rows
        .where(
          (row) => row['executionFinished'] == true && row['status'] != 127,
        )
        .length,
    'exactPassedCases': rows.where((row) => row['passed'] == true).length,
    'terminalLinePassedCases': rows
        .where((row) => row['terminalLinePassed'] == true)
        .length,
    'failedExactCases': rows.where((row) => row['passed'] != true).length,
    'scriptCaseJournal': script['caseJournal'],
  });
  await _persist(reportFile, report);
  return report;
}

Map<String, Object?> _snapshot(LuaDebugSnapshot value) => {
  'state': value.state.name,
  'status': value.status,
  'stdout': value.stdout,
  'stderr': value.stderr,
  'frames': [
    for (final frame in value.frames)
      {
        'file': frame.file,
        'name': frame.name,
        'line': frame.line,
        'locals': [
          for (final local in frame.locals)
            {'name': local.name, 'type': local.type, 'value': local.value},
        ],
      },
  ],
};

/// Actual VM controls, not a UI/state-machine simulation.
Future<Map<String, Object?>> runScriptDebuggerProbe({
  required Directory workspace,
  String? libraryPath,
}) async {
  await workspace.create(recursive: true);
  final project = await workspace.createTemp('debugger-probe-');
  final checks = <Map<String, Object?>>[];
  final sources = <Map<String, Object?>>[];
  final sessions = <LuaDebugger>[];
  final report = <String, Object?>{
    'ok': false,
    'checks': checks,
    'sources': sources,
  };
  Future<LuaDebugger> start(String name, String source) async {
    final file = File(p.join(project.path, name));
    await file.writeAsString(source, flush: true);
    sources.add({
      'path': file.path,
      'source': source,
      'sha256': OfflineDigest.sha256(source),
    });
    final session = await LuaDebugger.start(
      file: file.path,
      projectDirectory: project.path,
      libraryPath: libraryPath,
      timeLimit: const Duration(seconds: 10),
    );
    sessions.add(session);
    return session;
  }

  void check(String id, bool passed, LuaDebugSnapshot snapshot) =>
      checks.add({'id': id, 'passed': passed, ..._snapshot(snapshot)});
  bool at(LuaDebugSnapshot value, int line, int depth) =>
      value.state == LuaDebugState.paused &&
      value.frames.length == depth &&
      value.frames.first.line == line;
  String? local(LuaDebugSnapshot value, String name) => value.frames.isEmpty
      ? null
      : value.frames.first.locals
            .where((item) => item.name == name)
            .firstOrNull
            ?.value;
  try {
    final nested = await start(
      'nested.lua',
      'local function inner(v)\n'
          '  local result = v + 1\n  return result\nend\n'
          'local function outer(v)\n  local answer = inner(v)\n  return answer * 2\nend\n'
          'local result = outer(20)\nprint(result)\n',
    );
    check(
      'initial-source-stop-before-output',
      nested.snapshot.state == LuaDebugState.paused &&
          nested.snapshot.stdout.isEmpty &&
          nested.snapshot.frames.isNotEmpty,
      nested.snapshot,
    );
    await nested.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'nested.lua'), 9),
    ]);
    var snap = await nested.resume();
    check('breakpoint-added-real-file-line', at(snap, 9, 1), snap);
    await nested.setBreakpoints([]);
    snap = await nested.resume(LuaDebugAction.stepInto);
    check('step-into-outer', at(snap, 6, 2), snap);
    snap = await nested.resume(LuaDebugAction.stepInto);
    check(
      'step-into-inner-and-primitive-local',
      at(snap, 2, 3) && local(snap, 'v') == '20',
      snap,
    );
    snap = await nested.resume(LuaDebugAction.stepOut);
    check('step-out-inner', at(snap, 7, 2), snap);
    snap = await nested.resume(LuaDebugAction.stepOut);
    check(
      'step-out-outer',
      at(snap, 10, 1) && local(snap, 'result') == '42',
      snap,
    );
    snap = await nested.resume();
    check(
      'resume-completes-with-exact-output',
      snap.state == LuaDebugState.terminated &&
          snap.status == 0 &&
          snap.stdout == '42\n' &&
          snap.stderr.isEmpty,
      snap,
    );
    final over = await start(
      'over.lua',
      'local function f()\n  return 42\nend\nlocal n = f()\nprint(n)\n',
    );
    await over.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'over.lua'), 4),
    ]);
    await over.resume();
    await over.setBreakpoints([]);
    snap = await over.resume(LuaDebugAction.stepOver);
    check(
      'step-over-call-and-inspect-local',
      at(snap, 5, 1) && local(snap, 'n') == '42',
      snap,
    );
    snap = await over.resume();
    check(
      'step-over-session-completes',
      snap.status == 0 && snap.stdout == '42\n',
      snap,
    );
    final loop = await start(
      'breakpoint-remove.lua',
      'local n=0\nfor i=1,3 do\n  n=n+1\nend\nprint(n)\n',
    );
    await loop.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'breakpoint-remove.lua'), 3),
    ]);
    snap = await loop.resume();
    check(
      'loop-breakpoint-first-iteration',
      at(snap, 3, 1) && local(snap, 'n') == '0',
      snap,
    );
    await loop.setBreakpoints([]);
    snap = await loop.resume();
    check(
      'removed-breakpoint-does-not-stop-next-iterations',
      snap.state == LuaDebugState.terminated &&
          snap.status == 0 &&
          snap.stdout == '3\n',
      snap,
    );
    final closing = await start(
      'paused-close.lua',
      'local closer <close> = setmetatable({}, {__close = function()\n'
          '  print("cleanup" .. string.char(0) .. "preserved")\nend})\nprint("must not execute")\n',
    );
    await closing.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'paused-close.lua'), 4),
    ]);
    snap = await closing.resume();
    check(
      'close-local-established-before-paused-stop',
      at(snap, 4, 1) && snap.stdout.isEmpty,
      snap,
    );
    snap = await closing.stop();
    check(
      'paused-stop-unwinds-close-and-preserves-output',
      snap.state == LuaDebugState.terminated &&
          snap.status == 130 &&
          snap.stdout == 'cleanup\u0000preserved\n' &&
          snap.stderr == 'Lua execution cancelled\n',
      snap,
    );
    report['ok'] =
        checks.length == 13 && checks.every((item) => item['passed'] == true);
  } catch (error, stack) {
    report.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    var disposed = true;
    for (final session in sessions) {
      try {
        await session.dispose();
      } catch (error) {
        disposed = false;
        report['disposeError'] = '$error';
      }
    }
    if (disposed) {
      await project.delete(recursive: true);
      report['projectRemoved'] = true;
    } else {
      report.addAll({'ok': false, 'retainedProjectPath': project.path});
    }
  }
  return report;
}

Map<String, Object?> _studioSnapshot(DebugSnapshot value) => {
  'sessionId': value.sessionId,
  'revision': value.revision,
  'phase': value.phase.name,
  'pauseGeneration': value.pauseToken?.generation,
  'exitCode': value.exitCode,
  'stdout': value.stdout,
  'stderr': value.stderr,
  'console': value.console,
  'message': value.message,
  'stdoutTruncated': value.stdoutTruncated,
  'stderrTruncated': value.stderrTruncated,
  'frames': [
    for (final frame in value.frames)
      {
        'id': frame.id,
        'threadId': frame.threadId,
        'filePath': frame.location?.filePath,
        'line': frame.location?.line,
        'locals': [
          for (final local in frame.locals)
            {
              'name': local.name,
              'type': local.type,
              'value': local.value,
              'unavailableReason': local.unavailableReason,
              'truncated': local.truncated,
            },
        ],
      },
  ],
};

Future<DebugSnapshot> _waitForStudioPause(
  DebugSession session,
  DebugPauseToken? previous,
) async {
  final result = Completer<DebugSnapshot>();
  bool matches(DebugSnapshot value) =>
      value.phase == DebugPhase.paused && value.pauseToken != previous;
  void receive(DebugSnapshot value) {
    if (result.isCompleted) return;
    if (matches(value)) {
      result.complete(value);
    } else if (value.isTerminal) {
      result.completeError(
        StateError('Session ended before expected pause: ${value.message}'),
      );
    }
  }

  final subscription = session.updates.listen(
    receive,
    onError: result.completeError,
  );
  try {
    receive(session.snapshot);
    return await result.future.timeout(const Duration(seconds: 5));
  } finally {
    await subscription.cancel();
  }
}

/// Exercise the same saved-source adapter and lifecycle used by the editor.
Future<Map<String, Object?>> runScriptStudioDebuggerProbe({
  required Directory workspace,
  String? libraryPath,
}) async {
  const wait = Duration(seconds: 5);
  await workspace.create(recursive: true);
  final created = await workspace.createTemp('studio-debugger-probe-');
  final project = Directory(p.normalize(await created.resolveSymbolicLinks()));
  final provider = LuaStudioDebugger(libraryPath: libraryPath, timeLimit: wait);
  final checks = <Map<String, Object?>>[];
  final sources = <Map<String, Object?>>[];
  final sessions = <DebugSession>[];
  var unfinishedLaunch = false;
  final report = <String, Object?>{
    'ok': false,
    'checks': checks,
    'sources': sources,
    'canonicalProjectPath': project.path,
  };
  void check(String id, bool passed, DebugSnapshot snapshot) =>
      checks.add({'id': id, 'passed': passed, ..._studioSnapshot(snapshot)});
  Future<DebugSession> start(
    String name,
    String source, {
    List<DebugBreakpoint> breakpoints = const [],
  }) async {
    final file = File(p.join(project.path, name));
    await file.writeAsString(source, flush: true);
    sources.add({
      'path': file.path,
      'source': source,
      'sha256': OfflineDigest.sha256(source),
    });
    var abandoned = false;
    final launch = provider
        .launch(
          DebugLaunchRequest(
            projectPath: project.path,
            entryFilePath: file.path,
            language: 'Lua',
            documents: const [],
            stopOnEntry: true,
            breakpoints: breakpoints,
          ),
        )
        .then((session) async {
          if (abandoned) {
            // A timed-out launch may still return a live paused worker later.
            await session.dispose().timeout(wait);
          } else {
            sessions.add(session);
          }
          return session;
        });
    return launch.timeout(
      wait,
      onTimeout: () {
        abandoned = true;
        unfinishedLaunch = true;
        throw TimeoutException('Shared debugger launch did not finish', wait);
      },
    );
  }

  Future<void> disposeAndCheck(String id, DebugSession session) async {
    final closed = Completer<void>();
    final subscription = session.updates.listen(
      (_) {},
      onDone: closed.complete,
    );
    try {
      await session.dispose().timeout(wait);
      await closed.future.timeout(wait);
      await session.dispose().timeout(wait);
      check(
        id,
        session.snapshot.isTerminal && closed.isCompleted,
        session.snapshot,
      );
    } finally {
      await subscription.cancel();
    }
  }

  try {
    final running = await start(
      'shared-step.lua',
      'local n = 40\nn = n + 2\nprint(n)\n',
    );
    final entry = await _waitForStudioPause(running, null);
    check(
      'shared-entry-pause-before-output',
      entry.pauseToken?.sessionId == running.id &&
          entry.frames.length == 1 &&
          entry.frames.first.location?.line == 1 &&
          p.equals(
            entry.frames.first.location?.filePath ?? '',
            p.join(project.path, 'shared-step.lua'),
          ) &&
          entry.stdout.isEmpty &&
          entry.stderr.isEmpty &&
          entry.exitCode == null,
      entry,
    );
    await running
        .command(DebugCommand.stepInto, pauseToken: entry.pauseToken)
        .timeout(wait);
    final stepped = await _waitForStudioPause(running, entry.pauseToken);
    check(
      'shared-step-actual-source-and-local',
      stepped.revision > entry.revision &&
          stepped.frames.length == 1 &&
          stepped.frames.first.location?.line == 2 &&
          stepped.frames.first.locals.any(
            (local) =>
                local.name == 'n' &&
                local.type == 'number' &&
                local.value == '40' &&
                local.unavailableReason == null &&
                !local.truncated,
          ) &&
          stepped.stdout.isEmpty,
      stepped,
    );
    var staleRejected = false;
    try {
      await running
          .command(DebugCommand.resume, pauseToken: entry.pauseToken)
          .timeout(wait);
    } on StateError {
      staleRejected = true;
    }
    final afterStale = running.snapshot;
    check(
      'shared-stale-token-rejected-without-execution',
      staleRejected &&
          afterStale.revision == stepped.revision &&
          afterStale.phase == DebugPhase.paused &&
          afterStale.pauseToken == stepped.pauseToken &&
          afterStale.stdout == stepped.stdout &&
          afterStale.stderr == stepped.stderr,
      afterStale,
    );
    await running
        .command(DebugCommand.resume, pauseToken: stepped.pauseToken)
        .timeout(wait);
    await running.done.timeout(wait);
    final completed = running.snapshot;
    check(
      'shared-resume-exact-output-and-worker-done',
      completed.phase == DebugPhase.terminated &&
          completed.exitCode == 0 &&
          completed.stdout == '42\n' &&
          completed.stderr.isEmpty &&
          !completed.stdoutTruncated &&
          !completed.stderrTruncated &&
          completed.frames.isEmpty &&
          completed.pauseToken == null,
      completed,
    );
    await disposeAndCheck('shared-completed-dispose-closes-updates', running);

    final closePath = p.join(project.path, 'shared-close.lua');
    final closing = await start(
      'shared-close.lua',
      'local closer <close> = setmetatable({}, {__close = function()\n'
          '  print("cleanup" .. string.char(0) .. "preserved")\nend})\nprint("must not execute")\n',
      breakpoints: [DebugBreakpoint(filePath: closePath, line: 4)],
    );
    final closeEntry = await _waitForStudioPause(closing, null);
    await closing
        .command(DebugCommand.resume, pauseToken: closeEntry.pauseToken)
        .timeout(wait);
    final beforeStop = await _waitForStudioPause(
      closing,
      closeEntry.pauseToken,
    );
    check(
      'shared-close-local-established-before-stop',
      beforeStop.frames.isNotEmpty &&
          beforeStop.frames.first.location?.line == 4 &&
          beforeStop.frames.first.locals.any(
            (local) => local.name == 'closer',
          ) &&
          beforeStop.breakpoints.single.status ==
              DebugBreakpointStatus.verified &&
          beforeStop.stdout.isEmpty,
      beforeStop,
    );
    await closing.stop().timeout(wait);
    await closing.done.timeout(wait);
    final stopped = closing.snapshot;
    check(
      'shared-stop-unwinds-close-and-worker-done',
      stopped.phase == DebugPhase.terminated &&
          stopped.exitCode == 130 &&
          stopped.stdout == 'cleanup\u0000preserved\n' &&
          stopped.stderr == 'Lua execution cancelled\n' &&
          stopped.frames.isEmpty &&
          stopped.pauseToken == null,
      stopped,
    );
    await disposeAndCheck('shared-stopped-dispose-closes-updates', closing);
    report['ok'] =
        checks.length == 8 && checks.every((item) => item['passed'] == true);
  } catch (error, stack) {
    report.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    var disposed = !unfinishedLaunch;
    for (final session in sessions) {
      try {
        await session.dispose().timeout(wait);
        await session.done.timeout(wait);
      } catch (error) {
        disposed = false;
        report['disposeError'] = '$error';
      }
    }
    if (disposed) {
      await project.delete(recursive: true);
      report['projectRemoved'] = true;
    } else {
      report.addAll({'ok': false, 'retainedProjectPath': project.path});
    }
  }
  return report;
}

/// Dirty snapshots are checked without source writes or user-command execution.
Future<Map<String, Object?>> runScriptDiagnosticsProbe({
  required Directory workspace,
  ScriptToolchain toolchain = const ScriptToolchain(),
  String? shellPath,
}) async {
  await workspace.create(recursive: true);
  final created = await workspace.createTemp('dirty-probe-');
  final project = Directory(p.normalize(await created.resolveSymbolicLinks()));
  final checks = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'ok': false,
    'checks': checks,
    'requestedWorkspacePath': workspace.path,
    'canonicalProjectPath': project.path,
    'coreUiAndStaleResponseGate':
        'not evaluated here; shared-core workflow tests required',
  };
  try {
    for (final language in _scriptLanguages) {
      final extension = language == 'javascript'
          ? 'js'
          : language == 'typescript'
          ? 'ts'
          : 'sh';
      final file = File(p.join(project.path, 'dirty.$extension'));
      final marker = File(p.join(project.path, 'must-not-run-$extension'));
      const saved = 'intentionally different malformed saved source\r\n';
      await file.writeAsString(saved, flush: true);
      final before = _hashBytes(await file.readAsBytes());
      final String bad, clean;
      if (language == 'shell') {
        bad = '# 中文😀\r\nif then\n';
        final quoted = "'${marker.path.replaceAll("'", "'\\''")}'";
        clean =
            '# 中文😀\r\nprintf mutation > $quoted\nprintf "must not execute\\n"\n';
      } else {
        bad = language == 'javascript'
            ? '// 中文😀\r\nconst = 1;'
            : '// 中文😀\r\nconst n: number = ;';
        clean =
            '// 中文😀\r\nimport "./missing-that-must-not-load.js";\r\n'
            'console.log("must not execute"); throw new Error("must not execute"); while(true){}';
      }
      final CodeAnalyzer analyzer = language == 'shell'
          ? ShellCodeAnalyzer(shellFinder: () async => shellPath)
          : ScriptCodeAnalyzer(toolchain: toolchain);
      for (final (revision, source, expectError) in [
        (1, bad, true),
        (2, clean, false),
      ]) {
        final result = await analyzer.analyze(
          CodeAnalysisRequest(
            projectPath: project.path,
            activeFilePath: file.path,
            language: language,
            revision: revision,
            documents: [
              CodeDocumentSnapshot(
                path: file.path,
                text: source,
                revision: revision,
              ),
            ],
          ),
        );
        final expectedStart = language == 'javascript'
            ? source.indexOf('=')
            : source.indexOf(';');
        final validRange =
            result.diagnostics.isNotEmpty &&
            result.diagnostics.every(
              (item) =>
                  p.equals(item.filePath, file.path) &&
                  item.startOffset >= 0 &&
                  item.endOffset >= item.startOffset &&
                  item.endOffset <= source.length &&
                  item.severity == CodeDiagnosticSeverity.error,
            );
        final exactRange = language == 'shell'
            ? validRange
            : validRange &&
                  result.diagnostics.single.startOffset == expectedStart &&
                  result.diagnostics.single.endOffset == expectedStart + 1;
        checks.add({
          'id': '$language-${expectError ? 'dirty-error' : 'corrected-clean'}',
          'passed':
              result.unavailableReason == null &&
              (expectError ? exactRange : result.diagnostics.isEmpty),
          'file': file.path,
          'revision': revision,
          'source': source,
          'sourceSha256': OfflineDigest.sha256(source),
          'unavailableReason': result.unavailableReason,
          'diagnostics': [
            for (final item in result.diagnostics)
              {
                'filePath': item.filePath,
                'startOffset': item.startOffset,
                'endOffset': item.endOffset,
                'message': item.message,
                'source': item.source,
                'code': item.code,
              },
          ],
        });
      }
      final after = await file.exists()
          ? _hashBytes(await file.readAsBytes())
          : null;
      final markerExists = await marker.exists();
      checks.add({
        'id': '$language-source-and-side-effects-preserved',
        'passed': before == after && !markerExists,
        'beforeSha256': before,
        'afterSha256': after,
        'markerExists': markerExists,
      });
    }
    report['ok'] =
        checks.length == 9 && checks.every((item) => item['passed'] == true);
  } catch (error, stack) {
    report.addAll({'error': '$error', 'stack': '$stack'});
  } finally {
    await project.delete(recursive: true);
    report['projectRemoved'] = true;
  }
  return report;
}

class ScriptAcceptancePage extends StatefulWidget {
  const ScriptAcceptancePage({super.key});
  @override
  State<ScriptAcceptancePage> createState() => _ScriptAcceptancePageState();
}

class _ScriptAcceptancePageState extends State<ScriptAcceptancePage> {
  String _status = 'Preparing all1282 packaged Script locations…';
  String? _path;
  double? _progress;
  Map<String, Object?>? _summary;
  late final ScriptReportExporter _exporter;
  List<ScriptReportArtifact> _artifacts = const [];
  final Map<ScriptReportRole, ScriptReportExportResult> _receipts = {};

  /// Whether the exported top digest matched the logged digest for this run.
  /// `null` means unknown (no logged digest); it never promotes an acceptance
  /// flag and never changes the transfer verdict.
  final Map<ScriptReportRole, bool?> _digestBound = {};
  ScriptReportRole? _exporting;
  bool _running = true;
  bool _disposed = false;
  int _runSerial = 0;
  int _exportSerial = -1;
  @override
  void initState() {
    super.initState();
    _exporter = ScriptReportExporter(isActive: _exportActive);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    // A disposed page must never open a new destination write.
    _disposed = true;
    _exporter.dispose();
    super.dispose();
  }

  bool _exportActive() =>
      mounted && !_disposed && !_running && _runSerial == _exportSerial;

  Future<void> _run() async {
    _running = true;
    _exportSerial = -1;
    final serial = ++_runSerial;
    File? file;
    try {
      final storage = await AppPaths.storageDirectory();
      if (storage == null) throw StateError('App-owned storage unavailable');
      await AppPrivateRoots.resolve(storage);
      final runs = Directory(p.join(storage, 'qfli-script-acceptance-runs'));
      await runs.create(recursive: true);
      final workspace = await runs.createTemp('run-');
      // A fresh report directory per run keeps the four basenames while
      // preventing an old companion from standing in for this run.
      final reportDirectory = Directory(p.join(workspace.path, 'reports'));
      await reportDirectory.create(recursive: true);
      final reportFile = File(
        p.join(reportDirectory.path, 'qfli-script-acceptance.json'),
      );
      file = reportFile;
      if (mounted) setState(() => _path = reportFile.path);
      final report = await auditBundledScriptAcceptance(
        workspace: workspace,
        reportFile: reportFile,
        onProgress: (done, total, id) {
          if (mounted) {
            setState(() {
              _status = '$done / $total  $id';
              _progress = done / total;
            });
          }
        },
      );
      final summary = <String, Object?>{
        'finished': true,
        for (final key in [
          'executionComplete',
          'coverageGatePassed',
          'runtimeIdentityGatePassed',
          'allShippedExactGatePassed',
          'allShippedTerminalLineGatePassed',
          'current480LuaExactGatePassed',
          'deviceGatePassed',
          'terminalLineDeviceGatePassed',
          'offlinePlatformGatePassed',
          'totalLocations',
          'executedCases',
          'exactPassedCases',
          'terminalLinePassedCases',
          'failedExactCases',
        ])
          key: report[key],
        'debuggerProbePassed': (report['debuggerProbe'] as Map)['ok'],
        'studioDebuggerProbePassed':
            (report['studioDebuggerProbe'] as Map)['ok'],
        'diagnosticsProbePassed': (report['diagnosticsProbe'] as Map)['ok'],
        'offlinePlatformProbeEvaluated':
            (report['offlinePlatformProbe'] as Map)['evaluated'],
        'offlinePlatformProbePassed':
            (report['offlinePlatformProbe'] as Map)['ok'],
        'offlinePlatformProbeStatus':
            (report['offlinePlatformProbe'] as Map)['status'],
        'offlinePlatformEvidenceKind':
            (report['offlinePlatformProbe'] as Map)['evidenceKind'],
        'report': reportFile.path,
        'reportSha256': _hashBytes(await reportFile.readAsBytes()),
        'operatingSystem': Platform.operatingSystem,
        'abi': Abi.current().toString(),
      };
      debugPrint('QFLI_SCRIPT_ACCEPTANCE ${jsonEncode(summary)}');
      final artifacts = scriptReportArtifacts(reportFile);
      if (mounted) {
        setState(() {
          _summary = summary;
          _status = 'QFLI_SCRIPT_ACCEPTANCE FINISHED';
          _progress = 1;
          _running = false;
          _exportSerial = serial;
          _artifacts = artifacts;
        });
      }
    } catch (error, stack) {
      final failure = <String, Object?>{
        'finished': true,
        'executionComplete': false,
        'ok': false,
        'deviceGatePassed': false,
        'error': '$error',
        'stack': '$stack',
        'report': file?.path,
      };
      if (file != null) {
        try {
          final prior = await file.exists()
              ? (jsonDecode(await file.readAsString()) as Map)
                    .cast<String, Object?>()
              : <String, Object?>{};
          await _persist(file, {
            ..._fatalAcceptanceDefaults(),
            ...prior,
            'fatalFailure': failure,
            'ok': false,
            'executionComplete': false,
          });
          // Record a digest for the failed-attempt top checkpoint too, so the
          // export receipt can be bound to what was actually written.
          failure['reportSha256'] = _hashBytes(await file.readAsBytes());
        } catch (error) {
          failure['reportWriteError'] = '$error';
        }
      }
      debugPrint('QFLI_SCRIPT_ACCEPTANCE ${jsonEncode(failure)}');
      final failureArtifacts = file == null
          ? const <ScriptReportArtifact>[]
          : scriptReportArtifacts(file);
      if (mounted) {
        setState(() {
          _summary = failure;
          _status = 'QFLI_SCRIPT_ACCEPTANCE FAILED';
          _progress = 1;
          _running = false;
          _exportSerial = serial;
          _artifacts = failureArtifacts;
        });
      }
    }
  }

  Future<void> _export(ScriptReportArtifact artifact) async {
    // Preserve the single export lane and reject a stale or queued tap whose
    // page is disposed or whose run identity changed, before any setState.
    if (_exporting != null || !_exportActive()) return;
    setState(() => _exporting = artifact.role);
    final result = await _exporter.export(artifact);
    // Bind the top artifact digest to the digest logged for this attempt.
    // Retrieval state stays separate from acceptance; a mismatch is reported,
    // never silently promoted or used to rewrite source evidence. A result
    // with no source digest (refused, cancelled, failed) records no binding.
    final logged = _summary?['reportSha256'];
    final sourceSha = result.sourceSha256;
    final comparable =
        artifact.role == ScriptReportRole.top &&
        logged is String &&
        sourceSha != null;
    final bound = comparable ? logged == sourceSha : null;
    if (!mounted) return;
    setState(() {
      _receipts[artifact.role] = result;
      _digestBound[artifact.role] = bound;
      _exporting = null;
    });
    final metadata = <String, Object?>{
      ...result.toJson(),
      'digestBoundToLoggedReport': bound,
      'attemptLabel': _attemptLabel(),
    };
    debugPrint('QFLI_SCRIPT_REPORT_EXPORT ${jsonEncode(metadata)}');
  }

  String _bindingText(ScriptReportRole role) {
    final bound = _digestBound[role];
    if (bound == null) return '';
    return bound
        ? ', digest matches the logged report'
        : ', digest DIFFERS from the logged report';
  }

  /// Record the honest provenance limit for an opaque URI destination: which
  /// local file it maps to cannot be proven, so no path is guessed.
  String _guardText(ScriptReportExportResult receipt) {
    if (receipt.destinationGuard !=
        ScriptReportDestinationGuard.opaqueUriUnverified) {
      return '';
    }
    return ', destination is an opaque URI; local mapping unproven';
  }

  /// Honest attempt state for the current run. It prefixes every artifact tile
  /// and the export log so a transfer verdict is never read as an accepted run.
  /// Acceptance gates stay separate, and an unknown summary claims nothing.
  String _attemptLabel() {
    final complete = _summary?['executionComplete'];
    if (complete == true) {
      return 'Attempt: execution complete (acceptance gates separate)';
    }
    if (complete == false) return 'Attempt: partial/failed execution';
    return 'Attempt: status unavailable';
  }

  String _receiptText(ScriptReportExportResult receipt) {
    final destination = receipt.destinationLabel.isEmpty
        ? '—'
        : receipt.destinationLabel;
    final transfer = switch (receipt.state) {
      ScriptReportExportState.verified =>
        'Verified saved: ${receipt.sourceBytes} bytes, SHA256 '
            '${receipt.sourceSha256}, destination $destination'
            '${_bindingText(receipt.artifact.role)}'
            '${_guardText(receipt)}',
      ScriptReportExportState.cancelled =>
        'Cancelled: destination was not written',
      ScriptReportExportState.invalidDestination =>
        'Failed: picker returned neither a path nor a URI',
      ScriptReportExportState.destinationUnsafe =>
        'Refused: destination is inside the current run report directory '
            'or could not be proven outside it; evidence left unchanged',
      ScriptReportExportState.unavailableSource =>
        'Unavailable: source file missing or unreadable',
      ScriptReportExportState.writtenUnverified =>
        'Written but unverified: read-back unavailable',
      ScriptReportExportState.digestMismatch =>
        'Verification failed: read-back differs '
            '(${receipt.readBackBytes} bytes)',
      ScriptReportExportState.failed =>
        'Failed: ${receipt.message ?? 'write error'}',
      ScriptReportExportState.abandoned =>
        'Aborted: page closed or run changed before the write',
      ScriptReportExportState.busy =>
        'Ignored: another report is already being saved',
    };
    // Prefix the attempt label so a copied receipt is self-contained and never
    // reads as an accepted run on its own.
    return '${_attemptLabel()} — $transfer';
  }

  Widget _artifactTile(ScriptReportArtifact artifact) {
    final receipt = _receipts[artifact.role];
    final exporting = _exporting == artifact.role;
    final canExport =
        artifact.exists && !_running && _exporting == null && !_disposed;
    final name = artifact.exists
        ? artifact.basename
        : '${artifact.basename} (missing at inventory)';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('${_attemptLabel()} — $name'),
                if (receipt != null) SelectableText(_receiptText(receipt)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: canExport ? () => _export(artifact) : null,
            child: Text(exporting ? 'Saving…' : 'Save report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Script packaged acceptance')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(_status),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          if (_path != null) SelectableText('Report: $_path'),
          if (_summary != null)
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(_summary),
            ),
          if (_artifacts.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Report files (current run only)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_path != null)
              SelectableText('Run directory: ${p.dirname(_path!)}'),
            const SizedBox(height: 8),
            for (final artifact in _artifacts) _artifactTile(artifact),
          ],
        ],
      ),
    ),
  );
}

/// False-initialized acceptance flags so a fatal checkpoint written before the
/// first full report still carries the normal gate set. Values are never
/// promoted by export; retrieval state stays separate from acceptance.
Map<String, Object?> _fatalAcceptanceDefaults() => {
  'executionComplete': false,
  'coverageGatePassed': false,
  'runtimeIdentityGatePassed': false,
  'allShippedExactGatePassed': false,
  'allShippedTerminalLineGatePassed': false,
  'current480LuaExactGatePassed': false,
  'deviceGatePassed': false,
  'terminalLineDeviceGatePassed': false,
  'offlinePlatformGatePassed': false,
};
