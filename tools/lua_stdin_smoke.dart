import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

Future<void> main(List<String> arguments) async {
  final engine = LuaToolchain(
    libraryPath: arguments.isEmpty ? null : arguments.single,
  );
  final root = await Directory.systemTemp.createTemp('qfli_lua_stdin_');
  final project = Directory(p.join(root.path, '\u6d4b\u8bd5\u8f93\u5165'));
  await project.create();
  final source = File(p.join(project.path, 'main.lua'));
  final input = File(p.join(project.path, 'input.txt'));
  final checks = <String>[];
  void check(bool condition, String name) {
    if (!condition) throw StateError(name);
    checks.add(name);
  }

  try {
    await source.writeAsString(
      "print(io.read('l'))\nprint(io.stdin:read('l'))\n"
      "assert(io.read('l') == nil)\n",
    );
    await input.writeAsString('first\nsecond');
    final run = await engine
        .run(file: source.path, projectDirectory: project.path)
        .timeout(const Duration(seconds: 10));
    check(run.success && run.output == 'first\nsecond\n', 'project-input');

    final artifact = p.join(project.path, 'main.luac');
    final compile = await engine.compile(source.path, artifact);
    check(compile.success && await File(artifact).exists(), 'compile');
    await source.delete();
    final bytecode = await engine
        .run(file: artifact, projectDirectory: project.path)
        .timeout(const Duration(seconds: 10));
    check(
      bytecode.success && bytecode.output == 'first\nsecond\n',
      'source-free-bytecode-input',
    );

    await input.delete();
    await source.writeAsString(
      "assert(io.read('a') == '')\nassert(io.stdin:read('l') == nil)\n"
      "print('EOF')\n",
    );
    final empty = await engine
        .run(file: source.path, projectDirectory: project.path)
        .timeout(const Duration(seconds: 10));
    check(empty.success && empty.output == 'EOF\n', 'missing-input-eof');

    await Directory(input.path).create();
    final invalid = await engine
        .run(file: source.path, projectDirectory: project.path)
        .timeout(const Duration(seconds: 10));
    check(
      !invalid.success &&
          invalid.output.isEmpty &&
          invalid.error.contains('regular file'),
      'non-regular-input-rejected',
    );
    await Directory(input.path).delete();
    final fresh = await engine
        .run(file: source.path, projectDirectory: project.path)
        .timeout(const Duration(seconds: 10));
    check(fresh.success && fresh.output == 'EOF\n', 'recovery');
    Zone.current.print(
      '[LUA_STDIN_SMOKE] ${jsonEncode({'ok': true, 'engine': engine.version(), 'checks': checks})}',
    );
  } catch (error, stack) {
    Zone.current.print(
      '[LUA_STDIN_SMOKE] ${jsonEncode({'ok': false, 'checks': checks, 'error': '$error', 'stack': '$stack'})}',
    );
    rethrow;
  } finally {
    await root.delete(recursive: true);
  }
}
