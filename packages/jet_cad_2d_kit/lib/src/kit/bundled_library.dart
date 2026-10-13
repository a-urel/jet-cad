// A reader of a library bundled as a Flutter asset (spec K5). A kit's
// source is one line:
//   SymbolLibrarySource(label: 'restaurant', read: bundledLibrary(
//       'packages/jet_cad_2d_kit_restaurant/assets/restaurant.jetlib'))
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// A reader of [assetKey] in [bundle] ([rootBundle] when null), resolved
/// each time the reader runs.
Future<Uint8List> Function() bundledLibrary(String assetKey,
        {AssetBundle? bundle}) =>
    () async {
      final data = await (bundle ?? rootBundle).load(assetKey);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    };
