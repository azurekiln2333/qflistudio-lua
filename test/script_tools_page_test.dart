import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/script_toolchain.dart';
import 'package:qfli_lua/script_tools_page.dart';
import 'package:qfli_lua/shell_code_analyzer.dart';
import 'package:qfli_studio_core/services/code_analysis.dart';

const _sourceKey = Key('script-tool-source');
const _runKey = Key('script-tool-run');
const _pendingKey = Key('script-tool-pending');
const _outputKey = Key('script-tool-output');
const _diagnosticKey = Key('script-tool-diagnostic-0');

void main() {
  final toolchain = ScriptToolchain(
    libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
    typescriptCompilerPath: p.absolute('assets/runtime/typescript.js'),
  );
  late String shell;

  setUpAll(() async {
    final found = await findPosixShell();
    expect(found, isNotNull, reason: 'These tests require a real POSIX shell.');
    shell = found!;
  });

  testWidgets('JavaScript checks exact pasted text without evaluating it', (
    tester,
  ) async {
    await _open(tester, JavaScriptSyntaxPage(toolchain: toolchain));
    const invalid = '// 中文😀\r\nconst = 1;';
    await _enter(tester, invalid);
    await _runReal(tester);
    await _waitForText(tester, '发现 1 个诊断');
    expect(find.textContaining('第 2 行，第 7 列'), findsOneWidget);
    expect(find.byKey(_diagnosticKey), findsOneWidget);

    const valid = '''
import './missing_dependency.js';
throw new Error('must not execute');
while (true) {}
''';
    await _enter(tester, valid);
    expect(find.byKey(_diagnosticKey), findsNothing);
    expect(find.text('发现 1 个诊断'), findsNothing);
    await _runReal(tester);
    await _waitForText(tester, '语法检查通过');
    expect(find.byKey(_diagnosticKey), findsNothing);
    expect(_input(tester).controller!.text, valid);
  });

  testWidgets('TypeScript shows real emitted JavaScript and syntax errors', (
    tester,
  ) async {
    await _open(tester, TypeScriptTranspilePage(toolchain: toolchain));
    expect(find.textContaining('不进行项目级类型检查'), findsOneWidget);
    await _enter(tester, '// 中文😀\r\nconst value: number = ;');
    await _runReal(tester);
    await _waitForText(tester, '发现 1 个诊断');
    expect(find.textContaining('Expression expected'), findsOneWidget);
    expect(find.textContaining('第 2 行，第 23 列'), findsOneWidget);

    const source = '''
interface Payload { value: number; }
const data: Payload = { value: 42 };
console.log(data.value);
throw new Error('must not execute');
while (true) {}
''';
    await _enter(tester, source);
    expect(find.byKey(_outputKey), findsNothing);
    await _runReal(tester);
    await _waitForText(tester, '转译完成');
    final output = tester.widget<SelectableText>(find.byKey(_outputKey)).data!;
    expect(output, contains('data = { value: 42 }'));
    expect(output, contains('console.log(data.value)'));
    expect(output, contains('must not execute'));
    expect(output, isNot(contains('interface Payload')));
    expect(output, isNot(contains(': Payload')));
    expect(find.byKey(_diagnosticKey), findsNothing);
    expect(_input(tester).controller!.text, source);
  });

  testWidgets('Shell parses malformed and corrected stdin without execution', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('shell_tool_😀_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final marker = File(p.join(directory.path, 'must-not-exist.txt'));
    final markerPath = marker.path
        .replaceAll('\\', '/')
        .replaceAll("'", "'\"'\"'");
    await _open(
      tester,
      ShellSyntaxPage(
        analyzer: ShellCodeAnalyzer(shellFinder: () async => shell),
      ),
    );
    await _enter(tester, '# 中文😀\r\nprintf ok\r\n)\r\n');
    await _runReal(tester);
    await _waitForText(tester, '发现 1 个诊断');
    expect(find.textContaining('第 3 行，第 1 列'), findsOneWidget);

    final source =
        '''
printf mutation > '$markerPath'
. '/definitely-missing-shell-source'
exit 99
while :; do :; done
''';
    await _enter(tester, source);
    await _runReal(tester);
    await _waitForText(tester, '语法检查通过');
    expect(marker.existsSync(), isFalse);
    expect(directory.listSync(), isEmpty);
    expect(_input(tester).controller!.text, source);
  });

  testWidgets('real parsers accept empty source and empty transpile output', (
    tester,
  ) async {
    final pages = <Widget>[
      JavaScriptSyntaxPage(toolchain: toolchain),
      TypeScriptTranspilePage(toolchain: toolchain),
      ShellSyntaxPage(
        analyzer: ShellCodeAnalyzer(shellFinder: () async => shell),
      ),
    ];
    for (var i = 0; i < pages.length; i++) {
      await _open(tester, pages[i]);
      await _runReal(tester);
      await _waitForText(tester, i == 1 ? '转译完成' : '语法检查通过');
      expect(find.byKey(_diagnosticKey), findsNothing);
      if (i == 1) {
        expect(find.text('（没有生成 JavaScript 文本）'), findsOneWidget);
      }
    }
  });

  testWidgets('missing Script engine is reported as unavailable', (
    tester,
  ) async {
    await _open(
      tester,
      JavaScriptSyntaxPage(
        toolchain: ScriptToolchain(
          libraryPath: p.absolute('absent-script.dll'),
        ),
      ),
    );
    await _enter(tester, 'const value = 42;');
    await _runReal(tester);
    await _waitForText(tester, '后端不可用');
    expect(find.textContaining('Script parser unavailable'), findsOneWidget);
    expect(find.text('语法检查通过'), findsNothing);
  });

  testWidgets('missing TypeScript compiler is reported as unavailable', (
    tester,
  ) async {
    await _open(
      tester,
      TypeScriptTranspilePage(
        toolchain: ScriptToolchain(
          libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
          typescriptCompilerPath: p.absolute('absent-typescript.js'),
        ),
      ),
    );
    await _enter(tester, 'const value: number = 42;');
    await _runReal(tester);
    await _waitForText(tester, '后端不可用');
    expect(find.textContaining('absent-typescript.js'), findsOneWidget);
    expect(find.text('转译完成'), findsNothing);
    expect(find.byKey(_outputKey), findsNothing);
  });

  testWidgets('missing Shell parser is reported as unavailable', (
    tester,
  ) async {
    await _open(
      tester,
      ShellSyntaxPage(
        analyzer: ShellCodeAnalyzer(shellFinder: () async => null),
      ),
    );
    await _enter(tester, 'printf ok');
    await _runReal(tester);
    await _waitForText(tester, '后端不可用');
    expect(
      find.text('No local POSIX shell parser is available.'),
      findsOneWidget,
    );
    expect(find.text('语法检查通过'), findsNothing);
  });

  for (final transpile in [false, true]) {
    testWidgets(
      '${transpile ? 'TypeScript' : 'JavaScript'} ignores an old result after edit and revert',
      (tester) async {
        final controlled = _ControlledToolchain();
        await _open(
          tester,
          transpile
              ? TypeScriptTranspilePage(toolchain: controlled)
              : JavaScriptSyntaxPage(toolchain: controlled),
        );
        const original = '  // 中文😀\r\nconst value = 42;\n';
        await _enter(tester, original);
        await tester.tap(find.byKey(_runKey));
        await tester.pump();
        expect(find.byKey(_pendingKey), findsOneWidget);
        expect(
          tester.widget<FilledButton>(find.byKey(_runKey)).onPressed,
          isNull,
        );
        expect(controlled.sources.single, original);
        expect(controlled.transpiles.single, transpile);

        await _enter(tester, 'changed');
        await _enter(tester, original);
        controlled.pending.single.complete(
          const ScriptToolResult(
            status: 3,
            output: 'stale output',
            error: 'stale error',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_pendingKey), findsNothing);
        expect(find.textContaining('stale'), findsNothing);
        expect(find.textContaining('请重新'), findsOneWidget);

        await tester.tap(find.byKey(_runKey));
        controlled.pending.last.complete(
          ScriptToolResult(
            status: 0,
            output: transpile ? 'const value = 42;\n' : '',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(transpile ? '转译完成' : '语法检查通过'), findsOneWidget);
        await _enter(tester, 'new source');
        expect(find.byKey(const Key('script-tool-status')), findsNothing);
        expect(find.byKey(_outputKey), findsNothing);
      },
    );
  }

  testWidgets('Shell passes an exact snapshot and discards its stale result', (
    tester,
  ) async {
    final analyzer = _ControlledAnalyzer();
    await _open(tester, ShellSyntaxPage(analyzer: analyzer));
    const source = ' # 中文😀\r\nprintf ok\n';
    await _enter(tester, source);
    await tester.tap(find.byKey(_runKey));
    await tester.pump();
    final request = analyzer.requests.single;
    expect(request.language, 'Shell');
    expect(p.isAbsolute(request.projectPath), isTrue);
    expect(p.isWithin(request.projectPath, request.activeFilePath), isTrue);
    expect(request.documents.single.path, request.activeFilePath);
    expect(request.documents.single.revision, request.revision);
    expect(request.documents.single.text, source);
    await _enter(tester, ')');
    analyzer.pending.single.complete(const CodeAnalysisResult());
    await tester.pumpAndSettle();
    expect(find.text('语法检查通过'), findsNothing);
    expect(find.textContaining('请重新'), findsOneWidget);
    expect(find.byKey(_pendingKey), findsNothing);
  });

  testWidgets('selection changes do not invalidate a current check', (
    tester,
  ) async {
    final controlled = _ControlledToolchain();
    await _open(tester, JavaScriptSyntaxPage(toolchain: controlled));
    await _enter(tester, 'const value = 42;');
    await tester.tap(find.byKey(_runKey));
    _input(tester).controller!.selection = const TextSelection.collapsed(
      offset: 2,
    );
    controlled.pending.single.complete(const ScriptToolResult(status: 0));
    await tester.pumpAndSettle();
    expect(find.text('语法检查通过'), findsOneWidget);
  });

  testWidgets('replacing a backend invalidates its pending result', (
    tester,
  ) async {
    final old = _ControlledToolchain();
    final replacement = _ControlledToolchain();
    await _open(tester, TypeScriptTranspilePage(toolchain: old));
    await _enter(tester, 'const value: number = 42;');
    await tester.tap(find.byKey(_runKey));
    await tester.pumpWidget(
      MaterialApp(home: TypeScriptTranspilePage(toolchain: replacement)),
    );
    old.pending.single.complete(
      const ScriptToolResult(status: 0, output: 'stale output'),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_outputKey), findsNothing);
    await tester.tap(find.byKey(_runKey));
    expect(replacement.sources.single, 'const value: number = 42;');
    replacement.pending.single.complete(
      const ScriptToolResult(status: 0, output: 'fresh output'),
    );
    await tester.pumpAndSettle();
    expect(find.text('fresh output'), findsOneWidget);
  });

  testWidgets('unexpected backend failures remain failures and permit retry', (
    tester,
  ) async {
    final controlled = _ControlledToolchain();
    await _open(tester, JavaScriptSyntaxPage(toolchain: controlled));
    await tester.tap(find.byKey(_runKey));
    controlled.pending.single.completeError(StateError('backend failed'));
    await tester.pumpAndSettle();
    expect(find.text('操作失败'), findsOneWidget);
    expect(find.textContaining('backend failed'), findsOneWidget);
    await tester.tap(find.byKey(_runKey));
    controlled.pending.last.complete(const ScriptToolResult(status: 0));
    await tester.pumpAndSettle();
    expect(find.text('语法检查通过'), findsOneWidget);
  });

  for (final shellPage in [false, true]) {
    testWidgets(
      '${shellPage ? 'Shell' : 'Script'} completion after disposal is safe',
      (tester) async {
        final toolchain = _ControlledToolchain();
        final analyzer = _ControlledAnalyzer();
        await _open(
          tester,
          shellPage
              ? ShellSyntaxPage(analyzer: analyzer)
              : TypeScriptTranspilePage(toolchain: toolchain),
        );
        await tester.tap(find.byKey(_runKey));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        if (shellPage) {
          analyzer.pending.single.complete(const CodeAnalysisResult());
        } else {
          toolchain.pending.single.complete(const ScriptToolResult(status: 0));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

TextField _input(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(of: find.byKey(_sourceKey), matching: find.byType(TextField)),
);

Future<void> _enter(WidgetTester tester, String source) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(_sourceKey),
      matching: find.byType(TextField),
    ),
    source,
  );
  await tester.pump();
}

Future<void> _runReal(WidgetTester tester) async {
  // Real process streams and isolate work must start outside FakeAsync.
  await tester.runAsync(() => tester.tap(find.byKey(_runKey)));
  await tester.pump();
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (var attempt = 0; attempt < 500; attempt++) {
    if (tester.any(find.text(text))) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    find.text(text),
    findsOneWidget,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .join('\n'),
  );
}

class _ControlledToolchain extends ScriptToolchain {
  final sources = <String>[];
  final transpiles = <bool>[];
  final pending = <Completer<ScriptToolResult>>[];

  Future<ScriptToolResult> _capture(String source, bool transpile) {
    sources.add(source);
    transpiles.add(transpile);
    final completer = Completer<ScriptToolResult>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<ScriptToolResult> checkSource(
    String source, {
    String? fileName,
    bool typescript = false,
    bool module = true,
  }) => _capture(source, false);

  @override
  Future<ScriptToolResult> transpile(
    String source, {
    String fileName = 'editor.ts',
  }) => _capture(source, true);
}

class _ControlledAnalyzer implements CodeAnalyzer {
  final requests = <CodeAnalysisRequest>[];
  final pending = <Completer<CodeAnalysisResult>>[];

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) {
    requests.add(request);
    final completer = Completer<CodeAnalysisResult>();
    pending.add(completer);
    return completer.future;
  }
}
