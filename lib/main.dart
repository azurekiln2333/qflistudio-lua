import 'app_native.dart'
    if (dart.library.js_interop) 'web/app_web.dart'
    as bootstrap;

// Keep the native profile available to existing product integrations and tests.
export 'app_native.dart'
    if (dart.library.js_interop) 'web/app_web.dart'
    hide main;

void main() => bootstrap.main();
