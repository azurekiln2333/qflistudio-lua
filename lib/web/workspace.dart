import 'dart:convert';

import 'package:flutter/foundation.dart';

abstract interface class WorkspaceStorage {
  String? read();
  void write(String value);
}

class SourceFile {
  const SourceFile({required this.name, required this.content});

  final String name;
  final String content;
}

abstract interface class SourceFileTransfer {
  Future<List<SourceFile>> importFiles();
  void exportFile(SourceFile file);
}

class WorkspaceFile extends SourceFile {
  const WorkspaceFile({
    required this.id,
    required super.name,
    required super.content,
  });

  final String id;

  Map<String, String> toJson() => {'id': id, 'name': name, 'content': content};
}

/// The sole owner of the versioned browser workspace format and save state.
class WebWorkspace extends ChangeNotifier {
  WebWorkspace(this.storage) {
    try {
      _storedValue = storage.read();
      if (_storedValue != null) {
        _restore(_storedValue!);
        _savedFiles = _fileSnapshot();
        return;
      }
    } catch (_) {
      saveBlocked = true;
      storageError = _storedValue == null
          ? '无法读取浏览器数据。请导出文件后重试。'
          : '已保存的数据无法解析。原数据已保留。';
      recoveryData = _storedValue;
      // Never leave a partially decoded workspace on a validation failure.
      _files.clear();
      _selectedId = null;
    }
    _files.add(
      const WorkspaceFile(
        id: '1',
        name: 'main.lua',
        content: '-- QFLIScript Web\nprint("Hello, world!")\n',
      ),
    );
    _selectedId = '1';
  }

  final WorkspaceStorage storage;
  final List<WorkspaceFile> _files = [];
  int _nextId = 1;
  String? _selectedId;
  String? _storedValue;
  String? _savedFiles;
  String? storageError;
  String? recoveryData;
  bool saveBlocked = false;

  List<WorkspaceFile> get files => List.unmodifiable(_files);
  WorkspaceFile? get selectedFile {
    for (final file in _files) {
      if (file.id == _selectedId) return file;
    }
    return null;
  }

  bool get isDirty => _fileSnapshot() != _savedFiles;

  String? validateName(String name, {String? exceptId}) {
    if (name.isEmpty || name != name.trim() || name.length > 255) {
      return '文件名须为 1 至 255 字符，首尾不能有空格。';
    }
    if (name == '.' ||
        name == '..' ||
        RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]').hasMatch(name)) {
      return '文件名不能包含路径或特殊字符。';
    }
    if (_files.any((file) => file.id != exceptId && file.name == name)) {
      return '文件名已存在。';
    }
    return null;
  }

  String createFile(String name, [String content = '']) {
    final error = validateName(name);
    if (error != null) throw FormatException(error);
    while (_files.any((file) => file.id == '$_nextId')) {
      _nextId++;
    }
    final id = '${_nextId++}';
    _files.add(WorkspaceFile(id: id, name: name, content: content));
    _selectedId = id;
    notifyListeners();
    return id;
  }

  /// Import duplicates under a fresh name, preserving every existing buffer.
  void importFiles(List<SourceFile> imported) {
    for (final file in imported) {
      var name = file.name;
      var suffix = 2;
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      final extension = dot > 0 ? name.substring(dot) : '';
      while (_files.any((existing) => existing.name == name)) {
        name = '$stem ($suffix)$extension';
        suffix++;
      }
      createFile(name, file.content);
    }
  }

  void selectFile(String id) {
    _indexOf(id);
    _selectedId = id;
    notifyListeners();
  }

  void editFile(String id, String content) {
    final index = _indexOf(id);
    final old = _files[index];
    if (old.content == content) return;
    _files[index] = WorkspaceFile(id: id, name: old.name, content: content);
    notifyListeners();
  }

  void renameFile(String id, String name) {
    final index = _indexOf(id);
    final error = validateName(name, exceptId: id);
    if (error != null) throw FormatException(error);
    _files[index] = WorkspaceFile(
      id: id,
      name: name,
      content: _files[index].content,
    );
    notifyListeners();
  }

  void deleteFile(String id) {
    _files.removeAt(_indexOf(id));
    if (_selectedId == id) {
      _selectedId = _files.isEmpty ? null : _files.first.id;
    }
    notifyListeners();
  }

  bool save() {
    if (saveBlocked) return false;
    try {
      // Detect another tab's save before overwriting its workspace.
      if (storage.read() != _storedValue) {
        storageError = '已保存的文件发生更改。请导出当前文件后刷新。';
        notifyListeners();
        return false;
      }
      final value = jsonEncode({
        'version': 1,
        'selectedFile': _selectedId,
        'files': _files.map((file) => file.toJson()).toList(),
      });
      storage.write(value);
      _storedValue = value;
      _savedFiles = _fileSnapshot();
      storageError = null;
      notifyListeners();
      return true;
    } catch (_) {
      storageError = '保存失败。请检查浏览器权限和可用空间。';
      notifyListeners();
      return false;
    }
  }

  int _indexOf(String id) {
    final index = _files.indexWhere((file) => file.id == id);
    if (index == -1) throw StateError('Unknown workspace file: $id');
    return index;
  }

  String _fileSnapshot() =>
      jsonEncode(_files.map((file) => file.toJson()).toList());

  void _restore(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['files'] is! List) {
      throw const FormatException('Unsupported workspace format');
    }
    final ids = <String>{};
    for (final entry in decoded['files'] as List) {
      if (entry is! Map<String, dynamic> ||
          entry['id'] is! String ||
          (entry['id'] as String).isEmpty ||
          !ids.add(entry['id'] as String) ||
          entry['name'] is! String ||
          entry['content'] is! String ||
          validateName(entry['name'] as String) != null) {
        throw const FormatException('Invalid workspace file');
      }
      _files.add(
        WorkspaceFile(
          id: entry['id'] as String,
          name: entry['name'] as String,
          content: entry['content'] as String,
        ),
      );
    }
    final selected = decoded['selectedFile'];
    if ((_files.isEmpty && selected != null) ||
        (_files.isNotEmpty &&
            (selected is! String || !ids.contains(selected)))) {
      throw const FormatException('Invalid selected file');
    }
    _selectedId = selected as String?;
  }
}
