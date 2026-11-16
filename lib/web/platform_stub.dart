import 'workspace.dart';

WorkspaceStorage createStorage() => throw UnsupportedError('Browser only');
SourceFileTransfer createFileTransfer() =>
    throw UnsupportedError('Browser only');
void Function() watchUnsavedChanges(WebWorkspace workspace) => () {};
