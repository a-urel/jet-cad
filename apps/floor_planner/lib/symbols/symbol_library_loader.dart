// The symbol library's loader (spec 09b D2, R-4): one per app, owned by
// `FloorPlannerApp` above the document host, so a document swap -- which
// rebuilds the shell -- never reads the asset again.
//
// With `export/export_font.dart`, the only file of the app that touches
// `rootBundle`.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'symbol_library.dart';
import 'symbol_library_state.dart';

/// The bundled library's asset key (declared in `pubspec.yaml`, 09a).
const String kFurnitureLibraryAsset = 'assets/library/furniture.jetlib';

/// Reads the bundled library: [rootBundle] at [kFurnitureLibraryAsset].
Future<Uint8List> readBundledLibrary() async {
  final data = await rootBundle.load(kFurnitureLibraryAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Loads the symbol library once and holds its [SymbolLibraryState].
///
/// [read] is the test seam: it returns the library's bytes (or throws); the
/// default reads the bundled asset ([readBundledLibrary]). [load] runs
/// [read] then [SymbolLibrary.decode]; **any** throw -- a missing asset,
/// bytes the codec cannot read, a [SymbolLibraryError] -- ends in
/// [SymbolLibraryFailed]. [retry] runs it again, from a failure only.
/// Listeners are notified on every change of [state].
class SymbolLibraryLoader extends ChangeNotifier {
  SymbolLibraryLoader({Future<Uint8List> Function()? read})
      : _read = read ?? readBundledLibrary;

  final Future<Uint8List> Function() _read;

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
      next = SymbolLibraryReady(SymbolLibrary.decode(await _read()));
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
