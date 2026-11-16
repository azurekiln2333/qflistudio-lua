import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:qfli_studio_core/app.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/splash_screen.dart';
import 'package:qfli_studio_core/store/auth_store.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/store/settings_store.dart';

import 'lua_runner.dart';
import 'lua_editor_tools.dart';
import 'lua_content_repository.dart';
import 'lua_terminal_commands.dart';
import 'lua_tools_page.dart';
import 'product_code_analyzer.dart';
import 'lua_studio_debugger.dart';

/// 本 App 的产品名。窗口标题、任务切换器和应用内顶栏都读它。
const String _appTitle = StudioProductCatalog.script;

/// Lua 版档位：同一套内核 UI，收窄成只服务 Lua。
///
/// 单独提出来是为了让测试能直接断言档位，而不必为了一个常量去跑 `main()`。
const StudioProfile luaProfile = StudioProfile(
  id: 'lua',
  appTitle: _appTitle,
  templates: [
    ProjectTemplate.empty,
    ProjectTemplate.lua,
    ProjectTemplate.javascript,
    ProjectTemplate.typescript,
    ProjectTemplate.shell,
  ],
  isOffline: true,
  productKey: StudioProductCatalog.scriptKey,
  showHomeTabs: false,
  runtimeKind: 'lua-5.4-quickjs-typescript',
  runtimeStatus: 'available',
  supportedFileExtensions: ['.lua', '.luac', '.js', '.mjs', '.ts', '.sh'],
  runner: LuaProgramRunner(),
  codeAnalyzer: ProductCodeAnalyzer(),
  debugger: LuaStudioDebugger(),
  contentRepositoryFactory: LuaContentRepository.bundled,
  terminalCommandDelegate: luaTerminalCommandDelegate,
  toolsTabBuilder: buildLuaToolsTab,
  editorFileTools: LuaEditorTools.tools,
  // main.lua 排在默认入口表前面，保证本版一定先命中它。
  entryFileNames: [
    'main.lua',
    'src/main.lua',
    'main.luac',
    'src/main.luac',
    'main.js',
    'src/main.js',
    'main.ts',
    'src/main.ts',
    'main.sh',
    'src/main.sh',
  ],
);

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // 鸿蒙端由原生启动页（图标 + 进度条）遮住引擎初始化；推迟首帧，
  // 等首页真正布局完成再提交，原生遮罩才会在 onFirstFrame 时淡出。
  final nativeStartup = !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;
  if (nativeStartup) binding.deferFirstFrame();

  // 在 runApp 之前定档。
  StudioProfile.current = luaProfile;

  final store = ProjectStore();
  final auth = AuthStore();
  final settings = SettingsStore();
  final ready = ValueNotifier<bool>(false);
  runApp(QfliApp(store: store, auth: auth, settings: settings, ready: ready));

  const platformChannel = MethodChannel('qflistudio/platform');
  Future<void> reportProgress(double progress) async {
    try {
      await platformChannel.invokeMethod<void>('startupProgress', {
        'progress': progress,
      });
    } on PlatformException catch (error) {
      debugPrint('Startup progress unavailable: ${error.code}');
    } on MissingPluginException {
      // 其他平台壳没有原生进度条，忽略即可。
    }
  }

  Future<void> completeStartup() async {
    try {
      final minimumDisplay = nativeStartup
          ? Future<void>.delayed(const Duration(milliseconds: 1100))
          : Future<void>.value();
      if (nativeStartup) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
      await AppBootstrap.run(
        store: store,
        auth: auth,
        settings: settings,
        ready: ready,
        onProgress: nativeStartup
            ? (progress) => unawaited(reportProgress(progress))
            : null,
      );
      await Future.wait([
        minimumDisplay,
        if (nativeStartup)
          Future<void>.delayed(const Duration(milliseconds: 320)),
      ]);
      // 首页 build + layout 完成后再放行首帧。
      if (nativeStartup) await binding.endOfFrame;
    } finally {
      if (nativeStartup) binding.allowFirstFrame();
    }
  }

  // 首帧（被推迟时是首个内部帧）之后再做磁盘/插件初始化，避免与首帧构建争用主 isolate。
  binding.addPostFrameCallback((_) {
    unawaited(completeStartup());
  });
}
