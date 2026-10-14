// Spec P5 "Fonts": the font the PDF export embeds is read through the
// asset bundle, once per controller. Ported from
// apps/floor_planner/test/export/export_font_test.dart (EF4, EF5, EF7,
// EF8); EF1-EF3 and EF9-EF12 are the app's files, main() and pubspec, and
// EF6 (registerFontLicences) is Task 9's.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/export/export_font.dart';
import 'package:jet_cad_2d_plan/src/fonts/plan_fonts.dart' show kPlanFontAsset;

const String vendoredDir = '../jet_cad_2d_flutter/test/golden/fonts';

Uint8List vendoredFont() =>
    File('$vendoredDir/Roboto-Regular.ttf').readAsBytesSync();

/// A bundle that serves fixed bytes under one key and records every key
/// asked for.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;
  final List<String> asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  group('loadExportFont', () {
    testWidgets('EF4 reads the bundled font through rootBundle',
        (tester) async {
      final bytes = await loadExportFont();
      expect(bytes, orderedEquals(vendoredFont()));
    });

    testWidgets('EF5 reads from the bundle it is given', (tester) async {
      final fake = Uint8List.fromList(<int>[7, 1, 9, 3]);
      final bundle = _MapBundle(<String, Uint8List>{kPlanFontAsset: fake});
      expect(await loadExportFont(bundle), orderedEquals(fake));
      expect(bundle.asked, <String>[kPlanFontAsset]);
    });
  });

  group('ExportFontCache', () {
    test('EF7 reads once and returns the same future after', () async {
      var reads = 0;
      final bytes = Uint8List.fromList(<int>[4, 2]);
      final cache = ExportFontCache(load: () async {
        reads++;
        return bytes;
      });
      expect(reads, 0, reason: 'nothing is read until asked');
      final first = cache.bytes;
      expect(cache.bytes, same(first));
      expect(await first, same(bytes));
      expect(await cache.bytes, same(bytes));
      expect(reads, 1);
    });

    test('EF8 a failed read is not held: the next call reads again', () async {
      var reads = 0;
      final bytes = Uint8List.fromList(<int>[5]);
      final cache = ExportFontCache(load: () async {
        reads++;
        if (reads == 1) throw StateError('first read fails');
        return bytes;
      });
      await expectLater(cache.bytes, throwsStateError);
      expect(await cache.bytes, same(bytes));
      expect(reads, 2);
    });
  });
}
