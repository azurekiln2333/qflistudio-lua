import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/editor/editor_analysis_controller.dart';
import 'package:qfli_studio_core/editor/editor_page.dart';
import 'package:qfli_studio_core/editor/editor_problems_bar.dart';
import 'package:qfli_studio_core/editor/project_history.dart';
import 'package:qfli_studio_core/i18n/studio_localizations.dart';
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/task_activity_service.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storage;
  late PathProviderPlatform previousPaths;
  late StudioProfile? previousProfile;

  setUpAll(() async {
    storage = Directory.systemTemp.createTempSync('qfli_product_editor_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(storage.path);
    previousProfile = StudioProfile.current;
    StudioProfile.current = luaProfile;
    await AppPaths.storageDirectory();
    await AppPaths.projectsRoot(create: true);
    await TaskActivityService.instance.initialize();
  });
  tearDownAll(() async {
    StudioProfile.current = previousProfile;
    PathProviderPlatform.instance = previousPaths;
    await storage.delete(recursive: true);
  });

  for (final (extension, language, broken, corrected) in [
    ('lua', 'Lua', '-- 😀\r\nlocal = 1', '-- 😀\r\nerror("must not execute")'),
    (
      'js',
      'JavaScript',
      '// 😀\r\nconst = 1',
      '// 😀\r\nthrow new Error("must not execute");',
    ),
    (
      'ts',
      'TypeScript',
      '// 😀\r\nconst n: number = ;',
      '// 😀\r\nconst n: number = 42; throw new Error(String(n));',
    ),
    ('sh', 'Shell', '# 😀\r\nif then', '# 😀\r\n: > must-not-exist'),
  ]) {
    testWidgets(
      '$language actual editor checks dirty source, navigates Problems and clears repaired diagnostics',
      (tester) async {
        final root = storage.createTempSync('$extension-');
        final source = File(p.join(root.path, 'main.$extension'))
          ..writeAsStringSync(corrected);
        final saved = source.readAsBytesSync();
        final project = Project.create(
          name: language,
          path: root.path,
          type: extension,
          language: language,
        );
        final store = ProjectStore(
          storageFile: File(p.join(root.path, 'registry.json')),
        );
        final auth = AuthStore(
          storageFile: File(p.join(root.path, 'auth.json')),
        );
        final settings = SettingsStore(
          storageFile: File(p.join(root.path, 'settings.json')),
        );
        await tester.runAsync(store.load);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              StudioLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh'), Locale('en')],
            home: EditorPage(
              project: project,
              store: store,
              auth: auth,
              settings: settings,
              initialOpenPath: source.path,
            ),
          ),
        );
        try {
          EditorAnalysisController? analysis;
          await _wait(tester, () {
            final bars = find.byType(EditorProblemsBar);
            if (bars.evaluate().isEmpty) return false;
            analysis = tester.widget<EditorProblemsBar>(bars.first).analysis;
            return analysis!.editor.current?.path == source.path;
          });
          final currentAnalysis = analysis!;
          final file = currentAnalysis.editor.current!;
          expect(currentAnalysis.analyzer, same(luaProfile.codeAnalyzer));
          file.controller.text = broken;
          await _wait(tester, () => !currentAnalysis.pending);
          expect(currentAnalysis.unavailableReason, isNull);
          expect(currentAnalysis.checked, isTrue);
          expect(currentAnalysis.problems, isNotEmpty);
          expect(file.controller.text, broken);
          expect(file.dirty, isTrue);
          final diagnostic = currentAnalysis.problems.first;
          expect(diagnostic.filePath, source.path);
          expect(
            diagnostic.startOffset,
            greaterThanOrEqualTo(broken.indexOf('\n') + 1),
          );
          expect(diagnostic.endOffset, lessThanOrEqualTo(broken.length));
          expect(file.diagnostics!.problems, isNotEmpty);
          expect(
            file.diagnostics!.gutterSeverity(1),
            CodeDiagnosticSeverity.error,
          );

          await tester.tap(
            find.byKey(const ValueKey('editor-problems-status')),
          );
          await _wait(
            tester,
            () => find.byType(EditorProblemsPanel).evaluate().isNotEmpty,
          );
          final problemRow = find
              .descendant(
                of: find.byType(EditorProblemsPanel),
                matching: find.byType(ListTile),
              )
              .first;
          await tester.ensureVisible(problemRow);
          await tester.tap(problemRow);
          await tester.pump();
          expect(file.controller.selection.baseIndex, 1);

          file.controller.text = corrected;
          expect(currentAnalysis.problems, isEmpty);
          await _wait(tester, () => !currentAnalysis.pending);
          expect(currentAnalysis.checked, isTrue);
          expect(currentAnalysis.unavailableReason, isNull);
          expect(currentAnalysis.problems, isEmpty);
          expect(file.diagnostics!.problems, isEmpty);
          expect(find.text('本地检查未发现问题'), findsWidgets);
          expect(source.readAsBytesSync(), saved);
          expect(
            File(p.join(root.path, 'must-not-exist')).existsSync(),
            isFalse,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          var drained = false;
          final pendingHistory = ProjectHistory.load(root.path).then((_) {
            drained = true;
          });
          await _wait(tester, () => drained);
          await pendingHistory;
          store.dispose();
          auth.dispose();
          settings.dispose();
        }
      },
    );
  }
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  fail('Actual product editor operation did not finish.');
}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}
