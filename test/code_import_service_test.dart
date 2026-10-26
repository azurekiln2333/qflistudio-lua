import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/models/project.dart';
import 'package:qfli_studio_core/models/tutorial.dart';
import 'package:qfli_studio_core/services/code_import_service.dart';
import 'package:qfli_studio_core/services/file_backup.dart';
import 'package:qfli_studio_core/services/project_config.dart';
import 'package:qfli_studio_core/services/project_templates.dart';
import 'package:qfli_studio_core/services/runner_service.dart';
import 'package:qfli_studio_core/services/studio_profile.dart';
import 'package:qfli_studio_core/store/project_store.dart';

const _example = ExampleCode(
  id: 'import-test',
  type: 'lua',
  title: 'Lua example',
  summary: 'A code import fixture',
  code: 'print("custom entry")\n',
  output: 'custom entry',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProjectStore store;
  late StudioProfile? previousProfile;

  setUp(() async {
    previousProfile = StudioProfile.current;
    StudioProfile.current = luaProfile;
    directory = Directory.systemTemp.createTempSync('qfli_code_import_');
    FileBackup.baseOverride = directory.path;
    store = ProjectStore(
      storageFile: File(p.join(directory.path, 'registry.json')),
    );
    await store.load();
  });

  tearDown(() {
    store.dispose();
    FileBackup.baseOverride = null;
    StudioProfile.current = previousProfile;
    directory.deleteSync(recursive: true);
  });

  Matcher failure(CodeImportFailure reason) => throwsA(
    isA<CodeImportException>().having(
      (error) => error.reason,
      'reason',
      reason,
    ),
  );

  test('filenames reject paths, controls and nonportable names', () async {
    for (final name in [
      '',
      '.',
      '..',
      '../escape.lua',
      r'src\escape.lua',
      'bad:name.lua',
      ' file.lua',
      'file.lua ',
      'file.',
      'nul.lua',
      'COM1',
      'a\u0000.lua',
      'a\n.lua',
      List.filled(256, 'a').join(),
    ]) {
      expect(CodeImportService.isValidFileName(name), isFalse, reason: name);
      await expectLater(
        CodeImportService.openInEditor(
          example: _example,
          fileName: name,
          location: directory.path,
        ),
        failure(CodeImportFailure.invalidFileName),
      );
    }
    expect(CodeImportService.isValidFileName('lesson-01.lua'), isTrue);
    expect(directory.listSync().whereType<Directory>(), isEmpty);
  });

  test(
    'editor imports persist separate working copies without registration',
    () async {
      final first = await CodeImportService.openInEditor(
        example: _example,
        fileName: 'lesson.lua',
        location: directory.path,
      );
      final second = await CodeImportService.openInEditor(
        example: _example.copyWith(code: 'print("edited")'),
        fileName: 'lesson.lua',
        location: directory.path,
      );
      expect(File(first.path).readAsStringSync(), _example.code);
      expect(File(second.path).readAsStringSync(), 'print("edited")');
      expect(first.project.path, isNot(second.project.path));
      expect(p.basename(first.path), 'lesson.lua');
      expect(RunnerService.findEntry(first.project.path), first.path);
      expect(
        ProjectConfig.read(first.project.path)?['entryFile'],
        p.join('src', 'lesson.lua'),
      );
      await store.refresh();
      expect(store.projects, isEmpty);
    },
  );

  test(
    'a custom new-project entry is persisted, rediscovered and runnable',
    () async {
      final result = await store.createProjectFromExample(
        name: 'Imported project',
        example: _example,
        fileName: 'lesson-42.lua',
        location: directory.path,
      );
      expect(result.error, isNull);
      final project = result.project!;
      final source = p.join(project.path, 'src', 'lesson-42.lua');
      expect(File(source).readAsStringSync(), _example.code);
      expect(
        File(p.join(project.path, ProjectTemplate.lua.mainFile!)).existsSync(),
        isFalse,
      );
      expect(RunnerService.findEntry(project.path), source);
      await store.refresh();
      expect(store.projects.single.id, project.id);
      expect(store.projects.single.name, 'Imported project');
      final run = await RunnerService.runProject(
        projectPath: project.path,
        entryFile: RunnerService.findEntry(project.path)!,
      );
      expect(run?.hint, isNull);
      expect(await run!.stdout!.toList(), ['custom entry']);
      expect(await run.exitCode, 0);
    },
  );

  test('existing-project imports keep the entry and never overwrite', () async {
    final result = await store.createProjectFromExample(
      name: 'Existing',
      example: _example,
      fileName: 'entry.lua',
      location: directory.path,
    );
    final project = result.project!;
    final config = File(ProjectConfig.configPath(project.path));
    final before = config.readAsStringSync();
    final imported = await CodeImportService.importIntoProject(
      project: project,
      example: _example.copyWith(code: 'print("added")'),
      fileName: 'added.lua',
    );
    expect(imported.project, same(project));
    expect(File(imported.path).readAsStringSync(), 'print("added")');
    expect(config.readAsStringSync(), before);
    expect(
      RunnerService.findEntry(project.path),
      p.join(project.path, 'src', 'entry.lua'),
    );
    await expectLater(
      CodeImportService.importIntoProject(
        project: project,
        example: _example,
        fileName: 'added.lua',
      ),
      failure(CodeImportFailure.fileExists),
    );
    expect(File(imported.path).readAsStringSync(), 'print("added")');
  });

  test('simultaneous imports reserve occupied names exclusively', () async {
    final project = Project.create(
      name: 'Existing',
      path: directory.path,
      type: 'lua',
      language: 'Lua',
    );
    Directory(p.join(directory.path, 'src')).createSync();
    Future<Object> attempt(String code) async {
      try {
        return await CodeImportService.importIntoProject(
          project: project,
          example: _example.copyWith(code: code),
          fileName: 'same.lua',
        );
      } on CodeImportException catch (error) {
        return error;
      }
    }

    final results = await Future.wait([attempt('first'), attempt('second')]);
    expect(results.whereType<CodeImportResult>(), hasLength(1));
    expect(
      results.whereType<CodeImportException>().single.reason,
      CodeImportFailure.fileExists,
    );
    expect(
      File(p.join(directory.path, 'src', 'same.lua')).readAsStringSync(),
      isIn(['first', 'second']),
    );
  });

  test(
    'unavailable projects and filesystem write failures are reported',
    () async {
      final missing = Project.create(
        name: 'Missing',
        path: p.join(directory.path, 'missing'),
      );
      await expectLater(
        CodeImportService.importIntoProject(
          project: missing,
          example: _example,
          fileName: 'code.lua',
        ),
        failure(CodeImportFailure.projectUnavailable),
      );
      await expectLater(
        CodeImportService.openInEditor(
          example: _example,
          fileName: 'code.lua',
          location: missing.path,
        ),
        failure(CodeImportFailure.storageUnavailable),
      );
      File(p.join(directory.path, 'src')).writeAsStringSync('keep');
      final project = Project.create(
        name: 'Blocked',
        path: directory.path,
        type: 'lua',
      );
      await expectLater(
        CodeImportService.importIntoProject(
          project: project,
          example: _example,
          fileName: 'code.lua',
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(File(p.join(directory.path, 'src')).readAsStringSync(), 'keep');
      final creation = await store.createProjectFromExample(
        name: 'Cannot write',
        example: _example,
        location: p.join(directory.path, 'src'),
      );
      expect(creation.error, isNotNull);
      expect(creation.project, isNull);
      expect(store.projects, isEmpty);
    },
  );

  test(
    'configured entries take priority and stale or escaping entries fall back',
    () async {
      final defaultFile = File(p.join(directory.path, 'main.lua'))
        ..writeAsStringSync('default');
      final custom = File(p.join(directory.path, 'lesson.lua'))
        ..writeAsStringSync('custom');
      for (final entry in [
        'lesson.lua',
        'gone.lua',
        '../outside.lua',
        r'C:lesson.lua',
        custom.path,
      ]) {
        await ProjectConfig.write(
          projectRoot: directory.path,
          name: 'Entry',
          language: 'Lua',
          entryFile: entry,
          strict: true,
        );
        expect(
          RunnerService.findEntry(directory.path),
          entry == 'lesson.lua' ? custom.path : defaultFile.path,
        );
      }
    },
  );

  test(
    'confirmed replacement keeps a backup and cleans its temporary file',
    () async {
      final project = Project.create(
        name: 'Replacement',
        path: directory.path,
        type: 'lua',
      );
      final file = File(p.join(directory.path, 'src', 'entry.lua'));
      file.parent.createSync();
      file.writeAsStringSync('original code');
      await CodeImportService.importIntoProject(
        project: project,
        example: _example,
        fileName: 'entry.lua',
        overwrite: true,
      );
      expect(file.readAsStringSync(), _example.code);
      final backups = await FileBackup.listVersions(
        file,
        projectName: project.name,
      );
      expect(backups.single.file.readAsStringSync(), 'original code');
      expect(file.parent.listSync().map((entry) => p.basename(entry.path)), [
        'entry.lua',
      ]);
    },
  );

  test(
    'a backup failure leaves original contents intact and permits retry',
    () async {
      final project = Project.create(
        name: 'Backup failure',
        path: directory.path,
        type: 'lua',
      );
      final file = File(p.join(directory.path, 'src', 'entry.lua'));
      file.parent.createSync();
      file.writeAsStringSync('preserve original');
      final blocked = File(p.join(directory.path, 'backup-root'))
        ..writeAsStringSync('keep');
      FileBackup.baseOverride = blocked.path;
      await expectLater(
        CodeImportService.importIntoProject(
          project: project,
          example: _example,
          fileName: 'entry.lua',
          overwrite: true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.readAsStringSync(), 'preserve original');
      expect(file.parent.listSync().map((entry) => p.basename(entry.path)), [
        'entry.lua',
      ]);
      FileBackup.baseOverride = directory.path;
      await CodeImportService.importIntoProject(
        project: project,
        example: _example,
        fileName: 'entry.lua',
        overwrite: true,
      );
      expect(file.readAsStringSync(), _example.code);
    },
  );

  test(
    'failed registry writes roll back new and existing imports and refresh recovers',
    () async {
      final registry = Directory(p.join(directory.path, 'blocked-registry'))
        ..createSync();
      final failingStore = ProjectStore(storageFile: File(registry.path));
      addTearDown(failingStore.dispose);
      await failingStore.load();
      final creation = await failingStore.createProjectFromExample(
        name: 'Failed registration',
        example: _example,
        location: directory.path,
      );
      expect(creation.error, isNotNull);
      expect(creation.project, isNull);
      expect(failingStore.projects, isEmpty);
      final snippet = await CodeImportService.openInEditor(
        example: _example,
        fileName: 'saved.lua',
        location: directory.path,
      );
      final registration = await failingStore.addExisting(snippet.project.path);
      expect(registration.error, isNotNull);
      expect(registration.project, isNull);
      expect(failingStore.projects, isEmpty);
      registry.deleteSync();
      await failingStore.refresh();
      expect(failingStore.projects, isEmpty);
      final retried = await failingStore.addExisting(snippet.project.path);
      expect(retried.error, isNull);
      await failingStore.refresh();
      expect(failingStore.projects.single.path, snippet.project.path);
      expect(File(snippet.path).readAsStringSync(), _example.code);
    },
  );

  test(
    'a locked registry preserves previous projects and permits retry',
    () async {
      final original = await store.createProjectFromExample(
        name: 'Keep registered',
        example: _example,
        location: directory.path,
      );
      expect(original.error, isNull);
      final registry = File(p.join(directory.path, 'registry.json'));
      final before = await registry.readAsString();
      final handle = await registry.open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive);
        final failed = await store.createProjectFromExample(
          name: 'Cannot register yet',
          example: _example,
          location: directory.path,
        );
        expect(failed.error, isNotNull);
        expect(failed.project, isNull);
        expect(store.projects.map((project) => project.id), [
          original.project!.id,
        ]);
      } finally {
        await handle.unlock();
        await handle.close();
      }
      expect(await registry.readAsString(), before);
      expect(
        registry.parent.listSync().where(
          (entry) =>
              p.basename(entry.path).startsWith('.qfli-project-registry-'),
        ),
        isEmpty,
      );
      await store.refresh();
      expect(store.projects.single.id, original.project!.id);
      final retried = await store.createProjectFromExample(
        name: 'Cannot register yet',
        example: _example,
        location: directory.path,
      );
      expect(retried.error, isNull);
      await store.refresh();
      expect(
        store.projects.map((project) => project.id),
        unorderedEquals([original.project!.id, retried.project!.id]),
      );
    },
    skip: !Platform.isWindows,
  );

  test('an earlier save never publishes a later failed registration', () async {
    final original = await store.createProjectFromExample(
      name: 'Already registered',
      example: _example,
      location: directory.path,
    );
    final firstSnippet = await CodeImportService.openInEditor(
      example: _example,
      fileName: 'first.lua',
      location: directory.path,
    );
    final secondSnippet = await CodeImportService.openInEditor(
      example: _example,
      fileName: 'second.lua',
      location: directory.path,
    );
    final started = Completer<void>();
    final release = Completer<void>();
    var attempts = 0;
    final registry = File(p.join(directory.path, 'registry.json'));
    final concurrent = ProjectStore(
      storageFile: _ControlledRegistryFile(registry, () async {
        attempts++;
        if (attempts == 1) {
          started.complete();
          await release.future;
        } else if (attempts == 3) {
          throw FileSystemException('Registry unavailable', registry.path);
        }
      }),
    );
    addTearDown(concurrent.dispose);
    await concurrent.load();
    List<String>? lastPublished;
    concurrent.addListener(() {
      lastPublished = concurrent.projects.map((project) => project.id).toList();
    });
    final previous = concurrent.setFavorite(concurrent.projects.single, true);
    await started.future;
    final first = concurrent.addExisting(firstSnippet.project.path);
    final second = concurrent.addExisting(secondSnippet.project.path);
    late int pendingCount;
    try {
      for (
        var attempt = 0;
        attempt < 200 && concurrent.projects.length < 3;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      pendingCount = concurrent.projects.length;
    } finally {
      release.complete();
    }
    await previous;
    final results = await Future.wait([first, second]);
    expect(pendingCount, 3);
    final succeeded = results.where((result) => result.error == null).single;
    final failed = results.where((result) => result.error != null).single;
    expect(failed.project, isNull);
    final expectedIds = [original.project!.id, succeeded.project!.id];
    expect(
      concurrent.projects.map((project) => project.id),
      unorderedEquals(expectedIds),
    );
    expect(lastPublished, unorderedEquals(expectedIds));
    final saved = jsonDecode(await registry.readAsString()) as Map;
    expect(
      (saved['projects'] as List).map((project) => (project as Map)['id']),
      unorderedEquals(expectedIds),
    );
    await concurrent.refresh();
    expect(
      concurrent.projects.map((project) => project.id),
      unorderedEquals(expectedIds),
    );
    final failedPath = results.first.error != null
        ? firstSnippet.project.path
        : secondSnippet.project.path;
    final retry = await concurrent.addExisting(failedPath);
    expect(retry.error, isNull);
    await concurrent.refresh();
    expect(concurrent.projects, hasLength(3));
  });

  test(
    'refresh waits for registrations queued while another save runs',
    () async {
      final original = await store.createProjectFromExample(
        name: 'Original',
        example: _example,
        location: directory.path,
      );
      final snippet = await CodeImportService.openInEditor(
        example: _example,
        fileName: 'pending.lua',
        location: directory.path,
      );
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final secondStarted = Completer<void>();
      final releaseSecond = Completer<void>();
      var attempts = 0;
      final registry = File(p.join(directory.path, 'registry.json'));
      final concurrent = ProjectStore(
        storageFile: _ControlledRegistryFile(registry, () async {
          attempts++;
          if (attempts == 1) {
            firstStarted.complete();
            await releaseFirst.future;
          } else if (attempts == 2) {
            secondStarted.complete();
            await releaseSecond.future;
          }
        }),
      );
      addTearDown(concurrent.dispose);
      await concurrent.load();
      final previous = concurrent.setFavorite(concurrent.projects.single, true);
      await firstStarted.future;
      var refreshed = false;
      final refreshing = concurrent.refresh().then((_) => refreshed = true);
      final registration = concurrent.addExisting(snippet.project.path);
      for (
        var attempt = 0;
        attempt < 200 && concurrent.projects.length < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      releaseFirst.complete();
      await secondStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final refreshedBeforeRegistration = refreshed;
      releaseSecond.complete();
      await previous;
      final registered = await registration;
      await refreshing;
      expect(refreshedBeforeRegistration, isFalse);
      expect(registered.error, isNull);
      expect(
        concurrent.projects.map((project) => project.id),
        unorderedEquals([original.project!.id, registered.project!.id]),
      );
    },
  );
}

class _ControlledRegistryFile extends Fake implements File {
  _ControlledRegistryFile(this.file, this.beforeWrite);

  final File file;
  final Future<void> Function() beforeWrite;

  @override
  String get path => file.path;

  @override
  Directory get parent => _ControlledRegistryParent(file.parent, beforeWrite);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => file.writeAsString(
    contents,
    mode: mode,
    encoding: encoding,
    flush: flush,
  );
}

class _ControlledRegistryParent extends Fake implements Directory {
  _ControlledRegistryParent(this.directory, this.beforeWrite);

  final Directory directory;
  final Future<void> Function() beforeWrite;

  @override
  String get path => directory.path;

  @override
  Future<Directory> create({bool recursive = false}) async {
    await beforeWrite();
    return directory.create(recursive: recursive);
  }

  @override
  Future<Directory> createTemp([String? prefix]) =>
      directory.createTemp(prefix);
}
