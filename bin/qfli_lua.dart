import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.first == '--help') {
    stdout.writeln(
      'Usage: dart run bin/qfli_lua.dart <run|check|compile|version> <file> [output.luac]',
    );
    return;
  }

  const toolchain = LuaToolchain();
  try {
    final command = arguments.first;
    if (command == 'version') {
      stdout.writeln(toolchain.version());
      return;
    }
    if (arguments.length < 2) {
      stderr.writeln('Missing Lua source or bytecode file.');
      exitCode = 2;
      return;
    }
    final file = p.normalize(p.absolute(arguments[1]));
    final LuaToolResult result;
    switch (command) {
      case 'run':
        result = await toolchain.run(
          file: file,
          projectDirectory: p.dirname(file),
        );
      case 'check':
        result = await toolchain.check(file);
      case 'compile':
        final output = arguments.length > 2
            ? p.normalize(p.absolute(arguments[2]))
            : p.setExtension(file, '.luac');
        result = await toolchain.compile(file, output);
        if (result.success) stdout.writeln(output);
      default:
        stderr.writeln('Unknown Lua command: $command');
        exitCode = 2;
        return;
    }
    if (result.output.isNotEmpty) stdout.write(result.output);
    if (result.error.isNotEmpty) stderr.writeln(result.error.trimRight());
    exitCode = result.status;
  } catch (error) {
    stderr.writeln('Lua toolchain failed: $error');
    exitCode = 127;
  }
}
