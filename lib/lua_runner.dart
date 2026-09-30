import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'lua_toolchain.dart';

/// Runtime adapter for the shared scripting product.
class LuaProgramRunner implements ProgramRunner {
  const LuaProgramRunner({this.toolchain = const LuaToolchain()});

  final LuaToolchain toolchain;

  static final ProcessSupervisor _processSupervisor = ProcessSupervisor();

  static const Set<String> _sourceExtensions = {
    '.lua',
    '.luac',
    '.js',
    '.mjs',
    '.ts',
    '.sh',
  };

  @override
  Future<ProgramRunResult?> run({
    required String projectPath,
    required String entryFile,
  }) async {
    final extension = p.extension(entryFile).toLowerCase();
    if (!_sourceExtensions.contains(extension)) return null;
    if (extension == '.lua' || extension == '.luac') {
      return _runLua(projectPath, entryFile);
    }
    final runtime = _runtimeName(extension);
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return _notReady(p.basename(entryFile), runtime);
    }

    final command = await _commandFor(extension, entryFile);
    if (command == null) return _notReady(p.basename(entryFile), runtime);
    try {
      final process = await _processSupervisor.start(
        command.first,
        command.skip(1).toList(growable: false),
        workingDirectory: projectPath,
        runInShell: Platform.isWindows,
      );
      return ProgramRunResult(
        title: '运行 ${p.basename(entryFile)}（$runtime）',
        stdout: process.stdout
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter()),
        stderr: process.stderr
            .transform(systemEncoding.decoder)
            .transform(const LineSplitter()),
        exitCode: process.exitCode,
        cancel: process.cancel,
      );
    } on ProcessException {
      return _notReady(p.basename(entryFile), runtime);
    }
  }

  ProgramRunResult _runLua(String projectPath, String entryFile) {
    final LuaExecution execution;
    try {
      execution = toolchain.startRun(
        file: entryFile,
        projectDirectory: projectPath,
      );
    } catch (error) {
      return ProgramRunResult(
        title: '运行 ${p.basename(entryFile)}（Lua 5.4）',
        stdout: const Stream<String>.empty(),
        stderr: Stream<String>.value('Lua 运行失败：$error'),
        exitCode: Future<int>.value(kProgramNotRunExitCode),
      );
    }
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final completion = Completer<int>();
    var canceled = false;
    unawaited(() async {
      try {
        final result = await execution.result;
        if (!canceled) {
          for (final line in const LineSplitter().convert(result.output)) {
            stdout.add(line);
          }
          for (final line in const LineSplitter().convert(result.error)) {
            stderr.add(line);
          }
        }
        completion.complete(result.status);
      } catch (error) {
        if (!canceled) stderr.add('Lua 运行失败：$error');
        completion.complete(kProgramNotRunExitCode);
      } finally {
        await stdout.close();
        await stderr.close();
      }
    }());
    return ProgramRunResult(
      title: '运行 ${p.basename(entryFile)}（Lua 5.4）',
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: completion.future,
      cancel: () async {
        canceled = true;
        await execution.cancel();
      },
    );
  }

  Future<List<String>?> _commandFor(String extension, String entryFile) async {
    final candidates = switch (extension) {
      '.js' || '.mjs' => const [
        ['node'],
        ['deno', 'run'],
      ],
      '.ts' => const [
        ['deno', 'run'],
        ['tsx'],
        ['ts-node'],
      ],
      '.sh' =>
        Platform.isWindows
            ? const [
                [
                  'powershell',
                  '-NoProfile',
                  '-ExecutionPolicy',
                  'Bypass',
                  '-File',
                ],
              ]
            : const [
                ['sh'],
                ['bash'],
              ],
      _ => const <List<String>>[],
    };
    for (final candidate in candidates) {
      final probe = await Process.run(Platform.isWindows ? 'where' : 'which', [
        candidate.first,
      ], runInShell: Platform.isWindows);
      if (probe.exitCode == 0) return [...candidate, entryFile];
    }
    return null;
  }

  ProgramRunResult _notReady(String fileName, String runtime) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      controller
        ..add(
          Platform.isWindows || Platform.isLinux || Platform.isMacOS
              ? '未找到 $runtime 运行环境，请安装后重试。'
              : '$runtime 脚本需要桌面端对应的运行环境。',
        )
        ..close();
    });
    return ProgramRunResult(
      title: '运行 $fileName（$runtime）',
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  String _runtimeName(String extension) => switch (extension) {
    '.lua' => 'Lua',
    '.js' || '.mjs' => 'JavaScript',
    '.ts' => 'TypeScript',
    '.sh' => 'Shell',
    _ => 'Script',
  };
}
