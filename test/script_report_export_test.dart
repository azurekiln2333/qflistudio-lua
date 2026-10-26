import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/picker_service.dart';

import '../bin/script_report_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('qflistudio/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('qfli_script_report_export_');
    // Force the native picker channel so the real PickerService contract is
    // exercised on a desktop host.
    PickerService.forcePlatformChannel = true;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    PickerService.forcePlatformChannel = false;
    if (!root.existsSync()) return;
    // Remove symlinks before the recursive delete so it cannot follow them.
    for (final link
        in root
            .listSync(recursive: true, followLinks: false)
            .whereType<Link>()) {
      try {
        link.deleteSync();
      } on FileSystemException {
        // Already removed; ignore.
      }
    }
    root.deleteSync(recursive: true);
  });

  // Probing once keeps the symlink regressions honest: on a host without
  // symlink support the test records an explicit skip with the real reason
  // instead of silently passing.
  final symlinkSkip = () {
    final probe = Directory.systemTemp.createTempSync('qfli_symlink_probe_');
    final target = Directory(p.join(probe.path, 'target'))..createSync();
    try {
      Link(p.join(probe.path, 'link')).createSync(target.path);
      return null;
    } on FileSystemException catch (error) {
      return 'directory symlinks unavailable: $error';
    } finally {
      for (final link
          in probe
              .listSync(recursive: true, followLinks: false)
              .whereType<Link>()) {
        try {
          link.deleteSync();
        } on FileSystemException {
          // Already removed; ignore.
        }
      }
      if (probe.existsSync()) probe.deleteSync(recursive: true);
    }
  }();

  // Windows resolves a `..` before the preceding symlink, so the symlink/`..`
  // combination is a POSIX-only case; skip it explicitly there.
  final dotDotSkip = Platform.isWindows
      ? 'Windows resolves .. before the preceding symlink; POSIX-only case'
      : symlinkSkip;

  File reportFile(String run, [String name = 'qfli-script-acceptance.json']) {
    final directory = Directory(p.join(root.path, run, 'reports'))
      ..createSync(recursive: true);
    return File(p.join(directory.path, name));
  }

  ScriptReportArtifact artifact(String run, ScriptReportRole role) =>
      scriptReportArtifacts(
        reportFile(run),
      ).firstWhere((item) => item.role == role);

  Uint8List rawReportBytes() => Uint8List.fromList(<int>[
    ...utf8.encode('{"note":"审计 CRLF\r\nno final LF","emoji":"✓"}'),
    0x00,
    0xff,
    0x0d,
  ]);

  test(
    'path destination copies exact bytes, exact basename and verifies',
    () async {
      final bytes = rawReportBytes();
      reportFile('run-path').writeAsBytesSync(bytes, flush: true);
      final destination = p.join(root.path, 'chosen-report-name');
      String? suggested;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == 'saveDocument') {
          suggested = (call.arguments as Map)['suggestedName'] as String;
          return {'path': destination};
        }
        throw PlatformException(code: 'UNEXPECTED', message: call.method);
      });

      final result = await ScriptReportExporter().export(
        artifact('run-path', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.verified);
      expect(result.verified, isTrue);
      expect(result.sourceBytes, bytes.length);
      expect(result.sourceSha256, scriptReportSha256(bytes));
      expect(result.destinationPath, destination);
      expect(result.readBackBytes, bytes.length);
      expect(result.readBackSha256, scriptReportSha256(bytes));
      expect(suggested, 'qfli-script-acceptance.json');
      expect(File(destination).readAsBytesSync(), orderedEquals(bytes));
      // Source evidence is never rewritten.
      expect(reportFile('run-path').readAsBytesSync(), orderedEquals(bytes));
      // No extension is appended and no second destination is derived.
      expect(File('$destination.json').existsSync(), isFalse);
      expect(File('$destination.lua.json').existsSync(), isFalse);
      // Only the picker channel method is used for a local path.
      expect(methods, ['saveDocument']);
    },
  );

  test(
    'URI destination writes exact bytes through writeUri and verifies',
    () async {
      final bytes = rawReportBytes();
      reportFile('run-uri').writeAsBytesSync(bytes, flush: true);
      const uri = 'content://qfli/script-report.json';
      String? suggested;
      Uint8List? written;
      var readCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          suggested = (call.arguments as Map)['suggestedName'] as String;
          return {'uri': uri};
        }
        if (call.method == 'writeUri') {
          expect((call.arguments as Map)['uri'], uri);
          written = (call.arguments as Map)['bytes'] as Uint8List;
          return null;
        }
        if (call.method == 'readUri') {
          readCalls++;
          expect((call.arguments as Map)['uri'], uri);
          return written;
        }
        throw PlatformException(code: 'UNEXPECTED', message: call.method);
      });

      final result = await ScriptReportExporter().export(
        artifact('run-uri', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.verified);
      expect(result.destinationUri, uri);
      expect(result.sourceBytes, bytes.length);
      expect(result.sourceSha256, scriptReportSha256(bytes));
      expect(written, orderedEquals(bytes));
      expect(suggested, 'qfli-script-acceptance.json');
      expect(readCalls, 1);
      // The opaque URI is kept unchanged, not turned into a guessed file path.
      expect(result.destinationPath, isNull);
      expect(reportFile('run-uri').readAsBytesSync(), orderedEquals(bytes));
    },
  );

  test('cancelled selection reads and writes nothing', () async {
    final bytes = rawReportBytes();
    reportFile('run-cancel').writeAsBytesSync(bytes, flush: true);
    var pickerCalls = 0;
    var writeCalls = 0;
    var readCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') {
        pickerCalls++;
        return null;
      }
      if (call.method == 'writeUri') writeCalls++;
      if (call.method == 'readUri') readCalls++;
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-cancel', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.cancelled);
    expect(result.wroteDestination, isFalse);
    expect(result.destinationLabel, isEmpty);
    expect(pickerCalls, 1);
    expect(writeCalls, 0);
    expect(readCalls, 0);
    expect(reportFile('run-cancel').readAsBytesSync(), orderedEquals(bytes));
  });

  test('selection without a path or URI is an explicit error', () async {
    reportFile('run-invalid').writeAsStringSync('{}');
    var writeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'name': 'only-a-name'};
      if (call.method == 'writeUri') writeCalls++;
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-invalid', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.invalidDestination);
    expect(result.wroteDestination, isFalse);
    expect(writeCalls, 0);
  });

  test('read-back with different length/hash is a digest mismatch', () async {
    final bytes = Uint8List.fromList(utf8.encode('{"value":"source"}\n'));
    reportFile('run-mismatch').writeAsBytesSync(bytes, flush: true);
    const uri = 'content://qfli/mismatch.json';
    final tampered = Uint8List.fromList(utf8.encode('{"value":"tamper"}\n'));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'uri': uri};
      if (call.method == 'writeUri') return null;
      if (call.method == 'readUri') return tampered;
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-mismatch', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.digestMismatch);
    expect(result.verified, isFalse);
    expect(result.wroteDestination, isTrue);
    expect(result.readBackBytes, tampered.length);
    expect(result.readBackSha256, scriptReportSha256(tampered));
    expect(result.readBackSha256, isNot(result.sourceSha256));
  });

  test('read-back failure stays written-but-unverified', () async {
    final bytes = Uint8List.fromList(utf8.encode('{"value":"source"}\n'));
    reportFile('run-unreadable').writeAsBytesSync(bytes, flush: true);
    const uri = 'content://qfli/unreadable.json';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'uri': uri};
      if (call.method == 'writeUri') return null;
      if (call.method == 'readUri') {
        throw PlatformException(code: 'PICKER_ERROR', message: 'denied');
      }
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-unreadable', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.writtenUnverified);
    expect(result.verified, isFalse);
    expect(result.wroteDestination, isTrue);
    expect(result.readBackBytes, isNull);
    expect(result.message, 'Read-back unavailable');
  });

  test('write failure clears the busy lane and a retry can verify', () async {
    final bytes = Uint8List.fromList(utf8.encode('{"value":"source"}\n'));
    reportFile('run-retry').writeAsBytesSync(bytes, flush: true);
    const uri = 'content://qfli/retry.json';
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'uri': uri};
      if (call.method == 'writeUri') {
        attempts++;
        if (attempts == 1) {
          throw PlatformException(code: 'PICKER_ERROR', message: 'disk full');
        }
        return null;
      }
      if (call.method == 'readUri') return bytes;
      return null;
    });

    final exporter = ScriptReportExporter();
    final first = await exporter.export(
      artifact('run-retry', ScriptReportRole.top),
    );
    expect(first.state, ScriptReportExportState.failed);
    expect(first.wroteDestination, isFalse);
    expect(exporter.busy, isFalse);

    final second = await exporter.export(
      artifact('run-retry', ScriptReportRole.top),
    );
    expect(second.state, ScriptReportExportState.verified);
    expect(attempts, 2);
    expect(reportFile('run-retry').readAsBytesSync(), orderedEquals(bytes));
  });

  test(
    'a second export while one is running is rejected by the busy lane',
    () async {
      reportFile('run-busy').writeAsStringSync('{}');
      const uri = 'content://qfli/busy.json';
      // Return the platform payload so the real picker decodes the document.
      final gate = Completer<Map<String, Object?>?>();
      final pickerEntered = Completer<void>();
      var writeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          pickerEntered.complete();
          return await gate.future;
        }
        if (call.method == 'writeUri') {
          writeCalls++;
          return null;
        }
        if (call.method == 'readUri') {
          return Uint8List.fromList(utf8.encode('{}'));
        }
        return null;
      });

      final exporter = ScriptReportExporter();
      final pending = exporter.export(
        artifact('run-busy', ScriptReportRole.top),
      );
      await pickerEntered.future;
      final second = await exporter.export(
        artifact('run-busy', ScriptReportRole.top),
      );
      expect(second.state, ScriptReportExportState.busy);
      expect(second.wroteDestination, isFalse);

      gate.complete({'uri': uri});
      final first = await pending;
      expect(first.state, ScriptReportExportState.verified);
      expect(writeCalls, 1);
    },
  );

  test('disposal during picker prevents the destination write', () async {
    reportFile('run-disposed').writeAsStringSync('{}');
    const uri = 'content://qfli/disposed.json';
    final gate = Completer<Map<String, Object?>?>();
    final pickerEntered = Completer<void>();
    var active = true;
    var writeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') {
        pickerEntered.complete();
        return await gate.future;
      }
      if (call.method == 'writeUri') {
        writeCalls++;
        return null;
      }
      if (call.method == 'readUri') {
        return Uint8List.fromList(<int>[0x7b, 0x7d]);
      }
      return null;
    });

    final exporter = ScriptReportExporter(isActive: () => active);
    final pending = exporter.export(
      artifact('run-disposed', ScriptReportRole.top),
    );
    await pickerEntered.future;
    active = false;
    exporter.dispose();
    gate.complete({'uri': uri});

    final result = await pending;
    expect(result.state, ScriptReportExportState.abandoned);
    expect(result.wroteDestination, isFalse);
    expect(writeCalls, 0);
  });

  test(
    'run replacement during picker prevents the destination write',
    () async {
      reportFile('run-replaced').writeAsStringSync('{}');
      const uri = 'content://qfli/replaced.json';
      final gate = Completer<Map<String, Object?>?>();
      final pickerEntered = Completer<void>();
      var active = true;
      var writeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          pickerEntered.complete();
          return await gate.future;
        }
        if (call.method == 'writeUri') {
          writeCalls++;
          return null;
        }
        return null;
      });

      final exporter = ScriptReportExporter(isActive: () => active);
      final pending = exporter.export(
        artifact('run-replaced', ScriptReportRole.top),
      );
      await pickerEntered.future;
      // Simulate the page starting a different run.
      active = false;
      gate.complete({'uri': uri});

      final result = await pending;
      expect(result.state, ScriptReportExportState.abandoned);
      expect(writeCalls, 0);
    },
  );

  test(
    'current-run inventory never substitutes an old run companion',
    () async {
      // Previous run produced all four files.
      for (final name in [
        'qfli-script-acceptance.json',
        'qfli-script-acceptance.json.lua.json',
        'qfli-script-acceptance.json.script.json',
        'qfli-script-acceptance.json.script.json.cases.jsonl',
      ]) {
        reportFile('run-old', name).writeAsStringSync('OLD:$name');
      }
      // Current run produced only the top checkpoint so far.
      reportFile('run-new').writeAsStringSync('NEW');

      final inventory = scriptReportArtifacts(reportFile('run-new'));
      expect(inventory.map((item) => item.basename), [
        'qfli-script-acceptance.json',
        'qfli-script-acceptance.json.lua.json',
        'qfli-script-acceptance.json.script.json',
        'qfli-script-acceptance.json.script.json.cases.jsonl',
      ]);
      expect(
        inventory
            .firstWhere((item) => item.role == ScriptReportRole.top)
            .exists,
        isTrue,
      );
      expect(
        inventory
            .firstWhere((item) => item.role == ScriptReportRole.lua)
            .exists,
        isFalse,
      );

      var pickerCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') pickerCalls++;
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-new', ScriptReportRole.lua),
      );
      expect(result.state, ScriptReportExportState.unavailableSource);
      expect(result.wroteDestination, isFalse);
      // No picker, no read, no write for a file this run did not produce.
      expect(pickerCalls, 0);
    },
  );

  test(
    'incomplete/fatal checkpoint exports raw bytes without promoting flags',
    () async {
      final checkpoint = <String, Object?>{
        'executionComplete': false,
        'ok': false,
        'deviceGatePassed': false,
        'offlinePlatformGatePassed': false,
        'fatalFailure': {'error': 'boom'},
      };
      final bytes = Uint8List.fromList(
        utf8.encode('${jsonEncode(checkpoint)}\n'),
      );
      reportFile('run-fatal').writeAsBytesSync(bytes, flush: true);
      final destination = p.join(root.path, 'fatal-export.json');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') return {'path': destination};
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-fatal', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.verified);
      // Byte-identical transfer, not a re-serialized JSON document.
      expect(File(destination).readAsBytesSync(), orderedEquals(bytes));
      final decoded = (jsonDecode(File(destination).readAsStringSync()) as Map)
          .cast<String, Object?>();
      expect(decoded['executionComplete'], isFalse);
      expect(decoded['ok'], isFalse);
      expect(decoded['deviceGatePassed'], isFalse);
      expect(decoded['offlinePlatformGatePassed'], isFalse);
      expect(decoded['fatalFailure'], isA<Map>());
    },
  );

  test(
    'cases artifact keeps its exact .jsonl basename and destination',
    () async {
      reportFile('run-cases').writeAsStringSync('{}');
      const casesName = 'qfli-script-acceptance.json.script.json.cases.jsonl';
      reportFile('run-cases', casesName).writeAsStringSync('{"row":1}\n');
      final destination = p.join(root.path, 'picked-cases');
      String? suggested;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          suggested = (call.arguments as Map)['suggestedName'] as String;
          return {'path': destination};
        }
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-cases', ScriptReportRole.cases),
      );

      expect(result.state, ScriptReportExportState.verified);
      expect(suggested, casesName);
      expect(File(destination).readAsStringSync(), '{"row":1}\n');
      expect(File('$destination.jsonl').existsSync(), isFalse);
    },
  );

  test('receipt records run identity and the exact source path', () async {
    final bytes = Uint8List.fromList(utf8.encode('{"value":"source"}\n'));
    final source = reportFile('run-identity');
    source.writeAsBytesSync(bytes, flush: true);
    final destination = p.join(root.path, 'identity-export.json');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'path': destination};
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-identity', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.verified);
    final receipt = result.toJson();
    expect(receipt['role'], 'top');
    expect(receipt['basename'], 'qfli-script-acceptance.json');
    expect(receipt['sourcePath'], source.path);
    expect(receipt['runDirectory'], p.dirname(source.path));
    // The receipt stays separate from acceptance: no gate key is emitted here.
    expect(receipt.containsKey('ok'), isFalse);
    expect(receipt.containsKey('executionComplete'), isFalse);
  });

  test('refuses a destination equal to the source artifact', () async {
    final bytes = rawReportBytes();
    final source = reportFile('run-guard-self');
    source.writeAsBytesSync(bytes, flush: true);
    var writeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'path': source.path};
      if (call.method == 'writeUri') writeCalls++;
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-guard-self', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.destinationUnsafe);
    expect(result.wroteDestination, isFalse);
    expect(result.destinationGuard, ScriptReportDestinationGuard.insideRun);
    expect(writeCalls, 0);
    // Evidence keeps its original bytes.
    expect(source.readAsBytesSync(), orderedEquals(bytes));
  });

  test(
    'refuses a destination equal to another current-run companion',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-sibling');
      source.writeAsBytesSync(bytes, flush: true);
      final companion = reportFile(
        'run-guard-sibling',
        'qfli-script-acceptance.json.lua.json',
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') return {'path': companion.path};
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-sibling', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.destinationUnsafe);
      expect(result.wroteDestination, isFalse);
      // The untouched companion was never created or overwritten.
      expect(companion.existsSync(), isFalse);
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
  );

  test('refuses a brand-new name inside the run reports directory', () async {
    final bytes = rawReportBytes();
    final source = reportFile('run-guard-inside');
    source.writeAsBytesSync(bytes, flush: true);
    final inside = p.join(source.parent.path, 'brand-new-name.json');
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') return {'path': inside};
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-guard-inside', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.destinationUnsafe);
    expect(result.destinationGuard, ScriptReportDestinationGuard.insideRun);
    expect(result.wroteDestination, isFalse);
    expect(File(inside).existsSync(), isFalse);
    expect(source.readAsBytesSync(), orderedEquals(bytes));
  });

  test(
    'refuses normalized path aliases that land inside the run directory',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-alias');
      source.writeAsBytesSync(bytes, flush: true);
      final reports = source.parent.path;
      final aliases = <String>[
        p.join(reports, '..', 'reports', 'aliased-name.json'),
        p.join(reports, '.', 'aliased-name.json'),
        p.join(root.path, 'run-guard-alias', 'reports', 'aliased-name.json'),
      ];

      for (final alias in aliases) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'saveDocument') return {'path': alias};
          return null;
        });
        final result = await ScriptReportExporter().export(
          artifact('run-guard-alias', ScriptReportRole.top),
        );
        expect(
          result.state,
          ScriptReportExportState.destinationUnsafe,
          reason: alias,
        );
        expect(
          result.destinationGuard,
          ScriptReportDestinationGuard.insideRun,
          reason: alias,
        );
        expect(result.wroteDestination, isFalse, reason: alias);
      }

      expect(File(p.join(reports, 'aliased-name.json')).existsSync(), isFalse);
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
  );

  test(
    'refuses a symlinked parent that resolves inside the run directory',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-link');
      source.writeAsBytesSync(bytes, flush: true);
      final reports = source.parent.path;
      final linkPath = p.join(root.path, 'reports-alias');
      Link(linkPath).createSync(reports);
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          return {'path': p.join(linkPath, 'linked-name.json')};
        }
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-link', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.destinationUnsafe);
      expect(result.destinationGuard, ScriptReportDestinationGuard.insideRun);
      expect(result.wroteDestination, isFalse);
      expect(File(p.join(reports, 'linked-name.json')).existsSync(), isFalse);
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
    skip: symlinkSkip,
  );

  test(
    'refuses a symlink followed by .. that physically re-enters the run dir',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-dotdot');
      source.writeAsBytesSync(bytes, flush: true);
      final reports = source.parent.path;
      Directory(p.join(reports, 'subdir')).createSync(recursive: true);
      final companion = File(
        p.join(reports, 'qfli-script-acceptance.json.lua.json'),
      )..writeAsStringSync('LUA-COMPANION-ORIGINAL');

      final external = Directory(p.join(root.path, 'external'))..createSync();
      final link = p.join(external.path, 'link');
      Link(link).createSync(p.join(reports, 'subdir'));
      // The picker spelling keeps `link/..`; the OS resolves the link first, so
      // this physically names the companion inside the run directory.
      final destination = p.join(
        link,
        '..',
        'qfli-script-acceptance.json.lua.json',
      );
      var writeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') return {'path': destination};
        if (call.method == 'writeUri') writeCalls++;
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-dotdot', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.destinationUnsafe);
      expect(result.destinationGuard, ScriptReportDestinationGuard.insideRun);
      expect(result.wroteDestination, isFalse);
      expect(writeCalls, 0);
      // The physically named companion and the source keep their bytes.
      expect(companion.readAsStringSync(), 'LUA-COMPANION-ORIGINAL');
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
    skip: dotDotSkip,
  );

  test(
    'refuses a path with a dangling symlink that cannot be resolved',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-dangling');
      source.writeAsBytesSync(bytes, flush: true);
      final external = Directory(p.join(root.path, 'external-dangling'))
        ..createSync();
      // The link target does not exist, so the physical destination cannot be
      // proven; a lexical fallback would wrongly call it safe.
      Link(
        p.join(external.path, 'dangling'),
      ).createSync(p.join(source.parent.path, 'missing-dir'));
      final destination = p.join(external.path, 'dangling', 'new.json');
      var pickerCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') {
          pickerCalls++;
          return {'path': destination};
        }
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-dangling', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.destinationUnsafe);
      expect(
        result.destinationGuard,
        ScriptReportDestinationGuard.unprovablePath,
      );
      expect(result.wroteDestination, isFalse);
      expect(pickerCalls, 1);
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
    skip: symlinkSkip,
  );

  test(
    'an external destination is proven outside the run and succeeds',
    () async {
      final bytes = rawReportBytes();
      final source = reportFile('run-guard-outside');
      source.writeAsBytesSync(bytes, flush: true);
      final destination = p.join(root.path, 'outside-report.json');
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') return {'path': destination};
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-outside', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.verified);
      expect(result.destinationGuard, ScriptReportDestinationGuard.outsideRun);
      expect(File(destination).readAsBytesSync(), orderedEquals(bytes));
      expect(source.readAsBytesSync(), orderedEquals(bytes));
    },
  );

  test(
    'an opaque URI destination stays opaque and records the limit',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{"value":"source"}\n'));
      reportFile('run-guard-uri').writeAsBytesSync(bytes, flush: true);
      const uri = 'content://qfli/opaque.json';
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveDocument') return {'uri': uri};
        if (call.method == 'writeUri') return null;
        if (call.method == 'readUri') return bytes;
        return null;
      });

      final result = await ScriptReportExporter().export(
        artifact('run-guard-uri', ScriptReportRole.top),
      );

      expect(result.state, ScriptReportExportState.verified);
      expect(
        result.destinationGuard,
        ScriptReportDestinationGuard.opaqueUriUnverified,
      );
      // The URI is never converted into a guessed local path.
      expect(result.destinationPath, isNull);
      expect(result.destinationUri, uri);
      expect(result.toJson()['destinationGuard'], 'opaqueUriUnverified');
    },
  );

  test('missing source is unavailable without opening the picker', () async {
    reportFile('run-missing').parent.createSync(recursive: true);
    var pickerCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'saveDocument') pickerCalls++;
      return null;
    });

    final result = await ScriptReportExporter().export(
      artifact('run-missing', ScriptReportRole.top),
    );

    expect(result.state, ScriptReportExportState.unavailableSource);
    expect(pickerCalls, 0);
  });
}
