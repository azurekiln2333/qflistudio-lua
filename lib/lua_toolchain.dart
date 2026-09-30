import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

final class _NativeResult extends Struct {
  @Int32()
  external int status;

  external Pointer<Utf8> output;
  external Pointer<Utf8> error;

  @UintPtr()
  external int outputLength;

  @UintPtr()
  external int errorLength;
}

typedef _RunWithTokenNative =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Pointer<Void>,
    );
typedef _RunWithTokenDart =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      Pointer<Void>,
    );
typedef _NewTokenNative = Pointer<Void> Function();
typedef _NewTokenDart = Pointer<Void> Function();
typedef _TokenActionNative = Void Function(Pointer<Void>);
typedef _TokenActionDart = void Function(Pointer<Void>);
typedef _TwoPathNative =
    Pointer<_NativeResult> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _TwoPathDart =
    Pointer<_NativeResult> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _OnePathNative = Pointer<_NativeResult> Function(Pointer<Utf8>);
typedef _OnePathDart = Pointer<_NativeResult> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<_NativeResult>);
typedef _FreeDart = void Function(Pointer<_NativeResult>);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();

class LuaToolResult {
  const LuaToolResult({
    required this.status,
    required this.output,
    required this.error,
  });

  final int status;
  final String output;
  final String error;

  bool get success => status == 0;
}

class LuaExecution {
  const LuaExecution._(this.result, this._cancel);

  final Future<LuaToolResult> result;
  final void Function() _cancel;

  Future<void> cancel() async => _cancel();
}

/// Loads the bundled upstream Lua VM. Each operation owns a fresh Lua state.
class LuaToolchain {
  const LuaToolchain({this.libraryPath});

  final String? libraryPath;

  Future<LuaToolResult> run({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
  }) => startRun(
    file: file,
    projectDirectory: projectDirectory,
    timeLimit: timeLimit,
  ).result;

  LuaExecution startRun({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
  }) {
    final path = libraryPath;
    final library = _openLibrary(path);
    final newToken = library.lookupFunction<_NewTokenNative, _NewTokenDart>(
      'qfli_lua_token_new',
    );
    final cancelToken = library
        .lookupFunction<_TokenActionNative, _TokenActionDart>(
          'qfli_lua_token_cancel',
        );
    final freeToken = library
        .lookupFunction<_TokenActionNative, _TokenActionDart>(
          'qfli_lua_token_free',
        );
    final token = newToken();
    if (token == nullptr) throw StateError('Lua runtime is out of memory');
    var finished = false;
    final result =
        Isolate.run(
          () => _invokeNative(
            path,
            'run',
            file,
            projectDirectory,
            timeLimit.inMilliseconds,
            token.address,
          ),
        ).whenComplete(() {
          finished = true;
          freeToken(token);
        });
    return LuaExecution._(result, () {
      if (!finished) cancelToken(token);
    });
  }

  Future<LuaToolResult> check(String file) {
    final path = libraryPath;
    return Isolate.run(() => _invokeNative(path, 'check', file, null, 0));
  }

  Future<LuaToolResult> compile(String file, String outputFile) {
    final path = libraryPath;
    return Isolate.run(
      () => _invokeNative(path, 'compile', file, outputFile, 0),
    );
  }

  String version() {
    final library = _openLibrary(libraryPath);
    final native = library.lookupFunction<_VersionNative, _VersionDart>(
      'qfli_lua_version',
    );
    return native().toDartString();
  }
}

DynamicLibrary _openLibrary(String? explicitPath) {
  if (explicitPath != null) return DynamicLibrary.open(explicitPath);
  final name = Platform.isWindows
      ? 'libqfli_lua.dll'
      : Platform.isMacOS
      ? 'libqfli_lua.dylib'
      : 'libqfli_lua.so';
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final executableDirectory = File(Platform.resolvedExecutable).parent.path;
    final bundled = p.join(executableDirectory, name);
    if (File(bundled).existsSync()) return DynamicLibrary.open(bundled);
    final bundledLib = p.join(executableDirectory, 'lib', name);
    if (File(bundledLib).existsSync()) return DynamicLibrary.open(bundledLib);
    final development = p.join(
      Directory.current.path,
      'native',
      'build',
      Platform.isWindows
          ? 'windows'
          : Platform.isLinux
          ? 'linux'
          : 'macos',
      name,
    );
    if (File(development).existsSync()) return DynamicLibrary.open(development);
  }
  return DynamicLibrary.open(name);
}

LuaToolResult _invokeNative(
  String? libraryPath,
  String action,
  String file,
  String? secondPath,
  int timeoutMs, [
  int tokenAddress = 0,
]) {
  final library = _openLibrary(libraryPath);
  final free = library.lookupFunction<_FreeNative, _FreeDart>('qfli_lua_free');
  final first = file.toNativeUtf8();
  final second = secondPath?.toNativeUtf8();
  try {
    final Pointer<_NativeResult> result;
    switch (action) {
      case 'run':
        final run = library
            .lookupFunction<_RunWithTokenNative, _RunWithTokenDart>(
              'qfli_lua_run_with_token',
            );
        result = run(
          first,
          second ?? nullptr,
          timeoutMs,
          Pointer<Void>.fromAddress(tokenAddress),
        );
      case 'check':
        final check = library.lookupFunction<_OnePathNative, _OnePathDart>(
          'qfli_lua_check',
        );
        result = check(first);
      case 'compile':
        final compile = library.lookupFunction<_TwoPathNative, _TwoPathDart>(
          'qfli_lua_compile',
        );
        result = compile(first, second ?? nullptr);
      default:
        throw ArgumentError.value(action, 'action');
    }
    if (result == nullptr) throw StateError('Lua runtime is out of memory');
    try {
      return LuaToolResult(
        status: result.ref.status,
        output: utf8.decode(
          result.ref.output.cast<Uint8>().asTypedList(result.ref.outputLength),
          allowMalformed: true,
        ),
        error: utf8.decode(
          result.ref.error.cast<Uint8>().asTypedList(result.ref.errorLength),
          allowMalformed: true,
        ),
      );
    } finally {
      free(result);
    }
  } finally {
    calloc.free(first);
    if (second != null) calloc.free(second);
  }
}
