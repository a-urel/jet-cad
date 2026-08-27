// Live frame against tiled frame, byte for byte.
//
// **Why not `measureAgreement`.** That instrument's vertices arm rasterises in
// Dart (`support/sink_comparison.dart`), so it never reaches a `Canvas` and
// never executes a `drawImageRect`. A tile is invisible to it.
//
// **Why zero rather than a tolerance.** `quantiseCamera` puts every tile
// destination on whole device pixels at every camera, so a blit is a 1:1
// texel-to-pixel copy and there is nothing for a tolerance to absorb. A
// tolerance here would hide exactly the defects the criteria exist to catch.
//
// **What this cannot prove.** Software Skia does not antialias `drawVertices`
// at all — `drawvertices_antialiasing_test.dart` pins that, in its own words
// as "a fact about `flutter_test`'s software Skia, not about this codebase" —
// so this instrument cannot produce an antialiased seam and a zero result here
// is partly a property of the instrument. It proves geometric completeness:
// no pixel missing, none drawn twice, no clipping arithmetic error. Accepted
// gap G1 owns the rest, and mutant M3 is deferred to it. **M15 is the mutant
// this instrument fires**, and it moves pixels software Skia renders perfectly
// well.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'tile_fixture.dart';
import 'tile_harness.dart';

class InkReport {
  const InkReport({
    required this.liveInk,
    required this.tiledInk,
    required this.strayPixels,
    required this.uncoveredPixels,
    required this.differingPixels,
    required this.liveTriangleCount,
    required this.tiledTriangleCount,
    this.liveStripInk = 0,
  });

  /// Non-transparent pixels in the live capture.
  final int liveInk;
  final int tiledInk;

  /// Tiled pixels with ink where live has none.
  final int strayPixels;

  /// Live pixels with ink where tiled has none.
  final int uncoveredPixels;

  /// Pixels whose four bytes differ at all, stray and uncovered included.
  final int differingPixels;

  /// `VerticesDrawSink.frameTriangleCount` for the live arm: one
  /// `DraftPainter.paint` call over the whole viewport.
  final int liveTriangleCount;

  /// `VerticesDrawSink.frameTriangleCount` for the tiled arm: whatever
  /// `TileCache.paintFrame` actually emitted through the sink that frame.
  ///
  /// **Not the fallback alone.** At this rig's one-tile bake budget the same
  /// frame bakes one tile *and* runs the live fallback, and `_bake` draws
  /// through this same sink, so this count is "one tile's worth of geometry"
  /// plus whatever the fallback walked. See the comment on the ratio these
  /// numbers feed, in `measureFallbackAgreement`, for how that is accounted
  /// for rather than ignored.
  final int tiledTriangleCount;

  /// Non-transparent pixels of the **live** capture that lie inside
  /// `TileCache.debugLastStrip`, in device pixels — [uncovered] padded
  /// outward by `kTileSlack`, **not** `uncovered` itself. `uncovered` is the
  /// band the fallback actually owes; the pad reaches back into area the
  /// frame already blitted, so this field is weaker than its name might
  /// suggest and does not prove the band owed carried any ink.
  ///
  /// **A weaker anti-vacuity clause than the other six, and the gap is
  /// named (gap H7 in STATUS.md).** [liveInk] counts the whole frame, which
  /// at a fallback sample is dominated by the tiles the frame blitted; a
  /// fallback that walked the strip and found nothing in it still leaves
  /// [liveInk] in the tens of thousands and every pixel count at zero. What
  /// actually closes that gap is `fillingGrid`'s extent, not this field: two
  /// of the eight swept offsets carried no ink in the band owed until that
  /// fixture was widened — see its doc comment — and a re-review confirmed
  /// this clause alone would not have caught it: on the old, narrower
  /// extent, with this clause live at a floor of 200, deleting
  /// `canvas.translate` from `TileCache.paintFrame` still left the whole
  /// widget suite green. The one place this field is demonstrably
  /// load-bearing is under M3, where it reads `0` on the inverted rect
  /// `Rect.fromLTRB(395.0, 52.0, 387.0, 300.0)` (`left > right`, so
  /// `inkInside` returns `0` by construction) — see the mutation log.
  ///
  /// Zero on an arm that is not measured for it: [measureFallbackAgreement]
  /// only fills this in when it is asked to gate on it.
  final int liveStripInk;

  InkReport withStripInk(int ink) => InkReport(
      liveInk: liveInk,
      tiledInk: tiledInk,
      strayPixels: strayPixels,
      uncoveredPixels: uncoveredPixels,
      differingPixels: differingPixels,
      liveTriangleCount: liveTriangleCount,
      tiledTriangleCount: tiledTriangleCount,
      liveStripInk: ink);

  @override
  String toString() => 'InkReport(live: $liveInk, tiled: $tiledInk, '
      'stray: $strayPixels, uncovered: $uncoveredPixels, '
      'differing: $differingPixels, liveTri: $liveTriangleCount, '
      'tiledTri: $tiledTriangleCount, stripInk: $liveStripInk)';
}

Future<Uint8List> _capture(void Function(Canvas canvas) draw) async {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(kTileDpr);
  canvas.clipRect(Offset.zero & kTileViewport);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Paints [rig] both ways and compares.
///
/// The live arm goes through the **quantised** camera, not the raw one: that is
/// the rule, not a concession to the tiled arm. This instrument quantises its
/// own live arm, deliberately, at the call below -- `DraftCanvas` is not
/// involved and is not on this path at all. `DraftCanvas` itself quantises
/// only inside its tiled branch; its default (non-tiled) path draws the raw
/// camera untouched. Quantising here is what makes the two arms the same
/// drawing seen twice rather than two different drawings.
Future<InkReport> measureTiledAgreement(TileRig rig) async {
  final quantised = quantiseCamera(rig.camera, kTileDpr);

  // Reset around each arm rather than once, so each capture's count is that
  // arm's own emission and not the running total across both.
  rig.vertices.resetCounters();
  final live = await _capture((canvas) {
    rig.painter.debugRebaseOrigin =
        rebaseOriginFor(quantised.visibleWorld(kTileViewport));
    rig.sink.canvas = canvas;
    rig.vertices.canvas = canvas;
    rig.painter.paint(rig.vertices, quantised, kTileViewport);
    rig.vertices.flush();
    rig.painter.debugRebaseOrigin = null;
  });
  final liveTriangleCount = rig.vertices.frameTriangleCount;

  rig.vertices.resetCounters();
  final tiled = await _capture((canvas) {
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
  });
  final tiledTriangleCount = rig.vertices.frameTriangleCount;

  var liveInk = 0, tiledInk = 0, stray = 0, uncovered = 0, differing = 0;
  for (var i = 0; i < live.length; i += 4) {
    final liveHasInk = live[i + 3] != 0;
    final tiledHasInk = tiled[i + 3] != 0;
    if (liveHasInk) liveInk++;
    if (tiledHasInk) tiledInk++;
    if (tiledHasInk && !liveHasInk) stray++;
    if (liveHasInk && !tiledHasInk) uncovered++;
    if (live[i] != tiled[i] ||
        live[i + 1] != tiled[i + 1] ||
        live[i + 2] != tiled[i + 2] ||
        live[i + 3] != tiled[i + 3]) {
      differing++;
    }
  }
  return InkReport(
      liveInk: liveInk,
      tiledInk: tiledInk,
      strayPixels: stray,
      uncoveredPixels: uncovered,
      differingPixels: differing,
      liveTriangleCount: liveTriangleCount,
      tiledTriangleCount: tiledTriangleCount);
}

/// The gate. Zero stray, zero uncovered, zero differing — and a real drawing.
Future<InkReport> expectTiledEqualsLive(TileRig rig,
    {int minimumInk = 500}) async {
  final report = await measureTiledAgreement(rig);
  // The floor first. A comparison of two blank captures agrees perfectly and
  // proves nothing, which is the failure mode this whole plan's spike named.
  expect(report.liveInk, greaterThan(minimumInk),
      reason: 'the live arm must actually draw: $report');
  expect(report.tiledInk, greaterThan(minimumInk),
      reason: 'the tiled arm must actually draw: $report');
  expect(report.strayPixels, 0, reason: '$report');
  expect(report.uncoveredPixels, 0, reason: '$report');
  expect(report.differingPixels, 0, reason: '$report');
  return report;
}

/// The **live** frame's device pixels, RGBA, row-major at [kTileDpr].
///
/// The differential gate above reduces two captures to counts; a test that
/// needs to ask *where* the ink is — "does this stroke really reach into the
/// tile column its centreline is not in" — needs the pixels themselves. Same
/// quantised camera as [measureTiledAgreement]'s live arm, for the same
/// reason: the two arms must be one drawing seen twice.
Future<Uint8List> captureLiveFrame(TileRig rig) => _capture((canvas) {
      final quantised = quantiseCamera(rig.camera, kTileDpr);
      rig.painter.debugRebaseOrigin =
          rebaseOriginFor(quantised.visibleWorld(kTileViewport));
      rig.sink.canvas = canvas;
      rig.vertices.canvas = canvas;
      rig.painter.paint(rig.vertices, quantised, kTileViewport);
      rig.vertices.flush();
      rig.painter.debugRebaseOrigin = null;
    });

/// The **tiled** frame's device pixels, RGBA, row-major at [kTileDpr].
///
/// [captureLiveFrame]'s counterpart, and the only instrument that can see the
/// frame kinds a cache reaches by *standing still*. The widget capture
/// (`captureTiled`) cannot: an uncovered cache asks `DraftCanvas` for another
/// frame from a post-frame callback, so by the time `pump` returns the repaint
/// boundary is dirty and `toImage` asserts on `!debugNeedsPaint`. Precisely
/// the states this reads -- an unsettled cache one frame after the camera
/// stopped -- are the ones that leave it dirty.
///
/// **The capture is itself a frame, and that is the point.** It calls
/// `paintFrame` once at the rig's current camera, exactly as the next frame of
/// the application would, and the cache advances accordingly: the pixels
/// returned are that frame's, and the counters read afterwards are that
/// frame's too.
Future<Uint8List> captureTiledFrame(TileRig rig) => _capture((canvas) {
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
    });

/// Non-transparent pixels of [pixels] inside [logical], a rectangle in
/// **logical** pixels that is scaled by [kTileDpr] and clipped to the capture.
///
/// The capture is the device-pixel buffer [captureLiveFrame] returns;
/// `TileCache.debugLastStrip` is logical, like every rectangle `paintFrame`
/// works in, so the conversion belongs here rather than at the call site.
int inkInside(Uint8List pixels, Rect logical) {
  final width = (kTileViewport.width * kTileDpr).round();
  final height = (kTileViewport.height * kTileDpr).round();
  final x0 = (logical.left * kTileDpr).floor().clamp(0, width);
  final x1 = (logical.right * kTileDpr).ceil().clamp(0, width);
  final y0 = (logical.top * kTileDpr).floor().clamp(0, height);
  final y1 = (logical.bottom * kTileDpr).ceil().clamp(0, height);
  var ink = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (pixels[(y * width + x) * 4 + 3] != 0) ink++;
    }
  }
  return ink;
}

/// The tiled arm's `frameTriangleCount` may not exceed the live arm's by more
/// than this fraction, when [measureFallbackAgreement] is asked to check it.
///
/// **Not a bound on the fallback alone.** At this rig's one-tile bake budget
/// the tiled frame also bakes one 64x64 tile through the same sink, so
/// `tiledTriangleCount` is that tile's geometry plus whatever the fallback
/// walked -- never the fallback in isolation. The bound below has to hold
/// against that combined total, not an idealised fallback-only count.
///
/// **Bracketed, not guessed — and re-bracketed when `fillingGrid`'s extent
/// changed.** The bound was found the way a bound has to be: by locating the
/// value at which *correct* code first fails, then the value the *mutant*
/// produces, and sitting between them.
///
/// Swept over `kFallbackOffsets` on `fillingGrid` (the fixture
/// `criterion 2 and 2c` uses), the shipped narrowing's tiled/live ratio runs
/// **0.7742 to 0.9375** (48/62 .. 60/64 triangles), worst at
/// `Offset(0, 53)`. The assertion is strict, so correct code fails at any
/// bound **≤ 0.9375** and passes at 0.94 — measured, not derived: `0.9375`
/// reddens `criterion 2 and 2c` at that offset and `0.94` is green.
///
/// Growing `_drawInto`'s `Size` argument from the strip back to the full
/// `viewport` (mutant M5, and the end state M4 also reaches) — leaving the
/// clip, the translate and the camera offset alone, so `debugLastStrip` still
/// reports the strip and every pixel still lands correctly — moves the sweep
/// to **0.8710 to 1.2903**, and to **1.0000 or above at seven of the eight
/// offsets**. The lowest of those seven is the binding endpoint.
///
/// So the bracket is **(0.9375, 1.0000]** and `0.97` is its midpoint,
/// 0.0325 above the highest ratio correct code produces and 0.0300 below the
/// lowest ratio the mutant produces at an offset the gate can see. In
/// triangles, at the tightest offset it allows 62 of 64 where correct code
/// emits 60: two triangles of headroom, deterministic rather than flaky, and
/// brittle to any future edit of `fillingGrid`'s geometry or of the swept
/// offsets — recorded as such in `plan-3h-mutation-log.md`.
///
/// **The eighth offset, `Offset(-41, 0)`, is a hole in this gate and is
/// named rather than hidden.** Its strip already contains almost every entity
/// the full viewport would find, so the mutant only moves it 0.7742 → 0.8710,
/// both below the bound. The gate is a *sweep*-level gate: it kills the
/// mutant at seven offsets and would not have killed it at that one alone.
///
/// **Fixture-dependent, and that is why it can be switched off.**
/// `nearAxisDiagonals` (`criterion 2b`) is a handful of long diagonals
/// spanning most of the viewport; a query the size of the strip and a query
/// the size of the full viewport catch the *same* entities there, so the
/// ratio sits at exactly 1.0 (or 0/20 where the strip misses the diagonals
/// entirely) even under the correct implementation. That fixture carries no
/// signal for this check, so applying the bound to it would fail correct
/// code, not catch a mutant. It is the only caller that opts out.
const double kTriangleBudgetRatio = 0.97;

/// One fallback sample: a frame that is part blit and part live walk, compared
/// against the live frame at the same camera.
///
/// **Each sample owns its cache.** A sweep that panned one rig across offsets
/// would inherit tiles from the previous offset and become a warm-tile
/// comparison -- one of the three arrangements that failed to detect a
/// crippled query before this instrument existed.
///
/// [checkTriangleBudget] gates the [kTriangleBudgetRatio] assertion. **It
/// defaults to on**, so a caller that wants no triangle gate has to say so and
/// justify it, rather than getting a thinner sample by omission; the only
/// caller that opts out is `criterion 2b`, whose fixture carries no signal for
/// the ratio -- see [kTriangleBudgetRatio].
///
/// [minimumStripInk] is the floor on [InkReport.liveStripInk], the ink the
/// live frame carries **inside `TileCache.debugLastStrip`** — the strip
/// padded outward by `kTileSlack`, a weaker region than the band the
/// fallback actually owes (`uncovered`); see [InkReport.liveStripInk].
/// Passing `0` disables the clause and makes the sample vacuous as to the
/// fallback; only `criterion 2b` does, because `nearAxisDiagonals` leaves
/// five of the eight swept bands empty and widening it would import a
/// different fixture's contract.
Future<InkReport> measureFallbackAgreement(
  DraftDocument Function(FlutterTextMeasurer) of,
  FlutterTextMeasurer measurer,
  Offset pan, {
  int minimumInk = 500,
  int minimumStripInk = 200,
  bool checkTriangleBudget = true,
}) async {
  final rig = TileRig(
      tileDevicePixels: 64, tilesBakedPerFrame: 1000, document: of(measurer));
  try {
    // Cover the viewport, so the strip that enters next has blitted tiles on
    // its interior side.
    rig.paintOnce();
    rig.cache.resetCounters();
    // One tile a frame, so the entering band stays uncovered and the fallback
    // owes it.
    rig.cache.bakeBudgetDevicePixels = 64 * 64;
    rig.panBy(pan.dx, pan.dy);
    // No settle needed here: this fixture only pans, so no generation is
    // ever retired and `_carryOver` stays null throughout -- the rest gate's
    // fallback for a moving frame with nothing to fall back on keeps this
    // call unGated, so the reduced budget below still leaves a genuine
    // entering strip for the live fallback to own on this very call.
    final measured = await measureTiledAgreement(rig);

    // Anti-vacuity, and every clause of it was earned by an arrangement that
    // passed while proving nothing.
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'pan $pan ran no fallback: $measured');
    expect(rig.cache.blitCount, greaterThan(0),
        reason: 'pan $pan blitted nothing, so nothing was partly baked');
    final strip = rig.cache.debugLastStrip;
    expect(strip, isNotNull, reason: 'pan $pan recorded no strip');
    // The clause `bakeCount`/`liveDrawCount` cannot supply: `uncovered` is a
    // bounding rectangle, so an L-shaped uncovered set bounds to the whole
    // viewport and leaves no interior edge for a crippled query to lose ink
    // across.
    expect(strip != Offset.zero & kTileViewport, isTrue,
        reason: 'pan $pan left no interior strip edge: strip=$strip');
    // **Ink inside the padded strip, not merely somewhere in the frame --
    // and weaker than ink inside the band the fallback owes.** The two
    // clauses above see the strip's *shape*; the two below see the frame's
    // *total* ink, which at a fallback sample is dominated by blitted tiles.
    // This clause measures `strip` (`debugLastStrip`, `uncovered` padded
    // outward by `kTileSlack`), and the pad reaches back into area the frame
    // already blitted, so ink here does not prove `uncovered` -- the band
    // actually owed -- carried any. What protects this sweep from a vacuous
    // band is `fillingGrid`'s extent, not this clause: two of the eight
    // swept offsets entered across bare canvas until that fixture's extent
    // was widened -- passing every other clause here while the fallback drew
    // nothing at all -- see gap H7 in STATUS.md. A separate capture rather
    // than a by-product of the comparison above: `measureTiledAgreement`
    // reduces its two captures to counts, and this clause needs to know
    // *where* the ink is.
    final report =
        measured.withStripInk(inkInside(await captureLiveFrame(rig), strip!));
    expect(report.liveStripInk, greaterThanOrEqualTo(minimumStripInk),
        reason: 'pan $pan: the live frame carries no ink inside the padded '
            'strip ($strip) -- weaker than the band the fallback owes -- so '
            'every pixel assertion below is satisfied by a fallback that '
            'could have drawn nothing: $report');
    expect(report.liveInk, greaterThan(minimumInk), reason: '$report');
    expect(report.tiledInk, greaterThan(minimumInk), reason: '$report');
    // Pixels alone cannot see this: a fallback query padded back out to the
    // full viewport still clips to `uncovered` and lands every pixel right,
    // so it reads as a pixel-perfect frame while re-tessellating the whole
    // scene underneath. This is what caught it -- see [kTriangleBudgetRatio].
    if (checkTriangleBudget) {
      expect(report.tiledTriangleCount,
          lessThan(report.liveTriangleCount * kTriangleBudgetRatio),
          reason: 'pan $pan: the tiled arm emitted as much geometry as the '
              'full-frame live arm, so the fallback walked far more than the '
              'strip: $report');
    }
    return report;
  } finally {
    rig.dispose();
  }
}

/// [measureFallbackAgreement] over a set of pan offsets, each independent.
Future<List<InkReport>> sweepFallbackAgreement({
  required DraftDocument Function(FlutterTextMeasurer) of,
  required List<Offset> offsets,
  int minimumInk = 500,
  int minimumStripInk = 200,
  bool checkTriangleBudget = true,
}) async {
  final reports = <InkReport>[];
  for (final offset in offsets) {
    final measurer = FlutterTextMeasurer();
    try {
      reports.add(await measureFallbackAgreement(of, measurer, offset,
          minimumInk: minimumInk,
          minimumStripInk: minimumStripInk,
          checkTriangleBudget: checkTriangleBudget));
    } finally {
      measurer.clear();
    }
  }
  return reports;
}

/// The camera whose view span sits **just past a power-of-two rebase step**.
///
/// `rebaseOriginFor` (`camera_controller.dart`) takes the larger of the
/// visible world box's two spans, floors its base-2 logarithm to get a step,
/// and floors the view *centre* onto that step. A band is a fraction of the
/// frame's height, so a `_bakeBand` that derived its own origin instead of
/// using the one handed in would floor a different centre — and only lands on
/// a *different* step cell when a cell boundary actually falls inside the
/// frame. At an ordinary camera it usually does not, and the mutation is
/// invisible; this camera is chosen so it does.
///
/// **The arithmetic, and how it is known to straddle.** The viewport is
/// [kTileViewport], 400x300 logical. At the scale 3.0 below the visible world
/// box is `400 / 3 = 133.333` by `300 / 3 = 100`, so the span is **133.333**,
/// `floor(log2(133.333)) = 7`, and the step is **128** — the view is 1.042
/// steps wide, so exactly one cell boundary lies inside it. The translations
/// put the centre at
///
///     cx = (200 - e) / 3   = (200 + 184.5) / 3 = 128.1667
///     cy = (f - 150) / 3   = (534.5 - 150) / 3 = 128.1667
///
/// which is **0.1667 world units — one device pixel — past the 128 boundary**,
/// so the frame origin is `(128, 128)` and any band whose own centre falls
/// below 128 takes `(128, 0)` or `(0, 128)` instead. The visible world y runs
/// `78.167 .. 178.167`, so the 128 line is 50 world units inside it and the
/// bands genuinely fall on both sides.
///
/// Both translations are whole device pixels at [kTileDpr] (`-184.5 * 2 =
/// -369`, `534.5 * 2 = 1069`), so `quantiseCamera` leaves this camera exactly
/// as written and the tiled and live arms see the same matrix. The visible
/// world box, `x 61.5 .. 194.833` by `y 78.167 .. 178.167`, is strictly inside
/// [bandCrossingGrid]'s `-52 .. 380` by `-52 .. 300` extent, so the drawing
/// fills the viewport here rather than leaving a blank margin the comparison
/// would pass on for free.
ViewportTransform rebaseBoundaryCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(3.0, 0, 0, -3.0, -184.5, 534.5));

/// The [kTileViewport] at [kTileDpr], in device pixels — the size both
/// captures come back at.
///
/// **Asserted rather than assumed, by every helper that takes them.** The
/// edge sweeps below index a flat buffer as `(y * width + x) * 4`, so a
/// capture of a different size is not a failure but a *silent* reinterpretation
/// of the wrong quarter of the image, and the sweep goes on reporting zero.
/// That is not hypothetical: `pumpTiled`'s `SizedBox` was inert under
/// `pumpWidget`'s tight constraints until this task, so the canvas really was
/// 800x600 logical and these captures really were 1600x1200.
const int kCaptureWidth = 800;
const int kCaptureHeight = 600;

Future<ByteData> _captureBoundary(WidgetTester t) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.descendant(
      of: find.byType(DraftCanvas), matching: find.byType(RepaintBoundary)));
  late ByteData data;
  // `toImage` is a real async rasterisation and deadlocks under the fake async
  // zone a `testWidgets` body runs in; `runAsync` is the documented way out
  // and is the pattern this file's `_capture` already relies on through
  // `Picture.toImage`.
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kTileDpr);
    data = (await image.toByteData())!;
    image.dispose();
  });
  return data;
}

/// The tiled canvas exactly as it stands, at [kTileDpr].
///
/// Nothing is pumped here: a pump would give the cache another frame, and the
/// state under test is the one the caller settled into.
Future<ByteData> captureTiled(WidgetTester t, TiledHarness h) =>
    _captureBoundary(t);

/// The same document, index and camera, drawn with `tiles: false`.
///
/// **The camera is quantised and that is the rule, not a concession.**
/// `TileCache.paintFrame` quantises once, covering the blits and the live
/// fallback alike, so a tiled frame is internally consistent;
/// `DraftCanvas`'s untiled branch deliberately does not (see its own comment
/// — quantising there would move the *default* rendering path by up to half a
/// device pixel for nothing). Handing the untiled tree the quantised camera is
/// what makes the two captures one drawing seen twice rather than two
/// drawings, and it is exactly what [measureTiledAgreement] does for its own
/// live arm.
///
/// **This replaces the widget tree**, so the tiled cache behind [h] is
/// disposed by the time it returns. Capture the tiled arm first — every caller
/// here does, and Dart evaluates arguments left to right, so
/// `differingPixels(await captureTiled(...), await captureLive(...))` is
/// ordered correctly by the language rather than by luck.
///
/// **The key is the whole reason this returns a different image at all, and
/// without it this instrument was blind to every mutant.**
/// `_DraftCustomPainter.shouldRepaint` returns `false` unconditionally and
/// says why — `repaint` is the only trigger, and answering `true` there would
/// repaint on every unrelated rebuild. Pumping a tree that differs only in
/// `tiles` therefore re-runs `didUpdateWidget` (which does tear the cache
/// down) and then **keeps the retained picture**: the "live" capture came back
/// byte-for-byte equal to the tiled one, and `differingPixels` read zero under
/// M3, M7, M9, M9b, M10 and M11 alike. A key the tiled tree does not carry
/// makes this a different element, so the render object is new and has no
/// picture to retain.
Future<ByteData> captureLive(WidgetTester t, TiledHarness h) async {
  final controller = CameraController(quantiseCamera(h.camera.value, kTileDpr));
  addTearDown(controller.dispose);
  // The same `Center` `pumpTiled` needs, and for the same reason: without it
  // this tree would be 800x600 logical and the two captures would be the same
  // size as each other but not the size either arm's arithmetic assumes.
  await t.pumpWidget(MediaQuery(
    data: const MediaQueryData(devicePixelRatio: kTileDpr),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: SizedBox(
        width: kTileViewport.width,
        height: kTileViewport.height,
        child: DraftCanvas(
          key: const ValueKey('captureLive'),
          document: h.document,
          index: h.index,
          camera: controller,
          tiles: false,
          tileDevicePixels: 64,
        ),
      )),
    ),
  ));
  await t.pump();
  return _captureBoundary(t);
}

/// Non-transparent pixels of a **widget capture** inside [logical], a
/// rectangle in logical pixels scaled by [kTileDpr] and clipped to the
/// capture.
///
/// [inkInside] answers the same question for a [TileRig] capture, which is a
/// `Uint8List`; this one takes the `ByteData` [captureTiled] and [captureLive]
/// return, and is indexed against [kCaptureWidth] rather than against
/// [kTileViewport], for the reason [differingPixelsOnTileEdges] states: a
/// capture of another size is read as the wrong quarter of itself and still
/// reports a number.
///
/// **Ink, not agreement.** The question it exists for is "did the frame draw
/// anything here at all, or is this region background" -- which is what a
/// blank strip left by a frame that returned early looks like, and which a
/// whole-frame `differingPixels` buries under the tiles around it.
int inkInsideCapture(ByteData capture, Rect logical) {
  expect(capture.lengthInBytes, kCaptureWidth * kCaptureHeight * 4,
      reason: 'the sweep indexes rows by kCaptureWidth');
  final x0 = (logical.left * kTileDpr).floor().clamp(0, kCaptureWidth);
  final x1 = (logical.right * kTileDpr).ceil().clamp(0, kCaptureWidth);
  final y0 = (logical.top * kTileDpr).floor().clamp(0, kCaptureHeight);
  final y1 = (logical.bottom * kTileDpr).ceil().clamp(0, kCaptureHeight);
  var ink = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (capture.getUint8((y * kCaptureWidth + x) * 4 + 3) != 0) ink++;
    }
  }
  return ink;
}

/// Pixels whose RGBA differs, over two captures of the same size.
///
/// Exact `==` on stored bytes, never a tolerance: these are recorded values,
/// and a tolerance here is how a seam of one unit hides.
int differingPixels(ByteData a, ByteData b) {
  expect(a.lengthInBytes, b.lengthInBytes);
  var differing = 0;
  for (var i = 0; i < a.lengthInBytes; i += 4) {
    if (a.getUint32(i) != b.getUint32(i)) differing++;
  }
  return differing;
}

bool _onEdge(int v, int tileDevicePixels) {
  final m = v % tileDevicePixels;
  return m == 0 || m == 1 || m == tileDevicePixels - 1;
}

/// The same comparison, restricted to the columns and rows a tile boundary
/// falls on and the pixel either side of each.
///
/// A whole-frame count is dominated by tile interiors, where a seam cannot be:
/// a slice that lost one column out of 64 moves 1.5% of the frame and reads as
/// a small number beside a large one. This asks the question where the answer
/// lives.
int differingPixelsOnTileEdges(ByteData a, ByteData b,
    {required int tileDevicePixels, required int width, required int height}) {
  expect(a.lengthInBytes, width * height * 4,
      reason: 'the sweep indexes rows by [width]; a capture of another size '
          'is read as the wrong quarter of itself and still reports zero');
  expect(b.lengthInBytes, a.lengthInBytes);
  var differing = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!_onEdge(x, tileDevicePixels) && !_onEdge(y, tileDevicePixels)) {
        continue;
      }
      final i = (y * width + x) * 4;
      if (a.getUint32(i) != b.getUint32(i)) differing++;
    }
  }
  return differing;
}

/// Ink on those same rows and columns, so the sweep above cannot pass by
/// having looked at background. [live] is the untiled capture.
///
/// **Non-transparent, not "not white", and the difference inverts the
/// answer.** A `DraftCanvas` paints no background, so the page is
/// `0x00000000`; layer zero's colour is white, so the *strokes* are
/// `0xFFFFFFFF`. A predicate of `!= 0xFFFFFFFF` counts every background pixel
/// and no drawn one — it read 11,660 where the true figure is 1,868, and it
/// would have passed a floor of 200 on a capture with nothing in it at all.
/// Alpha is what the rest of this file tests (`inkInside`, `measureTiled‐
/// Agreement`) and it is what is tested here.
int inkOnTileEdges(ByteData live,
    {required int tileDevicePixels, required int width, required int height}) {
  expect(live.lengthInBytes, width * height * 4,
      reason: 'the sweep indexes rows by [width]; a capture of another size '
          'is read as the wrong quarter of itself');
  var ink = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!_onEdge(x, tileDevicePixels) && !_onEdge(y, tileDevicePixels)) {
        continue;
      }
      // Not the transparent page: a drawn pixel.
      if (live.getUint8((y * width + x) * 4 + 3) != 0) ink++;
    }
  }
  return ink;
}
