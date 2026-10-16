// Sub-project 4a Task 1, patterned on the architecture kit's
// test/furniture/package_assets_test.dart: the kit's library is read under
// its package key, so a host app finds it; an app key fails.
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolLibrary;
import 'package:jet_cad_2d_kit_restaurant/src/restaurant_source.dart';

/// A bundle that serves fixed bytes under the keys it holds, and nothing
/// else.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

Uint8List _file(String path) => File(path).readAsBytesSync();

void main() {
  // Written out, not read from the constant: a key that drifted to an app's
  // `assets/...` must turn these red.
  const libraryKey =
      'packages/jet_cad_2d_kit_restaurant/assets/library/restaurant.jetlib';

  test('RS-asset-key the constant names the package key', () {
    expect(kRestaurantAsset, libraryKey);
  });

  test('RS-read the library loads from a bundle holding only the package key',
      () async {
    final bytes = _file('assets/library/restaurant.jetlib');
    final read =
        await restaurantReader(bundle: _MapBundle({libraryKey: bytes}))();
    expect(read, orderedEquals(bytes));
    expect(SymbolLibrary.decode(read).entries.length, 69);
  });

  test('RS-app-key a bundle holding only an app\'s key fails the read',
      () async {
    final bytes = _file('assets/library/restaurant.jetlib');
    await expectLater(
        restaurantReader(
            bundle: _MapBundle({'assets/library/restaurant.jetlib': bytes}))(),
        throwsA(isA<FlutterError>()));
  });
}
