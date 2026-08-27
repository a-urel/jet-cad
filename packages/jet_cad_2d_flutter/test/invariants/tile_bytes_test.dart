import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('a live band image is counted in liveBytes', () {
    final cache = TileCache(tileDevicePixels: 64);
    addTearDown(cache.dispose);
    final before = cache.liveBytes;

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
        Paint()..color = const Color(0xFF00FF00));
    final picture = recorder.endRecording();
    final band = picture.toImageSync(256, 64);
    picture.dispose();

    cache.debugSetBand(band);
    expect(cache.liveBytes, before + 256 * 64 * 4,
        reason: 'a resident band image is 4 bytes a pixel like every other '
            'image this cache holds, and the ceiling has to see it');

    cache.debugSetBand(null);
    expect(cache.liveBytes, before);
    band.dispose();
  });
}
