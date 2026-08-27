import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

/// Everything a tiled-frame test needs to drive and read one canvas.
class TiledHarness {
  TiledHarness(this.cache, this.camera, this.document);
  final TileCache cache;
  final CameraController camera;
  final DraftDocument document;
}

/// Pumps a tiled canvas over `fillingGrid`, which inks every tile of
/// [kTileViewport] at [tileCamera] -- so "nothing was drawn" can never be
/// mistaken for "there was nothing to draw".
Future<TiledHarness> pumpTiled(
  WidgetTester t, {
  DraftDocument Function(FlutterTextMeasurer)? document,
  ViewportTransform? camera,
}) async {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = (document ?? fillingGrid)(measurer);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final controller = CameraController(camera ?? tileCamera());
  addTearDown(controller.dispose);

  await t.pumpWidget(MediaQuery(
    data: const MediaQueryData(devicePixelRatio: kTileDpr),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: kTileViewport.width,
        height: kTileViewport.height,
        child: DraftCanvas(
          document: doc,
          index: index,
          camera: controller,
          tiles: true,
          tileDevicePixels: 64,
        ),
      ),
    ),
  ));
  await t.pump();
  final state = t.state<DraftCanvasState>(find.byType(DraftCanvas));
  return TiledHarness(state.tileCache!, controller, doc);
}

/// Pumps until the canvas stops asking for frames, bounded.
///
/// The bound is not decoration: an implementation that asks forever would
/// otherwise hang the suite instead of failing it.
Future<void> settle(WidgetTester t, TiledHarness h) async {
  for (var i = 0; i < 40 && t.binding.hasScheduledFrame; i++) {
    await t.pump();
  }
  expect(t.binding.hasScheduledFrame, isFalse,
      reason: 'the settle must terminate');
}

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

  test('the skew terms are compared too', () {
    final a = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.1, 0, -1.4, 10, 20));
    final b = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.2, 0, -1.4, 10, 20));
    expect(sameQuantisedCamera(a, b), isFalse);
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
    expect(
        h.cache.blitCount + h.cache.liveDrawCount + h.cache.carryOverBlitCount,
        greaterThan(0),
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

  test('the gate needs two unchanged frames, not one', () {
    // The threshold itself, stated where a reader can see it: one unchanged
    // frame is the in-between frame and draws like a moving one.
    expect(kRestGateFrames, 2);
  });
}
