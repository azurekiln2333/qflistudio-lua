import 'dart:convert';
import 'dart:io';

import 'package:qfli_studio_core/terminal/shell/command_parser.dart';
import 'package:qfli_studio_core/terminal/shell/sandbox_shell_backend.dart';

import 'lua_toolchain.dart';

/// Shared by the editor terminal and the standalone terminal through the profile.
Future<bool> luaTerminalCommandDelegate(
  SandboxShellBackend backend,
  String command,
) => const LuaTerminalDelegate().handle(backend, command);

/// Runs offline commands through the bundled library, without spawning a shell.
class LuaTerminalDelegate {
  const LuaTerminalDelegate({
    this.toolchain = const LuaToolchain(),
    this.timeLimit = const Duration(seconds: 10),
  });

  final LuaToolchain toolchain;
  final Duration timeLimit;

  Future<bool> handle(SandboxShellBackend backend, String command) async {
    final policy = backend.escapePolicy;
    if (CommandParser.classify(command, escapePolicy: policy) !=
        CommandSyntax.simple) {
      return false;
    }
    final parsed = CommandParser.tokenize(command, escapePolicy: policy);
    if (!parsed.ok || parsed.tokens.isEmpty) return false;
    final tokens = parsed.tokens.map((token) => token.text).toList();
    final name = tokens.first.toLowerCase();
    final compiler = name == 'luac' || name == 'luac.exe';
    if (!compiler && name != 'lua' && name != 'lua.exe') return false;
    try {
      if (compiler) {
        await _compiler(backend, tokens);
      } else {
        await _interpreter(backend, tokens);
      }
    } on SandboxEscapeException catch (error) {
      await _show(
        backend,
        command,
        error: '$name: 不能越出沙盒目录: ${error.path}',
        status: 1,
      );
    } on FileSystemException catch (error) {
      await _show(
        backend,
        command,
        error: '$name: ${error.message}: ${error.path ?? ''}',
        status: 1,
      );
    } catch (error) {
      await _show(backend, command, error: '$name: $error', status: 127);
    }
    return true;
  }

  Future<void> _interpreter(
    SandboxShellBackend backend,
    List<String> tokens,
  ) async {
    var index = 1;
    var version = false;
    while (index < tokens.length) {
      final option = tokens[index];
      if (option == '--') {
        index++;
        break;
      }
      if (!option.startsWith('-')) break;
      if (option == '-v' || option == '--version') {
        version = true;
      } else if (option == '-h' || option == '--help') {
        await _show(backend, tokens.join(' '), output: _luaUsage);
        return;
      } else if (option == '-' ||
          option == '-i' ||
          option == '-E' ||
          option == '-W' ||
          option.startsWith('-e') ||
          option.startsWith('-l')) {
        await _show(
          backend,
          tokens.join(' '),
          status: 127,
          error:
              'lua: 当前内置入口不支持选项 $option。请将代码和 require 写入 Lua 文件；'
              '脚本输入来自当前目录的 input.txt，终端不提供交互式 REPL。',
        );
        return;
      } else {
        await _show(
          backend,
          tokens.join(' '),
          error: 'lua: unknown option $option\n$_luaUsage',
          status: 1,
        );
        return;
      }
      index++;
    }
    final banner = version ? '${toolchain.copyright()}\n' : '';
    if (index == tokens.length) {
      await _show(
        backend,
        tokens.join(' '),
        output: banner,
        error: version ? '' : 'lua: 终端不提供交互式 REPL，请使用 lua <文件>。\n$_luaUsage',
        status: version ? 0 : 127,
      );
      return;
    }
    final script = backend.resolveSandboxPath(tokens[index]);
    _requireFile(script);
    final execution = toolchain.startRun(
      file: script,
      projectDirectory: backend.cwd,
      commandLine: tokens,
      scriptIndex: index,
      timeLimit: timeLimit,
    );
    await _result(
      backend,
      tokens.join(' '),
      execution.result,
      prefix: banner,
      cancel: execution.cancel,
    );
  }

  Future<void> _compiler(
    SandboxShellBackend backend,
    List<String> tokens,
  ) async {
    var parseOnly = false;
    var strip = false;
    var version = false;
    var options = true;
    var output = 'luac.out';
    final inputs = <String>[];
    for (var index = 1; index < tokens.length; index++) {
      final option = tokens[index];
      if (!options || !option.startsWith('-')) {
        inputs.add(option);
        continue;
      }
      switch (option) {
        case '--':
          options = false;
        case '-v' || '--version':
          version = true;
        case '-p':
          parseOnly = true;
        case '-s':
          strip = true;
        case '-o':
          if (++index >= tokens.length || tokens[index].isEmpty) {
            await _show(
              backend,
              tokens.join(' '),
              error: 'luac: -o needs an output file',
              status: 1,
            );
            return;
          }
          output = tokens[index];
          if (output == '-') {
            await _show(
              backend,
              tokens.join(' '),
              status: 127,
              error: 'luac: 终端不显示二进制字节码，请使用 -o <文件>。',
            );
            return;
          }
        case '-h' || '--help':
          await _show(backend, tokens.join(' '), output: _luacUsage);
          return;
        case '-l' || '-':
          await _show(
            backend,
            tokens.join(' '),
            status: 127,
            error: 'luac: 当前内置入口不支持字节码列表和从终端读取源代码，请指定文件。',
          );
          return;
        default:
          await _show(
            backend,
            tokens.join(' '),
            error: 'luac: unknown option $option\n$_luacUsage',
            status: 1,
          );
          return;
      }
    }
    final banner = version ? '${toolchain.copyright()}\n' : '';
    if (inputs.isEmpty) {
      await _show(
        backend,
        tokens.join(' '),
        output: banner,
        error: version ? '' : 'luac: no input files\n$_luacUsage',
        status: version ? 0 : 1,
      );
      return;
    }
    if (!parseOnly && inputs.length != 1) {
      await _show(
        backend,
        tokens.join(' '),
        output: banner,
        status: 127,
        error: 'luac: 内置编译入口不支持将多个输入链接为一个字节码文件；可用 -p 检查多个文件。',
      );
      return;
    }
    final files = inputs.map(backend.resolveSandboxPath).toList();
    for (final file in files) {
      _requireFile(file);
    }
    final target = parseOnly ? null : backend.resolveSandboxPath(output);
    var canceled = false;
    Future<LuaToolResult> compile() async {
      for (final file in files) {
        if (canceled) {
          return const LuaToolResult(status: 130, output: '', error: '');
        }
        final result = await toolchain.load(
          file,
          outputFile: target,
          stripDebug: strip,
        );
        if (!result.success) return result;
      }
      return LuaToolResult(status: canceled ? 130 : 0, output: '', error: '');
    }

    await _result(
      backend,
      tokens.join(' '),
      compile(),
      prefix: banner,
      cancel: () async {
        canceled = true;
      },
    );
  }

  static void _requireFile(String path) {
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
      throw FileSystemException('not a readable regular file', path);
    }
  }

  Future<void> _result(
    SandboxShellBackend backend,
    String title,
    Future<LuaToolResult> pending, {
    String prefix = '',
    Future<void> Function()? cancel,
  }) async {
    final result = pending.catchError(
      (Object error) =>
          LuaToolResult(status: 127, output: '', error: 'lua: $error'),
    );
    await backend.runStreams(
      title: title,
      stdout: result
          .asStream()
          .map((value) => '$prefix${value.output}')
          .transform(const LineSplitter()),
      stderr: result
          .asStream()
          .map((value) => value.error)
          .transform(const LineSplitter()),
      exitCode: result.then((value) => value.status),
      cancel: cancel,
    );
  }

  Future<void> _show(
    SandboxShellBackend backend,
    String title, {
    String output = '',
    String error = '',
    int status = 0,
  }) => _result(
    backend,
    title,
    Future.value(LuaToolResult(status: status, output: output, error: error)),
  );

  static const _luaUsage = '''lua [options] <文件> [参数...]
  -v / --version     显示内置 Lua 版本
  -h / --help        显示帮助
  --                停止解析选项，可运行以 - 开头的文件
默认输入为当前目录的 input.txt；本地模块从当前目录和 src 目录加载。
支持源代码和 Lua 5.4 字节码；不支持 -e/-l/-i/-E/-W、交互输入和 shell 管道。''';

  static const _luacUsage = '''luac [-p] [-s] [-o 输出文件] <文件>
  -p                只解析，不执行；可检查多个源代码或字节码文件
  -s                剥离字节码调试信息
  -o 文件           编译输出文件，默认 luac.out
  -v / --version     显示内置 Lua 版本
  -h / --help        显示帮助
  --                停止解析选项
不支持字节码列表、多个输入链接、二进制终端输出和 shell 管道。''';
}
