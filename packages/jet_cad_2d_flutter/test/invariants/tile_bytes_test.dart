import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/tile_fixture.dart';
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

  testWidgets('the ceiling binds inside the rest frame, and eviction holds it',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    const tileBytes = 64 * 64 * 4;
    // A band is the visible key range's full width, one tile tall: 13 columns
    // at this 800 x 600 device-pixel viewport.
    const bandBytes = 13 * tileBytes;
    expect(h.cache.liveTileCount, 130,
        reason: 'what this viewport is, asserted rather than assumed: '
            '13 x 10 tiles');

    // **The pan is the setup, and what it leaves behind is the point.** Keys
    // that left the viewport stay in the map until something reclaims them,
    // so the cache below holds the visible set *and* a tail of stale tiles --
    // which is the only state in which the rest frame's ceiling has anything
    // to do. Without it the frame's own pricing guarantees room and no
    // eviction ever runs inside a rest bake.
    h.camera.panBy(const Offset(-96, -96));
    await settle(t, h);
    // **Two repaints at the same camera, because the pan settled without
    // arming the gate.** Most of the visible set survives a three-tile pan,
    // so the budgeted loop covers the viewport on the pan frame itself and
    // the canvas stops asking for frames with the rest gate still at zero.
    // `repaintOnce` notifies with a numerically identical camera, which is
    // what the gate counts.
    await repaintOnce(t, h);
    await repaintOnce(t, h);
    expect(h.cache.debugRestGateSteps, greaterThanOrEqualTo(kRestGateFrames),
        reason: 'setup: the frame after the edit has to be a rest frame, or '
            'the budgeted per-tile loop refills the condemned band and the '
            'band path is never reached');

    final held = h.cache.liveTileCount;
    expect(held, greaterThan(130),
        reason: 'setup: the pan must have left stale keys behind, or the '
            'cap below is not one the frame has to work against');

    // **This is what the old arm could not do.** It asserted `liveBytes <=
    // kTileCacheBytes` on a fixture whose entire peak was 2,342,912 bytes
    // against 100,663,296 -- 43x of headroom, where no mutation to the rest
    // bake could move the number far enough to fail. Criterion 7 says the
    // ceiling holds "at every point inside the rest frame"; a ceiling nothing
    // can reach is not a measurement of that.

    final evictedBefore = h.cache.evictionCount;
    h.moveOneEntityWithinOneBand();
    // **One pump for the edit to arrive, then the cap, then the rest frame.**
    // `DraftDocument`'s change stream reaches `TileCache.applyChange` through
    // the widget rather than from `execute`, so the condemned tiles are still
    // in the map on the line after the edit and the frame that drops them is
    // this pump. Pricing before it would leave the cap a condemned band's
    // worth too generous and nothing would ever have to be reclaimed.
    await t.pump();
    final afterEdit = h.cache.liveTileCount;
    expect(afterEdit, lessThan(held),
        reason: 'setup: the edit must have condemned tiles by now, or the '
            'cap below is priced against a generation that never lost any');

    // **A cap the frame reaches on every slice, derived rather than picked.**
    // One band plus everything the cache is holding: large enough that
    // `_restBake`'s up-front pricing (one band plus the *visible* set, which
    // is smaller than what the pan left held) proceeds, and tight enough that
    // the first `_makeRoomForBytes` must reclaim before the band image can
    // exist, and every slice after it must reclaim again before its tile can.
    // The frame runs at its ceiling from the first slice to the last.
    final cap = bandBytes + afterEdit * tileBytes;
    h.cache.cacheBytes = cap;

    var peak = 0;
    var slices = 0;
    h.cache.debugOnSliceForTest = () {
      slices++;
      final bytes = h.cache.liveBytes;
      if (bytes > peak) peak = bytes;
      expect(bytes, lessThanOrEqualTo(cap),
          reason: 'criterion 7, at a cap that can be reached: the band image '
              'is resident here and the meter counts it');
    };
    addTearDown(() => h.cache.debugOnSliceForTest = null);

    await settle(t, h);
    h.cache.debugOnSliceForTest = null;

    expect(slices, greaterThan(0),
        reason: 'non-vacuity: the rest bake must have run and cut tiles, or '
            'the ceiling was observed nowhere');
    expect(h.cache.evictionCount, greaterThan(evictedBefore),
        reason: 'and it ran with the ceiling binding: this cap cannot hold '
            'what the pan left plus a band, so the frame had to reclaim '
            'inside itself rather than at its edges. Measured: 12 slices, '
            '12 evictions, and a peak of exactly cap');
    expect(peak, greaterThan(cap - 2 * tileBytes),
        reason: 'and the frame ran within one tile of the cap the whole way, '
            'which is what makes the clause above a measurement: at 43x of '
            'headroom no mutation to the rest bake can move liveBytes far '
            'enough to fail it');
    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
        reason: 'no band image outlives its band here either');
    expect(h.cache.viewportCovered, isTrue,
        reason: 'and the frame still filled the viewport under the cap');
  });
}
