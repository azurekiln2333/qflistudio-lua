import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 离线平台的源码/清单回归测试。
///
/// 这些断言保护的是"这个 App 是纯离线产品"这一产品约束，而不只是某个实现细节：
/// 权限清单里不能再出现网络权限、Ability 不能再声明账号 client_id、页面路由表
/// 不能再注册远程协议页，并且平台通道里 `openAgreement` / `openUrl` 必须显式
/// 返回 OFFLINE_ONLY 而不是去做浏览器/网络操作。
///
/// ArkTS 的类型检查由最终的 HAP 构建负责；这里检查的是**清单与接线契约**，
/// 也就是那种改错了不会编译报错、但会把网络能力悄悄带回来的地方。
void main() {
  final ohos = Directory(p.join('ohos', 'entry', 'src', 'main'));

  String read(String relative) {
    final file = File(p.join(ohos.path, relative));
    expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
    return file.readAsStringSync();
  }

  /// JSON5 子集归一化：去行注释、块注释与尾逗号，然后按标准 JSON 解析。
  Object? parseJson5(String source) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < source.length) {
      if (source.startsWith('//', index)) {
        final end = source.indexOf('\n', index);
        index = end < 0 ? source.length : end;
        continue;
      }
      if (source.startsWith('/*', index)) {
        final end = source.indexOf('*/', index);
        index = end < 0 ? source.length : end + 2;
        continue;
      }
      buffer.write(source[index]);
      index++;
    }
    // 尾逗号：`}` 或 `]` 之前多余的逗号。
    // 注意 replaceAll 不做分组替换，必须用 replaceAllMapped。
    final withoutTrailing = buffer.toString().replaceAllMapped(
      RegExp(r',(\s*[}\]])'),
      (match) => match.group(1) as String,
    );
    return jsonDecode(withoutTrailing);
  }

  group('module.json5 清单', () {
    late Map<String, Object?> module;

    setUp(() {
      final document = parseJson5(read('module.json5'))! as Map;
      module = (document['module'] as Map).cast<String, Object?>();
    });

    test('只申请本地能力权限，绝不申请网络权限', () {
      final permissions = (module['requestPermissions'] as List)
          .map((entry) => (entry as Map)['name'] as String)
          .toList();

      // 精确断言整个权限集合：将来任何新增权限都必须显式改这个测试。
      expect(permissions, ['ohos.permission.READ_PASTEBOARD']);
      expect(
        permissions.where((name) => name == 'ohos.permission.INTERNET'),
        isEmpty,
        reason: '离线产品不得声明 INTERNET 权限',
      );
      expect(permissions.where((name) => name.contains('NETWORK')), isEmpty);
    });

    test('粘贴板权限保留完整的 reason 与 usedScene', () {
      final pasteboard = (module['requestPermissions'] as List)
          .cast<Map>()
          .singleWhere(
            (entry) => entry['name'] == 'ohos.permission.READ_PASTEBOARD',
          );
      expect(pasteboard['reason'], r'$string:pasteboard_reason');
      final scene = (pasteboard['usedScene'] as Map);
      expect(scene['abilities'], ['EntryAbility']);
      expect(scene['when'], 'inuse');
    });

    test('EntryAbility 不再声明账号 client_id 元数据', () {
      final ability = (module['abilities'] as List).cast<Map>().single;
      expect(ability['name'], 'EntryAbility');
      expect(ability['srcEntry'], './ets/entryability/EntryAbility.ets');
      // 离线版不接 Account Kit，因此没有 metadata，也没有占位 client_id。
      expect(ability.containsKey('metadata'), isFalse);
      expect(
        jsonEncode(ability).contains('REPLACE_WITH_AGC_CLIENT_ID'),
        isFalse,
      );
    });

    test('保留启动图标、启动底色与桌面入口', () {
      final ability = (module['abilities'] as List).cast<Map>().single;
      expect(ability['startWindowIcon'], r'$media:icon');
      expect(
        ability['startWindowBackground'],
        r'$color:start_window_background',
      );
      expect(ability['exported'], isTrue);
      final skills = (ability['skills'] as List).cast<Map>();
      final entities = (skills.single['entities'] as List);
      expect(entities, contains('entity.system.home'));
      expect(module['mainElement'], 'EntryAbility');
    });
  });

  group('main_pages.json 路由表', () {
    test('只注册本地首页，不再注册远程协议页', () {
      final document = parseJson5(
        read('resources/base/profile/main_pages.json'),
      )!;
      final pages = ((document as Map)['src'] as List).cast<String>();
      expect(pages, ['pages/Index']);
      expect(pages.where((page) => page.contains('AgreementReader')), isEmpty);
    });

    test('平台入口不引用远程协议页', () {
      // 本地工作区可能保留未跟踪的旧协议页；提交后的干净检出可以没有它。
      // 离线契约只要求路由未注册、已接线的平台源码不再引用该页。
      final entries = Directory(p.join(ohos.path, 'ets'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.ets'));
      for (final file in entries) {
        if (p.basename(file.path) == 'AgreementReader.ets') continue;
        expect(
          file.readAsStringSync().contains('AgreementReader'),
          isFalse,
          reason: '${p.basename(file.path)} 不应再引用 AgreementReader 路由',
        );
      }
    });
  });

  group('EntryAbility.ets 平台通道', () {
    late String source;

    setUp(() {
      source = read('ets/entryability/EntryAbility.ets');
    });

    /// 取出 `call.method === '<name>'` 分支的完整代码块。
    ///
    /// 分支体里可能有嵌套的 `if/else`，所以不能按第一个 `else` 截断，
    /// 而是从锚点后的 `{` 开始做花括号配平（同时跳过字符串字面量）。
    String branch(String method) {
      final anchor = "call.method === '$method'";
      final start = source.indexOf(anchor);
      expect(start, greaterThanOrEqualTo(0), reason: '缺少 $method 分支');
      final open = source.indexOf('{', start + anchor.length);
      expect(open, greaterThanOrEqualTo(0), reason: '$method 分支缺少函数体');
      var depth = 0;
      String? quote;
      for (var i = open; i < source.length; i++) {
        final char = source[i];
        if (quote != null) {
          if (char == r'\') {
            i++;
          } else if (char == quote) {
            quote = null;
          }
          continue;
        }
        if (char == "'" || char == '"') {
          quote = char;
          continue;
        }
        if (char == '{') {
          depth++;
        } else if (char == '}') {
          depth--;
          if (depth == 0) return source.substring(open, i + 1);
        }
      }
      fail('$method 分支花括号不配平');
    }

    test('不再引入 Account Kit 或华为登录通道', () {
      expect(source.contains('@kit.AccountKit'), isFalse);
      expect(source.contains('authentication.'), isFalse);
      expect(source.contains('HuaweiID'), isFalse);
      expect(source.contains('huawei_account'), isFalse);
      expect(source.contains('CHANNEL_HUAWEI'), isFalse);
    });

    test('不再注册可打开浏览器或远程页面', () {
      // router.pushUrl 会进内嵌 Web 页；startAbility 会拉起系统浏览器。
      expect(source.contains('router.pushUrl'), isFalse);
      expect(source.contains('ohos.want.action.viewData'), isFalse);
      expect(RegExp(r'\bstartAbility\s*\(').hasMatch(source), isFalse);
      expect(source.contains('Web('), isFalse);
      // 通道里不应出现任何 http(s) 地址。
      expect(RegExp(r'https?://').hasMatch(source), isFalse);
    });

    test('openAgreement 与 openUrl 显式返回 OFFLINE_ONLY', () {
      for (final method in ['openAgreement', 'openUrl']) {
        final body = branch(method);
        expect(
          body.contains('OFFLINE_ONLY_CODE'),
          isTrue,
          reason: '$method 必须返回 OFFLINE_ONLY 错误码',
        );
        expect(
          RegExp(r'result\.error\(\s*OFFLINE_ONLY_CODE').hasMatch(body),
          isTrue,
          reason: '$method 必须通过 result.error 拒绝',
        );
        // 拒绝路径里不能夹带成功或浏览器调用。
        expect(body.contains('result.success'), isFalse);
        expect(RegExp(r'\bstartAbility\s*\(').hasMatch(body), isFalse);
        expect(body.contains('pushUrl'), isFalse);
      }
    });

    test('OFFLINE_ONLY 错误码与消息是明确的离线说明', () {
      expect(
        source.contains("const OFFLINE_ONLY_CODE = 'OFFLINE_ONLY';"),
        isTrue,
      );
      final message = RegExp(
        r"const OFFLINE_ONLY_MESSAGE = '([^']+)';",
      ).firstMatch(source);
      expect(message, isNotNull);
      expect(message!.group(1)!.contains('离线'), isTrue);
    });

    test('保留启动进度通道契约', () {
      final body = branch('startupProgress');
      expect(body.contains("call.argument('progress')"), isTrue);
      expect(body.contains('Number.isFinite(progress)'), isTrue);
      expect(body.contains('EVENT_STARTUP_PROGRESS'), isTrue);
      expect(body.contains('Math.max(0, Math.min(1, progress))'), isTrue);
      expect(body.contains("'INVALID_PROGRESS'"), isTrue);
      expect(body.contains('result.success(null)'), isTrue);
    });

    test('保留深色/浅色窗口底色与既有启动钩子', () {
      expect(source.contains('setWindowBackgroundColor'), isTrue);
      expect(source.contains('#FF111418'), isTrue);
      expect(source.contains('#FFF8F9FF'), isTrue);
      expect(source.contains('COLOR_MODE_DARK'), isTrue);
      expect(source.contains('super.onWindowStageCreate(windowStage)'), isTrue);
      expect(
        source.contains('super.configureFlutterEngine(flutterEngine)'),
        isTrue,
      );
      expect(source.contains('GeneratedPluginRegistrant.registerWith'), isTrue);
    });

    test('保留本地能力：文件选择与系统分享', () {
      expect(source.contains("./PickerBridge'"), isTrue);
      expect(source.contains('isPickerMethod(call.method)'), isTrue);
      expect(
        source.contains('handlePickerCall(abilityContext, call, result)'),
        isTrue,
      );
      final share = branch('shareText');
      expect(share.contains('systemShare.SharedData'), isTrue);
      expect(share.contains('general.plain-text'), isTrue);
      expect(
        share.contains('controller.show(abilityContext, options)'),
        isTrue,
      );
    });

    test('未识别的方法仍然 notImplemented', () {
      expect(source.contains('result.notImplemented()'), isTrue);
    });
  });
}
