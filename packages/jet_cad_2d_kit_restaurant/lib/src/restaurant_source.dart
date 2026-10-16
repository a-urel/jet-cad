// The restaurant library as the kit's symbol source: the package's asset,
// read under its `packages/` key so a host app finds it.
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolLibrarySource, bundledLibrary;

/// The library's asset key: the package's, never an app's.
const String kRestaurantAsset =
    'packages/jet_cad_2d_kit_restaurant/assets/library/restaurant.jetlib';

/// The reader of [kRestaurantAsset] in [bundle] (`rootBundle` when null),
/// resolved each time it runs.
Future<Uint8List> Function() restaurantReader({AssetBundle? bundle}) =>
    bundledLibrary(kRestaurantAsset, bundle: bundle);

/// The kit's one symbol source: [restaurantReader] over `rootBundle`.
final SymbolLibrarySource restaurantSymbolSource =
    SymbolLibrarySource(label: 'restaurant', read: restaurantReader());
