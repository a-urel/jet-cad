// Spec 14 V-11, review F-3: family `Roboto` measures in the test font until
// `ensureFloorPlanFonts` registers the bundled face, then measures as those
// bytes do. Alone in its file, so its process has registered nothing
// before it measures (a registered face cannot be taken back).
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/src/fonts.dart';

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

/// The laid-out width of [text] in [family] at 20 px.
double _width(String text, String family) {
  final painter = TextPainter(
    text: TextSpan(
        text: text, style: TextStyle(fontFamily: family, fontSize: 20)),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  testWidgets(
      'FR1 Roboto measures in the test font before the registration and in '
      'the bundled face after it (M-14b1-2)', (tester) async {
    const sample = 'Masa 12 · Teras İçi';
    expect(kFloorPlanFontFamily, 'Roboto');
    final before = _width(sample, kFloorPlanFontFamily);
    expect(before, _width(sample, 'NoSuchFamily'),
        reason: 'premise: nothing named Roboto is registered yet');

    final bytes = File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();
    await tester.runAsync(() async {
      // A probe family over the same bytes: what Roboto must measure as.
      final probe = FontLoader('JetCadRobotoProbe')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await probe.load();
      await ensureFloorPlanFonts(_MapBundle(
          {'packages/jet_cad_floor_plan/lib/fonts/Roboto-Regular.ttf': bytes}));
    });
    final after = _width(sample, kFloorPlanFontFamily);
    expect(after, isNot(before));
    expect(after, _width(sample, 'JetCadRobotoProbe'));
  });
}
