import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_runner.dart';
import 'package:qfli_lua/script_toolchain.dart';
import 'package:qfli_lua/shell_code_analyzer.dart';
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('shell_run_中文_😀_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  Future<ProgramRunResult> start(String source) async {
    expect(await findPosixShell(), isNotNull, reason: 'Real sh is required.');
    final entry = File(p.join(project.path, '示例(1).sh'))
      ..writeAsStringSync(source);
    return (await const LuaProgramRunner().run(
      projectPath: project.path,
      entryFile: entry.path,
    ))!;
  }

  Future<({int status, List<String> output, List<String> errors})> collect(
    ProgramRunResult result,
  ) async {
    final output = result.stdout.toList();
    final errors = result.stderr.toList();
    return (
      status: await result.exitCode.timeout(const Duration(seconds: 5)),
      output: await output.timeout(const Duration(seconds: 5)),
      errors: await errors.timeout(const Duration(seconds: 5)),
    );
  }

  Future<ProgramRunResult> startControlled(ProcessSupervisor supervisor) async {
    final entry = File(p.join(project.path, 'controlled.sh'))
      ..writeAsStringSync('exit 0\n');
    return (await LuaProgramRunner(
      processSupervisor: supervisor,
      shellFinder: () async => p.join(project.path, 'controlled-shell'),
      operatingSystem: 'linux',
    ).run(projectPath: project.path, entryFile: entry.path))!;
  }

  test(
    'pending Shell Stop retains one attempt and its output observations',
    () async {
      final child = _ShellProcessDouble();
      final treeEntered = Completer<void>();
      final treeRelease = Completer<bool>();
      final supervisor = _shellSupervisor(
        child,
        windows: true,
        terminate: (_) {
          treeEntered.complete();
          return treeRelease.future;
        },
      );
      final result = await startControlled(supervisor);
      final output = <String>[];
      var outputClosed = false;
      result.stdout.listen(output.add, onDone: () => outputClosed = true);
      final errors = result.stderr.toList();
      var completed = false;
      final completion = result.exitCode.then((code) {
        completed = true;
        return code;
      });
      final stop = result.cancel!();
      await treeEntered.future;
      expect(identical(result.cancel!(), stop), isTrue);
      child.emitOutput('still owned\n');
      await Future<void>.delayed(Duration.zero);
      expect(output, ['still owned']);
      expect(outputClosed, isFalse);
      expect(completed, isFalse);
      expect(supervisor.activeCount, 1);

      // Root exit alone cannot settle the still-pending tree cancellation.
      await child.finish(7);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(outputClosed, isFalse);
      expect(supervisor.activeCount, 1);
      treeRelease.complete(true);
      await stop;
      expect(await completion, 130);
      expect(await errors, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(outputClosed, isTrue);
      expect(supervisor.activeCount, 0);
    },
  );

  test(
    'failed Shell Stop propagates and retains observations until actual exit',
    () async {
      final failure = StateError('controlled termination failure');
      final child = _ShellProcessDouble(killFailure: failure);
      final supervisor = _shellSupervisor(child);
      final result = await startControlled(supervisor);
      final output = <String>[];
      var outputClosed = false;
      result.stdout.listen(output.add, onDone: () => outputClosed = true);
      final errors = result.stderr.toList();
      var completed = false;
      final completion = result.exitCode.then<Object>(
        (code) {
          completed = true;
          return code;
        },
        onError: (Object error, StackTrace stackTrace) {
          completed = true;
          return error;
        },
      );
      final stop = result.cancel!();
      await expectLater(stop, throwsA(same(failure)));
      expect(identical(result.cancel!(), stop), isTrue);
      expect(
        child.killCalls,
        1,
        reason: 'A cached failure is not a cleanup retry.',
      );
      child.emitOutput('after failed Stop\n');
      await Future<void>.delayed(Duration.zero);
      expect(output, ['after failed Stop']);
      expect(completed, isFalse);
      expect(outputClosed, isFalse);
      expect(supervisor.activeCount, 1);

      await child.finish(7);
      expect(await completion, same(failure));
      expect((await errors).join('\n'), contains('cancellation failed'));
      await Future<void>.delayed(Duration.zero);
      expect(outputClosed, isTrue);
      expect(supervisor.activeCount, 0);
    },
  );

  test('POSIX shell scripts run with sh/bash or report unavailable', () async {
    final project = Directory.systemTemp.createTempSync('lua_posix_');
    addTearDown(() => project.deleteSync(recursive: true));
    final script = File(p.join(project.path, 'main.sh'))
      ..writeAsStringSync(
        "#!/bin/sh\nvalue='POSIX works'\ncase \"\$value\" in\n"
        "  POSIX*) printf '%s\\n' \"\$value\" ;;\n  *) exit 3 ;;\nesac\n",
      );
    final probes = await Future.wait(
      ['sh', 'bash'].map(
        (name) => Process.run(Platform.isWindows ? 'where' : 'which', [
          name,
        ], runInShell: Platform.isWindows),
      ),
    );
    final available = probes.any((probe) => probe.exitCode == 0);
    final result = await const LuaProgramRunner().run(
      projectPath: project.path,
      entryFile: script.path,
    );
    expect(result, isNotNull);
    final out = result!.stdout.toList();
    final err = result.stderr.toList();
    final code = await result.exitCode;
    final stdout = await out;
    final stderr = await err;
    if (available) {
      expect(code, 0, reason: stderr.join('\n'));
      expect(stdout, ['POSIX works']);
      expect(result.title, matches(RegExp(r'^(?:sh|bash)(?:\.exe)? ')));
    } else {
      expect(code, 127);
      expect(stdout.join('\n'), contains('runtime is unavailable'));
    }
  });

  test('Android platform attempts the discovered POSIX shell', () async {
    final shell = await findPosixShell();
    if (shell == null) {
      markTestSkipped('A real POSIX shell is unavailable on this host.');
      return;
    }
    final project = Directory.systemTemp.createTempSync('lua_android_shell_');
    addTearDown(() => project.deleteSync(recursive: true));
    final script = File(p.join(project.path, 'main.sh'))
      ..writeAsStringSync("printf 'android shell\\n'\n");
    var discovered = 0;
    final runner = LuaProgramRunner(
      operatingSystem: 'android',
      shellFinder: () async {
        discovered++;
        return shell;
      },
    );
    final result = (await runner.run(
      projectPath: project.path,
      entryFile: script.path,
    ))!;
    final captured = await collect(result);
    expect(discovered, 1, reason: 'Android must reach shell discovery.');
    expect(captured.status, 0, reason: captured.errors.join('\n'));
    expect(captured.output, ['android shell']);
    expect(result.title, matches(RegExp(r'^(?:sh|bash)(?:\.exe)? main\.sh$')));
  });

  test('Android without a discovered shell reports 127', () async {
    final project = Directory.systemTemp.createTempSync('lua_android_none_');
    addTearDown(() => project.deleteSync(recursive: true));
    final script = File(p.join(project.path, 'main.sh'))
      ..writeAsStringSync("printf 'must not run\\n'\n");
    final runner = LuaProgramRunner(
      operatingSystem: 'android',
      shellFinder: () async => null,
    );
    final result = (await runner.run(
      projectPath: project.path,
      entryFile: script.path,
    ))!;
    final captured = await collect(result);
    expect(captured.status, kProgramNotRunExitCode);
    expect(captured.errors, isEmpty);
    final message = captured.output.join('\n');
    expect(message, contains('Shell runtime is unavailable'));
    expect(
      message,
      isNot(contains('on this platform')),
      reason: 'Android is a supported shell platform.',
    );
  });

  test('Unsupported platform reports unavailable without discovery', () async {
    final project = Directory.systemTemp.createTempSync('lua_web_shell_');
    addTearDown(() => project.deleteSync(recursive: true));
    final script = File(p.join(project.path, 'main.sh'))
      ..writeAsStringSync("printf 'must not run\\n'\n");
    var discovered = 0;
    final runner = LuaProgramRunner(
      operatingSystem: 'web',
      shellFinder: () async {
        discovered++;
        return null;
      },
    );
    final result = (await runner.run(
      projectPath: project.path,
      entryFile: script.path,
    ))!;
    final captured = await collect(result);
    expect(discovered, 0, reason: 'Unsupported platforms must not discover.');
    expect(captured.status, kProgramNotRunExitCode);
    expect(
      captured.output.join('\n'),
      contains('Shell runtime is unavailable on this platform'),
    );
  });

  test('missing input sends immediate EOF to a real shell read', () async {
    final result = await collect(
      await start('''
if IFS= read -r value; then
  exit 4
else
  printf 'EOF\\n'
fi
'''),
    );
    expect(result.status, 0, reason: result.errors.join('\n'));
    expect(result.output, ['EOF']);
  });

  test(
    'input.txt preserves Unicode tabs and an unterminated final line',
    () async {
      File(
        p.join(project.path, 'input.txt'),
      ).writeAsBytesSync(utf8.encode('中文\t😀\nfinal tail'));
      final result = await collect(
        await start(r'''
IFS= read -r first
IFS= read -r second
printf '%s|%s\n' "$first" "$second"
if IFS= read -r extra; then exit 5; fi
'''),
      );
      expect(result.status, 0, reason: result.errors.join('\n'));
      expect(result.output, ['中文\t😀|final tail']);
      expect(result.errors, isEmpty);
    },
  );

  test('input bytes and embedded NUL pass through to the real child', () async {
    File(
      p.join(project.path, 'input.txt'),
    ).writeAsBytesSync(utf8.encode('中文\u0000tail\n'));
    final result = await collect(await start('cat\n'));
    expect(result.status, 0, reason: result.errors.join('\n'));
    expect(result.output, ['中文\u0000tail']);
  });

  test('nonregular input fails before any source side effect', () async {
    Directory(p.join(project.path, 'input.txt')).createSync();
    final result = await collect(await start('printf ran > marker\n'));
    expect(result.status, kProgramNotRunExitCode);
    expect(result.errors.join('\n'), contains('regular file'));
    expect(File(p.join(project.path, 'marker')).existsSync(), isFalse);
  });

  test(
    'early exit does not hang on EPIPE or replace the real status',
    () async {
      File(
        p.join(project.path, 'input.txt'),
      ).writeAsBytesSync(List.filled(1024 * 1024, 65));
      final result = await collect(await start('exit 7\n'));
      expect(result.status, 7);
      expect(result.errors, isEmpty);
    },
  );

  test('Stop is bounded with blocked input and an ignored TERM', () async {
    File(
      p.join(project.path, 'input.txt'),
    ).writeAsBytesSync(List.filled(1024 * 1024, 65));
    final result = await start(
      "trap '' TERM\nprintf 'ready\\n'\nwhile :; do :; done\n",
    );
    final ready = Completer<void>();
    final done = Completer<void>();
    final output = <String>[];
    result.stdout.listen((line) {
      output.add(line);
      if (line == 'ready' && !ready.isCompleted) ready.complete();
    }, onDone: done.complete);
    final errors = result.stderr.toList();
    try {
      await ready.future.timeout(const Duration(seconds: 3));
      await result.cancel!().timeout(const Duration(seconds: 4));
      expect(await result.exitCode, 130);
      await done.future.timeout(const Duration(seconds: 1));
      expect(output, ['ready']);
      expect(await errors, isEmpty);
      await result.cancel!();
    } finally {
      await result.cancel!();
    }
  });

  test(
    'native Stop retains stdout and stderr emitted before cancellation',
    () async {
      final entry = File(p.join(project.path, 'main.lua'))
        ..writeAsStringSync('''
print('before')
io.stderr:write('warning\\n')
assert(io.open('ready', 'w')):close()
while true do end
''');
      final result = (await const LuaProgramRunner().run(
        projectPath: project.path,
        entryFile: entry.path,
      ))!;
      final captured = collect(result);
      final marker = File(p.join(project.path, 'ready'));
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      try {
        while (!marker.existsSync() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(marker.existsSync(), isTrue);
        await result.cancel!();
        final finished = await captured;
        expect(finished.status, 130);
        expect(finished.output, ['before']);
        expect(finished.errors, contains('warning'));
        expect(finished.errors.join('\n'), contains('cancelled'));
      } finally {
        await result.cancel!();
      }
    },
  );

  test(
    'uppercase TS title matches the actual embedded compiler route',
    () async {
      final entry = File(p.join(project.path, 'main.TS'))
        ..writeAsStringSync('const value: number = 42; console.log(value);');
      final runner = LuaProgramRunner(
        scriptToolchain: ScriptToolchain(
          typescriptCompilerPath: p.absolute('assets/runtime/typescript.js'),
        ),
      );
      final result = (await runner.run(
        projectPath: project.path,
        entryFile: entry.path,
      ))!;
      final captured = await collect(result);
      expect(result.title, 'typescript main.TS');
      expect(captured.status, 0, reason: captured.errors.join('\n'));
      expect(captured.output, ['42']);
    },
  );
}

/// No real process is launched or signalled by these lifecycle regressions.
class _ShellProcessDouble implements Process {
  _ShellProcessDouble({this.killFailure}) {
    _input.stream.listen((_) {});
  }

  final Object? killFailure;
  final _input = StreamController<List<int>>();
  final _output = StreamController<List<int>>();
  final _errors = StreamController<List<int>>();
  final _exit = Completer<int>();
  late final IOSink _stdin = IOSink(_input.sink);
  int killCalls = 0;

  @override
  int get pid => 424242;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => _output.stream;

  @override
  Stream<List<int>> get stderr => _errors.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalls++;
    final failure = killFailure;
    if (failure != null) throw failure;
    return false;
  }

  void emitOutput(String text) => _output.add(utf8.encode(text));

  Future<void> finish(int code) async {
    _exit.complete(code);
    await Future.wait([_output.close(), _errors.close()]);
  }
}

ProcessSupervisor _shellSupervisor(
  _ShellProcessDouble child, {
  bool windows = false,
  WindowsProcessTreeTerminator? terminate,
}) => ProcessSupervisor(
  processStarter:
      (
        executable,
        arguments, {
        workingDirectory,
        environment,
        includeParentEnvironment = true,
        runInShell = false,
        mode = ProcessStartMode.normal,
      }) async => child,
  isWindows: windows,
  windowsProcessTreeTerminator: terminate ?? (_) async => true,
);
