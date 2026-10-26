import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/script_toolchain.dart';

void main() {
  final toolchain = ScriptToolchain(
    libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
    typescriptCompilerPath: p.absolute('assets/runtime/typescript.js'),
  );
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('script_离线_😀_');
  });
  tearDown(() => project.deleteSync(recursive: true));

  File write(String name, String source) {
    final file = File(p.join(project.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(source);
    return file;
  }

  Future<ScriptToolResult> run(
    String source, {
    String name = '入口(示例).js',
    Duration timeLimit = const Duration(seconds: 10),
  }) {
    final file = write(name, source);
    return toolchain.run(
      file: file.path,
      projectDirectory: project.path,
      timeLimit: timeLimit,
    );
  }

  test('real engine identifies its retained versions', () {
    expect(toolchain.version(), contains('QuickJS2026-06-04'));
    expect(toolchain.version(), contains('TypeScript5.9.3'));
  });

  test(
    'JS classes closures collections and destructuring actually execute',
    () async {
      final result = await run('''
class Counter { #n; constructor(n) { this.#n = n; } next() { return ++this.#n; } }
const counter = new Counter(39);
const multiply = n => value => n*value;
const [first, ...rest] = [counter.next(), counter.next(), 42];
const map = new Map([['value', multiply(2)(21)]]);
console.log(first, rest.join(','), map.get('value'), new Set([1,1,2]).size);
''');
      expect(result.status, 0, reason: result.error);
      expect(result.output, '40 41,42 42 2\n');
      expect(result.error, isEmpty);
    },
  );

  test('console preserves Unicode NUL and separates stderr', () async {
    final result = await run(
      r'console.log("中文😀\0尾"); console.warn("warning"); console.error("error");',
    );
    expect(result.status, 0);
    expect(result.output, '中文😀\u0000尾\n');
    expect(result.error, 'warning\nerror\n');
  });

  test('actual async jobs and top level await drain before success', () async {
    final result = await run('''
async function answer() { return (await Promise.resolve(40)) + 2; }
console.log(await answer());
Promise.resolve().then(() => console.log('microtask'));
''');
    expect(result.status, 0, reason: result.error);
    expect(result.output, '42\nmicrotask\n');
  });

  test(
    'pending work rejection runtime errors and missing hosts fail honestly',
    () async {
      for (final source in [
        'await new Promise(()=>{});',
        'Promise.reject(new Error("rejected"));',
        'throw new Error("actual runtime failure");',
        'console.log(process.version);',
        'fetch("https://example.com");',
        'setTimeout(()=>{}, 1);',
      ]) {
        final result = await run(source);
        expect(result.status, 1, reason: source);
        expect(result.error, isNotEmpty, reason: source);
      }
    },
  );

  test(
    'saved relative ES modules and cyclic imports resolve from project',
    () async {
      write(
        'nested/math.mjs',
        'import {base} from "../base.js"; export const square=n=>n*n+base;',
      );
      write('base.js', 'export const base = 0;');
      final result = await run(
        'import {square} from "./nested/math.mjs"; console.log(square(7));',
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, '49\n');
      write('a.js', 'import {b} from "./b.js"; export const a=()=>40+b;');
      write(
        'b.js',
        'import {a} from "./a.js"; export const b=2; export const answer=()=>a();',
      );
      final cyclic = await run(
        'import {answer} from "./b.js"; console.log(answer());',
      );
      expect(cyclic.status, 0, reason: cyclic.error);
      expect(cyclic.output, '42\n');
    },
  );

  test(
    'missing bare remote and outside modules never gain host access',
    () async {
      final outside = File(
        p.join(project.parent.path, '${p.basename(project.path)}_outside.js'),
      )..writeAsStringSync('console.log("outside executed");');
      addTearDown(() => outside.deleteSync());
      for (final specifier in [
        './missing.js',
        'node:fs',
        'https://example.com/a.js',
        '../${p.basename(outside.path)}',
      ]) {
        final result = await run('import "$specifier";');
        expect(result.status, 1, reason: specifier);
        expect(result.output, isEmpty);
        expect(result.error, contains('Offline project module unavailable'));
      }
    },
  );

  test(
    'TypeScript compiler really emits and executes enums generics assertions',
    () async {
      const source = '''
interface Value { n: number }
enum Numbering { start=40, next }
function identity<T>(value:T):T { return value; }
const item = {n:Numbering.next} as Value;
console.log(identity(item).n+1);
''';
      final emitted = await toolchain.transpile(source);
      expect(emitted.status, 0, reason: emitted.error);
      expect(emitted.output, contains('Numbering'));
      expect(emitted.output, isNot(contains('interface Value')));
      final result = await run(source, name: '入口.ts');
      expect(result.status, 0, reason: result.error);
      expect(result.output, '42\n');
    },
  );

  test(
    'TypeScript dependencies use actual compiler and source diagnostic paths',
    () async {
      final module = write('value.TS', 'export const value: number = 42;');
      var result = await run(
        'import {value} from "./value.TS"; console.log(value);',
        name: 'main.ts',
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, '42\n');
      final source = '${' ' * 200}export const value: number = ;';
      module.writeAsStringSync(source);
      result = await run('import "./value.TS";', name: 'main.ts');
      expect(result.status, 3, reason: result.error);
      expect(result.error, contains('Expression expected'));
      expect(
        result.diagnostics.single.filePath,
        module.path.replaceAll(r'\', '/'),
      );
      expect(result.diagnostics.single.startOffset, source.indexOf(';'));
    },
  );

  test('syntax checks never execute code or resolve imports', () async {
    for (final typescript in [false, true]) {
      final result = await toolchain.checkSource(
        '''
import './missing_dependency.js';
console.log('must not run');
throw new Error('must not run');
while(true) {}
''',
        typescript: typescript,
        fileName: typescript ? 'editor.ts' : 'editor.js',
      );
      expect(result.status, 0, reason: result.error);
      expect(result.output, isEmpty);
      expect(result.error, isEmpty);
      expect(result.diagnostics, isEmpty);
    }
    expect(project.listSync(), isEmpty);
  });

  test('JS syntax offsets preserve CRLF astral characters and EOF', () async {
    for (final prefix in ['// 中文😀\r\n', '"😀"; ', '// 中文\r', '// 中文\n\r']) {
      final source = '${prefix}const = 1';
      final result = await toolchain.checkSource(source);
      expect(result.status, 3, reason: result.error);
      expect(result.diagnostics.single.startOffset, source.indexOf('='));
      expect(result.diagnostics.single.endOffset, source.indexOf('=') + 1);
    }
    const source = 'function f(){';
    final eof = await toolchain.checkSource(source);
    expect(eof.status, 3, reason: eof.error);
    expect(eof.diagnostics.single.startOffset, source.length);
    expect(eof.diagnostics.single.endOffset, source.length);
  });

  test(
    'TS syntax positions use original UTF16 source and semantic types are out of scope',
    () async {
      const source = '// 中文😀\r\nconst value: number = ;';
      final result = await toolchain.checkSource(
        source,
        typescript: true,
        fileName: 'editor.ts',
      );
      expect(result.status, 3, reason: result.error);
      expect(result.diagnostics.single.startOffset, source.indexOf(';'));
      expect(result.diagnostics.single.endOffset, source.indexOf(';') + 1);
      expect(result.diagnostics.single.code, '1109');
      final syntaxOnly = await toolchain.checkSource(
        'const n: number = "semantic mismatch";',
        typescript: true,
      );
      expect(syntaxOnly.status, 0, reason: syntaxOnly.error);
      expect(syntaxOnly.diagnostics, isEmpty);
    },
  );

  test('timeout and VM cancellation recover with fresh state', () async {
    final timed = await run(
      'while(true) {}',
      timeLimit: const Duration(milliseconds: 60),
    );
    expect(timed.status, 124);
    final file = write('loop.js', 'while(true) {}');
    final execution = toolchain.startRun(
      file: file.path,
      projectDirectory: project.path,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await execution.cancel();
    final cancelled = await execution.result.timeout(
      const Duration(seconds: 5),
    );
    expect(cancelled.status, 130);
    await execution.cancel();
    final recovered = await run('console.log(42);');
    expect(recovered.status, 0, reason: recovered.error);
    expect(recovered.output, '42\n');
  });

  test(
    'immediate cancellation also covers asynchronous snapshot preparation',
    () async {
      final file = write('main.js', 'console.log("must not execute");');
      final execution = toolchain.startRun(
        file: file.path,
        projectDirectory: project.path,
      );
      await execution.cancel();
      final result = await execution.result;
      expect(result.status, 130);
      expect(result.output, isEmpty);
    },
  );

  test(
    'limits reject oversized source and output without reporting success',
    () async {
      final source = await toolchain.checkSource(
        ' ' * (ScriptToolchain.maximumSourceBytes + 1),
      );
      expect(source.status, 127);
      expect(source.unavailableReason, isNotEmpty);
      final result = await run('console.log("x".repeat(1024*1024+1));');
      expect(result.status, 1);
      expect(result.error, contains('output exceeds'));
    },
  );

  test(
    'missing engine/compiler and invalid saved entry report unavailable',
    () async {
      final missing = ScriptToolchain(
        libraryPath: p.join(project.path, 'absent.dll'),
      );
      var result = await missing.checkSource('const = invalid');
      expect(result.status, 127);
      result = await missing.run(
        file: 'absent.js',
        projectDirectory: project.path,
      );
      expect(result.status, 127);
      final noCompiler = ScriptToolchain(
        libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
        typescriptCompilerPath: p.join(project.path, 'absent-typescript.js'),
      );
      result = await noCompiler.checkSource(
        'const n:number=1;',
        typescript: true,
      );
      expect(result.status, 127);
      final badCompiler = write(
        'bad-compiler.txt',
        'not valid trusted compiler',
      );
      result = await ScriptToolchain(
        libraryPath: Platform.environment['QFLI_SCRIPT_LIBRARY'],
        typescriptCompilerPath: badCompiler.path,
      ).checkSource('', typescript: true);
      expect(result.status, 127);
      result = await toolchain.run(
        file: p.join(project.path, 'absent.js'),
        projectDirectory: project.path,
      );
      expect(result.status, 127);
    },
  );
}
