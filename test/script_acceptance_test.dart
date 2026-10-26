import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/script_toolchain.dart';
import 'package:qfli_lua/shell_code_analyzer.dart';

import '../bin/lua_catalog_audit.dart' as lua;
import '../bin/script_acceptance.dart';

void main() {
  final toolchain = ScriptToolchain(
    libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
    typescriptCompilerPath: p.absolute('assets/runtime/typescript.js'),
  );

  Map<String, String> sources() => {
    for (final asset in scriptAcceptanceAssets.entries)
      asset.key: File(
        '../qfli_studio_core/${asset.value.substring('packages/qfli_studio_core/'.length)}',
      ).readAsStringSync(),
  };
  Map<String, dynamic> decode(String source) =>
      jsonDecode(source) as Map<String, dynamic>;
  late Directory workspace;
  setUp(
    () => workspace = Directory.systemTemp.createTempSync('script_acceptance_'),
  );
  tearDown(() => workspace.deleteSync(recursive: true));

  test(
    'host offline platform probe is not evaluated and never passes',
    () async {
      var invoked = false;
      final report = await runScriptOfflinePlatformProbe(
        operatingSystem: 'windows',
        invokePlatform: (method, arguments) async {
          invoked = true;
          throw PlatformException(code: 'OFFLINE_ONLY');
        },
      );
      expect(invoked, isFalse);
      expect(report['evaluated'], isFalse);
      expect(report['ok'], isFalse);
      expect(report['status'], 'not_evaluated');
      expect(report['nativeEvidence'], isFalse);
      expect(report['evidenceKind'], 'not_evaluated');
      expect(report['checks'], isEmpty);
    },
  );

  test(
    'offline bridge probe checks both methods and all argument vectors',
    () async {
      final calls = <(String, Object?)>[];
      final report = await runScriptOfflinePlatformProbe(
        operatingSystem: 'ohos',
        invokePlatform: (method, arguments) async {
          calls.add((method, arguments));
          throw PlatformException(code: 'OFFLINE_ONLY', message: 'Offline');
        },
      );
      expect(report['evaluated'], isTrue);
      expect(report['ok'], isTrue);
      expect(report['status'], 'passed');
      expect(report['evidenceKind'], 'injected');
      expect(report['nativeEvidence'], isFalse);
      expect(report['channel'], 'qflistudio/platform');
      expect(calls, hasLength(28));
      final checks = (report['checks'] as List).cast<Map>();
      expect(checks, hasLength(28));
      expect(
        checks.every((check) => check['errorCode'] == 'OFFLINE_ONLY'),
        isTrue,
      );
      for (final method in ['openAgreement', 'openUrl']) {
        final methodChecks = checks.where((check) => check['method'] == method);
        expect(methodChecks, hasLength(14));
        expect(
          methodChecks.map((check) => check['vector']),
          containsAll([
            'https',
            'http',
            'network-path',
            'mailto',
            'tel',
            'custom-scheme',
            'javascript',
            'file',
            'data',
            'malformed-url',
            'missing-arguments',
            'missing-url',
            'wrong-url-type',
            'wrong-arguments-type',
          ]),
        );
        expect(calls.where((call) => call.$1 == method), hasLength(14));
      }
      expect(calls.any((call) => call.$2 == null), isTrue);
      expect(calls.any((call) => call.$2 == 42), isTrue);
      expect(
        jsonEncode(report),
        contains('https://example.com/qfli-offline-probe'),
      );
    },
  );

  final platformFailures = <(String, String, ScriptPlatformCall)>[
    ('null success', 'unexpected_success', (method, arguments) async => null),
    ('true success', 'unexpected_success', (method, arguments) async => true),
    (
      'wrong code',
      'platform_exception',
      (method, arguments) async {
        throw PlatformException(code: 'INVALID_ARGUMENT');
      },
    ),
    (
      'missing bridge',
      'not_implemented',
      (method, arguments) async {
        throw MissingPluginException('No native bridge');
      },
    ),
    (
      'unexpected error',
      'error',
      (method, arguments) async {
        throw StateError('Native transport failed');
      },
    ),
    ('timeout', 'timeout', (method, arguments) => Completer<Object?>().future),
  ];
  for (final (name, outcome, call) in platformFailures) {
    test('offline bridge probe never passes $name', () async {
      final report = await runScriptOfflinePlatformProbe(
        operatingSystem: 'ohos',
        invokePlatform: call,
        callTimeout: const Duration(milliseconds: 1),
      );
      expect(report['evaluated'], isTrue);
      expect(report['ok'], isFalse);
      expect(report['status'], 'failed');
      expect(report['nativeEvidence'], isFalse);
      final checks = (report['checks'] as List).cast<Map>();
      expect(checks, hasLength(28));
      expect(checks.every((check) => check['passed'] == false), isTrue);
      expect(checks.every((check) => check['outcome'] == outcome), isTrue);
    });
  }

  test(
    'one successful native call fails the whole offline bridge probe',
    () async {
      var calls = 0;
      final report = await runScriptOfflinePlatformProbe(
        operatingSystem: 'ohos',
        invokePlatform: (method, arguments) async {
          if (++calls == 1) return null;
          throw PlatformException(code: 'OFFLINE_ONLY');
        },
      );
      expect(calls, 28);
      expect(report['ok'], isFalse);
      expect(report['nativeEvidence'], isFalse);
      final checks = (report['checks'] as List).cast<Map>();
      expect(checks.where((check) => check['passed'] == true), hasLength(27));
    },
  );

  test('all shipped locations total1282 and keep every example and lesson', () {
    final inventory = ScriptAcceptanceInventory.fromSources(sources());
    expect(inventory.issues, isEmpty);
    expect(inventory.cases, hasLength(600));
    expect(inventory.counts.values, everyElement(100));
    expect(inventory.counts, hasLength(6));
    final luaInventory = lua.LuaCatalogAuditInventory.fromSources({
      for (final asset in lua.luaAuditAssets.entries)
        asset.key: File(
          asset.value.startsWith('packages/qfli_studio_core/')
              ? '../qfli_studio_core/${asset.value.substring('packages/qfli_studio_core/'.length)}'
              : asset.value,
        ).readAsStringSync(),
    });
    expect(luaInventory.issues, isEmpty);
    expect(luaInventory.cases, hasLength(682));
    expect(
      luaInventory.cases.length + inventory.cases.length,
      scriptAcceptanceExpectedLocations,
    );
    expect(scriptAcceptanceExpectedLocations, 1282);
    expect(
      luaInventory.cases.where((row) => row.corpus == 'current'),
      hasLength(480),
    );
    final first = inventory.cases.first;
    final lesson = inventory.cases.firstWhere(
      (item) => item.id == 'javascript-tutorial-001-lesson',
    );
    expect(first.source, endsWith('\n'));
    expect(lesson.source, isNot(endsWith('\n')));
    expect(lesson.fixtures, first.fixtures);
    expect(lesson.fixtureOrigin, contains('linked example'));
    expect(first.toJson()['sourceSha256'], hasLength(64));
  });

  test(
    'truncated missing duplicate and unsafe inventories fail independent counts',
    () {
      expect(
        () => ScriptAcceptanceInventory.fromSources({}),
        throwsFormatException,
      );
      final truncated = sources();
      final examples = decode(truncated['examples']!);
      (examples['entries'] as List).removeWhere(
        (entry) => entry['type'] == 'typescript',
      );
      truncated['examples'] = jsonEncode(examples);
      final missing = ScriptAcceptanceInventory.fromSources(truncated);
      expect(
        missing.issues,
        contains(contains('typescript examples: expected100')),
      );
      expect(missing.cases, hasLength(500));
      final mutated = sources();
      final entries = decode(mutated['examples']!);
      final js = (entries['entries'] as List)
          .where((entry) => entry['type'] == 'javascript')
          .toList();
      js[1]['id'] = js[0]['id'];
      js[0]['inputFixtures'] = {'../escape': 'must not write'};
      mutated['examples'] = jsonEncode(entries);
      final invalid = ScriptAcceptanceInventory.fromSources(mutated);
      expect(invalid.cases, hasLength(600));
      expect(invalid.issues, contains(contains('duplicate location identity')));
      expect(invalid.issues, contains(contains('Unsafe or colliding fixture')));
    },
  );

  test(
    'terminal comparison preserves blank lines spaces and raw exact mismatches',
    () {
      expect(scriptTerminalLinesMatch('42\n', '42'), isTrue);
      expect(scriptTerminalLinesMatch('42\r\n', '42'), isTrue);
      expect(scriptTerminalLinesMatch('a\nb\n', 'a\nb'), isTrue);
      expect(scriptTerminalLinesMatch('42\n\n', '42'), isFalse);
      expect(scriptTerminalLinesMatch('42 \n', '42'), isFalse);
      expect(scriptTerminalLinesMatch(' 42\n', '42'), isFalse);
      expect(scriptTerminalLinesMatch('\n', ''), isFalse);
      expect(scriptTerminalLinesMatch('a\n\nb\n', 'a\nb'), isFalse);
    },
  );

  test(
    'small real JS TS and POSIX fixtures retain raw results and durable checkpoints',
    () async {
      final shell = await findPosixShell();
      expect(
        shell,
        isNotNull,
        reason: 'This acceptance fixture requires a real local POSIX shell',
      );
      final file = File(p.join(workspace.path, 'small-report.json'));
      final checkpoints = <int>[];
      final report = await runScriptContentAudit(
        cases: const [
          ScriptAcceptanceCase(
            language: 'javascript',
            kind: 'example',
            id: 'js-original',
            asset: 'fixture',
            source: 'console.log([20,22].reduce((a,b)=>a+b,0));',
            expectedOutput: '42',
          ),
          ScriptAcceptanceCase(
            language: 'typescript',
            kind: 'lesson',
            id: 'ts-fixture',
            asset: 'fixture',
            source:
                'interface V {n:number}; const item:V={n:42}; console.log(item.n);',
            expectedOutput: '42\n',
          ),
          ScriptAcceptanceCase(
            language: 'shell',
            kind: 'example',
            id: 'sh-fixture',
            asset: 'fixture',
            source:
                'IFS= read -r value < data/input.txt\nprintf "%s\\n" "\$value"\n',
            expectedOutput: 'fixture preserved\n',
            fixtures: {'data/input.txt': 'fixture preserved\n'},
          ),
        ],
        workspace: Directory(p.join(workspace.path, 'runs')),
        reportFile: file,
        toolchain: toolchain,
        shellPath: shell,
        runtimeIdentities: {
          'script': {'version': toolchain.version()},
          'shell': {'path': shell},
        },
        onProgress: (done, _, _) {
          final persisted = File('${file.path}.cases.jsonl').readAsLinesSync();
          expect(persisted, hasLength(done));
          checkpoints.add(done);
        },
      );
      expect(checkpoints, [1, 2, 3]);
      expect(report['executionComplete'], isTrue);
      expect(
        report['ok'],
        isFalse,
        reason: 'Old output missing LF must remain an exact mismatch',
      );
      expect(report['exactPassedCases'], 2);
      expect(report['terminalLinePassedCases'], 3);
      final rows = (report['caseResults'] as List).cast<Map>();
      expect(rows[0]['stdout'], '42\n');
      expect(rows[0]['expectedOutput'], '42');
      expect(rows[0]['passed'], isFalse);
      expect(rows[0]['terminalLinePassed'], isTrue);
      expect(rows[2]['inputFixtures'], {
        'data/input.txt': 'fixture preserved\n',
      });
      expect(
        rows.every((row) => row['writtenSourceSha256'] == row['sourceSha256']),
        isTrue,
      );
      expect(rows.every((row) => row['projectRemoved'] == true), isTrue);
      final persisted = decode(file.readAsStringSync());
      expect(persisted['caseResults'], hasLength(3));
      final journal = File(
        report['caseJournal'] as String,
      ).readAsLinesSync().map(decode).toList();
      expect(journal, hasLength(3));
      expect(journal.map((row) => row['id']), [
        'js-original',
        'ts-fixture',
        'sh-fixture',
      ]);
      expect(journal.last['source'], rows.last['source']);
      expect(Directory(p.join(workspace.path, 'runs')).listSync(), isEmpty);
    },
  );

  test(
    'identical payloads run separately and unsafe fixtures never write outside project',
    () async {
      const source = 'console.log(42);';
      final report = await runScriptContentAudit(
        cases: const [
          ScriptAcceptanceCase(
            language: 'javascript',
            kind: 'example',
            id: 'same1',
            asset: 'fixture',
            source: source,
            expectedOutput: '42\n',
          ),
          ScriptAcceptanceCase(
            language: 'javascript',
            kind: 'lesson',
            id: 'same2',
            asset: 'fixture',
            source: source,
            expectedOutput: '42\n',
          ),
          ScriptAcceptanceCase(
            language: 'javascript',
            kind: 'example',
            id: 'unsafe',
            asset: 'fixture',
            source: source,
            expectedOutput: '42\n',
            fixtures: {'../escape.txt': 'must not write'},
          ),
        ],
        workspace: Directory(p.join(workspace.path, 'runs')),
        reportFile: File(p.join(workspace.path, 'report.json')),
        toolchain: toolchain,
      );
      expect(report['exactPassedCases'], 2);
      final rows = (report['caseResults'] as List).cast<Map>();
      expect(rows.take(2).map((row) => row['stdout']), ['42\n', '42\n']);
      expect(rows.last['executionFinished'], isFalse);
      expect(rows.last['error'], contains('Unsafe fixture'));
      expect(
        File(p.join(workspace.path, 'runs', 'escape.txt')).existsSync(),
        isFalse,
      );
      expect(report['executionComplete'], isFalse);
    },
  );

  test(
    'missing engine or shell is a recorded failure rather than omitted content',
    () async {
      final report = await runScriptContentAudit(
        cases: const [
          ScriptAcceptanceCase(
            language: 'javascript',
            kind: 'example',
            id: 'missing-engine',
            asset: 'fixture',
            source: '',
            expectedOutput: '',
          ),
          ScriptAcceptanceCase(
            language: 'shell',
            kind: 'example',
            id: 'missing-shell',
            asset: 'fixture',
            source: 'printf bad',
            expectedOutput: '',
          ),
        ],
        workspace: Directory(p.join(workspace.path, 'runs')),
        reportFile: File(p.join(workspace.path, 'report.json')),
        toolchain: ScriptToolchain(
          libraryPath: p.join(workspace.path, 'missing.dll'),
        ),
      );
      final rows = (report['caseResults'] as List).cast<Map>();
      expect(rows, hasLength(2));
      expect(
        rows.every((row) => row['status'] == 127 && row['passed'] == false),
        isTrue,
      );
      expect(report['exactPassedCases'], 0);
      expect(report['terminalLinePassedCases'], 0);
    },
  );

  test(
    'real debugger acceptance covers nested stepping removal and paused close cleanup',
    () async {
      final report = await runScriptDebuggerProbe(
        workspace: workspace,
        libraryPath: Platform.environment['QFLI_LUA_LIBRARY'],
      );
      expect(report['ok'], isTrue, reason: jsonEncode(report));
      expect(report['checks'], hasLength(13));
      expect(
        (report['checks'] as List).last['stdout'],
        'cleanup\u0000preserved\n',
      );
      expect((report['checks'] as List).last['status'], 130);
      expect(report['projectRemoved'], isTrue);
      expect(workspace.listSync(), isEmpty);
    },
  );

  test(
    'real shared debugger adapter validates tokens output and cleanup',
    () async {
      final report = await runScriptStudioDebuggerProbe(
        workspace: workspace,
        libraryPath: Platform.environment['QFLI_LUA_LIBRARY'],
      );
      expect(report['ok'], isTrue, reason: jsonEncode(report));
      final checks = (report['checks'] as List).cast<Map>();
      expect(checks, hasLength(8));
      expect(
        checks.map((check) => check['id']),
        contains('shared-stale-token-rejected-without-execution'),
      );
      final stopped = checks.singleWhere(
        (check) => check['id'] == 'shared-stop-unwinds-close-and-worker-done',
      );
      expect(stopped['stdout'], 'cleanup\u0000preserved\n');
      expect(stopped['exitCode'], 130);
      expect(report['projectRemoved'], isTrue);
      expect(workspace.listSync(), isEmpty);
    },
  );

  test(
    'real dirty analyzers parse buffers preserve files and never execute effects',
    () async {
      final report = await runScriptDiagnosticsProbe(
        workspace: workspace,
        toolchain: toolchain,
        shellPath: await findPosixShell(),
      );
      expect(report['ok'], isTrue, reason: jsonEncode(report));
      expect(report['checks'], hasLength(9));
      expect(report['projectRemoved'], isTrue);
      expect(workspace.listSync(), isEmpty);
    },
  );

  test(
    'dirty analyzer probe canonicalizes a mixed-separator caller workspace',
    () async {
      final requested = Platform.isWindows
          ? '${workspace.path.replaceAll(r'\', '/')}${p.separator}mixed'
          : p.join(workspace.path, 'mixed');
      final caller = Directory(requested);
      if (Platform.isWindows) {
        expect(caller.path, contains('/'));
        expect(caller.path, contains(r'\'));
      }
      final report = await runScriptDiagnosticsProbe(
        workspace: caller,
        toolchain: toolchain,
        shellPath: await findPosixShell(),
      );
      expect(report['ok'], isTrue, reason: jsonEncode(report));
      expect(report['checks'], hasLength(9));
      expect(report['requestedWorkspacePath'], requested);
      final canonicalProjectPath = report['canonicalProjectPath'] as String;
      expect(canonicalProjectPath, p.normalize(canonicalProjectPath));
      expect(p.isAbsolute(canonicalProjectPath), isTrue);
      expect(
        p.isWithin(await caller.resolveSymbolicLinks(), canonicalProjectPath),
        isTrue,
      );
      expect(report['projectRemoved'], isTrue);
      expect(caller.listSync(), isEmpty);
    },
  );

  // Explicit opt-in only: normal unit runs neither register nor skip this audit.
  if (const bool.fromEnvironment('SCRIPT_FULL_ACCEPTANCE')) {
    TestWidgetsFlutterBinding.ensureInitialized();
    test(
      'full packaged1282 host runtime acceptance',
      () async {
        final reportFile = File(
          p.absolute('build/offline-ide-audit/script-host-current.json'),
        );
        final runs = Directory(
          p.absolute('build/offline-ide-audit/script-host-runs'),
        );
        await runs.create(recursive: true);
        final ownedRun = await runs.createTemp('run-');
        final report = await auditBundledScriptAcceptance(
          workspace: ownedRun,
          reportFile: reportFile,
          bundle: rootBundle,
        );
        final rows = (report['caseResults'] as List).cast<Map>();
        expect(report['coverageGatePassed'], isTrue, reason: reportFile.path);
        expect(report['executionComplete'], isTrue, reason: reportFile.path);
        expect(
          report['runtimeIdentityGatePassed'],
          isTrue,
          reason: reportFile.path,
        );
        expect(
          report['current480LuaExactGatePassed'],
          isTrue,
          reason: reportFile.path,
        );
        expect(
          report['allShippedTerminalLineGatePassed'],
          isTrue,
          reason: reportFile.path,
        );
        expect(
          (report['debuggerProbe'] as Map)['ok'],
          isTrue,
          reason: reportFile.path,
        );
        expect(
          (report['studioDebuggerProbe'] as Map)['ok'],
          isTrue,
          reason: reportFile.path,
        );
        expect(
          (report['diagnosticsProbe'] as Map)['ok'],
          isTrue,
          reason: reportFile.path,
        );
        expect(rows, hasLength(1282));
        expect(report['executedCases'], 1282);
        final offlinePlatform = report['offlinePlatformProbe'] as Map;
        if (Platform.operatingSystem == 'ohos') {
          expect(offlinePlatform['evaluated'], isTrue);
          expect(offlinePlatform['ok'], isTrue, reason: reportFile.path);
          expect(offlinePlatform['nativeEvidence'], isTrue);
          expect(report['offlinePlatformGatePassed'], isTrue);
        } else {
          expect(offlinePlatform['status'], 'not_evaluated');
          expect(offlinePlatform['evaluated'], isFalse);
          expect(offlinePlatform['ok'], isFalse);
          expect(report['offlinePlatformGatePassed'], isFalse);
        }
        final mismatches = rows
            .where((row) => row['stdout'] != row['expectedOutput'])
            .toList();
        expect(
          mismatches,
          isNotEmpty,
          reason: 'Retain original expected-output final-LF mismatches',
        );
        expect(mismatches.every((row) => row['passed'] == false), isTrue);
        expect(report['allShippedExactGatePassed'], isFalse);
        expect(report['ok'], isFalse);
        expect(File(report['luaReportPath'] as String).existsSync(), isTrue);
        expect(
          File(report['scriptCaseJournal'] as String).readAsLinesSync(),
          hasLength(600),
        );
        expect(
          report['deviceGatePassed'],
          Platform.operatingSystem == 'ohos' &&
              report['allShippedExactGatePassed'] == true &&
              report['offlinePlatformGatePassed'] == true,
        );
        expect(
          report['terminalLineDeviceGatePassed'],
          Platform.operatingSystem == 'ohos' &&
              report['allShippedTerminalLineGatePassed'] == true &&
              report['offlinePlatformGatePassed'] == true,
        );
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  }
}
