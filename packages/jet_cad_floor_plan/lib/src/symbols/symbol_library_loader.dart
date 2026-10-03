// The symbol library's loader (spec 09b D2, R-4): one per app, owned by
// `FloorPlannerApp` above the document host, so a document swap -- which
// rebuilds the shell -- never reads the asset again.
//
// With `export/export_font.dart`, the only file of the app that touches
// `rootBundle`.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'symbol_library.dart';
import 'symbol_library_state.dart';

/// The bundled library's asset key: the package's own asset (declared in
/// its `pubspec.yaml`), read under its `packages/` key (spec 14 V-10).
const String kFurnitureLibraryAsset =
    'packages/jet_cad_floor_plan/assets/library/furniture.jetlib';

/// Reads the bundled library: [bundle] ([rootBundle] when null) at
/// [kFurnitureLibraryAsset], the package's key (spec 14 V-10).
Future<Uint8List> readBundledLibrary([AssetBundle? bundle]) async {
  final data = await (bundle ?? rootBundle).load(kFurnitureLibraryAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// One library the loader reads (spec 14 V-4): a [name] its errors use and
/// a [read]er of its bytes. A host adds its own beside the planner's
/// [furnitureSymbolSource].
final class SymbolLibrarySource {
  const SymbolLibrarySource({required this.name, required this.read});

  final String name;
  final Future<Uint8List> Function() read;

  @override
  String toString() => 'SymbolLibrarySource($name)';
}

/// The planner's own furniture library, read through [rootBundle].
const SymbolLibrarySource furnitureSymbolSource =
    SymbolLibrarySource(name: 'furniture', read: readBundledLibrary);

/// Loads the symbol libraries once and holds their [SymbolLibraryState].
///
/// [sources] are read and decoded in order and merged into one library
/// ([SymbolLibrary.merge]); the default is [furnitureSymbolSource] alone,
/// so a host that adds nothing sees the furniture palette. [read] is the
/// older single-source test seam, a source named `library`; give one or the
/// other. [load] reads every source; **any** throw -- a missing asset,
/// bytes the codec cannot read, a [SymbolLibraryError], a key and version
/// in two sources -- ends in [SymbolLibraryFailed]. [retry] reads every
/// source again, from a failure only. Listeners are notified on every
/// change of [state].
class SymbolLibraryLoader extends ChangeNotifier {
  /// Throws [ArgumentError] when both [read] and [sources] are given, or
  /// [sources] is empty.
  SymbolLibraryLoader(
      {Future<Uint8List> Function()? read, List<SymbolLibrarySource>? sources})
      : sources = List.unmodifiable(_sourcesOf(read, sources));

  static List<SymbolLibrarySource> _sourcesOf(
      Future<Uint8List> Function()? read, List<SymbolLibrarySource>? sources) {
    if (read != null && sources != null) {
      throw ArgumentError('give read or sources, not both');
    }
    if (sources != null) {
      if (sources.isEmpty) {
        throw ArgumentError.value(sources, 'sources', 'must not be empty');
      }
      return sources;
    }
    return [
      if (read == null)
        furnitureSymbolSource
      else
        SymbolLibrarySource(name: 'library', read: read),
    ];
  }

  /// The libraries this loader reads, in palette order.
  final List<SymbolLibrarySource> sources;

  SymbolLibraryState _state = const SymbolLibraryLoading();
  bool _started = false;
  bool _disposed = false;

  SymbolLibraryState get state => _state;

  /// Starts the first load. A second call, or a call after [dispose], does
  /// nothing; the future completes when this call's load has ended.
  Future<void> load() async {
    if (_disposed || _started) return;
    _started = true;
    await _run();
  }

  /// Loads again after a failure; does nothing in any other state or after
  /// [dispose].
  Future<void> retry() async {
    if (_disposed || _state is! SymbolLibraryFailed) return;
    _set(const SymbolLibraryLoading());
    await _run();
  }

  Future<void> _run() async {
    SymbolLibraryState next;
    try {
      final parts = <(String, SymbolLibrary)>[];
      for (final source in sources) {
        parts.add((source.name, SymbolLibrary.decode(await source.read())));
      }
      next = SymbolLibraryReady(SymbolLibrary.merge(parts));
    } catch (e) {
      next = SymbolLibraryFailed(e);
    }
    // A load still running when the app went away ends silently.
    if (_disposed) return;
    _set(next);
  }

  void _set(SymbolLibraryState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
