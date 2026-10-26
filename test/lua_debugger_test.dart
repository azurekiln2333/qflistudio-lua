import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_debugger.dart';
import 'package:qfli_lua/lua_toolchain.dart';

const _library = String.fromEnvironment('QFLI_LUA_TEST_LIBRARY');

void main() {
  late Directory project;
  final sessions = <LuaDebugger>[];
  setUp(() {
    project = Directory.systemTemp.createTempSync('lua_debug_中文_');
  });
  tearDown(() async {
    for (final session in sessions) {
      await session.dispose();
    }
    sessions.clear();
    project.deleteSync(recursive: true);
  });

  Future<LuaDebugger> start(
    String source, {
    Duration limit = const Duration(seconds: 2),
  }) async {
    final file = File(p.join(project.path, 'main.lua'))
      ..writeAsStringSync(source);
    final session = await LuaDebugger.start(
      file: file.path,
      projectDirectory: project.path,
      libraryPath: _library.isEmpty ? null : _library,
      timeLimit: limit,
    );
    sessions.add(session);
    return session;
  }

  test(
    'initial source stop is before side effects; locals do not stringify tables',
    () async {
      final session = await start('''
local n = 40
local object = setmetatable({}, {__tostring = function() error('must not inspect') end})
n = n + 2
print(n)
''');
      expect(session.snapshot.state, LuaDebugState.paused);
      expect(session.snapshot.frames.first.line, 1);
      expect(session.snapshot.frames.first.fileBacked, isTrue);
      expect(session.snapshot.frames.first.localsTruncated, isFalse);
      expect(session.snapshot.framesTruncated, isFalse);
      expect(session.snapshot.stdout, isEmpty);
      await session.resume(LuaDebugAction.stepInto);
      expect(session.snapshot.frames.first.line, 2);
      expect(
        session.snapshot.frames.first.locals
            .singleWhere((v) => v.name == 'n')
            .value,
        '40',
      );
      await session.resume(LuaDebugAction.stepOver);
      expect(session.snapshot.frames.first.line, 3);
      expect(
        session.snapshot.frames.first.locals
            .singleWhere((v) => v.name == 'object')
            .type,
        'table',
      );
      final done = await session.resume();
      expect(done.state, LuaDebugState.terminated);
      expect(done.status, 0, reason: done.stderr);
      expect(done.stdout, '42\n');
    },
  );

  test(
    'breakpoints stop on an absolute file/line and can be removed while paused',
    () async {
      final session = await start('local n = 1\nn = n + 1\nprint(n)\n');
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 3),
      ]);
      final paused = await session.resume();
      expect(paused.frames.first.line, 3);
      expect(paused.stdout, isEmpty);
      expect(
        paused.frames.first.locals.singleWhere((v) => v.name == 'n').value,
        '2',
      );
      await session.setBreakpoints([]);
      final done = await session.resume();
      expect(done.status, 0);
      expect(done.stdout, '2\n');
    },
  );

  test('into, over and out follow real nested stack depth', () async {
    final session = await start('''
local function inner(v)
  local result = v + 1
  return result
end
local function outer(v)
  local answer = inner(v)
  return answer * 2
end
local result = outer(20)
print(result)
''');
    await session.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'main.lua'), 9),
    ]);
    await session.resume();
    expect(session.snapshot.frames.first.line, 9);
    await session.setBreakpoints([]);
    await session.resume(LuaDebugAction.stepInto);
    expect(session.snapshot.frames.first.line, 6);
    expect(session.snapshot.frames.length, 2);
    await session.resume(LuaDebugAction.stepInto);
    expect(session.snapshot.frames.first.line, 2);
    expect(session.snapshot.frames.length, 3);
    expect(
      session.snapshot.frames.first.locals
          .singleWhere((v) => v.name == 'v')
          .value,
      '20',
    );
    await session.resume(LuaDebugAction.stepOut);
    expect(session.snapshot.frames.first.line, 7);
    expect(session.snapshot.frames.length, 2);
    await session.resume(LuaDebugAction.stepOut);
    expect(session.snapshot.frames.first.line, 10);
    expect(session.snapshot.frames.length, 1);
    expect((await session.resume()).stdout, '42\n');
  });

  test(
    'step over executes nested calls without stopping inside them',
    () async {
      final session = await start(
        'local function f()\n  return 42\nend\nlocal n = f()\nprint(n)\n',
      );
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 4),
      ]);
      await session.resume();
      await session.setBreakpoints([]);
      final paused = await session.resume(LuaDebugAction.stepOver);
      expect(paused.frames.first.line, 5);
      expect(paused.frames.length, 1);
      expect(
        paused.frames.first.locals.singleWhere((v) => v.name == 'n').value,
        '42',
      );
    },
  );

  test('stop while paused never executes the pending source line', () async {
    final session = await start(
      "assert(io.open('marker.txt', 'w'))\nprint('bad')\n",
    );
    final stopped = await session.stop();
    expect(stopped.status, 130);
    expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
    expect(stopped.stdout, isEmpty);
  });

  test('paused stop unwinds close locals and reports close failures', () async {
    final session = await start('''
local closer <close> = setmetatable({}, {__close = function()
  print('closing' .. string.char(0) .. 'local')
  error('close failure')
end})
print('must not execute')
''');
    await session.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'main.lua'), 5),
    ]);
    await session.resume();
    final stopped = await session.stop();
    expect(stopped.status, 130);
    expect(stopped.stdout, 'closing\u0000local\n');
    expect(stopped.stderr, contains('close failure'));
  });

  test('debugger finalizer exit status matches normal runtime', () async {
    final session = await start('''
collectgarbage('stop')
retained = setmetatable({}, {__gc = function() os.exit(9) end})
''');
    expect((await session.resume()).status, 9);
  });

  test(
    'pause and stop interrupt a real running VM; dispose is reusable',
    () async {
      final session = await start('local n = 0\nwhile true do n = n + 1 end\n');
      final running = session.resume();
      session.pause();
      final paused = await running.timeout(const Duration(seconds: 2));
      expect(paused.state, LuaDebugState.paused);
      expect(paused.frames, isNotEmpty);
      final runningAgain = session.resume();
      final stopped = await session.stop().timeout(const Duration(seconds: 2));
      await runningAgain;
      expect(stopped.status, 130);
      final next = await start('print(42)');
      expect((await next.resume()).stdout, '42\n');
    },
  );

  test(
    'paused time is excluded but active VM execution still times out',
    () async {
      final session = await start(
        'local n = 1\nn = n + 1\nwhile true do end\n',
        limit: const Duration(milliseconds: 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final paused = await session.resume(LuaDebugAction.stepInto);
      expect(paused.state, LuaDebugState.paused);
      expect(paused.frames.first.line, 2);
      final done = await session.resume();
      expect(done.status, isNot(0));
      expect(done.stderr, contains('timed out'));
    },
  );

  test(
    'source errors, explicit exit and EOF preserve actual status/output',
    () async {
      final syntax = await start('local = invalid');
      expect(syntax.snapshot.state, LuaDebugState.terminated);
      expect(syntax.snapshot.status, isNot(0));
      expect(syntax.snapshot.stderr, contains('main.lua:1:'));
      final runtime = await start(
        "print('before')\nio.stderr:write('warning\\n')\nerror('failed')",
      );
      final failed = await runtime.resume();
      expect(failed.status, isNot(0));
      expect(failed.stdout, 'before\n');
      expect(failed.stderr, contains('warning\n'));
      expect(failed.stderr, contains('failed'));
      final exiting = await start('os.exit(7)');
      expect((await exiting.resume()).status, 7);
      final empty = await start('');
      expect((await empty.resume()).status, 0);
    },
  );

  test(
    'unsupported user coroutines and hook replacement fail honestly',
    () async {
      for (final source in [
        'coroutine.create(function() return 1 end)',
        'debug.sethook(function() end)',
      ]) {
        final session = await start(source);
        final done = await session.resume();
        expect(done.status, isNot(0));
        expect(done.stderr, contains('unavailable'));
      }
    },
  );

  test('binary main chunks and outside-root breakpoints are refused', () async {
    final source = File(p.join(project.path, 'source.lua'))
      ..writeAsStringSync('print(42)');
    final binary = p.join(project.path, 'binary.lua');
    final result = await LuaToolchain(
      libraryPath: _library.isEmpty ? null : _library,
    ).compile(source.path, binary);
    expect(result.status, 0);
    final session = await LuaDebugger.start(
      file: binary,
      projectDirectory: project.path,
      libraryPath: _library.isEmpty ? null : _library,
    );
    sessions.add(session);
    expect(session.snapshot.state, LuaDebugState.terminated);
    expect(session.snapshot.status, isNot(0));
    expect(session.snapshot.stderr, contains('binary chunk'));
    final normal = await start('print(42)');
    await expectLater(
      normal.setBreakpoints([
        LuaBreakpoint(p.join(project.parent.path, 'other.lua'), 1),
      ]),
      throwsArgumentError,
    );
  });

  test(
    'module function breakpoints are real; require initialization defers explicitly',
    () async {
      final module = File(p.join(project.path, 'helper.lua'))
        ..writeAsStringSync(
          'local n = 21\nreturn function()\n  return n * 2\nend\n',
        );
      final session = await start(
        "local helper = require('helper')\nlocal n = helper()\nprint(n)\n",
      );
      await session.setBreakpoints([LuaBreakpoint(module.path, 1)]);
      final deferred = await session.resume();
      expect(deferred.state, LuaDebugState.paused);
      expect(deferred.stderr, contains('stop deferred'));
      expect(deferred.frames.first.file, p.join(project.path, 'main.lua'));
      await session.setBreakpoints([LuaBreakpoint(module.path, 3)]);
      final inModule = await session.resume();
      expect(inModule.frames.first.file, module.path);
      expect(inModule.frames.first.line, 3);
      expect((await session.resume()).stdout, '42\n');
    },
  );

  test(
    'older breakpoint acknowledgement never overwrites a running state',
    () async {
      final session = await start('local n = 1\nwhile true do n = n + 1 end\n');
      final changes = session.setBreakpoints([]);
      final running = session.resume();
      await changes;
      expect(session.snapshot.state, LuaDebugState.running);
      await session.stop();
      expect((await running).status, 130);
    },
  );

  test('dispose awaits actual worker exit in every VM state', () async {
    for (final state in [
      LuaDebugState.paused,
      LuaDebugState.running,
      LuaDebugState.terminated,
    ]) {
      final session = await start(
        state == LuaDebugState.running ? 'while true do end' : 'print(42)',
      );
      Future<LuaDebugSnapshot>? running;
      if (state == LuaDebugState.running) {
        running = session.resume();
      } else if (state == LuaDebugState.terminated) {
        await session.resume();
      }
      expect(session.snapshot.state, state);
      var workerExited = false;
      final exited = session.workerExited.then((_) => workerExited = true);
      expect(workerExited, isFalse);
      final disposal = session.dispose();
      expect(identical(disposal, session.dispose()), isTrue);
      await disposal.timeout(const Duration(seconds: 2));
      expect(workerExited, isTrue, reason: 'dispose returned before onExit');
      await exited;
      if (running != null) expect((await running).status, 130);
      await session.dispose();
      expect(() => session.resume(), throwsStateError);
    }
  });

  test('dispose finishes paused close cleanup before worker exit', () async {
    final session = await start('''
local closer <close> = setmetatable({}, {__close = function()
  local file = assert(io.open('closed.txt', 'w'))
  file:write('closed')
  file:close()
end})
print('must not execute')
''');
    await session.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'main.lua'), 6),
    ]);
    await session.resume();
    await session.dispose();
    expect(
      File(p.join(project.path, 'closed.txt')).readAsStringSync(),
      'closed',
    );
    expect(session.snapshot.stdout, isEmpty);
    expect(session.snapshot.status, 130);
    await session.workerExited;
  });

  test('failed launch does not prevent a fresh worker from exiting', () async {
    final file = File(p.join(project.path, 'main.lua'))
      ..writeAsStringSync('print(42)');
    await expectLater(
      LuaDebugger.start(
        file: file.path,
        projectDirectory: project.path,
        libraryPath: p.join(project.path, 'missing-runtime-library'),
      ),
      throwsA(isA<ArgumentError>()),
    );
    final session = await start('print(42)');
    expect((await session.resume()).stdout, '42\n');
    await session.dispose();
    await session.workerExited;
  });

  test(
    'absolute-looking generated chunk labels are not file sources',
    () async {
      final label = p.join(project.path, 'forged.lua').replaceAll('\\', '/');
      File(label).writeAsStringSync("error('this file must not execute')");
      final session = await start('''
local generated = assert(load("local n = 41\\nreturn n + 1", ${jsonEncode(label)}))
local result = generated()
print(result)
''');
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 2),
      ]);
      await session.resume();
      await session.setBreakpoints([]);
      final generated = await session.resume(LuaDebugAction.stepInto);
      expect(generated.frames.first.file, label);
      expect(generated.frames.first.fileBacked, isFalse);
      expect(generated.frames.first.line, 1);
      expect(generated.frames.last.fileBacked, isTrue);
      expect((await session.resume()).stdout, '42\n');
    },
  );

  test(
    'local value truncation distinguishes exact and oversized byte lengths',
    () async {
      final session = await start('''
local exact = string.rep('a', 4096)
local oversized = string.rep('b', 4097)
print(#exact + #oversized)
''');
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 3),
      ]);
      final paused = await session.resume();
      final locals = paused.frames.first.locals;
      final exact = locals.singleWhere((local) => local.name == 'exact');
      final oversized = locals.singleWhere(
        (local) => local.name == 'oversized',
      );
      expect(exact.truncated, isFalse);
      expect(exact.value, 'a' * 4096);
      expect(oversized.truncated, isTrue);
      expect(oversized.value, '${'b' * 4096}…');
      expect(paused.frames.first.localsTruncated, isFalse);
    },
  );

  test('truncated primitive Unicode values retain complete scalars', () async {
    final session = await start('''
local text = 'a' .. string.rep(utf8.char(0x1f600), 2000)
print(#text)
''');
    await session.setBreakpoints([
      LuaBreakpoint(p.join(project.path, 'main.lua'), 2),
    ]);
    final paused = await session.resume();
    final text = paused.frames.first.locals.singleWhere(
      (v) => v.name == 'text',
    );
    expect(text.truncated, isTrue);
    expect(text.value, 'a${'😀' * 1023}…');
    expect(text.value, isNot(contains('\ufffd')));
  });

  test(
    'hidden loop locals still mark the native local-slot inspection cap',
    () async {
      final source = [
        for (var i = 0; i < 125; i++) 'local v$i = $i',
        'for index = 1, 1 do',
        '  print(v0)',
        'end',
      ].join('\n');
      final session = await start(source);
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 127),
      ]);
      final paused = await session.resume();
      expect(paused.frames.first.line, 127);
      expect(paused.frames.first.localsTruncated, isTrue);
      expect(paused.frames.first.locals, hasLength(125));
      expect(
        paused.frames.first.locals.any((local) => local.name == 'index'),
        isFalse,
      );
      expect(
        paused.frames.first.locals.any((local) => local.name.startsWith('(')),
        isFalse,
      );
    },
  );

  test(
    'deep real call stacks expose the native frame inspection cap',
    () async {
      final session = await start('''
local function recurse(n)
  if n == 0 then
    local reached = true
    print('deep')
    return 0
  end
  local result = recurse(n - 1)
  return result + 1
end
print(recurse(70))
''');
      await session.setBreakpoints([
        LuaBreakpoint(p.join(project.path, 'main.lua'), 4),
      ]);
      final paused = await session.resume();
      expect(paused.frames, hasLength(64));
      expect(paused.framesTruncated, isTrue);
      expect(paused.frames.every((frame) => frame.fileBacked), isTrue);
      final done = await session.resume();
      expect(done.framesTruncated, isFalse);
      expect(done.stdout, 'deep\n70\n');
      expect(done.status, 0);
    },
  );
}
