import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/code_analysis.dart';
import 'package:qfli_studio_core/widgets/tool_widgets.dart';

import 'script_toolchain.dart';
import 'shell_code_analyzer.dart';

/// Checks pasted JavaScript with the embedded parser without evaluating it.
class JavaScriptSyntaxPage extends StatelessWidget {
  const JavaScriptSyntaxPage({
    super.key,
    this.toolchain = const ScriptToolchain(),
  });

  static const title = 'JavaScript 语法检查';
  static const summary = '内置解析器检查粘贴代码，不执行代码';

  final ScriptToolchain toolchain;

  @override
  Widget build(BuildContext context) =>
      _SourceToolPage(kind: _ToolKind.javascript, toolchain: toolchain);
}

/// Displays actual JavaScript emitted by the bundled TypeScript compiler.
class TypeScriptTranspilePage extends StatelessWidget {
  const TypeScriptTranspilePage({
    super.key,
    this.toolchain = const ScriptToolchain(),
  });

  static const title = 'TypeScript 转译';
  static const summary = '生成 JavaScript 并报告语法诊断';

  final ScriptToolchain toolchain;

  @override
  Widget build(BuildContext context) =>
      _SourceToolPage(kind: _ToolKind.typescript, toolchain: toolchain);
}

/// Checks pasted Shell source through a real local POSIX shell's `-n` mode.
class ShellSyntaxPage extends StatelessWidget {
  const ShellSyntaxPage({super.key, this.analyzer = const ShellCodeAnalyzer()});

  static const title = 'Shell 语法检查';
  static const summary = '使用本机 POSIX Shell 检查，不执行命令';

  final CodeAnalyzer analyzer;

  @override
  Widget build(BuildContext context) =>
      _SourceToolPage(kind: _ToolKind.shell, analyzer: analyzer);
}

enum _ToolKind {
  javascript,
  typescript,
  shell;

  String get title => switch (this) {
    javascript => JavaScriptSyntaxPage.title,
    typescript => TypeScriptTranspilePage.title,
    shell => ShellSyntaxPage.title,
  };

  String get language => switch (this) {
    javascript => 'JavaScript',
    typescript => 'TypeScript',
    shell => 'Shell',
  };

  String get description => switch (this) {
    javascript => '使用内置解析器检查原文（ES 模块语法），不执行代码或加载导入。',
    typescript =>
      '使用内置 TypeScript 编译器生成 JavaScript，报告语法与编译选项诊断；不进行项目级类型检查，也不执行代码。',
    shell => '使用本机 POSIX Shell 的 -n 模式检查原文，不执行命令；没有可用解析器时会显示原因。',
  };

  String get action => this == typescript ? '转译为 JavaScript' : '检查语法';
  String get pending => this == typescript ? '正在转译…' : '正在检查…';
  String get completed => this == typescript ? '转译完成' : '语法检查通过';
}

class _SourceToolPage extends StatefulWidget {
  const _SourceToolPage({
    required this.kind,
    this.toolchain = const ScriptToolchain(),
    this.analyzer = const ShellCodeAnalyzer(),
  });

  final _ToolKind kind;
  final ScriptToolchain toolchain;
  final CodeAnalyzer analyzer;

  @override
  State<_SourceToolPage> createState() => _SourceToolPageState();
}

class _SourceToolPageState extends State<_SourceToolPage> {
  final _source = TextEditingController();
  String _lastSource = '';
  int _revision = 0;
  bool _working = false;
  String? _notice;
  _ToolReport? _report;

  @override
  void initState() {
    super.initState();
    _source.addListener(_sourceChanged);
  }

  void _sourceChanged() {
    // Selection and composing-region updates do not change the source revision.
    if (_lastSource == _source.text) return;
    _lastSource = _source.text;
    setState(() {
      _revision++;
      _report = null;
      _notice = _working ? '输入已更改，当前结果将被忽略。' : null;
    });
  }

  @override
  void didUpdateWidget(covariant _SourceToolPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.toolchain != widget.toolchain ||
        oldWidget.analyzer != widget.analyzer) {
      _revision++;
      _report = null;
      _notice = _working ? '工具已更改，当前结果将被忽略。' : null;
    }
  }

  @override
  void dispose() {
    _source.removeListener(_sourceChanged);
    _source.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_working) return;
    final source = _source.text;
    final revision = _revision;
    final kind = widget.kind;
    final toolchain = widget.toolchain;
    final analyzer = widget.analyzer;
    setState(() {
      _working = true;
      _report = null;
      _notice = null;
    });

    _ToolReport report;
    try {
      if (kind == _ToolKind.shell) {
        // The analyzer needs document identity, but only consumes this in-memory
        // snapshot. Neither the logical directory nor source file is created.
        final root = p.join(
          Directory.systemTemp.absolute.path,
          'qfli-shell-tool',
        );
        final path = p.join(root, 'snippet.sh');
        final result = await analyzer.analyze(
          CodeAnalysisRequest(
            projectPath: root,
            activeFilePath: path,
            language: 'Shell',
            revision: revision,
            documents: [
              CodeDocumentSnapshot(
                path: path,
                text: source,
                revision: revision,
              ),
            ],
          ),
        );
        report = _ToolReport.fromShell(result);
      } else {
        final result = kind == _ToolKind.typescript
            ? await toolchain.transpile(source, fileName: 'snippet.ts')
            : await toolchain.checkSource(source, fileName: 'snippet.js');
        report = _ToolReport.fromScript(
          result,
          showOutput: kind == _ToolKind.typescript,
        );
      }
    } catch (error) {
      report = _ToolReport(success: false, error: '无法完成操作：$error');
    }

    if (!mounted) return;
    setState(() {
      _working = false;
      if (revision == _revision) {
        _report = report;
      } else {
        _notice = '输入或工具已更改，请重新${widget.kind.action}。';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final report = _report;
    return ToolScaffold(
      title: kind.title,
      description: kind.description,
      children: [
        ToolField(
          key: const Key('script-tool-source'),
          controller: _source,
          label: '${kind.language} 源码',
          hint: '在此粘贴要${kind.action}的完整代码',
          maxLines: 12,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('script-tool-run'),
          onPressed: _working ? null : _run,
          icon: Icon(
            kind == _ToolKind.typescript
                ? Icons.transform
                : Icons.fact_check_outlined,
          ),
          label: Text(kind.action),
        ),
        if (_working) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(key: Key('script-tool-pending')),
          const SizedBox(height: 8),
          Text(kind.pending),
        ],
        if (_notice != null) ...[const SizedBox(height: 12), Text(_notice!)],
        if (report != null) ...[
          const SizedBox(height: 20),
          Text(
            report.unavailableReason != null
                ? '后端不可用'
                : report.diagnostics.isNotEmpty
                ? '发现 ${report.diagnostics.length} 个诊断'
                : report.success
                ? kind.completed
                : '操作失败',
            key: const Key('script-tool-status'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ToolError(report.unavailableReason ?? report.error),
          for (var i = 0; i < report.diagnostics.length; i++) ...[
            const SizedBox(height: 12),
            _DiagnosticCard(
              diagnostic: report.diagnostics[i],
              source: _source.text,
              index: i,
            ),
          ],
          if (report.output != null && report.unavailableReason == null) ...[
            const SizedBox(height: 16),
            ToolResultCard(
              title: '生成的 JavaScript',
              children: [
                if (report.output!.isEmpty)
                  const Text('（没有生成 JavaScript 文本）')
                else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: '复制 JavaScript',
                      onPressed: () => Copy.copy(context, report.output!),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ),
                  SelectableText(
                    report.output!,
                    key: const Key('script-tool-output'),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ToolReport {
  const _ToolReport({
    required this.success,
    this.error,
    this.unavailableReason,
    this.output,
    this.diagnostics = const [],
  });

  factory _ToolReport.fromScript(
    ScriptToolResult result, {
    required bool showOutput,
  }) => _ToolReport(
    success: result.success,
    unavailableReason: result.unavailableReason,
    error: !result.success && result.diagnostics.isEmpty
        ? (result.error.isEmpty ? '操作失败（状态 ${result.status}）。' : result.error)
        : null,
    output: showOutput ? result.output : null,
    diagnostics: [
      for (final diagnostic in result.diagnostics)
        _ToolDiagnostic(
          startOffset: diagnostic.startOffset,
          message: diagnostic.message,
          code: diagnostic.code,
          severity: switch (diagnostic.category) {
            0 => '警告',
            2 => '建议',
            3 => '信息',
            _ => '错误',
          },
        ),
    ],
  );

  factory _ToolReport.fromShell(CodeAnalysisResult result) => _ToolReport(
    success:
        result.unavailableReason == null &&
        !result.diagnostics.any(
          (diagnostic) => diagnostic.severity == CodeDiagnosticSeverity.error,
        ),
    unavailableReason: result.unavailableReason,
    diagnostics: [
      for (final diagnostic in result.diagnostics)
        _ToolDiagnostic(
          startOffset: diagnostic.startOffset,
          message: diagnostic.message,
          code: diagnostic.code,
          severity: switch (diagnostic.severity) {
            CodeDiagnosticSeverity.error => '错误',
            CodeDiagnosticSeverity.warning => '警告',
            CodeDiagnosticSeverity.information => '信息',
            CodeDiagnosticSeverity.hint => '建议',
          },
        ),
    ],
  );

  final bool success;
  final String? error;
  final String? unavailableReason;
  final String? output;
  final List<_ToolDiagnostic> diagnostics;
}

class _ToolDiagnostic {
  const _ToolDiagnostic({
    required this.startOffset,
    required this.message,
    required this.code,
    required this.severity,
  });

  final int startOffset;
  final String message;
  final String code;
  final String severity;
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({
    required this.diagnostic,
    required this.source,
    required this.index,
  });

  final _ToolDiagnostic diagnostic;
  final String source;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (line, column) = _lineColumn(source, diagnostic.startOffset);
    final code = diagnostic.code.isEmpty ? '' : ' · ${diagnostic.code}';
    return ToolResultCard(
      title: '第 $line 行，第 $column 列 · ${diagnostic.severity}$code',
      children: [
        SelectableText(
          diagnostic.message,
          key: ValueKey('script-tool-diagnostic-$index'),
        ),
      ],
    );
  }
}

/// Diagnostic offsets and columns use the original UTF-16 text, including CRLF.
(int, int) _lineColumn(String source, int offset) {
  final end = offset.clamp(0, source.length);
  var line = 1;
  var column = 1;
  for (var i = 0; i < end; i++) {
    final unit = source.codeUnitAt(i);
    if (unit == 13 || unit == 10) {
      line++;
      column = 1;
      if (unit == 13 && i + 1 < end && source.codeUnitAt(i + 1) == 10) {
        i++;
      }
    } else {
      column++;
    }
  }
  return (line, column);
}
