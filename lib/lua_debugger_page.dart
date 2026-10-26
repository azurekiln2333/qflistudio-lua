import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/store/project_store.dart';
import 'package:qfli_studio_core/widgets/tool_widgets.dart';

import 'lua_debugger.dart';
import 'lua_tools.dart';

/// Individual offline tool page backed by the embedded VM's actual line hooks.
class LuaDebuggerPage extends StatefulWidget {
  const LuaDebuggerPage({
    super.key,
    this.store,
    this.projectPath,
    this.initialFile,
    this.libraryPath,
  }) : assert(store != null || projectPath != null);

  static const title = 'Lua 源码调试';
  static const summary = '离线断点、单步、调用栈和局部变量';
  final ProjectStore? store;
  final String? projectPath;
  final String? initialFile;
  final String? libraryPath;

  @override
  State<LuaDebuggerPage> createState() => _LuaDebuggerPageState();
}

class _LuaDebuggerPageState extends State<LuaDebuggerPage> {
  LuaProjectFileController? _files;
  LuaDebugger? _session;
  StreamSubscription<LuaDebugSnapshot>? _subscription;
  LuaDebugSnapshot? _snapshot;
  String? _root, _entry, _sourceFile, _error;
  List<String> _source = const [];
  final _breakpoints = <String, Set<int>>{};
  final _sourceCache = <String, List<String>>{};
  int _selectionGeneration = 0, _sourceGeneration = 0, _selectedFrame = 0;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    if (store != null) {
      _files = LuaProjectFileController(store: store)
        ..addListener(_selectionChanged);
      unawaited(_files!.refresh());
    } else {
      _root = widget.projectPath;
      _entry = widget.initialFile ?? p.join(_root!, 'main.lua');
      unawaited(_readSource(_entry!));
    }
  }

  void _selectionChanged() {
    if (!mounted) return;
    final root = _files?.project?.path;
    final entry = _files?.file;
    if (root != _root || entry != _entry) {
      _selectionGeneration++;
      _sourceGeneration++;
      final old = _session;
      _session = null;
      unawaited(_subscription?.cancel());
      _subscription = null;
      if (old != null) unawaited(old.dispose());
      _root = root;
      _entry = entry;
      _snapshot = null;
      _source = const [];
      _sourceFile = null;
      _breakpoints.clear();
      _sourceCache.clear();
      _error = null;
      if (entry != null) unawaited(_readSource(entry));
    }
    setState(() {});
  }

  Future<void> _readSource(String file) async {
    final generation = ++_sourceGeneration;
    if (mounted) {
      setState(() {
        _sourceFile = null;
        _source = const [];
      });
    }
    try {
      final root = _root;
      if (root == null || !p.isAbsolute(file) || !p.isWithin(root, file)) {
        return;
      }
      final cached = _sourceCache[file];
      if (cached != null) {
        if (mounted) {
          setState(() {
            _sourceFile = file;
            _source = cached;
          });
        }
        return;
      }
      final source = File(file);
      if (await source.length() > 512 * 1024) {
        throw const FileSystemException('源码预览限 512 KiB');
      }
      final lines = (await source.readAsLines()).take(2000).toList();
      if (!mounted || generation != _sourceGeneration) return;
      if (_session != null) _sourceCache[file] = List.unmodifiable(lines);
      setState(() {
        _sourceFile = file;
        _source = lines;
      });
    } catch (error) {
      if (mounted && generation == _sourceGeneration) {
        setState(() {
          _error = '$error';
        });
      }
    }
  }

  List<LuaBreakpoint> get _allBreakpoints => [
    for (final entry in _breakpoints.entries)
      for (final line in entry.value) LuaBreakpoint(entry.key, line),
  ];

  Future<void> _start() async {
    final root = _root, entry = _entry;
    if (root == null || entry == null || _starting) return;
    final generation = _selectionGeneration;
    setState(() {
      _starting = true;
      _error = null;
      _snapshot = null;
    });
    try {
      await _subscription?.cancel();
      final previous = _session;
      _session = null;
      await previous?.dispose();
      _sourceCache.clear();
      await _readSource(entry);
      if (!mounted || generation != _selectionGeneration) return;
      if (_sourceFile != null && p.equals(_sourceFile!, entry)) {
        _sourceCache[entry] = List.unmodifiable(_source);
      }
      final session = await LuaDebugger.start(
        file: entry,
        projectDirectory: root,
        libraryPath: widget.libraryPath,
      );
      if (!mounted || generation != _selectionGeneration) {
        await session.dispose();
        return;
      }
      _session = session;
      _subscription = session.updates.listen((snapshot) {
        if (mounted && identical(_session, session)) _receive(snapshot);
      });
      await session.setBreakpoints(_allBreakpoints);
      _receive(session.snapshot);
    } catch (error) {
      if (mounted && generation == _selectionGeneration) {
        setState(() {
          _error = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
        });
      }
    }
  }

  void _receive(LuaDebugSnapshot snapshot) {
    setState(() {
      _snapshot = snapshot;
      _selectedFrame = 0;
    });
    if (snapshot.frames.isNotEmpty) {
      _showFrameSource(snapshot.frames.first);
    }
  }

  void _showFrameSource(LuaDebugFrame frame) {
    if (frame.fileBacked && frame.line > 0) {
      unawaited(_readSource(frame.file));
      return;
    }
    // Generated chunk labels may look exactly like project file paths. Only
    // Lua's @ source marker establishes that a frame represents a disk file.
    _sourceGeneration++;
    setState(() {
      _sourceFile = null;
      _source = const [];
    });
  }

  Future<void> _act(Future<Object?> Function(LuaDebugger) action) async {
    final session = _session;
    if (session == null) return;
    try {
      await action(session);
    } catch (error) {
      if (mounted && identical(session, _session)) {
        setState(() {
          _error = '$error';
        });
      }
    }
  }

  Future<void> _toggle(int line) async {
    final file = _sourceFile;
    if (file == null) return;
    final lines = _breakpoints.putIfAbsent(file, () => {});
    final existed = lines.remove(line);
    if (!existed) lines.add(line);
    final generation = _selectionGeneration;
    setState(() {});
    final session = _session;
    if (session != null) {
      try {
        await session.setBreakpoints(_allBreakpoints);
      } catch (error) {
        if (mounted && generation == _selectionGeneration) {
          setState(() {
            if (existed) {
              lines.add(line);
            } else {
              lines.remove(line);
            }
            _error = '$error';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _selectionGeneration++;
    _sourceGeneration++;
    _files?.dispose();
    unawaited(_subscription?.cancel());
    final session = _session;
    _session = null;
    if (session != null) unawaited(session.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final active =
        snapshot != null && snapshot.state != LuaDebugState.terminated;
    final running = snapshot?.state == LuaDebugState.running;
    final paused = snapshot?.state == LuaDebugState.paused;
    final frames = snapshot?.frames ?? const <LuaDebugFrame>[];
    final selected = frames.isEmpty
        ? null
        : frames[_selectedFrame.clamp(0, frames.length - 1)];
    final currentLine =
        selected != null &&
            selected.fileBacked &&
            _sourceFile != null &&
            p.equals(selected.file, _sourceFile!)
        ? selected.line
        : null;
    final controller = _files;
    return ToolScaffold(
      title: LuaDebuggerPage.title,
      description: '调试已保存的 Lua 源码。点击行号旁的圆点设置断点；暂停后可查看真实调用栈和局部变量。',
      children: [
        if (controller != null) ...[
          DropdownButtonFormField<String>(
            key: ValueKey('debug-project-${controller.project?.id}'),
            initialValue: controller.project?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '项目'),
            items: [
              for (final project in controller.projects)
                DropdownMenuItem(
                  value: project.id,
                  child: Text(project.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: active || _starting ? null : controller.selectProject,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('debug-entry-${controller.file}'),
            initialValue: controller.file,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '入口 Lua 文件'),
            items: [
              for (final file in controller.files)
                DropdownMenuItem(
                  value: file,
                  child: Text(
                    controller.label(file),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: active || _starting ? null : controller.selectFile,
          ),
          if (controller.projects.isEmpty) const Text('没有本地项目，请先创建或导入 Lua 项目。'),
          if (controller.error != null) ToolError(controller.error),
        ] else
          Text(_entry == null ? '未选择源码' : p.basename(_entry!)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('lua-debug-start'),
              onPressed: _starting || active || _entry == null ? null : _start,
              icon: const Icon(Icons.bug_report_outlined),
              label: Text(_starting ? '正在启动' : '开始调试'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-continue'),
              onPressed: paused ? () => _act((s) => s.resume()) : null,
              child: const Text('继续'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-pause'),
              onPressed: running ? () => _session?.pause() : null,
              child: const Text('暂停'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-stop'),
              onPressed: active ? () => _act((s) => s.stop()) : null,
              child: const Text('停止'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-into'),
              onPressed: paused
                  ? () => _act((s) => s.resume(LuaDebugAction.stepInto))
                  : null,
              child: const Text('步入'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-over'),
              onPressed: paused
                  ? () => _act((s) => s.resume(LuaDebugAction.stepOver))
                  : null,
              child: const Text('步过'),
            ),
            OutlinedButton(
              key: const ValueKey('lua-debug-out'),
              onPressed: paused
                  ? () => _act((s) => s.resume(LuaDebugAction.stepOut))
                  : null,
              child: const Text('步出'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(switch (snapshot?.state) {
          LuaDebugState.running => '正在运行',
          LuaDebugState.paused =>
            '已暂停 · 第 ${frames.isEmpty ? '?' : frames.first.line} 行',
          LuaDebugState.terminated => '已结束 · 状态 ${snapshot?.status}',
          _ => '尚未启动',
        }, key: const ValueKey('lua-debug-status')),
        ToolError(_error),
        const SizedBox(height: 12),
        const Text(
          '限制：仅调试已保存的文本源码；此模式不支持用户协程、表达式求值或替换调试钩子。原生调用和终结器不可强制暂停；require 模块初始化或 C 回调中的断点会延后到可暂停的 Lua 行并给出提示；剥离或动态生成的字节码可能没有源码行。普通运行不受这些调试限制。调试期间保留已读取的源码预览；修改源码后请重新启动。预览最多 2000 行。',
        ),
        if (selected != null &&
            (!selected.fileBacked || selected.line <= 0 || _sourceFile == null))
          const Text(
            '所选调用帧没有可用的磁盘源码。',
            key: ValueKey('lua-debug-source-unavailable'),
          ),
        if (_sourceFile != null) ...[
          const SizedBox(height: 16),
          Text('源码 · ${p.relative(_sourceFile!, from: _root)}'),
          const SizedBox(height: 8),
          for (var index = 0; index < _source.length; index++)
            ColoredBox(
              color: currentLine == index + 1
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: ValueKey('lua-debug-breakpoint-${index + 1}'),
                    tooltip: '断点 ${index + 1}',
                    onPressed: running || _starting
                        ? null
                        : () => _toggle(index + 1),
                    iconSize: 16,
                    icon: Icon(
                      _breakpoints[_sourceFile]?.contains(index + 1) == true
                          ? Icons.circle
                          : Icons.radio_button_unchecked,
                      color:
                          _breakpoints[_sourceFile]?.contains(index + 1) == true
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text('${index + 1}'),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _source[index],
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (frames.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('调用栈（最多 64 帧）'),
          for (var index = 0; index < frames.length; index++)
            ListTile(
              dense: true,
              selected: index == _selectedFrame,
              title: Text(
                '${frames[index].name} · ${p.basename(frames[index].file)}:${frames[index].line}',
              ),
              onTap: () {
                setState(() {
                  _selectedFrame = index;
                });
                _showFrameSource(frames[index]);
              },
            ),
          const Text('局部变量（每帧最多 128 项，字符串最多 4096 字节）'),
          if (selected != null)
            for (final local in selected.locals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(
                  '${local.name} (${local.type}) = ${local.value}',
                ),
              ),
        ],
        const SizedBox(height: 16),
        const Text('输出'),
        SelectableText(
          snapshot?.stdout ?? '',
          key: const ValueKey('lua-debug-stdout'),
        ),
        if (snapshot?.stderr.isNotEmpty == true)
          SelectableText(
            snapshot!.stderr,
            key: const ValueKey('lua-debug-stderr'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
