import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';

/// Non-destructive verifier: executes every Lua tutorial lesson and example
/// through the bundled Lua 5.4.8 runtime and compares stdout with the
/// declared output. Writes nothing into product assets.
Future<void> main(List<String> args) async {
  final core = args.isNotEmpty ? args[0] : r'D:/MyNewProjects/qfli_studio_core';
  final tutorials =
      jsonDecode(
            await File(
              p.join(core, 'assets/content/tutorials.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;
  final examples =
      jsonDecode(
            await File(
              p.join(core, 'assets/content/examples.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>;

  final tmp = Directory.systemTemp.createTempSync('lua_audit_');
  stdout.writeln('workspace: ${tmp.path}');
  stdout.writeln('runtime: ${const LuaToolchain().version()}');

  final rows = <Map<String, Object?>>[];

  Future<void> verify(
    String kind,
    String id,
    String code,
    String expected,
    Map<String, String> fixtures,
  ) async {
    final project = Directory(p.join(tmp.path, id))
      ..createSync(recursive: true);
    final file = File(p.join(project.path, 'main.lua'))
      ..writeAsStringSync(code);
    if (fixtures.isNotEmpty) {
      final stdin = fixtures['stdin'] ?? fixtures.values.first;
      File(p.join(project.path, 'input.txt')).writeAsStringSync(stdin);
    }
    LuaToolResult result;
    try {
      result = await const LuaToolchain().run(
        file: file.path,
        projectDirectory: project.path,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      rows.add({'kind': kind, 'id': id, 'status': 127, 'error': 'load: $e'});
      return;
    }
    final normalizedActual = result.output.replaceAll('\r\n', '\n').trimRight();
    final normalizedExpected = expected.replaceAll('\r\n', '\n').trimRight();
    rows.add({
      'kind': kind,
      'id': id,
      'status': result.status,
      'ok': result.status == 0 && normalizedActual == normalizedExpected,
      'output': normalizedActual,
      'expected': normalizedExpected,
      'error': result.error,
    });
  }

  for (final raw in tutorials['entries'] as List) {
    final e = raw as Map<String, dynamic>;
    if ((e['language'] as String?)?.toLowerCase() != 'lua') continue;
    for (final l in e['lessons'] as List) {
      final lesson = l as Map<String, dynamic>;
      await verify(
        'tutorial',
        e['id'] as String,
        lesson['code'] as String,
        (lesson['output'] ?? '') as String,
        const {},
      );
    }
  }
  for (final raw in examples['entries'] as List) {
    final e = raw as Map<String, dynamic>;
    if ((e['language'] as String?)?.toLowerCase() != 'lua') continue;
    final fixtures = ((e['inputFixtures'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    );
    await verify(
      'example',
      e['id'] as String,
      e['code'] as String,
      (e['expectedOutput'] ?? '') as String,
      fixtures,
    );
  }

  tmp.deleteSync(recursive: true);
  final ok = rows.where((r) => r['ok'] == true).length;
  final fail = rows.length - ok;
  stdout.writeln('verified=${rows.length} ok=$ok fail=$fail');
  final outFile = File(
    args.length > 1
        ? args[1]
        : r'.trellis/tasks/10-15-lua-store-readiness/research/lua-exec-results.json',
  );
  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'runtime': const LuaToolchain().version(),
      'verified': rows.length,
      'ok': ok,
      'fail': fail,
      'rows': rows,
    }),
  );
  stdout.writeln('wrote ${outFile.path}');
}
