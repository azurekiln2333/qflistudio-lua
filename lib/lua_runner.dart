import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/process_supervisor.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'lua_toolchain.dart';
import 'script_toolchain.dart';
import 'shell_code_analyzer.dart' show findPosixShell;

/// Runtime adapter for the shared scripting product.
class LuaProgramRunner implements ProgramRunner {
  const LuaProgramRunner({
    this.toolchain = const LuaToolchain(),
    this.scriptToolchain = const ScriptToolchain(),
    this.operatingSystem,
    this.shellFinder = findPosixShell,
    this.processSupervisor,
  });

  final LuaToolchain toolchain;
  final ScriptToolchain scriptToolchain;

  /// Test seam for [Platform.operatingSystem]. Null keeps the real host value.
  ///
  /// There is deliberately no public global override; only this runner's
  /// platform selection reads the injected value.
  final String? operatingSystem;

  /// Discovers a local POSIX shell. Tests may inject a finder seam.
  final Future<String?> Function() shellFinder;

  /// Optional Shell lifecycle owner. Null keeps the shared product supervisor.
  final ProcessSupervisor? processSupervisor;

  /// Host systems that can launch a discovered POSIX shell.
  ///
  /// Android is included because `findPosixShell` probes `/system/bin/sh` and
  /// `/bin/sh` there. Lua and Script never consult this set.
  static const Set<String> _shellPlatforms = {
    'windows',
    'linux',
    'macos',
    'ohos',
    'android',
  };

  String get _hostOperatingSystem =>
      operatingSystem ?? Platform.operatingSystem;

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
    if (extension == '.js' || extension == '.mjs' || extension == '.ts') {
      return _runScript(projectPath, entryFile);
    }
    if (!_shellPlatforms.contains(_hostOperatingSystem)) {
      return _notReady(extension: extension, fileName: p.basename(entryFile));
    }

    final command = await _commandFor(extension, entryFile);
    if (command == null) {
      return _notReady(extension: extension, fileName: p.basename(entryFile));
    }
    RandomAccessFile? input;
    final inputPath = p.join(projectPath, 'input.txt');
    try {
      final type = await FileSystemEntity.type(inputPath);
      if (type == FileSystemEntityType.file) {
        input = await File(inputPath).open();
      } else if (type != FileSystemEntityType.notFound) {
        throw FileSystemException(
          'Shell project input.txt must be a regular file',
          inputPath,
        );
      }
    } catch (error) {
      return ProgramRunResult(
        title: '${p.basename(command.first)} ${p.basename(entryFile)}',
        stdout: const Stream<String>.empty(),
        stderr: Stream<String>.value(
          'sh: cannot open project input.txt: $error',
        ),
        exitCode: Future.value(kProgramNotRunExitCode),
      );
    }
    try {
      final process = await (processSupervisor ?? _processSupervisor).start(
        command.first,
        command.skip(1).toList(growable: false),
        workingDirectory: projectPath,
        runInShell: false,
      );
      return _ShellRun(
        process,
        input,
        '${p.basename(command.first)} ${p.basename(entryFile)}',
      ).result;
    } on ProcessException {
      await input?.close();
      // `which`/`where` found an executable but launching it failed. Report the
      // actual selected command instead of claiming the runtime is missing.
      return _notReady(
        extension: extension,
        fileName: p.basename(entryFile),
        command: command,
      );
    } catch (_) {
      await input?.close();
      rethrow;
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
        title: 'lua ${p.basename(entryFile)}',
        stdout: const Stream<String>.empty(),
        stderr: Stream<String>.value('lua: $error'),
        exitCode: Future<int>.value(kProgramNotRunExitCode),
      );
    }
    return _embeddedResult(
      title: 'lua ${p.basename(entryFile)}',
      result: execution.result.then(
        (value) =>
            (status: value.status, output: value.output, error: value.error),
      ),
      cancel: execution.cancel,
    );
  }

  ProgramRunResult _runScript(String projectPath, String entryFile) {
    final title =
        '${p.extension(entryFile).toLowerCase() == '.ts' ? 'typescript' : 'javascript'} ${p.basename(entryFile)}';
    try {
      final execution = scriptToolchain.startRun(
        file: entryFile,
        projectDirectory: projectPath,
      );
      return _embeddedResult(
        title: title,
        result: execution.result.then(
          (value) =>
              (status: value.status, output: value.output, error: value.error),
        ),
        cancel: execution.cancel,
      );
    } catch (error) {
      return ProgramRunResult(
        title: title,
        stdout: const Stream<String>.empty(),
        stderr: Stream<String>.value('Script runtime unavailable: $error'),
        exitCode: Future<int>.value(kProgramNotRunExitCode),
      );
    }
  }

  ProgramRunResult _embeddedResult({
    required String title,
    required Future<({int status, String output, String error})> result,
    required Future<void> Function() cancel,
  }) {
    final stdout = StreamController<String>();
    final stderr = StreamController<String>();
    final completion = Completer<int>();
    unawaited(() async {
      try {
        final value = await result;
        for (final line in const LineSplitter().convert(value.output)) {
          stdout.add(line);
        }
        for (final line in const LineSplitter().convert(value.error)) {
          stderr.add(line);
        }
        completion.complete(value.status);
      } catch (error) {
        stderr.add('$title: $error');
        completion.complete(kProgramNotRunExitCode);
      } finally {
        await stdout.close();
        await stderr.close();
      }
    }());
    return ProgramRunResult(
      title: title,
      stdout: stdout.stream,
      stderr: stderr.stream,
      exitCode: completion.future,
      cancel: cancel,
    );
  }

  Future<List<String>?> _commandFor(String extension, String entryFile) async {
    if (extension != '.sh') return null;
    final executable = await shellFinder();
    return executable == null ? null : [executable, entryFile];
  }

  /// Reports that a run never started, with a concise host diagnostic.
  ///
  /// [command] is the executable that was actually selected but failed to
  /// launch; when it is null, no runtime was discovered for [extension].
  ProgramRunResult _notReady({
    required String extension,
    required String fileName,
    List<String>? command,
  }) {
    final controller = StreamController<String>();
    scheduleMicrotask(() {
      final selected = command;
      final String message;
      if (selected != null) {
        message = '${selected.first}: failed to start';
      } else if (_shellPlatforms.contains(_hostOperatingSystem)) {
        message = '${_runtimeName(extension)} runtime is unavailable';
      } else {
        message =
            '${_runtimeName(extension)} runtime is unavailable on this platform';
      }
      controller
        ..add(message)
        ..close();
    });
    return ProgramRunResult(
      title: command?.join(' ') ?? _commandLine(extension, fileName),
      stdout: controller.stream,
      stderr: const Stream<String>.empty(),
      exitCode: Future<int>.value(kProgramNotRunExitCode),
    );
  }

  /// Conventional English command line for [fileName], matching how the shared
  /// terminal renders a run header (`lua main.lua`, `node app.js`).
  String _commandLine(String extension, String fileName) => switch (extension) {
    '.lua' || '.luac' => 'lua $fileName',
    '.js' || '.mjs' => 'node $fileName',
    '.ts' => 'deno run $fileName',
    '.sh' => 'sh $fileName',
    _ => fileName,
  };

  /// Human-readable language name used when no runtime is available.
  String _runtimeName(String extension) => switch (extension) {
    '.lua' || '.luac' => 'Lua',
    '.js' || '.mjs' => 'JavaScript',
    '.ts' => 'TypeScript',
    '.sh' => 'Shell',
    _ => 'Script',
  };
}

/// Owns Shell input and observes the supervisor's real exit and output streams.
/// Cancellation never closes those observations early. Supervisor cancellation
/// alone is not proof that every Windows descendant exited; acceptance still
/// requires the external private-Job terminal/empty verification.
class _ShellRun {
  _ShellRun(this.process, this.input, this.title) {
    const decoder = Utf8Decoder(allowMalformed: true);
    process.stdout
        .transform(decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!_finished) _stdout.add(line);
          },
          onError: (Object error) => _error('sh: stdout: $error'),
          onDone: () => _complete(_outDone),
        );
    process.stderr
        .transform(decoder)
        .transform(const LineSplitter())
        .listen(
          _error,
          onError: (Object error) => _error('sh: stderr: $error'),
          onDone: () => _complete(_errDone),
        );
    _inputDone = _feedInput();
    unawaited(_observe());
  }

  final ManagedProcess process;
  final RandomAccessFile? input;
  final String title;
  final _stdout = StreamController<String>();
  final _stderr = StreamController<String>();
  final _completion = Completer<int>();
  final _outDone = Completer<void>(), _errDone = Completer<void>();
  late final Future<void> _inputDone;
  Future<void>? _stopFuture;
  bool _stopping = false, _cancelled = false, _inputFailed = false;
  bool _finished = false;

  ProgramRunResult get result => ProgramRunResult(
    title: title,
    stdout: _stdout.stream,
    stderr: _stderr.stream,
    exitCode: _completion.future,
    cancel: cancel,
  );

  void _error(String text) {
    if (!_finished) _stderr.add(text);
  }

  Future<void> _feedInput() async {
    try {
      final file = input;
      while (file != null && !_stopping) {
        final bytes = await file.read(64 * 1024);
        if (bytes.isEmpty || _stopping) break;
        try {
          process.stdin.add(bytes);
          await process.stdin.flush();
        } catch (_) {
          // Early stdin closure must not replace the program's real exit code.
          break;
        }
      }
    } catch (error) {
      _inputFailed = true;
      _error('sh: cannot read project input.txt: $error');
      unawaited(_requestStop());
    } finally {
      try {
        await input?.close();
      } catch (error) {
        _inputFailed = true;
        _error('sh: cannot close project input.txt: $error');
      }
      try {
        await process.stdin.close();
      } catch (_) {
        // Includes a child that closed its input before this feed finished.
      }
    }
  }

  Future<void> _observe() async {
    int? status;
    Object? failure;
    StackTrace? failureStack;
    try {
      status = await process.exitCode;
    } catch (error, stackTrace) {
      failure = error;
      failureStack = stackTrace;
      _error('sh: process failed: $error');
    }
    // A failed cancellation never substitutes for actual input/stream closure.
    // Keep these observations alive even if the caller's Stop has rejected.
    await _inputDone;
    await Future.wait([_outDone.future, _errDone.future]);
    final stop = _stopFuture;
    if (stop != null) {
      try {
        await stop;
      } catch (error, stackTrace) {
        failure = error;
        failureStack = stackTrace;
      }
    }
    if (failure != null) {
      _finishError(failure, failureStack!);
    } else {
      _finish(_cancelled ? 130 : (_inputFailed ? 1 : status!));
    }
  }

  Future<void> cancel() {
    final stop = _stopFuture;
    if (stop != null) return stop;
    if (_finished) return Future<void>.value();
    _cancelled = true;
    return _requestStop();
  }

  Future<void> _requestStop() {
    final existing = _stopFuture;
    if (existing != null) return existing;
    final stop = _stop();
    _stopFuture = stop;
    // Input-read failures request Stop without a caller awaiting it. Attach an
    // error observer now, while returning the original failed future to callers
    // and retaining it for _observe. The supervisor caches a failed attempt too;
    // resetting this adapter alone would not provide a real cleanup retry.
    unawaited(
      stop.then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {},
      ),
    );
    return stop;
  }

  Future<void> _stop() async {
    _stopping = true;
    try {
      await process.cancel();
      await _inputDone;
      await Future.wait([_outDone.future, _errDone.future]);
    } catch (error) {
      _error('sh: cancellation failed: $error');
      rethrow;
    }
  }

  void _finishError(Object error, StackTrace stackTrace) {
    if (_finished) return;
    _finished = true;
    _completion.completeError(error, stackTrace);
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  void _finish(int code) {
    if (_finished) return;
    _finished = true;
    _completion.complete(code);
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }

  static void _complete(Completer<void> completion) {
    if (!completion.isCompleted) completion.complete();
  }
}
