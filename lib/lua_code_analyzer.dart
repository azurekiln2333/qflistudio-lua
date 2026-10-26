import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/code_analysis.dart';

import 'lua_toolchain.dart';

/// Checks the exact editor snapshot with the bundled Lua parser.
///
/// Loading a text chunk does not execute it, load its modules, or touch its
/// project. Lua reports a line and sometimes a token, but no source column.
/// Ambiguous tokens therefore decorate the reported line instead of inventing
/// a column. Every returned offset indexes the original UTF-16 Dart string.
class LuaCodeAnalyzer implements CodeAnalyzer {
  const LuaCodeAnalyzer({this.toolchain = const LuaToolchain()});

  static const maximumSourceLength = 1024 * 1024;
  static const _chunkName = '@qfli-editor';
  static final _location = RegExp(r'^qfli-editor:([0-9]+):\s?([\s\S]*)$');
  static final _preambleText = RegExp(r'[^\r\n]');
  static final _plainToken = RegExp(
    r'^(?:[A-Za-z_][A-Za-z0-9_]*|[0-9][A-Za-z0-9_.]*|[+*/%^#&|~<>=;:,().{}\[\]-]{1,3})$',
  );

  final LuaToolchain toolchain;

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) async {
    if (request.language.trim().toLowerCase() != 'lua') {
      return _unavailable('The bundled Lua parser only checks Lua source.');
    }
    final root = p.normalize(request.projectPath);
    final path = p.normalize(request.activeFilePath);
    if (root.contains('\u0000') ||
        path.contains('\u0000') ||
        !p.isAbsolute(root) ||
        !p.isAbsolute(path) ||
        !p.isWithin(root, path)) {
      return _unavailable('The active Lua file is outside its project.');
    }
    if (p.extension(path).toLowerCase() != '.lua') {
      return _unavailable('Lua diagnostics require a .lua text source file.');
    }

    CodeDocumentSnapshot? document;
    final seen = <String>{};
    for (final snapshot in request.documents) {
      final snapshotPath = p.normalize(snapshot.path);
      if (snapshotPath.contains('\u0000') ||
          !p.isAbsolute(snapshot.path) ||
          !p.isWithin(root, snapshotPath)) {
        return _unavailable('An editor snapshot is outside its project.');
      }
      if (!seen.add(p.canonicalize(snapshotPath))) {
        return _unavailable('An editor snapshot is duplicated.');
      }
      if (p.equals(snapshotPath, path)) document = snapshot;
    }
    if (document == null || document.revision != request.revision) {
      return _unavailable('The current Lua editor snapshot is unavailable.');
    }
    final source = document.text;
    if (source.startsWith('\u001bLua')) {
      return _unavailable('Lua bytecode cannot be checked as editor text.');
    }
    if (source.length > maximumSourceLength) {
      return _unavailable('Lua source is too large for live diagnostics.');
    }

    final LuaToolResult result;
    try {
      result = await toolchain.checkSource(
        _fileChunk(source),
        chunkName: _chunkName,
      );
    } catch (error) {
      return _unavailable('The bundled Lua parser is unavailable: $error');
    }
    if (result.success && result.error.isEmpty && result.output.isEmpty) {
      return const CodeAnalysisResult();
    }
    // LUA_ERRSYNTAX is 3. Allocation, linking, and bridge errors are availability
    // failures; they must never become source underlines or a clean result.
    if (result.status != 3 || result.output.isNotEmpty) {
      return _unavailable(
        'The bundled Lua parser failed (status '
        '${result.status}): ${result.error}',
      );
    }
    final match = _location.firstMatch(result.error);
    final line = int.tryParse(match?.group(1) ?? '');
    if (match == null || line == null) {
      return _unavailable(
        'Lua returned an unrecognized diagnostic: ${result.error}',
      );
    }
    final lineRange = _lineRange(source, line);
    if (lineRange == null) {
      return _unavailable(
        'Lua returned a diagnostic outside the editor snapshot.',
      );
    }
    final message = match.group(2)!;
    if (message.trim().isEmpty) {
      return _unavailable('Lua returned an empty syntax diagnostic.');
    }
    final range = _diagnosticRange(source, lineRange, message);
    return CodeAnalysisResult(
      diagnostics: [
        CodeDiagnostic(
          filePath: path,
          startOffset: range.$1,
          endOffset: range.$2,
          message: message,
          source: 'Lua',
          code: 'lua.syntax',
        ),
      ],
    );
  }

  static CodeAnalysisResult _unavailable(String reason) =>
      CodeAnalysisResult(unavailableReason: reason);

  /// Accept luaL_loadfilex's optional BOM and first-line '#' preamble, without
  /// reading a file. Blank the skipped preamble but preserve its line endings
  /// so even an unusual shebang containing CR maps to the original editor.
  static String _fileChunk(String source) {
    final start = source.startsWith('\ufeff') ? 1 : 0;
    if (start < source.length && source.codeUnitAt(start) == 35) {
      final end = source.indexOf('\n', start);
      if (end < 0) return '';
      return source.substring(0, end).replaceAll(_preambleText, ' ') +
          source.substring(end);
    }
    return start == 0 ? source : source.substring(start);
  }

  static (int, int) _diagnosticRange(
    String source,
    (int, int) line,
    String message,
  ) {
    if (message.endsWith(' near <eof>')) {
      return (source.length, source.length);
    }
    final near = message.lastIndexOf(" near '");
    if (near >= 0 && message.endsWith("'")) {
      final token = message.substring(near + 7, message.length - 1);
      // Lua may decode escapes in a string token. Only match literal tokens
      // that survive its diagnostic formatting unchanged.
      if (_plainToken.hasMatch(token)) {
        final text = source.substring(line.$1, line.$2);
        final first = text.indexOf(token);
        if (first >= 0 && text.indexOf(token, first + 1) < 0) {
          return (line.$1 + first, line.$1 + first + token.length);
        }
      }
    }
    var start = line.$1;
    var end = line.$2;
    while (start < end && _isSpace(source.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isSpace(source.codeUnitAt(end - 1))) {
      end--;
    }
    return (start, end);
  }

  /// Lua treats CRLF and LFCR as one newline, and lone CR/LF as one each.
  /// Keep their original code units when calculating editor positions.
  static (int, int)? _lineRange(String source, int requestedLine) {
    if (requestedLine < 1) return null;
    var line = 1;
    var start = 0;
    var offset = 0;
    while (offset < source.length) {
      final unit = source.codeUnitAt(offset);
      if (unit != 10 && unit != 13) {
        offset++;
        continue;
      }
      if (line == requestedLine) return (start, offset);
      offset++;
      if (offset < source.length) {
        final next = source.codeUnitAt(offset);
        if ((next == 10 || next == 13) && next != unit) offset++;
      }
      line++;
      start = offset;
    }
    return line == requestedLine ? (start, source.length) : null;
  }

  static bool _isSpace(int unit) =>
      unit == 32 || unit == 9 || unit == 11 || unit == 12;
}
