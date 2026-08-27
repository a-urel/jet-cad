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

  /// Enough more frames at the camera [rig] just painted for the rest gate to
  /// arm and a resting frame to actually bake.
  ///
  /// `tile_budget_test.dart` carries the same three lines for the same reason
  /// and neither is imported by the other; both are written from
  /// [kRestGateFrames] rather than from a literal, so the gate's threshold
  /// stays the single bound. `tile_harness.dart`'s `settle` is the widget
  /// harness's and pumps a tree; this one paints a rig.
  void settleRig(TileRig rig) {
    for (var i = 0; i < kRestGateFrames; i++) {
      rig.paintOnce();
    }
  }

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

  // **The frame the pan stops on, which is a frame class of its own.** Every
  // pan frame above changes the camera, so `_restGateSteps` reads 0 and the
  // frame falls through to bake-and-live-walk. Then the user stops: the next
  // frame repeats the same quantised camera, the count reads 1 -- too late for
  // that disjunct, too early for the rest gate -- and with the composite still
  // standing the frame returned after the composite blit alone. The strip the
  // composite had slid off was background for exactly one frame and correct
  // again on the next: correct -> blank -> correct, on every pan tail. The
  // frame *before* it only became correct with the D8 fix above, which is what
  // makes the flash stand out rather than what introduced it.
  //
  // Nothing but the remembered bit separates this frame from a wheel's
  // in-between frame, which owes the opposite answer: the zoom-out test below
  // holds that end and the wheel test above holds D1's.
  //
  // **A rig and not the widget harness, because of what the frame is.** An
  // uncovered cache asks `DraftCanvas` for another frame from a post-frame
  // callback, so the repaint boundary is dirty the moment this frame ends and
  // `captureTiled`'s `toImage` asserts rather than capturing. The same fact is
  // what makes this frame reach the screen at all, so it cannot be arranged
  // away -- see [captureTiledFrame].
  test(
      'the frame the pan stops on still fills what the composite '
      'does not cover', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    // **Four tiles a frame, and it is load-bearing twice over.** The rest bake
    // ignores the budget, so the settle below still covers in one frame; the
    // *pan* frames are budgeted, and a generation that caught up during the
    // pan would both cover the viewport -- ending the settle, so the tail
    // frame never happens -- and drop the composite the tail frame blits.
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 4,
        document: fillingGrid(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    settleRig(rig);
    expect(rig.cache.viewportCovered, isTrue,
        reason: 'setup: a generation that covers is what a zoom can retire '
            'into a composite');

    // A zoom **out**, so the composite cannot cover: it shrinks about the
    // viewport centre to [50, 350] x [37.5, 262.5] logical, and D3 leaves the
    // ring outside it as background for the length of the gesture. The strip
    // this test reads is not that ring -- it is inside the composite's own
    // rows and to the right of where the *pan* carried it, which is D8's
    // business and not D3's.
    rig.zoomBy(0.75);
    rig.paintOnce();
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'setup: the zoom minted the composite the pan then carries');
    expect(rig.cache.liveTileCount, 0,
        reason: 'setup: and retired every tile, so anything on screen below '
            'is the pan frames own');

    for (var i = 0; i < 4; i++) {
      rig.panBy(-40, 0);
      rig.paintOnce();
    }
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'setup: the composite is still standing, which is what makes '
            'the frame below take the early return at all');
    expect(rig.cache.viewportCovered, isFalse,
        reason: 'setup: an uncovered cache is what asks `DraftCanvas` for the '
            'tail frame -- covered, the flash frame would never be painted');
    expect(rig.cache.debugRestGateSteps, 0,
        reason: 'setup: every pan frame changed the camera');

    // The tail frame: one more frame at exactly the camera the last pan left.
    final tiled = await captureTiledFrame(rig);
    expect(rig.cache.debugRestGateSteps, 1,
        reason: 'the frame under test is the one that has matched once and '
            'not yet twice -- neither a pan frame nor a rest frame');

    // The strip the composite has slid off, taken inside the composite's own
    // rows so that D3's accepted ring cannot account for it: the composite
    // reaches x = 190 after four pans of 40 logical pixels, and the fixture
    // inks out to x = 261 at this camera.
    const revealed = Rect.fromLTRB(194, 40, 258, 240);
    final live = await captureLiveFrame(rig);
    expect(inkInside(live, revealed), greaterThan(200),
        reason: 'non-vacuity: the fixture must actually draw in the strip, '
            'or "the tiled frame drew nothing there" is not a defect');
    expect(inkInside(tiled, revealed), greaterThan(200),
        reason: 'the one frame between the last pan and the rest bake must '
            'draw what the pan frames before it drew, or the strip flashes '
            'background for a frame and comes back');
  });

  // **Spec D3, at the frame the test above could have broken.** A zoom out
  // shrinks the composite and leaves a ring, and that ring stays background
  // until the gesture ends: the alternative is a full-viewport live walk on
  // every zoom-out frame -- 31.5-41.6 ms at 500,000 entities -- because the
  // uncovered region bounds to the whole viewport while the incoming
  // generation is empty.
  //
  // The frame after the last notch is the one at risk. It has matched once and
  // not yet twice, exactly like the pan tail above, and it must still draw
  // what a moving frame draws. **The pan before the gesture is not
  // decoration**: it leaves the remembered bit set, so a bit a scale change
  // fails to clear turns this frame into the full-viewport walk D3 refuses.
  test(
      'a zoom out leaves its ring as background, the frame after the '
      'last notch included', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: fillingGrid(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    settleRig(rig);
    rig.panBy(-24, 0);
    rig.paintOnce();
    settleRig(rig);
    expect(rig.cache.viewportCovered, isTrue,
        reason: 'setup: the pan settled, and left the last camera change a '
            'pan rather than a zoom');

    rig.cache.resetCounters();
    for (var notch = 0; notch < 3; notch++) {
      rig.zoomBy(0.9);
      rig.paintOnce();
      if (notch == 0) {
        expect(rig.cache.hasCarryOver, isTrue,
            reason: 'setup: the first notch retires the settled generation '
                'into the composite the rest of the gesture blits');
      }
    }
    expect(rig.cache.debugRestGateSteps, 0,
        reason: 'setup: every notch changed the camera');

    // The frame after the last notch.
    final tiled = await captureTiledFrame(rig);
    expect(rig.cache.debugRestGateSteps, 1,
        reason: 'the frame under test has matched once and not yet twice');
    expect(rig.cache.bakeCount, 0,
        reason: 'a zoom gesture and the frame after it bake nothing (D1)');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'and walk no live geometry: on a zoom-out frame the uncovered '
            'region bounds to the whole viewport, so a walk here is a '
            'full-viewport walk -- the frame D3 exists to prevent');
    expect(rig.cache.carryOverBlitCount, greaterThan(0),
        reason: 'non-vacuity: those frames did still show something');

    // And the ring itself, in pixels. Three notches of 0.9 put the
    // composite's right edge at 200 + 0.729 * 200 = 345.8 logical, while the
    // fixture inks past the viewport's own edge at this camera.
    const ring = Rect.fromLTRB(348, 30, 398, 270);
    final live = await captureLiveFrame(rig);
    expect(inkInside(live, ring), greaterThan(200),
        reason: 'non-vacuity: there is drawing out there to have left out');
    expect(inkInside(tiled, ring), 0,
        reason: 'the ring is background until the gesture ends, and the frame '
            'after the last notch is still inside the gesture');
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
    // The other half of the skip: a rest bake that skips a band must leave
    // that band's tiles standing and blittable, and this measures that they
    // are -- nothing evicted, and the generation exactly as large afterwards
    // as before.
    //
    // **What it does not gate, stated because it reads as though it does.**
    // The skip branch also stamps every key of a skipped band with the
    // frame's serial, and that stamp is what the ceiling proof cites -- at
    // band `i` the set `_makeRoomForBytes` may not evict is the keys of bands
    // `0..i-1`. Deleting the stamp changes nothing this test, or any other,
    // can see, and the reason is arithmetic rather than headroom:
    //
    // * the rest bake refuses to start unless `cacheBytes` funds one band plus
    //   **every** visible tile, so the ceiling for a room request inside it is
    //   at least `visibleTiles - 1` tiles;
    // * every room request inside it is made while a visible key is still
    //   missing, so at most `visibleTiles - 1` visible tiles are held;
    // * therefore the eviction demand never exceeds the number of *stale*
    //   off-viewport keys held, and every stale key's serial is strictly
    //   older than any visible key's -- a key is stamped only on a frame it is
    //   visible on -- so `_makeRoomForBytes` takes stale keys and stops.
    //
    // Measured at the tightest cap the rest bake will run under
    // (`13 + 130` tiles here), with 30 and 60 stale keys left by whole-tile
    // pans: identical eviction counts, tile counts, coverage and byte peaks
    // with the stamp and without it. See **M24** in
    // `docs/superpowers/notes/plan-3i-mutation-log.md`, recorded there as a
    // survivor with the derivation; the stamp stays in the production path as
    // the belt to the pricing's braces, and gating it would need an
    // instrument that can see intra-frame victim selection, which is a
    // production seam this plan will not add for it.
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
