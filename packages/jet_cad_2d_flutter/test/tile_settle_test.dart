// The settle has to drive itself.
//
// `paintFrame` bakes at most `budgetedTilesPerFrame` tiles -- one tile at the
// default budget and a 512-pixel tile -- so a viewport of many tiles needs many
// frames to fill. Flutter produces a frame only when something asks for one,
// and the camera asks only while it is moving. A gesture that ends therefore
// ends the settle with it: whatever the cache had not baked stays unbaked, and
// the stale magnified composite a zoom leaves behind stays on screen until an
// unrelated edit or another gesture happens to produce a frame.
//
// This is the same class of defect `_TableListenableAdapter` was written for
// ("without it a layer edit causes no frame at all"), reached from the other
// side: there the cache was never told, here it is told and cannot act.
//
// Both directions are asserted. A canvas that asks for a frame unconditionally
// passes the first test and spins the device's GPU forever, so the second test
// is what makes the first one worth landing.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';
import 'support/tile_harness.dart';

void main() {
  /// Pumps a canvas whose viewport needs more tiles than one frame may bake.
  ///
  /// 400x300 logical at dpr 2 is 800x600 device pixels; at a 64-pixel tile
  /// that is 13 x 10 = 130 tiles against a budget of 262144 / 4096 = 64 per
  /// frame. Two frames minimum, and the fixture inks all of them.
  ///
  /// **The `Center` is load-bearing, the same finding `pumpTiled` in
  /// `support/tile_harness.dart` documents.** `pumpWidget` hands its child the
  /// surface's *tight* constraints, and a `SizedBox` under tight constraints
  /// is inert -- so without `Center` this canvas ran at 800x600 logical
  /// (1600x1200 device pixels, 475 tiles), not the 400x300 the comment above
  /// describes, and the "ten is slack" bound below was really spent on eight
  /// of its ten iterations.
  Future<TileCache> pumpFilling(WidgetTester tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = fillingGrid(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(tileCamera());
    addTearDown(camera.dispose);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: kTileDpr),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: kTileViewport.width,
            height: kTileViewport.height,
            child: DraftCanvas(
              document: doc,
              index: index,
              camera: camera,
              tiles: true,
              tileDevicePixels: 64,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.state<DraftCanvasState>(find.byType(DraftCanvas)).tileCache!;
  }

  testWidgets('a frame that left tiles unbaked asks for another', (t) async {
    final cache = await pumpFilling(t);

    // Not vacuous: if one frame had covered the viewport there would be
    // nothing left to schedule for, and the assertion below would be true of
    // a canvas that never schedules anything.
    expect(cache.liveTileCount, greaterThan(0));
    expect(t.binding.hasScheduledFrame, isTrue,
        reason: 'tiles are still missing, so the canvas owes another frame -- '
            'nothing else will produce one once the camera stops');
  });

  testWidgets('the settle finishes, and then stops asking', (t) async {
    final cache = await pumpFilling(t);
    final afterFirst = cache.liveTileCount;

    // Bounded: a settle that needs more frames than the viewport has tiles is
    // not a settle. 130 tiles at 64 per frame is three frames; ten is slack.
    for (var i = 0; i < 10 && t.binding.hasScheduledFrame; i++) {
      await t.pump();
    }

    expect(cache.liveTileCount, greaterThan(afterFirst),
        reason: 'the extra frames must have baked something');
    expect(t.binding.hasScheduledFrame, isFalse,
        reason: 'a covered viewport owes nothing, and a canvas that keeps '
            'asking burns the GPU on a still screen');
  });

  testWidgets('the settle completes in one frame', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump(); // moving
    await t.pump(); // in between
    final tilesBefore = h.cache.liveTileCount;
    await t.pump(); // the rest frame
    expect(h.cache.viewportCovered, isTrue,
        reason: 'one rest frame covers the viewport; the tiled fill it '
            'replaces took one frame per tile');
    expect(h.cache.liveTileCount, greaterThan(tilesBefore));

    // **The rest frame covers the viewport and still owes one frame, and that
    // is the zoom-blur fix rather than a regression against the claim above.**
    // It blitted the outgoing composite first and underneath everything, then
    // banded the incoming generation over it; it cannot un-draw the blit, so
    // the pixels it leaves are the new tiles over the old generation magnified
    // and filtered. Exactly one more frame is owed and not two, and the
    // difference is `_restBake`: it releases the composite itself, having
    // priced the whole viewport against the byte ceiling first, so the next
    // frame has nothing to blit and nothing uncovered and stops. A pan tail
    // owes two for want of that release -- see `tile_regime_test`'s D8 arm.
    // The bound is slack so a third would be reported as a count rather than
    // as a hang. See `TileCache.settlePending`.
    var extra = 0;
    while (t.binding.hasScheduledFrame && extra < 10) {
      await t.pump();
      extra++;
    }
    expect(extra, 1,
        reason: 'the canvas has to ask for the frame that replaces the '
            'composite it drew, and then stop');
    expect(h.cache.hasCarryOver, isFalse);
    expect(t.binding.hasScheduledFrame, isFalse,
        reason: 'and nothing is owed afterwards: a canvas that keeps asking '
            'burns the GPU on a still screen');
  });

  // **The frame a zoom actually leaves on the user's screen, and nothing
  // pumped it.**
  //
  // Every other settle assertion in this repository produces its own frames --
  // `runTileZoomPhase` pumps thirty regardless of whether the app asked, and a
  // widget test calling `t.pump()` a fixed number of times does the same -- so
  // none of them can see a frame the canvas never *requested*. This one pumps
  // only while `hasScheduledFrame`, through [settle], which is why it is the
  // one that can.
  //
  // The rest frame blits the outgoing composite first and underneath
  // everything, *then* bands the incoming generation over it and drops the
  // composite. It cannot un-draw the blit it already made, so the frame it
  // leaves on screen is the new tiles over the old generation magnified --
  // stale, filtered ink through every transparent pixel, which is the blur the
  // report describes. `repaintOnce` and `tile_cache_test`'s criterion 1 both
  // buy the frame after it by hand; the application has no hand to buy it
  // with, and until this test the canvas never asked for it.
  testWidgets('a zoom settles to a clean generation on its own', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    // Anti-vacuity, twice over: an uncovered generation mints no composite at
    // all (`_retireGeneration`'s third guard), so there would be nothing stale
    // to leave behind and the comparison below would pass over an empty claim.
    expect(h.cache.viewportCovered, isTrue);

    // Two notches, the way a trackpad delivers a zoom, and the gesture ends
    // with the camera changed -- so the last frame the gesture itself produces
    // is a moving one and every frame after it has to be asked for.
    h.camera.zoomAt(const Offset(120, 90), 1.12);
    await t.pump();
    h.camera.zoomAt(const Offset(120, 90), 1.09);
    await t.pump();

    // **Not a fixed count.** This is the whole instrument.
    await settle(t, h);

    expect(h.cache.viewportCovered, isTrue,
        reason: 'the settle has to have run at all');
    expect(h.cache.hasCarryOver, isFalse,
        reason: 'a composite still standing is a composite the next frame '
            'blits again');
    expect(
        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'the frame a zoom leaves on screen must be the incoming '
            'generation alone -- a composite blitted underneath it shows the '
            'outgoing generation, magnified and filtered, through every '
            'transparent pixel of the new tiles');
  });
}
