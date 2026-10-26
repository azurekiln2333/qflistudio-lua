import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qfli_lua/main.dart' show luaProfile;
import 'package:qfli_studio_core/editor/editor_controller.dart';
import 'package:qfli_studio_core/editor/highlight_themes.dart';
import 'package:qfli_studio_core/models/project.dart';
// Exercise the tokenizer used by core's public highlight themes without
// introducing a separate product grammar or changing its runtime dependencies.
// ignore: depend_on_referenced_packages
import 'package:re_highlight/re_highlight.dart';

const _samples = <String, _Sample>{
  '.lua': _Sample(
    language: 'lua',
    source: '-- 语法 😀\r\nlocal message = [[hello]]\r\nreturn message .. 42\r\n',
    tokens: {
      'local': 'keyword',
      '[[hello]]': 'string',
      '-- 语法 😀': 'comment',
      '42': 'number',
    },
  ),
  '.js': _Sample(
    language: 'javascript',
    source:
        '// 语法 😀\r\nexport const message = "hello";\r\nconsole.log(message, 42);\r\n',
    tokens: {
      'export': 'keyword',
      'const': 'keyword',
      '"hello"': 'string',
      '// 语法 😀': 'comment',
      '42': 'number',
    },
  ),
  '.mjs': _Sample(
    language: 'javascript',
    source:
        '// 语法 😀\r\nexport const message = "hello";\r\nconsole.log(message, 42);\r\n',
    tokens: {
      'export': 'keyword',
      'const': 'keyword',
      '"hello"': 'string',
      '// 语法 😀': 'comment',
      '42': 'number',
    },
  ),
  '.ts': _Sample(
    language: 'typescript',
    source:
        '// 语法 😀\r\ninterface Greeting { message: string; }\r\n'
        'const answer: number = 42;\r\nconst message: string = "hello";\r\n',
    tokens: {
      'interface': 'keyword',
      'const': 'keyword',
      '"hello"': 'string',
      '// 语法 😀': 'comment',
      '42': 'number',
    },
  ),
  '.sh': _Sample(
    language: 'bash',
    source:
        '# 语法 😀\r\nif true; then\r\n  printf "%s" "hello" "\$message"\r\nfi\r\n',
    tokens: {
      'if': 'keyword',
      'printf': 'built_in',
      '"hello"': 'string',
      '# 语法 😀': 'comment',
      r'$message': 'variable',
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every declared Script extension has a text or bytecode audit', () {
    expect(
      luaProfile.supportedFileExtensions,
      unorderedEquals([..._samples.keys, '.luac']),
    );
  });

  for (final entry in _samples.entries) {
    final extension = entry.key;
    final sample = entry.value;
    for (final variant in [
      extension,
      '.${extension[1].toUpperCase()}${extension.substring(2)}',
      extension.toUpperCase(),
    ]) {
      testWidgets(
        '$variant selects ${sample.language} and tokenizes exact text',
        (tester) async {
          expect(
            luaProfile.supportedFileExtensions,
            contains(variant.toLowerCase()),
          );
          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          final context = tester.element(find.byType(Scaffold));
          // EditorPage passes null here; the editor worker owns source limits.
          final theme = HighlightThemes.themeFor(context, 'main$variant', null);
          expect(theme, isNotNull);
          expect(theme!.language, sample.language);
          expect(theme.theme['keyword']?.color, isNotNull);
          expect(theme.theme['string']?.color, isNotNull);
          expect(theme.theme['comment']?.color, isNotNull);
          final highlighter = Highlight()
            ..debugMode()
            ..registerLanguages(
              theme.languages.map((key, value) => MapEntry(key, value.mode)),
            );
          final rendered = _Tokens();
          highlighter
              .highlight(code: sample.source, language: theme.language!)
              .render(rendered);

          expect(rendered.parts.map((part) => part.text).join(), sample.source);
          for (final expected in sample.tokens.entries) {
            expect(
              rendered.parts.any(
                (part) =>
                    part.scope == expected.value &&
                    part.text.contains(expected.key),
              ),
              isTrue,
              reason: '$variant: $expected; actual: ${rendered.parts}',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('bytecode extensions do not select a source grammar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );
    final context = tester.element(find.byType(Scaffold));
    for (final extension in ['.luac', '.Luac', '.LUAC']) {
      expect(
        luaProfile.supportedFileExtensions,
        contains(extension.toLowerCase()),
      );
      expect(
        HighlightThemes.themeFor(context, 'main$extension', null),
        isNull,
        reason: 'Lua bytecode is executable input, not editable Lua source.',
      );
    }
  });

  test(
    'editor refuses Lua binary-header files without changing their bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'qfli_highlight_binary_',
      );
      addTearDown(() => root.delete(recursive: true));
      final editor = EditorController(
        project: Project.create(
          name: 'Bytecode',
          path: root.path,
          language: 'Lua',
        ),
      );
      addTearDown(editor.dispose);
      // A binary-header fixture exercises the actual editor boundary. This is
      // not a compiled chunk or a claim that bytecode executed in this test.
      const header = [
        0x1b,
        0x4c,
        0x75,
        0x61,
        0x54,
        0x00,
        0x19,
        0x93,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ];
      for (final extension in ['.luac', '.Luac', '.LUAC']) {
        final file = File(p.join(root.path, 'main$extension'));
        await file.writeAsBytes(header, flush: true);
        expect(await editor.openPath(file.path), '暂不支持打开二进制文件');
        expect(editor.files, isEmpty);
        expect(editor.current, isNull);
        expect(await file.readAsBytes(), header);
      }
    },
  );
}

class _Sample {
  const _Sample({
    required this.language,
    required this.source,
    required this.tokens,
  });

  final String language;
  final String source;
  final Map<String, String> tokens;
}

class _Tokens implements HighlightRenderer {
  final parts = <({String text, String? scope})>[];
  final _scopes = <String?>[];

  @override
  void addText(String text) =>
      parts.add((text: text, scope: _scopes.isEmpty ? null : _scopes.last));

  @override
  void openNode(DataNode node) =>
      _scopes.add(node.scope ?? (_scopes.isEmpty ? null : _scopes.last));

  @override
  void closeNode(DataNode node) => _scopes.removeLast();
}
