import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:qfli_studio_core/content/asset_content_repository.dart';
import 'package:qfli_studio_core/content/content_repository.dart';

/// Loads one content asset by its logical path.
///
/// Injecting the loader keeps the repository testable without a widget binding
/// and lets a host read the same documents from disk during verification.
typedef LuaContentAssetLoader = Future<String> Function(String asset);

/// Product-owned content source for the Lua app.
///
/// Responsibilities, in order:
/// 1. Serve the app's own Lua curriculum from `assets/content/lua_*.json`.
/// 2. Apply the caller's [ContentFilter] so a Lua tab never shows another
///    language's entries (the shared aggregate catalog mixes them).
/// 3. Keep every other Script language reachable through an injected
///    [fallback] repository, without duplicating Lua entries.
/// 4. Parse and cache once per instance; the documents are immutable package
///    assets, so repeated tab switches must not re-decode megabytes.
class LuaContentRepository implements ContentRepository {
  LuaContentRepository({
    ContentRepository? fallback,
    LuaContentAssetLoader? loader,
    this.language = 'lua',
  }) : _fallback = fallback,
       _loader = loader;

  /// Convenience constructor for the app: bundled assets plus the shared
  /// catalog as the fallback for non-Lua Script languages.
  factory LuaContentRepository.bundled({ContentRepository? fallback}) =>
      LuaContentRepository(
        fallback: fallback ?? AssetContentRepository(),
        loader: _rootBundleLoader,
      );

  static const String tutorialAsset = 'assets/content/lua_tutorials.json';
  static const String exampleAsset = 'assets/content/lua_examples.json';

  /// The language this product owns.
  final String language;

  final ContentRepository? _fallback;
  final LuaContentAssetLoader? _loader;

  Future<ContentCatalog>? _catalog;

  /// Number of parse passes performed by this instance. Exposed for tests that
  /// assert the cache really prevents re-decoding.
  @visibleForTesting
  int get parseCount => _parseCount;
  int _parseCount = 0;

  @override
  Future<ContentCatalog> load() => _catalog ??= _loadCatalog();

  @override
  Future<List<TutorialContent>> tutorials({
    ContentFilter filter = const ContentFilter(),
  }) async {
    final own = <TutorialContent>[
      if (_ownsLanguage(filter))
        for (final tutorial in (await load()).tutorials)
          if (filter.matches(tutorial)) tutorial,
    ];
    final fallbackFilter = _fallbackFilter(filter);
    if (fallbackFilter == null) return own;
    final fallback = await _fallback!.tutorials(filter: fallbackFilter);
    return [
      ...own,
      for (final tutorial in fallback)
        if (!_isOwnedLanguage(tutorial.language)) tutorial,
    ];
  }

  @override
  Future<List<ExampleContent>> examples({
    ContentFilter filter = const ContentFilter(),
  }) async {
    final own = <ExampleContent>[
      if (_ownsLanguage(filter))
        for (final example in (await load()).examples)
          if (filter.matches(example)) example,
    ];
    final fallbackFilter = _fallbackFilter(filter);
    if (fallbackFilter == null) return own;
    final fallback = await _fallback!.examples(filter: fallbackFilter);
    return [
      ...own,
      for (final example in fallback)
        if (!_isOwnedLanguage(example.language)) example,
    ];
  }

  bool _isOwnedLanguage(String value) =>
      value.trim().toLowerCase() == language.toLowerCase();

  /// Whether this repository may contribute its own entries for [filter].
  ///
  /// A language filter naming another language, or a type filter that excludes
  /// this product's type, must yield nothing from the local catalog.
  bool _ownsLanguage(ContentFilter filter) {
    final requestedLanguage = filter.language?.trim().toLowerCase();
    if (requestedLanguage != null &&
        requestedLanguage.isNotEmpty &&
        requestedLanguage != language.toLowerCase()) {
      return false;
    }
    final types = filter.types;
    if (types != null && types.isNotEmpty) {
      final normalized = {for (final type in types) type.trim().toLowerCase()};
      if (!normalized.contains(language.toLowerCase())) return false;
    }
    final type = filter.type?.trim().toLowerCase();
    if (type != null && type.isNotEmpty && type != language.toLowerCase()) {
      return false;
    }
    return true;
  }

  /// Narrows [filter] to the languages the fallback still has to answer for.
  ///
  /// Returns null when nothing remains, so the shared aggregate catalog is not
  /// decoded at all for a query the local catalog can answer alone.
  ContentFilter? _fallbackFilter(ContentFilter filter) {
    if (_fallback == null) return null;
    final requestedLanguage = filter.language?.trim().toLowerCase();
    if (requestedLanguage != null && requestedLanguage.isNotEmpty) {
      // An explicit language is fully answered by exactly one side.
      return requestedLanguage == language.toLowerCase() ? null : filter;
    }
    final type = filter.type?.trim().toLowerCase();
    if (type != null && type.isNotEmpty) {
      return type == language.toLowerCase() ? null : filter;
    }
    final types = filter.types;
    if (types == null || types.isEmpty) {
      // No restriction at all: other languages are still reachable, so the
      // fallback answers and Lua duplicates are dropped afterwards.
      return filter;
    }
    final remaining = {
      for (final candidate in types)
        if (candidate.trim().toLowerCase() != language.toLowerCase())
          candidate.trim().toLowerCase(),
    };
    if (remaining.isEmpty) return null;
    return ContentFilter(
      language: filter.language,
      type: filter.type,
      locale: filter.locale,
      types: remaining,
    );
  }

  Future<ContentCatalog> _loadCatalog() async {
    final loader = _loader ?? _rootBundleLoader;
    final sources = await Future.wait([
      _loadString(loader, tutorialAsset),
      _loadString(loader, exampleAsset),
    ]);
    _parseCount++;
    final catalog = await compute(
      _parseLuaCatalog,
      sources,
      debugLabel: 'parse-lua-content-catalog',
    );
    _validate(catalog);
    return catalog;
  }

  Future<String> _loadString(LuaContentAssetLoader loader, String asset) async {
    try {
      return await loader(asset);
    } on Object catch (error) {
      throw LuaContentAssetException(asset, '$error');
    }
  }

  void _validate(ContentCatalog catalog) {
    if (catalog.tutorials.isEmpty) {
      throw const LuaContentAssetException(tutorialAsset, 'no Lua tutorials');
    }
    if (catalog.examples.isEmpty) {
      throw const LuaContentAssetException(exampleAsset, 'no Lua examples');
    }
    for (final tutorial in catalog.tutorials) {
      if (!_isOwnedLanguage(tutorial.language)) {
        throw LuaContentAssetException(
          tutorialAsset,
          'entry ${tutorial.id} is not $language',
        );
      }
      if (tutorial.id.isEmpty || tutorial.lessons.isEmpty) {
        throw LuaContentAssetException(
          tutorialAsset,
          'entry ${tutorial.id} has no id or no lessons',
        );
      }
    }
    for (final example in catalog.examples) {
      if (!_isOwnedLanguage(example.language)) {
        throw LuaContentAssetException(
          exampleAsset,
          'entry ${example.id} is not $language',
        );
      }
      if (example.id.isEmpty || example.code.isEmpty) {
        throw LuaContentAssetException(
          exampleAsset,
          'entry ${example.id} has no id or no code',
        );
      }
    }
  }
}

ContentCatalog _parseLuaCatalog(List<String> sources) =>
    ContentCatalog.fromJson(
      tutorialsSource: sources[0],
      examplesSource: sources[1],
    );

Future<String> _rootBundleLoader(String asset) async {
  final keys = <String>['packages/qfli_lua/$asset', asset];
  final failures = <String>[];
  for (final key in keys) {
    try {
      return await rootBundle.loadString(key);
    } on FlutterError catch (error) {
      failures.add('$key: ${error.message}');
    } on Object catch (error) {
      failures.add('$key: $error');
    }
  }
  throw LuaContentAssetException(asset, failures.join(' | '));
}

/// Raised when a Lua content asset is missing or malformed.
class LuaContentAssetException implements Exception {
  const LuaContentAssetException(this.asset, this.message);

  final String asset;
  final String message;

  @override
  String toString() => 'Lua content asset $asset is unusable: $message';
}

/// Counts authored Lua topics in a parsed catalog, for diagnostics and tests.
int luaTopicCount(ContentCatalog catalog) {
  var lessons = 0;
  for (final tutorial in catalog.tutorials) {
    lessons += tutorial.lessons.length;
  }
  return lessons;
}
