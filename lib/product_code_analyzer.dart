import 'package:qfli_studio_core/services/code_analysis.dart';

import 'lua_code_analyzer.dart';
import 'script_code_analyzer.dart';
import 'shell_code_analyzer.dart';

/// Routes each exact editor snapshot to its offline language parser.
class ProductCodeAnalyzer implements CodeAnalyzer {
  const ProductCodeAnalyzer();

  @override
  Future<CodeAnalysisResult> analyze(CodeAnalysisRequest request) =>
      switch (request.language.trim().toLowerCase()) {
        'lua' => const LuaCodeAnalyzer().analyze(request),
        'javascript' ||
        'js' ||
        'ecmascript' ||
        'typescript' ||
        'ts' => const ScriptCodeAnalyzer().analyze(request),
        'shell' || 'sh' || 'bash' => const ShellCodeAnalyzer().analyze(request),
        _ => Future.value(
          const CodeAnalysisResult(
            unavailableReason:
                'No offline parser is available for this language.',
          ),
        ),
      };
}
