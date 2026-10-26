import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_terminal_commands.dart';
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';
import 'package:qfli_studio_core/terminal/shell/shell_backend.dart';

const _library = String.fromEnvironment('QFLI_LUA_TEST_LIBRARY');

void main() {
  final toolchain = LuaToolchain(
    libraryPath: _library.isEmpty ? null : _library,
  );
  late Directory root;
  late Directory project;
  late SandboxShellBackend backend;
  late StreamSubscription<ShellChunk> subscription;
  late StringBuffer output;
  late StringBuffer errors;

  File write(String name, String source) {
    final file = File(p.join(project.path, name));
    file.parent.createSync(recursive: true);
    return file..writeAsStringSync(source);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('lua_terminal_');
    project = Directory(p.join(root.path, '中文项目 (终端)'))..createSync();
    backend = SandboxShellBackend(
      sandboxRoot: root.path,
      startDirectory: project.path,
      delegate: LuaTerminalDelegate(toolchain: toolchain).handle,
    );
    output = StringBuffer();
    errors = StringBuffer();
    subscription = backend.output.listen((chunk) {
      if (chunk.kind == OutputKind.stdout) output.write(chunk.text);
      if (chunk.kind == OutputKind.stderr) errors.write(chunk.text);
    });
  });

  tearDown(() async {
    await backend.shutdown();
    await subscription.cancel();
    root.deleteSync(recursive: true);
  });

  test('version and help report real VM and supported commands', () async {
    await backend.execute('lua -v');
    expect(backend.lastExitCode, 0);
    expect(output.toString(), '${toolchain.copyright()}\n');
    expect(errors.toString(), isEmpty);
    output.clear();
    await backend.execute('luac --help');
    expect(backend.lastExitCode, 0);
    expect(output.toString(), contains('-s'));
    expect(output.toString(), contains('-p'));
  });

  test(
    'Unicode script arguments, varargs, cwd modules and input share real VM',
    () async {
      write('input.txt', 'first\nsecond\n');
      write('src/answer.lua', 'return 42');
      write('脚本 (参数).lua', '''
print(arg[-2], arg[-1])
print(arg[0] .. '|' .. arg[1] .. '|' .. arg[2] .. '|' .. arg[3])
print(select('#', ...))
print((...))
print((require('answer')))
print(io.read('l'), io.stdin:read('l'))
''');
      await backend.execute('lua -v "脚本 (参数).lua" "你好 世界" "" "脚本 (参数).lua"');
      expect(backend.lastExitCode, 0, reason: errors.toString());
      expect(
        output.toString(),
        '${toolchain.copyright()}\n'
        'lua\t-v\n脚本 (参数).lua|你好 世界||脚本 (参数).lua\n'
        '3\n你好 世界\n42\nfirst\tsecond\n',
      );
    },
  );

  test(
    'double dash preserves negative arg indices and option-looking argv',
    () async {
      write('-entry.lua', "print(arg[-2], arg[-1], arg[0], arg[1], (...))");
      await backend.execute('lua -- -entry.lua -v');
      expect(backend.lastExitCode, 0);
      expect(output.toString(), 'lua\t--\t-entry.lua\t-v\t-v\n');
    },
  );

  test('parse checks multiple files without executing side effects', () async {
    write('side.lua', "assert(io.open('marker.txt', 'w')):write('bad')");
    write('bad.lua', 'local = invalid');
    await backend.execute('luac -p side.lua bad.lua');
    expect(backend.lastExitCode, isNot(0));
    expect(errors.toString(), contains('bad.lua:1:'));
    expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
    write('bad.lua', 'return 42');
    await backend.execute('luac -p side.lua bad.lua');
    expect(backend.lastExitCode, 0);
    expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
    expect(File(p.join(project.path, 'luac.out')).existsSync(), isFalse);
  });

  test(
    'compile, strip, parse and run bytecode after source deletion',
    () async {
      final source = write('main.lua', "local answer = 42\nprint(answer)");
      await backend.execute('luac main.lua');
      expect(backend.lastExitCode, 0, reason: errors.toString());
      final original = File(p.join(project.path, 'luac.out')).readAsBytesSync();
      expect(original.take(4), [27, 76, 117, 97]);
      await backend.execute('luac -s -o "编译 (结果).luac" main.lua');
      expect(backend.lastExitCode, 0);
      expect(
        File(p.join(project.path, '编译 (结果).luac')).lengthSync(),
        lessThan(original.length),
      );
      source.deleteSync();
      await backend.execute('luac -p luac.out "编译 (结果).luac"');
      expect(backend.lastExitCode, 0, reason: errors.toString());
      await backend.execute('lua "编译 (结果).luac"');
      expect(backend.lastExitCode, 0);
      expect(output.toString(), '42\n');
    },
  );

  test(
    'runtime errors retain both output streams and nonzero status',
    () async {
      write(
        'main.lua',
        "print('before')\nio.stderr:write('warning\\n')\nerror('failed')",
      );
      await backend.execute('lua main.lua');
      expect(backend.lastExitCode, isNot(0));
      expect(output.toString(), 'before\n');
      expect(errors.toString(), contains('warning\n'));
      expect(errors.toString(), contains('failed'));
    },
  );

  test('unsupported options and shell operators never execute Lua', () async {
    write('main.lua', "assert(io.open('marker.txt', 'w'))");
    for (final command in [
      'lua -e "print(1)"',
      'lua -i main.lua',
      'lua -l foo main.lua',
      'luac -l main.lua',
      'luac -o - main.lua',
      'luac main.lua main.lua',
    ]) {
      await backend.execute(command);
      expect(backend.lastExitCode, 127, reason: command);
    }
    await backend.execute('lua main.lua > output.txt');
    expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
    expect(File(p.join(project.path, 'output.txt')).existsSync(), isFalse);
  });

  test('command operands cannot escape sandbox', () async {
    write('main.lua', 'return 42');
    await backend.execute('lua ../../outside.lua');
    expect(backend.lastExitCode, 1);
    await backend.execute('luac -o ../../outside.luac main.lua');
    expect(backend.lastExitCode, 1);
    expect(errors.toString(), contains('沙盒'));
  });

  test(
    'missing runtime is 127, missing file is an actual file failure',
    () async {
      write('main.lua', 'print(42)');
      backend.delegate = LuaTerminalDelegate(
        toolchain: LuaToolchain(
          libraryPath: p.join(project.path, 'missing-library'),
        ),
      ).handle;
      await backend.execute('lua main.lua');
      expect(backend.lastExitCode, 127);
      backend.delegate = LuaTerminalDelegate(toolchain: toolchain).handle;
      await backend.execute('lua missing.lua');
      expect(backend.lastExitCode, 1);
    },
  );

  test(
    'timeout and immediate cancellation recover for the next command',
    () async {
      write('loop.lua', 'while true do end');
      backend.delegate = LuaTerminalDelegate(
        toolchain: toolchain,
        timeLimit: const Duration(milliseconds: 30),
      ).handle;
      await backend.execute('lua loop.lua');
      expect(backend.lastExitCode, isNot(0));
      expect(errors.toString(), contains('timed out'));
      final observed = _RecordingLuaToolchain(
        libraryPath: _library.isEmpty ? null : _library,
      );
      backend.delegate = LuaTerminalDelegate(toolchain: observed).handle;
      errors.clear();
      final running = backend.execute('lua loop.lua');
      await backend.interrupt();
      await running.timeout(const Duration(seconds: 3));
      expect(observed.execution, isNotNull);
      expect((await observed.execution!.result).status, 130);
      expect(errors.toString(), contains('cancelled'));
      expect(backend.busy, isFalse);
      // Shared terminals suppress the exit footer after a user interrupt.
      expect(backend.lastExitCode, isNull);
      write('main.lua', 'print(42)');
      await backend.execute('lua main.lua');
      expect(backend.lastExitCode, 0);
      expect(output.toString(), endsWith('42\n'));
    },
  );

  test(
    'source buffers parse without execution and retain explicit NUL length',
    () async {
      final valid = await toolchain.checkSource("error('must not execute')");
      expect(valid.status, 0);
      expect(valid.output, isEmpty);
      final bad = await toolchain.checkSource(
        'local = invalid',
        chunkName: '@未保存.lua',
      );
      expect(bad.status, 3);
      expect(bad.error, contains('未保存.lua:1:'));
      final nul = await toolchain.checkSource('return 1\u0000return 2');
      expect(nul.status, 3);
    },
  );

  test(
    'argv snapshots survive caller mutation and accept many arguments',
    () async {
      final source = write(
        'main.lua',
        "print(arg[1], arg[100], select('#', ...))",
      );
      final args = ['lua', 'main.lua', for (var i = 1; i <= 100; i++) '$i'];
      final execution = toolchain.startRun(
        file: source.path,
        projectDirectory: project.path,
        commandLine: args,
      );
      args[2] = 'mutated';
      final result = await execution.result;
      expect(result.status, 0, reason: result.error);
      expect(result.output, '1\t100\t100\n');
      expect(
        () => toolchain.startRun(
          file: source.path,
          projectDirectory: project.path,
          commandLine: ['lua'],
          scriptIndex: 2,
        ),
        throwsArgumentError,
      );
    },
  );
}

/// Observes the real VM result without replacing the native execution path.
class _RecordingLuaToolchain extends LuaToolchain {
  _RecordingLuaToolchain({super.libraryPath});

  LuaExecution? execution;

  @override
  LuaExecution startRun({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
    List<String> commandLine = const [],
    int scriptIndex = 1,
  }) {
    return execution = super.startRun(
      file: file,
      projectDirectory: projectDirectory,
      timeLimit: timeLimit,
      commandLine: commandLine,
      scriptIndex: scriptIndex,
    );
  }
}
