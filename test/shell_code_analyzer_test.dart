import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/shell_code_analyzer.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';

void main() {
  late Directory project;
  late File activeFile;
  late String shell;
  late ShellCodeAnalyzer analyzer;

  setUpAll(() async {
    final found = await findPosixShell();
    expect(
      found,
      isNotNull,
      reason: 'Real local sh is required for these tests.',
    );
    shell = found!;
    analyzer = ShellCodeAnalyzer(shellFinder: () async => shell);
  });

  setUp(() {
    project = Directory.systemTemp.createTempSync('shell_诊断_😀_');
    activeFile = File(p.join(project.path, '未保存(示例).sh'))
      ..writeAsStringSync('printf "disk version"\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  CodeAnalysisRequest request(
    String source, {
    String language = 'Shell',
    String? path,
    String? root,
    int revision = 7,
    List<CodeDocumentSnapshot>? documents,
  }) {
    final active = path ?? activeFile.path;
    return CodeAnalysisRequest(
      projectPath: root ?? project.path,
      activeFilePath: active,
      language: language,
      revision: revision,
      documents:
          documents ??
          [
            CodeDocumentSnapshot(
              path: active,
              text: source,
              revision: revision,
            ),
          ],
    );
  }

  CodeDiagnostic diagnostic(CodeAnalysisResult result) {
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, hasLength(1));
    final value = result.diagnostics.single;
    expect(value.filePath, activeFile.path);
    expect(value.severity, CodeDiagnosticSeverity.error);
    expect(value.source, 'Shell');
    expect(value.code, 'shell.syntax');
    return value;
  }

  test('finder resolves an absolute real POSIX shell executable', () {
    expect(p.isAbsolute(shell), isTrue);
    expect(File(shell).existsSync(), isTrue);
    expect(p.basename(shell).toLowerCase(), isNot(contains('powershell')));
    expect(p.basename(shell).toLowerCase(), matches(r'^(?:ba)?sh(?:\.exe)?$'));
  });

  test(
    'real parser checks dirty malformed text without changing disk',
    () async {
      final before = activeFile.readAsBytesSync();
      const source = 'printf "hello"\n)\n';
      final value = diagnostic(await analyzer.analyze(request(source)));
      expect(value.message.toLowerCase(), contains('syntax'));
      expect(value.startOffset, source.indexOf(')'));
      expect(value.endOffset, source.indexOf(')') + 1);
      expect(activeFile.readAsBytesSync(), before);
      expect(project.listSync(), hasLength(1));
    },
  );

  test('valid dirty source and empty source are actually parsed', () async {
    activeFile.writeAsStringSync('if then invalid disk source');
    for (final language in ['Shell', 'sh', 'BASH']) {
      for (final source in ['', '#!/bin/sh\nprintf "%s\\n" "中文😀"\n']) {
        final result = await analyzer.analyze(
          request(source, language: language),
        );
        expect(result.unavailableReason, isNull);
        expect(result.diagnostics, isEmpty);
      }
    }
    expect(activeFile.readAsStringSync(), 'if then invalid disk source');
  });

  test(
    'CRLF and preceding Unicode preserve whole-line UTF-16 ranges',
    () async {
      const source = '# 中文😀\r\nprintf "未保存😀"\r\n  ) # 错误\r\n';
      final value = diagnostic(await analyzer.analyze(request(source)));
      expect(value.startOffset, source.indexOf('  )'));
      expect(value.endOffset, source.length - 2);
      expect(source.substring(value.startOffset, value.endOffset), '  ) # 错误');
    },
  );

  test('unterminated control flow without final newline maps EOF', () async {
    const source = 'if true; then\n  printf "hi"';
    final value = diagnostic(await analyzer.analyze(request(source)));
    expect(value.message.toLowerCase(), contains('end of file'));
    expect(value.startOffset, source.length);
    expect(value.endOffset, source.length);
  });

  test(
    'syntax-only stdin never executes substitutions or sources files',
    () async {
      final marker = File(p.join(project.path, 'must-not-exist.txt'));
      final markerPath = marker.path
          .replaceAll('\\', '/')
          .replaceAll("'", "'\"'\"'");
      final source =
          '''
printf '%s\\n' "\$(printf mutation > '$markerPath')"
. '/definitely-missing-shell-source'
exit 99
while :; do :; done
''';
      final before = activeFile.readAsBytesSync();
      final result = await analyzer.analyze(request(source));
      expect(result.unavailableReason, isNull);
      expect(result.diagnostics, isEmpty);
      expect(marker.existsSync(), isFalse);
      expect(activeFile.readAsBytesSync(), before);
      expect(project.listSync(), hasLength(1));
    },
  );

  test('other snapshots are not read from disk or executed', () async {
    final result = await analyzer.analyze(
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(
            path: p.join(project.path, 'missing.sh'),
            text: 'exit 88',
            revision: 3,
          ),
        ],
      ),
    );
    expect(result.unavailableReason, isNull);
    expect(result.diagnostics, isEmpty);
    expect(project.listSync(), hasLength(1));
  });

  test('invalid snapshots fail before parser discovery', () async {
    var calls = 0;
    final guarded = ShellCodeAnalyzer(
      shellFinder: () async {
        calls++;
        return shell;
      },
    );
    final other = p.join(project.path, 'other.sh');
    final foreign = p.join(project.parent.path, 'outside.sh');
    final invalid = [
      request(')', language: 'lua'),
      request(')', path: p.join(project.path, 'main.txt')),
      request(')', path: foreign),
      request(')', path: 'relative.sh'),
      request(')', root: 'relative'),
      request(')', path: '${activeFile.path}\u0000'),
      request(')', root: '${project.path}\u0000'),
      request('a\u0000b'),
      request(' ' * (ShellCodeAnalyzer.maximumSourceLength + 1)),
      request('', documents: []),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 6),
        ],
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: activeFile.path, text: ')', revision: 7),
        ],
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: foreign, text: '', revision: 1),
        ],
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: other, text: '', revision: 1),
          CodeDocumentSnapshot(path: other, text: '', revision: 1),
        ],
      ),
      request(
        '',
        documents: [
          CodeDocumentSnapshot(path: activeFile.path, text: '', revision: 7),
          CodeDocumentSnapshot(path: other, text: '\u0000', revision: 1),
        ],
      ),
    ];
    for (final value in invalid) {
      final result = await guarded.analyze(value);
      expect(result.unavailableReason, isNotEmpty);
      expect(result.diagnostics, isEmpty);
    }
    expect(calls, 0);
  });

  test('missing or unusable parser is unavailable rather than clean', () async {
    for (final provider in [
      ShellCodeAnalyzer(shellFinder: () async => null),
      ShellCodeAnalyzer(shellFinder: () async => 'relative-shell'),
      ShellCodeAnalyzer(
        shellFinder: () async => p.join(project.path, 'missing-shell'),
      ),
      ShellCodeAnalyzer(shellFinder: () async => throw StateError('missing')),
      ShellCodeAnalyzer(shellFinder: () async => activeFile.path),
    ]) {
      final result = await provider.analyze(request(')'));
      expect(result.unavailableReason, isNotEmpty);
      expect(result.diagnostics, isEmpty);
    }
  });
}
