import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_debugger_page.dart';

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('lua_debug_page_');
  });

  Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
    for (var index = 0; index < 100; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (ready()) return;
    }
    fail('Timed out waiting for debugger page');
  }

  Future<void> open(
    WidgetTester tester,
    String source, {
    String? library,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final file = File(p.join(project.path, 'main.lua'))
      ..writeAsStringSync(source);
    await tester.pumpWidget(
      MaterialApp(
        home: LuaDebuggerPage(
          projectPath: project.path,
          initialFile: file.path,
          libraryPath: library,
        ),
      ),
    );
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('lua-debug-breakpoint-1'))
          .evaluate()
          .isNotEmpty,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.runAsync(() => project.delete(recursive: true));
    });
  }

  String status(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('lua-debug-status'))).data!;
  Future<void> press(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets(
    'narrow page has real breakpoint, locals, output and restart controls',
    (tester) async {
      await open(tester, 'local n = 40\nn = n + 2\nprint(n)\n');
      await press(tester, 'lua-debug-breakpoint-3');
      await press(tester, 'lua-debug-start');
      await waitFor(tester, () => status(tester).contains('已暂停'));
      expect(status(tester), contains('第 1 行'));
      await press(tester, 'lua-debug-continue');
      await waitFor(tester, () => status(tester).contains('第 3 行'));
      expect(find.text('n (number) = 42'), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('lua-debug-stdout')),
            )
            .data,
        isEmpty,
      );
      await press(tester, 'lua-debug-continue');
      await waitFor(tester, () => status(tester).contains('状态 0'));
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey('lua-debug-stdout')),
            )
            .data,
        '42\n',
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('lua-debug-into')),
            )
            .onPressed,
        isNull,
      );
      await press(tester, 'lua-debug-start');
      await waitFor(tester, () => status(tester).contains('第 1 行'));
      await press(tester, 'lua-debug-stop');
      await waitFor(tester, () => status(tester).contains('状态 130'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('step controls show true source position and limitation text', (
    tester,
  ) async {
    await open(tester, 'local n = 1\nn = n + 1\nprint(n)\n');
    expect(find.textContaining('不支持用户协程'), findsOneWidget);
    await press(tester, 'lua-debug-start');
    await waitFor(tester, () => status(tester).contains('第 1 行'));
    File(
      p.join(project.path, 'main.lua'),
    ).writeAsStringSync("error('changed')");
    await press(tester, 'lua-debug-into');
    await waitFor(tester, () => status(tester).contains('第 2 行'));
    expect(find.text('n (number) = 1'), findsOneWidget);
    expect(find.text('n = n + 1'), findsOneWidget);
    expect(find.text("error('changed')"), findsNothing);
    await press(tester, 'lua-debug-over');
    await waitFor(tester, () => status(tester).contains('第 3 行'));
    expect(find.text('n (number) = 2'), findsOneWidget);
    await press(tester, 'lua-debug-out');
    await waitFor(tester, () => status(tester).contains('状态 0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated path labels do not become disk source previews', (
    tester,
  ) async {
    final label = p.join(project.path, 'main.lua').replaceAll(r'\', '/');
    await open(
      tester,
      'local generated = assert(load("local hidden = 42\\nprint(hidden)", '
      '${jsonEncode(label)}))\ngenerated()\n',
    );
    await press(tester, 'lua-debug-start');
    await waitFor(tester, () => status(tester).contains('第 1 行'));
    await press(tester, 'lua-debug-into');
    await waitFor(tester, () => status(tester).contains('第 2 行'));
    await press(tester, 'lua-debug-into');
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('lua-debug-source-unavailable'))
          .evaluate()
          .isNotEmpty,
    );
    expect(find.byKey(const ValueKey('lua-debug-breakpoint-1')), findsNothing);
    final parentFrame = find.byType(ListTile).last;
    await tester.ensureVisible(parentFrame);
    await tester.tap(parentFrame);
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('lua-debug-breakpoint-1'))
          .evaluate()
          .isNotEmpty,
    );
    expect(
      find.byKey(const ValueKey('lua-debug-source-unavailable')),
      findsNothing,
    );
    await press(tester, 'lua-debug-stop');
    await waitFor(tester, () => status(tester).contains('状态 130'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing frame source clears the previous preview and breakpoint buttons',
    (tester) async {
      final module = File(p.join(project.path, 'module.lua'))
        ..writeAsStringSync('local value = 42\nprint(value)\n');
      await open(
        tester,
        'local module = assert(loadfile("module.lua"))\nmodule()\n',
      );
      await press(tester, 'lua-debug-start');
      await waitFor(tester, () => status(tester).contains('第 1 行'));
      await press(tester, 'lua-debug-into');
      await waitFor(tester, () => status(tester).contains('第 2 行'));
      await tester.runAsync(() => module.delete());
      await press(tester, 'lua-debug-into');
      await waitFor(
        tester,
        () =>
            find
                .byKey(const ValueKey('lua-debug-source-unavailable'))
                .evaluate()
                .isNotEmpty &&
            find.textContaining('Exception').evaluate().isNotEmpty,
      );
      expect(status(tester), contains('第 1 行'));
      expect(find.text('module()'), findsNothing);
      expect(
        find.byKey(const ValueKey('lua-debug-breakpoint-1')),
        findsNothing,
      );
      final parentFrame = find.byType(ListTile).last;
      await tester.ensureVisible(parentFrame);
      await tester.tap(parentFrame);
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('lua-debug-breakpoint-1'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('module()'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lua-debug-source-unavailable')),
        findsNothing,
      );
      await press(tester, 'lua-debug-stop');
      await waitFor(tester, () => status(tester).contains('状态 130'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing native debugger is an actual failure with no paused result',
    (tester) async {
      await open(
        tester,
        'print(42)',
        library: p.join(project.path, 'missing-library'),
      );
      await press(tester, 'lua-debug-start');
      await waitFor(
        tester,
        () => find
            .textContaining('Failed to load dynamic library')
            .evaluate()
            .isNotEmpty,
      );
      expect(status(tester), '尚未启动');
      expect(find.textContaining('已暂停'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
