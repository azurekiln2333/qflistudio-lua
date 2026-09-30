import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String status;
  final directory = await Directory.systemTemp.createTemp('qfli_lua_probe_');
  try {
    final source = p.join(directory.path, 'main.lua');
    final bytecode = p.join(directory.path, 'main.luac');
    await File(source).writeAsString('print("lua-device-ok", 6 * 7)');
    const toolchain = LuaToolchain();
    final check = await toolchain.check(source);
    final compile = await toolchain.compile(source, bytecode);
    final run = await toolchain.run(
      file: bytecode,
      projectDirectory: directory.path,
    );
    if (!check.success ||
        !compile.success ||
        !run.success ||
        run.output.trim() != 'lua-device-ok\t42') {
      throw StateError(
        'check=${check.error}; compile=${compile.error}; run=${run.error}; output=${run.output}',
      );
    }
    status = 'QFLI_LUA_PROBE PASS ${toolchain.version()}';
  } catch (error) {
    status = 'QFLI_LUA_PROBE FAIL $error';
  } finally {
    await directory.delete(recursive: true);
  }
  debugPrint(status);
  runApp(
    MaterialApp(
      home: Scaffold(body: Center(child: Text(status))),
    ),
  );
}
