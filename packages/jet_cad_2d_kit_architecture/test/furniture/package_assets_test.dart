// 3a Task 23 (spec C4; D-15), ported from jet_cad_floor_plan/test/
// package_assets_test.dart PA2, PA3 (spec 14 V-10): the kit's library is read
// under its package key, so a host app finds it; an app key fails. PA1's
// counterpart for the kit's key is FU-asset-key. PA4 (the export font) is
// sub-project 4's.
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolLibrary;
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_source.dart';

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
  group('V-10 the asset key is the package\'s', () {
    // Written out, not read from the constant: a key that drifted to an
    // app's `assets/...` must turn these red.
    const libraryKey =
        'packages/jet_cad_2d_kit_architecture/assets/library/furniture.jetlib';

    test('FU-asset-key the constant names the package key', () {
      expect(kFurnitureAsset, libraryKey);
    });

    test(
        'PA2 the furniture library loads from a bundle holding only the '
        'package key', () async {
      final bytes = _file('assets/library/furniture.jetlib');
      final read =
          await furnitureReader(bundle: _MapBundle({libraryKey: bytes}))();
      expect(read, orderedEquals(bytes));
      expect(SymbolLibrary.decode(read).entries, isNotEmpty);
    });

    test('PA3 a bundle holding only the app\'s old key fails the read',
        () async {
      final bytes = _file('assets/library/furniture.jetlib');
      await expectLater(
          furnitureReader(
              bundle: _MapBundle({'assets/library/furniture.jetlib': bytes}))(),
          throwsA(isA<FlutterError>()));
    });
  });
}
