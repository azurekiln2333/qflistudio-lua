import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

void main() {
  testWidgets(
    'editor tools save current Lua, report errors, and compile runnable bytecode',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = StudioProfile.current;
      StudioProfile.current = luaProfile;
      final directory = Directory.systemTemp.createTempSync('qfli_lua_editor_');
      final source = File(p.join(directory.path, 'main.lua'));
      source.writeAsStringSync('print("old")');
      final project = Project.create(
        name: 'Lua',
        path: directory.path,
        language: 'Lua',
      );
      final store = ProjectStore(
        storageFile: File(p.join(directory.path, 'projects.json')),
      );
      final auth = AuthStore();
      final settings = SettingsStore(
        storageFile: File(p.join(directory.path, 'settings.json')),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        StudioProfile.current = previous;
        store.dispose();
        auth.dispose();
        settings.dispose();
        directory.deleteSync(recursive: true);
      });

      Future<void> waitFor(Finder finder) async {
        for (var attempt = 0; attempt < 100 && !tester.any(finder); attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        expect(finder, findsOneWidget);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: EditorPage(
            project: project,
            auth: auth,
            store: store,
            settings: settings,
          ),
        ),
      );
      await tester.tap(find.byTooltip('打开文件树'));
      await tester.pumpAndSettle();
      final explorer = tester.widget<FileExplorer>(find.byType(FileExplorer));
      final editor = explorer.editor;
      await tester.runAsync(() => editor.openPath(source.path));
      await tester.pumpAndSettle();
      Scaffold.of(tester.element(find.byType(FileExplorer))).closeDrawer();
      await tester.pumpAndSettle();

      editor.current!.controller.text = 'local = invalid';
      await tester.pump();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查 Lua 语法'));
      await waitFor(find.text('检查 Lua 语法失败'));
      expect(source.readAsStringSync(), 'local = invalid');
      expect(find.textContaining('main.lua:'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      editor.current!.controller.text = 'print(6 * 7)';
      await tester.pump();
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编译 Lua 字节码'));
      await waitFor(find.text('编译 Lua 字节码完成'));
      expect(find.text('已生成 main.luac'), findsOneWidget);
      final result = await tester.runAsync(
        () => const LuaToolchain().run(
          file: p.join(directory.path, 'main.luac'),
          projectDirectory: directory.path,
        ),
      );
      expect(result!.status, 0, reason: result.error);
      expect(result.output, '42\n');
    },
  );
}
