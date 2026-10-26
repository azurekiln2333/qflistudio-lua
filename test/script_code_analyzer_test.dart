import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/script_code_analyzer.dart';
import 'package:qfli_lua/script_toolchain.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';

void main() {
  final analyzer = ScriptCodeAnalyzer(
    toolchain: ScriptToolchain(
      libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
      typescriptCompilerPath: p.absolute('assets/runtime/typescript.js'),
    ),
  );
  late Directory project;
  late File active;

  setUp(() {
    project = Directory.systemTemp.createTempSync('script_诊断_😀_');
    active = File(p.join(project.path, '未保存.js'))
      ..writeAsStringSync('console.log("saved version");');
  });
  tearDown(() => project.deleteSync(recursive: true));

  CodeAnalysisRequest request(
    String source, {
    String language = 'JavaScript',
    String? path,
    String? root,
    int revision = 7,
    List<CodeDocumentSnapshot>? documents,
  }) {
    final activePath = path ?? active.path;
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

  test(
    'unsaved JS syntax error uses original text and preserves saved bytes',
    () async {
      final before = active.readAsBytesSync();
      const source = '// 中文😀\r\n"😀"; const = 1';
      final result = await analyzer.analyze(request(source));
      expect(result.unavailableReason, isNull);
      final diagnostic = result.diagnostics.single;
      expect(diagnostic.filePath, active.path);
      expect(diagnostic.source, 'QuickJS');
      expect(diagnostic.code, 'javascript.syntax');
      expect(diagnostic.severity, CodeDiagnosticSeverity.error);
      expect(diagnostic.startOffset, source.indexOf('='));
      expect(diagnostic.endOffset, source.indexOf('=') + 1);
      expect(active.readAsBytesSync(), before);
    },
  );

  test(
    'clean and empty snapshots are actually checked instead of saved source',
    () async {
      active.writeAsStringSync('const = malformed saved source');
      for (final text in ['', 'const n=40+2; console.log(n);']) {
        final result = await analyzer.analyze(request(text));
        expect(result.unavailableReason, isNull);
        expect(result.diagnostics, isEmpty);
      }
      expect(active.readAsStringSync(), 'const = malformed saved source');
    },
  );

  test(
    'checking neither executes user code nor loads other buffers/modules',
    () async {
      final before = active.readAsBytesSync();
      final result = await analyzer.analyze(
        request(
          '''
import './missing.js';
console.log('must not run');
throw new Error('must not run');
while(true) {}
''',
          documents: [
            CodeDocumentSnapshot(
              path: active.path,
              text: '''
import './missing.js';
console.log('must not run');
throw new Error('must not run');
while(true) {}
''',
              revision: 7,
            ),
            CodeDocumentSnapshot(
              path: p.join(project.path, 'missing.js'),
              text: 'const = malformed other buffer',
              revision: 3,
            ),
          ],
        ),
      );
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics, isEmpty);
      expect(active.readAsBytesSync(), before);
      expect(project.listSync(), hasLength(1));
    },
  );

  test(
    'unsaved TS diagnostics retain original UTF16 positions and compiler code',
    () async {
      final path = p.join(project.path, '未保存.ts');
      const source =
          '// 中文😀\r\ninterface Value {n:number}\r\nconst value: Value = ;';
      final result = await analyzer.analyze(
        request(source, language: 'TypeScript', path: path),
      );
      expect(result.unavailableReason, isNull);
      final diagnostic = result.diagnostics.single;
      expect(diagnostic.filePath, path);
      expect(diagnostic.source, 'TypeScript syntax');
      expect(diagnostic.code, '1109');
      expect(diagnostic.startOffset, source.indexOf(';'));
      expect(diagnostic.endOffset, source.indexOf(';') + 1);
      expect(File(path).existsSync(), isFalse);
    },
  );

  test(
    'TS syntax check accepts semantic mismatches without claiming type checking',
    () async {
      final result = await analyzer.analyze(
        request(
          'const value: number = "semantic mismatch";',
          language: 'ts',
          path: p.join(project.path, 'source.ts'),
        ),
      );
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'missing stale duplicate and outside snapshots report unavailable',
    () async {
      final foreign = p.join(project.parent.path, 'foreign.js');
      for (final value in [
        request('const = 1', documents: []),
        request(
          'const = 1',
          revision: 8,
          documents: [
            CodeDocumentSnapshot(
              path: active.path,
              text: 'const = 1',
              revision: 7,
            ),
          ],
        ),
        request(
          '',
          documents: [
            CodeDocumentSnapshot(path: active.path, text: '', revision: 7),
            CodeDocumentSnapshot(path: active.path, text: '', revision: 7),
          ],
        ),
        request(
          '',
          documents: [
            CodeDocumentSnapshot(path: active.path, text: '', revision: 7),
            CodeDocumentSnapshot(path: foreign, text: '', revision: 1),
          ],
        ),
        request('const = 1', path: foreign),
        request('const = 1', path: 'relative.js'),
        request('const = 1', root: 'relative-root'),
        request(
          'const = 1',
          path: p.join(project.path, '..', '..', 'escape.js'),
        ),
      ]) {
        final result = await analyzer.analyze(value);
        expect(result.unavailableReason, isNotEmpty);
        expect(result.diagnostics, isEmpty);
      }
    },
  );

  test(
    'language mismatch NUL paths and oversized source are unavailable',
    () async {
      for (final value in [
        request('', language: 'Lua'),
        request('', language: 'TypeScript'),
        request('', path: p.join(project.path, 'source.ts')),
        request('', path: p.join(project.path, 'source.js\u0000')),
        request('中' * (ScriptToolchain.maximumSourceBytes ~/ 3 + 1)),
      ]) {
        final result = await analyzer.analyze(value);
        expect(result.unavailableReason, isNotEmpty);
        expect(result.diagnostics, isEmpty);
      }
    },
  );

  test(
    'missing engine is unavailable and cannot produce a false clean result',
    () async {
      final missing = ScriptCodeAnalyzer(
        toolchain: ScriptToolchain(
          libraryPath: p.join(project.path, 'missing.dll'),
        ),
      );
      final result = await missing.analyze(request('const = 1'));
      expect(result.unavailableReason, isNotEmpty);
      expect(result.diagnostics, isEmpty);
    },
  );

  test(
    'backend failure inconsistent statuses and forged ranges are unavailable',
    () async {
      ScriptDiagnostic diagnostic({
        String? file,
        int start = 0,
        int end = 1,
        String message = 'actual syntax error',
        int category = 1,
      }) => ScriptDiagnostic(
        filePath: file ?? active.path,
        startOffset: start,
        endOffset: end,
        message: message,
        code: 'test',
        category: category,
      );
      for (final result in [
        const ScriptToolResult(status: 127, error: 'engine absent'),
        const ScriptToolResult(status: 124, error: 'parser timed out'),
        const ScriptToolResult(status: 3),
        const ScriptToolResult(status: 0, error: 'bridge failed'),
        const ScriptToolResult(status: 0, output: 'user code ran'),
        ScriptToolResult(status: 0, diagnostics: [diagnostic()]),
        ScriptToolResult(
          status: 3,
          diagnostics: [diagnostic(file: p.join(project.path, 'foreign.js'))],
        ),
        ScriptToolResult(status: 3, diagnostics: [diagnostic(start: -1)]),
        ScriptToolResult(status: 3, diagnostics: [diagnostic(end: 100)]),
        ScriptToolResult(status: 3, diagnostics: [diagnostic(message: '')]),
        ScriptToolResult(status: 3, diagnostics: [diagnostic(category: 99)]),
      ]) {
        final provider = ScriptCodeAnalyzer(
          toolchain: _ResultToolchain(result),
        );
        final analysis = await provider.analyze(request('const = 1'));
        expect(
          analysis.unavailableReason,
          isNotEmpty,
          reason: '${result.status}',
        );
        expect(analysis.diagnostics, isEmpty);
      }
    },
  );

  test('compiler warning and hint categories keep their severity', () async {
    final provider = ScriptCodeAnalyzer(
      toolchain: _ResultToolchain(
        ScriptToolResult(
          status: 0,
          diagnostics: [
            for (final category in [0, 2, 3])
              ScriptDiagnostic(
                filePath: active.path,
                startOffset: 0,
                endOffset: 0,
                message: 'compiler message',
                code: 'test',
                category: category,
              ),
          ],
        ),
      ),
    );
    final result = await provider.analyze(request(''));
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics.map((item) => item.severity), [
      CodeDiagnosticSeverity.warning,
      CodeDiagnosticSeverity.hint,
      CodeDiagnosticSeverity.information,
    ]);
  });
}

class _ResultToolchain extends ScriptToolchain {
  const _ResultToolchain(this.result);
  final ScriptToolResult result;

  @override
  Future<ScriptToolResult> checkSource(
    String source, {
    String? fileName,
    bool typescript = false,
    bool module = true,
  }) async => result;
}
