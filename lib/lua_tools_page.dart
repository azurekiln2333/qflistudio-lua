import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/pages/tools_grid.dart';
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/widgets/tool_widgets.dart';

import 'lua_toolchain.dart';
import 'lua_tools.dart';
import 'lua_debugger_page.dart';
import 'script_tools_page.dart';

/// Product-owned body for the shared FunctionsTab.
///
/// The Lua tools are individual cards in the existing tools tab; there is
/// no gateway card and no nested Scaffold, because [ToolsGrid] already scrolls
/// inside the tab. Wire it from `main.dart` with
/// `toolsTabBuilder: buildLuaToolsTab`.
Widget buildLuaToolsTab(ProjectStore store, VoidCallback onOpenTerminal) =>
    ToolsGrid(
      onOpenTerminal: onOpenTerminal,
      sections: [
        ToolSection(
          title: 'Lua',
          icon: Icons.code,
          tools: [
            ToolDefinition(
              icon: Icons.bug_report_outlined,
              title: LuaDebuggerPage.title,
              description: LuaDebuggerPage.summary,
              builder: (_) => LuaDebuggerPage(store: store),
            ),
            ToolDefinition(
              icon: Icons.fact_check_outlined,
              title: LuaSyntaxCheckPage.title,
              description: LuaSyntaxCheckPage.summary,
              builder: (_) => LuaSyntaxCheckPage(store: store),
            ),
            ToolDefinition(
              icon: Icons.memory_outlined,
              title: LuaBytecodePage.title,
              description: LuaBytecodePage.summary,
              builder: (_) => LuaBytecodePage(store: store),
            ),
            ToolDefinition(
              icon: Icons.account_tree_outlined,
              title: LuaModuleResolverPage.title,
              description: LuaModuleResolverPage.summary,
              builder: (_) => LuaModuleResolverPage(store: store),
            ),
            ToolDefinition(
              icon: Icons.format_quote_outlined,
              title: LuaLiteralPage.title,
              description: LuaLiteralPage.summary,
              builder: (_) => const LuaLiteralPage(),
            ),
            ToolDefinition(
              icon: Icons.search_outlined,
              title: LuaPatternPage.title,
              description: LuaPatternPage.summary,
              builder: (_) => const LuaPatternPage(),
            ),
          ],
        ),
        ToolSection(
          title: 'JavaScript / TypeScript / Shell',
          icon: Icons.integration_instructions_outlined,
          tools: [
            ToolDefinition(
              icon: Icons.fact_check_outlined,
              title: JavaScriptSyntaxPage.title,
              description: JavaScriptSyntaxPage.summary,
              builder: (_) => const JavaScriptSyntaxPage(),
            ),
            ToolDefinition(
              icon: Icons.transform_outlined,
              title: TypeScriptTranspilePage.title,
              description: TypeScriptTranspilePage.summary,
              builder: (_) => const TypeScriptTranspilePage(),
            ),
            ToolDefinition(
              icon: Icons.terminal_outlined,
              title: ShellSyntaxPage.title,
              description: ShellSyntaxPage.summary,
              builder: (_) => const ShellSyntaxPage(),
            ),
          ],
        ),
      ],
    );

/// Picks the project (and optionally one of its files) for a tool page.
///
/// Kept as a small widget so every Lua tool selects files the same way and the
/// selection survives rebuilds through [LuaProjectFileController].
class _LuaProjectPicker extends StatelessWidget {
  const _LuaProjectPicker({required this.controller, this.showFiles = true});

  final LuaProjectFileController controller;
  final bool showFiles;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final projects = controller.projects;
        final project = controller.project;
        final files = controller.files;
        final file = controller.file;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (projects.isEmpty)
              const Text('没有本地项目，请先在首页创建或导入项目。')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('lua-project-${project?.id ?? ''}'),
                initialValue: project?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '项目'),
                items: [
                  for (final item in projects)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: controller.loading
                    ? null
                    : (id) => controller.selectProject(id),
              ),
              if (showFiles) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(
                          'lua-file-${project?.id ?? ''}-${file ?? ''}',
                        ),
                        initialValue: file,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Lua 文件'),
                        items: [
                          for (final path in files)
                            DropdownMenuItem(
                              value: path,
                              child: Text(
                                controller.label(path),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: controller.loading
                            ? null
                            : controller.selectFile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '刷新文件',
                      onPressed: controller.loading
                          ? null
                          : () => unawaited(controller.refresh()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (controller.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (files.isEmpty && project != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('项目中没有 Lua 文件'),
                  ),
              ],
            ],
            ToolError(controller.error),
          ],
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) => text == null || text!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(text!, style: Theme.of(context).textTheme.titleSmall),
        );
}

/// Reports real Lua syntax errors from the bundled parser.
class LuaSyntaxCheckPage extends StatefulWidget {
  const LuaSyntaxCheckPage({
    super.key,
    required this.store,
    this.toolchain = const LuaToolchain(),
  });

  static const String title = 'Lua 语法检查';
  static const String summary = '内置解析器检查项目文件或粘贴代码';

  final ProjectStore store;
  final LuaToolchain toolchain;

  @override
  State<LuaSyntaxCheckPage> createState() => _LuaSyntaxCheckPageState();
}

class _LuaSyntaxCheckPageState extends State<LuaSyntaxCheckPage> {
  late final LuaProjectFileController _files = LuaProjectFileController(
    store: widget.store,
  );
  final _snippet = TextEditingController(
    text:
        'local total = 0\nfor i = 1, 3 do\n  total = total + i\nend\nprint(total)',
  );
  String? _status;
  LuaSyntaxReport? _report;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _files.addListener(_onFilesChanged);
    unawaited(_files.refresh());
  }

  void _onFilesChanged() {
    if (!mounted) return;
    setState(() {
      _report = null;
      _status = null;
    });
  }

  @override
  void dispose() {
    _files.dispose();
    _snippet.dispose();
    super.dispose();
  }

  Future<void> _run(Future<LuaSyntaxReport> Function() task) async {
    if (_working) return;
    final selection = (_files.project?.id, _files.file, _snippet.text);
    setState(() {
      _working = true;
      _status = '正在检查';
      _report = null;
    });
    final report = await task();
    if (!mounted) return;
    setState(() {
      _working = false;
      if (selection != (_files.project?.id, _files.file, _snippet.text)) return;
      _report = report;
      _status = report.ok ? '语法正确' : '语法错误';
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final project = _files.project;
    final file = _files.file;
    return ToolScaffold(
      title: LuaSyntaxCheckPage.title,
      description: '使用内置 Lua 5.4 解析器检查语法，只解析不执行代码。项目文件不会被修改。',
      children: [
        _LuaProjectPicker(controller: _files),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _working || file == null || project == null
              ? null
              : () => _run(
                  () => checkLuaFile(
                    file,
                    relativeTo: project.path,
                    toolchain: widget.toolchain,
                  ),
                ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('检查项目文件'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        ToolField(
          controller: _snippet,
          label: '粘贴的代码',
          maxLines: 8,
          hint: '粘贴一段 Lua 代码，使用临时文件检查',
          onChanged: (_) => setState(() {
            _report = null;
            _status = null;
          }),
        ),
        FilledButton.tonalIcon(
          onPressed: _working
              ? null
              : () => _run(
                  () => checkLuaSource(
                    _snippet.text,
                    fileName: 'snippet.lua',
                    toolchain: widget.toolchain,
                  ),
                ),
          icon: const Icon(Icons.code),
          label: const Text('检查代码'),
        ),
        _StatusLine(_status),
        if (report != null) ...[
          const SizedBox(height: 12),
          if (report.ok)
            const ToolResultCard(title: '结果', children: [Text('解析器没有报告语法错误。')])
          else
            ToolResultCard(
              title: '诊断',
              children: [
                ResultRow(label: '文件', value: report.displayFile ?? ''),
                ResultRow(
                  label: '行号',
                  value: report.line == null ? '未知' : '${report.line}',
                ),
                ResultRow(label: '消息', value: report.message, monospace: false),
                if (report.sourceLine != null)
                  ResultRow(label: '源码', value: report.sourceLine!),
                if (report.raw.isNotEmpty)
                  ResultRow(label: '原始输出', value: report.raw, monospace: false),
              ],
            ),
        ],
      ],
    );
  }
}

/// Compiles a project file with the real VM and inspects the dump.
class LuaBytecodePage extends StatefulWidget {
  const LuaBytecodePage({
    super.key,
    required this.store,
    this.toolchain = const LuaToolchain(),
  });

  static const String title = 'Lua 字节码';
  static const String summary = '编译并检查 .luac 头部、函数与常量';

  final ProjectStore store;
  final LuaToolchain toolchain;

  @override
  State<LuaBytecodePage> createState() => _LuaBytecodePageState();
}

class _LuaBytecodePageState extends State<LuaBytecodePage> {
  late final LuaProjectFileController _files = LuaProjectFileController(
    store: widget.store,
    extensions: const ['.lua', '.luac'],
  );
  LuaBytecodeChunk? _chunk;
  String? _status;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _files.addListener(_onFilesChanged);
    unawaited(_files.refresh());
  }

  void _onFilesChanged() {
    if (!mounted) return;
    setState(() {
      _chunk = null;
      _status = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _files.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final file = _files.file;
    if (_working || file == null) return;
    setState(() {
      _working = true;
      _status = '正在编译并解析';
      _chunk = null;
      _error = null;
    });
    try {
      final chunk = p.extension(file).toLowerCase() == '.luac'
          ? parseLuaBytecode(await File(file).readAsBytes())
          : await inspectLuaBytecode(file, toolchain: widget.toolchain);
      if (!mounted) return;
      if (_files.file != file) return;
      setState(() {
        _chunk = chunk;
        _status = '字节码检查完成';
      });
    } on LuaBytecodeFormatException catch (exception) {
      if (!mounted || _files.file != file) return;
      setState(() {
        _error = exception.message;
        _status = '字节码检查失败';
      });
    } on Object catch (error) {
      if (!mounted || _files.file != file) return;
      setState(() {
        _error = '$error';
        _status = '字节码检查失败';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _compileToProject() async {
    final file = _files.file;
    final project = _files.project;
    if (_working || file == null || project == null) return;
    final output = p.setExtension(file, '.luac');
    setState(() {
      _working = true;
      _status = '正在准备字节码';
      _error = null;
    });
    try {
      var overwrite = false;
      if (await FileSystemEntity.type(output, followLinks: false) !=
          FileSystemEntityType.notFound) {
        if (!mounted) return;
        overwrite =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('替换已有字节码？'),
                content: Text(
                  '将备份并替换 ${p.relative(output, from: project.path)}。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('备份并替换'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!overwrite) {
          if (mounted) setState(() => _status = null);
          return;
        }
      }
      if (!mounted) return;
      setState(() => _status = '正在编译到项目');
      await compileLuaFileToProject(
        file,
        projectDirectory: project.path,
        overwrite: overwrite,
        toolchain: widget.toolchain,
      );
      if (!mounted) return;
      if (_files.file != file || _files.project?.id != project.id) return;
      setState(() => _status = '已生成 ${p.relative(output, from: project.path)}');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _status = '编译失败';
        _error = '$error';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chunk = _chunk;
    return ToolScaffold(
      title: LuaBytecodePage.title,
      description: '编译 Lua 源文件或检查已有 .luac 的头部、函数和常量。检查使用临时目录；生成到项目时会确认并备份已有文件。',
      children: [
        _LuaProjectPicker(controller: _files),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _working || _files.file == null ? null : _inspect,
              icon: const Icon(Icons.memory_outlined),
              label: Text(
                p.extension(_files.file ?? '').toLowerCase() == '.luac'
                    ? '检查字节码'
                    : '编译并检查',
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  _working ||
                      p.extension(_files.file ?? '').toLowerCase() != '.lua'
                  ? null
                  : _compileToProject,
              icon: const Icon(Icons.save_alt),
              label: const Text('生成 .luac 到项目'),
            ),
          ],
        ),
        _StatusLine(_status),
        ToolError(_error),
        if (chunk != null) ...[
          const SizedBox(height: 12),
          ToolResultCard(
            title: '头部',
            children: [
              ResultRow(
                label: '版本',
                value:
                    '0x${chunk.header.version.toRadixString(16)} (Lua ${chunk.header.versionMajor}.${chunk.header.versionMinor})',
              ),
              ResultRow(label: '格式', value: '${chunk.header.format}'),
              ResultRow(label: '文件大小', value: '${chunk.byteLength} 字节'),
              ResultRow(
                label: '校验',
                value: chunk.header.integerCheck && chunk.header.numberCheck
                    ? '通过（小端）'
                    : '未通过，字节序或宽度异常',
              ),
              ResultRow(
                label: '类型宽度',
                value:
                    '指令 ${chunk.header.instructionSize} / 整数 ${chunk.header.luaIntegerSize} / 浮点 ${chunk.header.luaNumberSize}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolResultCard(
            title: '统计',
            children: [
              ResultRow(label: '函数数', value: '${chunk.main.totalFunctions}'),
              ResultRow(label: '指令数', value: '${chunk.main.totalInstructions}'),
              ResultRow(
                label: '字符串常量',
                value: '${chunk.main.allStringConstants.length}',
              ),
              ResultRow(
                label: '主函数',
                value:
                    '行 ${chunk.main.lineDefined}-${chunk.main.lastLineDefined} · '
                    '参数 ${chunk.main.numParams} · 变长 ${chunk.main.isVararg != 0 ? '是' : '否'} · '
                    '栈 ${chunk.main.maxStackSize}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ToolResultCard(
            title: '函数原型',
            children: [
              for (final entry in _flattenFunctions(chunk.main))
                Padding(
                  padding: EdgeInsets.only(left: 12.0 * entry.$1, top: 4),
                  child: Text(
                    '${'函数 ${entry.$2.lineDefined}-${entry.$2.lastLineDefined}'}'
                    ' · 指令 ${entry.$2.instructionCount}'
                    ' · 常量 ${entry.$2.constants.length}'
                    ' · 栈 ${entry.$2.maxStackSize}'
                    ' · 参数 ${entry.$2.numParams}'
                    '${entry.$2.isVararg != 0 ? ' · 变长' : ''}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          if (chunk.main.constants.isNotEmpty) ...[
            const SizedBox(height: 12),
            ToolResultCard(
              title: '主函数常量',
              children: [
                for (final value in chunk.main.constants)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

List<(int, LuaBytecodeFunction)> _flattenFunctions(
  LuaBytecodeFunction function, [
  int depth = 0,
]) => [
  (depth, function),
  for (final child in function.children) ..._flattenFunctions(child, depth + 1),
];

/// Resolves `require` names with the runtime's own `package.searchpath`.
class LuaModuleResolverPage extends StatefulWidget {
  const LuaModuleResolverPage({
    super.key,
    required this.store,
    this.toolchain = const LuaToolchain(),
  });

  static const String title = 'Lua 模块解析';
  static const String summary = '按运行时 package.path 解析 require 与项目依赖';

  final ProjectStore store;
  final LuaToolchain toolchain;

  @override
  State<LuaModuleResolverPage> createState() => _LuaModuleResolverPageState();
}

class _LuaModuleResolverPageState extends State<LuaModuleResolverPage> {
  late final LuaProjectFileController _files = LuaProjectFileController(
    store: widget.store,
  );
  final _module = TextEditingController(text: 'util');
  LuaModuleResolution? _resolution;
  LuaModuleSearch? _search;
  LuaProjectScan? _scan;
  String? _status;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _files.addListener(_onFilesChanged);
    unawaited(_files.refresh());
  }

  void _onFilesChanged() {
    if (!mounted) return;
    setState(() {
      _resolution = null;
      _search = null;
      _scan = null;
      _status = null;
    });
  }

  @override
  void dispose() {
    _files.dispose();
    _module.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final project = _files.project;
    if (_working || project == null) return;
    final module = _module.text.trim();
    if (module.isEmpty) {
      setState(() {
        _status = '请输入模块名';
        _resolution = null;
        _search = null;
      });
      return;
    }
    setState(() {
      _working = true;
      _status = '正在解析';
      _resolution = null;
      _search = null;
    });
    final search = await resolveLuaModules(
      projectDirectory: project.path,
      modules: [module],
      toolchain: widget.toolchain,
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      if (_files.project?.id != project.id || _module.text.trim() != module) {
        return;
      }
      _search = search;
      _resolution = search.forModule(module);
      _status = search.error != null
          ? '解析失败'
          : (_resolution?.resolved ?? false ? '已解析' : '未找到');
    });
  }

  Future<void> _scanProject() async {
    final project = _files.project;
    if (_working || project == null) return;
    setState(() {
      _working = true;
      _status = '正在扫描项目依赖';
      _scan = null;
      _resolution = null;
      _search = null;
    });
    final scan = await scanLuaProject(
      projectDirectory: project.path,
      toolchain: widget.toolchain,
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      if (_files.project?.id != project.id) return;
      _scan = scan;
      _status = scan.error != null
          ? '扫描失败'
          : '扫描完成 · ${scan.unresolved.length} 个未解析模块';
    });
  }

  @override
  Widget build(BuildContext context) {
    final project = _files.project;
    final resolution = _resolution;
    final scan = _scan;
    return ToolScaffold(
      title: LuaModuleResolverPage.title,
      description:
          '用内置运行时真实的 package.searchpath 解析模块：项目根目录的 ?.lua、?/init.lua、src/?.lua、src/?/init.lua 优先，其余为运行时默认路径。',
      children: [
        _LuaProjectPicker(controller: _files, showFiles: false),
        const SizedBox(height: 16),
        ToolField(
          controller: _module,
          label: '模块名',
          hint: '例如 util、pkg.init、json',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _working || project == null ? null : _resolve,
              icon: const Icon(Icons.search),
              label: const Text('解析模块'),
            ),
            OutlinedButton.icon(
              onPressed: _working || project == null ? null : _scanProject,
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('扫描项目 require'),
            ),
          ],
        ),
        if (_working)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        _StatusLine(_status),
        if (resolution != null) ...[
          const SizedBox(height: 12),
          ToolResultCard(
            title: '解析结果',
            children: [
              ResultRow(label: '模块', value: resolution.module),
              ResultRow(
                label: '命中文件',
                value: resolution.builtIn
                    ? '内置标准库'
                    : resolution.file == null
                    ? '未找到'
                    : (project == null
                          ? p.normalize(resolution.file!)
                          : p.normalize(
                              p.relative(resolution.file!, from: project.path),
                            )),
              ),
              if (resolution.file != null)
                ResultRow(label: '绝对路径', value: p.normalize(resolution.file!)),
              for (final candidate in resolution.searched)
                ResultRow(
                  label: '已尝试',
                  value: project == null
                      ? p.normalize(candidate)
                      : p.normalize(p.relative(candidate, from: project.path)),
                ),
            ],
          ),
        ],
        if (_search != null && _search!.packagePath.isNotEmpty) ...[
          const SizedBox(height: 12),
          ToolResultCard(
            title: '运行时 package.path',
            children: [
              SelectableText(
                _search!.packagePath.split(';').join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ),
        ],
        if (scan != null) ...[
          const SizedBox(height: 12),
          ToolResultCard(
            title: '项目依赖',
            children: [
              ResultRow(label: '文件数', value: '${scan.entries.length}'),
              ResultRow(
                label: '未解析模块',
                value: scan.unresolved.isEmpty
                    ? '无'
                    : scan.unresolved.join(', '),
              ),
              ResultRow(
                label: '动态 require',
                value: '${scan.dynamicRequires} 处（参数不是字面量）',
              ),
              if (scan.truncated)
                ResultRow(
                  label: '提示',
                  value: '文件数超过上限，仅扫描了前 $maxProjectFiles 个文件',
                  monospace: false,
                ),
              if (scan.error != null)
                ResultRow(label: '错误', value: scan.error!, monospace: false),
            ],
          ),
          const SizedBox(height: 12),
          ToolResultCard(
            title: '每个文件的 require',
            children: [
              for (final entry in scan.entries)
                if (entry.requires.isNotEmpty || entry.dynamicRequires > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          entry.relativePath,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        for (final reference in entry.requires)
                          Text(
                            '  第 ${reference.line} 行 → ${reference.module}'
                            '${_requireState(scan, reference.module)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        if (entry.dynamicRequires > 0)
                          Text(
                            '  ${entry.dynamicRequires} 处动态 require 无法静态解析',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ],
    );
  }

  static String _requireState(LuaProjectScan scan, String module) {
    final resolution = scan.resolutions[module];
    if (resolution == null) return ' · 未解析';
    if (resolution.builtIn) return ' · 内置标准库';
    final file = resolution.file;
    if (file == null) return ' · 缺失';
    return ' · ${p.basename(file)}';
  }
}

/// Escapes and parses Lua string literals without executing anything.
class LuaLiteralPage extends StatefulWidget {
  const LuaLiteralPage({super.key});

  static const String title = 'Lua 字符串字面量';
  static const String summary = '文本与 Lua 转义字面量互转';

  @override
  State<LuaLiteralPage> createState() => _LuaLiteralPageState();
}

class _LuaLiteralPageState extends State<LuaLiteralPage> {
  final _plain = TextEditingController(text: '第一行\n"引号" 与 \\ 反斜杠');
  final _literal = TextEditingController();
  var _escapeNonAscii = false;

  @override
  void dispose() {
    _plain.dispose();
    _literal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encoded = LuaStringLiteral.encode(
      _plain.text,
      escapeNonAscii: _escapeNonAscii,
    );
    final decoded = LuaStringLiteral.decode(_literal.text);
    return ToolScaffold(
      title: LuaLiteralPage.title,
      description: '按 Lua 5.4 规则转义文本，或把已有字面量还原成文本与原始字节；完全离线。',
      children: [
        ToolField(
          controller: _plain,
          label: '原始文本',
          maxLines: 6,
          onChanged: (_) => setState(() {}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('非 ASCII 转义为 \\u{...}'),
          value: _escapeNonAscii,
          onChanged: (value) => setState(() => _escapeNonAscii = value),
        ),
        ToolResultCard(
          title: 'Lua 字面量',
          children: [
            ResultRow(label: '双引号', value: encoded),
            ResultRow(
              label: '长括号',
              value: LuaStringLiteral.encodeLongBracket(_plain.text),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        ToolField(
          controller: _literal,
          label: 'Lua 字面量',
          maxLines: 4,
          hint: r'"第一行\n第二行" 或 [[原样文本]]',
          onChanged: (_) => setState(() {}),
        ),
        ToolError(decoded.error),
        if (decoded.ok)
          ToolResultCard(
            title: '还原结果',
            children: [
              ResultRow(label: '内容', value: decoded.value!),
              ResultRow(label: '字符数', value: '${decoded.value!.runes.length}'),
              ResultRow(label: 'Lua 字节数', value: '${decoded.bytes!.length}'),
              ResultRow(
                label: '十六进制字节',
                value: decoded.bytes!
                    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                    .join(' '),
              ),
              if (decoded.hasMalformedUtf8)
                const Text('包含非 UTF-8 字节；文本预览用 � 显示，十六进制保留原字节。'),
            ],
          ),
      ],
    );
  }
}

/// Runs Lua patterns in the real VM, including captures and `gsub`.
class LuaPatternPage extends StatefulWidget {
  const LuaPatternPage({super.key, this.toolchain = const LuaToolchain()});

  static const String title = 'Lua 模式匹配';
  static const String summary = '用真实 Lua 引擎测试模式、捕获与替换';

  final LuaToolchain toolchain;

  @override
  State<LuaPatternPage> createState() => _LuaPatternPageState();
}

class _LuaPatternPageState extends State<LuaPatternPage> {
  final _subject = TextEditingController(text: 'a=1, b=22, c=333');
  final _pattern = TextEditingController(text: '(%a+)=(%d+)');
  final _replacement = TextEditingController(text: '%2=%1');
  var _plain = false;
  LuaPatternExecution? _execution;
  LuaPatternOutcome? _outcome;
  String? _status;

  @override
  void dispose() {
    unawaited(_execution?.cancel());
    _subject.dispose();
    _pattern.dispose();
    _replacement.dispose();
    super.dispose();
  }

  bool get _working => _execution != null;

  Future<void> _run() async {
    if (_working) return;
    final LuaPatternExecution execution;
    try {
      execution = startLuaPattern(
        subject: _subject.text,
        pattern: _pattern.text,
        replacement: _replacement.text,
        plain: _plain,
        toolchain: widget.toolchain,
      );
    } on Object catch (error) {
      setState(() {
        _outcome = LuaPatternOutcome.failure('$error');
        _status = '模式错误';
      });
      return;
    }
    setState(() {
      _execution = execution;
      _outcome = null;
      _status = '正在运行';
    });
    final outcome = await execution.result;
    if (!mounted) return;
    setState(() {
      _execution = null;
      _outcome = outcome;
      _status = outcome.ok ? '运行完成' : '模式错误';
    });
  }

  Future<void> _cancel() async {
    final execution = _execution;
    if (execution == null) return;
    setState(() => _status = '正在取消');
    await execution.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final outcome = _outcome;
    return ToolScaffold(
      title: LuaPatternPage.title,
      description:
          'Lua 模式不是正则表达式。这里在真实 Lua 5.4 中执行 string.find / string.gsub，位置按字节从 1 开始。',
      children: [
        ToolField(controller: _subject, label: '待匹配文本', maxLines: 4),
        ToolField(controller: _pattern, label: 'Lua 模式'),
        ToolField(
          controller: _replacement,
          label: '替换字符串',
          hint: r'支持 %1、%2 与 %%',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('纯文本查找（不使用模式）'),
          value: _plain,
          onChanged: (value) => setState(() => _plain = value),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _working ? null : _run,
              icon: const Icon(Icons.play_arrow),
              label: const Text('运行模式'),
            ),
            OutlinedButton.icon(
              onPressed: _working ? _cancel : null,
              icon: const Icon(Icons.stop),
              label: const Text('取消'),
            ),
          ],
        ),
        if (_working)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        _StatusLine(_status),
        if (outcome != null) ...[
          const SizedBox(height: 12),
          ToolError(outcome.error),
          if (outcome.ok) ...[
            ToolResultCard(
              title: '匹配',
              children: [
                ResultRow(label: '匹配数', value: '${outcome.matches.length}'),
                for (final match in outcome.matches)
                  ResultRow(
                    label: '${match.start}-${match.end}',
                    value: match.captures.isEmpty
                        ? match.text
                        : '${match.text}  →  ${match.captures.join(' | ')}',
                  ),
                if (outcome.truncated)
                  const ResultRow(
                    label: '提示',
                    value: '匹配数达到上限，只显示前 50 条',
                    monospace: false,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ToolResultCard(
              title: '替换结果',
              children: [
                ResultRow(label: '替换次数', value: '${outcome.replacementCount}'),
                ResultRow(label: '结果', value: outcome.replaced),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
