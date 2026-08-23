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

  test('criterion 3: text survives the tile round trip', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: crossingLabels(measurer));
    addTearDown(rig.dispose);

    // `DraftPainter.paint` resets its text counters on every call, and a
    // tile bake calls it once per tile -- so reading `textOpCount` right
    // after `rig.paintOnce()` would read whichever tile happened to bake
    // *last* in `TileGrid.visibleKeys`' order, not the frame's total, and
    // that tile is overwhelmingly likely to be one of the many that carry no
    // text at all (confirmed empirically: it reads 0, not 6 -- see Task 6's
    // report). Proved directly instead, with one live, whole-viewport walk:
    // unlike `measureTiledAgreement`'s live arm, this applies no
    // `quantiseCamera` and sets no `debugRebaseOrigin` -- it exists only to
    // total the counters over the whole frame in one `paint` call, and that
    // total still runs before any pixel is compared.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    rig.sink.canvas = canvas;
    rig.vertices.canvas = canvas;
    rig.painter.paint(rig.vertices, rig.camera, kTileViewport);
    rig.vertices.flush();
    recorder.endRecording().dispose();
    // A level-of-detail cull would produce a smaller, self-consistent, wrong
    // picture that agreed with itself perfectly, so both counters are
    // checked before any pixel comparison runs.
    expect(rig.painter.textOpCount, 6);
    expect(rig.painter.culledTextCount, 0);

    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });

  test('criterion 4: overlapping translucent strokes composite identically',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: translucentOverlap(measurer));
    addTearDown(rig.dispose);

    // `InkReport` carries no colour information -- it counts ink, it does not
    // read alpha -- so if `style_resolver` dropped `transparency` entirely,
    // both arms would draw fully opaque and `expectTiledEqualsLive` would
    // still pass at zero, exactly the trap closed for text with
    // `textOpCount`/`culledTextCount` and left open here. Checked directly,
    // before any pixel is compared: `translucentOverlap`'s first line is
    // handle 1000, `ByLayerColor` on layer zero resolves to white, and
    // `transparency: 153` must resolve to alpha `255 - 153 = 102 = 0x66` --
    // not the opaque `0xFF` a dropped channel would give.
    final firstLineSlot = rig.doc.entities.slotOf(const Handle(1000))!;
    final resolvedStyle = DocumentStyleResolver(rig.doc)
        .styleFor(firstLineSlot, StyleContext.documentRoot);
    expect(resolvedStyle.argb, 0x66FFFFFF,
        reason: 'transparency: 153 must resolve to a translucent ARGB, not '
            'the opaque one a dropped transparency channel would give: '
            '0x${resolvedStyle.argb.toRadixString(16)}');

    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });

  test(
      'M11 regression: the blit composites with srcOver, so a tile leaves '
      'what is beneath it alone wherever it has no ink of its own', () async {
    // `expectTiledEqualsLive`'s pixel comparison cannot see mutant M11
    // (`_blitPaint`'s blend mode flipped to `BlendMode.src`): `_capture`
    // always starts from a blank, fully transparent canvas, and `src` and
    // `srcOver` compute the exact same result whenever the destination pixel
    // already sits at alpha 0 -- `result = src` either way, because `srcOver`
    // is `src + dst*(1-src.a)` and `dst` is zero. Every destination pixel in
    // this plan's tile grid is blitted by exactly one tile, so criteria 1
    // through 4 never touch a pixel twice and never give the two blend modes
    // a chance to disagree. Confirmed empirically: pre-filling the
    // destination with opaque red before calling `paintFrame` and reading
    // the result back found 460,140 of 480,000 pixels erased to alpha 0
    // under the mutation, and 0 erased on the restored, unmutated code (Task
    // 6's report has the transcript).
    //
    // Checked two ways: the property directly, which is what actually gates
    // the mutation, and the pixel-level damage it causes against a canvas
    // that is not blank -- the shape `expectTiledEqualsLive`'s harness
    // cannot produce -- so the property assertion above is not read on
    // faith.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    expect(rig.cache.debugBlitPaint.blendMode, BlendMode.srcOver);

    final width = (kTileViewport.width * kTileDpr).round();
    final height = (kTileViewport.height * kTileDpr).round();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(kTileDpr);
    canvas.drawRect(
        Offset.zero & kTileViewport, Paint()..color = const Color(0xFFFF0000));
    rig.cache.paintFrame(
      canvas: canvas,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: rig.camera,
      painter: rig.painter,
      sink: rig.sink,
      vertices: rig.vertices,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData();
    image.dispose();
    final bytes = data!.buffer.asUint8List();

    var erased = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] == 0) erased++;
    }
    expect(erased, 0,
        reason: 'srcOver must leave the red backdrop opaque everywhere a '
            'tile has no ink of its own; $erased of ${bytes.length ~/ 4} '
            'pixels went transparent');
  });

  // The accepted gap, measured on every run rather than rediscovered.
  //
  // **What this proves.** A near-axis stroke disagrees between the live and
  // tiled paths on a small, bounded number of pixels, every one of them a
  // pure displacement -- ink present on one side and absent on the other,
  // never a pixel that carries a different colour. The bound is the measured
  // worst case with headroom, not a tolerance chosen to make a test pass: a
  // real defect in the tile machinery is nowhere near it. A one-device-pixel
  // error in `TileGrid.destRectFor` moves the whole frame and reddens this at
  // 53x the bound -- 3192 differing against a bound of 60 (verified in Task
  // 6a).
  //
  // **What this does not prove.** It does not prove the tiled frame equals the
  // live frame; criteria 1 and 2 make that claim, and it holds for every
  // axis-aligned and general-slope fixture measured. It does not prove the
  // gap is harmless on a GPU backend, and it does not prove the bound holds
  // at every camera and every slope -- Task 6a swept 82 slopes at one camera
  // and one tile size. See `nearAxisDiagonals` for the mechanism.
  group('accepted gap: near-axis strokes displace a bounded number of pixels',
      () {
    Future<InkReport> measure(DraftDocument Function(FlutterTextMeasurer) of,
        {int minimumInk = 500}) async {
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);
      final rig = TileRig(
          tileDevicePixels: 64,
          tilesBakedPerFrame: 1000,
          document: of(measurer));
      addTearDown(rig.dispose);
      final report = await measureTiledAgreement(rig);
      // The floor first, for the reason `expectTiledEqualsLive` states: two
      // blank captures agree perfectly and prove nothing.
      expect(report.liveInk, greaterThan(minimumInk), reason: '$report');
      expect(report.tiledInk, greaterThan(minimumInk), reason: '$report');
      // Every disagreement is ink moved, never ink recoloured. A blend, alpha
      // or colour-resolution defect would break this before it broke a count.
      expect(
          report.differingPixels, report.strayPixels + report.uncoveredPixels,
          reason: 'a pixel differing without being stray or uncovered is a '
              'colour defect, which this gap is not: $report');
      return report;
    }

    test('the ten-line fan stays inside the bound', () async {
      final report = await measure(nearAxisDiagonals);
      // Measured 2026-08-24: differing 36 of 10342 ink, 0.348%.
      expect(report.differingPixels, lessThanOrEqualTo(60), reason: '$report');
      expect(report.differingPixels / report.liveInk, lessThan(0.01),
          reason: '$report');
    });

    test('the worst single slope measured stays inside the bound', () async {
      // The two worst of the 82 slopes Task 6a swept at this camera: a
      // near-horizontal line rising 20 world units over 200, and a
      // near-vertical one running 30 over 200. Each spans 8.75 tiles.
      // Measured 2026-08-24: 24 of 1030 ink (2.330%) and 26 of 1092 (2.381%).
      for (final (label, x0, y0, x1, y1)
          in <(String, double, double, double, double)>[
        ('near-horizontal', 20, 84, 220, 104),
        ('near-vertical', 84, 20, 114, 220),
      ]) {
        final report = await measure((measurer) {
          final doc = DraftDocument.empty(measurer: measurer);
          addLine(doc, doc.rootHandle, const Handle(1000), x0, y0, x1, y1);
          return doc;
        });
        expect(report.differingPixels, lessThanOrEqualTo(45),
            reason: '$label: $report');
        expect(report.differingPixels / report.liveInk, lessThan(0.04),
            reason: '$label: $report');
      }
    });

    test('the same camera and tile size agree exactly on axis-aligned ink',
        () async {
      // The control that makes the slope the variable rather than the tiling:
      // `crossingGrid` crosses just as many seams and disagrees on nothing.
      final report = await measure(crossingGrid, minimumInk: 5000);
      expect(report.differingPixels, 0, reason: '$report');
    });
  });
}
