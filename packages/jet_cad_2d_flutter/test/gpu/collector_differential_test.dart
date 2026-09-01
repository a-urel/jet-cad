import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

const double _devicePixelRatio = 2.0;

/// Tighter than any of the mutations below by orders of magnitude, but far
/// looser than the two arms' honest disagreement: the collector stores
/// `float32` (about 1.2e-7 relative precision) while the reference sink
/// works in `double`, and the largest coordinate this fixture produces is a
/// few hundred device pixels, so float32 rounding alone is on the order of
/// 1e-4 at most. A transposed residual, a dropped `x dpr` factor or a
/// reordered buffer each move a value by whole units or more, so 1e-3 catches
/// every one of them while never tripping on rounding.
const double _tolerance = 1e-3;

void main() {
  test(
      'emits every polyline segment the painter walks, in the same order, '
      'with the residual applied and half-width scaled by dpr', () {
    // `differentialFixture` is this suite's standing corpus, not a fixture
    // built for this test alone: two placements of the same "outer"
    // definition (instance 820, non-uniformly scaled `scale(1.6, 1.1)`, and
    // instance 830, mirrored but conformal `scale(-1.3, 1.3)` -- see
    // `fixtures.dart:126-128`'s own "still conformal: anisotropyRatio 1").
    // Both placements carry a nested instance of "inner" two levels deep
    // (node 520 lives inside definition "outer", so it is placed once per
    // placement of "outer" -- `fixtures.dart:86-96`), plus a root line and a
    // grouped line. No transform anywhere in it is the identity --
    // `assertNoIdentityTransforms`
    // pins that below, which is the guard this project's post-mortem asked
    // for after four fixtures hid a composition-order defect behind
    // transforms that happened to commute.
    //
    // A single-entity fixture cannot show an ordering defect at all: with
    // only one leaf there is only one possible position for its segment in
    // the buffer. This one has two placements of "outer" (each contributing
    // a polyline leaf) interleaved with a nested instance and group leaves,
    // so walk order is a real constraint here -- sorting the buffer by
    // coordinate, or emitting handles in ascending order instead of walk
    // order, produces a different sequence than the one asserted below.
    final doc = differentialFixture();
    assertNoIdentityTransforms(doc);
    _checkAgainstOracle(doc);
  });

  test(
      'fades a hairline stroke exactly as the reference sink does, not just '
      'strokes above the floor', () {
    // The Plan A ledger deferred this comparison: `differentialFixture`'s
    // entities all sit above `VerticesDrawSink.kMinStrokeDevicePixels`, so
    // routing the oracle's expected colour through `_referenceCoveredArgb`
    // (above) is a no-op there and the fade formula itself goes untested by
    // this file. Rather than add a hairline entity to `differentialFixture`
    // -- shared by six other test files
    // (`differential_test.dart`, `draft_canvas_test.dart`,
    // `large_coordinate_test.dart`, `tile_invalidation_test.dart`,
    // `vertices_differential_test.dart`, plus this one) whose entity counts,
    // extents and tile boundaries a new entity could quietly move -- this is
    // a second, local, single-purpose fixture instead.
    final doc = _hairlineFixture();
    _checkAgainstOracle(doc);
  });

  test(
      'fades a hairline stroke by lineweightScale as well as by dpr, not '
      'just the identity default every other gate in this file exercises', () {
    // Every construction of `GeometryCollector` in this file --
    // `_checkAgainstOracle`'s included -- omits `lineweightScale`, so it
    // defaults to `1.0` and the factor `_coveredArgb` multiplies by is the
    // identity everywhere else in this suite, and in
    // `resident_pixel_differential_test.dart` too. Deleting
    // `lineweightScale *` from `_coveredArgb` is invisible to every
    // assertion above for exactly that reason (M-B16). This test is the one
    // place in the package that pins the factor.
    //
    // The arithmetic (`pixelsPerPaperMm=kLogicalPixelsPerMm`
    // (3.7795275590551185, matching `_referenceCoveredArgb`'s own hardcoded
    // constant), `devicePixelRatio=_devicePixelRatio` (2.0, this file's own
    // constant, which `_referenceCoveredArgb` also reads directly rather
    // than taking dpr as a parameter), `lineweightHundredths=25` (this
    // file's own default lineweight, `_style`'s and `differentialFixture`'s),
    // `lineweightScale=0.2`):
    //   * unscaled device width -- what a collector that dropped the factor
    //     would compute, since removing `lineweightScale *` leaves the
    //     expression as if the factor were always `1.0` regardless of what
    //     was configured: 25/100 * 3.7795275590551185 * 2.0 =
    //     1.8897637795275593 device px. That is above
    //     `kMinStrokeDevicePixels` (1.0), so the mutant returns the style's
    //     alpha unchanged (255).
    //   * scaled device width -- correct: 25/100 * 3.7795275590551185 *
    //     0.2 * 2.0 = 0.37795275590551186 device px. That is below the
    //     floor, so the correct collector fades: coverage =
    //     (0.37795275590551186 * 2).clamp(0, 1) = 0.7559055118110237,
    //     alpha = round(255 * 0.7559055118110237) = 193 (0xC1).
    // The two arms disagree on a non-boundary alpha (255 vs 193, not a
    // clamp-to-0-or-255 coincidence), so the factor is load-bearing here,
    // not incidental.
    const lineweightHundredths = 25;
    const argb = 0xFF204060;
    const scale = 0.2;
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: _devicePixelRatio,
        lineweightScale: scale);
    collector.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0]),
        2,
        const ResolvedStyle(
            argb: argb,
            lineweightHundredths: lineweightHundredths,
            linetype: Handle.none,
            linetypeScale: 1),
        closed: false);

    final expectedArgb = _referenceCoveredArgb(argb, lineweightHundredths,
        lineweightScale: scale);
    final expectedAlpha = (expectedArgb >> 24) & 0xFF;
    expect(expectedAlpha, 193,
        reason: 'the fixture above must actually land off the identity and '
            'off a clamp boundary, or this test would not be load-bearing');

    final data = collector.data;
    expect(data[InstanceFieldOffset.a] * 255.0,
        closeTo(expectedAlpha.toDouble(), 0.51),
        reason: 'a collector that dropped lineweightScale from the fade '
            'formula would leave this at 255, not 193');
    // The colour channels are untouched -- `_coveredArgb` gives up alpha,
    // it does not darken.
    expect(data[InstanceFieldOffset.r] * 255.0, closeTo(0x20, 0.51));
    expect(data[InstanceFieldOffset.g] * 255.0, closeTo(0x40, 0.51));
    expect(data[InstanceFieldOffset.b] * 255.0, closeTo(0x60, 0.51));
  });

  test(
      'the fill fixture -- every instance\'s kind, argb and three points '
      'match the reference\'s triangle stream, in order', () {
    // Plan D's own corpus, walked at the record level exactly the way
    // `differentialFixture` is above: `_checkAgainstOracle` already handles
    // `PolylineOp` and `CircleOp` generically (900, 903 are plain 2-point
    // lines; 902 and 905, the two regions' own boundaries, are ordinary
    // visible entities too -- `AddRegionCommand.apply` adds fill AND
    // boundary to the tree, "fill first" -- so their outline strokes and
    // joins are already covered by the existing PolylineOp/CircleOp
    // handling below). What is new here is `FillPolygonOp` (901) and
    // `FillCircleOp` (904), which this file had no case for until Plan D.
    //
    // **This is also where a fill's colour is checked, not only in
    // `resident_pixel_differential_test.dart`'s pixel gate.** The pixel
    // gate can only report a percentage; this loop names the wrong VALUE --
    // a mutant that routed a fill's argb through `_coveredArgb` would fail
    // here with the exact faded channel it produced, not just a coverage
    // fraction.
    _checkAgainstOracle(fillFixture());
  });
}

/// Runs [doc] through the painter twice -- once recorded, once collected --
/// and checks every instance the collector wrote against the oracle built
/// declaratively from the recording. Shared by both tests in this file, so
/// the hairline fixture exercises the same oracle the main corpus does
/// rather than a second, possibly-diverging copy of it.
void _checkAgainstOracle(DraftDocument doc) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);

  final resolver = DocumentStyleResolver(doc);
  final camera = ViewportTransform.fit(doc.extents, kViewport);
  final painter = DraftPainter(document: doc, index: index, resolver: resolver);

  // The reference: what the painter emits, recorded.
  final recording = RecordingDrawSink();
  painter.paint(recording, camera, kViewport);

  // The arm: what the collector writes, from the same painter replaying
  // the same camera over the same document.
  final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: _devicePixelRatio);
  painter.paint(collector, camera, kViewport);

  // Rebuild the expected segment list from the recording, applying the
  // residual exactly as the collector must, and keeping each segment's
  // style alongside it so the half-width and colour checks below are
  // per-segment.
  // **What this residual actually is, in the real walk.** Every
  // `beginResidual` a `PolylineOp` sees here carries a *pure translation*:
  // `DraftPainter._emitScreenSpace` folds the full affine chain into the
  // points themselves and leaves only the screen-origin rebase as the
  // residual (`draft_painter.dart`, and its own comment that the general
  // `_emit` polyline path is dead). So this loop's generic
  // `a/b/c/d/e/f` application is honest, but a mutation that swaps the
  // residual's off-diagonal terms (b <-> c) cannot be observed through
  // *this* walk's POLYLINE ops -- their b and c are always 0, by
  // construction, on every fixture. That mutation was covered instead by
  // `geometry_collector_test.dart`'s "applies the residual, and a
  // transposed one is not the same residual", which drives
  // `GeometryCollector.polyline` directly with a genuine off-diagonal
  // residual.
  //
  // **That stopped being the whole story in Task 5.** Circle 701 and arc
  // 703 reach the collector through `draft_painter.dart:568`'s general
  // chain rather than through `_emitScreenSpace`, so they arrive under
  // genuinely non-zero off-diagonal terms and a non-uniform scale -- the
  // fixture's rotations at `fixtures.dart:88-96` and its two placements of
  // `outer`. This gate covers the general-affine residual path from Task 5
  // on, which is the path Plan A's transposition fix was written to guard
  // and no Plan A fixture could reach.
  // The expected instance list, generated declaratively from each
  // `PolylineOp`'s deduped point list by `_expectedInstancesFor` -- not by
  // replaying `GeometryCollector`'s own `_beginRun` / `_runTo` / `_endRun`
  // state machine a second time. A rebuild that re-typed that state
  // machine would share every misreading of it with the code under test;
  // this rebuild instead reads the reference's own *documented* ordering
  // rule (`vertices_draw_sink.dart`'s doc comments on `_runTo` and
  // `_endRun`) straight off the point list, with no run-state bookkeeping
  // of its own to get wrong the same way twice.
  final expected = <_ExpectedInstance>[];
  Transform2 residual = Transform2.identity();
  for (final op in recording.ops) {
    if (op is BeginResidualOp) residual = op.residual;
    if (op is PolylineOp) {
      // `PolylineOp.points` is already trimmed to the drawn point count
      // (`draw_sink.dart`'s own doc comment) -- there is no separate
      // `count` field on the op, unlike the brief's sample code assumed.
      final pts = op.points;
      _expectedInstancesFor(
          pts, pts.length ~/ 2, op.closed, op.style, residual, expected);
    }
    // A circle and an arc reach the collector as a flattened run, so the
    // oracle flattens them too -- from the REFERENCE's formula
    // (`_flattenedLocalPoints` below), never from
    // `GeometryCollector._flatten` -- and then hands the resulting point
    // list to the same declarative rule the polylines use. A circle is
    // `closed`, so it is where the rule's seam limb finally comes under
    // this gate at all: the fixture carries no closed polyline, so before
    // Task 5 that limb was exercised only by unit tests.
    if (op is CircleOp) {
      final pts = _flattenedLocalPoints(
          op.cx, op.cy, op.r, 0, 2 * math.pi, residual,
          closed: true);
      _expectedInstancesFor(
          pts, pts.length ~/ 2, true, op.style, residual, expected);
    }
    if (op is ArcOp) {
      final pts = _flattenedLocalPoints(
          op.cx, op.cy, op.r, op.start, op.sweep, residual,
          closed: false);
      _expectedInstancesFor(
          pts, pts.length ~/ 2, false, op.style, residual, expected);
    }
    // A point is one instance, not a run -- no dedupe, no join, no seam.
    // Its position is the residual applied to the op's own (already
    // screen-rebased) coordinates, exactly as every other op's is above.
    if (op is PointOp) {
      expected.add(_ExpectedInstance.point(
          op.style,
          residual.a * op.x + residual.c * op.y + residual.e,
          residual.b * op.x + residual.d * op.y + residual.f));
    }
    // A polygon fill: `triangles` triple-indexes `op.points`' own point
    // numbering (`draw_sink.dart`'s doc on `FillPolygonOp`, and
    // `VerticesDrawSink.fillPolygon`, which this expression mirrors), so
    // each index is doubled to reach the coordinate pair before the
    // residual is applied. One expected instance per triangle -- no
    // dedupe, no join, no seam: a fill triangle is not a run.
    if (op is FillPolygonOp) {
      final pts = op.points;
      final tris = op.triangles;
      for (var t = 0; t + 2 < tris.length; t += 3) {
        final a = tris[t], b = tris[t + 1], c = tris[t + 2];
        final ax = pts[a * 2], ay = pts[a * 2 + 1];
        final bx = pts[b * 2], by = pts[b * 2 + 1];
        final cx = pts[c * 2], cy = pts[c * 2 + 1];
        expected.add(_ExpectedInstance.fill(
            op.style,
            residual.a * ax + residual.c * ay + residual.e,
            residual.b * ax + residual.d * ay + residual.f,
            residual.a * bx + residual.c * by + residual.e,
            residual.b * bx + residual.d * by + residual.f,
            residual.a * cx + residual.c * cy + residual.e,
            residual.b * cx + residual.d * cy + residual.f));
      }
    }
    // A circle fill: a triangle fan around the centre, at the SAME step
    // count the circle's own outline stroke would flatten to
    // (`geometry_collector.dart`'s `fillCircle` doc, Ruling D5) -- so this
    // reuses `_flattenedLocalPoints`, the same perimeter-point deriver the
    // CircleOp case above already uses for a stroked circle, rather than a
    // third copy of the step-count formula. The rim starts at angle 0, i.e.
    // `(cx + r, cy)`, and each fan triangle is `(centre, previous rim point,
    // next rim point)` -- `VerticesDrawSink.fillCircle`'s own order,
    // transcribed by `GeometryCollector.fillCircle` too.
    if (op is FillCircleOp) {
      final rim = _flattenedLocalPoints(
          op.cx, op.cy, op.r, 0, 2 * math.pi, residual,
          closed: false);
      final rimCount = rim.length ~/ 2;
      if (rimCount >= 2) {
        final ccx = residual.a * op.cx + residual.c * op.cy + residual.e;
        final ccy = residual.b * op.cx + residual.d * op.cy + residual.f;
        for (var i = 1; i < rimCount; i++) {
          final px = rim[(i - 1) * 2], py = rim[(i - 1) * 2 + 1];
          final nx = rim[i * 2], ny = rim[i * 2 + 1];
          expected.add(_ExpectedInstance.fill(
              op.style,
              ccx,
              ccy,
              residual.a * px + residual.c * py + residual.e,
              residual.b * px + residual.d * py + residual.f,
              residual.a * nx + residual.c * ny + residual.e,
              residual.b * nx + residual.d * ny + residual.f));
        }
      }
    }
  }

  expect(expected, isNotEmpty,
      reason: 'a fixture with no drawable geometry would make this test '
          'vacuous -- polylines, circles and arcs all feed this list');
  expect(collector.instanceCount, expected.length,
      reason: 'the collector must emit exactly one instance per segment '
          'and per join the declarative rule produces -- neither '
          'dropping nor duplicating one');

  // Captured once: `collector.data` copies `_buffer` on every access, so
  // the comparison loop below reads a single snapshot rather than a fresh
  // sublist per index.
  final data = collector.data;

  for (var i = 0; i < expected.length; i++) {
    final o = i * kFloatsPerInstance;
    final e = expected[i];
    final style = e.style;

    // -- kind: a stroke, a join, a point and a fill lay their geometry out
    // differently (`InstanceFieldOffset` doc), so asserting only the
    // strokes' kind would pass on a join or point emitted as a stroke with
    // the wrong fields simply never being checked. Every instance's kind
    // is asserted here, strokes, joins, points and fills alike.
    expect(data[o + InstanceFieldOffset.kind], e.kind,
        reason: 'instance $i must be a '
            '${e.kind == kKindJoin ? "join" : e.kind == kKindPoint ? "point" : e.kind == kKindFill ? "fill" : "stroke"}');

    // -- walk order & the residual -----------------------------------
    // A stroke's (x0,y0,x1,y1) is its segment; a join's is
    // (vertex, previous point) and (x2,y2) is its next point. A stroke's
    // own (x2,y2) is asserted too (against 0,0, `writeStroke`'s own
    // constant) rather than left unchecked, so a join emitted where a
    // stroke was expected -- carrying a non-zero neighbour in x2/y2 --
    // fails here instead of only on the kind check above.
    expect(data[o + InstanceFieldOffset.x0], closeTo(e.x0, _tolerance),
        reason: 'instance $i x0');
    expect(data[o + InstanceFieldOffset.y0], closeTo(e.y0, _tolerance),
        reason: 'instance $i y0');
    expect(data[o + InstanceFieldOffset.x1], closeTo(e.x1, _tolerance),
        reason: 'instance $i x1');
    expect(data[o + InstanceFieldOffset.y1], closeTo(e.y1, _tolerance),
        reason: 'instance $i y1');
    expect(data[o + InstanceFieldOffset.x2], closeTo(e.x2, _tolerance),
        reason: 'instance $i x2');
    expect(data[o + InstanceFieldOffset.y2], closeTo(e.y2, _tolerance),
        reason: 'instance $i y2');

    // -- half-width: the collector stores DEVICE pixels, the reference
    // sink's own formula (`VerticesDrawSink._halfWidthFor`) stores LOGICAL
    // pixels. They must differ by exactly `devicePixelRatio` -- this is
    // not a bug being tolerated, it is the fact this test pins (see the
    // module doc on `GeometryCollector._halfWidthFor`). A join carries the
    // same half-width as the segments either side of it.
    //
    // **A fill has no width at all** (`instance_record.dart`'s `writeFill`
    // doc, Ruling D2) -- `writeFill` writes a literal `0`, not a lineweight
    // computation that happens to floor to zero, so the general formula
    // below is not merely inapplicable to a fill, it would assert the WRONG
    // thing: `style.argb`'s lineweight is real (fill 901 sits on the
    // hairline layer) and `_referenceLogicalHalfWidth` would compute a
    // non-zero floored value for it, which no fill instance ever carries.
    if (e.kind == kKindFill) {
      expect(data[o + InstanceFieldOffset.halfWidth], closeTo(0, _tolerance),
          reason: 'instance $i is a fill and must carry no half-width at '
              'all, not a floored stroke-width computation');
    } else {
      final sinkHalf = _referenceLogicalHalfWidth(style.lineweightHundredths);
      expect(data[o + InstanceFieldOffset.halfWidth],
          closeTo(sinkHalf * _devicePixelRatio, _tolerance),
          reason: 'instance $i half-width must be the reference sink\'s '
              'logical half-width scaled by devicePixelRatio, not the raw '
              'logical value copied straight across');
    }

    // -- colour: every entity in `differentialFixture` carries the
    // default lineweight (25 hundredths-of-a-mm), which at
    // `kLogicalPixelsPerMm` and dpr 2 computes to a device width above
    // `VerticesDrawSink.kMinStrokeDevicePixels` -- so `_coveredArgb` is a
    // no-op on every one of those segments and this line changes nothing
    // for them. It is still routed through the reference's own fade
    // formula rather than left as `style.argb`, because Plan B's hairline
    // corpus (`_hairlineFixture`, below) needs exactly this comparison to
    // be live: a hairline's alpha now differs from its `style.argb`, and a
    // collector that forgot to fade it, or faded it by the wrong formula,
    // must fail this loop rather than being invisible to it.
    //
    // **A fill's colour is `style.argb` directly, never `_coveredArgb`'s**
    // (Ruling D3, `geometry_collector.dart:637-639`): a fill has no width
    // to fade, and both `fillPolygon` and `fillCircle` pass `style.argb`
    // straight through in the reference too
    // (`vertices_draw_sink.dart:750-755`). Fill 901 sits on the "hairline"
    // layer -- lineweight 1 hundredth-of-a-mm -- specifically so this branch
    // is not vacuous: routing it through `_referenceCoveredArgb` the way the
    // `else` below does would compute a REAL fade (well under
    // `kMinStrokeDevicePixels`), so a collector that mistakenly faded a fill
    // disagrees with a genuinely different number here, not a coincidence
    // that happens to equal `style.argb` anyway.
    final argb = e.kind == kKindFill
        ? style.argb
        : _referenceCoveredArgb(style.argb, style.lineweightHundredths);
    expect(data[o + InstanceFieldOffset.r],
        closeTo(((argb >> 16) & 0xFF) / 255.0, _tolerance),
        reason: 'instance $i red channel');
    expect(data[o + InstanceFieldOffset.g],
        closeTo(((argb >> 8) & 0xFF) / 255.0, _tolerance),
        reason: 'instance $i green channel');
    expect(data[o + InstanceFieldOffset.b],
        closeTo((argb & 0xFF) / 255.0, _tolerance),
        reason: 'instance $i blue channel');
    expect(data[o + InstanceFieldOffset.a],
        closeTo(((argb >> 24) & 0xFF) / 255.0, _tolerance),
        reason: 'instance $i alpha channel');
  }
}

/// One instance the oracle predicts, tagged with the [ResolvedStyle] it
/// came from so the half-width and colour checks above can be per-instance.
///
/// Mirrors the two record shapes `GeometryCollector` actually writes: a
/// stroke's `(x2, y2)` is always `(0, 0)` -- `writeStroke` writes `0` to both
/// explicitly (`instance_record.dart:110-111`), it does not merely leave
/// them unset -- and a join's `(x0, y0)` is the corner, `(x1, y1)` the
/// previous point and `(x2, y2)` the next one (`writeJoin`'s doc).
class _ExpectedInstance {
  _ExpectedInstance.stroke(this.style, this.x0, this.y0, this.x1, this.y1)
      : kind = kKindStroke,
        x2 = 0,
        y2 = 0;

  _ExpectedInstance.join(this.style, double vx, double vy, double prevX,
      double prevY, double nextX, double nextY)
      : kind = kKindJoin,
        x0 = vx,
        y0 = vy,
        x1 = prevX,
        y1 = prevY,
        x2 = nextX,
        y2 = nextY;

  // `writePoint` zeroes all four of x1/y1/x2/y2 -- see `instance_record.dart`
  // -- so the expected entry matches, the same way a stroke's own x2/y2 are
  // pinned to 0 above rather than left unchecked.
  _ExpectedInstance.point(this.style, this.x0, this.y0)
      : kind = kKindPoint,
        x1 = 0,
        y1 = 0,
        x2 = 0,
        y2 = 0;

  // A fill triangle's three corners occupy all six coordinate slots --
  // `writeFill` writes every one of x0/y0/x1/y1/x2/y2 (`instance_record.dart`
  // -- unlike a stroke or a point, nothing here is pinned to zero.
  _ExpectedInstance.fill(
      this.style, this.x0, this.y0, this.x1, this.y1, this.x2, this.y2)
      : kind = kKindFill;

  final double kind;
  final double x0, y0, x1, y1, x2, y2;
  final ResolvedStyle style;
}

/// The point list a circle or arc flattens to, in the residual's **local**
/// space — the space `_expectedInstancesFor` expects, since it applies the
/// residual itself.
///
/// **Derived from the reference, not from the collector.** Every constant
/// here is read live off `VerticesDrawSink` (`kFlattenTolerance`,
/// `kMaxFlattenSegments`, both public), and the step count is the
/// reference's own expression from `_flattenSteps`. `GeometryCollector`
/// keeps its *own* copies of those two constants deliberately — two
/// independent implementations that agree are a differential test, one
/// shared field is not — so reading the reference's here is what makes the
/// comparison mean something. Raise either arm's constant out of step with
/// the other and this test goes red, which is the intended alarm.
///
/// Three properties reproduced from `_flatten`'s own doc, each because
/// getting it wrong is a defect this gate exists to catch:
///  - the walk is in **local** space, because a non-uniform residual turns
///    the circle into an ellipse and flattening a transformed circle would
///    not reproduce it;
///  - only the **count** is a scale decision, so the radius that sets it is
///    the on-screen one, `r * residual.scaleMagnitude`;
///  - a closed sweep stops **one sample short**, because its last chord is
///    the segment `_endRun` draws back to the first point — sampling it here
///    would draw that chord twice and leave the seam a duplicated point
///    instead of a join.
List<double> _flattenedLocalPoints(double cx, double cy, double r, double start,
    double sweep, Transform2 residual,
    {required bool closed}) {
  if (r <= 0 || sweep == 0) return const <double>[];
  final deviceRadius = r * residual.scaleMagnitude;
  if (deviceRadius <= 0) return const <double>[];

  final theta = sweep.abs();
  final steps = (theta *
          math.sqrt(deviceRadius / (8 * VerticesDrawSink.kFlattenTolerance)))
      .ceil()
      .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
  final step = sweep / steps;
  final last = closed ? steps - 1 : steps;

  final out = <double>[];
  for (var i = 0; i <= last; i++) {
    final angle = start + step * i;
    out.add(cx + r * math.cos(angle));
    out.add(cy + r * math.sin(angle));
  }
  return out;
}

/// The reference's own zero-length predicate (`vertices_draw_sink.dart`,
/// `_runTo`): a displacement whose square root is zero, not coordinate
/// equality -- see `geometry_collector.dart`'s `_runTo` doc on why the two
/// are not the same predicate near the underflow boundary.
bool _coincide(double x0, double y0, double x1, double y1) {
  final dx = x1 - x0, dy = y1 - y0;
  return math.sqrt(dx * dx + dy * dy) == 0;
}

/// Generates the instances one `PolylineOp` must produce, appending them to
/// [out] -- **declaratively**, off a deduped point list, with no run state
/// of its own to mis-thread the way a second implementation of
/// `GeometryCollector`'s own `_beginRun` / `_runTo` / `_endRun` state
/// machine could. That would still not be a call into the code under test,
/// but it would be a transcription of it: the same private field names
/// minus the underscore, the same statement order, the same zero-length
/// guard copied verbatim -- close enough to share a misreading of the
/// reference with the collector, which is exactly what an oracle exists to
/// catch. This function is derived instead from the reference's own
/// *documented* rule (`vertices_draw_sink.dart`'s doc comments on `_runTo`
/// -- "the join comes before the segment" -- and `_endRun` -- "the corner no
/// vertex list contains"), read directly off the point list rather than
/// replayed as a walk.
///
/// [points] is [residual]-applied and deduped first: consecutive points
/// closer together than the reference's own zero-length test collapse to
/// one, and for a closed run a trailing point that coincides with the first
/// is dropped too -- the reference's own closing step (`_endRun`'s call into
/// `_runTo`) is a no-op on exactly that shape, so it contributes neither a
/// stroke nor a join of its own, only the seam. What survives, `p[0..n-1]`,
/// is then read straight down:
///   - a stroke `(p[i], p[i+1])` for every `i` in `0..n-2`;
///   - a join at `p[i]` carrying `(p[i-1], p[i+1])` for every interior `i`
///     in `1..n-2`, each one written before the stroke leaving it
///     (`S₀, J₁, S₁, J₂, S₂, …`);
///   - closed and `n >= 3` only: the same ordinary join at `p[n-1]` --
///     `_endRun`'s closing step is just another `_runTo`, and every
///     `_runTo` writes its join before its segment, the last point included
///     -- then the closing stroke `(p[n-1], p[0])`, then the seam join at
///     `p[0]` carrying `(p[n-1], p[1])`, the corner the point list never
///     names on its own.
void _expectedInstancesFor(List<double> rawPoints, int rawCount, bool closed,
    ResolvedStyle style, Transform2 residual, List<_ExpectedInstance> out) {
  if (rawCount < 2) return;
  final t = residual;

  // 1. Transform every point by the residual.
  final xs = List<double>.generate(rawCount,
      (i) => t.a * rawPoints[i * 2] + t.c * rawPoints[i * 2 + 1] + t.e);
  final ys = List<double>.generate(rawCount,
      (i) => t.b * rawPoints[i * 2] + t.d * rawPoints[i * 2 + 1] + t.f);

  // 2. Dedupe consecutive points against the previous KEPT point.
  final px = <double>[xs[0]];
  final py = <double>[ys[0]];
  for (var i = 1; i < rawCount; i++) {
    if (_coincide(px.last, py.last, xs[i], ys[i])) continue;
    px.add(xs[i]);
    py.add(ys[i]);
  }
  // For a closed run, drop a trailing point that coincides with the first.
  if (closed &&
      px.length > 1 &&
      _coincide(px.first, py.first, px.last, py.last)) {
    px.removeLast();
    py.removeLast();
  }

  final n = px.length;
  if (n < 2) return;

  // 3. Generate the instance list declaratively from p[0..n-1].
  for (var i = 0; i < n - 1; i++) {
    if (i >= 1) {
      out.add(_ExpectedInstance.join(
          style, px[i], py[i], px[i - 1], py[i - 1], px[i + 1], py[i + 1]));
    }
    out.add(
        _ExpectedInstance.stroke(style, px[i], py[i], px[i + 1], py[i + 1]));
  }
  if (closed && n >= 3) {
    out.add(_ExpectedInstance.join(
        style, px[n - 1], py[n - 1], px[n - 2], py[n - 2], px[0], py[0]));
    out.add(
        _ExpectedInstance.stroke(style, px[n - 1], py[n - 1], px[0], py[0]));
    out.add(_ExpectedInstance.join(
        style, px[0], py[0], px[n - 1], py[n - 1], px[1], py[1]));
  }
}

/// `VerticesDrawSink._halfWidthFor`, reproduced here because that method is
/// private to its own file. Computes the half-width **in logical pixels** --
/// the reference sink's own space, per its `floorLogical` naming
/// (`vertices_draw_sink.dart:544-552`) -- so the test above can assert the
/// `x devicePixelRatio` relationship explicitly instead of checking the
/// collector against a copy of its own formula.
double _referenceLogicalHalfWidth(int lineweightHundredths) {
  const pixelsPerPaperMm = kLogicalPixelsPerMm;
  // The reference sink's own floor, not a third copy of it: the collector's
  // module doc (`geometry_collector.dart:31-35`) claims raising either
  // constant out of step with the other turns this test red, and that claim
  // is only true if this side reads the sink's live constant rather than
  // hardcoding its current value.
  final logical = lineweightHundredths / 100.0 * pixelsPerPaperMm;
  final floorLogical =
      VerticesDrawSink.kMinStrokeDevicePixels / _devicePixelRatio;
  final w = logical.isFinite && logical > floorLogical ? logical : floorLogical;
  return w / 2;
}

/// `VerticesDrawSink._coveredArgb`, reproduced here for the same reason
/// [_referenceLogicalHalfWidth] is: that method is private to its own file,
/// and reading a live copy of `kMinStrokeDevicePixels` off the public
/// constant keeps this a second, independent formula rather than a value
/// shared with the code under test.
///
/// **`lineweightScale` is a factor here, mirroring
/// `VerticesDrawSink._coveredArgb`'s own `lineweightScale *` term.** Every
/// call site in this file passes the default of `1.0`, at which the factor
/// is the identity and every existing assertion is unchanged -- the sole
/// caller that exercises a non-default value is the
/// `lineweightScale != 1` fade test above, added specifically because a
/// default-only oracle can never disagree with a collector that dropped
/// this factor entirely.
///
/// **Only the guard is read live; the `* 2` slope below is not.** Unlike
/// [_referenceLogicalHalfWidth], which reads `kMinStrokeDevicePixels` in
/// both the guard and the value it floors to, this function's fade slope
/// (`deviceWidth * 2`, mirroring the reference's own
/// `Geometry::ComputeStrokeAlphaCoverage`) is not derived from that
/// constant at all -- it happens to equal `2 / kMinStrokeDevicePixels`
/// today only because the floor is `1.0`. Raising
/// `VerticesDrawSink.kMinStrokeDevicePixels` would move the guard here
/// (correctly, since it is read live) but would leave the slope at a stale
/// `* 2`, silently wrong rather than caught by this test the way a floor
/// change is.
int _referenceCoveredArgb(int argb, int lineweightHundredths,
    {double lineweightScale = 1.0}) {
  final deviceWidth = lineweightHundredths /
      100.0 *
      kLogicalPixelsPerMm *
      lineweightScale *
      _devicePixelRatio;
  if (!deviceWidth.isFinite ||
      deviceWidth <= 0 ||
      deviceWidth >= VerticesDrawSink.kMinStrokeDevicePixels) {
    return argb;
  }
  final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
  final alpha = (((argb >> 24) & 0xFF) * coverage).round();
  return (alpha << 24) | (argb & 0x00FFFFFF);
}

/// A single hairline entity, isolated from `differentialFixture` so this
/// file's colour comparison can exercise `_coveredArgb`'s fade without
/// disturbing the six other suites that share the standing corpus.
///
/// Wrapped in a rotated, non-uniformly scaled group -- not dropped straight
/// on the root -- so this fixture does not become the identity-transform
/// degenerate case `assertNoIdentityTransforms` exists to rule out
/// elsewhere in this file: a hairline drawn at the identity would still
/// exercise the fade, but it would do so without the residual this file's
/// other oracle checks (x0/y0/.../y2, half-width) also depend on being
/// non-trivial.
///
/// Lineweight 5 (0.05 mm) is chosen deliberately, not the smallest value
/// available: at `kLogicalPixelsPerMm` and dpr 2 it computes to a device
/// width of about 0.38 px, which fades to roughly 76% alpha -- a mid-range
/// value neither 0 nor 255, so a fade formula that is merely *present* but
/// computed wrong (an off-by-a-factor, a missed `x2`) still shows as a wrong
/// number rather than agreeing by coincidence at a boundary.
DraftDocument _hairlineFixture() {
  final doc = DraftDocument.empty();
  final group = addGroup(
      doc,
      doc.rootHandle,
      const Handle(900),
      Transform2.translation(37, -14)
          .multiply(Transform2.rotation(0.83))
          .multiply(Transform2.scale(1.7, 0.6)));
  addEntity(
      doc, group, const Handle(901), EntityKind.line, [0, 0, 6, 3], const [],
      lineweight: 5);
  return doc;
}
