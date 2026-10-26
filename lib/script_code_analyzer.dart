import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:qfli_studio_core/services/code_analysis.dart';

import 'script_toolchain.dart';

/// Syntax diagnostics for exact unsaved JS/TS text. Imports and user code are
/// never evaluated. TypeScript uses transpileModule syntax/options diagnostics;
/// this provider does not perform semantic or project type checking.
class ScriptCodeAnalyzer implements CodeAnalyzer {
  const ScriptCodeAnalyzer({this.toolchain = const ScriptToolchain()});

  final ScriptToolchain toolchain;

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) async {
    final language = request.language.trim().toLowerCase();
    final typescript = {'typescript', 'ts'}.contains(language);
    if (!typescript && !{'javascript', 'js', 'ecmascript'}.contains(language)) {
      return _unavailable(
        'The Script parser only checks JavaScript/TypeScript.',
      );
    }
    final root = p.normalize(request.projectPath);
    final path = p.normalize(request.activeFilePath);
    if (!p.isAbsolute(root) ||
        !p.isAbsolute(path) ||
        !p.isWithin(root, path) ||
        root.contains('\u0000') ||
        path.contains('\u0000')) {
      return _unavailable('The active Script file is outside its project.');
    }
    final extension = p.extension(path).toLowerCase();
    if (typescript
        ? extension != '.ts'
        : !{'.js', '.mjs'}.contains(extension)) {
      return _unavailable(
        'The Script file extension does not match its language.',
      );
    }

    CodeDocumentSnapshot? active;
    final seen = <String>{};
    for (final document in request.documents) {
      final documentPath = p.normalize(document.path);
      if (!p.isAbsolute(document.path) ||
          !p.isWithin(root, documentPath) ||
          documentPath.contains('\u0000')) {
        return _unavailable('An editor snapshot is outside its project.');
      }
      final key = p.canonicalize(documentPath);
      if (!seen.add(key)) {
        return _unavailable('An editor snapshot is duplicated.');
      }
      if (p.equals(documentPath, path)) active = document;
    }
    if (active == null || active.revision != request.revision) {
      return _unavailable('The current Script editor snapshot is unavailable.');
    }
    if (utf8.encode(active.text).length > ScriptToolchain.maximumSourceBytes) {
      return _unavailable('Script source exceeds the live diagnostics limit.');
    }

    final ScriptToolResult result;
    try {
      result = await toolchain.checkSource(
        active.text,
        fileName: path,
        typescript: typescript,
      );
    } catch (error) {
      return _unavailable('The Script parser is unavailable: $error');
    }
    final hasErrors = result.diagnostics.any((item) => item.category == 1);
    if (!{0, 3}.contains(result.status) ||
        result.output.isNotEmpty ||
        (result.status == 3 && !hasErrors) ||
        (result.status == 0 && hasErrors) ||
        (result.status == 0 && result.error.isNotEmpty)) {
      return _unavailable(
        'The Script parser failed (status ${result.status}): ${result.error}',
      );
    }
    final diagnostics = <CodeDiagnostic>[];
    for (final item in result.diagnostics) {
      if (!p.equals(p.normalize(item.filePath), path) ||
          item.startOffset < 0 ||
          item.endOffset < item.startOffset ||
          item.endOffset > active.text.length ||
          item.message.trim().isEmpty ||
          item.category < 0 ||
          item.category > 3) {
        return _unavailable(
          'The Script parser returned an invalid diagnostic.',
        );
      }
      diagnostics.add(
        CodeDiagnostic(
          filePath: path,
          startOffset: item.startOffset,
          endOffset: item.endOffset,
          message: item.message,
          source: typescript ? 'TypeScript syntax' : 'QuickJS',
          code: item.code,
          severity: switch (item.category) {
            0 => CodeDiagnosticSeverity.warning,
            1 => CodeDiagnosticSeverity.error,
            2 => CodeDiagnosticSeverity.hint,
            _ => CodeDiagnosticSeverity.information,
          },
        ),
      );
    }
    return CodeAnalysisResult(diagnostics: List.unmodifiable(diagnostics));
  }

  static CodeAnalysisResult _unavailable(String reason) =>
      CodeAnalysisResult(unavailableReason: reason);
}
