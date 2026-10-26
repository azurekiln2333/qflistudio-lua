/// Offline export of the current-run Script acceptance report artifacts.
///
/// This is an audit-only retrieval boundary. It copies the exact bytes that the
/// current run produced to a destination the user explicitly selects through
/// [PickerService], then reads those bytes back to verify length and SHA-256.
///
/// Contract notes (see
/// `research/lua-report-retrieval-readiness-20261024.md`):
/// - Never parse and re-serialize JSON/JSONL. Source bytes are copied verbatim.
/// - Never guess a sandbox path, append another extension or derive a second
///   destination. Write only the returned local `path` or opaque `uri`.
/// - Only offer files that actually exist in the current run report directory,
///   so an old companion cannot stand in for this run.
/// - Refuse a local destination that resolves inside the current run report
///   directory. The comparison uses resolved, case-folded paths, so a string
///   alias or symlinked parent cannot overwrite current-run evidence.
/// - Keep an opaque URI opaque. Which local file it maps to cannot be proven,
///   so no path is guessed and the limitation is recorded on the receipt.
/// - Read the source only after a valid destination has been chosen.
/// - One export lane at a time; a disposed page must not start a new write.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/picker_service.dart';
import 'package:qfli_studio_core/tools/offline_tools.dart';

/// Roles of the four-file report family, in display order.
///
/// The basenames are derived from the top report basename so a caller that
/// passes a freshly-created per-run top file gets the matching companions.
enum ScriptReportRole { top, lua, script, cases }

/// One report artifact belonging to a single run.
class ScriptReportArtifact {
  const ScriptReportArtifact({
    required this.role,
    required this.basename,
    required this.file,
    required this.reportDirectory,
    required this.exists,
  });

  final ScriptReportRole role;

  /// Basename passed to the picker; never rewritten or extended.
  final String basename;

  /// Current-run file path.
  final File file;

  /// Absolute directory the artifact must live in (the current run's report
  /// directory). Used to reject a rebound/foreign path.
  final String reportDirectory;

  /// Whether the file existed when the inventory was taken.
  final bool exists;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'basename': basename,
    'path': file.path,
    'exists': exists,
  };
}

/// Outcome taxonomy for one export attempt.
///
/// The states are deliberately distinct so a written-but-unverified transfer is
/// never reported as a clean success.
enum ScriptReportExportState {
  /// Read-back byte length and SHA-256 both matched the source.
  verified,

  /// The user dismissed the picker. Nothing was read or written.
  cancelled,

  /// The picker returned a selection with neither a nonempty path nor URI.
  invalidDestination,

  /// The chosen local destination is inside the current run report directory or
  /// could not be proven outside it. Refused before the source is read and
  /// before anything is written, so evidence keeps its original bytes.
  destinationUnsafe,

  /// The current-run source is missing or could not be read.
  unavailableSource,

  /// The destination accepted the write but read-back was unavailable.
  writtenUnverified,

  /// Read-back succeeded but its length/SHA-256 did not match the source.
  digestMismatch,

  /// The picker, write or read operation threw.
  failed,

  /// The page was disposed or the run was replaced before the write started.
  abandoned,

  /// Another export was already running on the single lane.
  busy,
}

/// Provenance verdict for a selected destination.
///
/// A local path is compared as a resolved, case-folded path so a string alias
/// cannot masquerade as a new destination. An opaque URI stays opaque: the
/// picker contract cannot prove which local file it maps to, so no path is
/// guessed and the limitation is recorded instead.
enum ScriptReportDestinationGuard {
  /// Local path proven to be outside the current run report directory.
  outsideRun,

  /// Local path resolved inside the current run report directory.
  insideRun,

  /// Local path could not be resolved, so it cannot be proven outside the run
  /// directory. Refused conservatively rather than guessed.
  unprovablePath,

  /// Opaque URI. Which local file it maps to cannot be proven.
  opaqueUriUnverified,
}

/// Result receipt for one artifact export.
class ScriptReportExportResult {
  const ScriptReportExportResult({
    required this.artifact,
    required this.state,
    this.sourceBytes,
    this.sourceSha256,
    this.destinationPath,
    this.destinationUri,
    this.destinationGuard,
    this.readBackBytes,
    this.readBackSha256,
    this.message,
    this.error,
  });

  final ScriptReportArtifact artifact;
  final ScriptReportExportState state;
  final int? sourceBytes;
  final String? sourceSha256;
  final String? destinationPath;
  final String? destinationUri;

  /// Provenance verdict for the selected destination; null when no destination
  /// was validated (cancelled, busy, unavailable source).
  final ScriptReportDestinationGuard? destinationGuard;
  final int? readBackBytes;
  final String? readBackSha256;
  final String? message;
  final Object? error;

  bool get verified => state == ScriptReportExportState.verified;

  /// True once bytes reached the destination (even if unverified).
  bool get wroteDestination =>
      state == ScriptReportExportState.verified ||
      state == ScriptReportExportState.writtenUnverified ||
      state == ScriptReportExportState.digestMismatch;

  String get destinationLabel => destinationPath ?? destinationUri ?? '';

  Map<String, Object?> toJson() => {
    'role': artifact.role.name,
    'basename': artifact.basename,
    // Run/workspace identity travels with the receipt so a collected file can
    // be traced back to the attempt that produced it.
    'sourcePath': artifact.file.path,
    'runDirectory': artifact.reportDirectory,
    'state': state.name,
    'sourceBytes': sourceBytes,
    'sourceSha256': sourceSha256,
    'destinationPath': destinationPath,
    'destinationUri': destinationUri,
    'destinationGuard': destinationGuard?.name,
    'readBackBytes': readBackBytes,
    'readBackSha256': readBackSha256,
    'message': message,
    'error': error == null ? null : '$error',
  };
}

typedef ScriptReportSavePicker =
    Future<PickedDocument?> Function({String suggestedName});
typedef ScriptReportReadUri = Future<Uint8List> Function(String uri);
typedef ScriptReportWriteUri =
    Future<void> Function(String uri, Uint8List bytes);

/// SHA-256 of exact report bytes, hex encoded.
String scriptReportSha256(List<int> bytes) => OfflineDigest.sha256Bytes(
  bytes,
).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

/// Builds the artifact inventory for a single run's top report file.
///
/// All four basenames live directly beside [topReportFile] in the same fresh
/// directory. Missing files are still listed (so the UI can show them as not
/// produced) but only existing files can be exported.
List<ScriptReportArtifact> scriptReportArtifacts(File topReportFile) {
  final directory = topReportFile.parent.path;
  final base = p.basename(topReportFile.path);
  final entries = <(ScriptReportRole, String)>[
    (ScriptReportRole.top, base),
    (ScriptReportRole.lua, '$base.lua.json'),
    (ScriptReportRole.script, '$base.script.json'),
    (ScriptReportRole.cases, '$base.script.json.cases.jsonl'),
  ];
  final artifacts = <ScriptReportArtifact>[];
  for (final (role, basename) in entries) {
    final file = File(p.join(directory, basename));
    artifacts.add(
      ScriptReportArtifact(
        role: role,
        basename: basename,
        file: file,
        reportDirectory: directory,
        exists: file.existsSync(),
      ),
    );
  }
  return artifacts;
}

/// Single-lane, read-back-verified exporter for current-run report artifacts.
class ScriptReportExporter {
  ScriptReportExporter({
    ScriptReportSavePicker? pick,
    ScriptReportReadUri? readUri,
    ScriptReportWriteUri? writeUri,
    this.isActive,
  }) : _pick = pick ?? PickerService.saveDocument,
       _readUri = readUri ?? PickerService.readUri,
       _writeUri = writeUri ?? PickerService.writeUri;

  final ScriptReportSavePicker _pick;
  final ScriptReportReadUri _readUri;
  final ScriptReportWriteUri _writeUri;

  /// Guard re-checked after every `await`. Return `false` once the page is
  /// disposed or the run identity has changed; that stops a later write.
  final bool Function()? isActive;

  bool _busy = false;
  bool _disposed = false;

  bool get busy => _busy;
  bool get disposed => _disposed;

  /// Permanently stops new writes for this exporter.
  void dispose() {
    _disposed = true;
  }

  bool get _canContinue => !_disposed && (isActive?.call() ?? true);

  ScriptReportExportResult _result(
    ScriptReportArtifact artifact,
    ScriptReportExportState state, {
    int? sourceBytes,
    String? sourceSha256,
    String? destinationPath,
    String? destinationUri,
    ScriptReportDestinationGuard? destinationGuard,
    int? readBackBytes,
    String? readBackSha256,
    String? message,
    Object? error,
  }) => ScriptReportExportResult(
    artifact: artifact,
    state: state,
    sourceBytes: sourceBytes,
    sourceSha256: sourceSha256,
    destinationPath: destinationPath,
    destinationUri: destinationUri,
    destinationGuard: destinationGuard,
    readBackBytes: readBackBytes,
    readBackSha256: readBackSha256,
    message: message,
    error: error,
  );

  /// Exports one current-run artifact. Honours the single busy lane and the
  /// active guard, copies raw bytes and verifies them by reading back.
  Future<ScriptReportExportResult> export(ScriptReportArtifact artifact) async {
    if (_disposed) {
      return _result(
        artifact,
        ScriptReportExportState.abandoned,
        message: 'Page disposed before export',
      );
    }
    if (_busy) {
      return _result(
        artifact,
        ScriptReportExportState.busy,
        message: 'Another export is already running',
      );
    }
    _busy = true;
    try {
      if (!_canContinue) {
        return _result(
          artifact,
          ScriptReportExportState.abandoned,
          message: 'Run changed before export started',
        );
      }
      if (!_sourceInsideRun(artifact) || !await artifact.file.exists()) {
        return _result(
          artifact,
          ScriptReportExportState.unavailableSource,
          message: 'Source file missing from the current run',
        );
      }

      // Choose the destination before reading the source bytes.
      PickedDocument? selected;
      try {
        selected = await _pick(suggestedName: artifact.basename);
      } catch (error) {
        return _result(
          artifact,
          ScriptReportExportState.failed,
          message: 'Picker failed',
          error: error,
        );
      }
      if (!_canContinue) {
        return _result(
          artifact,
          ScriptReportExportState.abandoned,
          message: 'Run changed during destination selection',
        );
      }
      if (selected == null) {
        return _result(
          artifact,
          ScriptReportExportState.cancelled,
          message: 'Destination selection cancelled',
        );
      }
      final path = selected.path;
      final uri = selected.uri;
      final hasPath = path != null && path.isNotEmpty;
      final hasUri = uri != null && uri.isNotEmpty;
      if (!hasPath && !hasUri) {
        return _result(
          artifact,
          ScriptReportExportState.invalidDestination,
          message: 'Picker returned neither a path nor a URI',
        );
      }

      // Refuse a local destination that would overwrite current-run evidence.
      // Both sides are resolved and case-folded, so `reports/../reports/x`, a
      // leading `./` and a symlinked parent cannot pass a plain string check.
      // An opaque URI is kept opaque; no path is guessed for it.
      final guard = _destinationGuard(artifact, path: hasPath ? path : null);
      if (guard == ScriptReportDestinationGuard.insideRun ||
          guard == ScriptReportDestinationGuard.unprovablePath) {
        return _result(
          artifact,
          ScriptReportExportState.destinationUnsafe,
          destinationPath: hasPath ? path : null,
          destinationGuard: guard,
          message: guard == ScriptReportDestinationGuard.insideRun
              ? 'Destination is inside the current run report directory'
              : 'Destination could not be proven outside the run directory',
        );
      }

      // Read the exact current-run bytes. No parse/re-serialize.
      Uint8List bytes;
      try {
        bytes = await artifact.file.readAsBytes();
      } catch (error) {
        return _result(
          artifact,
          ScriptReportExportState.unavailableSource,
          destinationPath: hasPath ? path : null,
          destinationUri: hasUri ? uri : null,
          destinationGuard: guard,
          message: 'Source could not be read',
          error: error,
        );
      }
      final sourceSha = scriptReportSha256(bytes);
      if (!_canContinue) {
        return _result(
          artifact,
          ScriptReportExportState.abandoned,
          sourceBytes: bytes.length,
          sourceSha256: sourceSha,
          destinationGuard: guard,
          message: 'Run changed before writing to the destination',
        );
      }

      // Write the exact bytes to the exact selected destination only.
      try {
        if (hasPath) {
          await File(path).writeAsBytes(bytes, flush: true);
        } else {
          await _writeUri(uri!, bytes);
        }
      } catch (error) {
        return _result(
          artifact,
          ScriptReportExportState.failed,
          sourceBytes: bytes.length,
          sourceSha256: sourceSha,
          destinationPath: hasPath ? path : null,
          destinationUri: hasUri ? uri : null,
          destinationGuard: guard,
          message: 'Destination write failed',
          error: error,
        );
      }

      // Verify by reading the destination back. A read-back failure is
      // written-but-unverified, never clean success.
      Uint8List readBack;
      try {
        readBack = hasPath
            ? await File(path).readAsBytes()
            : await _readUri(uri!);
      } catch (error) {
        return _result(
          artifact,
          ScriptReportExportState.writtenUnverified,
          sourceBytes: bytes.length,
          sourceSha256: sourceSha,
          destinationPath: hasPath ? path : null,
          destinationUri: hasUri ? uri : null,
          destinationGuard: guard,
          message: 'Read-back unavailable',
          error: error,
        );
      }
      final readBackSha = scriptReportSha256(readBack);
      if (readBack.length != bytes.length || readBackSha != sourceSha) {
        return _result(
          artifact,
          ScriptReportExportState.digestMismatch,
          sourceBytes: bytes.length,
          sourceSha256: sourceSha,
          destinationPath: hasPath ? path : null,
          destinationUri: hasUri ? uri : null,
          destinationGuard: guard,
          readBackBytes: readBack.length,
          readBackSha256: readBackSha,
          message: 'Read-back bytes differ from the source',
        );
      }
      return _result(
        artifact,
        ScriptReportExportState.verified,
        sourceBytes: bytes.length,
        sourceSha256: sourceSha,
        destinationPath: hasPath ? path : null,
        destinationUri: hasUri ? uri : null,
        destinationGuard: guard,
        readBackBytes: readBack.length,
        readBackSha256: readBackSha,
      );
    } finally {
      _busy = false;
    }
  }

  /// True only when the source resolves inside its run report directory.
  ///
  /// This is a real constraint, not a formality: a source file symlinked out of
  /// the run directory is refused instead of exported.
  static bool _sourceInsideRun(ScriptReportArtifact artifact) {
    final runDirectory = _canonicalPath(artifact.reportDirectory);
    final source = _canonicalPath(artifact.file.path);
    if (runDirectory == null || source == null) return false;
    return _isInsideDirectory(source, runDirectory);
  }

  static ScriptReportDestinationGuard _destinationGuard(
    ScriptReportArtifact artifact, {
    String? path,
  }) {
    // No local path: an opaque URI. Keep it opaque and record the limitation.
    if (path == null) return ScriptReportDestinationGuard.opaqueUriUnverified;
    final runDirectory = _canonicalPath(artifact.reportDirectory);
    final destination = _canonicalPath(path);
    if (runDirectory == null || destination == null) {
      return ScriptReportDestinationGuard.unprovablePath;
    }
    return _isInsideDirectory(destination, runDirectory)
        ? ScriptReportDestinationGuard.insideRun
        : ScriptReportDestinationGuard.outsideRun;
  }
}

/// Canonical, case-folded physical path used only for provenance comparison.
///
/// Resolution follows the platform's real path semantics, so the guard sees the
/// same physical destination the later write will. On POSIX a `symlink/..`
/// resolves the link before the dot segment; on Windows the dot segment is
/// resolved first. Either spelling is resolved before any lexical collapse, and
/// a lexical normalize would hide that platform difference. Returns null when
/// physical resolution fails; the caller must then refuse rather than guess.
String? _canonicalPath(String path) {
  try {
    final absolute = p.isAbsolute(path) ? path : p.join(p.current, path);
    final resolved = _resolveExistingAncestor(absolute);
    // The existing prefix is now physically resolved, so a lexical collapse of
    // the remaining tail (`.`/`..`) is unambiguous.
    final folded = p.canonicalize(resolved);
    return Platform.isWindows ? folded.toLowerCase() : folded;
  } on FileSystemException {
    return null;
  }
}

/// Physically resolves [absolute] or its longest existing ancestor.
///
/// Throws [FileSystemException] when a component cannot be resolved. It never
/// falls back to a lexical spelling, because an unresolved path must not
/// masquerade as proven outside the evidence directory.
String _resolveExistingAncestor(String absolute) {
  var existing = absolute;
  final tail = <String>[];
  while (true) {
    if (FileSystemEntity.typeSync(existing) != FileSystemEntityType.notFound) {
      break;
    }
    // A dangling symlink cannot be physically resolved, yet the OS still
    // follows it on write. Refuse instead of reconstructing a lexical path.
    if (FileSystemEntity.typeSync(existing, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException('Unresolvable symlink', existing);
    }
    final parent = p.dirname(existing);
    if (parent == existing) {
      throw FileSystemException('No existing ancestor', absolute);
    }
    tail.insert(0, p.basename(existing));
    existing = parent;
  }
  final type = FileSystemEntity.typeSync(existing);
  final resolved = type == FileSystemEntityType.directory
      ? Directory(existing).resolveSymbolicLinksSync()
      : File(existing).resolveSymbolicLinksSync();
  return tail.isEmpty ? resolved : p.joinAll(<String>[resolved, ...tail]);
}

bool _isInsideDirectory(String candidate, String directory) {
  if (candidate == directory) return true;
  final prefix = directory.endsWith(p.separator)
      ? directory
      : '$directory${p.separator}';
  return candidate.startsWith(prefix);
}
