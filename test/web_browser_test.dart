@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_lua/web/app_web.dart';
import 'package:qfli_lua/web/platform_browser.dart';
import 'package:qfli_lua/web/workspace.dart';
import 'package:re_editor/re_editor.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('real browser storage restores a newly mounted editor', (
    tester,
  ) async {
    final key = 'qfliscript.test.${DateTime.now().microsecondsSinceEpoch}';
    final storage = BrowserWorkspaceStorage(key: key);
    addTearDown(() => web.window.localStorage.removeItem(key));
    final first = WebWorkspace(storage);
    addTearDown(first.dispose);
    await tester.pumpWidget(
      QfliWebApp(workspace: first, fileTransfer: BrowserSourceFileTransfer()),
    );
    await tester.pumpAndSettle();
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text =
        'print("浏览器保存")\n';
    first.createFile('browser.ts', 'const message = "persisted";\n');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-workspace')));
    await tester.pump();
    expect(web.window.localStorage.getItem(key), contains('browser.ts'));
    expect(find.text('已保存到此浏览器'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    final reopened = WebWorkspace(BrowserWorkspaceStorage(key: key));
    addTearDown(reopened.dispose);
    await tester.pumpWidget(
      QfliWebApp(
        workspace: reopened,
        fileTransfer: BrowserSourceFileTransfer(),
      ),
    );
    await tester.pumpAndSettle();
    expect(reopened.files.first.content, 'print("浏览器保存")\n');
    expect(reopened.selectedFile!.name, 'browser.ts');
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text,
      'const message = "persisted";\n',
    );
    expect(find.text('已保存到此浏览器'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
