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
}
