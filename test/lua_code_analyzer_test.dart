import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_code_analyzer.dart';
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';

void main() {
  late Directory project;
  late File activeFile;
  final analyzer = LuaCodeAnalyzer(
    toolchain: LuaToolchain(
      libraryPath: Platform.environment['QFLI_LUA_LIBRARY'],
    ),
  );

  setUp(() {
    project = Directory.systemTemp.createTempSync('lua_诊断_😀_');
    activeFile = File(p.join(project.path, '未保存(示例).lua'));
    activeFile.writeAsStringSync('print("disk version")');
  });

  tearDown(() => project.deleteSync(recursive: true));

  CodeAnalysisRequest request(
    String source, {
    String language = 'Lua',
    String? path,
    String? root,
    int revision = 7,
    List<CodeDocumentSnapshot>? documents,
  }) {
    final activePath = path ?? activeFile.path;
    return CodeAnalysisRequest(
      projectPath: root ?? project.path,
      activeFilePath: activePath,
      language: language,
      revision: revision,
      documents:
          documents ??
          [
            CodeDocumentSnapshot(
              path: activePath,
              text: source,
              revision: revision,
            ),
          ],
    );
  }

  CodeDiagnostic onlyDiagnostic(CodeAnalysisResult result) {
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, hasLength(1));
    final diagnostic = result.diagnostics.single;
    expect(diagnostic.filePath, activeFile.path);
    expect(diagnostic.severity, CodeDiagnosticSeverity.error);
    expect(diagnostic.source, 'Lua');
    expect(diagnostic.code, 'lua.syntax');
    return diagnostic;
  }

  test(
    'bundled parser checks unsaved malformed text without changing disk',
    () async {
      final before = activeFile.readAsBytesSync();
      const source = 'local = 1';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, 6);
      expect(diagnostic.endOffset, 7);
      expect(
        source.substring(diagnostic.startOffset, diagnostic.endOffset),
        '=',
      );
      expect(diagnostic.message, contains('expected'));
      expect(activeFile.readAsBytesSync(), before);
    },
  );

  test('clean unsaved source takes precedence over malformed disk', () async {
    activeFile.writeAsStringSync('local = invalid disk contents');
    final result = await analyzer.analyze(
      request('local n = 40 + 2\nprint(n)'),
    );
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, isEmpty);
    expect(activeFile.readAsStringSync(), 'local = invalid disk contents');
  });

  test('empty source is actually accepted by the bundled parser', () async {
    final result = await analyzer.analyze(request(''));
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, isEmpty);
  });

  test(
    'BOM and shebang match source-file syntax without executing it',
    () async {
      for (final source in [
        '\ufeffprint("中文😀")',
        '#!/usr/bin/env lua\r\nprint("中文😀")',
        '\ufeff#!/usr/bin/env lua\r\nprint("中文😀")',
        '#!/usr/bin/env lua',
      ]) {
        final result = await analyzer.analyze(request(source));
        expect(result.unavailableReason, isNull);
        expect(result.diagnostics, isEmpty);
      }
      for (final prefix in [
        '\ufeff#!/usr/bin/env lua\r\n',
        '#!/usr/bin/env lua\rignored header text\r\n',
      ]) {
        final malformed = '${prefix}print("中文😀"); local = 1';
        final diagnostic = onlyDiagnostic(
          await analyzer.analyze(request(malformed)),
        );
        expect(diagnostic.startOffset, malformed.indexOf('='));
        expect(diagnostic.endOffset, malformed.indexOf('=') + 1);
      }
    },
  );

  test('valid source is loaded without executing any side effects', () async {
    const source = '''
local f = assert(io.open("must-not-exist.txt", "w"))
f:write("mutation")
f:close()
os.remove("未保存(示例).lua")
require("missing_module_that_must_not_be_loaded")
error("must not run")
while true do end
''';
    final before = activeFile.readAsBytesSync();
    final result = await analyzer.analyze(request(source));
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, isEmpty);
    expect(activeFile.readAsBytesSync(), before);
    expect(project.listSync(), hasLength(1));
    expect(File('must-not-exist.txt').existsSync(), isFalse);
  });

  test(
    'Unicode before the error preserves UTF-16 positions on the same line',
    () async {
      const source = 'print("中文😀"); local = 1';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, source.indexOf('='));
      expect(diagnostic.endOffset, source.indexOf('=') + 1);
    },
  );

  test(
    'CRLF and Unicode in preceding lines preserve original offsets',
    () async {
      const source = '-- 中文😀\r\nprint("你好🌍")\r\n\tlocal = 1\r\n';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, source.indexOf('='));
      expect(diagnostic.endOffset, source.indexOf('=') + 1);
    },
  );

  test('Lua lone CR and paired LFCR newlines use editor code units', () async {
    for (final newline in ['\r', '\n\r']) {
      final source = '-- 中文😀${newline}local = 1';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, source.indexOf('='));
      expect(diagnostic.endOffset, source.indexOf('=') + 1);
    }
  });

  test(
    'long lines retain the real offending token without truncation',
    () async {
      final source = ' ' * 24000 + 'local = 1';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, 24006);
      expect(diagnostic.endOffset, 24007);
    },
  );

  test('missing closing syntax is an exact EOF insertion range', () async {
    const source = 'local function greet()\r\n  print("你好😀")\r\n';
    final diagnostic = onlyDiagnostic(await analyzer.analyze(request(source)));
    expect(diagnostic.message, contains('near <eof>'));
    expect(diagnostic.startOffset, source.length);
    expect(diagnostic.endOffset, source.length);
  });

  test(
    'unfinished quoted text and long comments return bounded diagnostics',
    () async {
      for (final source in ['local text = "中文😀', '--[=[ 中文\r\n😀']) {
        final diagnostic = onlyDiagnostic(
          await analyzer.analyze(request(source)),
        );
        expect(diagnostic.message, contains('unfinished'));
        expect(diagnostic.startOffset, source.length);
        expect(diagnostic.endOffset, source.length);
      }
    },
  );

  test(
    'ambiguous near tokens underline the line instead of guessing a column',
    () async {
      const source = '-- prior\r\n  print("="); local = 1  \r\n';
      final diagnostic = onlyDiagnostic(
        await analyzer.analyze(request(source)),
      );
      expect(diagnostic.startOffset, source.indexOf('print'));
      expect(diagnostic.endOffset, source.indexOf('1') + 1);
      expect(
        source.substring(diagnostic.startOffset, diagnostic.endOffset),
        'print("="); local = 1',
      );
    },
  );

  test('embedded NUL is checked using explicit source length', () async {
    const source = 'local ok = 1\u0000local = 2';
    final diagnostic = onlyDiagnostic(await analyzer.analyze(request(source)));
    expect(diagnostic.message, contains('unexpected symbol'));
    expect(diagnostic.endOffset, lessThanOrEqualTo(source.length));
  });

  test('other open buffers are neither executed nor read from disk', () async {
    final result = await analyzer.analyze(
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(
            path: p.join(project.path, 'missing.lua'),
            text: 'error("other buffer must not execute")',
            revision: 3,
          ),
        ],
      ),
    );
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, isEmpty);
    expect(project.listSync(), hasLength(1));
  });

  test('foreign or relative paths cannot produce diagnostics', () async {
    final foreign = p.join(project.parent.path, 'outside.lua');
    final requests = [
      request('local = 1', path: foreign),
      request('local = 1', path: 'relative.lua'),
      request('local = 1', root: 'relative-root'),
      request(
        'local = 1',
        path: p.join(project.path, 'nested', '..', '..', 'escape.lua'),
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: foreign, text: 'local = 1', revision: 1),
        ],
      ),
    ];
    for (final value in requests) {
      final result = await analyzer.analyze(value);
      expect(result.unavailableReason, isNotEmpty);
      expect(result.diagnostics, isEmpty);
    }
  });

  test(
    'missing, stale and duplicate active snapshots report unavailable',
    () async {
      for (final documents in <List<CodeDocumentSnapshot>>[
        [],
        [CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 6)],
        [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(
            path: activeFile.path,
            text: 'local = 1',
            revision: 7,
          ),
        ],
      ]) {
        final result = await analyzer.analyze(
          request('', documents: documents),
        );
        expect(result.unavailableReason, isNotEmpty);
        expect(result.diagnostics, isEmpty);
      }
    },
  );

  test(
    'non-Lua, bytecode and oversized documents report unavailable',
    () async {
      for (final value in [
        request('print("hi")', language: 'javascript'),
        request('print("hi")', path: p.join(project.path, 'main.luac')),
        request('\u001bLua\u0054'),
        request(' ' * (LuaCodeAnalyzer.maximumSourceLength + 1)),
      ]) {
        final result = await analyzer.analyze(value);
        expect(result.unavailableReason, isNotEmpty);
        expect(result.diagnostics, isEmpty);
      }
    },
  );

  test('invalid snapshot identities are rejected before parsing', () async {
    final provider = LuaCodeAnalyzer(
      toolchain: const _ResultToolchain(
        LuaToolResult(status: 0, output: '', error: ''),
      ),
    );
    final nulRoot = p.join(project.path, 'invalid\u0000root');
    final helper = p.join(project.path, 'helper.lua');
    for (final value in [
      request('', root: nulRoot, path: p.join(nulRoot, 'main.lua')),
      request('', path: p.join(project.path, 'invalid\u0000.lua')),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(
            path: p.join(project.path, 'invalid\u0000.lua'),
            text: '',
            revision: 1,
          ),
        ],
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: helper, text: '', revision: 1),
          CodeDocumentSnapshot(
            path: p.join(project.path, 'nested', '..', 'helper.lua'),
            text: 'local = 1',
            revision: 2,
          ),
        ],
      ),
    ]) {
      final result = await provider.analyze(value);
      expect(result.unavailableReason, isNotEmpty);
      expect(result.diagnostics, isEmpty);
    }
  });

  test(
    'missing bundled library is unavailable rather than clean syntax',
    () async {
      final missing = LuaCodeAnalyzer(
        toolchain: LuaToolchain(
          libraryPath: p.join(project.path, 'missing.dll'),
        ),
      );
      final result = await missing.analyze(request('local = 1'));
      expect(result.unavailableReason, contains('unavailable'));
      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'backend failures are availability messages rather than source errors',
    () async {
      for (final result in [
        const LuaToolResult(status: 4, output: '', error: 'not enough memory'),
        const LuaToolResult(
          status: 3,
          output: '',
          error: 'missing diagnostic location',
        ),
        const LuaToolResult(
          status: 3,
          output: '',
          error: 'qfli-editor:200: bad syntax',
        ),
        const LuaToolResult(
          status: 0,
          output: '',
          error: 'unexpected bridge error',
        ),
      ]) {
        final provider = LuaCodeAnalyzer(toolchain: _ResultToolchain(result));
        final analysis = await provider.analyze(request('local = 1'));
        expect(analysis.unavailableReason, isNotEmpty);
        expect(analysis.diagnostics, isEmpty);
      }
    },
  );
}

class _ResultToolchain extends LuaToolchain {
  const _ResultToolchain(this.result);

  final LuaToolResult result;

  @override
  Future<LuaToolResult> checkSource(
    String source, {
    String chunkName = '@editor.lua',
  }) async => result;
}
