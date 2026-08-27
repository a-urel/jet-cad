// Whether one arm of the zoom measurement leaves the next arm's settle
// trivially covered.
//
// **The concern.** `apps/dev_harness_2d/lib/measurement_rig.dart`'s
// `runTileZoomPhase` ends every arm with a settle, and `main.dart` runs
// `kZoomArms` of them back to back against **one** `TileCache`, resetting
// `camera.value = fittedCamera` before each. The gesture is symmetric --
// `kZoomSteps` steps at `kZoomFactor` and then the same number at
// `1 / kZoomFactor` -- so it ends, arithmetically, where it began. If the warm
// generation an arm's settle leaves behind were still live when the next arm's
// settle is measured, "frames to a covered viewport" would read 1 in both arms
// of criterion 4 whatever the flag under test did, and the ratio would be
// measuring cache warmth rather than the rest bake. That is the degenerate
// fixture `CLAUDE.md` names as this codebase's dominant failure mode, and it
// would be invisible in the published number.
//
// **The answer this file records is that it does not happen, for two
// independent reasons, and it pins both.**
//
// 1. A zoom frame changes the scale, `TileCache._gridFor` finds
//    `TileGrid.matchesScale` false and retires the generation, and
//    `_retireGeneration` ends in `_disposeTiles()`. So the warm generation is
//    gone after the **first** frame of the excursion -- not at its end -- and
//    no frame in between can refill it: every gesture frame is a moving frame
//    and takes `paintFrame`'s early return, which bakes nothing. Measured
//    below: `liveTileCount` 130 -> 0 on frame one, and 0 for all 80 frames.
// 2. The round trip does not land back on the starting camera anyway.
//    `zoomAt` multiplies the scale term one step at a time, so 40 multiplies
//    by 1.03 followed by 40 by `1 / 1.03` take 1.4 to 1.4000000000000017 --
//    and `matchesScale`, like every stored-value comparison in this file, is
//    exact `==`. The second test pins that number.
//
// The two arms below therefore settle identically -- same frame count, same
// band-bake count, same tile count -- and neither settle is trivial. That is
// the property criterion 4's ratio needs, and this file is the regression that
// keeps it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';
import 'support/tile_harness.dart';

/// Steps in each direction, mirroring `measurement_rig.dart`'s `kZoomSteps`.
///
/// The rig's constant is pinned by the design spec and lives in an app package
/// this one cannot import, so it is restated rather than shared. What matters
/// here is the *shape* -- an excursion that returns to its starting scale --
/// but the count is matched anyway so that the float residue the second test
/// pins is the residue the rig's own script actually accumulates.
const int kArmZoomSteps = 40;

/// Per-step factor, mirroring `measurement_rig.dart`'s `kZoomFactor`.
const double kArmZoomFactor = 1.03;

/// What one arm of the two-arm sequence measured.
class _ArmResult {
  _ArmResult({
    required this.settleFrames,
    required this.settleBakes,
    required this.tilesAfterSettle,
  });

  /// Idle frames pumped before [TileCache.viewportCovered] first read true, or
  /// **0** when it was already true before a single idle frame was pumped --
  /// which is precisely the trivial coverage this file exists to rule out.
  final int settleFrames;

  /// [TileCache.bakeCount] over the settle. Band-counted, not tile-counted:
  /// the settle's bakes come from `_restBake`, which counts once per band.
  final int settleBakes;

  final int tilesAfterSettle;
}

void main() {
  // Off-centre, the same 30%/70% of the viewport `zoomFocusFor` uses: a focal
  // point at the viewport's centre coincides with `rebaseOriginFor`'s own
  // centre and half the residual arithmetic never runs.
  final focus = Offset(kTileViewport.width * 0.30, kTileViewport.height * 0.70);

  /// One arm: reset the camera the way `main.dart` does, run the round trip,
  /// then measure the settle.
  Future<_ArmResult> runArm(
    WidgetTester t,
    TiledHarness h,
    ViewportTransform fitted,
  ) async {
    h.camera.value = fitted;
    // The two throwaway frames `runTileZoomPhase` takes before it resets its
    // counters.
    for (var i = 0; i < 2; i++) {
      h.camera.panBy(Offset.zero);
      await t.pump();
    }

    final generationBefore = h.cache.generation;
    for (var i = 0; i < kArmZoomSteps; i++) {
      h.camera.zoomAt(focus, kArmZoomFactor);
      await t.pump();
      if (i == 0) {
        // **Reason 1, at the only frame where it is visible.** By the end of
        // the excursion "no tiles" is over-determined -- 80 scale changes have
        // happened -- so an implementation that retired the generation only
        // on, say, a large enough scale ratio would still arrive at zero. The
        // first frame is where a single 3% step has to have been enough.
        expect(h.cache.generation, generationBefore + 1,
            reason: 'the first zoom frame changes the scale, so the grid must '
                'have been retired and a new generation anchored');
        expect(h.cache.liveTileCount, 0,
            reason: 'retiring the generation disposes its tiles -- the warm '
                'set the previous settle left behind cannot survive into '
                'this arm');
        expect(h.cache.viewportCovered, isFalse,
            reason: 'and coverage is a statement about tiles that exist, so '
                'it goes with them');
      }
    }
    for (var i = 0; i < kArmZoomSteps; i++) {
      h.camera.zoomAt(focus, 1 / kArmZoomFactor);
      await t.pump();
    }

    // No gesture frame refilled anything: `paintFrame` returns early on every
    // moving frame that has a composite to blit, which all 80 of these do
    // after the first.
    expect(h.cache.liveTileCount, 0,
        reason: 'no frame of the excursion may bake -- a moving frame blits '
            'the composite and returns');
    expect(h.cache.viewportCovered, isFalse,
        reason: 'the gesture ends with an empty generation, so the settle '
            'that follows has real work to do');

    h.cache.resetCounters();
    var settleFrames = 0;
    // Zero means the settle was over before it started. The loop is skipped
    // rather than entered so that the trivial case is reported as 0 and never
    // as 1 -- 1 is what a genuine one-frame settle would read, and the whole
    // question here is telling those two apart.
    if (!h.cache.viewportCovered) {
      for (var i = 1; i <= 30; i++) {
        await t.pump();
        settleFrames = i;
        if (h.cache.viewportCovered) break;
      }
    }
    return _ArmResult(
      settleFrames: settleFrames,
      settleBakes: h.cache.bakeCount,
      tilesAfterSettle: h.cache.liveTileCount,
    );
  }

  testWidgets('a zoom round trip leaves the next arm nothing warm to settle on',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    // Not vacuous: the arms below are only interesting because there *was* a
    // warm generation for the first one to inherit.
    expect(h.cache.viewportCovered, isTrue);
    expect(h.cache.liveTileCount, 130,
        reason: 'setup: the whole viewport is warm before arm A starts');
    final fitted = h.camera.value;

    final armA = await runArm(t, h, fitted);
    final armB = await runArm(t, h, fitted);

    // **The finding.** Both arms pay a real settle, and they pay the same one.
    expect(armA.settleFrames, greaterThan(0),
        reason: 'arm A must not find the viewport already covered');
    expect(armB.settleFrames, greaterThan(0),
        reason: 'arm B must not inherit arm A settle -- a settle reported as '
            'covered before its first idle frame is measuring cache warmth, '
            'not the rest bake');
    expect(armB.settleFrames, armA.settleFrames,
        reason: 'the two arms of criterion 4 must cost the same number of '
            'frames when nothing differs between them but the arm ordinal');
    expect(armB.settleBakes, armA.settleBakes,
        reason: 'and the same number of band bakes');
    expect(armB.tilesAfterSettle, armA.tilesAfterSettle,
        reason: 'and must arrive at the same generation');

    // The absolute figures, pinned so a change of regime is visible rather
    // than merely equal to itself: two idle frames (the rest gate needs two
    // consecutive unchanged cameras -- `kRestGateFrames`), ten bands, 130
    // tiles.
    expect(armA.settleFrames, 2);
    expect(armA.settleBakes, 10);
    expect(armA.tilesAfterSettle, 130);
  });

  // Reason 2, on its own, without a canvas: even if the excursion had left
  // tiles behind, the scale it returns to is not the scale it started from.
  //
  // A unit test rather than a second widget test because nothing here needs a
  // frame -- this is `zoomAt`'s arithmetic and `matchesScale`'s exactness,
  // and the widget test above already covers the cache's behaviour.
  test('the zoom round trip does not return to the starting scale', () {
    final camera = CameraController(tileCamera());
    addTearDown(camera.dispose);
    final start = quantiseCamera(camera.value, kTileDpr);
    final focus =
        Offset(kTileViewport.width * 0.30, kTileViewport.height * 0.70);

    for (var i = 0; i < kArmZoomSteps; i++) {
      camera.zoomAt(focus, kArmZoomFactor);
    }
    for (var i = 0; i < kArmZoomSteps; i++) {
      camera.zoomAt(focus, 1 / kArmZoomFactor);
    }
    final end = quantiseCamera(camera.value, kTileDpr);

    // The residue, spelled out. `zoomAt` composes `about * m`, and for a
    // camera with no skew that is a plain scalar multiply of the scale term
    // once per step, so 80 roundings accumulate here and nowhere else.
    expect(start.worldToScreenMatrix.a, 1.4);
    expect(end.worldToScreenMatrix.a, 1.4000000000000017);
    expect(end.worldToScreenMatrix.a, closeTo(1.4, 1e-14),
        reason: 'the trip does return to the starting scale within float '
            'error -- which is exactly why an implementation comparing with '
            'a Tolerance would treat the generation as reusable');
    expect(sameQuantisedCamera(start, end), isFalse,
        reason: 'but the comparison is a stored-value comparison and is '
            'exact `==`, so the grid that ends the excursion is not the grid '
            'that began it');
    // The translation, by contrast, does come back -- quantisation snaps it
    // onto the same device pixel. Asserted so that the difference above is
    // known to be the scale term and not a translation the reader might
    // assume away.
    expect(end.worldToScreenMatrix.e, start.worldToScreenMatrix.e);
    expect(end.worldToScreenMatrix.f, start.worldToScreenMatrix.f);
  });
}
