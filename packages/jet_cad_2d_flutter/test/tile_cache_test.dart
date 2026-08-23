// What the cache does, counted. Criteria 1-4 arrive in Tasks 5 and 6 and
// compare pixels; these three ask whether the machine ran at all, which is
// what makes a later zero-difference result mean something rather than
// meaning nothing was drawn -- the trap the 3g spike walked into with Probe C.

import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';
import 'support/spy_canvas.dart';
import 'support/tile_comparison.dart';
import 'support/tile_fixture.dart';

/// Records the largest absolute coordinate `_emitScreenSpace` ever hands
/// [polyline], then forwards to the real implementation so the bake still
/// produces a real image.
///
/// **Why this exists.** `expectTiledEqualsLive`'s pixel comparison cannot see
/// mutant M17 (`_bake` dropping the injected rebase origin): for a line
/// entity under an identity placement, `_emitScreenSpace` computes
/// `toScreen.a*x + toScreen.c*y + toScreen.e - _screenOrigin.x`, and whatever
/// `_screenOrigin` is, `VerticesDrawSink.polyline` immediately adds it back
/// (`a*points[0] + ... + e`) before the buffer ever reaches a Float32 slot.
/// That round trip is an exact algebraic identity in Float64 regardless of
/// `_screenOrigin`'s value, and `flutter_test`'s software Skia never touches
/// Float32 in between the way a GPU backend would -- so the final pixel is
/// identical whether or not the origin was dropped. What *does* differ
/// numerically is the residual coordinate itself, mid-flight: small when the
/// origin matches the geometry, and world-magnitude when it does not. That is
/// exactly the property `large_coordinate_test.dart` and
/// `draft_painter_rebase_test.dart` check for `DraftPainter`'s own rebase;
/// this checks the same property survives `TileCache._bake`'s wiring of it.
class _MaxMagnitudeVertices extends VerticesDrawSink {
  _MaxMagnitudeVertices(
      {required super.pixelsPerPaperMm,
      required super.devicePixelRatio,
      required super.fallback});

  double maxAbsCoordinate = 0;

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    for (var i = 0; i < count * 2; i++) {
      final v = points[i].abs();
      if (v > maxAbsCoordinate) maxAbsCoordinate = v;
    }
    super.polyline(points, count, style, closed: closed);
  }
}

void main() {
  test('a first frame bakes up to its budget and draws the rest live',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 3);
    addTearDown(rig.dispose);

    rig.paintOnce();

    expect(rig.cache.bakeCount, 3, reason: 'the budget, not the visible set');
    expect(rig.cache.blitCount, 3, reason: 'what was baked is what blitted');
    expect(rig.cache.liveDrawCount, 1,
        reason: 'one walk for the union of the uncovered rects, not one per '
            'tile: 154 painter invocations in a frame would be slower than '
            'the live path this cache replaces');
  });

  test('a warm frame bakes nothing and blits the whole visible set', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);

    rig.paintOnce();
    final visible = rig.cache.blitCount;
    expect(visible, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'every grid and seam claim vacuous');

    rig.cache.resetCounters();
    rig.paintOnce();

    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.blitCount, visible);
    expect(rig.cache.liveDrawCount, 0, reason: 'nothing left uncovered');
  });

  test('the blit Paint is one instance for the life of the cache', () {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final first = rig.cache.debugBlitPaint;
    rig.paintOnce();
    expect(identical(rig.cache.debugBlitPaint, first), isTrue,
        reason: 'criterion 13, and the shape VerticesDrawSink.debugPaint '
            'already uses: debugCapacityVertices cannot see a Paint');
  });

  test(
      'the blit hands drawImageRect the same Paint object every time, not a '
      'call-site-local one', () {
    // The test above pins that the `_blitPaint` *field* is not reassigned,
    // which a mutation that builds a fresh, call-site-local `Paint` and
    // passes it straight to `drawImageRect` -- never touching the field --
    // survives: `debugBlitPaint` still reads the untouched field, so
    // `identical` still reports true. Confirmed empirically against this
    // exact mutation (see task-4-report.md). `SpyCanvas` reads what
    // `dart:ui` actually received, which is the only way to see the
    // difference: identity of the object handed to the call, not of the
    // field. The same gap and the same fix are recorded in
    // `paint_allocation_test.dart` for `VerticesDrawSink.debugPaint`.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    final spy = SpyCanvas();

    rig.cache.paintFrame(
      canvas: spy,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
    );

    final calls = spy.named('drawImageRect').toList();
    expect(calls.length, greaterThan(30),
        reason: 'anti-degenerate clause 3: a single-tile viewport would make '
            'the identity comparison below vacuous over one call');
    final paints = calls.map((c) => c.args.whereType<Paint>().single).toList();
    final first = paints.first;
    for (final paint in paints) {
      expect(identical(paint, first), isTrue,
          reason: 'paintFrame must hand drawImageRect the one Paint built '
              "for the cache's life, not a fresh one per blit");
    }
  });

  test('criterion 1: a warm tiled frame equals the live frame exactly',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    // Warm first: criterion 1 is about a settled frame, and the uncovered path
    // is criterion 2's and Task 10's business.
    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });

  test('criterion 1: and it still holds after twenty-three awkward pans',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    for (var i = 0; i < 23; i++) {
      // Not whole pixels, and not a whole tile: the claim is that quantisation
      // makes an arbitrary pan exact, so an arbitrary pan is what tests it.
      rig.panBy(-7.37, -3.19);
      rig.paintOnce();
      await expectTiledEqualsLive(rig);
    }
  });

  test('criterion 2: a fixture crossing tile boundaries still matches',
      () async {
    // `crossingGrid`'s lines are 190 world units, which at this camera's 1.4
    // scale is 266 logical pixels against a 32-logical-pixel tile: every line
    // spans about eight tiles. The seam is exercised by geometry, not by
    // intent -- anti-degenerate clause 1.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final report = await expectTiledEqualsLive(rig);
    expect(report.liveInk, greaterThan(5000),
        reason: 'a fixture this small would make the seam claim thin: $report');
  });

  test(
      'M17 regression: a bake hands the sink a residual, not a raw '
      'site-plan-magnitude coordinate', () {
    // `expectTiledEqualsLive` cannot gate this mutation -- see
    // `_MaxMagnitudeVertices`'s header for why -- so this reads the actual
    // coordinate `_bake` hands the sink instead of the pixels it produces.
    // 4.5e6 is the site-plan magnitude `viewport_transform.dart`'s header
    // names, and the same value `draft_painter_rebase_test.dart` and
    // `large_coordinate_test.dart` use for the identical reason: near the
    // world origin an unrebased and a rebased coordinate are both small, and
    // the mutant would be invisible to this check too.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    const o = 4.5e6;
    final doc = DraftDocument.empty(measurer: measurer);
    // Mapped by the camera below to exactly fill `kTileViewport`, the same
    // convention `draft_painter_rebase_test.dart` uses.
    addLine(doc, doc.rootHandle, const Handle(1001), o, o, o + 400, o + 300);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final fallback = CanvasDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
    final vertices = _MaxMagnitudeVertices(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: kTileDpr,
        fallback: fallback);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final cache = TileCache(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(cache.dispose);
    final camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(1, 0, 0, -1, -o, o + kTileViewport.height));

    final recorder = PictureRecorder();
    cache.paintFrame(
      canvas: Canvas(recorder),
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: camera,
      painter: painter,
      sink: fallback,
      vertices: vertices,
    );
    recorder.endRecording().dispose();

    expect(vertices.maxAbsCoordinate, lessThan(1e5),
        reason: 'a residual, not a world coordinate -- if `_bake` drops the '
            'injected origin, `_emitScreenSpace` hands the sink the raw '
            '${o.toStringAsFixed(0)}-magnitude world value instead, which '
            'this bound catches even though it renders to the same pixel');
  });
}
