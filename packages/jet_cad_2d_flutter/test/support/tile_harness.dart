// One tiled `DraftCanvas`, pumped, plus the two things every tiled-frame test
// does with it: drive it to rest, and read the cache behind it.
//
// These lived in `tile_regime_test.dart` until Plan 3i Task 8, which needed
// them from two more files. Moving rather than copying is the point: a second
// copy of `settle` would be a second bound to keep in step with
// [kRestGateFrames].

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'tile_fixture.dart';

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
