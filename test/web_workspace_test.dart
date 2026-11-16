import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qfli_lua/web/workspace.dart';

class MemoryWorkspaceStorage implements WorkspaceStorage {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  @override
  String? read() {
    if (failRead) throw StateError('Storage access denied');
    return value;
  }

  @override
  void write(String next) {
    if (failWrite) throw StateError('Quota exceeded');
    writes++;
    value = next;
  }
}

void main() {
  test('edits survive switching, save and reopening', () {
    final storage = MemoryWorkspaceStorage();
    final workspace = WebWorkspace(storage);
    addTearDown(workspace.dispose);
    expect(workspace.isDirty, isTrue);
    final firstId = workspace.selectedFile!.id;
    workspace.editFile(firstId, 'print("你好")\r\n');
    final secondId = workspace.createFile('hello.js', 'console.log(42);\n');
    workspace.selectFile(firstId);
    expect(workspace.selectedFile!.content, 'print("你好")\r\n');
    workspace.renameFile(secondId, 'hello.mjs');
    expect(workspace.save(), isTrue);
    expect(workspace.isDirty, isFalse);

    final reopened = WebWorkspace(storage);
    addTearDown(reopened.dispose);
    expect(reopened.isDirty, isFalse);
    expect(reopened.selectedFile!.name, 'main.lua');
    expect(reopened.selectedFile!.content, 'print("你好")\r\n');
    expect(reopened.files.last.name, 'hello.mjs');
    expect(reopened.files.last.content, 'console.log(42);\n');
    reopened.selectFile(secondId);
    expect(reopened.isDirty, isFalse, reason: 'Selection is not a source edit');
  });

  test('deletion persists, including an empty workspace', () {
    final storage = MemoryWorkspaceStorage();
    final workspace = WebWorkspace(storage);
    addTearDown(workspace.dispose);
    workspace.createFile('second.ts', 'const value = 1;');
    workspace.deleteFile(workspace.files.first.id);
    expect(workspace.selectedFile!.name, 'second.ts');
    expect(workspace.save(), isTrue);
    final reopened = WebWorkspace(storage);
    addTearDown(reopened.dispose);
    expect(reopened.files.map((file) => file.name), ['second.ts']);
    reopened.deleteFile(reopened.selectedFile!.id);
    expect(reopened.selectedFile, isNull);
    expect(reopened.save(), isTrue);
    final empty = WebWorkspace(storage);
    addTearDown(empty.dispose);
    expect(empty.files, isEmpty);
    expect(empty.isDirty, isFalse);
  });

  test('invalid and duplicate names cannot change existing buffers', () {
    final workspace = WebWorkspace(MemoryWorkspaceStorage());
    addTearDown(workspace.dispose);
    final id = workspace.createFile('second.lua', 'return 2');
    for (final name in ['', ' main.lua', '../main.lua', 'a\\b', '.', 'a:b']) {
      expect(() => workspace.createFile(name), throwsFormatException);
    }
    expect(() => workspace.renameFile(id, 'main.lua'), throwsFormatException);
    expect(workspace.selectedFile!.name, 'second.lua');
    expect(workspace.selectedFile!.content, 'return 2');
    workspace.importFiles([
      const SourceFile(name: 'main.lua', content: 'return "imported"'),
    ]);
    expect(workspace.selectedFile!.name, 'main (2).lua');
    expect(workspace.files.first.content, contains('Hello, world!'));
  });

  test('write failures preserve the saved snapshot and dirty edits', () {
    final storage = MemoryWorkspaceStorage();
    final workspace = WebWorkspace(storage);
    addTearDown(workspace.dispose);
    expect(workspace.save(), isTrue);
    final saved = storage.value;
    workspace.editFile(workspace.selectedFile!.id, 'print("unsaved")');
    storage.failWrite = true;
    expect(workspace.save(), isFalse);
    expect(workspace.isDirty, isTrue);
    expect(workspace.storageError, isNotNull);
    expect(storage.value, saved);
    storage.failWrite = false;
    expect(workspace.save(), isTrue);
    expect(workspace.storageError, isNull);
    expect(workspace.isDirty, isFalse);
  });

  test('a denied initial read never turns into an overwrite', () {
    final storage = MemoryWorkspaceStorage()..failRead = true;
    final workspace = WebWorkspace(storage);
    addTearDown(workspace.dispose);
    expect(workspace.saveBlocked, isTrue);
    expect(workspace.isDirty, isTrue);
    storage.failRead = false;
    expect(workspace.save(), isFalse);
    expect(storage.writes, 0);
  });

  test('corrupt and future schemas preserve exact recovery data', () {
    for (final raw in [
      '{broken',
      '{"version":2,"files":[]}',
      jsonEncode({
        'version': 1,
        'selectedFile': '1',
        'files': [
          {'id': '1', 'name': 'first.lua', 'content': 'return 1'},
          {'id': '2', 'name': 'first.lua', 'content': 'return 2'},
        ],
      }),
      '{"version":1,"files":[],"selectedFile":"missing"}',
    ]) {
      final storage = MemoryWorkspaceStorage()..value = raw;
      final workspace = WebWorkspace(storage);
      addTearDown(workspace.dispose);
      expect(workspace.saveBlocked, isTrue);
      expect(workspace.recoveryData, raw);
      expect(workspace.files.map((file) => file.name), ['main.lua']);
      expect(workspace.save(), isFalse);
      expect(storage.value, raw);
      expect(storage.writes, 0);
    }
  });

  test('another tab cannot silently replace newer saved data', () {
    final storage = MemoryWorkspaceStorage();
    final first = WebWorkspace(storage);
    addTearDown(first.dispose);
    first.save();
    final second = WebWorkspace(storage);
    addTearDown(second.dispose);
    first.editFile(first.selectedFile!.id, 'first tab');
    first.save();
    final latest = storage.value;
    second.editFile(second.selectedFile!.id, 'second tab');
    expect(second.save(), isFalse);
    expect(second.isDirty, isTrue);
    expect(second.storageError, isNotNull);
    expect(storage.value, latest);
  });
}
