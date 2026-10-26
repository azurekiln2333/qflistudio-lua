import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:qfli_lua/main.dart' as product;
import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/pages/home_page.dart';
import 'package:qfli_studio_core/services/app_paths.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/services/task_activity_service.dart';
import 'package:qfli_studio_core/splash_screen.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('qflistudio/platform');
  late Directory storage;
  late PathProviderPlatform previousPaths;
  late StudioProfile? previousProfile;

  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('qfli_startup_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _StartupPaths(storage.path);
    await AppPaths.storageDirectory();
    await AppPaths.projectsRoot(create: true);
    await TaskActivityService.instance.initialize();
  });

  setUp(() {
    previousProfile = StudioProfile.current;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    StudioProfile.current = previousProfile;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    await storage.delete(recursive: true);
  });

  testWidgets(
    'HarmonyOS keeps its native splash until home is ready to render',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
      final progress = <double>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'startupProgress');
        final arguments = call.arguments as Map;
        progress.add((arguments['progress'] as num).toDouble());
        return null;
      });

      product.main();
      expect(binding.sendFramesToEngine, isFalse);
      await tester.pump();
      final app = tester.widget<QfliApp>(find.byType(QfliApp));
      expect(app.ready!.value, isFalse);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);

      // The first internal frame must not remove the native loading surface.
      await tester.pump(const Duration(milliseconds: 160));
      for (var attempt = 0; attempt < 200 && !app.ready!.value; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(app.ready!.value, isTrue);
      expect(find.byType(HomePage), findsOneWidget);
      expect(binding.sendFramesToEngine, isFalse);
      expect(progress, [1 / 3, 2 / 3, 1.0]);

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      await tester.pump();
      expect(binding.sendFramesToEngine, isTrue);
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      app.store.dispose();
      app.auth.dispose();
      app.settings!.dispose();
      (app.ready! as ValueNotifier<bool>).dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _StartupPaths extends PathProviderPlatform {
  _StartupPaths(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getExternalStoragePath() async => path;
}
