import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/styles/github.dart';

import 'platform_stub.dart'
    if (dart.library.js_interop) 'platform_browser.dart'
    as platform;
import 'workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QfliWebApp());
}

class QfliWebApp extends StatelessWidget {
  const QfliWebApp({super.key, this.workspace, this.fileTransfer});

  final WebWorkspace? workspace;
  final SourceFileTransfer? fileTransfer;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'QFLIScript Web',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff526b43)),
      useMaterial3: true,
    ),
    home: _WorkspacePage(workspace: workspace, fileTransfer: fileTransfer),
  );
}

class _WorkspacePage extends StatefulWidget {
  const _WorkspacePage({this.workspace, this.fileTransfer});

  final WebWorkspace? workspace;
  final SourceFileTransfer? fileTransfer;

  @override
  State<_WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<_WorkspacePage> {
  late final WebWorkspace _workspace;
  late final SourceFileTransfer _fileTransfer;
  late final VoidCallback _stopWatching;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _workspace = widget.workspace ?? WebWorkspace(platform.createStorage());
    _fileTransfer = widget.fileTransfer ?? platform.createFileTransfer();
    _workspace.addListener(_refresh);
    _stopWatching = platform.watchUnsavedChanges(_workspace);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _stopWatching();
    _workspace.removeListener(_refresh);
    if (widget.workspace == null) _workspace.dispose();
    super.dispose();
  }

  Future<void> _nameFile({WorkspaceFile? file}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FileNameDialog(workspace: _workspace, file: file),
    );
    if (name == null || !mounted) return;
    if (file == null) {
      _workspace.createFile(name);
    } else {
      _workspace.renameFile(file.id, name);
    }
  }

  Future<void> _deleteFile(WorkspaceFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件？'),
        content: Text('将删除 ${file.name} 及其未保存内容。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _workspace.deleteFile(file.id);
  }

  Future<void> _importFiles() async {
    setState(() => _importing = true);
    try {
      final files = await _fileTransfer.importFiles();
      if (mounted) _workspace.importFiles(files);
    } catch (_) {
      if (mounted) _showMessage('导入失败。请选择 UTF-8 文本文件。');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _exportFile(SourceFile file) {
    try {
      _fileTransfer.exportFile(file);
    } catch (_) {
      _showMessage('导出失败。请检查浏览器下载权限。');
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final selected = _workspace.selectedFile;
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _workspace.save,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _workspace.save,
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('QFLIScript Web')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const Key('save-workspace'),
                      onPressed: _workspace.saveBlocked
                          ? null
                          : _workspace.save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('保存'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _nameFile(),
                      icon: const Icon(Icons.add),
                      label: const Text('新建文件'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importing ? null : _importFiles,
                      icon: const Icon(Icons.file_open_outlined),
                      label: Text(_importing ? '正在导入' : '导入'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selected == null
                          ? null
                          : () => _exportFile(selected),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('导出当前文件'),
                    ),
                    Text(
                      _workspace.storageError != null
                          ? '保存不可用'
                          : _workspace.isDirty
                          ? '未保存'
                          : '已保存到此浏览器',
                      key: const Key('save-status'),
                      style: TextStyle(
                        color: _workspace.storageError != null
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '文件保存在此浏览器。删除网站数据会删除文件。请定期导出。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_workspace.storageError != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(12),
                  color: colors.errorContainer,
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_workspace.storageError!),
                      if (_workspace.recoveryData != null)
                        TextButton(
                          onPressed: () => _exportFile(
                            SourceFile(
                              name: 'qfliscript-workspace-recovery.json',
                              content: _workspace.recoveryData!,
                            ),
                          ),
                          child: const Text('导出原始数据'),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Web 版仅支持编辑和保存。原生运行不可用。'),
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('运行'),
                    ),
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: const Text('调试'),
                    ),
                    TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.build_outlined),
                      label: const Text('编译'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 56,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final file in _workspace.files)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: ValueKey('file-${file.id}'),
                          label: Text(file.name),
                          selected: file.id == selected?.id,
                          onSelected: (_) => _workspace.selectFile(file.id),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _nameFile(file: selected),
                        child: const Text('重命名'),
                      ),
                      TextButton(
                        onPressed: () => _deleteFile(selected),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('新建或导入文件以开始编辑。'))
                    : _SourceEditor(
                        key: ValueKey(selected.id),
                        file: selected,
                        workspace: _workspace,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceEditor extends StatefulWidget {
  const _SourceEditor({super.key, required this.file, required this.workspace});

  final WorkspaceFile file;
  final WebWorkspace workspace;

  @override
  State<_SourceEditor> createState() => _SourceEditorState();
}

class _SourceEditorState extends State<_SourceEditor> {
  late final CodeLineEditingController _controller;
  late CodeLines _lastLines;

  @override
  void initState() {
    super.initState();
    final source = widget.file.content;
    final lineBreak = source.contains('\r\n')
        ? TextLineBreak.crlf
        : source.contains('\r')
        ? TextLineBreak.cr
        : TextLineBreak.lf;
    _controller = CodeLineEditingController.fromText(
      source,
      CodeLineOptions(lineBreak: lineBreak),
    );
    _lastLines = _controller.codeLines;
    _controller.addListener(_onEdit);
  }

  void _onEdit() {
    if (_controller.codeLines == _lastLines) return;
    _lastLines = _controller.codeLines;
    widget.workspace.editFile(widget.file.id, _controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onEdit);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extension = widget.file.name.split('.').last.toLowerCase();
    final mode = switch (extension) {
      'lua' => langLua,
      'js' || 'mjs' => langJavascript,
      'ts' => langTypescript,
      'sh' => langBash,
      'json' => langJson,
      _ => null,
    };
    return CodeEditor(
      controller: _controller,
      wordWrap: false,
      padding: const EdgeInsets.all(12),
      style: CodeEditorStyle(
        fontSize: 15,
        fontFamily: 'monospace',
        backgroundColor: Theme.of(context).colorScheme.surface,
        codeTheme: mode == null
            ? null
            : CodeHighlightTheme(
                languages: {extension: CodeHighlightThemeMode(mode: mode)},
                language: extension,
                theme: githubTheme,
              ),
      ),
      indicatorBuilder: (context, controller, chunks, notifier) =>
          DefaultCodeLineNumber(controller: controller, notifier: notifier),
    );
  }
}

class _FileNameDialog extends StatefulWidget {
  const _FileNameDialog({required this.workspace, this.file});

  final WebWorkspace workspace;
  final WorkspaceFile? file;

  @override
  State<_FileNameDialog> createState() => _FileNameDialogState();
}

class _FileNameDialogState extends State<_FileNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.file?.name ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.file == null ? '新建文件' : '重命名文件'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '文件名',
          hintText: 'main.lua',
        ),
        validator: (value) => widget.workspace.validateName(
          value ?? '',
          exceptId: widget.file?.id,
        ),
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}
