import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/file_explorer.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/editor/retained_editor_host.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/task_activity_service.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';
import 'package:qfli_studio_core/workspace/saved_workspace.dart';
import 'package:qfli_studio_core/workspace/workspace_store.dart';
// Inspect the real editor's selection rather than a parallel session model.
// ignore: depend_on_referenced_packages
import 'package:re_editor/re_editor.dart';

const _name = 'Lua offline workbench';
const _primarySource =
    '-- primary project\n'
    'local owner = "primary"\n'
    'local value = 1\n'
    'print(owner, value)\n';
const _secondarySource =
    '-- secondary project\n'
    'local owner = "secondary"\n'
    'local value = 2\n'
    'print(owner, value)\n';
const _editedSource =
    '-- secondary project, edited in the named workspace\n'
    'local owner = "secondary"\n'
    'local value = 42\n'
    'print(owner, value)\n';
const _nestedSource = 'return { nested = true }\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  late PathProviderPlatform previousPaths;
  StudioProfile? previousProfile;

  setUpAll(() async {
    fixture = await _Fixture.create();
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPaths(fixture.directory.path);
    // Resolve cached services outside widget fake time, before Home loads the
    // singleton workspace store into this test's isolated filesystem.
    expect(await AppPaths.storageDirectory(), fixture.directory.path);
    await TaskActivityService.instance.initialize();
    await WorkspaceStore.instance.load();
  });

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = luaProfile;
  });
  tearDown(() => StudioProfile.current = previousProfile);
  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    fixture.disposeStores();
    await fixture.directory.delete(recursive: true);
  });

  testWidgets(
    'actual Lua Home preserves a named workspace live and after app reconstruction',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => fixture.unmountAndDrain(tester));
      expect(StudioProfile.current, same(luaProfile));
      expect(luaProfile.productKey, StudioProductCatalog.scriptKey);
      expect(luaProfile.offlineOnly, isTrue);
      expect(fixture.settings.autoSave, isFalse);

      await fixture.mountHome(tester);
      expect(find.text('云端项目'), findsNothing);
      await tester.tap(find.text(fixture.primary.name).hitTestable());
      await _until(
        tester,
        () => fixture.editor(tester)?.files.length == 1,
        'The actual Lua Home project did not restore its primary document.',
      );
      await fixture.showTree(tester);

      // Save through the real FileExplorer dialog under the unmodified Lua
      // profile. The legacy membership-only dialog cannot satisfy this step.
      final workspaceAction = find.descendant(
        of: find.byType(FileExplorer).hitTestable(),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '工作区项目',
        ),
      );
      await _until(
        tester,
        () => workspaceAction.hitTestable().evaluate().isNotEmpty,
        'The Lua workspace settings button did not become interactive.',
      );
      await tester.tap(workspaceAction.hitTestable());
      final nameField = find.byKey(const ValueKey('workspace-name-field'));
      await _until(
        tester,
        () => nameField.hitTestable().evaluate().isNotEmpty,
        'The actual Lua profile did not expose named workspace saving.',
      );
      await tester.pump(const Duration(milliseconds: 300));
      final secondaryChoice = find.byKey(
        ValueKey('workspace-project-${fixture.secondary.id}'),
      );
      expect(tester.widget<CheckboxListTile>(secondaryChoice).value, isFalse);
      await tester.tap(secondaryChoice.hitTestable());
      await tester.enterText(nameField, _name);
      await tester.tap(find.widgetWithText(FilledButton, '保存').hitTestable());
      await _until(
        tester,
        () =>
            WorkspaceStore.instance.workspaces.length == 1 &&
            find.byType(AlertDialog).evaluate().isEmpty &&
            fixture.root(fixture.secondary).evaluate().isNotEmpty,
        'Saving the named Lua workspace did not attach both project roots.',
      );
      final saved = WorkspaceStore.instance.workspaces.single;
      expect(saved.name, _name);
      expect(saved.memberPaths, [fixture.primary.path, fixture.secondary.path]);
      expect(fixture.document(saved).existsSync(), isTrue);
      expect(fixture.page(tester).workspace?.id, saved.id);
      await fixture.drain(tester);
      final standaloneHistory = fixture.history.readAsBytesSync();

      await fixture.expand(tester, fixture.primary);
      await fixture.expand(tester, fixture.secondary);
      await tester.tap(
        fixture.entry(fixture.secondary, 'main.lua').hitTestable(),
      );
      await _until(
        tester,
        () =>
            fixture.editor(tester)?.files.length == 2 &&
            fixture.editor(tester)?.current?.projectRootPath ==
                fixture.secondary.path,
        'The secondary main.lua did not open with its owning project.',
      );
      final editor = fixture.editor(tester)!;
      fixture.expectOwners(editor);
      final secondaryBuffer = editor.current!;
      secondaryBuffer.controller.text = _editedSource;
      editor.files.first.controller.selection =
          const CodeLineSelection.collapsed(index: 1, offset: 3);
      secondaryBuffer.controller.selection = const CodeLineSelection.collapsed(
        index: 2,
        offset: 4,
      );
      await tester.pump();
      expect(secondaryBuffer.dirty, isTrue);
      fixture.expectSourceBytes();

      await tester.tap(find.byTooltip('收起文件树').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await fixture.showTree(tester);
      await fixture.expectExpanded(tester);
      expect(fixture.editor(tester), same(editor));
      expect(editor.current, same(secondaryBuffer));
      expect(secondaryBuffer.controller.text, _editedSource);
      expect(secondaryBuffer.dirty, isTrue);

      // Switch through Home to a separate, real standalone editor. It reads
      // disk while the named workspace retains its unsaved secondary buffer.
      await fixture.minimize(tester);
      await tester.tap(find.text(fixture.secondary.name).hitTestable());
      await _until(
        tester,
        () =>
            fixture.editor(tester)?.current?.path ==
                fixture.source(fixture.secondary).path &&
            !identical(fixture.editor(tester), editor),
        'Home did not open a distinct standalone secondary session.',
      );
      final standalone = fixture.editor(tester)!;
      expect(fixture.page(tester).workspace, isNull);
      expect(standalone.files, hasLength(1));
      expect(standalone.current!.controller.text, _secondarySource);
      expect(standalone.current!.dirty, isFalse);
      final retained = tester
          .widget<RetainedEditorHost>(find.byType(RetainedEditorHost))
          .controller;
      expect(retained.sessionInfos, hasLength(2));
      expect(
        retained.sessionInfos.where(
          (session) => session.workspace?.id == saved.id,
        ),
        hasLength(1),
      );
      await fixture.minimize(tester);
      await fixture.openWorkspace(tester);
      await _until(
        tester,
        () => identical(fixture.editor(tester), editor),
        'The saved Home workspace card did not resume its retained editor.',
      );
      fixture.expectOwners(editor);
      expect(editor.current, same(secondaryBuffer));
      expect(secondaryBuffer.controller.text, _editedSource);
      expect(secondaryBuffer.dirty, isTrue);
      expect(editor.files.first.controller.selection.baseIndex, 1);
      expect(editor.files.first.controller.selection.baseOffset, 3);
      expect(secondaryBuffer.controller.selection.baseIndex, 2);
      expect(secondaryBuffer.controller.selection.baseOffset, 4);
      await fixture.showTree(tester);
      await fixture.expectExpanded(tester);
      fixture.expectSourceBytes();

      // Preserve a collapsed root as well as its expanded child directory.
      await tester.tap(
        fixture.entry(fixture.primary, fixture.primary.name).hitTestable(),
      );
      await _until(
        tester,
        () => fixture.entry(fixture.primary, 'nested').evaluate().isEmpty,
        'The primary workspace root did not collapse.',
      );
      expect(fixture.entry(fixture.secondary, 'detail.lua'), findsOneWidget);

      // Workspace JSON contains identities/cursors/tree state, not dirty text.
      // Save with the actual editor menu before destroying QfliApp.
      await tester.tap(find.byTooltip('更多').hitTestable());
      final saveAction = find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == 'save',
      );
      await _until(
        tester,
        () => saveAction.hitTestable().evaluate().isNotEmpty,
        'The real editor save action did not become interactive.',
      );
      await tester.tap(saveAction.hitTestable());
      await _until(
        tester,
        () =>
            !secondaryBuffer.dirty &&
            fixture.source(fixture.secondary).readAsStringSync() ==
                _editedSource,
        'The actual editor did not flush the edited secondary source.',
      );
      fixture.expectSourceBytes(edited: true);

      // This disposes QfliApp's retained controller and both live editors.
      await fixture.unmountAndDrain(tester);
      expect(find.byType(EditorPage), findsNothing);
      final latest = WorkspaceStore.instance.byId(saved.id)!;
      fixture.expectSession(latest.session);
      expect(
        fixture.history.readAsBytesSync(),
        orderedEquals(standaloneHistory),
        reason: 'Named workspace state must not overwrite standalone history.',
      );
      fixture.expectSourceBytes(edited: true);

      await tester.runAsync(() async {
        await WorkspaceStore.instance.load(force: true);
        await fixture.recreateStores();
      });
      fixture.expectSession(WorkspaceStore.instance.byId(saved.id)!.session);
      await fixture.mountHome(tester);
      await fixture.openWorkspace(tester);
      await _until(
        tester,
        () =>
            fixture.editor(tester)?.files.length == 2 &&
            fixture.editor(tester)?.current?.projectRootPath ==
                fixture.secondary.path,
        'The actual Lua Home card did not reconstruct the saved session.',
      );
      final restored = fixture.editor(tester)!;
      expect(restored, isNot(same(editor)));
      expect(fixture.page(tester).workspace?.id, saved.id);
      fixture.expectOwners(restored);
      expect(restored.files.every((file) => !file.dirty), isTrue);
      expect(restored.files.first.controller.text, _primarySource);
      expect(restored.current!.controller.text, _editedSource);
      expect(restored.files.first.controller.selection.baseIndex, 1);
      expect(restored.files.first.controller.selection.baseOffset, 3);
      expect(restored.current!.controller.selection.baseIndex, 2);
      expect(restored.current!.controller.selection.baseOffset, 4);
      await fixture.showTree(tester);
      await _until(
        tester,
        () =>
            fixture.entry(fixture.primary, 'nested').evaluate().isEmpty &&
            fixture
                .entry(fixture.secondary, 'detail.lua')
                .evaluate()
                .isNotEmpty,
        'The reconstructed workspace did not restore its root expansion states.',
      );
      await tester.tap(
        fixture.entry(fixture.primary, fixture.primary.name).hitTestable(),
      );
      await fixture.expectExpanded(tester);
      fixture.expectSourceBytes(edited: true);
      expect(StudioProfile.current, same(luaProfile));
      expect(tester.takeException(), isNull);
    },
  );
}

class _Fixture {
  _Fixture(this.directory, this.primary, this.secondary);

  final Directory directory;
  final Project primary;
  final Project secondary;
  late ProjectStore store;
  late AuthStore auth;
  late SettingsStore settings;

  File get registry => File(p.join(directory.path, 'projects.json'));
  File get history => File(p.join(primary.path, 'history.json'));
  File source(Project project) => File(p.join(project.path, 'main.lua'));
  File document(SavedWorkspace workspace) =>
      File(p.join(directory.path, 'workspaces', '${workspace.id}.json'));
  Finder root(Project project) =>
      find.byKey(ValueKey('workspace-root-${project.path}')).hitTestable();
  Finder entry(Project project, String name) =>
      find.descendant(of: root(project), matching: find.text(name));

  static Future<_Fixture> create() async {
    final directory = await Directory.systemTemp.createTemp('lua_named_ws_');
    Project project(String name, String folder) => Project.create(
      name: name,
      path: p.join(directory.path, folder),
      language: 'Lua',
      type: 'lua',
    );
    final fixture = _Fixture(
      directory,
      project('Primary Lua', 'primary'),
      project('Secondary Lua', 'secondary'),
    );
    for (final project in [fixture.primary, fixture.secondary]) {
      await Directory(p.join(project.path, 'nested')).create(recursive: true);
      await File(
        p.join(project.path, 'nested', 'detail.lua'),
      ).writeAsString(_nestedSource);
      await ProjectHistory.save(
        project.path,
        cursors: const {},
        openFiles: const ['main.lua'],
        activeFile: 'main.lua',
      );
    }
    await fixture.source(fixture.primary).writeAsString(_primarySource);
    await fixture.source(fixture.secondary).writeAsString(_secondarySource);
    await fixture.registry.writeAsString(
      jsonEncode({
        'projects': [fixture.primary.toJson(), fixture.secondary.toJson()],
      }),
    );
    await fixture._createStores();
    return fixture;
  }

  Future<void> _createStores() async {
    store = ProjectStore(storageFile: registry);
    auth = AuthStore(storageFile: File(p.join(directory.path, 'auth.json')));
    settings = SettingsStore(
      storageFile: File(p.join(directory.path, 'settings.json')),
    );
    await store.load();
    await auth.load();
    await settings.load();
  }

  Future<void> recreateStores() async {
    disposeStores();
    await _createStores();
  }

  void disposeStores() {
    store.dispose();
    auth.dispose();
    settings.dispose();
  }

  Future<void> mountHome(WidgetTester tester) async {
    await tester.pumpWidget(
      QfliApp(store: store, auth: auth, settings: settings),
    );
    await _until(
      tester,
      () => find.text(primary.name).hitTestable().evaluate().isNotEmpty,
      'The actual Lua Home did not show its registered project.',
    );
  }

  EditorController? editor(WidgetTester tester) {
    final bar = find.byType(EditorProblemsBar).hitTestable();
    if (bar.evaluate().isEmpty) return null;
    return tester.widget<EditorProblemsBar>(bar).analysis.editor;
  }

  EditorPage page(WidgetTester tester) =>
      tester.widget<EditorPage>(find.byType(EditorPage).hitTestable());

  Future<void> openWorkspace(WidgetTester tester) async {
    final workspaceTab = find.widgetWithText(Tab, '工作区').hitTestable();
    expect(workspaceTab, findsOneWidget);
    await tester.tap(workspaceTab);
    await _until(
      tester,
      () => find.text(_name).hitTestable().evaluate().isNotEmpty,
      'The actual Lua Home workspace scope did not list the saved document.',
    );
    await tester.tap(find.text(_name).hitTestable());
  }

  Future<void> minimize(WidgetTester tester) async {
    await tester.tap(find.byTooltip('暂时收起编辑器').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _until(
      tester,
      () => find.byType(EditorProblemsBar).hitTestable().evaluate().isEmpty,
      'The retained editor did not reveal Home.',
    );
  }

  Future<void> showTree(WidgetTester tester) async {
    await _until(
      tester,
      () =>
          find.byTooltip('打开文件树').hitTestable().evaluate().isNotEmpty ||
          find.byTooltip('收起文件树').hitTestable().evaluate().isNotEmpty,
      'The editor tree toggle did not become interactive.',
    );
    final closed = find.byTooltip('打开文件树').hitTestable();
    if (closed.evaluate().isNotEmpty) await tester.tap(closed);
    // Start AnimatedAlign before advancing fake time, otherwise the settings
    // button can still be clipped although the root's center is visible.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _until(
      tester,
      () => root(primary).evaluate().isNotEmpty,
      'The primary Lua project tree did not open.',
    );
  }

  Future<void> expand(WidgetTester tester, Project project) async {
    final folder = entry(project, 'nested').hitTestable();
    await _until(
      tester,
      () => folder.evaluate().isNotEmpty,
      'The ${project.name} folder did not load.',
    );
    await tester.tap(folder);
    await _until(
      tester,
      () => entry(project, 'detail.lua').evaluate().isNotEmpty,
      'The ${project.name} folder did not expand.',
    );
  }

  Future<void> expectExpanded(WidgetTester tester) => _until(
    tester,
    () => [
      primary,
      secondary,
    ].every((project) => entry(project, 'detail.lua').evaluate().isNotEmpty),
    'The named workspace did not preserve both expanded nested directories.',
  );

  Future<void> unmountAndDrain(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await drain(tester);
  }

  Future<void> drain(WidgetTester tester) async {
    var done = false;
    final pending = Future.wait([
      WorkspaceStore.instance.settle(),
      ProjectHistory.load(primary.path),
      ProjectHistory.load(secondary.path),
      store.refresh(),
    ]);
    pending.then(
      (_) => done = true,
      onError: (Object _, StackTrace _) => done = true,
    );
    await _until(
      tester,
      () => done,
      'Queued Lua workspace/history writes did not drain.',
    );
    await pending;
  }

  void expectOwners(EditorController editor) {
    expect(editor.files.map((file) => file.path), [
      source(primary).path,
      source(secondary).path,
    ]);
    expect(editor.files.map((file) => file.projectRootPath), [
      primary.path,
      secondary.path,
    ]);
    expect(editor.files.map((file) => file.ownerProjectName), [
      primary.name,
      secondary.name,
    ]);
    expect(editor.files.every((file) => file.projectType == 'lua'), isTrue);
    expect(editor.current?.projectRootPath, secondary.path);
  }

  void expectSession(WorkspaceSessionSnapshot session) {
    expect(session.primaryPath, primary.path);
    expect(session.documents.map((document) => document.projectPath), [
      primary.path,
      secondary.path,
    ]);
    expect(session.documents.map((document) => document.relativePath), [
      'main.lua',
      'main.lua',
    ]);
    expect(session.documents.map((document) => document.isActive), [
      false,
      true,
    ]);
    expect(session.documents.first.cursor.baseIndex, 1);
    expect(session.documents.first.cursor.baseOffset, 3);
    expect(session.documents.last.cursor.baseIndex, 2);
    expect(session.documents.last.cursor.baseOffset, 4);
    for (final project in [primary, secondary]) {
      expect(session.expandedDirs[project.path], contains('nested'));
    }
    expect(session.rootExpanded[primary.path], isFalse);
    expect(session.rootExpanded[secondary.path], isTrue);
  }

  void expectSourceBytes({bool edited = false}) {
    expect(source(primary).readAsBytesSync(), utf8.encode(_primarySource));
    expect(
      source(secondary).readAsBytesSync(),
      utf8.encode(edited ? _editedSource : _secondarySource),
    );
    for (final project in [primary, secondary]) {
      expect(
        File(p.join(project.path, 'nested', 'detail.lua')).readAsBytesSync(),
        utf8.encode(_nestedSource),
      );
    }
  }
}

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

Future<void> _until(
  WidgetTester tester,
  bool Function() complete,
  String reason,
) async {
  for (var attempt = 0; attempt < 240; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (complete()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(complete(), isTrue, reason: reason);
}
