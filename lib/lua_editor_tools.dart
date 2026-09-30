import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/studio_profile.dart';

import 'lua_toolchain.dart';

abstract final class LuaEditorTools {
  static const tools = [
    EditorFileTool(
      id: 'lua_check',
      label: '检查 Lua 语法',
      icon: Icons.fact_check_outlined,
      extensions: ['.lua'],
      run: _check,
    ),
    EditorFileTool(
      id: 'lua_compile',
      label: '编译 Lua 字节码',
      icon: Icons.build_outlined,
      extensions: ['.lua'],
      run: _compile,
    ),
  ];

  static Future<EditorFileToolResult> _check(
    String file,
    String projectPath,
  ) async {
    final result = await const LuaToolchain().check(file);
    return EditorFileToolResult(
      success: result.success,
      message: result.success ? '${p.basename(file)}：语法正确' : result.error,
    );
  }

  static Future<EditorFileToolResult> _compile(
    String file,
    String projectPath,
  ) async {
    final output = p.setExtension(file, '.luac');
    final result = await const LuaToolchain().compile(file, output);
    return EditorFileToolResult(
      success: result.success,
      message: result.success
          ? '已生成 ${p.relative(output, from: projectPath)}'
          : result.error,
    );
  }
}
