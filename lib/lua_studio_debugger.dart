import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show protected;
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/debug_session.dart';

import 'lua_debugger.dart';

/// Shared editor adapter for the real, saved-source Lua debugger.
///
/// Snapshots retain the latest 64 Ki UTF-16 units of each output stream, at most
/// 64 frames and 128 local slots per frame. Names/messages are limited to 1024/
/// 4096 UTF-16 units, without splitting surrogate pairs. Native inspection caps
/// primitive string values at 4096 UTF-8 bytes and reports its cap metadata.
/// Object contents are unavailable; inspection never invokes Lua code.
class LuaStudioDebugger implements StudioDebugger {
  const LuaStudioDebugger({
    this.libraryPath,
    this.timeLimit = const Duration(seconds: 10),
  });

  final String? libraryPath;
  final Duration timeLimit;

  @override
  String get displayName => 'Lua source debugger';

  @override
  DebugCapabilities get capabilities => const DebugCapabilities(
    breakpointUpdate: DebugBreakpointUpdate.paused,
    outputDelivery: DebugOutputDelivery.pauseOrExit,
    supportsPause: true,
    supportsStepInto: true,
    supportsStepOver: true,
    supportsStepOut: true,
    supportsStopOnEntry: true,
    supportsStackFrames: true,
    supportsVariables: true,
  );

  @override
  bool supportsLanguage(String language) =>
      language.trim().toLowerCase() == 'lua';

  /// Creates the product runtime after launch paths have been validated.
  /// Kept protected so lifecycle tests can supply controlled worker failures
  /// without changing the shared debugger interface or the native ABI.
  @protected
  Future<LuaDebugger> startRuntime({
    required String file,
    required String projectDirectory,
  }) => LuaDebugger.start(
    file: file,
    projectDirectory: projectDirectory,
    libraryPath: libraryPath,
    timeLimit: timeLimit,
  );

  @override
  Future<DebugSession> launch(DebugLaunchRequest request) async {
    if (!supportsLanguage(request.language)) {
      throw ArgumentError('The Lua debugger only supports Lua source.');
    }
    if (request.documents.isNotEmpty) {
      throw UnsupportedError(
        'Lua debugging requires saved files. Save all documents and launch '
        'with an empty snapshot list; unsaved snapshots cannot be executed.',
      );
    }
    _validatePath(request.projectPath, 'projectPath');
    final root = p.normalize(
      await Directory(request.projectPath).resolveSymbolicLinks(),
    );
    _validatePath(root, 'canonical projectPath');
    if (await FileSystemEntity.type(root) != FileSystemEntityType.directory) {
      throw ArgumentError(
        'The Lua project root must be an existing directory.',
      );
    }
    final entry = await _sourcePath(request.entryFilePath, root);
    final breakpoints = await _canonicalBreakpoints(request.breakpoints, root);
    LuaDebugger? runtime;
    _LuaStudioSession? session;
    try {
      runtime = await startRuntime(file: entry, projectDirectory: root);
      session = _LuaStudioSession(runtime, root, breakpoints);
      await session.initialize(stopOnEntry: request.stopOnEntry);
      return session;
    } catch (error, stackTrace) {
      if (session != null) {
        session._recordFailure(error, stackTrace: stackTrace);
        try {
          await session.dispose();
        } catch (_) {
          if (!session._done.isCompleted) {
            // The controller can retain this stopping session and retry Stop.
            // Throwing here would release its lane while cleanup is incomplete.
            return session;
          }
        }
      } else if (runtime != null) {
        try {
          await runtime.dispose();
        } catch (_) {
          // Concrete runtime disposal may rethrow a stop error after its finally
          // has freed the VM. Preserve the initialization error after actual exit.
        }
        await runtime.workerExited;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

void _validatePath(String path, String name) {
  if (path.isEmpty ||
      path.contains('\u0000') ||
      path.length > 4096 ||
      !p.isAbsolute(path)) {
    throw ArgumentError.value(
      path,
      name,
      'Expected an absolute filesystem path.',
    );
  }
}

Future<String> _sourcePath(String input, String root) async {
  _validatePath(input, 'source path');
  final path = p.normalize(await File(input).resolveSymbolicLinks());
  _validatePath(path, 'canonical source path');
  if (!p.isWithin(root, path) ||
      p.extension(path).toLowerCase() != '.lua' ||
      await FileSystemEntity.type(path) != FileSystemEntityType.file) {
    throw ArgumentError(
      'Lua source must be a saved .lua file inside its project.',
    );
  }
  return path;
}

Future<List<DebugBreakpoint>> _canonicalBreakpoints(
  List<DebugBreakpoint> requested,
  String root,
) async {
  if (requested.length > 256) {
    throw ArgumentError('The Lua debugger supports at most 256 breakpoints.');
  }
  final result = <DebugBreakpoint>[];
  for (final breakpoint in requested) {
    if (breakpoint.line < 1 || breakpoint.line > 0x7fffffff) {
      throw ArgumentError('Breakpoint lines must be positive 32-bit integers.');
    }
    final path = await _sourcePath(breakpoint.filePath, root);
    if (result.any(
      (known) =>
          p.equals(known.filePath, path) && known.line == breakpoint.line,
    )) {
      throw ArgumentError(
        'Duplicate Lua breakpoint: $path:${breakpoint.line}.',
      );
    }
    result.add(DebugBreakpoint(filePath: path, line: breakpoint.line));
  }
  return List.unmodifiable(result);
}

class _LuaStudioSession implements DebugSession {
  _LuaStudioSession(
    this._runtime,
    this._root,
    List<DebugBreakpoint> breakpoints,
  ) : id = 'lua-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}',
      _breakpoints = _pendingBreakpoints(breakpoints) {
    _snapshot = DebugSnapshot(
      sessionId: id,
      revision: 0,
      phase: DebugPhase.starting,
      breakpoints: _breakpoints,
    );
    _subscription = _runtime.updates.listen(_receive, onError: _backendFailed);
    unawaited(
      _runtime.workerExited.then<void>((_) {
        _workerHasExited = true;
        if (_snapshot.isTerminal) return;
        if (!_stopping) {
          _recordFailure(StateError('Lua debugger worker exited unexpectedly'));
        }
        // This can retry a cleanup that rejected while the worker was still
        // alive. An in-flight cleanup remains shared by every caller.
        unawaited(_finish().catchError(_cleanupFailed));
      }, onError: _backendFailed),
    );
  }

  static int _nextId = 1;
  static const _threadId = 'lua-main';
  static const _outputLimit = 64 * 1024;
  final LuaDebugger _runtime;
  final String _root;
  @override
  final String id;
  late DebugSnapshot _snapshot;
  final _updates = StreamController<DebugSnapshot>.broadcast();
  final _done = Completer<void>();
  late final StreamSubscription<LuaDebugSnapshot> _subscription;
  Future<void> _events = Future.value();
  Future<void>? _stoppingFuture, _completion, _disposing;
  List<DebugBreakpointResult> _breakpoints;
  int _generation = 0, _epoch = 0;
  bool _stopping = false, _changingBreakpoints = false;
  bool _workerHasExited = false;
  String _stdout = '', _stderr = '', _console = '';
  bool _stdoutTruncated = false, _stderrTruncated = false;
  bool _consoleTruncated = false;
  String? _failure;

  @override
  DebugSnapshot get snapshot => _snapshot;
  @override
  Stream<DebugSnapshot> get updates => _updates.stream;
  @override
  Future<void> get done => _done.future;

  Future<void> initialize({required bool stopOnEntry}) async {
    if (_runtime.snapshot.state == LuaDebugState.terminated) {
      await _finish();
      return;
    }
    await _runtime.setBreakpoints([
      for (final item in _breakpoints)
        LuaBreakpoint(item.requested.filePath, item.requested.line),
    ]);
    await _events;
    // The initial stopped line can itself be a requested, real breakpoint.
    final entryBreakpoint = _breakpoints.any(
      (item) => item.status == DebugBreakpointStatus.verified,
    );
    if (!stopOnEntry && !entryBreakpoint && !_snapshot.isTerminal) {
      await command(DebugCommand.resume, pauseToken: _snapshot.pauseToken);
    }
  }

  static List<DebugBreakpointResult> _pendingBreakpoints(
    List<DebugBreakpoint> breakpoints,
  ) => [
    for (final breakpoint in breakpoints)
      DebugBreakpointResult(
        requested: breakpoint,
        status: DebugBreakpointStatus.pending,
      ),
  ];

  void _receive(LuaDebugSnapshot source) {
    final epoch = _epoch;
    _events = _events.then((_) => _accept(source, epoch)).catchError((
      Object error,
    ) {
      _backendFailed(error);
    });
  }

  Future<void> _accept(LuaDebugSnapshot source, int epoch) async {
    if (_snapshot.isTerminal) return;
    if (source.state == LuaDebugState.terminated) {
      await _finish();
      return;
    }
    if (_stopping || epoch != _epoch) return;
    if (source.state == LuaDebugState.running) {
      _captureOutput(source);
      _publish(DebugPhase.running);
      return;
    }
    if (source.state != LuaDebugState.paused) return;
    final generation = _snapshot.pauseToken?.generation ?? _generation + 1;
    final frames = <DebugFrame>[];
    var frameNamesTruncated = false;
    for (var index = 0; index < source.frames.length && index < 64; index++) {
      final frame = source.frames[index];
      final name = _prefix(frame.name, 1024);
      frameNamesTruncated = frameNamesTruncated || name.truncated;
      frames.add(
        DebugFrame(
          id: '$id-p$generation-f$index',
          threadId: _threadId,
          name: name.text,
          location: await _location(frame),
          locals: [
            for (final value in frame.locals.take(128)) _variable(value),
          ],
          localsUnavailableReason: frame.line > 0
              ? null
              : 'This native frame does not expose a Lua local scope.',
          localsTruncated: frame.localsTruncated || frame.locals.length > 128,
        ),
      );
    }
    if (_stopping || epoch != _epoch || _snapshot.isTerminal) return;
    _generation = generation;
    _captureOutput(source);
    if (frameNamesTruncated) {
      const note = 'Lua frame names were truncated to 1024 UTF-16 units.\n';
      if (!_console.contains(note)) {
        final console = _tail('$_console$note', _outputLimit);
        _console = console.text;
        _consoleTruncated = _consoleTruncated || console.truncated;
      }
    }
    _verifyBreakpoints(frames);
    _publish(
      DebugPhase.paused,
      pauseToken: DebugPauseToken(sessionId: id, generation: generation),
      frames: frames,
      framesTruncated:
          source.framesTruncated ||
          source.frames.length > 64 ||
          frameNamesTruncated,
    );
  }

  Future<DebugSourceLocation?> _location(LuaDebugFrame frame) async {
    if (!frame.fileBacked || frame.line <= 0 || frame.file.contains('\u0000')) {
      return null;
    }
    try {
      final input = p.isAbsolute(frame.file)
          ? frame.file
          : p.join(_root, frame.file);
      if (input.length > 4096) return null;
      final path = p.normalize(await File(input).resolveSymbolicLinks());
      if (!p.isWithin(_root, path) ||
          path.length > 4096 ||
          await FileSystemEntity.type(path) != FileSystemEntityType.file) {
        return null;
      }
      return DebugSourceLocation(filePath: path, line: frame.line);
    } on FileSystemException {
      return null;
    }
  }

  DebugVariable _variable(LuaDebugLocal variable) {
    final name = _prefix(variable.name, 1024);
    final type = _prefix(variable.type, 64);
    final value = _prefix(variable.value, 4096);
    final primitive = const {
      'nil',
      'boolean',
      'number',
      'string',
    }.contains(variable.type);
    return DebugVariable(
      name: name.text,
      type: type.text,
      value: value.text,
      unavailableReason: primitive
          ? null
          : 'Lua exposes only the type of this value; object contents are unavailable.',
      truncated:
          variable.truncated ||
          name.truncated ||
          type.truncated ||
          value.truncated,
    );
  }

  void _verifyBreakpoints(List<DebugFrame> frames) {
    final top = frames.isEmpty ? null : frames.first.location;
    if (top == null) return;
    _breakpoints = [
      for (final item in _breakpoints)
        if (p.equals(item.requested.filePath, top.filePath) &&
            item.requested.line == top.line)
          DebugBreakpointResult(
            requested: item.requested,
            status: DebugBreakpointStatus.verified,
            actualLocation: top,
          )
        else
          item,
    ];
  }

  void _captureOutput(LuaDebugSnapshot source) {
    final stdout = _tail(source.stdout, _outputLimit);
    final stderr = _tail(source.stderr, _outputLimit);
    _stdout = stdout.text;
    _stderr = stderr.text;
    _stdoutTruncated = _stdoutTruncated || stdout.truncated;
    _stderrTruncated = _stderrTruncated || stderr.truncated;
  }

  void _publish(
    DebugPhase phase, {
    DebugPauseToken? pauseToken,
    List<DebugFrame> frames = const [],
    bool framesTruncated = false,
    String? message,
    int? exitCode,
  }) {
    if (_updates.isClosed) return;
    _snapshot = DebugSnapshot(
      sessionId: id,
      revision: _snapshot.revision + 1,
      phase: phase,
      pauseToken: pauseToken,
      threads: phase == DebugPhase.terminated || phase == DebugPhase.failed
          ? const []
          : [
              DebugThread(
                id: _threadId,
                name: 'Lua main thread',
                isPaused: phase == DebugPhase.paused,
              ),
            ],
      frames: frames,
      framesTruncated: framesTruncated,
      breakpoints: _breakpoints,
      stdout: _stdout,
      stderr: _stderr,
      console: _console,
      stdoutTruncated: _stdoutTruncated,
      stderrTruncated: _stderrTruncated,
      consoleTruncated: _consoleTruncated,
      message: message == null ? null : _prefix(message, 4096).text,
      exitCode: exitCode,
    );
    _updates.add(_snapshot);
  }

  void _ensureOpen() {
    if (_stopping || _snapshot.isTerminal || _disposing != null) {
      throw StateError('The Lua debug session is stopping or has ended.');
    }
  }

  @override
  Future<List<DebugBreakpointResult>> setBreakpoints(
    List<DebugBreakpoint> breakpoints,
  ) async {
    _ensureOpen();
    if (_snapshot.phase != DebugPhase.paused || _changingBreakpoints) {
      throw StateError('Lua breakpoints can only be replaced while paused.');
    }
    final token = _snapshot.pauseToken;
    _changingBreakpoints = true;
    try {
      // Validate the whole replacement before mutating the real backend.
      final canonical = await _canonicalBreakpoints(breakpoints, _root);
      _ensureOpen();
      if (_snapshot.pauseToken != token) {
        throw StateError('The observed Lua pause has changed.');
      }
      await _runtime.setBreakpoints([
        for (final item in canonical) LuaBreakpoint(item.filePath, item.line),
      ]);
      _ensureOpen();
      _breakpoints = _pendingBreakpoints(canonical);
      _verifyBreakpoints(_snapshot.frames);
      _publish(
        DebugPhase.paused,
        pauseToken: token,
        frames: _snapshot.frames,
        framesTruncated: _snapshot.framesTruncated,
      );
      return _snapshot.breakpoints;
    } finally {
      _changingBreakpoints = false;
    }
  }

  @override
  Future<void> command(
    DebugCommand command, {
    DebugPauseToken? pauseToken,
    String? threadId,
  }) async {
    _ensureOpen();
    if (threadId != null && threadId != _threadId) {
      throw ArgumentError.value(threadId, 'threadId', 'Unknown Lua thread.');
    }
    if (command == DebugCommand.pause) {
      if (_snapshot.phase != DebugPhase.running || !_runtime.running) {
        throw StateError('Pause requires a running Lua session.');
      }
      if (pauseToken != null) {
        throw StateError('A running Lua session has no current pause token.');
      }
      _runtime.pause();
      return;
    }
    if (_changingBreakpoints ||
        _snapshot.phase != DebugPhase.paused ||
        pauseToken == null ||
        pauseToken != _snapshot.pauseToken) {
      throw StateError('Resume and step require the current Lua pause token.');
    }
    final action = switch (command) {
      DebugCommand.resume => LuaDebugAction.continueRun,
      DebugCommand.stepInto => LuaDebugAction.stepInto,
      DebugCommand.stepOver => LuaDebugAction.stepOver,
      DebugCommand.stepOut => LuaDebugAction.stepOut,
      DebugCommand.pause => throw StateError('Unexpected pause command.'),
    };
    final execution = _runtime.resume(action);
    _epoch++;
    _publish(DebugPhase.running);
    // Acknowledge dispatch now, so a long-running resume cannot queue stop/pause.
    unawaited(execution.then<void>((_) {}, onError: _backendFailed));
  }

  void _backendFailed(Object error) {
    if (_snapshot.isTerminal) return;
    _recordFailure(error);
    unawaited(stop().catchError(_cleanupFailed));
  }

  void _recordFailure(Object error, {StackTrace? stackTrace}) {
    final failure = _prefix('Lua debugger failed: $error', 4096);
    final stack = stackTrace == null ? null : _prefix('$stackTrace', 4096);
    _failure ??= failure.text;
    _consoleTruncated =
        _consoleTruncated || failure.truncated || (stack?.truncated ?? false);
    final entry = '${failure.text}\n${stack == null ? '' : '${stack.text}\n'}';
    if (_console.contains(entry)) return;
    final console = _tail('$_console$entry', _outputLimit);
    _console = console.text;
    _consoleTruncated = _consoleTruncated || console.truncated;
  }

  void _cleanupFailed(Object error) {
    if (_snapshot.isTerminal) return;
    _publish(
      DebugPhase.stopping,
      message: 'Lua worker cleanup has not completed: $error',
    );
  }

  @override
  Future<void> stop() {
    final current = _stoppingFuture;
    if (current != null) return current;
    final attempt = _stop();
    _stoppingFuture = attempt;
    unawaited(
      attempt.then<void>(
        (_) {},
        onError: (Object error) {
          if (identical(_stoppingFuture, attempt)) _stoppingFuture = null;
        },
      ),
    );
    return attempt;
  }

  Future<void> _stop() async {
    if (_snapshot.isTerminal) return done;
    _stopping = true;
    _epoch++;
    _publish(DebugPhase.stopping);
    try {
      await _runtime.stop();
    } catch (error) {
      // A worker/command failure must not bypass the runtime's finally cleanup.
      _recordFailure(error);
    }
    await _finish();
  }

  Future<void> _finish() {
    final current = _completion;
    if (current != null) return current;
    final attempt = _finishWorker();
    _completion = attempt;
    unawaited(
      attempt.then<void>(
        (_) {},
        onError: (Object error) {
          if (identical(_completion, attempt)) _completion = null;
          _recordFailure(error);
          _cleanupFailed(error);
        },
      ),
    );
    return attempt;
  }

  Future<void> _finishWorker() async {
    _stopping = true;
    _epoch++;
    if (!_snapshot.isTerminal && _snapshot.phase != DebugPhase.stopping) {
      _publish(DebugPhase.stopping);
    }
    // dispose awaits stop, native VM free and the actual worker isolate exit.
    try {
      await _runtime.dispose();
    } catch (error) {
      _recordFailure(error);
      // The real runtime can rethrow an earlier stop error after its finally
      // completed cleanup. A rejection before worker exit remains retryable,
      // with ownership and `done` retained by this stopping session.
      if (!_workerHasExited) rethrow;
    }
    // Keep this independent of the dispose acknowledgement: it is not proof
    // that the persistent worker has actually exited.
    await _runtime.workerExited;
    await _subscription.cancel();
    final source = _runtime.snapshot;
    _captureOutput(source);
    final status = source.status;
    final failed =
        _failure != null || (status != null && status != 0 && status != 130);
    _publish(
      failed ? DebugPhase.failed : DebugPhase.terminated,
      exitCode: status,
      message:
          _failure ??
          (failed
              ? (_stderr.isEmpty ? 'Lua exited with status $status.' : _stderr)
              : status == 130
              ? 'Lua execution stopped.'
              : null),
    );
    _done.complete();
  }

  @override
  Future<void> dispose() {
    final current = _disposing;
    if (current != null) return current;
    final attempt = _dispose();
    _disposing = attempt;
    unawaited(
      attempt.then<void>(
        (_) {},
        onError: (Object error) {
          if (identical(_disposing, attempt)) _disposing = null;
        },
      ),
    );
    return attempt;
  }

  Future<void> _dispose() async {
    await stop();
    await done;
    await _updates.close();
  }
}

class _BoundedText {
  const _BoundedText(this.text, this.truncated);
  final String text;
  final bool truncated;
}

_BoundedText _prefix(String text, int limit) {
  if (text.length <= limit) return _BoundedText(text, false);
  var end = limit;
  if (_highSurrogate(text.codeUnitAt(end - 1)) &&
      _lowSurrogate(text.codeUnitAt(end))) {
    end--;
  }
  return _BoundedText(text.substring(0, end), true);
}

_BoundedText _tail(String text, int limit) {
  if (text.length <= limit) return _BoundedText(text, false);
  var start = text.length - limit;
  if (_lowSurrogate(text.codeUnitAt(start)) &&
      _highSurrogate(text.codeUnitAt(start - 1))) {
    start++;
  }
  return _BoundedText(text.substring(start), true);
}

bool _highSurrogate(int unit) => unit >= 0xd800 && unit <= 0xdbff;
bool _lowSurrogate(int unit) => unit >= 0xdc00 && unit <= 0xdfff;
