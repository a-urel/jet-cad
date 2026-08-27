import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';
import 'support/tile_harness.dart';

void main() {
  ViewportTransform at(double scale, double e, double f) => ViewportTransform(
      worldToScreenMatrix: Transform2(scale, 0, 0, -scale, e, f));

  test('the same camera compares same', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 20)), isTrue);
  });

  test('a scale change compares different', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.5, 10, 20)), isFalse);
  });

  // Translation is in the comparison and not only scale. Immediately after a
  // zoom the generation is empty, so a pan that follows keeps the scale and
  // does not cover the viewport: under a scale-only rule two same-scale pan
  // frames would satisfy every rest condition and spend a full bake while the
  // camera is still moving.
  test('a translation change compares different', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 11, 20)), isFalse);
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 21)), isFalse);
  });

  // **`a` and `d` are separate fields and every other fixture here ties them
  // together.** The `at()` helper builds `Transform2(scale, 0, 0, -scale, ...)`
  // and 'a scale change compares different' moves both at once, so deleting
  // either `x.a == y.a &&` or `x.d == y.d &&` left the other one firing and
  // the whole suite green -- M12's defect one field over, recorded as a
  // deferred minor at Task 1 and closed here. An anisotropic camera is what
  // separates them: `d != -a`, and each arm moves one term only.
  test('the two scale terms are compared independently', () {
    ViewportTransform anisotropic(double a, double d) =>
        ViewportTransform(worldToScreenMatrix: Transform2(a, 0, 0, d, 10, 20));

    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.4, -2.1)),
        isTrue,
        reason: 'non-vacuity: two equal anisotropic cameras must still '
            'compare same, or the two arms below pass for want of any '
            'agreement at all');
    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.5, -2.1)),
        isFalse,
        reason: 'x scale alone, with y held: a generation anchored at one x '
            'scale cannot blit at another');
    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.4, -2.2)),
        isFalse,
        reason: 'y scale alone, with x held');
  });

  test('the skew terms are compared too', () {
    final a = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.1, 0, -1.4, 10, 20));
    final b = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.2, 0, -1.4, 10, 20));
    expect(sameQuantisedCamera(a, b), isFalse);

    // The other skew term. Every other fixture in this file, including `a`
    // and `b` above, leaves `c` at 0 -- so without a case that varies it,
    // deleting `x.c == y.c` from the comparison kills no test here.
    final c1 = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0, 0.1, -1.4, 10, 20));
    final c2 = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0, 0.2, -1.4, 10, 20));
    expect(sameQuantisedCamera(c1, c2), isFalse);
  });

  testWidgets('a moving frame bakes nothing and walks nothing', (t) async {
    final h = await pumpTiled(t);
    // Settle first, so the failure below cannot be "there was nothing to do".
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue);

    h.cache.resetCounters();
    for (var i = 0; i < 8; i++) {
      h.camera.zoomAt(const Offset(120, 90), 1.05);
      await t.pump();
    }

    expect(h.cache.bakeCount, 0, reason: 'a moving frame must bake nothing');
    // `liveDrawCount` and not the painter's leaf counter: `DraftPainter.paint`
    // zeroes its own counters on entry, so a frame that never calls it leaves
    // the previous frame's number standing and the assertion would pass for
    // the wrong reason. The cache's counter increments where the live walk
    // actually happens.
    expect(h.cache.liveDrawCount, 0,
        reason: 'a moving frame must draw no live geometry either -- the '
            'uncovered region bounds to the whole viewport, so a live walk '
            'there is a full-viewport walk, 31.5-41.6 ms at 500,000 entities');
    expect(h.cache.carryOverBlitCount, greaterThan(0),
        reason: 'and it must still show something');
  });

  testWidgets(
      'a moving frame with no composite falls through and draws something',
      (t) async {
    final h = await pumpTiled(t);
    // A one-tile budget: the first generation this cache ever bakes cannot
    // cover `fillingGrid`'s ~130 tiles at this viewport within a handful of
    // frames, so no generation is ever retired into a composite before the
    // zooms below -- the review's state (2), reached without ever settling
    // once. `settle` is not called here on purpose: settling would either
    // finish covering (defeating the setup) or, if it never can, hang the
    // suite -- neither is wanted.
    h.cache.bakeBudgetDevicePixels = 64 * 64;
    // **And a ceiling below one band, which is what actually holds the
    // generation short now.** Plan 3i Task 8's rest bake is not rationed by
    // `bakeBudgetDevicePixels` -- it fills the viewport a tile row at a time
    // -- so the budget alone no longer keeps a generation from covering. It
    // declines to run at all when the ceiling cannot hold a band plus the
    // visible set, and eight tiles cannot hold a thirteen-tile row, so this
    // is the knob that produces the never-covering generation the setup
    // needs. Both are kept: the budget is what bounds the frames the rest
    // bake declines.
    h.cache.cacheBytes = 8 * 64 * 64 * 4;
    await t.pump();
    // Non-vacuous setup, asserted rather than assumed: if this generation
    // somehow did cover, the zoom below would mint a composite the normal
    // way and the frames after it would pass for a reason that has nothing
    // to do with the guard this test exists to catch.
    expect(h.cache.hasCarryOver, isFalse,
        reason: 'setup: nothing has ever been retired into a composite yet');
    expect(h.cache.viewportCovered, isFalse,
        reason: 'setup: the one-tile budget cannot have covered the '
            'viewport already, or the composite above would be real for '
            'the wrong reason');

    h.cache.resetCounters();
    // Two zooms, with no settling frame in between: the generation the first
    // zoom leaves behind never gets a chance to cover either, so the second
    // zoom's own retire attempt also has nothing to mint from.
    h.camera.zoomAt(const Offset(120, 90), 1.05);
    await t.pump();
    h.camera.zoomAt(const Offset(120, 90), 1.05);
    await t.pump();

    expect(h.cache.hasCarryOver, isFalse,
        reason: 'the outgoing generation for both zooms never covered, so '
            '`_retireGeneration` minted nothing to fall back on -- this is '
            'the state the guard has to survive without painting nothing');
    // `liveDrawCount` alone, not the three-way sum: a single blitted tile
    // satisfies "not gated" without proving the frame drew any geometry, and
    // the live walk is what the ordinary bake-and-live-walk path this guard
    // falls through to actually promises. Confirmed to still die to the
    // guard's own mutation (deleting `_carryOver == null ||`): with no
    // composite and the clause gone, `resting` reads false, the early return
    // fires, and `liveDrawCount` stays 0.
    expect(h.cache.liveDrawCount, greaterThan(0),
        reason: 'a moving frame with no composite to show must still draw '
            'something -- the ordinary bake-and-live-walk path -- rather '
            'than leave the viewport blank for the length of the gesture');
  });

  // A wheel spun steadily: one scale change per frame, with a single
  // unchanged frame between notches. Under a one-frame gate this bakes on
  // every second frame.
  testWidgets('a steadily spun wheel never arms the rest gate', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    h.cache.resetCounters();

    for (var notch = 0; notch < 6; notch++) {
      h.camera.zoomAt(const Offset(120, 90), 1.1); // the moving frame
      await t.pump();

      // After the first notch, a composite is minted by the settled generation.
      // Asserting it exists proves the gate's threshold term is under test: if
      // the composite were null, the guard's middle disjunct would decide every
      // frame and the threshold value would be unreachable.
      if (notch == 0) {
        expect(h.cache.hasCarryOver, isTrue,
            reason: 'the first zoom retires the settled generation into a '
                'composite; without it this test is vacuous');
      }

      await t.pump(); // one unchanged frame before the next notch
    }

    expect(h.cache.bakeCount, 0,
        reason: 'a wheel that keeps turning must never reach two consecutive '
            'unchanged frames, so it must never bake');
  });

  // **Spec D8: the pan path is untouched.** A pan straight after a zoom is the
  // frame this whole test exists for, and it was drawing only the stale
  // composite for the length of the gesture: `CameraController.panBy` copies
  // `a, b, c, d` bit-identically, so `TileGrid.matchesScale` holds, `_gridFor`
  // returns the standing grid without retiring, and the composite the zoom
  // minted survives every pan frame. With the camera changing every frame the
  // rest gate never armed, so `_tiles` stayed empty and the region the
  // composite slid off stayed background until the user stopped moving.
  //
  // A macOS trackpad reaches this directly: any stretch of a gesture where the
  // pan continues after the scale stops changing.
  testWidgets('a pan after a zoom fills the region the composite slides off',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue,
        reason: 'setup: a generation that covers is what a zoom can retire '
            'into a composite');

    // One zoom step, and one only: the settled generation is flattened into
    // the composite and every tile disposed, which is the state the pan below
    // starts from.
    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();
    expect(h.cache.hasCarryOver, isTrue,
        reason: 'setup: the zoom minted the composite the pan then carries');
    expect(h.cache.liveTileCount, 0,
        reason: 'setup: and retired every tile, so anything the pan frames '
            'put on screen below is theirs');

    h.cache.resetCounters();
    // Four pan frames at exactly the scale the zoom left. Enough that the
    // composite -- magnified 1.3x about (120, 90), so it reaches x = 484 in a
    // 400-wide viewport -- slides its right edge inside the viewport and
    // stops covering.
    for (var i = 0; i < 4; i++) {
      h.camera.panBy(const Offset(-40, 0));
      await t.pump();
    }

    expect(h.cache.bakeCount, greaterThan(0),
        reason: 'a pan is not a moving frame (spec D1 defines moving by the '
            'scale) and D8 leaves the pan path baking at its edge');
    expect(h.cache.liveTileCount, greaterThan(0),
        reason: 'and the tiles it bakes are what fill the revealed region '
            'once the composite no longer covers it');

    // **The pixels, not only the counters.** The strip below is the part of
    // the viewport the composite has slid off: its right edge sits at
    // 120 + 1.3 * 280 - 160 = 324 logical after the four pans, so
    // [324, 400) x [0, 300) is served by the incoming generation alone. A
    // frame that returned early leaves it transparent.
    const revealed = Rect.fromLTRB(324, 0, 400, 300);
    final tiled = await captureTiled(t, h);
    final ink = inkInsideCapture(tiled, revealed);
    // `captureLive` replaces the widget tree and disposes the cache behind
    // `h`, so it comes last and nothing is read from the cache after it.
    final live = await captureLive(t, h);
    expect(inkInsideCapture(live, revealed), greaterThan(200),
        reason: 'non-vacuity: the fixture must actually draw in the strip, '
            'or "the tiled frame drew nothing there" is not a defect');
    expect(ink, greaterThan(200),
        reason: 'the region the composite slid off must carry the drawing, '
            'not background: this is spec D3 accepting a ring on a zoom '
            '*out* and nothing else');
  });

  // **Spec D6 and the rest bake's own doc comment, at the granularity the
  // walk happens at.** One missing key anywhere in the viewport used to
  // commit every band to a full painter walk, an owner climb, a
  // `toImageSync` and a `_bakes++` -- and then to throw the image away,
  // because the per-key skip inside the band loop skips only the slice.
  //
  // This is the ordinary edit path: after an `applyChange` the camera has not
  // moved, so the gate is still armed and the next frame rest-bakes, while
  // invalidation has typically condemned one band.
  testWidgets('an edit inside one band rebakes that band alone', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);

    // **The control, measured rather than assumed.** A whole-generation drop
    // at the same camera is the same rest frame with every band missing, and
    // the number it bakes is what "all of them" means on this viewport. The
    // assertion below is only worth making because this one is larger.
    h.cache.resetCounters();
    h.document.tables.layers.add(const LayerRecord(
      handle: Handle(901),
      name: 'ALL-BANDS',
      color: IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 0,
    ));
    await t.pump();
    await settle(t, h);
    final allBands = h.cache.bakeCount;
    expect(allBands, greaterThan(5),
        reason: 'non-vacuity: the viewport must span several bands, or "one '
            'band, not all of them" is a distinction without a difference');
    expect(h.cache.viewportCovered, isTrue,
        reason: 'setup: the control frame refilled what it dropped');

    // The measurement: one edit, inside one band.
    h.cache.resetCounters();
    final invalidatedBefore = h.cache.invalidationCount;
    h.moveOneEntityWithinOneBand();
    await t.pump();
    await settle(t, h);

    expect(h.cache.invalidationCount, greaterThan(invalidatedBefore),
        reason: 'setup: the edit must have condemned tiles, or the rest bake '
            'below had nothing to do for a reason that is not the probe');
    // **Three of ten, and the three are derivable rather than observed.**
    // Direction one of invalidation condemns every tile whose `_baked` record
    // names the handle, and a sliced tile's record is its whole band's (spec
    // D6). A band's walk is *queried* padded by [kTileSlack] and clipped hard
    // (spec D4/D7), and `kTileSlack` is 32 logical pixels -- exactly one tile
    // row at this harness's 64 device pixels and `kTileDpr` of 2 -- so a leaf
    // resting in row 4 is visited by the walks for rows 3, 4 and 5 and named
    // in all three records. Measured: 39 tiles condemned, 3 x 13. The number
    // to compare it against is `allBands`, not one: the defect this pins is a
    // rest bake that walked all ten and threw seven images away.
    expect(h.cache.bakeCount, 3,
        reason: 'only the bands the edit condemned owe a walk; the other '
            '${allBands - 3} hold every key they need, and rebaking them '
            'replaces good images with identical ones -- a whole-viewport '
            'walk for three rows, on every frame of a drag');
    expect(h.cache.bakeCount, lessThan(allBands),
        reason: 'stated twice on purpose: the exact 3 pins the pad is reach, '
            'and this clause is the one that fails if the frame-global probe '
            'comes back and every band bakes again');
    expect(h.cache.viewportCovered, isTrue,
        reason: 'and skipping them must not leave a hole: a skipped band '
            'keeps its tiles, and they are still blitted');
  });

  testWidgets('a skipped band keeps its tiles out of the ceiling\'s reach',
      (t) async {
    // The other half of the skip, and the half that is easy to get wrong.
    // `_makeRoomForBytes` may evict any tile whose recency is older than this
    // frame's, so a band skipped *without* touching its keys' recency would
    // leave them evictable by a later band's own room-making -- and the frame
    // would blit a hole in a row it had already decided it owned. The rest
    // bake's up-front pricing rests on exactly that: at band `i` the
    // un-evictable set is the keys of bands `0..i-1`.
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settleFromBands(t, h);
    final tiles = h.cache.liveTileCount;

    h.cache.resetCounters();
    final evictedBefore = h.cache.evictionCount;
    h.moveOneEntityWithinOneBand();
    await t.pump();
    await settle(t, h);

    expect(h.cache.evictionCount, evictedBefore,
        reason: 'nothing may be evicted here: every visible key carries this '
            'frame is serial, skipped bands included');
    expect(h.cache.liveTileCount, tiles,
        reason: 'the generation is whole again and exactly as large as it '
            'was: one band rebaked, nine left standing');
  });

  test('the gate is two unchanged frames, and the constant says so', () {
    // A restatement of the constant and named as one. The *behaviour* it
    // gates is 'a steadily spun wheel never arms the rest gate' above, which
    // is what reddens under M4b; this line exists so a reader who changes the
    // constant sees the threshold the wheel test was written against.
    expect(kRestGateFrames, 2);
  });
}
