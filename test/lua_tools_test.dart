import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/lua_toolchain.dart';
import 'package:qfli_lua/lua_tools.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/store/project_store.dart';

/// Creates one throwaway directory per test and removes it afterwards.
Directory scratchDirectory(String label) {
  final directory = Directory.systemTemp.createTempSync('qfli_lua_$label');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

void main() {
  group('parseLuaDiagnostic', () {
    test('splits the file, line and message of a syntax error', () {
      final report = parseLuaDiagnostic(
        "main.lua:3: unexpected symbol near '='",
        file: p.join('/tmp', 'project', 'main.lua'),
      );
      expect(report.ok, isFalse);
      expect(report.line, 3);
      expect(report.message, "unexpected symbol near '='");
      expect(report.displayFile, 'main.lua');
    });

    test('accepts an absolute Windows path and keeps Unicode', () {
      final report = parseLuaDiagnostic(
        r'C:\用户\项目\main.lua:2: <eof> expected near end of file',
        file: r'C:\用户\项目\main.lua',
      );
      expect(report.line, 2);
      expect(report.message, '<eof> expected near end of file');
    });

    test('accepts a truncated chunk name that Lua shortens with ...', () {
      final report = parseLuaDiagnostic(
        r'...\very\long\project\main.lua:7: unexpected symbol',
        file: r'C:\very\long\project\main.lua',
      );
      expect(report.line, 7);
      expect(report.message, 'unexpected symbol');
    });

    test('keeps a message without a positional prefix verbatim', () {
      final report = parseLuaDiagnostic(
        'cannot open main.lua',
        file: 'main.lua',
      );
      expect(report.line, isNull);
      expect(report.message, 'cannot open main.lua');
    });

    test('treats an empty diagnostic as success', () {
      final report = parseLuaDiagnostic('  ', file: 'main.lua');
      expect(report.ok, isTrue);
    });
  });

  group('LuaStringLiteral', () {
    test('escapes quotes, backslashes and control characters', () {
      expect(LuaStringLiteral.encode('a"b\\c'), r'"a\"b\\c"');
      expect(LuaStringLiteral.encode('a\nb\tc\rd'), r'"a\nb\tc\rd"');
      expect(LuaStringLiteral.encode('\u0001'), r'"\x01"');
      expect(LuaStringLiteral.encode('中'), '"中"');
      expect(LuaStringLiteral.encode('中', escapeNonAscii: true), r'"\u{4E2D}"');
    });

    test('round-trips awkward text through encode and decode', () {
      const text = '第一行\n"引号" \\ 反斜杠\t制表\r回车 中文 😀';
      final encoded = LuaStringLiteral.encode(text);
      final decoded = LuaStringLiteral.decode(encoded);
      expect(decoded.ok, isTrue, reason: decoded.error);
      expect(decoded.value, text);

      final ascii = LuaStringLiteral.encode(text, escapeNonAscii: true);
      expect(LuaStringLiteral.decode(ascii).value, text);
    });

    test('decodes byte, hex and unicode escapes like Lua 5.4', () {
      expect(LuaStringLiteral.decode(r'"\65\66"').value, 'AB');
      expect(LuaStringLiteral.decode(r'"\x41\x42"').value, 'AB');
      expect(LuaStringLiteral.decode(r'"\u{4F60}\u{597D}"').value, '你好');
      expect(LuaStringLiteral.decode(r'"a\z   b"').value, 'ab');
      expect(LuaStringLiteral.decode(r'"\228\189\160"').value, '你');
    });

    test('decodes long brackets and skips the leading newline', () {
      expect(LuaStringLiteral.decode('[[第一行\n第二行]]').value, '第一行\n第二行');
      expect(LuaStringLiteral.decode('[[\nbody]]').value, 'body');
      expect(LuaStringLiteral.decode('[==[a]]b]==]').value, 'a]]b');
    });

    test('reports invalid literals instead of guessing', () {
      expect(LuaStringLiteral.decode(r'"abc').ok, isFalse);
      expect(LuaStringLiteral.decode(r'"a" .. "b"').ok, isFalse);
      expect(LuaStringLiteral.decode(r'"\q"').ok, isFalse);
      expect(LuaStringLiteral.decode(r'"\x4"').ok, isFalse);
      expect(LuaStringLiteral.decode(r'"\300"').ok, isFalse);
      expect(LuaStringLiteral.decode(r'"\u{80000000}"').ok, isFalse);
      expect(LuaStringLiteral.decode('[[open').ok, isFalse);
      expect(LuaStringLiteral.decode('bare').ok, isFalse);
    });

    test('long brackets escalate the level for embedded closers', () {
      expect(LuaStringLiteral.encodeLongBracket('a]]b'), '[=[a]]b]=]');
      expect(LuaStringLiteral.encodeLongBracket('a\nb'), '[[a\nb]]');
      expect(
        LuaStringLiteral.encodeLongBracket('\nleading'),
        '[[\n\nleading]]',
      );
      // A NUL cannot live in source text, so it falls back to short escapes.
      expect(LuaStringLiteral.encodeLongBracket('a\u0000b'), r'"a\x00b"');
    });
  });

  group('scanLuaSource', () {
    test('finds literal requires with their line numbers', () {
      final scan = scanLuaSource('''
local a = require("alpha")
local b = require 'beta'
local c = require [[gamma]]
local d = require(
  "delta"
)
''');
      expect(scan.dynamicRequires, 0);
      expect(scan.requires.map((reference) => reference.module).toList(), [
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
      expect(scan.requires.map((reference) => reference.line).toList(), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('ignores comments, long comments and ordinary strings', () {
      final scan = scanLuaSource('''
-- require("commented")
--[==[ require("longcommented") ]==]
local text = "require('quoted')"
local long = [[require("longquoted")]]
local real = require("real")
''');
      expect(scan.requires.map((reference) => reference.module).toList(), [
        'real',
      ]);
      expect(scan.requires.single.line, 5);
    });

    test('counts non-literal arguments as dynamic', () {
      final scan = scanLuaSource('''
require(variable)
require("a" .. "b")
require(prefix .. ".mod")
''');
      expect(scan.requires, isEmpty);
      expect(scan.dynamicRequires, 3);
    });
  });

  group('syntax checking with the bundled Lua parser', () {
    test('accepts valid source and reports the real error line', () async {
      final directory = scratchDirectory('check');
      final valid = await checkLuaSource(
        'local total = 0\nfor i = 1, 3 do total = total + i end\nprint(total)',
        scratchDirectory: directory,
      );
      expect(valid.ok, isTrue, reason: valid.message);
      expect(directory.listSync(), isEmpty, reason: '临时文件必须清理');

      final broken = await checkLuaSource(
        'local ok = 1\nlocal = invalid\n',
        fileName: 'snippet.lua',
        scratchDirectory: directory,
      );
      expect(broken.ok, isFalse);
      expect(broken.line, 2);
      expect(broken.message, contains('expected near'));
      expect(broken.sourceLine, 'local = invalid');
      expect(directory.listSync(), isEmpty, reason: '临时文件必须清理');
    });

    test('checks a project file under a Unicode path', () async {
      final directory = scratchDirectory('check_file');
      final project = Directory(p.join(directory.path, '中文 项目 (1)'))
        ..createSync();
      final file = File(p.join(project.path, 'main.lua'))
        ..writeAsStringSync('print("ok")\nlocal = 1\n');

      final report = await checkLuaFile(file.path, relativeTo: project.path);
      expect(report.ok, isFalse);
      expect(report.displayFile, 'main.lua');
      expect(report.line, 2);
      expect(report.sourceLine, 'local = 1');
    });
  });

  group('bytecode inspection', () {
    test('compiles and parses a real chunk', () async {
      final directory = scratchDirectory('bytecode');
      final source = File(p.join(directory.path, 'demo.lua'))
        ..writeAsStringSync('''
local greeting = "hello"
local function add(a, b) return a + b end
print(greeting, add(1, 2))
''');
      final chunk = await inspectLuaBytecode(source.path);
      expect(chunk.header.isLua54, isTrue);
      expect(chunk.header.version, 0x54);
      expect(chunk.header.format, 0);
      expect(chunk.header.versionMajor, 5);
      expect(chunk.header.versionMinor, 4);
      expect(chunk.header.instructionSize, 4);
      expect(chunk.header.luaIntegerSize, 8);
      expect(chunk.header.luaNumberSize, 8);
      expect(chunk.header.integerCheck, isTrue);
      expect(chunk.header.numberCheck, isTrue);
      expect(chunk.byteLength, greaterThan(32));
      expect(chunk.main.totalFunctions, 2);
      expect(chunk.main.totalInstructions, greaterThan(0));
      expect(chunk.main.allStringConstants, contains('"hello"'));
      expect(chunk.main.children.single.numParams, 2);
      expect(
        directory.listSync().map((entry) => p.basename(entry.path)),
        ['demo.lua'],
        reason: '检查不能留下 .luac',
      );
    });

    test('compiled bytecode still runs in the bundled VM', () async {
      final directory = scratchDirectory('bytecode_run');
      final source = File(p.join(directory.path, 'main.lua'))
        ..writeAsStringSync('print(6 * 7)');
      final output = p.join(directory.path, 'main.luac');
      final compiled = await const LuaToolchain().compile(source.path, output);
      expect(compiled.success, isTrue, reason: compiled.error);

      final chunk = parseLuaBytecode(await File(output).readAsBytes());
      expect(chunk.main.totalFunctions, 1);

      final run = await const LuaToolchain().run(
        file: output,
        projectDirectory: directory.path,
      );
      expect(run.status, 0, reason: run.error);
      expect(run.output, '42\n');
    });

    test('rejects foreign and mismatched bytecode with a clear message', () {
      expect(
        () => parseLuaBytecode(Uint8List.fromList(utf8.encode('print(1)'))),
        throwsA(isA<LuaBytecodeFormatException>()),
      );
      final mismatched = Uint8List.fromList([
        0x1B, 0x4C, 0x75, 0x61, // \x1bLua
        0x53, 0x00, // Lua 5.3, format 0
        0x19, 0x93, 0x0D, 0x0A, 0x1A, 0x0A,
        4, 8, 8, // Instruction, lua_Integer, lua_Number
        0x78, 0x56, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0x88, 0x77, 0x40,
        0,
      ]);
      expect(
        () => parseLuaBytecode(mismatched),
        throwsA(
          isA<LuaBytecodeFormatException>().having(
            (error) => error.message,
            'message',
            contains('不匹配'),
          ),
        ),
      );
      expect(
        () => parseLuaBytecode(Uint8List.fromList([0x1B, 0x4C, 0x75, 0x61])),
        throwsA(isA<LuaBytecodeFormatException>()),
      );
    });
  });

  group('module resolution', () {
    test('resolves the templates the runtime installs', () async {
      final directory = scratchDirectory('modules');
      final project = Directory(p.join(directory.path, '中文 模块'))..createSync();
      File(p.join(project.path, 'util.lua')).writeAsStringSync('return 1');
      Directory(p.join(project.path, 'pkg')).createSync();
      File(
        p.join(project.path, 'pkg', 'init.lua'),
      ).writeAsStringSync('return {}');
      Directory(p.join(project.path, 'src')).createSync();
      File(
        p.join(project.path, 'src', 'mod.lua'),
      ).writeAsStringSync('return 2');

      final search = await resolveLuaModules(
        projectDirectory: project.path,
        modules: ['util', 'pkg', 'mod', 'missing'],
      );
      expect(search.error, isNull);
      expect(search.packagePath, contains('?.lua'));

      final util = search.forModule('util')!;
      expect(util.resolved, isTrue);
      expect(p.basename(util.file!), 'util.lua');

      final pkg = search.forModule('pkg')!;
      expect(p.basename(pkg.file!), 'init.lua');

      final mod = search.forModule('mod')!;
      expect(
        p.equals(mod.file!, p.join(project.path, 'src', 'mod.lua')),
        isTrue,
      );

      final missing = search.forModule('missing')!;
      expect(missing.resolved, isFalse);
      expect(
        missing.searched.map((path) => p.relative(path, from: project.path)),
        containsAll([
          'missing.lua',
          p.join('missing', 'init.lua'),
          p.join('src', 'missing.lua'),
        ]),
      );
    });

    test('reports an error instead of pretending a module resolved', () async {
      final search = await resolveLuaModules(
        projectDirectory: Directory.systemTemp.path,
        modules: const [],
      );
      expect(search.error, isNotNull);
      expect(search.resolutions, isEmpty);
    });
  });

  group('project require scan', () {
    test('lists requires per file and flags missing modules', () async {
      final directory = scratchDirectory('scan');
      final project = Directory(p.join(directory.path, 'app'))..createSync();
      File(p.join(project.path, 'util.lua')).writeAsStringSync('return 1');
      File(p.join(project.path, 'main.lua')).writeAsStringSync('''
local util = require("util")
local nope = require("nope")
local dynamic = require(name)
-- require("commented")
''');
      // Build folders must not contribute files to the audit.
      final build = Directory(p.join(project.path, 'build'))..createSync();
      File(p.join(build.path, 'generated.lua')).writeAsStringSync('return 1');

      final scan = await scanLuaProject(projectDirectory: project.path);
      expect(scan.error, isNull);
      expect(scan.entries.map((entry) => entry.relativePath), [
        'main.lua',
        'util.lua',
      ]);
      expect(scan.unresolved, ['nope']);
      expect(scan.dynamicRequires, 1);
      expect(scan.truncated, isFalse);

      final main = scan.entries.first;
      expect(main.requires.map((reference) => reference.module), [
        'util',
        'nope',
      ]);
      expect(main.requires.map((reference) => reference.line), [1, 2]);
      expect(scan.resolutions['util']!.resolved, isTrue);
      expect(scan.resolutions['nope']!.resolved, isFalse);
    });

    test('limits the file list instead of walking a huge tree', () async {
      final directory = scratchDirectory('scan_limit');
      for (var index = 0; index < 5; index++) {
        File(p.join(directory.path, 'f$index.lua')).writeAsStringSync('');
      }
      final files = await listLuaFiles(directory.path, maxFiles: 2);
      expect(files, hasLength(2));
      expect(files.every((path) => path.endsWith('.lua')), isTrue);
    });
  });

  group('Lua patterns', () {
    test('reports matches, captures and gsub results', () async {
      final outcome = await runLuaPattern(
        subject: 'a=1, b=22, c=333',
        pattern: '(%a+)=(%d+)',
        replacement: r'%2=%1',
      );
      expect(outcome.ok, isTrue, reason: outcome.error);
      expect(outcome.matches, hasLength(3));
      expect(outcome.matches.first.start, 1);
      expect(outcome.matches.first.end, 3);
      expect(outcome.matches.first.text, 'a=1');
      expect(outcome.matches.first.captures, ['a', '1']);
      expect(outcome.matches.last.captures, ['c', '333']);
      expect(outcome.replacementCount, 3);
      expect(outcome.replaced, '1=a, 22=b, 333=c');
      expect(outcome.truncated, isFalse);
    });

    test('reports invalid patterns and invalid replacements', () async {
      final invalidPattern = await runLuaPattern(
        subject: 'abc',
        pattern: '(%a',
      );
      expect(invalidPattern.ok, isFalse);
      expect(invalidPattern.error, isNotNull);

      final invalidReplacement = await runLuaPattern(
        subject: 'abc',
        pattern: '(%a)',
        replacement: '%9',
      );
      expect(invalidReplacement.ok, isFalse);
      expect(invalidReplacement.error, contains('invalid capture index'));
    });

    test('supports plain text search and keeps Unicode intact', () async {
      final outcome = await runLuaPattern(
        subject: '中文 (括号) 与 % 百分号',
        pattern: '(括号)',
        replacement: '【括号】',
        plain: true,
      );
      expect(outcome.ok, isTrue, reason: outcome.error);
      expect(outcome.matches, hasLength(1));
      expect(outcome.matches.single.text, '(括号)');
      expect(outcome.replaced, '中文 【括号】 与 % 百分号');
    });

    test('cancel is safe after the run finished', () async {
      final execution = startLuaPattern(subject: 'abc', pattern: 'a');
      final outcome = await execution.result;
      expect(outcome.ok, isTrue);
      await execution.cancel();
    });

    test('stops a match list at the built-in limit', () async {
      final outcome = await runLuaPattern(
        subject: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        pattern: 'a',
      );
      expect(outcome.matches, hasLength(50));
      expect(outcome.truncated, isTrue);
    });
  });

  group('LuaProjectFileController', () {
    test('lists Lua files of the selected project only', () async {
      final directory = scratchDirectory('controller');
      final alpha = Directory(p.join(directory.path, 'alpha'))..createSync();
      File(p.join(alpha.path, 'main.lua')).writeAsStringSync('');
      final nested = Directory(p.join(alpha.path, 'src'))..createSync();
      File(p.join(nested.path, 'util.lua')).writeAsStringSync('');
      File(p.join(alpha.path, 'notes.txt')).writeAsStringSync('');
      final beta = Directory(p.join(directory.path, 'beta'))..createSync();
      File(p.join(beta.path, 'only.lua')).writeAsStringSync('');

      final store = ProjectStore(
        storageFile: File(p.join(directory.path, 'projects.json')),
      );
      addTearDown(store.dispose);
      await store.load();
      final alphaResult = await store.addExisting(alpha.path);
      final betaResult = await store.addExisting(beta.path);
      expect(alphaResult.project, isNotNull, reason: alphaResult.error);
      expect(betaResult.project, isNotNull, reason: betaResult.error);

      final controller = LuaProjectFileController(store: store);
      addTearDown(controller.dispose);
      await controller.refresh();

      expect(controller.projects, hasLength(2));
      // Projects are ordered by recent activity, so select explicitly.
      controller.selectProject(alphaResult.project!.id);
      await controller.refresh();
      expect(controller.files, hasLength(2));
      expect(controller.files.map(controller.label).toList(), [
        'main.lua',
        p.join('src', 'util.lua'),
      ]);
      expect(controller.file, controller.files.first);

      controller.selectProject(betaResult.project!.id);
      await controller.refresh();
      expect(controller.files, hasLength(1));
      expect(controller.label(controller.file), 'only.lua');

      // An unknown path must not become the current selection.
      controller.selectFile(p.join(beta.path, 'missing.lua'));
      expect(controller.file, isNull);
    });
  });

  group('tool boundary regressions', () {
    test(
      'syntax checks cannot execute code or overwrite a scratch fixture',
      () async {
        final directory = scratchDirectory('check_no_execute');
        final existing = File(p.join(directory.path, 'snippet.lua'))
          ..writeAsStringSync('keep this fixture');
        final sentinel = File(p.join(directory.path, 'executed.txt'));
        final report = await checkLuaSource(
          'io.open(${LuaStringLiteral.encode(sentinel.path)}, "w")\n'
          'while true do end',
          scratchDirectory: directory,
        );
        expect(report.ok, isTrue, reason: report.message);
        expect(sentinel.existsSync(), isFalse);
        expect(existing.readAsStringSync(), 'keep this fixture');
        expect(directory.listSync(), hasLength(1));
      },
    );

    test(
      'literal byte escapes and extended Lua UTF-8 retain exact bytes',
      () async {
        final directory = scratchDirectory('literal_bytes');
        const literals = [
          r'"\u{D800}"',
          r'"\u{110000}"',
          r'"\u{7FFFFFFF}"',
          r'"\u{0000000000000041}"',
          r'"\255\0\x01"',
          r'"你好 😀"',
        ];
        for (final literal in literals) {
          final decoded = LuaStringLiteral.decode(literal);
          expect(decoded.ok, isTrue, reason: '$literal: ${decoded.error}');
          final source = File(p.join(directory.path, 'literal.lua'))
            ..writeAsStringSync(
              'local s=$literal\n'
              'for i=1,#s do io.write(string.format("%02x",s:byte(i))) end',
            );
          final result = await const LuaToolchain().run(
            file: source.path,
            projectDirectory: directory.path,
          );
          expect(result.success, isTrue, reason: result.error);
          expect(
            decoded.bytes!
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join(),
            result.output,
            reason: literal,
          );
        }
        expect(LuaStringLiteral.decode(r'"\255"').hasMalformedUtf8, isTrue);
        for (final malformed in [r'"\u41}"', r'"\u{}"', r'"\u{-1}"']) {
          expect(LuaStringLiteral.decode(malformed).ok, isFalse);
        }
        const crlf = '\r\nfirst\rsecond';
        final encoded = LuaStringLiteral.encodeLongBracket(crlf);
        expect(LuaStringLiteral.decode(encoded).value, crlf);
        expect(
          LuaStringLiteral.decode('[[a\r\nb\rc\n\rd]]').value,
          'a\nb\nc\nd',
        );
      },
    );

    test(
      'bytecode validates all required sections and numeric constants',
      () async {
        final directory = scratchDirectory('bytecode_bounds');
        final source = File(p.join(directory.path, 'bounds.lua'))
          ..writeAsStringSync(
            'local t={1234567890123,-1234567890124,1.25}\n'
            'return function() return t end',
          );
        final output = File(p.join(directory.path, 'bounds.luac'));
        final compiled = await const LuaToolchain().compile(
          source.path,
          output.path,
        );
        expect(compiled.success, isTrue, reason: compiled.error);
        final bytes = output.readAsBytesSync();
        final chunk = parseLuaBytecode(bytes);
        expect(
          chunk.main.constants,
          containsAll(['1234567890123', '-1234567890124', '1.25']),
        );
        expect(chunk.main.children.single.upvalueCount, 1);
        expect(chunk.main.children.single.source, chunk.main.source);
        for (var length = 0; length < bytes.length; length++) {
          expect(
            () => parseLuaBytecode(Uint8List.sublistView(bytes, 0, length)),
            throwsA(isA<LuaBytecodeFormatException>()),
            reason: 'truncated at $length / ${bytes.length}',
          );
        }
        for (final offset in [5, 12, 15, 23]) {
          final corrupt = Uint8List.fromList(bytes);
          corrupt[offset] ^= 1;
          expect(
            () => parseLuaBytecode(corrupt),
            throwsA(isA<LuaBytecodeFormatException>()),
          );
        }
      },
    );

    test(
      'bytecode export preserves existing files and backs up replacement',
      () async {
        final directory = scratchDirectory('bytecode_export');
        final source = File(p.join(directory.path, '程序.lua'))
          ..writeAsStringSync('print(42)');
        final outputPath = await compileLuaFileToProject(
          source.path,
          projectDirectory: directory.path,
        );
        final output = File(outputPath);
        final original = output.readAsBytesSync();
        source.writeAsStringSync('print(43)');
        await expectLater(
          compileLuaFileToProject(
            source.path,
            projectDirectory: directory.path,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(output.readAsBytesSync(), original);
        source.writeAsStringSync('local = invalid');
        await expectLater(
          compileLuaFileToProject(
            source.path,
            projectDirectory: directory.path,
            overwrite: true,
          ),
          throwsA(isA<LuaBytecodeFormatException>()),
        );
        expect(output.readAsBytesSync(), original);
        source.writeAsStringSync('print(43)');
        final previous = FileBackup.baseOverride;
        addTearDown(() => FileBackup.baseOverride = previous);
        final blocked = File(p.join(directory.path, 'blocked'))
          ..writeAsStringSync('not a directory');
        FileBackup.baseOverride = blocked.path;
        await expectLater(
          compileLuaFileToProject(
            source.path,
            projectDirectory: directory.path,
            overwrite: true,
          ),
          throwsA(isA<FileSystemException>()),
        );
        expect(output.readAsBytesSync(), original);
        FileBackup.baseOverride = p.join(directory.path, 'backups');
        await compileLuaFileToProject(
          source.path,
          projectDirectory: directory.path,
          overwrite: true,
        );
        final backups = await FileBackup.listVersions(
          output,
          projectName: p.basename(directory.path),
        );
        expect(backups, hasLength(1));
        expect(backups.single.file.readAsBytesSync(), original);
        final result = await const LuaToolchain().run(
          file: outputPath,
          projectDirectory: directory.path,
        );
        expect(result.success, isTrue, reason: result.error);
        expect(result.output, '43\n');
        expect(
          directory.listSync().where(
            (entry) => p.basename(entry.path).startsWith('.qfli-luac-'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'module lookup recognizes standard libraries without executing files',
      () async {
        final directory = scratchDirectory("module's_unicode_中文");
        final marker = File(p.join(directory.path, 'executed.txt'));
        File(p.join(directory.path, 'util.lua')).writeAsStringSync(
          'io.open("executed.txt","w"):close()\nerror("must not run")',
        );
        final result = await resolveLuaModules(
          projectDirectory: directory.path,
          modules: ['math', 'utf8', 'string', 'util', "odd'\tname"],
        );
        expect(result.error, isNull);
        for (final module in ['math', 'utf8', 'string']) {
          expect(result.forModule(module)!.builtIn, isTrue);
          expect(result.forModule(module)!.resolved, isTrue);
        }
        expect(result.forModule('util')!.resolved, isTrue);
        expect(result.forModule("odd'\tname")!.resolved, isFalse);
        expect(marker.existsSync(), isFalse);
      },
    );

    test(
      'static scan handles nested calls, comments and qualified functions',
      () {
        final scan = scanLuaSource('''
print(require "one")
local text = require "two" .. "tail"
require -- comment between function and argument
  ("three")
object.require("ignore")
object:require("ignore2")
function require(value) return value end
''');
        expect(scan.requires.map((reference) => reference.module), [
          'one',
          'two',
          'three',
        ]);
        expect(scan.requires.map((reference) => reference.line), [1, 2, 3]);
        expect(scan.dynamicRequires, 0);
        expect(() => scanLuaSource('local s = "unfinished\\'), returnsNormally);
      },
    );

    test(
      'empty, anchored and control-byte patterns match Lua gsub semantics',
      () async {
        final empty = await runLuaPattern(
          subject: 'abc',
          pattern: '',
          replacement: '-',
        );
        expect(empty.ok, isTrue, reason: empty.error);
        expect(empty.matches.map((match) => match.start), [1, 2, 3, 4]);
        expect(empty.replaced, '-a-b-c-');
        expect(empty.replacementCount, 4);
        expect(empty.truncated, isFalse);
        final anchored = await runLuaPattern(
          subject: 'abc',
          pattern: '^',
          replacement: '-',
        );
        expect(anchored.matches, hasLength(1));
        expect(anchored.replaced, '-abc');
        final optional = await runLuaPattern(
          subject: 'abc',
          pattern: 'a*',
          replacement: '-',
        );
        expect(optional.matches, hasLength(optional.replacementCount));
        final controls = await runLuaPattern(
          subject: 'a\r\nb\u0000😀]]',
          pattern: '\r\n',
          replacement: 'X',
          plain: true,
        );
        expect(controls.ok, isTrue, reason: controls.error);
        expect(controls.replaced, 'aXb\u0000😀]]');
        expect(controls.matches.single.text, '\r\n');
        final exact = await runLuaPattern(subject: 'a' * 50, pattern: 'a');
        expect(exact.matches, hasLength(50));
        expect(exact.truncated, isFalse);
      },
    );

    test(
      'missing project is an audit error and exact file limit is complete',
      () async {
        final directory = scratchDirectory('scan_complete');
        File(p.join(directory.path, 'one.lua')).writeAsStringSync('');
        final exact = await scanLuaProject(
          projectDirectory: directory.path,
          maxFiles: 1,
        );
        expect(exact.error, isNull);
        expect(exact.truncated, isFalse);
        final missing = await scanLuaProject(
          projectDirectory: p.join(directory.path, 'missing'),
        );
        expect(missing.error, isNotNull);
      },
    );
  });
}
