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
  TiledHarness(this.cache, this.camera, this.document, this.index);
  final TileCache cache;
  final CameraController camera;
  final DraftDocument document;

  /// The index the tiled canvas was built over.
  ///
  /// Held so a second canvas can be pumped over the **same** document and the
  /// same index — which is what `captureLive` does. Rebuilding the index
  /// there would compare two frames drawn from two different trees, and a
  /// query-order difference between them would read as a tiling defect.
  final SpatialIndex index;

  /// Moves [kMovableHandle] onto tiles it did not occupy, for Task 10's
  /// edit-after-a-settle test.
  ///
  /// **Onto disjoint tiles, not merely somewhere else.** An edit that extends
  /// a line rather than moving it makes the new tile set a superset of the
  /// old one, and then "the old position was condemned" is true of an
  /// implementation that condemns nothing -- the trap
  /// `tile_invalidation_test.dart` documents at its own head.
  ///
  /// `TransformNodeCommand` **replaces** the node's transform rather than
  /// composing with it, so the destination below is an absolute world point,
  /// not an offset from wherever [kMovableHandle] happens to rest. Screen
  /// (300, 48), through [tileCamera]'s own inversion (`sx = 1.4 wx - 37`,
  /// `sy = -1.4 wy + 323`): tile column 9 spans device x [576, 640) -- logical
  /// [288, 320) -- and row 1 spans device y [64, 128) -- logical [32, 64).
  /// [bandCrossingGrid]'s doc comment places [kMovableHandle]'s resting
  /// position at tile column 2, row 4 -- seven columns and three rows clear
  /// of this destination, far outside [kTileSlack]'s one-tile ring, so the
  /// two tile sets are disjoint by construction and the test only has to
  /// confirm it.
  void moveOneEntityOntoDisjointTiles() {
    double worldX(double screenX) => (screenX + 37.0) / 1.4;
    double worldY(double screenY) => (323.0 - screenY) / 1.4;
    document.commands.execute(TransformNodeCommand(
        kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(48))));
  }

  /// Moves [kMovableHandle] **along its own tile row**, so exactly one band is
  /// condemned, for the per-band rest-bake probe.
  ///
  /// The same arithmetic as [moveOneEntityOntoDisjointTiles] and a different
  /// destination, chosen so that both directions of invalidation land in the
  /// same band. Direction one condemns every tile whose `_baked` record names
  /// the handle, and a sliced tile's record is its **whole band's** (spec D6),
  /// so the old position condemns row 4 entire. Direction two condemns the
  /// tiles the new geometry reaches: screen (300, 144) with the leaf's local
  /// (0, 0)-(6, 6) diagonal reaching screen (308.4, 135.6) -- both inside row
  /// 4, which spans device y [256, 320), logical [128, 160). So the band set
  /// this edit condemns is `{row 4}` and the other nine rows of the viewport
  /// are untouched, which is the whole point: a rest bake that walks them
  /// anyway is walking a whole viewport to replace one row.
  void moveOneEntityWithinOneBand() {
    double worldX(double screenX) => (screenX + 37.0) / 1.4;
    double worldY(double screenY) => (323.0 - screenY) / 1.4;
    document.commands.execute(TransformNodeCommand(
        kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(144))));
  }
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

  // **The `Center` is load-bearing and was missing.** `pumpWidget` hands its
  // child the surface's *tight* constraints (800x600 logical), and a
  // `SizedBox` under tight constraints is inert -- `additionalConstraints
  // .enforce(constraints)` gives the incoming tight box back unchanged. So
  // this canvas was 800x600 logical, not [kTileViewport]: 1600x1200 device
  // pixels, 25 x 19 = 475 tiles, and `fillingGrid` -- whose extent is derived
  // in its own doc comment against a 400x300 viewport, and which reaches only
  // screen x -109.8..495 at [tileCamera] -- left the right-hand 38% of every
  // frame blank. `Center` passes loose constraints, so the box takes the size
  // it asks for and the harness is the viewport it documents. Measured before
  // and after: 475 tiles and a 1600x1200 capture became 130 and 800x600.
  await t.pumpWidget(MediaQuery(
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
          camera: controller,
          tiles: true,
          tileDevicePixels: 64,
        ),
      )),
    ),
  ));
  await t.pump();
  final state = t.state<DraftCanvasState>(find.byType(DraftCanvas));
  return TiledHarness(state.tileCache!, controller, doc, index);
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

/// Drives [h] to a rest whose **every** visible tile was cut out of a band,
/// and returns how many were.
///
/// **[settle] alone does not reach that state, and every slice-path mutant
/// would be judged on two tiles if this did not exist.** `paintFrame` bakes up
/// to `budgetedTilesPerFrame` tiles a frame through the per-tile `_bake` path
/// — `262144 / (64 * 64) = 64` at this harness's tile size — and the rest gate
/// needs two consecutive unchanged cameras before `_restBake` runs at all. A
/// 400x300 logical viewport at [kTileDpr] is 800x600 device pixels, 13 x 10 =
/// **130 tiles**, so the first two frames bake 128 of them and the rest frame
/// finds two keys missing. `_restBake` skips every key `_tiles` already
/// serves, so the band path would own 2 tiles of 130 — in the bottom-right
/// corner, 24 device rows tall — and `sliceSourceRect`, the band pad and the
/// band origin would all be measured there or nowhere.
///
/// **A table edit is what puts the whole viewport back in the band's hands at
/// the same camera.** `paintFrame` reads `tables.mutationRevision` every frame
/// and calls `_dropGeneration` when it moves; that drops the tiles and the
/// composite and **keeps the lattice and the anchor** ("the tiles go and the
/// lattice stays"). The camera has not moved, so `_restGateSteps` keeps its
/// count and the very next frame is a rest frame over an empty generation:
/// one band per tile row, 130 slices, at exactly the camera the fixture was
/// laid out against. A zoom would reach the same state but would move the
/// camera, and [bandCrossingGrid]'s strokes are placed against [tileCamera]'s
/// band boundaries specifically.
///
/// The layer added is referenced by nothing, so not one pixel changes with it:
/// the drop is the whole point of the edit.
Future<int> settleFromBands(WidgetTester t, TiledHarness h) async {
  await settle(t, h);
  var slices = 0;
  h.cache.debugOnSliceForTest = () => slices++;
  addTearDown(() => h.cache.debugOnSliceForTest = null);
  h.document.tables.layers.add(const LayerRecord(
    handle: Handle(900),
    name: 'BAND-DROP',
    color: IndexedColor(3),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 50,
    transparency: 0,
  ));
  await t.pump();
  await settle(t, h);
  h.cache.debugOnSliceForTest = null;
  // Pinned to equality, not merely non-zero: this helper's own doc comment
  // promises **every** visible tile was cut out of a band, and a rest bake
  // that filled some tiles through the band path and backfilled the rest
  // through the ordinary per-tile `_bake` would satisfy `greaterThan(0)`
  // while breaking that promise. Measured on this harness: `slices ==
  // liveTileCount == 130`.
  expect(slices, equals(h.cache.liveTileCount),
      reason: 'every visible tile must have been cut from a band -- a '
          'partial band bake backfilled through the ordinary per-tile path '
          'must not pass as a band settle');
  expect(h.cache.viewportCovered, isTrue,
      reason: 'the rest bake must have refilled the generation it dropped');
  return slices;
}

/// One more painted frame at the camera [h] already has.
///
/// **The frame a rest bake after a *scale change* leaves on screen is not a
/// clean generation, and this is the same allowance `tile_cache_test`'s
/// `criterion 1: a settled frame equals the live frame after a zoom` makes by
/// painting a fifth frame.** `paintFrame` blits the outgoing composite first
/// and underneath everything, before it decides the frame is resting;
/// `_restBake` then calls `_dropCarryOver`, which frees the composite for
/// every *later* frame but cannot un-draw the blit this one already made. So
/// the settled frame carries stale, magnified ink wherever the incoming tiles
/// are transparent — 67,509 differing pixels of it on this task's arm 3 — and
/// the first frame that is a statement about the new generation alone is the
/// one after. Nothing schedules that frame: `viewportCovered` is true, so the
/// canvas stops asking.
///
/// A zero pan rather than a real one: [ViewportTransform] declares no `==`, so
/// a fresh instance always notifies, and the camera it notifies with is
/// numerically the one already on screen — no key moves, no tile is rebaked,
/// and `_restBake` returns at its "nothing missing" guard.
Future<void> repaintOnce(WidgetTester t, TiledHarness h) async {
  h.camera.panBy(Offset.zero);
  await t.pump();
  await settle(t, h);
}
