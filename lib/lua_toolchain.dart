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
typedef _RunWithArgvNative =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Int32,
      Pointer<Pointer<Utf8>>,
      Int32,
      Int32,
      Pointer<Void>,
    );
typedef _RunWithArgvDart =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      Pointer<Pointer<Utf8>>,
      int,
      int,
      Pointer<Void>,
    );
typedef _CompileExNative =
    Pointer<_NativeResult> Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _CompileExDart =
    Pointer<_NativeResult> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _CheckSourceNative =
    Pointer<_NativeResult> Function(Pointer<Utf8>, UintPtr, Pointer<Utf8>);
typedef _CheckSourceDart =
    Pointer<_NativeResult> Function(Pointer<Utf8>, int, Pointer<Utf8>);

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

  /// Uses the same bundled-library resolution for all product-owned VM tools.
  DynamicLibrary openNativeLibrary() => _openLibrary(libraryPath);

  Future<LuaToolResult> run({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
    List<String> commandLine = const [],
    int scriptIndex = 1,
  }) => startRun(
    file: file,
    projectDirectory: projectDirectory,
    timeLimit: timeLimit,
    commandLine: commandLine,
    scriptIndex: scriptIndex,
  ).result;

  /// Starts [file] with cancellation and a time limit.
  ///
  /// [commandLine] is the full command line as typed, starting with the
  /// interpreter name (`['lua', 'main.lua', 'a', 'b']`), and [scriptIndex] is
  /// the position of the executed script inside it. The native entry point then
  /// builds the global `arg` table and the chunk varargs exactly like the
  /// upstream interpreter, so `arg[0]` is the script name the user typed,
  /// `arg[1..]` / `...` are its arguments, and `arg[-1]` is the interpreter.
  ///
  /// An empty [commandLine] keeps the plain shape: `arg[0]` is [file] and the
  /// chunk receives no varargs.
  LuaExecution startRun({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
    List<String> commandLine = const [],
    int scriptIndex = 1,
  }) {
    if (commandLine.isNotEmpty &&
        (scriptIndex < 0 || scriptIndex >= commandLine.length)) {
      throw ArgumentError.value(
        scriptIndex,
        'scriptIndex',
        'must index the executed script inside commandLine',
      );
    }
    final arguments = List<String>.unmodifiable(commandLine);
    if ([
      file,
      projectDirectory,
      ...arguments,
    ].any((value) => value.contains('\u0000'))) {
      throw ArgumentError('Lua paths and arguments cannot contain NUL');
    }
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
            tokenAddress: token.address,
            commandLine: arguments,
            scriptIndex: scriptIndex,
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

  /// Parses an unsaved UTF-8 source buffer without executing it or opening libraries.
  /// Native Lua parser statuses are preserved (3 means a syntax error).
  Future<LuaToolResult> checkSource(
    String source, {
    String chunkName = '@editor.lua',
  }) {
    if (chunkName.contains('\u0000')) {
      throw ArgumentError.value(chunkName, 'chunkName');
    }
    final path = libraryPath;
    return Isolate.run(
      () => _invokeNative(path, 'source', source, chunkName, 0),
    );
  }

  /// Loads source or bytecode without executing; an output path dumps a chunk.
  Future<LuaToolResult> load(
    String file, {
    String? outputFile,
    bool stripDebug = false,
  }) {
    final path = libraryPath;
    return Isolate.run(
      () => _invokeNative(
        path,
        'load',
        file,
        outputFile,
        0,
        strip: stripDebug ? 1 : 0,
      ),
    );
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

  /// The banner the upstream interpreter prints for `lua -v`.
  ///
  /// Older bundled libraries predate `qfli_lua_copyright`; they fall back to
  /// the bare [version] string instead of inventing a copyright line the
  /// loaded VM may not match.
  String copyright() {
    final library = _openLibrary(libraryPath);
    final Pointer<Utf8> Function()? native;
    try {
      native = library.lookupFunction<_VersionNative, _VersionDart>(
        'qfli_lua_copyright',
      );
    } on ArgumentError {
      return version();
    }
    return native().toDartString();
  }

  /// Whether the bundled library exposes the command-line entry point.
  ///
  /// A packaged library that predates `qfli_lua_run_with_argv` cannot receive
  /// script arguments; callers must report that honestly instead of silently
  /// dropping them.
  bool get supportsCommandLine {
    try {
      _openLibrary(
        libraryPath,
      ).lookup<NativeFunction<_RunWithArgvNative>>('qfli_lua_run_with_argv');
      return true;
    } on ArgumentError {
      return false;
    }
  }
}

DynamicLibrary _openLibrary(String? explicitPath) {
  if (explicitPath != null) return DynamicLibrary.open(explicitPath);
  if (Platform.isIOS) return DynamicLibrary.process();
  if (Platform.isMacOS) {
    final linked = DynamicLibrary.process();
    if (linked.providesSymbol('qfli_lua_version')) return linked;
  }
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
  int timeoutMs, {
  int tokenAddress = 0,
  List<String> commandLine = const [],
  int scriptIndex = 1,
  int strip = 0,
}) {
  final library = _openLibrary(libraryPath);
  final free = library.lookupFunction<_FreeNative, _FreeDart>('qfli_lua_free');
  final first = file.toNativeUtf8();
  final second = secondPath?.toNativeUtf8();
  // The native call builds the table before returning and never keeps these
  // pointers, so they only have to outlive this isolate's call.
  Pointer<Pointer<Utf8>> argv = nullptr;
  final owned = <Pointer<Utf8>>[];
  try {
    final Pointer<_NativeResult> result;
    switch (action) {
      case 'run':
        final Pointer<_NativeResult> Function(
          Pointer<Utf8>,
          Pointer<Utf8>,
          int,
          Pointer<Void>,
        )
        runWithToken;
        var argvCount = 0;
        if (commandLine.isEmpty) {
          runWithToken = library
              .lookupFunction<_RunWithTokenNative, _RunWithTokenDart>(
                'qfli_lua_run_with_token',
              );
        } else {
          final runWithArgv = library
              .lookupFunction<_RunWithArgvNative, _RunWithArgvDart>(
                'qfli_lua_run_with_argv',
              );
          argvCount = commandLine.length;
          argv = calloc<Pointer<Utf8>>(argvCount);
          for (var index = 0; index < argvCount; index++) {
            final encoded = commandLine[index].toNativeUtf8();
            owned.add(encoded);
            argv[index] = encoded;
          }
          runWithToken =
              (
                Pointer<Utf8> entry,
                Pointer<Utf8> project,
                int timeout,
                Pointer<Void> token,
              ) => runWithArgv(
                entry,
                project,
                timeout,
                argv,
                argvCount,
                scriptIndex,
                token,
              );
        }
        result = runWithToken(
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
      case 'load':
        final load = library.lookupFunction<_CompileExNative, _CompileExDart>(
          'qfli_lua_compile_ex',
        );
        result = load(first, second ?? nullptr, strip);
      case 'source':
        final check = library
            .lookupFunction<_CheckSourceNative, _CheckSourceDart>(
              'qfli_lua_check_source',
            );
        result = check(first, utf8.encode(file).length, second ?? nullptr);
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
    for (final encoded in owned) {
      calloc.free(encoded);
    }
    if (argv != nullptr) calloc.free(argv);
  }
}
