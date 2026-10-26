import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_debugger.dart';
import 'package:qfli_lua/lua_toolchain.dart';

void main() {
  const library = String.fromEnvironment('QFLI_LUA_TEST_LIBRARY');
  final toolchain = LuaToolchain(libraryPath: library.isEmpty ? null : library);
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lua_temp_中文_😀_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  File script(String name, String source) =>
      File(p.join(project.path, name))..writeAsStringSync(source);

  List<FileSystemEntity> temporaryFiles() => project
      .listSync()
      .where((entry) => p.basename(entry.path).startsWith('.qfli_tmp_'))
      .toList();

  test('tmpname precreates unique files inside the Unicode project', () async {
    final source = script('main.lua', '''
local names = {}
for i = 1, 64 do
  local path = os.tmpname()
  assert(not names[path])
  names[path] = true
  local file = assert(io.open(path, 'r+b'))
  assert(file:read('a') == '')
  file:write('owned')
  file:close()
  print(path)
end
''');
    final results = await Future.wait([
      for (var index = 0; index < 4; index++)
        toolchain.run(file: source.path, projectDirectory: project.path),
    ]);
    final paths = <String>[];
    for (final result in results) {
      expect(result.status, 0, reason: result.error);
      paths.addAll(result.output.trimRight().split('\n'));
    }
    expect(paths.toSet(), hasLength(256));
    for (final path in paths) {
      expect(p.isAbsolute(path), isTrue);
      expect(
        p.equals(p.dirname(path), project.resolveSymbolicLinksSync()),
        isTrue,
      );
      expect(File(path).readAsStringSync(), 'owned');
    }
    expect(temporaryFiles(), hasLength(256));
  });

  test(
    'tmpfile removes files after explicit close, GC and VM shutdown',
    () async {
      final source = script('main.lua', '''
local file = assert(io.tmpfile())
assert(io.type(file) == 'file')
file:write('中文', string.char(0), 'data')
assert(file:seek('set', 0) == 0)
assert(file:read('a') == '中文' .. string.char(0) .. 'data')
assert(file:close())
assert(io.type(file) == 'closed file')
do local collected = assert(io.tmpfile()); collected:write('gc') end
collectgarbage('collect')
retained = assert(io.tmpfile())
retained:write('shutdown')
print('done')
''');
      final result = await toolchain.run(
        file: source.path,
        projectDirectory: project.path,
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, 'done\n');
      expect(temporaryFiles(), isEmpty);
    },
  );

  test('unavailable project temp storage reports actual errors', () async {
    final source = script('main.lua', '''
local file, message, code = io.tmpfile()
assert(file == nil and type(message) == 'string' and type(code) == 'number')
local okay, problem = pcall(os.tmpname)
assert(not okay and problem:find('Lua project', 1, true))
print('unavailable')
''');
    final result = await toolchain.run(
      file: source.path,
      projectDirectory: p.join(project.path, 'missing'),
    );
    expect(result.status, 0, reason: result.error);
    expect(result.output, 'unavailable\n');
    expect(temporaryFiles(), isEmpty);
  });

  test(
    'running cancellation closes and removes retained temporary files',
    () async {
      final source = script('main.lua', '''
retained = assert(io.tmpfile())
retained:write('cancelled')
assert(io.open('ready', 'w')):close()
while true do end
''');
      final execution = toolchain.startRun(
        file: source.path,
        projectDirectory: project.path,
        timeLimit: const Duration(seconds: 5),
      );
      final marker = File(p.join(project.path, 'ready'));
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!marker.existsSync() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      try {
        expect(marker.existsSync(), isTrue);
        expect(temporaryFiles(), hasLength(1));
      } finally {
        await execution.cancel();
      }
      final result = await execution.result;
      expect(result.status, 130, reason: result.error);
      expect(temporaryFiles(), isEmpty);
    },
  );

  test(
    'debugger stop closes project temporaries before output snapshot',
    () async {
      final source = script('main.lua', '''
local name = os.tmpname()
assert(os.remove(name))
retained = assert(io.tmpfile())
retained:write('debug')
local finalizer <close> = setmetatable({}, {__close = function()
  print('closed' .. string.char(0) .. 'debug')
end})
print('must not run')
''');
      final session = await LuaDebugger.start(
        file: source.path,
        projectDirectory: project.path,
        libraryPath: library.isEmpty ? null : library,
      );
      try {
        await session.setBreakpoints([LuaBreakpoint(source.path, 8)]);
        final paused = await session.resume();
        expect(paused.state, LuaDebugState.paused);
        expect(temporaryFiles(), hasLength(1));
        final stopped = await session.stop();
        expect(stopped.status, 130);
        expect(stopped.stdout, 'closed\u0000debug\n');
        expect(temporaryFiles(), isEmpty);
      } finally {
        await session.dispose();
      }
    },
  );
}
