import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_debugger.dart';
import 'package:qfli_lua/lua_studio_debugger.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_debug_controller.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

const _library = String.fromEnvironment('QFLI_LUA_TEST_LIBRARY');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final provider = LuaStudioDebugger(
    libraryPath: _library.isEmpty ? null : _library,
    timeLimit: const Duration(seconds: 3),
  );
  late Directory project;
  final sessions = <DebugSession>[];

  setUp(() {
    project = Directory.systemTemp.createTempSync('lua_studio_中文_😀_');
  });
  tearDown(() async {
    for (final session in sessions) {
      await session.dispose();
    }
    sessions.clear();
    project.deleteSync(recursive: true);
  });

  File write(String name, String source) => File(p.join(project.path, name))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(source);

  DebugLaunchRequest request({
    String? root,
    String? entry,
    String language = 'Lua',
    List<CodeDocumentSnapshot> documents = const [],
    List<DebugBreakpoint> breakpoints = const [],
    bool stopOnEntry = true,
  }) => DebugLaunchRequest(
    projectPath: root ?? project.path,
    entryFilePath: entry ?? p.join(project.path, 'main.lua'),
    language: language,
    documents: documents,
    breakpoints: breakpoints,
    stopOnEntry: stopOnEntry,
  );

  Future<DebugSession> launch(
    String source, {
    List<DebugBreakpoint> breakpoints = const [],
    bool stopOnEntry = true,
  }) async {
    write('main.lua', source);
    final session = await provider.launch(
      request(breakpoints: breakpoints, stopOnEntry: stopOnEntry),
    );
    sessions.add(session);
    return session;
  }

  DebugBreakpoint mainBreakpoint(int line) =>
      DebugBreakpoint(filePath: p.join(project.path, 'main.lua'), line: line);

  test(
    'capabilities match the real backend and initial state is immutable',
    () async {
      expect(provider.supportsLanguage(' LUA '), isTrue);
      expect(provider.supportsLanguage('JavaScript'), isFalse);
      final capabilities = provider.capabilities;
      expect(capabilities.breakpointUpdate, DebugBreakpointUpdate.paused);
      expect(capabilities.outputDelivery, DebugOutputDelivery.pauseOrExit);
      expect(capabilities.supportsPause, isTrue);
      expect(capabilities.supportsStepInto, isTrue);
      expect(capabilities.supportsStepOver, isTrue);
      expect(capabilities.supportsStepOut, isTrue);
      expect(capabilities.supportsStopOnEntry, isTrue);
      expect(capabilities.supportsStackFrames, isTrue);
      expect(capabilities.supportsVariables, isTrue);
      expect(capabilities.supportsDocumentSnapshots, isFalse);
      final session = await launch('local n = 40\nn = n + 2\nprint(n)\n');
      final initial = session.snapshot;
      expect(initial.phase, DebugPhase.paused);
      expect(initial.pauseToken!.sessionId, session.id);
      expect(initial.frames.first.location!.line, 1);
      expect(
        initial.frames.first.location!.filePath,
        await File(p.join(project.path, 'main.lua')).resolveSymbolicLinks(),
      );
      expect(initial.stdout, isEmpty);
      expect(initial.exitCode, isNull);
      expect(initial.frames.first.threadId, initial.threads.single.id);
      expect(() => initial.frames.clear(), throwsUnsupportedError);
      expect(() => initial.threads.clear(), throwsUnsupportedError);
      expect(() => initial.breakpoints.clear(), throwsUnsupportedError);
      expect(() => initial.frames.first.locals.clear(), throwsUnsupportedError);
      final stepped = await _step(session, DebugCommand.stepInto);
      expect(stepped.frames.first.location!.line, 2);
      expect(
        stepped.frames.first.locals.singleWhere((v) => v.name == 'n').value,
        '40',
      );
      expect(initial.frames.first.location!.line, 1);
      expect(initial.pauseToken, isNot(stepped.pauseToken));
    },
  );

  test('into over and out follow actual nested frames and values', () async {
    final session = await launch(
      '''
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
''',
      breakpoints: [mainBreakpoint(9)],
    );
    var stopped = await _step(session, DebugCommand.resume);
    expect(stopped.frames.first.location!.line, 9);
    expect(stopped.breakpoints.single.status, DebugBreakpointStatus.verified);
    await session.setBreakpoints([]);
    stopped = await _step(session, DebugCommand.stepInto);
    expect(stopped.frames.first.location!.line, 6);
    expect(stopped.frames.length, 2);
    stopped = await _step(session, DebugCommand.stepInto);
    expect(stopped.frames.first.location!.line, 2);
    expect(stopped.frames.length, 3);
    expect(
      stopped.frames.first.locals.singleWhere((v) => v.name == 'v').value,
      '20',
    );
    stopped = await _step(session, DebugCommand.stepOut);
    expect(stopped.frames.first.location!.line, 7);
    stopped = await _step(session, DebugCommand.stepOut);
    expect(stopped.frames.first.location!.line, 10);
    await session.command(DebugCommand.resume, pauseToken: stopped.pauseToken);
    await session.done;
    expect(session.snapshot.stdout, '42\n');
    expect(session.snapshot.exitCode, 0);
  });

  test(
    'step over completes a nested call without stopping inside it',
    () async {
      final session = await launch(
        'local function f()\n  return 42\nend\nlocal n = f()\nprint(n)\n',
        breakpoints: [mainBreakpoint(4)],
      );
      await _step(session, DebugCommand.resume);
      await session.setBreakpoints([]);
      final stopped = await _step(session, DebugCommand.stepOver);
      expect(stopped.frames.first.location!.line, 5);
      expect(stopped.frames, hasLength(1));
      expect(
        stopped.frames.first.locals.singleWhere((v) => v.name == 'n').value,
        '42',
      );
    },
  );

  test(
    'cross-file launch breakpoint has a real canonical verified location',
    () async {
      final module = write(
        'helper.lua',
        'return function(v)\n  local result = v * 2\n  return result\nend\n',
      );
      final session = await launch(
        "local helper = require('helper')\nprint(helper(21))\n",
        stopOnEntry: false,
        breakpoints: [DebugBreakpoint(filePath: module.path, line: 3)],
      );
      final stopped = await _waitFor(
        session,
        (s) => s.phase == DebugPhase.paused,
      );
      final location = stopped.frames.first.location!;
      expect(location.filePath, await module.resolveSymbolicLinks());
      expect(location.line, 3);
      expect(
        stopped.frames.first.locals
            .singleWhere((v) => v.name == 'result')
            .value,
        '42',
      );
      expect(stopped.breakpoints.single.status, DebugBreakpointStatus.verified);
      expect(
        stopped.breakpoints.single.actualLocation!.filePath,
        location.filePath,
      );
      await session.command(
        DebugCommand.resume,
        pauseToken: stopped.pauseToken,
      );
      await session.done;
      expect(session.snapshot.stdout, '42\n');
    },
  );

  test(
    'entry breakpoint is respected even when stop on entry is false',
    () async {
      final session = await launch(
        "print('after entry')\n",
        breakpoints: [mainBreakpoint(1)],
        stopOnEntry: false,
      );
      expect(session.snapshot.phase, DebugPhase.paused);
      expect(session.snapshot.frames.first.location!.line, 1);
      expect(
        session.snapshot.breakpoints.single.status,
        DebugBreakpointStatus.verified,
      );
      expect(session.snapshot.stdout, isEmpty);
    },
  );

  test(
    'stale foreign missing tokens and unknown threads cannot change execution',
    () async {
      final session = await launch('local n = 1\nn = n + 1\nprint(n)\n');
      final old = session.snapshot.pauseToken!;
      final next = await _step(session, DebugCommand.stepInto);
      final revision = next.revision;
      for (final token in [
        old,
        null,
        DebugPauseToken(
          sessionId: 'foreign-session',
          generation: old.generation,
        ),
      ]) {
        await expectLater(
          session.command(DebugCommand.resume, pauseToken: token),
          throwsStateError,
        );
      }
      await expectLater(
        session.command(
          DebugCommand.resume,
          pauseToken: next.pauseToken,
          threadId: 'unknown',
        ),
        throwsArgumentError,
      );
      await expectLater(session.command(DebugCommand.pause), throwsStateError);
      expect(session.snapshot.revision, revision);
      expect(session.snapshot.pauseToken, next.pauseToken);
      expect(session.snapshot.stdout, isEmpty);
    },
  );

  test(
    'resume acknowledges dispatch while real pause and stop remain usable',
    () async {
      final session = await launch(
        'local n = 0\nwhile true do n = n + 1 end\n',
      );
      final token = session.snapshot.pauseToken;
      await session
          .command(DebugCommand.resume, pauseToken: token)
          .timeout(const Duration(milliseconds: 500));
      expect(session.snapshot.phase, DebugPhase.running);
      expect(session.snapshot.pauseToken, isNull);
      expect(session.snapshot.frames, isEmpty);
      await expectLater(session.setBreakpoints([]), throwsStateError);
      await session.command(DebugCommand.pause);
      final stopped = await _waitFor(
        session,
        (s) => s.phase == DebugPhase.paused,
      );
      expect(stopped.pauseToken, isNot(token));
      await session.command(
        DebugCommand.resume,
        pauseToken: stopped.pauseToken,
      );
      final stop = session.stop();
      expect(identical(stop, session.stop()), isTrue);
      await stop.timeout(const Duration(seconds: 3));
      await session.done;
      expect(session.snapshot.phase, DebugPhase.terminated);
      expect(session.snapshot.exitCode, 130);
      expect(session.snapshot.frames, isEmpty);
      expect(session.snapshot.pauseToken, isNull);
      final dispose = session.dispose();
      expect(identical(dispose, session.dispose()), isTrue);
      await dispose;
    },
  );

  test(
    'stop while paused waits for close cleanup without executing the pending line',
    () async {
      final session = await launch(
        "local closer <close> = setmetatable({}, {__close=function() print('closed') end})\n"
        "assert(io.open('must-not-exist.txt', 'w'))\n",
      );
      await _step(session, DebugCommand.stepOver);
      expect(session.snapshot.frames.first.location!.line, 2);
      await session.stop();
      await session.done;
      expect(session.snapshot.stdout, 'closed\n');
      expect(session.snapshot.exitCode, 130);
      expect(
        File(p.join(project.path, 'must-not-exist.txt')).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'full retained output snapshots have increasing revisions without duplication',
    () async {
      final session = await launch(
        "print('first')\nio.stderr:write('warning\\n')\nlocal n = 1\n"
        "print('second')\nlocal m = 2\nprint('third')\n",
        breakpoints: [mainBreakpoint(3), mainBreakpoint(5)],
      );
      final observed = <DebugSnapshot>[];
      final sub = session.updates.listen((snapshot) {
        expect(
          session.snapshot.revision,
          greaterThanOrEqualTo(snapshot.revision),
        );
        observed.add(snapshot);
      });
      addTearDown(sub.cancel);
      final first = await _step(session, DebugCommand.resume);
      expect(first.stdout, 'first\n');
      expect(first.stderr, 'warning\n');
      final second = await _step(session, DebugCommand.resume);
      expect(second.stdout, 'first\nsecond\n');
      expect(second.stderr, 'warning\n');
      expect(first.stdout, 'first\n');
      await session.command(DebugCommand.resume, pauseToken: second.pauseToken);
      await session.done;
      await Future<void>.delayed(Duration.zero);
      expect(session.snapshot.stdout, 'first\nsecond\nthird\n');
      expect(session.snapshot.stderr, 'warning\n');
      expect(observed.where((s) => s.isTerminal), hasLength(1));
      for (var i = 1; i < observed.length; i++) {
        expect(observed[i].revision, greaterThan(observed[i - 1].revision));
      }
    },
  );

  test(
    'output tails and primitive string truncation preserve Unicode and expose loss',
    () async {
      final session = await launch(
        "local text = string.rep('😀', 2000)\n"
        "print(string.rep('😀', 40000))\nlocal n = 1\nprint('tail')\n",
        breakpoints: [mainBreakpoint(3)],
      );
      final stopped = await _step(session, DebugCommand.resume);
      final text = stopped.frames.first.locals.singleWhere(
        (v) => v.name == 'text',
      );
      expect(text.truncated, isTrue);
      expect(text.unavailableReason, isNull);
      expect(utf8.decode(utf8.encode(text.value)), text.value);
      expect(text.value, isNot(contains('\uFFFD')));
      expect(stopped.stdoutTruncated, isTrue);
      expect(stopped.stdout.length, lessThanOrEqualTo(64 * 1024));
      expect(utf8.decode(utf8.encode(stopped.stdout)), stopped.stdout);
      expect(stopped.stdout, startsWith('😀'));
      expect(stopped.stdout, endsWith('\n'));
      await session.command(
        DebugCommand.resume,
        pauseToken: stopped.pauseToken,
      );
      await session.done;
      expect(session.snapshot.stdout, endsWith('tail\n'));
      expect(session.snapshot.stdoutTruncated, isTrue);
    },
  );

  test(
    'object contents are unavailable and inspection never invokes tostring',
    () async {
      final session = await launch(
        "local object = setmetatable({}, {__tostring=function() error('must not inspect') end})\n"
        'local n = 42\nprint(n)\n',
      );
      final stopped = await _step(session, DebugCommand.stepOver);
      final object = stopped.frames.first.locals.singleWhere(
        (v) => v.name == 'object',
      );
      expect(object.type, 'table');
      expect(object.value, 'table');
      expect(object.unavailableReason, isNotEmpty);
      expect(object.children, isEmpty);
      expect(stopped.stderr, isEmpty);
      await session.command(
        DebugCommand.resume,
        pauseToken: stopped.pauseToken,
      );
      await session.done;
      expect(session.snapshot.stdout, '42\n');
      expect(session.snapshot.exitCode, 0);
    },
  );

  test(
    'native frame and local-slot cap metadata reaches shared snapshots',
    () async {
      final deep = await launch(
        '''
local function visit(n)
  if n > 0 then
    local child = visit(n - 1)
    return child + 1
  end
  local result = 42
  return result
end
local result = visit(70)
print(result)
''',
        breakpoints: [mainBreakpoint(6)],
      );
      final stack = await _step(deep, DebugCommand.resume);
      expect(stack.frames, hasLength(64));
      expect(stack.framesTruncated, isTrue);
      await deep.stop();
      final names = List.generate(128, (i) => 'value$i').join(',');
      final values = List.generate(128, (i) => '$i').join(',');
      final many = await launch(
        'local $names = $values\nlocal done = true\nprint(value127)\n',
        breakpoints: [mainBreakpoint(2)],
      );
      final locals = await _step(many, DebugCommand.resume);
      expect(locals.frames.first.locals.length, lessThanOrEqualTo(128));
      expect(locals.frames.first.localsTruncated, isTrue);
      expect(
        locals.frames.first.locals
            .singleWhere((v) => v.name == 'value127')
            .value,
        '127',
      );
    },
  );

  test(
    'generated chunks cannot forge a navigable project source location',
    () async {
      final path = p.join(project.path, 'main.lua').replaceAll('\\', '/');
      final session = await launch(
        "local f = assert(load('local n = 1\\nreturn n', '$path'))\n"
        'local result = f()\nprint(result)\n',
        breakpoints: [mainBreakpoint(2)],
      );
      await _step(session, DebugCommand.resume);
      await session.setBreakpoints([]);
      final generated = await _step(session, DebugCommand.stepInto);
      expect(generated.frames, hasLength(2));
      expect(generated.frames.first.location, isNull);
      expect(
        generated.frames.last.location!.filePath,
        await File(path).resolveSymbolicLinks(),
      );
    },
  );

  test(
    'unsaved snapshots are rejected without modifying or running disk source',
    () async {
      final entry = write('main.lua', "assert(io.open('marker.txt', 'w'))\n");
      final before = entry.readAsBytesSync();
      await expectLater(
        provider.launch(
          request(
            documents: [
              CodeDocumentSnapshot(
                path: entry.path,
                text: 'print(42)',
                revision: 7,
              ),
            ],
          ),
        ),
        throwsUnsupportedError,
      );
      expect(entry.readAsBytesSync(), before);
      expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
      expect(project.listSync(), hasLength(1));
    },
  );

  test(
    'unsupported language and invalid project entry or breakpoints never run',
    () async {
      final entry = write('main.lua', "assert(io.open('marker.txt', 'w'))\n");
      final foreign = Directory.systemTemp.createTempSync('foreign_debug_');
      addTearDown(() => foreign.deleteSync(recursive: true));
      final outside = File(p.join(foreign.path, 'other.lua'))
        ..writeAsStringSync('print(42)');
      write('wrong.txt', 'print(42)');
      final invalid = [
        request(language: 'Shell'),
        request(root: 'relative'),
        request(root: entry.path),
        request(entry: 'main.lua'),
        request(entry: '${entry.path}\u0000'),
        request(entry: outside.path),
        request(entry: p.join(project.path, 'missing.lua')),
        request(entry: p.join(project.path, 'wrong.txt')),
        request(
          breakpoints: [DebugBreakpoint(filePath: outside.path, line: 1)],
        ),
        request(breakpoints: [mainBreakpoint(1), mainBreakpoint(1)]),
        request(breakpoints: [mainBreakpoint(0x80000000)]),
        request(breakpoints: List.generate(257, (i) => mainBreakpoint(i + 1))),
      ];
      for (final invalidRequest in invalid) {
        await expectLater(
          provider.launch(invalidRequest),
          throwsA(isA<Object>()),
        );
      }
      expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
      expect(project.listSync(), hasLength(2));
    },
  );

  test(
    'filesystem aliases are resolved to the physical project and source',
    () async {
      Directory(p.join(project.path, 'sub')).createSync();
      final entry = write('main.lua', 'print(42)\n');
      final aliasRoot = '${project.path}${p.separator}sub${p.separator}..';
      final aliasEntry = '$aliasRoot${p.separator}main.lua';
      final session = await provider.launch(
        request(
          root: aliasRoot,
          entry: aliasEntry,
          breakpoints: [DebugBreakpoint(filePath: aliasEntry, line: 1)],
        ),
      );
      sessions.add(session);
      final canonical = await entry.resolveSymbolicLinks();
      expect(session.snapshot.frames.first.location!.filePath, canonical);
      expect(session.snapshot.breakpoints.single.requested.filePath, canonical);
    },
  );

  test(
    'symlink or junction sources outside the physical project are rejected',
    () async {
      write('main.lua', "assert(io.open('marker.txt', 'w'))\n");
      final foreign = Directory.systemTemp.createTempSync(
        'foreign_link_debug_',
      );
      addTearDown(() => foreign.deleteSync(recursive: true));
      File(p.join(foreign.path, 'other.lua')).writeAsStringSync('print(42)\n');
      final alias = Link(p.join(project.path, 'outside'));
      try {
        await alias.create(foreign.path);
      } on FileSystemException {
        if (!Platform.isWindows) rethrow;
        // A directory junction needs no Windows symlink privilege.
        final created = await Process.run('cmd', [
          '/c',
          'mklink',
          '/J',
          alias.path,
          foreign.path,
        ]);
        expect(
          created.exitCode,
          0,
          reason: '${created.stdout}${created.stderr}',
        );
      }
      addTearDown(() => alias.delete());
      final outside = p.join(alias.path, 'other.lua');
      await expectLater(
        provider.launch(request(entry: outside)),
        throwsArgumentError,
      );
      await expectLater(
        provider.launch(
          request(breakpoints: [DebugBreakpoint(filePath: outside, line: 1)]),
        ),
        throwsArgumentError,
      );
      expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
    },
  );

  test(
    'unverified lines remain pending and invalid replacement is atomic',
    () async {
      final session = await launch(
        'local n = 1\nn = n + 1\nprint(n)\n',
        breakpoints: [mainBreakpoint(900)],
      );
      expect(
        session.snapshot.breakpoints.single.status,
        DebugBreakpointStatus.pending,
      );
      expect(session.snapshot.breakpoints.single.actualLocation, isNull);
      final replacement = await session.setBreakpoints([mainBreakpoint(2)]);
      expect(replacement.single.status, DebugBreakpointStatus.pending);
      await expectLater(
        session.setBreakpoints([mainBreakpoint(3), mainBreakpoint(3)]),
        throwsArgumentError,
      );
      expect(session.snapshot.breakpoints.single.requested.line, 2);
      final stopped = await _step(session, DebugCommand.resume);
      expect(stopped.frames.first.location!.line, 2);
      expect(stopped.breakpoints.single.status, DebugBreakpointStatus.verified);
      expect(replacement.single.status, DebugBreakpointStatus.pending);
    },
  );

  test(
    'queued breakpoint acknowledgements cannot republish a pause after resume',
    () async {
      final session = await launch(
        'local n = 1\nwhile true do n = n + 1 end\n',
      );
      for (var i = 0; i < 5; i++) {
        await session.setBreakpoints([]);
        await session.command(
          DebugCommand.resume,
          pauseToken: session.snapshot.pauseToken,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(session.snapshot.phase, DebugPhase.running);
        expect(session.snapshot.pauseToken, isNull);
        expect(session.snapshot.frames, isEmpty);
        await session.command(DebugCommand.pause);
        await _waitFor(session, (s) => s.phase == DebugPhase.paused);
      }
      await session.stop();
      expect(session.snapshot.exitCode, 130);
    },
  );

  test('stop can interrupt an asynchronous breakpoint replacement', () async {
    final session = await launch('print(42)\n');
    final updating = session.setBreakpoints([mainBreakpoint(1)]);
    final rejected = expectLater(updating, throwsStateError);
    await session.stop();
    await rejected;
    expect(session.snapshot.exitCode, 130);
    expect(session.snapshot.stdout, isEmpty);
  });

  test(
    'normal launch continues automatically and dispose closes updates after done',
    () async {
      final session = await launch("print('finished')\n", stopOnEntry: false);
      var closed = false;
      final subscription = session.updates.listen(
        (_) {},
        onDone: () => closed = true,
      );
      await session.done.timeout(const Duration(seconds: 3));
      expect(session.snapshot.phase, DebugPhase.terminated);
      expect(session.snapshot.exitCode, 0);
      expect(session.snapshot.stdout, 'finished\n');
      expect(closed, isFalse);
      await session.dispose();
      expect(closed, isTrue);
      await subscription.cancel();
    },
  );

  test(
    'syntax errors runtime failures and explicit exit retain real status',
    () async {
      final syntax = await launch('local = invalid');
      await syntax.done;
      expect(syntax.snapshot.phase, DebugPhase.failed);
      expect(syntax.snapshot.exitCode, isNot(0));
      expect(syntax.snapshot.message, contains('main.lua:1:'));
      final failed = await launch(
        "print('before')\nerror('actual failure')\n",
        stopOnEntry: false,
      );
      await failed.done;
      expect(failed.snapshot.phase, DebugPhase.failed);
      expect(failed.snapshot.stdout, 'before\n');
      expect(failed.snapshot.stderr, contains('actual failure'));
      expect(failed.snapshot.message, isNotEmpty);
      final exiting = await launch('os.exit(7)', stopOnEntry: false);
      await exiting.done;
      expect(exiting.snapshot.phase, DebugPhase.failed);
      expect(exiting.snapshot.exitCode, 7);
    },
  );

  test(
    'initialization failure preserves its original error and stack after cleanup',
    () async {
      final entry = write('main.lua', 'print(42)\n');
      final initializationError = StateError(
        'original breakpoint setup failure',
      );
      final initializationStack = StackTrace.fromString(
        'original Lua initialization stack',
      );
      final runtime = _ControlledDebugger(project.path, entry.path)
        ..breakpointsError = initializationError
        ..breakpointsStack = initializationStack
        ..stopError = StateError('different cleanup stop failure')
        ..disposeFailures = 1
        ..exitBeforeDisposeError = true;
      Object? caught;
      StackTrace? caughtStack;
      try {
        try {
          await _ControlledProvider(runtime).launch(request());
        } catch (error, stackTrace) {
          caught = error;
          caughtStack = stackTrace;
        }
        expect(identical(caught, initializationError), isTrue);
        expect(caughtStack.toString(), initializationStack.toString());
        expect(runtime.stopCalls, 1);
        expect(runtime.disposeCalls, 1);
        await runtime.workerExited.timeout(const Duration(seconds: 1));
      } finally {
        runtime.exit();
        await runtime.close();
      }
    },
  );

  test(
    'incomplete initialization cleanup keeps the controller lane until retry exits',
    () async {
      final entry = write('main.lua', 'print(42)\n');
      final runtime = _ControlledDebugger(project.path, entry.path)
        ..breakpointsError = StateError('original breakpoint setup failure')
        ..breakpointsStack = StackTrace.fromString(
          'original incomplete initialization stack',
        )
        ..stopError = StateError('different cleanup stop failure')
        ..disposeFailures = 1;
      final controlled = _ControlledProvider(runtime);
      final editor = EditorController(
        project: Project.create(
          name: 'Lua initialization',
          path: project.path,
          type: 'lua',
          language: 'Lua',
        ),
      );
      final debug = EditorDebugController(editor: editor, debugger: controlled);
      final previousProfile = StudioProfile.current;
      StudioProfile.current = const StudioProfile(
        id: 'lua-initialization-test',
        appTitle: 'Lua initialization test',
        templates: [],
        isOffline: true,
        entryFileNames: ['main.lua'],
      );
      try {
        expect(await editor.openPath(entry.path), isNull);
        await debug.start(stopOnEntry: true);
        final session = controlled.session!;
        expect(debug.busy, isTrue);
        expect(debug.stopping, isTrue);
        expect(session.snapshot.isTerminal, isFalse);
        expect(session.snapshot.phase, DebugPhase.stopping);
        expect(
          session.snapshot.console,
          contains('original breakpoint setup failure'),
        );
        expect(
          session.snapshot.console,
          contains('original incomplete initialization stack'),
        );
        expect(runtime.disposeCalls, 1);
        var done = false;
        unawaited(session.done.then((_) => done = true));
        await debug.start(stopOnEntry: true);
        expect(controlled.starts, 1);
        expect(debug.busy, isTrue);
        expect(done, isFalse);
        await expectLater(
          session.command(DebugCommand.resume),
          throwsStateError,
        );

        final stopping = debug.stop();
        await Future<void>.delayed(Duration.zero);
        expect(runtime.disposeCalls, 2);
        expect(debug.busy, isTrue);
        expect(done, isFalse);
        runtime.exit();
        await stopping.timeout(const Duration(seconds: 3));
        expect(done, isTrue);
        expect(debug.busy, isFalse);
        expect(session.snapshot.phase, DebugPhase.failed);
        expect(
          session.snapshot.message,
          contains('original breakpoint setup failure'),
        );
      } finally {
        runtime.exit();
        await debug.close().timeout(const Duration(seconds: 3));
        debug.dispose();
        editor.dispose();
        StudioProfile.current = previousProfile;
        await runtime.close();
      }
    },
  );

  test(
    'stop failure still disposes and waits for actual worker exit',
    () async {
      final entry = write('main.lua', 'print(42)\n');
      final runtime = _ControlledDebugger(project.path, entry.path)
        ..stopError = StateError('original stop failure');
      final session = await _ControlledProvider(runtime).launch(request());
      sessions.add(session);
      var done = false, closed = false;
      unawaited(session.done.then((_) => done = true));
      final subscription = session.updates.listen(
        (_) {},
        onDone: () {
          expect(done, isTrue);
          closed = true;
        },
      );
      try {
        final stopping = session.stop();
        expect(identical(stopping, session.stop()), isTrue);
        final disposing = session.dispose();
        expect(identical(disposing, session.dispose()), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(runtime.stopCalls, 1);
        expect(runtime.disposeCalls, 1);
        expect(session.snapshot.phase, DebugPhase.stopping);
        expect(session.snapshot.isTerminal, isFalse);
        expect(done, isFalse);
        expect(closed, isFalse);

        runtime.exit();
        await stopping;
        await disposing;
        expect(done, isTrue);
        expect(closed, isTrue);
        expect(session.snapshot.phase, DebugPhase.failed);
        expect(session.snapshot.exitCode, isNull);
        expect(session.snapshot.message, contains('original stop failure'));
        expect(session.snapshot.console, contains('original stop failure'));
        expect(session.snapshot.stdout, 'before failure\n');
      } finally {
        runtime.exit();
        await session.dispose();
        await subscription.cancel();
        await runtime.close();
      }
    },
  );

  test(
    'incomplete cleanup failure retains ownership and permits dispose retry',
    () async {
      final entry = write('main.lua', 'print(42)\n');
      final runtime = _ControlledDebugger(project.path, entry.path)
        ..stopError = StateError('original stop failure')
        ..disposeFailures = 1;
      final session = await _ControlledProvider(runtime).launch(request());
      sessions.add(session);
      final token = session.snapshot.pauseToken;
      var done = false, closed = false;
      unawaited(session.done.then((_) => done = true));
      final subscription = session.updates.listen(
        (_) {},
        onDone: () => closed = true,
      );
      try {
        final first = session.dispose();
        await expectLater(first, throwsStateError);
        expect(runtime.disposeCalls, 1);
        expect(session.snapshot.phase, DebugPhase.stopping);
        expect(session.snapshot.isTerminal, isFalse);
        expect(done, isFalse);
        expect(closed, isFalse);
        await expectLater(
          session.command(DebugCommand.resume, pauseToken: token),
          throwsStateError,
        );

        final retry = session.dispose();
        expect(identical(first, retry), isFalse);
        expect(identical(retry, session.dispose()), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(runtime.disposeCalls, 2);
        expect(done, isFalse);
        expect(closed, isFalse);
        expect(session.snapshot.isTerminal, isFalse);
        runtime.exit();
        await retry;
        expect(done, isTrue);
        expect(closed, isTrue);
        expect(session.snapshot.phase, DebugPhase.failed);
        expect(session.snapshot.message, contains('original stop failure'));
        expect(
          session.snapshot.console,
          contains('cleanup temporarily unavailable'),
        );
      } finally {
        runtime.exit();
        await session.dispose();
        await subscription.cancel();
        await runtime.close();
      }
    },
  );

  test('unexpected worker exit performs cleanup and retains failure', () async {
    final entry = write('main.lua', 'print(42)\n');
    final runtime = _ControlledDebugger(project.path, entry.path);
    final session = await _ControlledProvider(runtime).launch(request());
    sessions.add(session);
    try {
      runtime.exit();
      await session.done;
      expect(runtime.disposeCalls, 1);
      expect(session.snapshot.phase, DebugPhase.failed);
      expect(session.snapshot.message, contains('worker exited unexpectedly'));
      expect(session.snapshot.stdout, 'before failure\n');
      expect(session.snapshot.exitCode, isNull);
    } finally {
      runtime.exit();
      await session.dispose();
      await runtime.close();
    }
  });

  test(
    'a stop error rethrown after completed cleanup remains a failure',
    () async {
      final entry = write('main.lua', 'print(42)\n');
      final runtime = _ControlledDebugger(project.path, entry.path)
        ..stopError = StateError('stop failed before completed cleanup')
        ..disposeFailures = 1
        ..exitBeforeDisposeError = true;
      final session = await _ControlledProvider(runtime).launch(request());
      sessions.add(session);
      try {
        await session.stop();
        expect(runtime.disposeCalls, 1);
        expect(session.snapshot.phase, DebugPhase.failed);
        expect(session.snapshot.exitCode, isNull);
        expect(
          session.snapshot.message,
          contains('stop failed before completed cleanup'),
        );
        expect(
          session.snapshot.console,
          contains('stop failed before completed cleanup'),
        );
        await session.done;
      } finally {
        runtime.exit();
        await session.dispose();
        await runtime.close();
      }
    },
  );

  test(
    'missing native backend fails launch without executing a fallback',
    () async {
      write('main.lua', "assert(io.open('marker.txt', 'w'))\n");
      final unavailable = LuaStudioDebugger(
        libraryPath: p.join(project.path, 'absent.dll'),
      );
      await expectLater(unavailable.launch(request()), throwsA(isA<Object>()));
      expect(File(p.join(project.path, 'marker.txt')).existsSync(), isFalse);
      expect(project.listSync(), hasLength(1));
    },
  );
}

class _ControlledProvider extends LuaStudioDebugger {
  _ControlledProvider(this.runtime);
  final LuaDebugger runtime;
  int starts = 0;
  DebugSession? session;

  @override
  Future<DebugSession> launch(DebugLaunchRequest request) async {
    final launched = await super.launch(request);
    session = launched;
    return launched;
  }

  @override
  Future<LuaDebugger> startRuntime({
    required String file,
    required String projectDirectory,
  }) async {
    starts++;
    return runtime;
  }
}

/// A dispose acknowledgement and an actual worker exit are separate events.
/// Keep them independently controllable to exercise ownership/cleanup failures.
class _ControlledDebugger implements LuaDebugger {
  _ControlledDebugger(this.projectDirectory, String entry)
    : snapshot = LuaDebugSnapshot(
        state: LuaDebugState.paused,
        stdout: 'before failure\n',
        frames: [LuaDebugFrame(entry, '<main>', 1, const [])],
      );

  @override
  final String projectDirectory;
  @override
  LuaDebugSnapshot snapshot;
  final _updates = StreamController<LuaDebugSnapshot>.broadcast(sync: true);
  final _exit = Completer<void>();
  Object? breakpointsError;
  StackTrace? breakpointsStack;
  Object? stopError;
  int stopCalls = 0, disposeCalls = 0, disposeFailures = 0;
  bool exitBeforeDisposeError = false;

  @override
  Stream<LuaDebugSnapshot> get updates => _updates.stream;
  @override
  Future<void> get workerExited => _exit.future;
  @override
  bool get running => snapshot.state == LuaDebugState.running;

  @override
  Future<void> setBreakpoints(List<LuaBreakpoint> breakpoints) async {
    final error = breakpointsError;
    if (error != null) {
      Error.throwWithStackTrace(error, breakpointsStack ?? StackTrace.current);
    }
    _updates.add(snapshot);
  }

  @override
  Future<LuaDebugSnapshot> resume([
    LuaDebugAction action = LuaDebugAction.continueRun,
  ]) => throw StateError('This lifecycle transport must not execute source');

  @override
  void pause() => throw StateError('No source is running');

  @override
  Future<LuaDebugSnapshot> stop() async {
    stopCalls++;
    final error = stopError;
    if (error != null) throw error;
    return snapshot;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (disposeFailures > 0) {
      disposeFailures--;
      if (exitBeforeDisposeError) {
        // Real LuaDebugger.dispose can finish its finally cleanup and then
        // rethrow the earlier stop/transport failure.
        exit();
        await workerExited;
        throw stopError ?? StateError('earlier stop failure');
      }
      throw StateError('cleanup temporarily unavailable');
    }
    // An acknowledgement is deliberately insufficient to complete workerExit.
  }

  void exit() {
    if (!_exit.isCompleted) _exit.complete();
  }

  Future<void> close() => _updates.close();
}

Future<DebugSnapshot> _step(DebugSession session, DebugCommand command) async {
  final token = session.snapshot.pauseToken;
  await session.command(command, pauseToken: token);
  return _waitFor(
    session,
    (snapshot) =>
        snapshot.phase == DebugPhase.paused && snapshot.pauseToken != token,
  );
}

Future<DebugSnapshot> _waitFor(
  DebugSession session,
  bool Function(DebugSnapshot) predicate,
) async {
  final result = Completer<DebugSnapshot>();
  final subscription = session.updates.listen((snapshot) {
    if (!result.isCompleted && predicate(snapshot)) result.complete(snapshot);
    if (!result.isCompleted && snapshot.isTerminal) {
      result.completeError(
        StateError('Session ended before expected pause: ${snapshot.message}'),
      );
    }
  });
  try {
    if (predicate(session.snapshot)) result.complete(session.snapshot);
    return await result.future.timeout(const Duration(seconds: 5));
  } finally {
    await subscription.cancel();
  }
}
