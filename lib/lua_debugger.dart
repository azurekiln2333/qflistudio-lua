import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'lua_toolchain.dart';

enum LuaDebugState { ready, running, paused, terminated }

enum LuaDebugAction { continueRun, stepInto, stepOver, stepOut }

class LuaBreakpoint {
  const LuaBreakpoint(this.file, this.line);
  final String file;
  final int line;
}

class LuaDebugLocal {
  const LuaDebugLocal(
    this.name,
    this.type,
    this.value, {
    this.truncated = false,
  });
  final String name;
  final String type;
  final String value;
  final bool truncated;
}

class LuaDebugFrame {
  const LuaDebugFrame(
    this.file,
    this.name,
    this.line,
    this.locals, {
    this.fileBacked = true,
    this.localsTruncated = false,
  });
  final String file;
  final String name;
  final int line;
  final List<LuaDebugLocal> locals;

  /// Whether Lua identified the source as a file with its `@` marker.
  final bool fileBacked;

  /// The native local-slot limit was reached; further locals may exist.
  final bool localsTruncated;
}

class LuaDebugSnapshot {
  const LuaDebugSnapshot({
    required this.state,
    this.status,
    this.stdout = '',
    this.stderr = '',
    this.frames = const [],
    this.framesTruncated = false,
  });
  final LuaDebugState state;
  final int? status;
  final String stdout;
  final String stderr;
  final List<LuaDebugFrame> frames;

  /// The native frame limit was reached; further frames may exist.
  final bool framesTruncated;
}

/// A real source debugger. VM access stays on one persistent worker isolate.
///
/// Main entries are saved .lua text files. User coroutines and replacing the
/// debug hook are rejected in this mode. Native calls/callbacks and finalizers
/// cannot be preempted; stripped/generated chunks may have no source lines.
/// Stops inside non-yieldable callbacks (including require initialization) are
/// deferred to the next resumable Lua instruction, with an explicit diagnostic.
/// Locals are bounded primitive displays; inspection never evaluates user code.
class LuaDebugger {
  LuaDebugger._(
    this._commands,
    this._isolate,
    this._workerExit,
    this._address,
    this._native,
    this.projectDirectory,
    this.snapshot,
  );

  final SendPort _commands;
  final Isolate _isolate;
  final _DebugWorkerExit _workerExit;
  int _address;
  final _DebugBindings _native;
  final String projectDirectory;
  LuaDebugSnapshot snapshot;
  final _updates = StreamController<LuaDebugSnapshot>.broadcast(sync: true);
  Stream<LuaDebugSnapshot> get updates => _updates.stream;
  Future<LuaDebugSnapshot>? _pending;
  Future<void>? _disposing;
  bool _disposed = false;
  int _commandRevision = 0;
  bool get running => _pending != null;

  /// Completes only after the persistent worker has actually exited.
  Future<void> get workerExited => _workerExit.future;

  static Future<LuaDebugger> start({
    required String file,
    required String projectDirectory,
    String? libraryPath,
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    final root = p.normalize(
      await Directory(projectDirectory).resolveSymbolicLinks(),
    );
    final path = p.normalize(await File(file).resolveSymbolicLinks());
    if (!p.isWithin(root, path) ||
        p.extension(path).toLowerCase() != '.lua' ||
        path.contains('\u0000') ||
        root.contains('\u0000')) {
      throw ArgumentError(
        'Debugger requires a .lua source file inside its project',
      );
    }
    if (timeLimit.inMilliseconds <= 0 ||
        timeLimit.inMilliseconds > 0x7fffffff) {
      throw ArgumentError.value(timeLimit, 'timeLimit');
    }
    final native = _DebugBindings(
      LuaToolchain(libraryPath: libraryPath).openNativeLibrary(),
    );
    final ready = ReceivePort();
    final workerExit = _DebugWorkerExit();
    Isolate? isolate;
    LuaDebugger? debugger;
    try {
      isolate = await Isolate.spawn(_debugWorker, [
        ready.sendPort,
        path,
        root,
        libraryPath,
        timeLimit.inMilliseconds,
      ], onExit: workerExit.sendPort);
      final response = await workerExit.waitFor(ready.first) as List<Object?>;
      if (response.first == 'error') {
        // Startup failures still own native cleanup in the worker's finally.
        await workerExit.future;
        throw StateError(response[1] as String);
      }
      debugger = LuaDebugger._(
        response[0] as SendPort,
        isolate,
        workerExit,
        response[1] as int,
        native,
        root,
        response[2] as LuaDebugSnapshot,
      );
      if (debugger.snapshot.state != LuaDebugState.terminated) {
        await debugger.resume(LuaDebugAction.stepInto);
      }
      return debugger;
    } catch (_) {
      if (debugger != null) {
        // Even a failed initial step must release the persistent session.
        try {
          await debugger.dispose();
        } catch (_) {
          // Preserve the original launch failure after disposal has finished.
        }
      } else if (isolate != null) {
        isolate.kill();
        await workerExit.future;
      } else {
        workerExit.close();
      }
      rethrow;
    } finally {
      ready.close();
    }
  }

  Future<LuaDebugSnapshot> resume([
    LuaDebugAction action = LuaDebugAction.continueRun,
  ]) {
    if (_disposed || _disposing != null || _workerExit.hasExited) {
      throw StateError('Debugger is disposed');
    }
    if (_pending != null) throw StateError('Debugger is already running');
    if (snapshot.state == LuaDebugState.terminated) {
      return Future.value(snapshot);
    }
    snapshot = LuaDebugSnapshot(
      state: LuaDebugState.running,
      stdout: snapshot.stdout,
      stderr: snapshot.stderr,
    );
    _updates.add(snapshot);
    final pending = _exchange('resume', action.index);
    _pending = pending;
    return pending.whenComplete(() {
      _pending = null;
    });
  }

  Future<void> setBreakpoints(List<LuaBreakpoint> breakpoints) async {
    if (_disposed || _disposing != null || running) {
      throw StateError('Change breakpoints while paused');
    }
    if (breakpoints.length > 256) {
      throw ArgumentError('At most 256 breakpoints');
    }
    final values = <LuaBreakpoint>[];
    for (final breakpoint in breakpoints) {
      final path = p.normalize(p.absolute(breakpoint.file));
      if (!p.isWithin(projectDirectory, path) ||
          path.contains('\u0000') ||
          breakpoint.line < 1) {
        throw ArgumentError(
          'Breakpoints require project source paths and positive lines',
        );
      }
      values.add(LuaBreakpoint(path, breakpoint.line));
    }
    await _exchange('breakpoints', values);
  }

  void pause() {
    if (!_disposed &&
        _disposing == null &&
        !_workerExit.hasExited &&
        running &&
        _address != 0) {
      _native.pause(Pointer<Void>.fromAddress(_address));
    }
  }

  Future<LuaDebugSnapshot> stop() {
    if (_disposed) return Future.value(snapshot);
    if (_workerExit.hasExited) {
      return Future.error(StateError('Lua debugger worker exited'));
    }
    if (_address != 0) _native.stop(Pointer<Void>.fromAddress(_address));
    final pending = _pending;
    if (pending != null) return pending;
    if (snapshot.state == LuaDebugState.terminated) {
      return Future.value(snapshot);
    }
    final pendingStop = _exchange('resume', 0);
    _pending = pendingStop;
    return pendingStop.whenComplete(() {
      _pending = null;
    });
  }

  Future<LuaDebugSnapshot> _exchange(String command, Object? value) async {
    final revision = ++_commandRevision;
    final reply = ReceivePort();
    try {
      _commands.send([command, value, reply.sendPort]);
      final response = await _workerExit.waitFor(reply.first);
      if (response is String) throw StateError(response);
      final received = response as LuaDebugSnapshot;
      if (revision == _commandRevision) {
        snapshot = received;
        if (!_updates.isClosed) _updates.add(snapshot);
      }
      return received;
    } finally {
      reply.close();
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    try {
      await stop();
    } finally {
      _disposed = true;
      // No control call may use the address after the worker receives dispose.
      _address = 0;
      final reply = ReceivePort();
      try {
        if (!_workerExit.hasExited) {
          _commands.send(['dispose', null, reply.sendPort]);
          await Future.any<Object?>([reply.first, _workerExit.future]);
        }
      } finally {
        reply.close();
        // The acknowledgement follows native.free; exit is a separate event.
        _isolate.kill();
        await _workerExit.future;
        await _updates.close();
      }
    }
  }
}

final class _DebugWorkerExit {
  _DebugWorkerExit() {
    _port.handler = (_) {
      hasExited = true;
      close();
      _completion.complete();
    };
  }

  final _port = RawReceivePort();
  final _completion = Completer<void>();
  bool hasExited = false;
  SendPort get sendPort => _port.sendPort;
  Future<void> get future => _completion.future;

  Future<T> waitFor<T>(Future<T> response) => Future.any([
    response,
    future.then<T>((_) => throw StateError('Lua debugger worker exited')),
  ]);

  void close() => _port.close();
}

final class _NativeFrame extends Struct {
  external Pointer<Utf8> source;
  external Pointer<Utf8> name;
  @Int32()
  external int line;
}

final class _NativeLocal extends Struct {
  external Pointer<Utf8> name;
  external Pointer<Utf8> type;
  external Pointer<Utf8> value;
  @UintPtr()
  external int length;
}

final class _NativeOutput extends Struct {
  @Int32()
  external int status;
  external Pointer<Utf8> output;
  external Pointer<Utf8> error;
  @UintPtr()
  external int outputLength;
  @UintPtr()
  external int errorLength;
}

typedef _NewNative =
    Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _NewDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _ResumeNative = Int32 Function(Pointer<Void>, Int32);
typedef _ResumeDart = int Function(Pointer<Void>, int);
typedef _ControlNative = Void Function(Pointer<Void>);
typedef _ControlDart = void Function(Pointer<Void>);
typedef _StateNative = Int32 Function(Pointer<Void>);
typedef _StateDart = int Function(Pointer<Void>);
typedef _BreakpointsNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Utf8>>,
      Pointer<Int32>,
      Int32,
    );
typedef _BreakpointsDart =
    int Function(Pointer<Void>, Pointer<Pointer<Utf8>>, Pointer<Int32>, int);
typedef _FrameNative =
    Int32 Function(Pointer<Void>, Int32, Pointer<_NativeFrame>);
typedef _FrameDart = int Function(Pointer<Void>, int, Pointer<_NativeFrame>);
typedef _LocalNative =
    Int32 Function(Pointer<Void>, Int32, Int32, Pointer<_NativeLocal>);
typedef _LocalDart =
    int Function(Pointer<Void>, int, int, Pointer<_NativeLocal>);
typedef _OutputNative = Pointer<_NativeOutput> Function(Pointer<Void>);
typedef _OutputDart = Pointer<_NativeOutput> Function(Pointer<Void>);
typedef _FreeOutputNative = Void Function(Pointer<_NativeOutput>);
typedef _FreeOutputDart = void Function(Pointer<_NativeOutput>);

class _DebugBindings {
  _DebugBindings(DynamicLibrary library) {
    create = library.lookupFunction<_NewNative, _NewDart>('qfli_lua_debug_new');
    resume = library.lookupFunction<_ResumeNative, _ResumeDart>(
      'qfli_lua_debug_resume',
    );
    pause = library.lookupFunction<_ControlNative, _ControlDart>(
      'qfli_lua_debug_pause',
    );
    stop = library.lookupFunction<_ControlNative, _ControlDart>(
      'qfli_lua_debug_stop',
    );
    free = library.lookupFunction<_ControlNative, _ControlDart>(
      'qfli_lua_debug_free',
    );
    state = library.lookupFunction<_StateNative, _StateDart>(
      'qfli_lua_debug_state',
    );
    breakpoints = library.lookupFunction<_BreakpointsNative, _BreakpointsDart>(
      'qfli_lua_debug_set_breakpoints',
    );
    frame = library.lookupFunction<_FrameNative, _FrameDart>(
      'qfli_lua_debug_frame',
    );
    local = library.lookupFunction<_LocalNative, _LocalDart>(
      'qfli_lua_debug_local',
    );
    output = library.lookupFunction<_OutputNative, _OutputDart>(
      'qfli_lua_debug_output',
    );
    freeOutput = library.lookupFunction<_FreeOutputNative, _FreeOutputDart>(
      'qfli_lua_free',
    );
  }
  late final _NewDart create;
  late final _ResumeDart resume;
  late final _ControlDart pause, stop, free;
  late final _StateDart state;
  late final _BreakpointsDart breakpoints;
  late final _FrameDart frame;
  late final _LocalDart local;
  late final _OutputDart output;
  late final _FreeOutputDart freeOutput;

  LuaDebugSnapshot inspect(Pointer<Void> session) => using((arena) {
    final frames = <LuaDebugFrame>[];
    var framesTruncated = false;
    final nativeFrame = arena<_NativeFrame>();
    final nativeLocal = arena<_NativeLocal>();
    final stateValue = state(session);
    if (stateValue == 1) {
      for (var index = 0; index < 64; index++) {
        if (frame(session, index, nativeFrame) == 0) break;
        framesTruncated = index == 63;
        final source = nativeFrame.ref.source.toDartString();
        final fileBacked = source.startsWith('@');
        final name = nativeFrame.ref.name.toDartString();
        final line = nativeFrame.ref.line;
        final locals = <LuaDebugLocal>[];
        var localsTruncated = false;
        for (var slot = 1; slot <= 128; slot++) {
          if (local(session, index, slot, nativeLocal) == 0) break;
          localsTruncated = slot == 128;
          final name = nativeLocal.ref.name.toDartString();
          if (name.startsWith('(')) continue;
          final length = nativeLocal.ref.length;
          final bytes = nativeLocal.ref.value.cast<Uint8>().asTypedList(
            math.min(length, 4097),
          );
          var end = math.min(length, 4096);
          if (length > end) {
            // A byte cap must not turn a valid final Unicode scalar into a
            // replacement character. Keep malformed original bytes observable.
            while (end > 0 && (bytes[end] & 0xc0) == 0x80) {
              end--;
            }
          }
          final value = utf8.decode(
            bytes.sublist(0, end),
            allowMalformed: true,
          );
          locals.add(
            LuaDebugLocal(
              name,
              nativeLocal.ref.type.toDartString(),
              length > 4096 ? '$value…' : value,
              truncated: length > 4096,
            ),
          );
        }
        frames.add(
          LuaDebugFrame(
            fileBacked ? p.normalize(source.substring(1)) : source,
            name,
            line,
            List.unmodifiable(locals),
            fileBacked: fileBacked,
            localsTruncated: localsTruncated,
          ),
        );
      }
    }
    final captured = output(session);
    if (captured == nullptr) {
      throw StateError('Cannot inspect Lua debugger output');
    }
    try {
      return LuaDebugSnapshot(
        state: stateValue == 1
            ? LuaDebugState.paused
            : stateValue == 2
            ? LuaDebugState.terminated
            : LuaDebugState.ready,
        status: stateValue == 2 ? captured.ref.status : null,
        stdout: utf8.decode(
          captured.ref.output.cast<Uint8>().asTypedList(
            captured.ref.outputLength,
          ),
          allowMalformed: true,
        ),
        stderr: utf8.decode(
          captured.ref.error.cast<Uint8>().asTypedList(
            captured.ref.errorLength,
          ),
          allowMalformed: true,
        ),
        frames: List.unmodifiable(frames),
        framesTruncated: framesTruncated,
      );
    } finally {
      freeOutput(captured);
    }
  });
}

Future<void> _debugWorker(List<Object?> arguments) async {
  final ready = arguments[0] as SendPort;
  final commands = ReceivePort();
  _DebugBindings? native;
  Pointer<Void> session = nullptr;
  var initialized = false;
  try {
    native = _DebugBindings(
      LuaToolchain(libraryPath: arguments[3] as String?).openNativeLibrary(),
    );
    session = using(
      (arena) => native!.create(
        (arguments[1] as String).toNativeUtf8(allocator: arena),
        (arguments[2] as String).toNativeUtf8(allocator: arena),
        arguments[4] as int,
      ),
    );
    if (session == nullptr) throw StateError('Cannot create Lua debugger');
    ready.send([commands.sendPort, session.address, native.inspect(session)]);
    initialized = true;
    await for (final raw in commands) {
      final message = raw as List<Object?>;
      final reply = message[2] as SendPort;
      try {
        switch (message[0]) {
          case 'dispose':
            native.free(session);
            session = nullptr;
            reply.send(true);
            return;
          case 'resume':
            native.resume(session, message[1] as int);
          case 'breakpoints':
            final values = message[1] as List<LuaBreakpoint>;
            using((arena) {
              final paths = arena<Pointer<Utf8>>(math.max(1, values.length));
              final lines = arena<Int32>(math.max(1, values.length));
              for (var index = 0; index < values.length; index++) {
                paths[index] = values[index].file.toNativeUtf8(
                  allocator: arena,
                );
                lines[index] = values[index].line;
              }
              if (native!.breakpoints(session, paths, lines, values.length) ==
                  0) {
                throw StateError('Cannot set Lua breakpoints');
              }
            });
          default:
            throw StateError('Unknown debugger command');
        }
        reply.send(native.inspect(session));
      } catch (error) {
        reply.send('$error');
      }
    }
  } catch (error) {
    if (!initialized) ready.send(['error', '$error']);
  } finally {
    if (session != nullptr) native?.free(session);
    commands.close();
  }
}
