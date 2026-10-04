// Where the planner reads the restaurant library from (spec 14 V-2, V-4):
// the package's own asset, under its `packages/` key.
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:jet_cad_floor_plan/symbol_sources.dart';

/// The committed library's asset key.
const String kRestaurantLibraryAsset =
    'packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib';

/// Reads the restaurant library's bytes from [bundle] ([rootBundle] when
/// null).
Future<Uint8List> readRestaurantLibrary([AssetBundle? bundle]) async {
  final data = await (bundle ?? rootBundle).load(kRestaurantLibraryAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// The restaurant library, for the planner's symbol sources:
/// `SymbolLibraryLoader(sources: [furnitureSymbolSource,
/// restaurantSymbolSource])`.
const SymbolLibrarySource restaurantSymbolSource =
    SymbolLibrarySource(name: 'restaurant', read: readRestaurantLibrary);
