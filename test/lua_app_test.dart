import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';

/// Lua 版 App 的接线测试。
///
/// 覆盖的正是「一个语言一个 App」的全部接缝：内核怎么知道该显示哪个模板、
/// 该跑哪个入口文件、以及运行后端有没有正确接管/交回。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory project;
  late StudioProfile? previousProfile;

  setUp(() {
    previousProfile = StudioProfile.current;
    StudioProfile.current = luaProfile;
    project = Directory.systemTemp.createTempSync('qfli_lua_app_test');
  });

  tearDown(() {
    StudioProfile.current = previousProfile;
    if (project.existsSync()) project.deleteSync(recursive: true);
  });

  void write(String relative, String content) {
    final file = File(p.join(project.path, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  group('档位收窄', () {
    test('新建项目放行 Script 产品的脚本模板', () {
      expect(luaProfile.filterTemplates(ProjectTemplate.values), [
        ProjectTemplate.empty,
        ProjectTemplate.lua,
        ProjectTemplate.javascript,
        ProjectTemplate.typescript,
        ProjectTemplate.shell,
      ]);
    });

    test('默认模板是 Lua 而不是空项目', () {
      expect(luaProfile.defaultTemplate, ProjectTemplate.lua);
    });

    test('语言筛选芯片只剩 Lua', () {
      // 首页传给档位的候选本来就不含「空项目」——它不是一门语言。
      const all = ['C++', 'Lua', 'Web', 'Python', 'Java', 'Dart'];
      expect(luaProfile.filterLanguages(all), ['Lua']);
    });

    test('产品名使用 QFLIScript', () {
      expect(luaProfile.appTitle, 'QFLIScript');
    });

    test('档位只使用本地能力', () {
      expect(luaProfile.isOffline, isTrue);
    });
  });

  group('入口文件识别', () {
    test('优先命中 main.lua', () {
      write('main.lua', '// .lua');
      write('other.txt', 'x');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, 'main.lua'),
      );
    });

    test('入口表覆盖了模板自带的入口文件', () {
      // 这是「一个语言一个 App」最容易出错的地方：模板统一把源码放在 src/ 下，
      // 而入口表要是只写了根目录的文件名，新建项目后点运行就会找不到入口。
      final mainFile = ProjectTemplate.lua.mainFile;
      expect(mainFile, isNotNull, reason: '模板里没有文件');
      expect(luaProfile.entryFileNames, contains(mainFile));
    });

    test('模板把源码放在 src/ 下时也能找到入口', () {
      final mainFile = ProjectTemplate.lua.mainFile!;
      write(mainFile, '// 示例');
      expect(
        RunnerService.findEntry(project.path),
        p.join(project.path, mainFile),
      );
    });
  });

  group('运行后端', () {
    for (final (extension, code) in [
      ('js', 'console.log("脚本：" + [1, 2, 3].reduce((a, b) => a + b, 0));'),
      (
        'ts',
        'interface Value { n: number }; const v: Value = { n: 42 }; console.log(v.n);',
      ),
    ]) {
      test('内置 $extension 后端经档位完整接管运行', () async {
        write('main.$extension', code);
        final result = await luaProfile.runner!.run(
          projectPath: project.path,
          entryFile: p.join(project.path, 'main.$extension'),
        );
        expect(result, isNotNull);
        final output = result!.stdout.toList();
        final errors = result.stderr.toList();
        expect(await result.exitCode, 0, reason: (await errors).join('\n'));
        expect(await output, [extension == 'js' ? '脚本：6' : '42']);
      });
    }

    test('本语言文件由内置 Lua 执行', () async {
      write('main.lua', 'print(6 * 7)');
      final result = await luaProfile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.lua'),
      );
      expect(result, isNotNull, reason: '运行后端没有接管本语言文件');
      expect(result!.title, 'lua main.lua');
      expect(await result.stdout.toList(), ['42']);
      expect(await result.exitCode, 0);
    });

    test('别的语言文件交回内核', () async {
      write('main.py', 'x');
      final result = await luaProfile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.py'),
      );
      expect(result, isNull);
    });

    test('标题是英文命令行，输出照实回放', () async {
      // 文件名故意带括号和中文：括号是用户内容，不该被当成宿主标签剥掉。
      write('测试(1).lua', 'print("你好，世界")\nprint("（运行结束）")');
      final result = await luaProfile.runner!.run(
        projectPath: project.path,
        entryFile: p.join(project.path, '测试(1).lua'),
      );
      expect(result, isNotNull);
      // 标题是英文命令行，括号只来自文件名本身。
      expect(result!.title, 'lua 测试(1).lua');
      // 脚本输出里的中文和旧页脚文本必须原样保留，且两条流都要抽干，
      // 否则这次运行会一直挂在 pending 状态。
      final stdout = await result.stdout.toList();
      final stderr = await result.stderr.toList();
      expect(stdout, ['你好，世界', '（运行结束）']);
      expect(stderr, isEmpty);
      expect(await result.exitCode, 0);
    });
  });

  group('运行按钮分流', () {
    test('点运行拿到结果，而不是掉进「移动端跑不了」的兜底提示', () async {
      write('main.lua', 'print("ready")');
      final result = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: p.join(project.path, 'main.lua'),
      );
      expect(result, isNotNull);
      expect(result!.hint, isNull, reason: '后端接管了就不该走兜底提示');
      expect(result.title, 'lua main.lua');
      expect(await result.stdout!.toList(), ['ready']);
      expect(await result.exitCode, 0);
    });
  });

  group('Lua 编译器', () {
    const toolchain = LuaToolchain();

    test('语法检查不执行程序，编译字节码可再运行', () async {
      write('main.lua', 'error("should not run")');
      final source = p.join(project.path, 'main.lua');
      final output = p.join(project.path, 'main.luac');
      expect((await toolchain.check(source)).success, isTrue);
      expect((await toolchain.compile(source, output)).success, isTrue);
      final bytes = File(output).readAsBytesSync();
      expect(bytes.take(4), [27, 76, 117, 97]);
      final result = await toolchain.run(
        file: output,
        projectDirectory: project.path,
      );
      expect(result.status, isNonZero);
      expect(result.error, contains('should not run'));
    });

    test('项目模块和标准库可用', () async {
      write('maths.lua', 'return { answer = 6 * 7 }');
      write(
        'main.lua',
        'local m = require("maths")\nprint(m.answer, string.upper("lua"))',
      );
      final result = await toolchain.run(
        file: p.join(project.path, 'main.lua'),
        projectDirectory: project.path,
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, '42\tLUA\n');
    });

    test('native tools support Unicode project and file paths', () async {
      const folder = '\u9879\u76ee-\u{1f527}';
      const entry = '\u5165\u53e3.lua';
      const module = '\u6a21\u5757';
      const data = '\u6570\u636e.txt';
      const renamed = '\u7ed3\u679c.txt';
      write('$folder/$module.lua', 'return 42');
      write(
        '$folder/$entry',
        'local answer = require("$module")\n'
            'local f = assert(io.open("$data", "w"))\n'
            'f:write(answer); f:close()\n'
            'assert(os.rename("$data", "$renamed"))\n'
            'local input = assert(io.open("$renamed", "r"))\n'
            'print(input:read("a")); input:close()\n'
            'assert(os.remove("$renamed"))',
      );
      final root = p.join(project.path, folder);
      final source = p.join(root, entry);
      final bytecode = p.setExtension(source, '.luac');
      final checked = await toolchain.check(source);
      expect(checked.status, 0, reason: checked.error);
      final compiled = await toolchain.compile(source, bytecode);
      expect(compiled.status, 0, reason: compiled.error);
      expect(File(bytecode).readAsBytesSync().take(4), [27, 76, 117, 97]);
      for (final file in [source, bytecode]) {
        final result = await toolchain.run(file: file, projectDirectory: root);
        expect(result.status, 0, reason: result.error);
        expect(result.output, '42\n');
        expect(File(p.join(root, renamed)).existsSync(), isFalse);
      }
    });

    test('语法错误返回诊断', () async {
      write('main.lua', 'local = nope');
      final result = await toolchain.check(p.join(project.path, 'main.lua'));
      expect(result.status, isNonZero);
      expect(result.error, contains('main.lua'));
    });

    test('FFI 保留零字节，非 UTF-8 输出不会丢弃运行结果', () async {
      write('main.lua', 'io.write("before", string.char(0, 255), "after")');
      final result = await toolchain.run(
        file: p.join(project.path, 'main.lua'),
        projectDirectory: project.path,
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output.codeUnits, [
        ...'before'.codeUnits,
        0,
        0xfffd,
        ...'after'.codeUnits,
      ]);
    });

    test('项目相对文件读写和 dofile 不依赖 App 进程目录', () async {
      write('scripts/value.lua', 'return 42');
      write(
        'main.lua',
        'local f = assert(io.open("data.txt", "w"))\n'
            'f:write(dofile("scripts/value.lua")); f:close()\n'
            'assert(os.rename("data.txt", "answer.txt"))\n'
            'io.input("answer.txt")\n'
            'print(io.read("*a"))',
      );
      final result = await toolchain.run(
        file: p.join(project.path, 'main.lua'),
        projectDirectory: project.path,
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, '42\n');
      expect(File(p.join(project.path, 'answer.txt')).readAsStringSync(), '42');
    });

    test('取消运行会停止 Lua 死循环', () async {
      write('main.lua', 'while true do end');
      final execution = toolchain.startRun(
        file: p.join(project.path, 'main.lua'),
        projectDirectory: project.path,
        timeLimit: const Duration(seconds: 3),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await execution.cancel();
      final result = await execution.result;
      expect(result.status, 130);
      expect(result.error, contains('cancelled'));
    });
  });
}
