import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/content/asset_content_repository.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/models/tutorial.dart';
import 'package:qfli_studio_core/pages/local_content_pages.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/services/project_config.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/task_activity_service.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/theme/app_theme.dart';
import 'package:qfli_studio_core/widgets/code_snippet.dart';

const _example = ExampleCode(
  id: 'workflow',
  type: 'lua',
  title: 'Lua: code sample',
  summary: 'Import an editable Lua example.',
  code: 'print("original")\n',
  output: 'original',
);
const _capture = bool.fromEnvironment('CONTENT_SCREENSHOTS');
const _boundaryKey = ValueKey('content-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  late Directory testDirectory;
  late PathProviderPlatform previousPaths;
  late StudioProfile? previousProfile;
  late ProjectStore store;
  late AuthStore auth;
  late SettingsStore settings;
  late AssetContentRepository repository;

  setUpAll(() async {
    storage = Directory.systemTemp.createTempSync('qfli_content_workflows_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPaths(storage.path);
    await AppPaths.storageDirectory();
    await AppPaths.projectsRoot(create: true);
    await TaskActivityService.instance.initialize();
    repository = AssetContentRepository();
    await repository.load();
    if (_capture) {
      final fonts = [
        ('ContentTestUI', File('C:/Windows/Fonts/msyh.ttc')),
        (
          'packages/qfli_studio_core/RobotoMono',
          File(
            '../qfli_studio_core/assets/fonts/roboto_mono/static/RobotoMono-Regular.ttf',
          ),
        ),
        (
          'MaterialIcons',
          File(
            'D:/ProgramFiles/flutter_ohos/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ),
      ];
      for (final (family, file) in fonts) {
        if (file.existsSync()) {
          await (FontLoader(family)..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              ))
              .load();
        }
      }
    }
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    await storage.delete(recursive: true);
  });

  setUp(() async {
    previousProfile = StudioProfile.current;
    StudioProfile.current = luaProfile;
    testDirectory = storage.createTempSync('case_');
    store = ProjectStore(
      storageFile: File(p.join(testDirectory.path, 'registry.json')),
    );
    auth = AuthStore(
      storageFile: File(p.join(testDirectory.path, 'auth.json')),
    );
    settings = SettingsStore(
      storageFile: File(p.join(testDirectory.path, 'settings.json')),
    );
    await store.load();
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    store.dispose();
    auth.dispose();
    settings.dispose();
  });

  Future<void> waitUntil(WidgetTester tester, bool Function() ready) async {
    for (var attempt = 0; attempt < 150 && !ready(); attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      ready(),
      isTrue,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .join('\n'),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> mount(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // The writes started in test time, so pump their continuations while
      // waitUntil yields to real filesystem I/O. Awaiting them inside runAsync
      // would block the fake-zone callbacks that complete the same queues.
      var drained = false;
      final pending = () async {
        await store.refresh();
        for (final project in store.projects) {
          await ProjectHistory.load(project.path);
        }
      }().whenComplete(() => drained = true);
      await waitUntil(tester, () => drained);
      await pending;
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          supportedLocales: StudioLocalizations.supportedLocales,
          localizationsDelegates: const [
            StudioLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _capture
              ? AppTheme.light.copyWith(
                  textTheme: AppTheme.light.textTheme.apply(
                    fontFamily: 'ContentTestUI',
                  ),
                )
              : AppTheme.light,
          home: page,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  ExampleDetailPage detail() => ExampleDetailPage(
    example: _example,
    store: store,
    auth: auth,
    settings: settings,
  );

  Future<EditorController> openedEditor(
    WidgetTester tester,
    String name,
  ) async {
    await waitUntil(
      tester,
      () => tester.any(find.byType(EditorPage)) && tester.any(find.text(name)),
    );
    await tester.tap(find.byTooltip('打开文件树'));
    await tester.pumpAndSettle();
    final editor = tester
        .widget<FileExplorer>(find.byType(FileExplorer))
        .editor;
    await waitUntil(
      tester,
      () => editor.current != null && p.basename(editor.current!.path) == name,
    );
    expect(tester.takeException(), isNull);
    return editor;
  }

  Future<Project> existingProject(WidgetTester tester) async {
    final result = await tester.runAsync(
      () => store.createProjectFromExample(
        name: 'Existing project',
        example: _example,
        fileName: 'entry.lua',
        location: testDirectory.path,
      ),
    );
    expect(result!.error, isNull);
    return result.project!;
  }

  Future<void> selectProject(WidgetTester tester, Project project) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(project.name).last);
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!_capture) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/content-screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [const Size(360, 800), const Size(1280, 900)]) {
    final suffix = size.width < 600 ? 'mobile' : 'desktop';
    for (final tutorial in [true, false]) {
      final kind = tutorial ? 'tutorial' : 'example';
      testWidgets(
        '$kind list and details render at $suffix size with real bundled content',
        (tester) async {
          await mount(
            tester,
            tutorial
                ? LocalTutorialsTab(
                    language: 'lua',
                    repository: repository,
                    store: store,
                    auth: auth,
                    settings: settings,
                  )
                : ExampleCodeTab(
                    language: 'lua',
                    repository: repository,
                    store: store,
                    auth: auth,
                    settings: settings,
                  ),
            size: size,
          );
          await waitUntil(tester, () => tester.any(find.byType(ListTile)));
          expect(find.byType(CodeSnippet), findsNothing);
          expect(find.byType(SelectableText), findsNothing);
          expect(find.byKey(const ValueKey('content-query')), findsOneWidget);
          expect(find.byType(Card), findsNothing);
          await screenshot(tester, '${kind}_list_$suffix');
          await tester.tap(find.byType(ListTile).first);
          await tester.pumpAndSettle();
          expect(find.byType(CodeSnippet), findsOneWidget);
          for (final tooltip in ['复制示例代码', '导入编辑器', '导入项目']) {
            expect(find.byTooltip(tooltip), findsOneWidget);
            expect(
              tester
                  .widget<IconButton>(
                    find.ancestor(
                      of: find.byTooltip(tooltip),
                      matching: find.byType(IconButton),
                    ),
                  )
                  .onPressed,
              isNotNull,
            );
          }
          expect(tester.takeException(), isNull);
          await screenshot(tester, '${kind}_detail_$suffix');
          await tester.tap(find.byTooltip('导入项目'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('import-file-name')),
            findsOneWidget,
          );
          await screenshot(tester, '${kind}_import_$suffix');
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets(
    'editor import saves and opens edited code with a custom filename',
    (tester) async {
      await mount(tester, detail());
      await tester.enterText(
        find.byType(TextField),
        'print("edited in details")\n',
      );
      await tester.tap(find.byTooltip('导入编辑器'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'edited.lua',
      );
      await tester.tap(find.text('导入并打开'));
      final editor = await openedEditor(tester, 'edited.lua');
      expect(editor.current!.controller.text, 'print("edited in details")\n');
      expect(
        File(editor.current!.path).readAsStringSync(),
        'print("edited in details")\n',
      );
      expect(store.projects.single.path, editor.project.path);
      expect(p.isWithin(storage.path, editor.current!.path), isTrue);
    },
  );

  testWidgets('new-project import registers the custom entry and opens it', (
    tester,
  ) async {
    await mount(tester, detail());
    await tester.tap(find.byTooltip('导入项目'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-project-name')),
      'New Lua project',
    );
    await tester.enterText(
      find.byKey(const ValueKey('import-file-name')),
      'custom.lua',
    );
    await tester.tap(find.text('导入并打开'));
    final editor = await openedEditor(tester, 'custom.lua');
    final project = store.projects.single;
    expect(project.name, 'New Lua project');
    expect(editor.current!.path, p.join(project.path, 'src', 'custom.lua'));
    expect(editor.current!.controller.text, _example.code);
    expect(RunnerService.findEntry(project.path), editor.current!.path);
    await waitUntil(
      tester,
      () => File(
        p.join(testDirectory.path, 'registry.json'),
      ).readAsStringSync().contains(project.id),
    );
  });

  testWidgets(
    'existing project retains old tabs and selects the imported file',
    (tester) async {
      final project = await existingProject(tester);
      final oldFile = File(p.join(project.path, 'src', 'old.lua'))
        ..writeAsStringSync('print("old")');
      await tester.runAsync(
        () => ProjectHistory.save(
          project.path,
          cursors: {},
          openFiles: ['src/entry.lua', 'src/old.lua'],
          activeFile: 'src/old.lua',
        ),
      );
      final configBefore = File(
        ProjectConfig.configPath(project.path),
      ).readAsStringSync();
      await mount(tester, detail());
      await tester.tap(find.byTooltip('导入项目'));
      await tester.pumpAndSettle();
      await selectProject(tester, project);
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'imported.lua',
      );
      await tester.tap(find.text('导入并打开'));
      final editor = await openedEditor(tester, 'imported.lua');
      expect(editor.files.map((file) => p.basename(file.path)), [
        'entry.lua',
        'old.lua',
        'imported.lua',
      ]);
      expect(editor.current!.controller.text, _example.code);
      expect(oldFile.readAsStringSync(), 'print("old")');
      expect(
        File(ProjectConfig.configPath(project.path)).readAsStringSync(),
        configBefore,
      );
      expect(store.projects, hasLength(1));
    },
  );

  testWidgets('invalid names and cancellation do not write files or navigate', (
    tester,
  ) async {
    await mount(tester, detail());
    final count = storage.listSync(recursive: true).length;
    await tester.tap(find.byTooltip('导入编辑器'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-file-name')),
      '../bad.lua',
    );
    await tester.tap(find.text('导入并打开'));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的文件名，不能包含路径或特殊字符'), findsOneWidget);
    expect(find.byType(EditorPage), findsNothing);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(storage.listSync(recursive: true).length, count);
    expect(store.projects, isEmpty);
    expect(find.byType(ExampleDetailPage), findsOneWidget);
  });

  testWidgets(
    'cancelling replacement preserves the file and allows a corrected import',
    (tester) async {
      final project = await existingProject(tester);
      await mount(tester, detail());
      await tester.tap(find.byTooltip('导入项目'));
      await tester.pumpAndSettle();
      await selectProject(tester, project);
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'entry.lua',
      );
      await tester.tap(find.text('导入并打开'));
      await waitUntil(tester, () => tester.any(find.text('资源已存在')));
      expect(
        File(p.join(project.path, 'src', 'entry.lua')).readAsStringSync(),
        _example.code,
      );
      expect(find.byType(EditorPage), findsNothing);
      await tester.tap(find.text('取消').last);
      await waitUntil(
        tester,
        () =>
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('import-code-confirm')),
                )
                .onPressed !=
            null,
      );
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'retry.lua',
      );
      await tester.tap(find.text('导入并打开'));
      await openedEditor(tester, 'retry.lua');
    },
  );

  testWidgets(
    'confirmed replacement opens the new code and preserves its backup',
    (tester) async {
      final project = await existingProject(tester);
      await mount(tester, detail());
      await tester.enterText(find.byType(TextField), 'print("replacement")');
      await tester.tap(find.byTooltip('导入项目'));
      await tester.pumpAndSettle();
      await selectProject(tester, project);
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'entry.lua',
      );
      await tester.tap(find.text('导入并打开'));
      await waitUntil(tester, () => tester.any(find.text('资源已存在')));
      await tester.tap(find.text('覆盖'));
      final editor = await openedEditor(tester, 'entry.lua');
      expect(editor.current!.controller.text, 'print("replacement")');
      final backups = await tester.runAsync(
        () => FileBackup.listVersions(
          File(editor.current!.path),
          projectName: project.name,
        ),
      );
      expect(backups!.single.file.readAsStringSync(), _example.code);
    },
  );

  testWidgets(
    'write errors keep the import dialog usable and preserve existing files',
    (tester) async {
      final project = await existingProject(tester);
      final sourceDirectory = Directory(p.join(project.path, 'src'));
      sourceDirectory.deleteSync(recursive: true);
      final blockingFile = File(sourceDirectory.path)
        ..writeAsStringSync('preserve');
      await mount(tester, detail());
      await tester.tap(find.byTooltip('导入项目'));
      await tester.pumpAndSettle();
      await selectProject(tester, project);
      await tester.enterText(
        find.byKey(const ValueKey('import-file-name')),
        'extra.lua',
      );
      await tester.tap(find.text('导入并打开'));
      await waitUntil(tester, () => tester.any(find.textContaining('导入失败')));
      expect(find.byType(EditorPage), findsNothing);
      expect(blockingFile.readAsStringSync(), 'preserve');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('import-code-confirm')),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(ExampleDetailPage), findsOneWidget);
    },
  );
}

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
