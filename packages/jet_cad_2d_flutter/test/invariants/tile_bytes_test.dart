import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/tile_harness.dart';

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

  testWidgets('the ceiling holds at every point inside the rest frame',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    // One tile of `pumpTiled`'s canvas: 64 device pixels square, RGBA.
    const tileBytes = 64 * 64 * 4;
    h.cache.debugOnSliceForTest = () {
      expect(h.cache.liveBytes, lessThanOrEqualTo(kTileCacheBytes),
          reason: 'the band image is resident here and the meter counts it');
      // **The lower bound, and it is the half that has a witness.** The
      // ceiling above is one-sided: a `paintFrame` that never assigned
      // `_band` would leave `liveBytes` reading tiles alone, which is
      // smaller still and satisfies it. Task 4's seam could only prove
      // `liveBytes` counts a band handed to `debugSetBand`; this is what
      // proves the production path puts one there. Fired as M6b.
      expect(h.cache.liveBytes, greaterThan(h.cache.liveTileCount * tileBytes),
          reason: 'the band image is in the total, not merely permitted by '
              'it: a rest frame that never assigned _band would read exactly '
              'the tile sum here');
    };
    addTearDown(() => h.cache.debugOnSliceForTest = null);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();
    await t.pump();
    await t.pump();

    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
        reason: 'no band image outlives its band, and the composite was '
            'dropped before the bake');
  });
}
