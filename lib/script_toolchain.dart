import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ScriptDiagnostic {
  const ScriptDiagnostic({
    required this.filePath,
    required this.startOffset,
    required this.endOffset,
    required this.message,
    required this.code,
    this.category = 1,
  });
  final String filePath;
  final int startOffset, endOffset;
  final String message, code;

  /// TypeScript categories:0warning,1error,2suggestion,3message.
  final int category;
}

class ScriptToolResult {
  const ScriptToolResult({
    required this.status,
    this.output = '',
    this.error = '',
    this.diagnostics = const [],
  });
  final int status;
  final String output, error;
  final List<ScriptDiagnostic> diagnostics;
  bool get success => status == 0;
  String? get unavailableReason => status == 127 ? error : null;
}

class ScriptExecution {
  const ScriptExecution._(this.result, this._cancel);
  final Future<ScriptToolResult> result;
  final void Function() _cancel;
  Future<void> cancel() async => _cancel();
}

/// Embedded QuickJS plus the official offline TypeScript transpileModule.
///
/// No Node/browser/network/OS bindings. Relative ES modules come from saved
/// root-owned project files. TypeScript checks syntax/options, not semantic
/// project types. Every operation owns a fresh VM and never mutates source.
class ScriptToolchain {
  const ScriptToolchain({this.libraryPath, this.typescriptCompilerPath});
  final String? libraryPath, typescriptCompilerPath;
  static const maximumSourceBytes = 512 * 1024;
  static final _compilerSources = <String, Future<String>>{};

  Future<ScriptToolResult> run({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
  }) => startRun(
    file: file,
    projectDirectory: projectDirectory,
    timeLimit: timeLimit,
  ).result;

  ScriptExecution startRun({
    required String file,
    required String projectDirectory,
    Duration timeLimit = const Duration(seconds: 10),
  }) {
    final _Bindings bindings;
    final Pointer<Void> token;
    try {
      bindings = _Bindings(_open(libraryPath));
      token = bindings.newToken();
      if (token == nullptr) {
        throw StateError('Cannot allocate Script cancellation token');
      }
    } catch (error) {
      return ScriptExecution._(
        Future.value(
          ScriptToolResult(
            status: 127,
            error: 'Script runtime unavailable: $error',
          ),
        ),
        () {},
      );
    }
    var finished = false;
    var cancelled = false;
    void checkCancelled() {
      if (cancelled) throw const _PreparationCancelled();
    }

    Future<ScriptToolResult> prepare() async {
      try {
        _limit(timeLimit);
        final root = p.normalize(
          await Directory(projectDirectory).resolveSymbolicLinks(),
        );
        checkCancelled();
        final path = p.normalize(await File(file).resolveSymbolicLinks());
        checkCancelled();
        if (!p.isWithin(root, path)) {
          throw ArgumentError('Script entry is outside project');
        }
        final documents = await _documents(root, checkCancelled);
        final source = documents[_posix(path)];
        if (source == null) {
          throw StateError('Script entry is missing or unsupported');
        }
        final typescript = p.extension(path).toLowerCase() == '.ts';
        final needsCompiler =
            typescript ||
            documents.keys.any((key) => key.toLowerCase().endsWith('.ts'));
        final compiler = needsCompiler ? await _compiler() : '';
        checkCancelled();
        final encodedDocuments = jsonEncode(documents);
        final address = token.address, nativePath = libraryPath;
        return await Isolate.run(
          () => _invoke(
            nativePath,
            source,
            _posix(path),
            _posix(root),
            encodedDocuments,
            compiler,
            typescript,
            0,
            true,
            timeLimit.inMilliseconds,
            address,
          ),
        );
      } catch (error) {
        if (cancelled) {
          return const ScriptToolResult(
            status: 130,
            error: 'Script execution cancelled',
          );
        }
        return ScriptToolResult(
          status: 127,
          error: 'Script runtime unavailable: $error',
        );
      }
    }

    final result = prepare().whenComplete(() {
      finished = true;
      bindings.freeToken(token);
    });
    return ScriptExecution._(result, () {
      if (!finished) {
        cancelled = true;
        bindings.cancelToken(token);
      }
    });
  }

  Future<ScriptToolResult> checkSource(
    String source, {
    String? fileName,
    bool typescript = false,
    bool module = true,
  }) => _source(
    source,
    fileName ?? (typescript ? 'editor.ts' : 'editor.js'),
    typescript,
    1,
    module,
  );

  /// Output contains actual emitted JavaScript; user source is never executed.
  Future<ScriptToolResult> transpile(
    String source, {
    String fileName = 'editor.ts',
  }) => _source(source, fileName, true, 2, true);

  Future<ScriptToolResult> _source(
    String source,
    String file,
    bool typescript,
    int action,
    bool module,
  ) async {
    try {
      if (file.contains('\u0000') ||
          utf8.encode(source).length > maximumSourceBytes) {
        throw ArgumentError(
          'Script source exceeds 512 KiB or filename contains NUL',
        );
      }
      final compiler = typescript ? await _compiler() : '';
      final nativePath = libraryPath;
      return await Isolate.run(
        () => _invoke(
          nativePath,
          source,
          file,
          '',
          '{}',
          compiler,
          typescript,
          action,
          module,
          10000,
          0,
        ),
      );
    } catch (error) {
      return ScriptToolResult(
        status: 127,
        error: 'Script parser unavailable: $error',
      );
    }
  }

  Future<String> _compiler() {
    final key = typescriptCompilerPath ?? '<bundled>';
    return _compilerSources.putIfAbsent(key, () async {
      try {
        final path = typescriptCompilerPath;
        if (path != null) return await File(path).readAsString();
        return await rootBundle.loadString(
          'assets/runtime/typescript.js',
          cache: true,
        );
      } catch (_) {
        _compilerSources.remove(key);
        rethrow;
      }
    });
  }

  String version() => _Bindings(_open(libraryPath)).version().toDartString();
}

void _limit(Duration duration) {
  if (duration.inMilliseconds < 1 || duration.inMilliseconds > 0x7fffffff) {
    throw ArgumentError.value(duration, 'timeLimit');
  }
}

String _posix(String path) => path.replaceAll(r'\', '/');

class _PreparationCancelled implements Exception {
  const _PreparationCancelled();
}

Future<Map<String, String>> _documents(
  String root,
  void Function() checkCancelled,
) async {
  final pending = <Directory>[Directory(root)];
  final result = <String, String>{};
  var bytes = 0;
  var entries = 0;
  while (pending.isNotEmpty) {
    checkCancelled();
    final directory = pending.removeLast();
    await for (final entity in directory.list(followLinks: false)) {
      checkCancelled();
      if (++entries > 16384) {
        throw StateError('Script project exceeds 16384 directory entries');
      }
      if (entity is Directory) {
        if (!{
          '.git',
          '.qfli',
          'node_modules',
          'build',
        }.contains(p.basename(entity.path))) {
          pending.add(entity);
        }
      } else if (entity is File &&
          {
            '.js',
            '.mjs',
            '.ts',
          }.contains(p.extension(entity.path).toLowerCase())) {
        final length = await entity.length();
        bytes += length;
        if (length > ScriptToolchain.maximumSourceBytes ||
            bytes > 8 * 1024 * 1024 ||
            result.length >= 256) {
          throw StateError(
            'Script project exceeds 256 files/8 MiB or 512 KiB per source',
          );
        }
        final source = await entity.readAsString();
        checkCancelled();
        if (utf8.encode(source).length > ScriptToolchain.maximumSourceBytes) {
          throw StateError('Script source exceeds 512 KiB');
        }
        result[_posix(p.normalize(entity.path))] = source;
      }
    }
  }
  return result;
}

final class _NativeResult extends Struct {
  @Int32()
  external int status;
  external Pointer<Utf8> output;
  external Pointer<Utf8> error;
  external Pointer<Utf8> diagnostics;
  @UintPtr()
  external int outputLength;
  @UintPtr()
  external int errorLength;
  @UintPtr()
  external int diagnosticsLength;
}

typedef _NewNative = Pointer<Void> Function();
typedef _NewDart = Pointer<Void> Function();
typedef _TokenNative = Void Function(Pointer<Void>);
typedef _TokenDart = void Function(Pointer<Void>);
typedef _VersionNative = Pointer<Utf8> Function();
typedef _VersionDart = Pointer<Utf8> Function();
typedef _ProcessNative =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      UintPtr,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      UintPtr,
      Pointer<Utf8>,
      UintPtr,
      Int32,
      Int32,
      Int32,
      Int32,
      Pointer<Void>,
    );
typedef _ProcessDart =
    Pointer<_NativeResult> Function(
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
      Pointer<Utf8>,
      int,
      int,
      int,
      int,
      int,
      Pointer<Void>,
    );
typedef _FreeNative = Void Function(Pointer<_NativeResult>);
typedef _FreeDart = void Function(Pointer<_NativeResult>);

class _Bindings {
  _Bindings(DynamicLibrary library) {
    newToken = library.lookupFunction<_NewNative, _NewDart>(
      'qfli_script_token_new',
    );
    cancelToken = library.lookupFunction<_TokenNative, _TokenDart>(
      'qfli_script_token_cancel',
    );
    freeToken = library.lookupFunction<_TokenNative, _TokenDart>(
      'qfli_script_token_free',
    );
    process = library.lookupFunction<_ProcessNative, _ProcessDart>(
      'qfli_script_process',
    );
    free = library.lookupFunction<_FreeNative, _FreeDart>('qfli_script_free');
    version = library.lookupFunction<_VersionNative, _VersionDart>(
      'qfli_script_version',
    );
  }
  late final _NewDart newToken;
  late final _TokenDart cancelToken, freeToken;
  late final _ProcessDart process;
  late final _FreeDart free;
  late final _VersionDart version;
}

DynamicLibrary _open(String? explicitPath) {
  if (explicitPath != null) return DynamicLibrary.open(explicitPath);
  if (Platform.isIOS) return DynamicLibrary.process();
  final name = Platform.isWindows
      ? 'libqfli_script.dll'
      : Platform.isMacOS
      ? 'libqfli_script.dylib'
      : 'libqfli_script.so';
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final executable = p.dirname(Platform.resolvedExecutable);
    final platform = Platform.isWindows
        ? 'windows'
        : Platform.isLinux
        ? 'linux'
        : 'macos';
    for (final candidate in [
      p.join(executable, name),
      p.join(executable, 'lib', name),
      p.join(Directory.current.path, 'native', 'build', platform, name),
      p.join(
        Directory.current.path,
        'native',
        'build',
        'script-$platform',
        'script',
        name,
      ),
    ]) {
      if (File(candidate).existsSync()) return DynamicLibrary.open(candidate);
    }
  }
  return DynamicLibrary.open(name);
}

ScriptToolResult _invoke(
  String? library,
  String source,
  String file,
  String project,
  String documents,
  String compiler,
  bool typescript,
  int action,
  bool module,
  int timeout,
  int address,
) => using((arena) {
  final bindings = _Bindings(_open(library));
  final result = bindings.process(
    source.toNativeUtf8(allocator: arena),
    utf8.encode(source).length,
    file.toNativeUtf8(allocator: arena),
    project.toNativeUtf8(allocator: arena),
    documents.toNativeUtf8(allocator: arena),
    utf8.encode(documents).length,
    compiler.toNativeUtf8(allocator: arena),
    utf8.encode(compiler).length,
    typescript ? 1 : 0,
    action,
    module ? 1 : 0,
    timeout,
    Pointer<Void>.fromAddress(address),
  );
  if (result == nullptr) throw StateError('Cannot allocate Script result');
  String decode(Pointer<Utf8> pointer, int length) => utf8.decode(
    pointer.cast<Uint8>().asTypedList(length),
    allowMalformed: true,
  );
  try {
    final raw =
        jsonDecode(decode(result.ref.diagnostics, result.ref.diagnosticsLength))
            as List;
    final snapshots = action == 0
        ? jsonDecode(documents) as Map<String, dynamic>
        : <String, dynamic>{};
    final diagnostics = <ScriptDiagnostic>[];
    for (final item in raw.cast<Map<String, dynamic>>()) {
      final start = item['startOffset'] as int, end = item['endOffset'] as int;
      final diagnosticFile = item['filePath'] as String;
      final diagnosticSource = diagnosticFile == file
          ? source
          : snapshots[diagnosticFile] as String?;
      final category = item['severity'] as int;
      if (diagnosticSource == null ||
          start < 0 ||
          end < start ||
          end > diagnosticSource.length ||
          item['message'] is! String ||
          category < 0 ||
          category > 3) {
        throw StateError('Script parser returned an invalid source range');
      }
      diagnostics.add(
        ScriptDiagnostic(
          filePath: diagnosticFile,
          startOffset: start,
          endOffset: end,
          message: item['message'] as String,
          code: '${item['code']}',
          category: category,
        ),
      );
    }
    return ScriptToolResult(
      status: result.ref.status,
      output: decode(result.ref.output, result.ref.outputLength),
      error: decode(result.ref.error, result.ref.errorLength),
      diagnostics: List.unmodifiable(diagnostics),
    );
  } finally {
    bindings.free(result);
  }
});
