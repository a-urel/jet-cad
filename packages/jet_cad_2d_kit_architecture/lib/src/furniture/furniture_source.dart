// The furniture library as the kit's symbol source (spec 3a C4, contract
// K5): the package's asset, read under its `packages/` key so a host app
// finds it (today's kFurnitureLibraryAsset and readBundledLibrary,
// jet_cad_floor_plan/lib/src/symbols/symbol_library_loader.dart:17-26).
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolLibrarySource, bundledLibrary;

/// The library's asset key: the package's, never an app's.
const String kFurnitureAsset =
    'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';

/// The reader of [kFurnitureAsset] in [bundle] (`rootBundle` when null),
/// resolved each time it runs.
Future<Uint8List> Function() furnitureReader({AssetBundle? bundle}) =>
    bundledLibrary(kFurnitureAsset, bundle: bundle);

/// The kit's one symbol source: [furnitureReader] over `rootBundle`.
final SymbolLibrarySource furnitureSource =
    SymbolLibrarySource(label: 'furniture', read: furnitureReader());
