import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_lua/lua_tools_page.dart';
import 'package:qfli_lua/lua_debugger_page.dart';
import 'package:qfli_lua/script_tools_page.dart';
import 'package:qfli_studio_core/pages/tools_grid.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/widgets/tool_widgets.dart' show ToolCard;

/// One registered local project backed by real files under a temp directory.
class _Harness {
  _Harness(this.directory, this.store);

  final Directory directory;
  final ProjectStore store;

  static Future<_Harness> create(
    WidgetTester tester,
    Map<String, String> files, {
    String name = 'Lua 项目',
  }) async {
    return (await tester.runAsync(() async {
      final directory = Directory.systemTemp.createTempSync('qfli_lua_tools_');
      final project = Directory(p.join(directory.path, name))..createSync();
      for (final entry in files.entries) {
        final file = File(p.join(project.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }
      final store = ProjectStore(
        storageFile: File(p.join(directory.path, 'projects.json')),
      );
      await store.load();
      final result = await store.addExisting(project.path);
      if (result.project == null) {
        throw StateError('project registration failed: ${result.error}');
      }
      final harness = _Harness(directory, store);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        harness.dispose();
      });
      return harness;
    }))!;
  }

  void dispose() {
    store.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

/// Pumps the tools tab and returns the harness plus the terminal tap counter.
class _TabHarness {
  _TabHarness(this.harness, this.terminalOpens);

  final _Harness harness;
  final int Function() terminalOpens;
}

void main() {
  Future<_TabHarness> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _Harness.create(tester, {
      'main.lua': 'local util = require("util")\nprint(util)\n',
      'util.lua': 'return 1\n',
    });
    var terminalOpened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLuaToolsTab(harness.store, () => terminalOpened++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _TabHarness(harness, () => terminalOpened);
  }

  group('tools tab', () {
    testWidgets('lists every Lua tool individually beside the shared groups', (
      tester,
    ) async {
      await pumpTab(tester);
      for (final title in [
        LuaDebuggerPage.title,
        LuaSyntaxCheckPage.title,
        LuaBytecodePage.title,
        LuaModuleResolverPage.title,
        LuaLiteralPage.title,
        LuaPatternPage.title,
        JavaScriptSyntaxPage.title,
        TypeScriptTranspilePage.title,
        ShellSyntaxPage.title,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // The shared terminal shortcut and the shared offline tools stay intact.
      expect(find.text('终端'), findsOneWidget);
      expect(find.text('通用'), findsOneWidget);
      expect(find.byType(ToolCard), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('opens the terminal through the shared shortcut', (
      tester,
    ) async {
      final tab = await pumpTab(tester);
      await tester.tap(find.text('终端'));
      await tester.pumpAndSettle();
      expect(tab.terminalOpens(), 1);
    });

    testWidgets('opens each tool page from its own card', (tester) async {
      await pumpTab(tester);
      for (final title in [
        LuaDebuggerPage.title,
        LuaSyntaxCheckPage.title,
        LuaBytecodePage.title,
        LuaModuleResolverPage.title,
        LuaLiteralPage.title,
        LuaPatternPage.title,
        JavaScriptSyntaxPage.title,
        TypeScriptTranspilePage.title,
        ShellSyntaxPage.title,
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pump();
        if (title == LuaSyntaxCheckPage.title ||
            title == LuaBytecodePage.title) {
          await waitForText(tester, 'main.lua');
        }
        await tester.pumpAndSettle();
        // A tools tab must not nest another tools tab or a gateway card; the
        // tool page owns one Scaffold with its own app bar.
        expect(find.byType(ToolsGrid), findsNothing);
        expect(find.widgetWithText(AppBar, title), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  });

  group('syntax check page', () {
    testWidgets('reports the real error line and then accepts fixed code', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await _Harness.create(tester, {
        'broken.lua': 'local ok = 1\nlocal = 2\n',
        'good.lua': 'print("ok")\n',
      });

      await tester.pumpWidget(
        MaterialApp(home: LuaSyntaxCheckPage(store: harness.store)),
      );
      await waitForText(tester, 'broken.lua');

      await tester.tap(find.text('检查项目文件'));
      await waitForText(tester, '语法错误');
      expect(find.text("<name> expected near '='"), findsOneWidget);
      expect(find.text('local = 2'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Switch to the other file through the picker and re-check.
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('good.lua').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查项目文件'));
      await waitForText(tester, '语法正确');
    });

    testWidgets('checks pasted source without touching project files', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await _Harness.create(tester, {'main.lua': 'print(1)\n'});
      await tester.pumpWidget(
        MaterialApp(home: LuaSyntaxCheckPage(store: harness.store)),
      );
      await waitForText(tester, 'main.lua');

      await tester.enterText(find.byType(TextField).first, 'if true then');
      await tester.tap(find.text('检查代码'));
      await waitForText(tester, '语法错误');
      expect(find.text('snippet.lua'), findsOneWidget);
      expect(
        File(
          p.join(
            Directory(harness.store.projects.single.path).path,
            'main.lua',
          ),
        ).readAsStringSync(),
        'print(1)\n',
        reason: '检查片段不得修改项目文件',
      );
    });
  });

  group('bytecode page', () {
    testWidgets('compiles a project file and reports the Lua 5.4 header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await _Harness.create(tester, {
        'demo.lua': '''
local greeting = "hello"
local function add(a, b) return a + b end
print(greeting, add(1, 2))
''',
      });
      await tester.pumpWidget(
        MaterialApp(home: LuaBytecodePage(store: harness.store)),
      );
      await waitForText(tester, 'demo.lua');

      await tester.tap(find.text('编译并检查'));
      await waitForText(tester, '字节码检查完成');
      expect(find.text('0x54 (Lua 5.4)'), findsOneWidget);
      expect(find.text('函数数'), findsOneWidget);
      expect(find.text('指令数'), findsOneWidget);
      expect(find.textContaining('"hello"'), findsOneWidget);
      // Inspection must not leave a .luac next to the source.
      final project = Directory(harness.store.projects.single.path);
      expect(File(p.join(project.path, 'demo.luac')).existsSync(), isFalse);
      expect(
        File(p.join(project.path, 'demo.lua')).readAsStringSync(),
        contains('local greeting = "hello"'),
      );
    });

    testWidgets(
      'exports runnable bytecode, preserves cancelled output and inspects it',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = await _Harness.create(tester, {
          'demo.lua': 'print(42)',
        });
        await tester.pumpWidget(
          MaterialApp(home: LuaBytecodePage(store: harness.store)),
        );
        await waitForText(tester, 'demo.lua');
        await tester.tap(find.text('生成 .luac 到项目'));
        await waitForText(tester, '已生成 demo.luac');
        final project = harness.store.projects.single.path;
        final output = File(p.join(project, 'demo.luac'));
        final bytes = output.readAsBytesSync();
        final run = await tester.runAsync(
          () => const LuaToolchain().run(
            file: output.path,
            projectDirectory: project,
          ),
        );
        expect(run!.output, '42\n');
        expect(run.success, isTrue, reason: run.error);
        await tester.tap(find.text('生成 .luac 到项目'));
        await waitForText(tester, '替换已有字节码？');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(output.readAsBytesSync(), bytes);
        await tester.tap(find.byTooltip('刷新文件'));
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (!tester.any(find.byType(LinearProgressIndicator))) break;
        }
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('demo.luac').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('检查字节码'));
        await waitForText(tester, '字节码检查完成');
        expect(find.text('0x54 (Lua 5.4)'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, '生成 .luac 到项目'),
              )
              .onPressed,
          isNull,
        );
      },
    );
  });

  group('module resolver page', () {
    testWidgets('resolves a module and audits the project graph', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await _Harness.create(tester, {
        'main.lua': 'local util = require("util")\nrequire("nope")\n',
        'util.lua': 'return 1\n',
      });
      await tester.pumpWidget(
        MaterialApp(home: LuaModuleResolverPage(store: harness.store)),
      );
      await waitForText(tester, 'Lua 项目');

      await tester.tap(find.text('解析模块'));
      await waitForText(tester, '命中文件');
      expect(find.text('util.lua'), findsOneWidget);

      await tester.tap(find.text('扫描项目 require'));
      await waitForText(tester, '扫描完成 · 1 个未解析模块');
      expect(find.textContaining('nope'), findsWidgets);
    });
  });

  group('literal page', () {
    testWidgets('escapes text and restores a literal', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LuaLiteralPage()));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'a"b\nc');
      await tester.pumpAndSettle();
      expect(find.text(r'"a\"b\nc"'), findsOneWidget);

      await tester.enterText(fields.last, r'"\65\66"');
      await tester.pumpAndSettle();
      expect(find.text('AB'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      await tester.enterText(fields.last, r'"\q"');
      await tester.pumpAndSettle();
      expect(find.textContaining('无效转义序列'), findsOneWidget);
    });
  });

  group('pattern page', () {
    testWidgets('runs a pattern in the real VM and shows the replacement', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: LuaPatternPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('运行模式'));
      await waitForText(tester, '运行完成');
      expect(find.text('匹配数'), findsOneWidget);
      expect(find.text('1=a, 22=b, 333=c'), findsOneWidget);
      expect(find.text('a=1  →  a | 1'), findsOneWidget);
      expect(find.text('a | 1'), findsNothing);

      // An invalid pattern must surface the VM message, not a fake success.
      await tester.enterText(find.byType(TextField).at(1), '(%a');
      await tester.tap(find.text('运行模式'));
      await waitForText(tester, '模式错误');
    });
  });
}

/// Waits for an async native call by pumping frames while real time passes.
Future<void> waitForText(
  WidgetTester tester,
  String text, {
  int attempts = 300,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (tester.any(find.text(text))) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.text(text), findsOneWidget);
}
