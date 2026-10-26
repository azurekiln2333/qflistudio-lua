import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/code_analysis.dart';

/// Finds an actual local POSIX shell, never PowerShell or a command string.
Future<String?> findPosixShell() async {
  if (Platform.operatingSystem == 'ohos' || Platform.isAndroid) {
    for (final candidate in ['/system/bin/sh', '/bin/sh']) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }
  for (final name in ['sh', 'bash']) {
    final found = await _runBoundedProcess(
      Platform.isWindows ? 'where' : 'which',
      [name],
      '',
    );
    if (found.failure != null || found.exitCode != 0) continue;
    for (final line in const LineSplitter().convert(found.stdout)) {
      final candidate = p.normalize(line.trim());
      if (p.isAbsolute(candidate) && await File(candidate).exists()) {
        return candidate;
      }
    }
  }
  return null;
}

/// Parses the exact unsaved buffer with `sh -n -s` over standard input.
///
/// No user command is executed, and no source or temporary file is written.
/// Shells report lines rather than reliable columns, so diagnostics cover the
/// original UTF-16 line, preserving CRLF and any preceding Unicode text.
class ShellCodeAnalyzer implements CodeAnalyzer {
  const ShellCodeAnalyzer({this.shellFinder = findPosixShell});

  static const maximumSourceLength = 1024 * 1024;
  final Future<String?> Function() shellFinder;

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) async {
    if (!const {
      'shell',
      'sh',
      'bash',
    }.contains(request.language.trim().toLowerCase())) {
      return _unavailable('The local shell parser only checks Shell source.');
    }
    final root = p.normalize(request.projectPath);
    final path = p.normalize(request.activeFilePath);
    if (request.projectPath.contains('\u0000') ||
        request.activeFilePath.contains('\u0000') ||
        !p.isAbsolute(root) ||
        !p.isAbsolute(path) ||
        !p.isWithin(root, path)) {
      return _unavailable('The active Shell file is outside its project.');
    }
    if (p.extension(path).toLowerCase() != '.sh') {
      return _unavailable('Shell diagnostics require a .sh source file.');
    }

    CodeDocumentSnapshot? active;
    final paths = <String>[];
    for (final snapshot in request.documents) {
      final documentPath = p.normalize(snapshot.path);
      if (snapshot.path.contains('\u0000') ||
          !p.isAbsolute(documentPath) ||
          !p.isWithin(root, documentPath)) {
        return _unavailable('An editor snapshot is outside its project.');
      }
      if (paths.any((known) => p.equals(known, documentPath))) {
        return _unavailable('An editor snapshot is duplicated.');
      }
      paths.add(documentPath);
      if (snapshot.text.contains('\u0000')) {
        return _unavailable('Shell source cannot contain NUL bytes.');
      }
      if (snapshot.text.length > maximumSourceLength) {
        return _unavailable('Shell source is too large for live diagnostics.');
      }
      if (p.equals(path, documentPath)) active = snapshot;
    }
    if (active == null || active.revision != request.revision) {
      return _unavailable('The current Shell editor snapshot is unavailable.');
    }

    final String? shell;
    try {
      shell = await shellFinder();
    } catch (error) {
      return _unavailable('The local Shell parser is unavailable: $error');
    }
    if (shell == null ||
        shell.contains('\u0000') ||
        !p.isAbsolute(shell) ||
        !await File(shell).exists()) {
      return _unavailable('No local POSIX shell parser is available.');
    }
    final parsed = await _runBoundedProcess(shell, ['-n', '-s'], active.text);
    if (parsed.failure != null) return _unavailable(parsed.failure!);
    if (parsed.stdout.isNotEmpty) {
      return _unavailable('The Shell parser unexpectedly produced output.');
    }
    if (parsed.exitCode == 0 && parsed.stderr.isEmpty) {
      return const CodeAnalysisResult();
    }
    if (parsed.exitCode == 0) {
      return _unavailable('The Shell parser reported: ${parsed.stderr.trim()}');
    }

    final location = _diagnosticLocation(parsed.stderr);
    if (location == null) {
      return _unavailable(
        'The Shell parser failed (status ${parsed.exitCode}): '
        '${parsed.stderr.trim()}',
      );
    }
    final range = _lineRange(active.text, location.$1, location.$2);
    if (range == null) {
      return _unavailable(
        'The Shell diagnostic is outside the editor snapshot.',
      );
    }
    return CodeAnalysisResult(
      diagnostics: [
        CodeDiagnostic(
          filePath: path,
          startOffset: range.$1,
          endOffset: range.$2,
          message: location.$2,
          source: 'Shell',
          code: 'shell.syntax',
        ),
      ],
    );
  }

  static CodeAnalysisResult _unavailable(String reason) =>
      CodeAnalysisResult(unavailableReason: reason);

  static (int, String)? _diagnosticLocation(String stderr) {
    // bash, dash, mksh (OHOS/Android), and ksh respectively. Unknown parser or
    // loader failures stay unavailable instead of acquiring invented ranges.
    final patterns = [
      RegExp(r'^.*?: line ([0-9]+):\s*(.+)$'),
      RegExp(r'^.*?: ([0-9]+):\s*(.+)$'),
      RegExp(r'^.*?\[([0-9]+)\]:\s*(.+)$'),
      RegExp(r'^.*?: syntax error at line ([0-9]+):\s*(.+)$'),
    ];
    for (final line in const LineSplitter().convert(stderr)) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;
        final number = int.tryParse(match.group(1)!);
        final message = match.group(2)!.trim();
        if (number != null && number > 0 && message.isNotEmpty) {
          return (number, message);
        }
      }
    }
    return null;
  }

  static (int, int)? _lineRange(String source, int requested, String message) {
    var line = 1;
    var start = 0;
    for (var offset = 0; offset < source.length; offset++) {
      if (source.codeUnitAt(offset) != 10) continue;
      if (line == requested) {
        final end = offset > start && source.codeUnitAt(offset - 1) == 13
            ? offset - 1
            : offset;
        return (start, end);
      }
      line++;
      start = offset + 1;
    }
    if (line == requested) return (start, source.length);
    // Some shells synthesize a final newline and report EOF on the next line.
    if (requested == line + 1 &&
        RegExp(
          r'end of file|end-of-file|\bEOF\b',
          caseSensitive: false,
        ).hasMatch(message)) {
      return (source.length, source.length);
    }
    return null;
  }
}

class _ShellProcessResult {
  const _ShellProcessResult({
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.failure,
  });
  final int? exitCode;
  final String stdout;
  final String stderr;
  final String? failure;
}

Future<_ShellProcessResult> _runBoundedProcess(
  String executable,
  List<String> arguments,
  String source,
) async {
  final Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      environment: const {
        'LC_ALL': 'C',
        'LANG': 'C',
        'ENV': '',
        'BASH_ENV': '',
      },
    );
  } catch (error) {
    return _ShellProcessResult(
      failure: 'Cannot start the local Shell parser: $error',
    );
  }
  final stdout = BytesBuilder(copy: false);
  final stderr = BytesBuilder(copy: false);
  const outputLimit = 64 * 1024;
  var captured = 0;
  String? failure;
  Object? inputFailure;
  void abort(String reason) {
    failure ??= reason;
    process.kill(ProcessSignal.sigkill);
  }

  Future<void> drain(Stream<List<int>> stream, BytesBuilder target) async {
    try {
      await for (final chunk in stream) {
        final remaining = outputLimit - captured;
        if (chunk.length <= remaining) {
          target.add(chunk);
          captured += chunk.length;
        } else {
          if (remaining > 0) target.add(chunk.sublist(0, remaining));
          captured = outputLimit;
          abort('The Shell parser output exceeded 64 KiB.');
        }
      }
    } catch (error) {
      abort('Cannot read the Shell parser output: $error');
    }
  }

  Future<void> sendSource() async {
    try {
      process.stdin.add(utf8.encode(source));
      await process.stdin.flush();
    } catch (error) {
      inputFailure = error;
    } finally {
      try {
        await process.stdin.close();
      } catch (error) {
        inputFailure ??= error;
      }
    }
  }

  final timer = Timer(const Duration(seconds: 3), () {
    abort('The Shell parser timed out after 3 seconds.');
  });
  final drains = [drain(process.stdout, stdout), drain(process.stderr, stderr)];
  final input = sendSource();
  int? status;
  try {
    status = await process.exitCode;
    await Future.wait([input, ...drains]);
  } catch (error) {
    abort('The Shell parser failed: $error');
    await process.exitCode;
    await Future.wait([input, ...drains]);
  } finally {
    timer.cancel();
  }
  if (inputFailure != null && status == 0) {
    failure ??=
        'Cannot send the editor text to the Shell parser: $inputFailure';
  }
  return _ShellProcessResult(
    exitCode: status,
    stdout: utf8.decode(stdout.takeBytes(), allowMalformed: true),
    stderr: utf8.decode(stderr.takeBytes(), allowMalformed: true),
    failure: failure,
  );
}
