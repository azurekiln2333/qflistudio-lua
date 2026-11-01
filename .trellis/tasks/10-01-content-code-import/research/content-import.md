# Current Contracts

- Offline routes: `home_page.dart` indexes 2 and 3 use `LocalTutorialsTab` and `ExampleCodeTab`.
- `ExampleCodeTab` currently receives store/auth but no settings; tutorial receives none.
- `ExampleDetailPage` keeps editable code in a TextEditingController. `_importProject` currently creates a project and only shows a snackbar.
- `ProjectStore.createProjectFromExample` creates a template and then overwrites its default entry. It has no filename option.
- `EditorPage` accepts `initialOpenPath`. `_restoreSession` currently returns after restoring an existing session, so the explicit file is ignored for an existing project.
- `RunnerService.findEntry` searches fixed default names, so a custom imported project entry needs an explicit persisted entry contract.
- `ProjectConfig.write` merges existing metadata. `AppPaths.storageDirectory` provides writable app-owned storage and `projectsRoot(create: true)` provides the default location.
- `ProjectStore.touch` and `TaskActivityService.report` are used by home navigation. Follow the same navigation/accounting pattern for registered imports.
- `FileService.isValidEntryName` validates basename characters; reject control characters and occupied paths as well.
- The core repository has extensive pre-existing dirty files. Only this task's additions may be staged. The root repository owns task artifacts and product workflow tests.
