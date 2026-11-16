import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_lua/web/app_web.dart';
import 'package:qfli_lua/web/workspace.dart';
import 'package:re_editor/re_editor.dart';

import 'web_workspace_test.dart' show MemoryWorkspaceStorage;

class FakeSourceFileTransfer implements SourceFileTransfer {
  List<SourceFile> incoming = [];
  final List<SourceFile> exported = [];

  @override
  Future<List<SourceFile>> importFiles() async => incoming;

  @override
  void exportFile(SourceFile file) => exported.add(file);
}

void main() {
  testWidgets('opening and editing CRLF files preserves line endings', (
    tester,
  ) async {
    final workspace = WebWorkspace(MemoryWorkspaceStorage());
    final id = workspace.createFile('windows.lua', 'print(1)\r\nprint(2)\r\n');
    workspace.save();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: workspace, fileTransfer: FakeSourceFileTransfer()),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    controller.selection = const CodeLineSelection.collapsed(
      index: 1,
      offset: 2,
    );
    await tester.pump();
    expect(workspace.isDirty, isFalse);
    expect(workspace.selectedFile!.content, 'print(1)\r\nprint(2)\r\n');
    controller.text = 'print(3)\r\nprint(4)\r\n';
    await tester.pump();
    expect(
      workspace.files.firstWhere((file) => file.id == id).content,
      'print(3)\r\nprint(4)\r\n',
    );
    expect(workspace.isDirty, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('editor changes save, restore and export exact source', (
    tester,
  ) async {
    final storage = MemoryWorkspaceStorage();
    final workspace = WebWorkspace(storage);
    final transfer = FakeSourceFileTransfer();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: workspace, fileTransfer: transfer),
    );
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = 'print("edited in the browser")\n';
    await tester.pump();
    expect(find.text('未保存'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-workspace')));
    await tester.pump();
    expect(find.text('已保存到此浏览器'), findsOneWidget);
    await tester.tap(find.text('导出当前文件'));
    expect(
      transfer.exported.single.content,
      'print("edited in the browser")\n',
    );

    await tester.pumpWidget(const SizedBox());
    final reopened = WebWorkspace(storage);
    addTearDown(reopened.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: reopened, fileTransfer: transfer),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text,
      'print("edited in the browser")\n',
    );
    for (final label in ['运行', '调试', '编译']) {
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, label),
      );
      expect(button.onPressed, isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('file controls preserve edits and confirm deletion', (
    tester,
  ) async {
    final workspace = WebWorkspace(MemoryWorkspaceStorage());
    final transfer = FakeSourceFileTransfer()
      ..incoming = [
        const SourceFile(name: 'imported.ts', content: 'let x = 1;'),
      ];
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: workspace, fileTransfer: transfer),
    );
    await tester.pumpAndSettle();
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text =
        'draft';
    await tester.tap(find.text('新建文件'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'second.lua');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(workspace.selectedFile!.name, 'second.lua');

    await tester.tap(find.widgetWithText(ChoiceChip, 'main.lua'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text,
      'draft',
    );
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'renamed.lua');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(workspace.selectedFile!.name, 'renamed.lua');

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(workspace.selectedFile!.name, 'imported.ts');
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text,
      'let x = 1;',
    );
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(workspace.files, hasLength(3));
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(workspace.files.map((file) => file.name), [
      'renamed.lua',
      'second.lua',
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed save remains visibly unsaved', (tester) async {
    final storage = MemoryWorkspaceStorage()..failWrite = true;
    final workspace = WebWorkspace(storage);
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: workspace, fileTransfer: FakeSourceFileTransfer()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-workspace')));
    await tester.pump();
    expect(find.text('保存不可用'), findsOneWidget);
    expect(find.text('已保存到此浏览器'), findsNothing);
    expect(workspace.isDirty, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('corrupt data can be exported without overwriting storage', (
    tester,
  ) async {
    final storage = MemoryWorkspaceStorage()..value = '{broken';
    final workspace = WebWorkspace(storage);
    final transfer = FakeSourceFileTransfer();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: workspace, fileTransfer: transfer),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-workspace')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('导出原始数据'));
    expect(transfer.exported.single.content, '{broken');
    expect(storage.writes, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
