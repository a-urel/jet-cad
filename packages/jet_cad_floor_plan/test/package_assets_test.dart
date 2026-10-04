// Spec 14 V-10, V-11, plan 14b-1 Task 3: the planner's assets live in the
// package and are read under its `packages/` keys, and the package
// registers the family documents name (`Roboto`) from its own font bytes.
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/src/export/export_font.dart';
import 'package:jet_cad_floor_plan/src/fonts.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';

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
  group('V-10 the asset keys are the package\'s', () {
    // Written out, not read from the constants: a key that drifted back to
    // the app's `assets/...` must turn these red (M-14b1-1).
    const libraryKey =
        'packages/jet_cad_floor_plan/assets/library/furniture.jetlib';
    const fontKey = 'packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf';
    const licenceKey =
        'packages/jet_cad_floor_plan/assets/fonts/Roboto_LICENSE.txt';

    test('PA1 the constants name the package keys', () {
      expect(kFurnitureLibraryAsset, libraryKey);
      expect(kExportFontAsset, fontKey);
      expect(kExportFontLicenceAsset, licenceKey);
    });

    test(
        'PA2 the furniture library loads from a bundle holding only the '
        'package key', () async {
      final bytes = _file('assets/library/furniture.jetlib');
      final read = await readBundledLibrary(_MapBundle({libraryKey: bytes}));
      expect(read, orderedEquals(bytes));
      expect(SymbolLibrary.decode(read).entries, isNotEmpty);
    });

    test('PA3 a bundle holding only the app\'s old key fails the read',
        () async {
      final bytes = _file('assets/library/furniture.jetlib');
      await expectLater(
          readBundledLibrary(
              _MapBundle({'assets/library/furniture.jetlib': bytes})),
          throwsA(isA<FlutterError>()));
    });

    test('PA4 the export font loads from a bundle holding the package key',
        () async {
      final bytes = _file('lib/fonts/Roboto-Regular.ttf');
      expect(await loadExportFont(_MapBundle({fontKey: bytes})),
          orderedEquals(bytes));
    });

    test('PA5 the pubspec declares the three assets', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final asset in const [
        'assets/library/furniture.jetlib',
        'lib/fonts/Roboto-Regular.ttf',
        'assets/fonts/Roboto_LICENSE.txt',
      ]) {
        expect(
            RegExp('^\\s*-\\s+${RegExp.escape(asset)}\\s*\$', multiLine: true)
                .hasMatch(pubspec),
            isTrue,
            reason: asset);
      }
    });
  });

  group('V-11 ensureFloorPlanFonts', () {
    // The registration is process-wide: each test starts from none (review
    // F-3), and every call that reads a bundle runs in real async time.
    setUp(resetFloorPlanFontsForTest);
    tearDown(resetFloorPlanFontsForTest);

    const fontKey = 'packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf';

    testWidgets(
        'PA6 a bundle without the font fails the registration, and the next '
        'call tries again', (tester) async {
      await tester.runAsync(() async {
        await expectLater(
            ensureFloorPlanFonts(_MapBundle(const {})), throwsA(anything));
      });
      // Not held: this call registers from a bundle that has the bytes.
      final bytes = _file('lib/fonts/Roboto-Regular.ttf');
      await tester
          .runAsync(() => ensureFloorPlanFonts(_MapBundle({fontKey: bytes})));
    });

    testWidgets('PA8 a second call returns the first call\'s future',
        (tester) async {
      final bundle =
          _MapBundle({fontKey: _file('lib/fonts/Roboto-Regular.ttf')});
      await tester.runAsync(() async {
        final first = ensureFloorPlanFonts(bundle);
        expect(ensureFloorPlanFonts(bundle), same(first));
        expect(ensureFloorPlanFonts(), same(first),
            reason: 'a later call, whatever its bundle, gets the first');
        await first;
      });
    });
  });
}
