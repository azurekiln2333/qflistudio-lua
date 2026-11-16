import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'workspace.dart';

WorkspaceStorage createStorage() => BrowserWorkspaceStorage();
SourceFileTransfer createFileTransfer() => BrowserSourceFileTransfer();

class BrowserWorkspaceStorage implements WorkspaceStorage {
  BrowserWorkspaceStorage({this.key = 'qfliscript.workspace.v1'});

  final String key;

  @override
  String? read() => web.window.localStorage.getItem(key);

  @override
  void write(String value) => web.window.localStorage.setItem(key, value);
}

class BrowserSourceFileTransfer implements SourceFileTransfer {
  @override
  Future<List<SourceFile>> importFiles() async {
    final result = Completer<List<SourceFile>>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..multiple = true
      ..accept = '.lua,.js,.mjs,.ts,.sh,.json,.txt,.md,.html,.css'
      ..style.display = 'none';
    input.onchange = ((web.Event event) {
      () async {
        try {
          final files = <SourceFile>[];
          final selected = input.files;
          if (selected != null) {
            for (var index = 0; index < selected.length; index++) {
              final file = selected.item(index)!;
              // Strict decoding refuses binary/malformed input without data loss.
              final bytes = (await file.arrayBuffer().toDart).toDart
                  .asUint8List();
              files.add(
                SourceFile(name: file.name, content: utf8.decode(bytes)),
              );
            }
          }
          result.complete(files);
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      }();
    }).toJS;
    input.oncancel = ((web.Event event) => result.complete(
      <SourceFile>[],
    )).toJS;
    web.document.body!.append(input);
    try {
      input.click();
      return await result.future;
    } finally {
      input.remove();
    }
  }

  @override
  void exportFile(SourceFile file) {
    final blob = web.Blob(
      <JSAny>[file.content.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = file.name
      ..style.display = 'none';
    web.document.body!.append(anchor);
    try {
      anchor.click();
    } finally {
      anchor.remove();
      // Let the browser consume the download before releasing its URL.
      Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
    }
  }
}

void Function() watchUnsavedChanges(WebWorkspace workspace) {
  final listener = ((web.Event event) {
    if (!workspace.isDirty) return;
    event.preventDefault();
    (event as web.BeforeUnloadEvent).returnValue = '';
  }).toJS;
  web.window.addEventListener('beforeunload', listener);
  return () => web.window.removeEventListener('beforeunload', listener);
}
