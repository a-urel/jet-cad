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
    expect(rig.cache.hasCarryOver, isFalse,
        reason: 'and no composite stands -- a covering one suppresses the live '
            'walk outright, so without this the count below would read the '
            'same whether the tiles covered the viewport or something else '
            'did');
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
      tablesRevision: rig.doc.tables.mutationRevision,
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

    // **The second state, which the frame above cannot reach.** A cold frame
    // has no composite, so "every call gets the same object" is a true
    // statement about a frame that only ever blits tiles -- and it is *false*
    // once a composite stands, where a frame legitimately hands
    // `drawImageRect` two different objects. Asserted only over the first
    // phase, the criterion would have gone on reading as "one Paint, always",
    // and a mutation that built the composite's `Paint` at the call site would
    // have had nowhere to be caught. Found by asking the file which tests
    // exclude the state their comment is about; see the fix round in the
    // report.
    final zoomed = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(zoomed.dispose);
    zoomed.paintOnce();
    // Four, not zero: the frame under the spy must contain *both* kinds of
    // blit, or the two-object claim is made over one object again.
    zoomed.cache.tilesBakedPerFrame = 4;
    zoomed.zoomBy(1.19);
    zoomed.cache.resetCounters();
    final zoomedSpy = SpyCanvas();
    zoomed.cache.paintFrame(
      canvas: zoomedSpy,
      viewport: kTileViewport,
      devicePixelRatio: kTileDpr,
      camera: zoomed.camera,
      painter: zoomed.painter,
      sink: zoomed.sink,
      vertices: zoomed.vertices,
      tablesRevision: zoomed.doc.tables.mutationRevision,
    );

    expect(zoomed.cache.carryOverBlitCount, 1);
    expect(zoomed.cache.blitCount, 4);
    final zoomedCalls = zoomedSpy.named('drawImageRect').toList();
    expect(zoomedCalls.length, 5,
        reason: 'one composite and four tiles: the state is real, not a '
            'second cold frame under another name');
    final zoomedPaints =
        zoomedCalls.map((c) => c.args.whereType<Paint>().single).toList();
    expect(
        identical(zoomedPaints.first, zoomed.cache.debugCarryOverPaint), isTrue,
        reason: 'the composite goes first and with its own field, so an '
            'incoming tile and a live walk both composite on top of it');
    for (final paint in zoomedPaints.skip(1)) {
      expect(identical(paint, zoomed.cache.debugBlitPaint), isTrue,
          reason: 'and every tile blit still gets the one tile Paint');
    }

    // The two fields differ in the one way the ruling is about, and nothing
    // else in this plan pins it: the carry-over is the only blit that is not a
    // 1:1 texel-to-pixel copy, so it is the only one that wants a filter.
    expect(zoomed.cache.debugBlitPaint.filterQuality, FilterQuality.none);
    expect(zoomed.cache.debugCarryOverPaint.filterQuality, FilterQuality.low);
    // And it is drawn underneath everything, so `src` there would clobber the
    // backdrop to transparent wherever the composite has no ink -- M11's
    // hazard, on the one blit M11's test cannot see.
    expect(zoomed.cache.debugCarryOverPaint.blendMode, BlendMode.srcOver);
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
      tablesRevision: doc.tables.mutationRevision,
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
      tablesRevision: rig.doc.tables.mutationRevision,
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

  // ---------------------------------------------------------------------
  // Task 9: the generation, the carry-over composite, and the zoom path.
  // ---------------------------------------------------------------------

  test('criterion 8: a pan drops nothing and a scale change drops everything',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final generation = rig.cache.generation;
    final tiles = rig.cache.liveTileCount;

    // Twelve pans, none of them a whole tile.
    for (var i = 0; i < 12; i++) {
      rig.panBy(-5.5, -2.5);
      rig.paintOnce();
    }
    expect(rig.cache.generation, generation,
        reason: 'a pan is not a new generation');
    expect(rig.cache.liveTileCount, greaterThanOrEqualTo(tiles),
        reason: 'a pan adds tiles at the leading edge and drops none');

    rig.zoomBy(1.03);
    rig.paintOnce();
    expect(rig.cache.generation, generation + 1);
    expect(rig.cache.hasCarryOver, isTrue,
        reason: 'the retired generation lives on as one composite: two live '
            'generations do not fit under the cap, and independently snapped '
            'scaled tiles gap or overlap along every shared edge');
  });

  test('a zoom gesture blits the carry-over and bakes nothing', () async {
    // **The budget is taken away after the first frame, not at construction.**
    // A rig built with `tilesBakedPerFrame: 0` never bakes a first generation
    // at all, so there is nothing to retire, no composite is ever made, and
    // every assertion below reads zero against zero -- green for the one
    // reason that would make the test worthless. Deviation D1 in the report.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    rig.cache.tilesBakedPerFrame = 0;
    rig.cache.resetCounters();
    for (var i = 0; i < 8; i++) {
      rig.zoomBy(1.03);
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 0);
    expect(rig.cache.carryOverBlitCount, 8,
        reason: 'one composite blit per gesture frame');
    expect(rig.cache.blitCount, 0,
        reason: 'and not one tile blit: every gesture frame anchors a fresh '
            'generation whose tiles cannot be baked under a zero budget');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'the carry-over covers the viewport, so nothing is uncovered');
    expect(rig.cache.generation, greaterThanOrEqualTo(9),
        reason: 'anti-vacuity: eight scale changes really did retire eight '
            'generations, so the eight blits above are gesture frames and '
            'not eight repeats of one warm frame');
  });

  test('the gesture frame the carry-over serves is not blank', () async {
    // `carryOverBlitCount` counts calls, and a `drawImageRect` into a
    // degenerate destination rect counts exactly the same as one that puts the
    // outgoing generation on screen. This reads the pixels instead: under a
    // zero bake budget and a fresh generation holding no tiles at all, every
    // non-transparent pixel in the frame came from the composite or from
    // nowhere.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final warmInk = await frameInk(rig);
    expect(warmInk, greaterThan(5000),
        reason: 'the floor first: a blank warm frame would make the '
            'comparison below vacuous');

    rig.cache.tilesBakedPerFrame = 0;
    rig.zoomBy(1.19);
    final gestureInk = await frameInk(rig);
    expect(rig.cache.liveTileCount, 0,
        reason: 'the new generation holds nothing, so the ink below cannot '
            'have come from a tile');
    expect(rig.cache.liveDrawCount, 0,
        reason: 'and no live walk ran, so it cannot have come from the '
            'painter either');
    expect(gestureInk, greaterThan(5000),
        reason: 'the composite must actually reach the canvas: $gestureInk '
            'against a warm $warmInk');
  });

  test('the settle spreads its bakes across frames', () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 4);
    addTearDown(rig.dispose);
    rig.paintOnce();
    rig.zoomBy(1.03);
    rig.cache.resetCounters();
    // Settled: the scale stops moving, so the new generation fills in.
    for (var i = 0; i < 3; i++) {
      rig.paintOnce();
    }
    expect(rig.cache.bakeCount, 12, reason: 'four per frame, three frames');
    expect(rig.cache.liveTileCount, 12,
        reason: 'and every bake was kept, so 12 is a throttle rather than a '
            'recount of four tiles rebaked three times');
    expect(rig.cache.hasCarryOver, isFalse,
        reason: 'and no composite stands: generation one never covered the '
            'viewport at a budget of four, so nothing was minted -- which is '
            'what makes the live-draw count below a statement about coverage '
            'rather than about suppression');
    expect(rig.cache.liveDrawCount, 3,
        reason: 'anti-vacuity: all three frames still left ink uncovered, so '
            'the visible set is larger than 12 and the budget is what bounded '
            'the count');
  });

  test('criterion 1: a settled frame equals the live frame after a zoom',
      () async {
    // **The zoom half of criterion 1, and the camera was the degenerate
    // fixture.** Every criterion 1 case before this one runs at the rig's one
    // scale of 1.4 -- a pan cannot change a scale -- so nothing in this plan
    // had ever asked whether a *different* scale tiles exactly.
    //
    // It does, at all forty-one factors swept from 0.70 to 1.50 in steps of
    // 0.02. Six of them used to lose a whole stroke column -- defect F1, which
    // the group below now gates at zero rather than at a bound -- so the list
    // here no longer excludes anything: **1.22 and 1.10 are two of the six**,
    // and they are in it deliberately. These are a criterion-1 claim rather
    // than a demonstration -- mutant M4 reddens every one of them, because a
    // generation replayed at the old scale carries the old stroke widths and
    // the old dash phase and no pan test can see either.
    for (final factor in <double>[0.74, 0.83, 1.10, 1.16, 1.22, 1.30]) {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
      addTearDown(rig.dispose);
      rig.paintOnce();
      rig.zoomBy(factor);
      // Two frames. The first anchors the new generation and fills it, with
      // the composite blitted underneath; the second bakes nothing, finds the
      // viewport covered, and retires the composite. Only the third frame --
      // the comparison's own -- is a clean generation, and that is the frame
      // criterion 1 is a claim about.
      rig.paintOnce();
      rig.paintOnce();
      expect(rig.cache.hasCarryOver, isFalse,
          reason: 'factor $factor: a covered viewport retires the composite, '
              'and a composite still on screen would compose stale ink under '
              'every antialiased tile edge');
      await expectTiledEqualsLive(rig);
    }
  });

  // **Defect F1, closed in Task 9a.** This group was a measurement of a live
  // defect; it is now the gate that keeps it closed.
  //
  // **What used to happen.** At six of the forty-one zoom factors swept from
  // 0.70 to 1.50 in steps of 0.02, one whole one-device-pixel stroke column
  // was absent from the tiled frame -- 370 to 561 pixels of pure `uncovered`
  // with zero `stray`. A line simply was not drawn.
  //
  // **The mechanism, measured.** At factor 1.17 the quantised camera is
  // `a = 1.638, e = -77.5`, which puts `crossingGrid`'s vertical line at world
  // x 106 on device x **192.256** -- 0.256 px right of the tile boundary at
  // 192. Its stroke is 2 device pixels wide, so it covers pixel centres 191.5
  // and 192.5, and the live frame inks both. Pixel 191 belongs to tile column
  // 2, whose device range is `[128, 192)`; `cache.tilesHolding(Handle(1009))`
  // returned `[3]`. Column 2 never received the entity at all.
  //
  // **Why.** `DraftPainter.paint` derives its index query from
  // `camera.visibleWorld(viewport)` with no slack whatsoever
  // (`draft_painter.dart:338`); only its *screen* clip carries
  // `kScreenClipInflate`, which is defined as "half the widest stroke the
  // frame can draw" precisely so a centreline just outside still contributes
  // its edge. A tile bake passes the tile as the viewport, so the tile's world
  // rect ended 0.08 world units left of the centreline and the half of the
  // stroke that reaches back inside was drawn by nobody: the neighbouring tile
  // owns different pixels, and a device column can only be written by the tile
  // containing it. A clip only *keeps*; it cannot return what the query never
  // yielded.
  //
  // **The fix.** `_bake` pads its cull by `kTileSlack`, and direction two of
  // invalidation pads its tile box by the same constant -- see that constant's
  // own documentation for why one number has to serve both, and for what the
  // padding costs. The sweep goes from **6 of 41 to 0 of 41**, which is why
  // the assertions below are exact zeros rather than the bounds they were.
  // `criterion 1: a settled frame equals the live frame after a zoom` now runs
  // two of these six factors as well.
  group(
      'defect F1 stays closed: a stroke centreline just outside a tile '
      'still inks it', () {
    test('the six factors that used to lose a stroke column agree exactly',
        () async {
      for (final factor in <double>[0.72, 0.78, 0.82, 1.06, 1.10, 1.22]) {
        final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
        addTearDown(rig.dispose);
        rig.zoomBy(factor);
        rig.paintOnce();
        final report = await measureTiledAgreement(rig);
        expect(report.liveInk, greaterThan(5000),
            reason: 'factor $factor: the floor first: $report');
        // Measured before the fix: 370, 415, 436, 527, 484 and 561 uncovered,
        // in that order. Zero now, and a bound rather than a zero here would
        // let the whole column come back.
        expect(report.uncoveredPixels, 0,
            reason: 'factor $factor: a stroke whose centreline sits just '
                'outside a tile still inks the pixel column inside it, and no '
                'other tile can write that column: $report');
        expect(report.strayPixels, 0,
            reason: 'factor $factor: and the padded bake draws nothing the '
                'live frame does not -- the hard clip still holds each tile '
                'to exactly the pixels it owns, which is what stops the wider '
                'query double-inking a seam: $report');
        expect(report.differingPixels, 0, reason: 'factor $factor: $report');
      }
    });
  });

  test('a whole-document change clears the carry-over as well as the tiles',
      () async {
    for (final change in <DocChange>[
      const DocumentLoaded(),
      const DocumentPurged(),
    ]) {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
      addTearDown(rig.dispose);
      rig.paintOnce();
      rig.cache.tilesBakedPerFrame = 0;
      rig.zoomBy(1.19);
      rig.paintOnce();
      expect(rig.cache.hasCarryOver, isTrue,
          reason: '$change: the floor -- there must be a composite to clear');

      rig.cache.applyChange(change, rig.doc);
      expect(rig.cache.hasCarryOver, isFalse,
          reason: '$change: the composite is anchored to a camera that no '
              'longer means anything, and it holds native memory until '
              'something disposes it');
      expect(rig.cache.liveTileCount, 0, reason: '$change');
    }
  });

  test('an edit while a composite stands drops it, and the frame repaints',
      () async {
    // **Finding C1, and the state the test below could not reach.** That test
    // asserts `liveDrawCount > 0` and its comment says "which a composite
    // standing in front of it would hide" -- the right claim, made in the one
    // state where the hazard cannot occur, because it never zooms and no
    // composite ever exists. This one zooms first, so the assertion runs with
    // a composite actually standing.
    //
    // What it was hiding: `_dropGeneration` and `_invalidateTouched` left
    // `_carryOver` alone, and `paintFrame` suppresses the live fallback
    // outright whenever the composite covers the viewport. Measured before the
    // fix, on the frame after a layer edit: `hasCarryOver=true,
    // liveTileCount=0, liveDrawCount=0, carryOverBlitCount=1` -- the whole
    // frame is the pre-edit drawing -- and still `liveDrawCount=0` eleven
    // frames later. At a real bake budget of 4 it was no better: four tiles
    // rebaked at the new colour, and every pixel they did not cover still the
    // old one, for the whole of the settle.
    for (final (what, edit) in <(String, void Function(TileRig))>[
      (
        'a table edit, which reaches no command at all',
        (rig) {
          rig.doc.tables.layers.add(const LayerRecord(
            handle: Handle(900),
            name: 'WALLS',
            color: IndexedColor(3),
            linetype: ReservedHandles.continuousLinetype,
            lineweight: 50,
            transparency: 40,
          ));
        }
      ),
      // The per-tile arm, which is a different path and was a second hole:
      // `_invalidateTouched` removes tiles one at a time and never reaches
      // `_dropGeneration`, so only a drop hoisted above `applyChange`'s switch
      // catches this one. With no tiles alive the `doomed` sweep finds nothing
      // to remove, which is exactly what makes the composite the only thing
      // left on screen.
      (
        'a leaf edit, which takes the per-tile path',
        (rig) {
          rig.cache.applyChange(
              const CommandApplied(label: 'move', touched: {Handle(1001)}),
              rig.doc);
        }
      ),
    ]) {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
      addTearDown(rig.dispose);
      rig.paintOnce();
      // Zero budget from here, so the incoming generation cannot quietly
      // refill and make a stale composite look like a repaint.
      rig.cache.tilesBakedPerFrame = 0;
      rig.zoomBy(1.19);
      rig.paintOnce();
      expect(rig.cache.hasCarryOver, isTrue,
          reason: '$what: the floor, and the whole point of this test -- '
              'without a composite standing, the assertions below run in a '
              'state where what they are about cannot happen');
      expect(rig.cache.liveTileCount, 0,
          reason: '$what: and no tile stands either, so the frame on screen '
              'is the composite and nothing else');
      rig.cache.resetCounters();

      edit(rig);
      rig.paintOnce();

      expect(rig.cache.hasCarryOver, isFalse,
          reason: '$what: a composite is a picture of the document before the '
              'edit');
      expect(rig.cache.carryOverBlitCount, 0,
          reason: '$what: and it must not have reached the canvas even once '
              'on the way out');
      expect(rig.cache.liveDrawCount, greaterThan(0),
          reason: '$what: the viewport is uncovered and must be walked live, '
              'at the post-edit document -- the walk a covering composite '
              'suppresses outright');
    }
  });

  test('a table edit drops the generation without minting a carry-over',
      () async {
    // The other half, and not the same claim: above, a composite already
    // stands and must be destroyed; here the outgoing generation *covers the
    // viewport*, which is the precondition `_retireGeneration` mints on. A
    // `_dropGeneration` that composited instead of disposing would put the
    // pre-edit colour straight back on screen for as long as the refill takes
    // -- while `liveTileCount` still read zero and every existing
    // invalidation gate stayed green.
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    expect(rig.cache.liveTileCount, greaterThan(30),
        reason: 'the floor: a generation worth compositing');
    final generation = rig.cache.generation;

    // Budget zero for the frame that follows, so the drop cannot be papered
    // over by an immediate refill.
    rig.cache.tilesBakedPerFrame = 0;
    rig.doc.tables.layers.add(const LayerRecord(
      handle: Handle(900),
      name: 'WALLS',
      color: IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    ));
    rig.paintOnce();

    expect(rig.cache.liveTileCount, 0, reason: 'the generation is dropped');
    expect(rig.cache.hasCarryOver, isFalse,
        reason: 'a table edit invalidates pixels; it does not retire a scale');
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'and the uncovered viewport is drawn live, at the new table '
            'values -- which a composite standing in front of it would hide');
    expect(rig.cache.generation, generation,
        reason: 'the lattice stays: the anchor still describes the camera');
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

/// Non-transparent pixels in one tiled frame of [rig].
///
/// A separate instrument from `measureTiledAgreement`, and deliberately so:
/// that one compares two arms and is blind to a frame both arms leave blank.
/// This one asks the question that gates the carry-over -- did anything at all
/// reach the canvas -- which is the only way to tell a composite that painted
/// from a `drawImageRect` into a degenerate rect.
Future<int> frameInk(TileRig rig) async {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kTileDpr);
  canvas.clipRect(Offset.zero & kTileViewport);
  rig.cache.paintFrame(
    canvas: canvas,
    viewport: kTileViewport,
    devicePixelRatio: kTileDpr,
    camera: rig.camera,
    painter: rig.painter,
    sink: rig.sink,
    vertices: rig.vertices,
    tablesRevision: rig.doc.tables.mutationRevision,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  final bytes = data!.buffer.asUint8List();
  var ink = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] != 0) ink++;
  }
  return ink;
}
