import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/store/project_store.dart';

import 'lua_toolchain.dart';

// ---------------------------------------------------------------------------
// Syntax checking
// ---------------------------------------------------------------------------

/// One real diagnostic from the bundled Lua parser, with the file name the
/// user recognises instead of the temporary or absolute path.
class LuaSyntaxReport {
  const LuaSyntaxReport({
    required this.ok,
    required this.message,
    required this.raw,
    this.line,
    this.displayFile,
    this.sourceLine,
  });

  final bool ok;

  /// Short, path-free diagnostic text. Empty when [ok] is true.
  final String message;

  /// Original diagnostic exactly as the runtime produced it.
  final String raw;
  final int? line;
  final String? displayFile;

  /// The offending source line, when the caller supplied the source text.
  final String? sourceLine;
}

/// Splits a runtime diagnostic such as `main.lua:3: unexpected symbol near '='`
/// into its line number and message.
///
/// Lua truncates long chunk names with a leading `...`, so the prefix is
/// matched by the file's base name instead of string equality.
LuaSyntaxReport parseLuaDiagnostic(
  String diagnostic, {
  required String file,
  String? displayFile,
}) {
  final raw = diagnostic.trim();
  final name = displayFile ?? p.basename(file);
  if (raw.isEmpty) {
    return LuaSyntaxReport(ok: true, message: '', raw: raw, displayFile: name);
  }
  final prefix =
      _matchDiagnosticPrefix(raw, p.basename(file)) ??
      _matchDiagnosticPrefix(raw, name);
  if (prefix != null) {
    return LuaSyntaxReport(
      ok: false,
      message: prefix.$2,
      raw: raw,
      line: prefix.$1,
      displayFile: name,
    );
  }
  // No positional prefix: errors such as "cannot open main.lua" stay verbatim.
  return LuaSyntaxReport(ok: false, message: raw, raw: raw, displayFile: name);
}

/// Returns `(line, message)` when [text] starts with `...<name>:<line>: `.
(int, String)? _matchDiagnosticPrefix(String text, String name) {
  // The chunk name may be an absolute Windows path, or a name Lua truncated to
  // "..." plus the tail of the path, so match by the trailing base name.
  final match = RegExp(r'^(.*?):(\d+):\s*([\s\S]*)$').firstMatch(text);
  if (match == null) return null;
  if (!match.group(1)!.endsWith(name)) return null;
  return (int.parse(match.group(2)!), match.group(3)!.trim());
}

/// Runs the bundled Lua parser on [source] written to a scratch file.
///
/// The parser never executes the chunk, so this is safe for partial edits.
/// [scratchDirectory] exists so tests can assert that nothing is left behind.
Future<LuaSyntaxReport> checkLuaSource(
  String source, {
  String fileName = 'snippet.lua',
  LuaToolchain toolchain = const LuaToolchain(),
  Directory? scratchDirectory,
}) async {
  final parent = scratchDirectory ?? Directory.systemTemp;
  await parent.create(recursive: true);
  final directory = await parent.createTemp('qfli_lua_check_');
  final safeName = p.basename(fileName).isEmpty
      ? 'snippet.lua'
      : p.basename(fileName);
  final file = File(p.join(directory.path, safeName));
  try {
    await directory.create(recursive: true);
    await file.writeAsBytes(utf8.encode(source), flush: true);
    final result = await toolchain.check(file.path);
    if (result.success) {
      return LuaSyntaxReport(
        ok: true,
        message: '',
        raw: result.error,
        displayFile: safeName,
      );
    }
    final report = parseLuaDiagnostic(
      result.error.isEmpty ? 'Lua 语法检查失败' : result.error,
      file: file.path,
      displayFile: safeName,
    );
    return LuaSyntaxReport(
      ok: false,
      message: report.message,
      raw: result.error,
      line: report.line,
      displayFile: safeName,
      sourceLine: _sourceLineAt(source, report.line),
    );
  } on Object catch (error) {
    return LuaSyntaxReport(
      ok: false,
      message: '$error',
      raw: '$error',
      displayFile: safeName,
    );
  } finally {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // A scratch file that cannot be removed must not hide the real result.
    }
    await _deleteQuietly(directory);
  }
}

/// Checks a real file inside a project without writing anything to it.
Future<LuaSyntaxReport> checkLuaFile(
  String path, {
  String? relativeTo,
  LuaToolchain toolchain = const LuaToolchain(),
}) async {
  final display = relativeTo == null
      ? p.basename(path)
      : p.relative(path, from: relativeTo);
  try {
    final result = await toolchain.check(path);
    if (result.success) {
      return LuaSyntaxReport(
        ok: true,
        message: '',
        raw: '',
        displayFile: display,
      );
    }
    String? source;
    try {
      source = utf8.decode(
        await File(path).readAsBytes(),
        allowMalformed: true,
      );
    } on FileSystemException {
      source = null;
    }
    final report = parseLuaDiagnostic(
      result.error.isEmpty ? 'Lua 语法检查失败' : result.error,
      file: path,
      displayFile: display,
    );
    return LuaSyntaxReport(
      ok: false,
      message: report.message,
      raw: result.error,
      line: report.line,
      displayFile: display,
      sourceLine: source == null ? null : _sourceLineAt(source, report.line),
    );
  } on Object catch (error) {
    return LuaSyntaxReport(
      ok: false,
      message: '$error',
      raw: '$error',
      displayFile: display,
    );
  }
}

String? _sourceLineAt(String source, int? line) {
  if (line == null || line < 1) return null;
  final lines = const LineSplitter().convert(source);
  if (line > lines.length) return null;
  return lines[line - 1];
}

// ---------------------------------------------------------------------------
// Lua string literals
// ---------------------------------------------------------------------------

/// Result of parsing a Lua string literal: exactly one of [value] or [error].
class LuaLiteralResult {
  LuaLiteralResult.ok(String this.value, {List<int>? bytes})
    : bytes = Uint8List.fromList(bytes ?? utf8.encode(value)),
      error = null;
  const LuaLiteralResult.failure(this.error) : value = null, bytes = null;

  final String? value;
  final Uint8List? bytes;
  final String? error;

  bool get ok => value != null;

  bool get hasMalformedUtf8 {
    if (bytes == null) return false;
    try {
      utf8.decode(bytes!);
      return false;
    } on FormatException {
      return true;
    }
  }
}

/// Encodes and decodes Lua 5.4 short- and long-bracket string literals.
///
/// Authoring Lua content means escaping user text; doing it by hand is where
/// invalid escapes come from, so the rules live in one tested place.
abstract final class LuaStringLiteral {
  /// Renders [text] as a double-quoted Lua literal.
  ///
  /// Logical newlines, tabs, CRs, quotes and backslashes use their short
  /// escapes; other control bytes use `\xNN`. With [escapeNonAscii] every
  /// non-ASCII code point becomes a `\u{...}` escape that Lua decodes to UTF-8.
  static String encode(String text, {bool escapeNonAscii = false}) {
    final buffer = StringBuffer('"');
    for (final rune in text.runes) {
      switch (rune) {
        case 0x5C:
          buffer.write(r'\\');
        case 0x22:
          buffer.write(r'\"');
        case 0x0A:
          buffer.write(r'\n');
        case 0x0D:
          buffer.write(r'\r');
        case 0x09:
          buffer.write(r'\t');
        case < 0x20:
        case 0x7F:
          buffer.write(r'\x');
          buffer.write(rune.toRadixString(16).toUpperCase().padLeft(2, '0'));
        case > 0x7E:
          if (escapeNonAscii) {
            buffer.write(r'\u{');
            buffer.write(rune.toRadixString(16).toUpperCase());
            buffer.write('}');
          } else {
            buffer.writeCharCode(rune);
          }
        default:
          buffer.writeCharCode(rune);
      }
    }
    buffer.write('"');
    return buffer.toString();
  }

  /// Renders [text] as a long-bracket literal when that is lossless, otherwise
  /// falls back to [encode].
  ///
  /// A long bracket skips one leading newline, so text that starts with a line
  /// break gains a compensating one.
  static String encodeLongBracket(String text) {
    if (text.contains('\u0000') ||
        text.contains('\r') ||
        _hasControlBesidesWhitespace(text)) {
      return encode(text);
    }
    var level = 0;
    while (text.contains(']${'=' * level}]')) {
      level++;
    }
    final equals = '=' * level;
    final body = text.startsWith('\n') || text.startsWith('\r')
        ? '\n$text'
        : text;
    return '[$equals[$body]$equals]';
  }

  static bool _hasControlBesidesWhitespace(String text) => text.runes.any(
    (rune) => rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D,
  );

  /// Parses one Lua string literal.
  static LuaLiteralResult decode(String literal) {
    final text = literal.trim();
    if (text.isEmpty) return const LuaLiteralResult.failure('字面量为空');
    if (text.startsWith('[')) return _decodeLongBracket(text);
    final quote = text[0];
    if (quote != '"' && quote != "'") {
      return const LuaLiteralResult.failure('请以 "、\' 或 [[ 开头');
    }
    final bytes = <int>[];
    var index = 1;
    while (index < text.length) {
      final char = text[index];
      if (char == quote) {
        if (text.substring(index + 1).trim().isNotEmpty) {
          return const LuaLiteralResult.failure('字面量在收尾引号之后还有内容');
        }
        return LuaLiteralResult.ok(
          utf8.decode(bytes, allowMalformed: true),
          bytes: bytes,
        );
      }
      if (char == '\n' || char == '\r') {
        return const LuaLiteralResult.failure('字符串中不能直接换行，请写成 \\n 或使用长括号');
      }
      if (char != r'\') {
        final rune = _codePointAt(text, index);
        bytes.addAll(utf8.encode(String.fromCharCode(rune)));
        index += rune > 0xFFFF ? 2 : 1;
        continue;
      }
      index++;
      if (index >= text.length) {
        return const LuaLiteralResult.failure('反斜杠之后缺少转义字符');
      }
      final escape = text[index];
      const simple = <String, int>{
        'a': 0x07,
        'b': 0x08,
        'f': 0x0C,
        'n': 0x0A,
        'r': 0x0D,
        't': 0x09,
        'v': 0x0B,
        r'\': 0x5C,
        '"': 0x22,
        "'": 0x27,
      };
      final simpleValue = simple[escape];
      if (simpleValue != null) {
        bytes.add(simpleValue);
        index++;
        continue;
      }
      if (escape == '\r' || escape == '\n') {
        bytes.add(0x0A);
        index++;
        if (index < text.length &&
            (text[index] == '\r' || text[index] == '\n') &&
            text[index] != escape) {
          index++;
        }
        continue;
      }
      if (escape == 'z') {
        index++;
        while (index < text.length && _isSpace(text[index])) {
          index++;
        }
        continue;
      }
      if (escape == 'x') {
        final hex = index + 1 + 2 <= text.length
            ? text.substring(index + 1, index + 3)
            : '';
        final value = int.tryParse(hex, radix: 16);
        if (hex.length != 2 ||
            value == null ||
            RegExp(r'[^0-9a-fA-F]').hasMatch(hex)) {
          return LuaLiteralResult.failure('\\x 需要两位十六进制数字（当前 "$hex"）');
        }
        bytes.add(value);
        index += 3;
        continue;
      }
      if (escape == 'u') {
        if (index + 1 >= text.length || text[index + 1] != '{') {
          return const LuaLiteralResult.failure('\\u 后缺少 {');
        }
        final close = text.indexOf('}', index + 2);
        if (close < 0) return const LuaLiteralResult.failure('\\u{ 缺少收尾的 }');
        final hex = text.substring(index + 2, close);
        final value = hex.isEmpty ? null : int.tryParse(hex, radix: 16);
        if (value == null || RegExp(r'[^0-9a-fA-F]').hasMatch(hex)) {
          return LuaLiteralResult.failure('\\u{...} 需要十六进制码点（当前 "$hex"）');
        }
        if (value > 0x7FFFFFFF) {
          return const LuaLiteralResult.failure('\\u{...} 码点超出 Lua 支持范围');
        }
        bytes.addAll(_luaUtf8Bytes(value));
        index = close + 1;
        continue;
      }
      if (_isDigit(escape)) {
        var end = index;
        while (end < text.length && end - index < 3 && _isDigit(text[end])) {
          end++;
        }
        final value = int.parse(text.substring(index, end));
        if (value > 0xFF) {
          return LuaLiteralResult.failure('\\$value 超过单字节范围（最大 255）');
        }
        bytes.add(value);
        index = end;
        continue;
      }
      return LuaLiteralResult.failure('无效转义序列 \\$escape');
    }
    return const LuaLiteralResult.failure('字符串缺少收尾引号');
  }

  static LuaLiteralResult _decodeLongBracket(String text) {
    final open = RegExp(r'^\[(=*)\[').firstMatch(text);
    if (open == null) {
      return const LuaLiteralResult.failure('长括号应以 [[ 或 [=[ 开头');
    }
    final equals = open.group(1)!;
    final close =
        ']'
        '$equals'
        ']';
    final start = open.end;
    final end = text.indexOf(close, start);
    if (end < 0) return LuaLiteralResult.failure('长括号缺少收尾的 $close');
    if (text.substring(end + close.length).trim().isNotEmpty) {
      return const LuaLiteralResult.failure('字面量在收尾长括号之后还有内容');
    }
    var body = text.substring(start, end);
    if (body.startsWith('\r\n') || body.startsWith('\n\r')) {
      body = body.substring(2);
    } else if (body.startsWith('\n') || body.startsWith('\r')) {
      body = body.substring(1);
    }
    return LuaLiteralResult.ok(body.replaceAll(RegExp(r'\r\n|\n\r|\r'), '\n'));
  }

  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  static bool _isSpace(String char) =>
      char == ' ' ||
      char == '\t' ||
      char == '\r' ||
      char == '\n' ||
      char == '\v' ||
      char == '\f';
}

List<int> _luaUtf8Bytes(int value) {
  if (value < 0x80) return [value];
  final reversed = <int>[];
  var prefix = 0xC0;
  var limit = 0x1F;
  do {
    reversed.add(0x80 | (value & 0x3F));
    value >>= 6;
    if (value <= limit) break;
    prefix = (prefix >> 1) | 0x80;
    limit >>= 1;
  } while (true);
  reversed.add(prefix | value);
  return reversed.reversed.toList();
}

// ---------------------------------------------------------------------------
// Source scanning (require calls)
// ---------------------------------------------------------------------------

/// One literal `require` argument found in a Lua source file.
class LuaRequireReference {
  const LuaRequireReference({required this.module, required this.line});

  final String module;
  final int line;

  @override
  String toString() => '$module@$line';
}

/// Static scan result: literal module names plus a count of calls that pass a
/// non-literal argument and therefore cannot be resolved ahead of time.
class LuaSourceScan {
  const LuaSourceScan({required this.requires, required this.dynamicRequires});

  final List<LuaRequireReference> requires;
  final int dynamicRequires;
}

/// Finds `require "mod"` / `require('mod')` / `require [[mod]]` calls.
///
/// Comments, long comments and every string that is not a require argument are
/// skipped by a small lexer, so text inside them never produces a false module.
LuaSourceScan scanLuaSource(String source) {
  final scanner = _LuaScanner(source);
  final requires = <LuaRequireReference>[];
  var dynamic = 0;
  String? previous;
  while (true) {
    final token = scanner.next();
    if (token == null) break;
    final isCall =
        token == 'require' &&
        previous != '.' &&
        previous != ':' &&
        previous != 'function';
    previous = token;
    if (!isCall) continue;
    final line = scanner.line;
    scanner.skipWhitespace();
    var parenthesized = false;
    if (scanner.peekChar() == '(') {
      parenthesized = true;
      scanner.advance();
      scanner.skipWhitespace();
    }
    final literal = scanner.readStringLiteral();
    if (literal == null) {
      if (parenthesized) dynamic++;
      continue;
    }
    if (parenthesized) {
      scanner.skipWhitespace();
      if (scanner.peekChar() != ')') {
        dynamic++;
        continue;
      }
    }
    final decoded = LuaStringLiteral.decode(literal).value;
    if (decoded == null || decoded.isEmpty) {
      dynamic++;
      continue;
    }
    requires.add(LuaRequireReference(module: decoded, line: line));
  }
  return LuaSourceScan(requires: requires, dynamicRequires: dynamic);
}

/// Identifier-level cursor used by [scanLuaSource].
///
/// It only needs to recognise comments, strings and identifiers; it never
/// validates expressions, because the real parser does that.
class _LuaScanner {
  _LuaScanner(this._source);

  final String _source;
  int _index = 0;
  int line = 1;

  String? next() {
    while (_index < _source.length) {
      final char = _source[_index];
      if (_skipTrivia()) {
        if (char == '"' || char == "'" || char == '[') return '<string>';
        continue;
      }
      if (_isIdentifierStart(char)) return _readIdentifier();
      _index++;
      if (char == '\n') line++;
      return char;
    }
    return null;
  }

  /// Skips whitespace, comments and string literals. Returns true when [next]
  /// must look at the same position again.
  bool _skipTrivia() {
    final char = _source[_index];
    if (char == '\n') {
      line++;
      _index++;
      return true;
    }
    if (_isSpace(char)) {
      _index++;
      return true;
    }
    if (char == '-' &&
        _index + 1 < _source.length &&
        _source[_index + 1] == '-') {
      _index += 2;
      final longLevel = _longBracketLevel(_index);
      if (longLevel == null) {
        while (_index < _source.length && _source[_index] != '\n') {
          _index++;
        }
      } else {
        _skipLongBracket(longLevel);
      }
      return true;
    }
    if (char == '"' || char == "'" || char == '[') {
      final longLevel = char == '[' ? _longBracketLevel(_index) : null;
      if (longLevel != null) {
        _skipLongBracket(longLevel);
      } else if (char == '"' || char == "'") {
        _skipShortString();
      } else {
        _index++;
      }
      return true;
    }
    return false;
  }

  void _skipShortString() {
    final quote = _source[_index];
    _index++;
    while (_index < _source.length) {
      final char = _source[_index];
      if (char == r'\') {
        _index++;
        if (_index < _source.length) {
          if (_source[_index] == '\n') line++;
          _index++;
        }
        continue;
      }
      _index++;
      if (char == '\n') {
        line++;
        // Unterminated short string: stop at the line break like Lua does.
        return;
      }
      if (char == quote) return;
    }
  }

  int? _longBracketLevel(int start) {
    if (start >= _source.length || _source[start] != '[') return null;
    var index = start + 1;
    var level = 0;
    while (index < _source.length && _source[index] == '=') {
      level++;
      index++;
    }
    if (index >= _source.length || _source[index] != '[') return null;
    _index = index + 1;
    return level;
  }

  void _skipLongBracket(int level) {
    final close = ']${'=' * level}]';
    final start = _index;
    var index = start;
    while (index < _source.length) {
      if (_source.codeUnitAt(index) == 0x5D &&
          _source.startsWith(close, index)) {
        _countLines(start, index);
        _index = index + close.length;
        return;
      }
      index++;
    }
    _countLines(start, _source.length);
    _index = _source.length;
  }

  void _countLines(int from, int to) {
    for (var index = from; index < to; index++) {
      if (_source[index] == '\n') line++;
    }
  }

  String _readIdentifier() {
    final start = _index;
    while (_index < _source.length && _isIdentifierPart(_source[_index])) {
      _index++;
    }
    return _source.substring(start, _index);
  }

  /// Reads a string literal at the cursor without consuming it on failure.
  String? readStringLiteral() {
    final start = _index;
    if (_index >= _source.length) return null;
    final char = _source[_index];
    if (char == '"' || char == "'") {
      _skipShortString();
      final text = _source.substring(start, _index);
      return text.length > 1 ? text : null;
    }
    final level = _longBracketLevel(_index);
    if (level == null) return null;
    _skipLongBracket(level);
    return _source.substring(start, _index);
  }

  String? peekChar() {
    var index = _index;
    while (index < _source.length && _isSpace(_source[index])) {
      index++;
    }
    if (index >= _source.length) return null;
    return _source[index];
  }

  void advance() {
    if (_index < _source.length) {
      if (_source[_index] == '\n') line++;
      _index++;
    }
  }

  void skipWhitespace() {
    while (_index < _source.length) {
      if (_isSpace(_source[_index])) {
        if (_source[_index] == '\n') line++;
        _index++;
      } else if (_source.startsWith('--', _index)) {
        _skipTrivia();
      } else {
        return;
      }
    }
  }

  static bool _isSpace(String char) =>
      char == ' ' ||
      char == '\t' ||
      char == '\r' ||
      char == '\n' ||
      char == '\v' ||
      char == '\f';

  static bool _isIdentifierStart(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        code == 0x5F;
  }

  static bool _isIdentifierPart(String char) {
    final code = char.codeUnitAt(0);
    return _isIdentifierStart(char) || (code >= 0x30 && code <= 0x39);
  }
}

// ---------------------------------------------------------------------------
// Module resolution through the real runtime
// ---------------------------------------------------------------------------

/// Where `require(name)` would load [module] from, according to the running VM.
class LuaModuleResolution {
  const LuaModuleResolution({
    required this.module,
    required this.file,
    required this.searched,
    this.builtIn = false,
  });

  final String module;

  /// Absolute path the runtime would use, or null when nothing matched.
  final String? file;

  /// Candidate paths the runtime reported, in search order.
  final List<String> searched;
  final bool builtIn;

  bool get resolved => builtIn || file != null;
}

/// Result of asking the bundled VM to resolve modules for one project.
class LuaModuleSearch {
  const LuaModuleSearch({
    required this.packagePath,
    required this.resolutions,
    this.error,
  });

  final String packagePath;
  final List<LuaModuleResolution> resolutions;
  final String? error;

  LuaModuleResolution? forModule(String module) {
    for (final resolution in resolutions) {
      if (resolution.module == module) return resolution;
    }
    return null;
  }
}

/// Resolves [modules] with the VM's own `package.searchpath`.
///
/// The runtime prepends the project's `?.lua` / `src/?.lua` templates exactly
/// as a real run does, so a match here is what `require` will load.
Future<LuaModuleSearch> resolveLuaModules({
  required String projectDirectory,
  required List<String> modules,
  LuaToolchain toolchain = const LuaToolchain(),
}) async {
  final unique = <String>[];
  for (final module in modules) {
    if (module.isEmpty || unique.contains(module)) continue;
    unique.add(module);
  }
  if (unique.isEmpty) {
    return LuaModuleSearch(
      packagePath: '',
      resolutions: const [],
      error: '没有可解析的模块名',
    );
  }
  final directory = Directory.systemTemp.createTempSync('qfli_lua_modules_');
  try {
    final script = File(p.join(directory.path, 'qfli_module_search.lua'));
    script.writeAsStringSync(_moduleSearchScript(unique), flush: true);
    final result = await toolchain.run(
      file: script.path,
      projectDirectory: projectDirectory,
      timeLimit: const Duration(seconds: 5),
    );
    if (!result.success) {
      return LuaModuleSearch(
        packagePath: '',
        resolutions: const [],
        error: result.error.isEmpty ? '模块解析失败' : result.error.trim(),
      );
    }
    return parseModuleSearchOutput(result.output);
  } on Object catch (error) {
    return LuaModuleSearch(
      packagePath: '',
      resolutions: const [],
      error: '$error',
    );
  } finally {
    await _deleteQuietly(directory);
  }
}

/// Parses the tab-separated records printed by [_moduleSearchScript].
LuaModuleSearch parseModuleSearchOutput(String output) {
  var packagePath = '';
  final files = <String, String>{};
  final builtIns = <String>{};
  final searched = <String, List<String>>{};
  final order = <String>[];
  for (final line in const LineSplitter().convert(output)) {
    if (line.isEmpty) continue;
    final fields = line.split('\t');
    switch (fields.first) {
      case 'path' when fields.length >= 2:
        packagePath = _decodeHexField(fields[1]);
      case 'ok' when fields.length >= 3:
        final module = _decodeHexField(fields[1]);
        if (!order.contains(module)) order.add(module);
        files[module] = _decodeHexField(fields[2]);
      case 'builtin' when fields.length >= 2:
        final module = _decodeHexField(fields[1]);
        if (!order.contains(module)) order.add(module);
        builtIns.add(module);
      case 'miss' when fields.length >= 3:
        final module = _decodeHexField(fields[1]);
        if (!order.contains(module)) order.add(module);
        (searched[module] ??= <String>[]).add(_decodeHexField(fields[2]));
    }
  }
  return LuaModuleSearch(
    packagePath: packagePath,
    resolutions: [
      for (final module in order)
        LuaModuleResolution(
          module: module,
          file: files[module],
          builtIn: builtIns.contains(module),
          searched: List<String>.unmodifiable(searched[module] ?? const []),
        ),
    ],
  );
}

String _decodeHexField(String field) {
  if (field.length.isOdd || RegExp(r'[^0-9a-fA-F]').hasMatch(field)) {
    throw const FormatException('Lua 工具返回了无效的数据');
  }
  return utf8.decode([
    for (var index = 0; index < field.length; index += 2)
      int.parse(field.substring(index, index + 2), radix: 16),
  ], allowMalformed: true);
}

String _moduleSearchScript(List<String> modules) {
  final list = modules.map(LuaStringLiteral.encode).join(', ');
  return '''
local modules = { $list }
local function hex(value)
  return (string.gsub(value, ".", function(char)
    return string.format("%02x", string.byte(char))
  end))
end
print("path\\t" .. hex(package.path))
for index = 1, #modules do
  local name = modules[index]
  if package.loaded[name] ~= nil then
    print("builtin\\t" .. hex(name))
  else
    local file = package.searchpath(name, package.path)
    if file then
      print("ok\\t" .. hex(name) .. "\\t" .. hex(file))
    else
      local expanded = string.gsub(name, "%.", package.config:sub(1, 1))
      for template in string.gmatch(package.path, "[^;]+") do
        local candidate = string.gsub(template, "%?", function() return expanded end)
        print("miss\\t" .. hex(name) .. "\\t" .. hex(candidate))
      end
    end
  end
end
''';
}

/// One project file and its requires, resolved against the runtime.
class LuaProjectModuleEntry {
  const LuaProjectModuleEntry({
    required this.relativePath,
    required this.requires,
    required this.dynamicRequires,
  });

  final String relativePath;
  final List<LuaRequireReference> requires;
  final int dynamicRequires;
}

/// Whole-project require audit: every literal require and whether it resolves.
class LuaProjectScan {
  const LuaProjectScan({
    required this.packagePath,
    required this.entries,
    required this.resolutions,
    required this.unresolved,
    required this.dynamicRequires,
    required this.truncated,
    this.error,
  });

  final String packagePath;
  final List<LuaProjectModuleEntry> entries;
  final Map<String, LuaModuleResolution> resolutions;

  /// Unique module names that no candidate path satisfies.
  final List<String> unresolved;
  final int dynamicRequires;

  /// True when the file list was cut at [maxProjectFiles].
  final bool truncated;
  final String? error;
}

/// Upper bound on files read by [scanLuaProject]; keeps a huge tree responsive.
const int maxProjectFiles = 400;

const Set<String> _skippedDirectories = {
  '.git',
  '.dart_tool',
  'build',
  'node_modules',
  '.qfli',
};

/// Static requires of every `.lua` file, with runtime module resolution.
Future<LuaProjectScan> scanLuaProject({
  required String projectDirectory,
  LuaToolchain toolchain = const LuaToolchain(),
  int maxFiles = maxProjectFiles,
}) async {
  if (maxFiles < 1) throw ArgumentError.value(maxFiles, 'maxFiles');
  final List<String> paths;
  try {
    paths = await listLuaFiles(projectDirectory, maxFiles: maxFiles + 1);
  } on FileSystemException catch (error) {
    return LuaProjectScan(
      packagePath: '',
      entries: const [],
      resolutions: const {},
      unresolved: const [],
      dynamicRequires: 0,
      truncated: false,
      error: error.message,
    );
  }
  final entries = <LuaProjectModuleEntry>[];
  final modules = <String>[];
  var dynamic = 0;
  String? scanError;
  for (final path in paths.take(maxFiles)) {
    final String source;
    try {
      source = utf8.decode(
        await File(path).readAsBytes(),
        allowMalformed: true,
      );
    } on FileSystemException catch (error) {
      scanError = '$path: ${error.message}';
      continue;
    }
    final scan = scanLuaSource(source);
    dynamic += scan.dynamicRequires;
    for (final reference in scan.requires) {
      if (!modules.contains(reference.module)) modules.add(reference.module);
    }
    entries.add(
      LuaProjectModuleEntry(
        relativePath: p.relative(path, from: projectDirectory),
        requires: scan.requires,
        dynamicRequires: scan.dynamicRequires,
      ),
    );
  }
  if (modules.isEmpty) {
    return LuaProjectScan(
      packagePath: '',
      entries: entries,
      resolutions: const {},
      unresolved: const [],
      dynamicRequires: dynamic,
      truncated: paths.length > maxFiles,
      error: scanError,
    );
  }
  final search = await resolveLuaModules(
    projectDirectory: projectDirectory,
    modules: modules,
    toolchain: toolchain,
  );
  if (search.error != null) {
    return LuaProjectScan(
      packagePath: search.packagePath,
      entries: entries,
      resolutions: const {},
      unresolved: const [],
      dynamicRequires: dynamic,
      truncated: paths.length > maxFiles,
      error: search.error,
    );
  }
  return LuaProjectScan(
    packagePath: search.packagePath,
    entries: entries,
    resolutions: {
      for (final resolution in search.resolutions)
        resolution.module: resolution,
    },
    unresolved: [
      for (final resolution in search.resolutions)
        if (!resolution.resolved) resolution.module,
    ],
    dynamicRequires: dynamic,
    truncated: paths.length > maxFiles,
    error: scanError,
  );
}

/// Lists `.lua` files under [directory], skipping build and metadata folders.
Future<List<String>> listLuaFiles(
  String directory, {
  int maxFiles = maxProjectFiles,
}) => _listProjectFiles(directory, {'.lua'}, maxFiles);

Future<List<String>> _listProjectFiles(
  String directory,
  Set<String> extensions,
  int maxFiles,
) async {
  if (maxFiles < 1) throw ArgumentError.value(maxFiles, 'maxFiles');
  final files = <String>[];
  final root = Directory(directory);
  if (!await root.exists()) {
    throw FileSystemException('项目目录不存在', directory);
  }
  final pending = <Directory>[root];
  while (pending.isNotEmpty && files.length < maxFiles) {
    final current = pending.removeLast();
    final entries = await current.list(followLinks: false).toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    final children = <Directory>[];
    for (final entity in entries) {
      if (entity is Directory) {
        if (!_skippedDirectories.contains(p.basename(entity.path))) {
          children.add(entity);
        }
      } else if (entity is File &&
          extensions.contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity.path);
        if (files.length >= maxFiles) break;
      }
    }
    pending.addAll(children.reversed);
  }
  files.sort(
    (a, b) => p
        .relative(a, from: directory)
        .compareTo(p.relative(b, from: directory)),
  );
  return files;
}

// ---------------------------------------------------------------------------
// Bytecode
// ---------------------------------------------------------------------------

/// Raised when a compiled chunk does not match the Lua 5.4 dump format.
class LuaBytecodeFormatException implements Exception {
  const LuaBytecodeFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The fixed part of a Lua 5.4 bytecode file.
///
/// Lua 5.4 stores instruction, Lua integer and Lua number widths. Counts and
/// positions use base-128 variable-length encoding, independently of size_t.
class LuaBytecodeHeader {
  const LuaBytecodeHeader({
    required this.version,
    required this.format,
    required this.instructionSize,
    required this.luaIntegerSize,
    required this.luaNumberSize,
    required this.integerCheck,
    required this.numberCheck,
    required this.littleEndian,
  });

  final int version;
  final int format;
  final int instructionSize;
  final int luaIntegerSize;
  final int luaNumberSize;

  /// True when the 0x5678 probe and the 370.5 probe both matched.
  final bool integerCheck;
  final bool numberCheck;
  final bool littleEndian;

  /// Upper and lower nibbles encode the major and minor Lua versions.
  int get versionMajor => version >> 4;
  int get versionMinor => version & 0x0F;
  bool get isLua54 => version == 0x54;
}

/// One dumped function prototype, with nested prototypes.
class LuaBytecodeFunction {
  LuaBytecodeFunction({
    required this.source,
    required this.lineDefined,
    required this.lastLineDefined,
    required this.numParams,
    required this.isVararg,
    required this.maxStackSize,
    required this.instructionCount,
    required this.constants,
    required this.upvalueCount,
    required this.children,
  });

  final String? source;
  final int lineDefined;
  final int lastLineDefined;
  final int numParams;
  final int isVararg;
  final int maxStackSize;
  final int instructionCount;
  final List<String> constants;
  final int upvalueCount;
  final List<LuaBytecodeFunction> children;

  int get totalFunctions =>
      1 + children.fold(0, (sum, child) => sum + child.totalFunctions);

  int get totalInstructions =>
      instructionCount +
      children.fold(0, (sum, child) => sum + child.totalInstructions);

  /// Recursive string constants, used to show what the chunk carries.
  List<String> get allStringConstants => [
    ...constants.where((value) => value.startsWith('"')),
    ...children.expand((child) => child.allStringConstants),
  ];
}

/// A parsed chunk: header plus main prototype.
class LuaBytecodeChunk {
  const LuaBytecodeChunk({
    required this.header,
    required this.byteLength,
    required this.main,
  });

  final LuaBytecodeHeader header;
  final int byteLength;
  final LuaBytecodeFunction main;
}

/// Compiles [path] into a scratch directory and parses the dump.
///
/// The compiled file is removed afterwards: inspecting a project must not leave
/// artifacts behind. Compilation uses the same VM version that will run it.
Future<LuaBytecodeChunk> inspectLuaBytecode(
  String path, {
  LuaToolchain toolchain = const LuaToolchain(),
}) async {
  final directory = Directory.systemTemp.createTempSync('qfli_lua_bytecode_');
  try {
    final output = File(p.join(directory.path, 'chunk.luac'));
    final result = await toolchain.compile(path, output.path);
    if (!result.success) {
      throw LuaBytecodeFormatException(
        result.error.trim().isEmpty ? '编译失败' : result.error.trim(),
      );
    }
    if (!output.existsSync()) {
      throw const LuaBytecodeFormatException('编译器没有生成字节码文件');
    }
    return parseLuaBytecode(await output.readAsBytes());
  } finally {
    await _deleteQuietly(directory);
  }
}

/// Compiles without touching an existing output until a complete dump is ready.
/// Replacement requires explicit confirmation and a successful history backup.
Future<String> compileLuaFileToProject(
  String source, {
  required String projectDirectory,
  bool overwrite = false,
  LuaToolchain toolchain = const LuaToolchain(),
}) async {
  final root = await Directory(projectDirectory).resolveSymbolicLinks();
  final input = await File(source).resolveSymbolicLinks();
  if (!p.isWithin(root, input) || p.extension(input).toLowerCase() != '.lua') {
    throw FileSystemException('请选择项目内的 Lua 源文件', source);
  }
  final output = File(p.setExtension(input, '.luac'));
  final type = await FileSystemEntity.type(output.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      (type != FileSystemEntityType.file || !overwrite)) {
    throw FileSystemException('目标已存在，需要确认替换普通文件', output.path);
  }
  final temporary = await output.parent.createTemp('.qfli-luac-');
  var reserved = false;
  try {
    final prepared = File(p.join(temporary.path, 'chunk.luac'));
    final result = await toolchain.compile(input, prepared.path);
    if (!result.success) {
      throw LuaBytecodeFormatException(result.error.trim());
    }
    parseLuaBytecode(await prepared.readAsBytes());
    final current = await FileSystemEntity.type(
      output.path,
      followLinks: false,
    );
    if (current == FileSystemEntityType.notFound) {
      await output.create(exclusive: true);
      reserved = true;
    } else {
      if (!overwrite || current != FileSystemEntityType.file) {
        throw FileSystemException('目标已存在，请重新确认替换', output.path);
      }
      final error = await FileBackup.backupBeforeOverwrite(
        output,
        projectName: p.basename(root),
      );
      if (error != null) throw FileSystemException(error, output.path);
    }
    await prepared.rename(output.path);
    reserved = false;
    return output.path;
  } finally {
    if (reserved) await output.delete();
    await _deleteQuietly(temporary);
  }
}

/// Parses a Lua 5.4 binary chunk (`luac` output or `string.dump`).
LuaBytecodeChunk parseLuaBytecode(Uint8List bytes) {
  final reader = _ByteReader(bytes);
  if (bytes.length < 32) {
    throw const LuaBytecodeFormatException('文件太短，不是 Lua 字节码');
  }
  final signature = reader.readBytes(4);
  if (signature[0] != 0x1B ||
      signature[1] != 0x4C ||
      signature[2] != 0x75 ||
      signature[3] != 0x61) {
    throw const LuaBytecodeFormatException('缺少 Lua 签名 \\x1bLua');
  }
  final version = reader.readByte();
  if (version != 0x54) {
    throw LuaBytecodeFormatException(
      '字节码版本 0x${version.toRadixString(16)} 与内置 Lua 5.4 不匹配',
    );
  }
  final format = reader.readByte();
  if (format != 0) {
    throw const LuaBytecodeFormatException('不支持的 Lua 字节码格式');
  }
  final data = reader.readBytes(6);
  if (!listEquals(data, const [0x19, 0x93, 0x0D, 0x0A, 0x1A, 0x0A])) {
    throw const LuaBytecodeFormatException('LUAC_DATA 校验失败');
  }
  final instructionSize = reader.readByte();
  final luaIntegerSize = reader.readByte();
  final luaNumberSize = reader.readByte();
  if (instructionSize != 4 || luaIntegerSize != 8 || luaNumberSize != 8) {
    throw const LuaBytecodeFormatException('字节码类型宽度与内置运行时不匹配');
  }
  final integerCheck =
      reader.readInteger(luaIntegerSize, littleEndian: true) == 0x5678;
  final numberCheck =
      reader.readFloating(luaNumberSize, littleEndian: true) == 370.5;
  if (!integerCheck || !numberCheck) {
    throw const LuaBytecodeFormatException('字节码字节序或数值格式与内置运行时不匹配');
  }
  final header = LuaBytecodeHeader(
    version: version,
    format: format,
    instructionSize: instructionSize,
    luaIntegerSize: luaIntegerSize,
    luaNumberSize: luaNumberSize,
    integerCheck: integerCheck,
    numberCheck: numberCheck,
    littleEndian: integerCheck && numberCheck,
  );
  final upvalueCount = reader.readByte();
  final main = _readFunction(reader, header, upvalueCount);
  if (reader.remaining != 0) {
    throw const LuaBytecodeFormatException('字节码包含额外数据');
  }
  return LuaBytecodeChunk(header: header, byteLength: bytes.length, main: main);
}

const int _tagNil = 0x00;
const int _tagFalse = 0x01;
const int _tagTrue = 0x11;
const int _tagInteger = 0x03;
const int _tagNumber = 0x13;
const int _tagShortString = 0x04;
const int _tagLongString = 0x14;

LuaBytecodeFunction _readFunction(
  _ByteReader reader,
  LuaBytecodeHeader header,
  int? expectedUpvalues, [
  int depth = 0,
  String? parentSource,
]) {
  if (depth > 200) {
    throw const LuaBytecodeFormatException('字节码函数嵌套过深');
  }
  final source = reader.readString() ?? parentSource;
  final lineDefined = reader.readInt();
  final lastLineDefined = reader.readInt();
  final numParams = reader.readByte();
  final isVararg = reader.readByte();
  final maxStackSize = reader.readByte();
  final instructionCount = reader.readInt();
  reader.skip(instructionCount * header.instructionSize);
  final constantCount = reader.readInt();
  final constants = <String>[];
  for (var index = 0; index < constantCount; index++) {
    final tag = reader.readByte();
    switch (tag) {
      case _tagNil:
        constants.add('nil');
      case _tagFalse:
        constants.add('false');
      case _tagTrue:
        constants.add('true');
      case _tagInteger:
        constants.add('${reader.readInteger(header.luaIntegerSize)}');
      case _tagNumber:
        constants.add(_formatNumber(reader.readFloating(header.luaNumberSize)));
      case _tagShortString || _tagLongString:
        constants.add('"${_shorten(reader.readString() ?? '')}"');
      default:
        throw LuaBytecodeFormatException('未知常量类型 0x${tag.toRadixString(16)}');
    }
  }
  final count = reader.readInt();
  if (expectedUpvalues != null && count != expectedUpvalues) {
    throw const LuaBytecodeFormatException('主函数 upvalue 数量不匹配');
  }
  for (var index = 0; index < count; index++) {
    reader.skip(3);
  }
  final childCount = reader.readInt();
  final children = <LuaBytecodeFunction>[
    for (var index = 0; index < childCount; index++)
      _readFunction(reader, header, null, depth + 1, source),
  ];
  // Debug section: line info, absolute line info, locals, upvalue names.
  final lineInfoCount = reader.readInt();
  reader.skip(lineInfoCount);
  final absoluteCount = reader.readInt();
  for (var index = 0; index < absoluteCount; index++) {
    reader.readInt();
    reader.readInt();
  }
  final localCount = reader.readInt();
  for (var index = 0; index < localCount; index++) {
    reader.readString();
    reader.readInt();
    reader.readInt();
  }
  final upvalueNameCount = reader.readInt();
  for (var index = 0; index < upvalueNameCount; index++) {
    reader.readString();
  }
  return LuaBytecodeFunction(
    source: source,
    lineDefined: lineDefined,
    lastLineDefined: lastLineDefined,
    numParams: numParams,
    isVararg: isVararg,
    maxStackSize: maxStackSize,
    instructionCount: instructionCount,
    constants: List<String>.unmodifiable(constants),
    upvalueCount: count,
    children: List<LuaBytecodeFunction>.unmodifiable(children),
  );
}

String _formatNumber(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e16) {
    return '${value.toInt()}.0';
  }
  return '$value';
}

String _shorten(String value, {int limit = 40}) {
  final escaped = value
      .replaceAll('\\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll('\t', r'\t');
  return escaped.length <= limit ? escaped : '${escaped.substring(0, limit)}…';
}

class _ByteReader {
  _ByteReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;

  int readByte() {
    if (remaining < 1) throw const LuaBytecodeFormatException('字节码意外结束');
    return _bytes[_offset++];
  }

  void skip(int count) {
    if (count < 0 || remaining < count) {
      throw const LuaBytecodeFormatException('字节码意外结束');
    }
    _offset += count;
  }

  Uint8List readBytes(int count) {
    if (count < 0 || remaining < count) {
      throw const LuaBytecodeFormatException('字节码意外结束');
    }
    final slice = _bytes.sublist(_offset, _offset + count);
    _offset += count;
    return slice;
  }

  int readInt() {
    final value = readSize();
    if (value > 0x7FFFFFFF) {
      throw const LuaBytecodeFormatException('字节码计数超出范围');
    }
    return value;
  }

  /// Lua 5.4 dumps counts and positions as big-endian base-128 integers, with
  /// the high bit set on the last byte (`dumpSize` in `ldump.c`).
  int readSize() {
    var value = 0;
    for (var count = 0; count < 10; count++) {
      final byte = readByte();
      if (value > 0x00FFFFFFFFFFFFFF) {
        throw const LuaBytecodeFormatException('变长整数超出范围');
      }
      value = (value << 7) | (byte & 0x7F);
      if ((byte & 0x80) != 0) return value;
    }
    throw const LuaBytecodeFormatException('变长整数超过 10 字节');
  }

  /// Reads a fixed-width signed integer; returns null when the size is 0.
  int? readInteger(int size, {bool littleEndian = true}) {
    if (size == 0) return null;
    if (size > 8) {
      throw LuaBytecodeFormatException('不支持的整数宽度 $size');
    }
    final bytes = readBytes(size);
    var value = 0;
    for (var index = 0; index < size; index++) {
      final shift = (littleEndian ? index : size - 1 - index) * 8;
      value |= bytes[index] << shift;
    }
    final signBit = 1 << (size * 8 - 1);
    if (size < 8 && (value & signBit) != 0) {
      value -= 1 << (size * 8);
    }
    return value;
  }

  double readFloating(int size, {bool littleEndian = true}) {
    final data = ByteData.sublistView(readBytes(size));
    if (size == 8) {
      return data.getFloat64(0, littleEndian ? Endian.little : Endian.big);
    }
    if (size == 4) {
      return data.getFloat32(0, littleEndian ? Endian.little : Endian.big);
    }
    throw LuaBytecodeFormatException('不支持的浮点宽度 $size');
  }

  String? readString() {
    final size = readSize();
    if (size == 0) return null;
    if (size < 0) {
      throw const LuaBytecodeFormatException('字符串长度不合法');
    }
    final bytes = readBytes(size - 1);
    return utf8.decode(bytes, allowMalformed: true);
  }
}

// ---------------------------------------------------------------------------
// Lua patterns
// ---------------------------------------------------------------------------

/// One `string.find` match in the subject.
class LuaPatternMatch {
  const LuaPatternMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.captures,
  });

  /// 1-based byte offset, exactly as Lua reports it.
  final int start;
  final int end;
  final String text;
  final List<String> captures;
}

/// Everything one pattern run reported.
class LuaPatternOutcome {
  const LuaPatternOutcome({
    required this.matches,
    required this.replaced,
    required this.replacementCount,
    required this.truncated,
    this.error,
  });

  const LuaPatternOutcome.failure(String this.error)
    : matches = const [],
      replaced = '',
      replacementCount = 0,
      truncated = false;

  final List<LuaPatternMatch> matches;
  final String replaced;
  final int replacementCount;

  /// True when the match list stopped at the built-in limit.
  final bool truncated;
  final String? error;

  bool get ok => error == null;

  /// Whether the case-sensitive Lua search found a match.
  bool get isMatch => matches.isNotEmpty;
}

/// Execution handle so a runaway pattern can be cancelled from the UI.
class LuaPatternExecution {
  const LuaPatternExecution(this.result, this._cancel);

  final Future<LuaPatternOutcome> result;
  final Future<void> Function() _cancel;

  Future<void> cancel() => _cancel();
}

/// Runs [pattern] against [subject] in the bundled VM.
///
/// Lua patterns are not regular expressions; using the real engine is the only
/// way to report captures, positions and `gsub` results truthfully.
LuaPatternExecution startLuaPattern({
  required String subject,
  required String pattern,
  String replacement = '',
  bool plain = false,
  Duration timeLimit = const Duration(seconds: 5),
  LuaToolchain toolchain = const LuaToolchain(),
}) {
  final directory = Directory.systemTemp.createTempSync('qfli_lua_pattern_');
  try {
    final script = File(p.join(directory.path, 'qfli_pattern.lua'));
    script.writeAsStringSync(
      _patternScript(subject, pattern, replacement, plain),
      flush: true,
    );
    final execution = toolchain.startRun(
      file: script.path,
      projectDirectory: directory.path,
      timeLimit: timeLimit,
    );
    final result = () async {
      try {
        final outcome = await execution.result;
        if (!outcome.success) {
          final error = outcome.error.trim();
          return LuaPatternOutcome.failure(error.isEmpty ? '模式执行失败' : error);
        }
        return parsePatternOutput(outcome.output);
      } on Object catch (error) {
        return LuaPatternOutcome.failure('$error');
      } finally {
        await _deleteQuietly(directory);
      }
    }();
    return LuaPatternExecution(result, execution.cancel);
  } on Object {
    unawaited(_deleteQuietly(directory));
    rethrow;
  }
}

/// Convenience wrapper for callers that do not need cancellation.
Future<LuaPatternOutcome> runLuaPattern({
  required String subject,
  required String pattern,
  String replacement = '',
  bool plain = false,
  Duration timeLimit = const Duration(seconds: 5),
  LuaToolchain toolchain = const LuaToolchain(),
}) => startLuaPattern(
  subject: subject,
  pattern: pattern,
  replacement: replacement,
  plain: plain,
  timeLimit: timeLimit,
  toolchain: toolchain,
).result;

/// Parses the tab-separated records printed by [_patternScript].
LuaPatternOutcome parsePatternOutput(String output) {
  final matches = <LuaPatternMatch>[];
  var replaced = '';
  var count = 0;
  var truncated = false;
  String? error;
  for (final line in const LineSplitter().convert(output)) {
    if (line.isEmpty) continue;
    final fields = line.split('\t');
    switch (fields.first) {
      case 'error':
        error = _unescapePatternField(fields.skip(1).join('\t'));
      case 'match' when fields.length >= 4:
        matches.add(
          LuaPatternMatch(
            start: int.tryParse(fields[1]) ?? 0,
            end: int.tryParse(fields[2]) ?? 0,
            text: _unescapePatternField(fields[3]),
            captures: [
              for (final capture in fields.skip(4))
                _unescapePatternField(capture),
            ],
          ),
        );
      case 'gsub' when fields.length >= 3:
        count = int.tryParse(fields[1]) ?? 0;
        replaced = _unescapePatternField(fields.sublist(2).join('\t'));
      case 'truncated':
        truncated = true;
    }
  }
  if (error != null) return LuaPatternOutcome.failure(error);
  return LuaPatternOutcome(
    matches: List<LuaPatternMatch>.unmodifiable(matches),
    replaced: replaced,
    replacementCount: count,
    truncated: truncated,
  );
}

String _unescapePatternField(String field) {
  final bytes = <int>[];
  var index = 0;
  while (index < field.length) {
    final char = field[index];
    if (char == r'\' && index + 3 < field.length) {
      final digits = field.substring(index + 1, index + 4);
      final value = int.tryParse(digits);
      if (value != null && value <= 0xFF) {
        bytes.add(value);
        index += 4;
        continue;
      }
    }
    final rune = _codePointAt(field, index);
    bytes.addAll(utf8.encode(String.fromCharCode(rune)));
    index += rune > 0xFFFF ? 2 : 1;
  }
  return utf8.decode(bytes, allowMalformed: true);
}

/// Reads one code point so a surrogate pair is re-encoded as one UTF-8 rune.
int _codePointAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final next = text.codeUnitAt(index + 1);
    if (next >= 0xDC00 && next <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00);
    }
  }
  return unit;
}

const int _maxPatternMatches = 50;

String _patternScript(
  String subject,
  String pattern,
  String replacement,
  bool plain,
) {
  final findLimit = plain ? 'true' : 'false';
  return '''
local subject = ${LuaStringLiteral.encode(subject)}
local pattern = ${LuaStringLiteral.encode(pattern)}
local replacement = ${LuaStringLiteral.encode(replacement)}
local plain = $findLimit
local function escape(value)
  if value == nil then return "nil" end
  return (string.gsub(tostring(value), "[%c\\\\]", function(char)
    return string.format("\\\\%03d", string.byte(char))
  end))
end
local records = {}
local truncated = false
-- string.gsub has no plain mode, so escape magic characters for that path.
local gsubPattern = pattern
if plain then
  gsubPattern = string.gsub(pattern, "%p", "%%%0")
end
local ok, failure = pcall(function()
  local position = 1
  local lastEnd = nil
  local anchored = not plain and string.sub(pattern, 1, 1) == "^"
  while position <= #subject + 1 do
    local found = table.pack(string.find(subject, pattern, position, plain))
    if not found[1] then return end
    if found[2] ~= lastEnd then
      if #records >= $_maxPatternMatches then
        truncated = true
        return
      end
      local text = string.sub(subject, found[1], found[2])
      local record = "match\\t" .. found[1] .. "\\t" .. found[2] .. "\\t" .. escape(text)
      for index = 3, found.n do
        record = record .. "\\t" .. escape(found[index])
      end
      records[#records + 1] = record
      lastEnd = found[2]
      position = found[2] + 1
    else
      position = position + 1
    end
    if anchored then return end
  end
end)
if not ok then
  print("error\\t" .. escape(failure))
  return
end
local replaced, count = string.gsub(subject, gsubPattern, replacement)
records[#records + 1] = "gsub\\t" .. count .. "\\t" .. escape(replaced)
if truncated then records[#records + 1] = "truncated" end
print(table.concat(records, "\\n"))
''';
}

// ---------------------------------------------------------------------------
// Project/file selection
// ---------------------------------------------------------------------------

/// Lists project files for the tools pages and keeps one selection per page.
///
/// Every async read carries a generation number so a slow directory listing from
/// a project the user already left can never overwrite the current one.
class LuaProjectFileController extends ChangeNotifier {
  LuaProjectFileController({
    required this.store,
    this.extensions = const ['.lua'],
  }) {
    store.addListener(_onStoreChanged);
  }

  final ProjectStore store;

  /// Lower-case extensions accepted by the owning page.
  final List<String> extensions;

  int _generation = 0;
  bool _disposed = false;
  bool _loading = false;
  String? _projectId;
  String? _file;
  String? _error;
  List<String> _files = const [];

  List<Project> get projects => [
    for (final project in store.projects)
      if (!project.isCloud && Directory(project.path).existsSync()) project,
  ];

  Project? get project {
    final available = projects;
    if (available.isEmpty) return null;
    for (final candidate in available) {
      if (candidate.id == _projectId) return candidate;
    }
    return available.first;
  }

  List<String> get files => _files;
  String? get file => _file;
  bool get loading => _loading;
  String? get error => _error;

  /// Loads the current project's file list; safe to call repeatedly.
  Future<void> refresh() async {
    final generation = ++_generation;
    final project = this.project;
    if (project == null) {
      _files = const [];
      _file = null;
      _loading = false;
      _error = null;
      _notify();
      return;
    }
    final projectId = project.id;
    if (projectId != _projectId) {
      _projectId = projectId;
      _files = const [];
      _file = null;
    }
    _loading = true;
    _error = null;
    _notify();
    final accepted = {
      for (final extension in extensions) extension.toLowerCase(),
    };
    var found = <String>[];
    String? failure;
    try {
      found = await _listProjectFiles(project.path, accepted, maxProjectFiles);
    } on FileSystemException catch (exception) {
      failure = exception.message;
    }
    if (_disposed || generation != _generation) return;
    _files = List<String>.unmodifiable(found);
    _file = found.contains(_file)
        ? _file
        : (found.isEmpty ? null : found.first);
    _loading = false;
    _error = failure;
    _notify();
  }

  void selectProject(String? id) {
    if (id == _projectId) return;
    _projectId = id;
    _file = null;
    _files = const [];
    unawaited(refresh());
  }

  void selectFile(String? path) {
    if (_file == path) return;
    _file = _files.contains(path) ? path : null;
    _notify();
  }

  /// Project-relative label used by dropdowns and result rows.
  String label(String? path) {
    if (path == null) return '';
    final root = project?.path;
    if (root == null) return p.basename(path);
    return p.relative(path, from: root);
  }

  void _onStoreChanged() {
    unawaited(refresh());
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

Future<void> _deleteQuietly(Directory directory) async {
  try {
    if (directory.existsSync()) await directory.delete(recursive: true);
  } on FileSystemException {
    // A leftover scratch directory is not worth failing a tool result over.
  }
}
