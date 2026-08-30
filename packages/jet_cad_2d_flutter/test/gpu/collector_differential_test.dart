import 'dart:math' as math;

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
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final resolver = DocumentStyleResolver(doc);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final painter =
        DraftPainter(document: doc, index: index, resolver: resolver);

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
    // *this* walk -- b and c are always 0 here, by construction, on every
    // fixture. That mutation is covered instead by
    // `geometry_collector_test.dart`'s "applies the residual, and a
    // transposed one is not the same residual", which drives
    // `GeometryCollector.polyline` directly with a genuine off-diagonal
    // residual. See Task 8's report for the transcript proving that.
    // The expected instance list, rebuilt by mirroring
    // `GeometryCollector`'s run state machine (`_beginRun` / `_runTo` /
    // `_endRun`) over each `PolylineOp` -- not just its raw segment list.
    // Once the collector emits a join instance at every interior vertex
    // (Task 4), a per-segment rebuild undercounts on every polyline with
    // more than two points, so the oracle has to run the same state machine
    // the collector runs, not merely walk the same points.
    final expected = <_ExpectedInstance>[];
    Transform2 residual = Transform2.identity();
    for (final op in recording.ops) {
      if (op is BeginResidualOp) residual = op.residual;
      if (op is PolylineOp) {
        // `PolylineOp.points` is already trimmed to the drawn point count
        // (`draw_sink.dart`'s own doc comment) -- there is no separate
        // `count` field on the op, unlike the brief's sample code assumed.
        final pts = op.points;
        _mirrorPolylineRun(
            pts, pts.length ~/ 2, op.closed, op.style, residual, expected);
      }
    }

    expect(expected, isNotEmpty,
        reason: 'a fixture with no polylines would make this test vacuous');
    expect(collector.instanceCount, expected.length,
        reason: 'the collector must emit exactly one instance per segment '
            'and per join the run state machine produces -- neither '
            'dropping nor duplicating one');

    // Captured once: `collector.data` copies `_buffer` on every access, so
    // the comparison loop below reads a single snapshot rather than a fresh
    // sublist per index.
    final data = collector.data;

    for (var i = 0; i < expected.length; i++) {
      final o = i * kFloatsPerInstance;
      final e = expected[i];
      final style = e.style;

      // -- kind: a stroke and a join lay their geometry out differently
      // (`InstanceFieldOffset` doc), so asserting only the strokes' kind
      // would pass on a join emitted as a stroke with the wrong fields
      // simply never being checked. Every instance's kind is asserted here,
      // strokes and joins alike.
      expect(data[o + InstanceFieldOffset.kind], e.kind,
          reason: 'instance $i must be a '
              '${e.kind == kKindJoin ? "join" : "stroke"}');

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
      final sinkHalf = _referenceLogicalHalfWidth(style.lineweightHundredths);
      expect(data[o + InstanceFieldOffset.halfWidth],
          closeTo(sinkHalf * _devicePixelRatio, _tolerance),
          reason: 'instance $i half-width must be the reference sink\'s '
              'logical half-width scaled by devicePixelRatio, not the raw '
              'logical value copied straight across');

      // -- colour: every entity in `differentialFixture` carries the
      // default lineweight (25 hundredths-of-a-mm), which at
      // `kLogicalPixelsPerMm` and dpr 2 computes to a device width above
      // `VerticesDrawSink.kMinStrokeDevicePixels` -- so `_coveredArgb` is a
      // no-op on every one of these segments and the reference colour is
      // `style.argb` unmodified. That is why this fixture's colour
      // comparison is meaningful without the collector implementing
      // `_coveredArgb` itself: hairline fading is Plan B's job
      // (`geometry_collector.dart`'s module doc), and folding it in here
      // would smuggle that work into the wrong layer just to pass a test.
      final argb = style.argb;
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
  });
}

/// One instance the oracle predicts, tagged with the [ResolvedStyle] it
/// came from so the half-width and colour checks above can be per-instance.
///
/// Mirrors the two record shapes `GeometryCollector` actually writes: a
/// stroke's `(x2, y2)` is always `(0, 0)` (`writeStroke` never touches those
/// slots) and a join's `(x0, y0)` is the corner, `(x1, y1)` the previous
/// point and `(x2, y2)` the next one (`writeJoin`'s doc).
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

  final double kind;
  final double x0, y0, x1, y1, x2, y2;
  final ResolvedStyle style;
}

/// Mirrors `GeometryCollector`'s run state machine (`_beginRun` / `_runTo` /
/// `_endRun`, `geometry_collector.dart`) over one `PolylineOp`'s points,
/// after [residual] is applied, appending the instances the collector must
/// emit for it to [out]: a join **before** every interior segment, and on a
/// closed run the closing segment then the seam join, last.
///
/// A second, independent implementation of that state machine rather than a
/// call into the collector's own -- an oracle that invoked the code under
/// test to build its own expectation could not catch a defect in that code.
void _mirrorPolylineRun(List<double> points, int count, bool closed,
    ResolvedStyle style, Transform2 residual, List<_ExpectedInstance> out) {
  if (count < 2) return;
  final t = residual;
  double px(int i) => t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e;
  double py(int i) => t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f;

  double runFirstX = 0, runFirstY = 0, runSecondX = 0, runSecondY = 0;
  double runPrevX = 0, runPrevY = 0, runBackX = 0, runBackY = 0;
  var runHasDirection = false;
  var runSegments = 0;

  void emitSeg(double x0, double y0, double x1, double y1) {
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    out.add(_ExpectedInstance.stroke(style, x0, y0, x1, y1));
  }

  void emitJoin(double vx, double vy, double prevX, double prevY, double nextX,
      double nextY) {
    out.add(_ExpectedInstance.join(style, vx, vy, prevX, prevY, nextX, nextY));
  }

  void beginRun(double x, double y) {
    runFirstX = x;
    runFirstY = y;
    runSecondX = x;
    runSecondY = y;
    runPrevX = x;
    runPrevY = y;
    runBackX = x;
    runBackY = y;
    runHasDirection = false;
    runSegments = 0;
  }

  void runTo(double x, double y) {
    final dx = x - runPrevX, dy = y - runPrevY;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    if (runHasDirection) {
      emitJoin(runPrevX, runPrevY, runBackX, runBackY, x, y);
    } else {
      runSecondX = x;
      runSecondY = y;
    }
    emitSeg(runPrevX, runPrevY, x, y);
    runBackX = runPrevX;
    runBackY = runPrevY;
    runPrevX = x;
    runPrevY = y;
    runHasDirection = true;
    runSegments++;
  }

  beginRun(px(0), py(0));
  for (var i = 1; i < count; i++) {
    runTo(px(i), py(i));
  }
  if (closed && runHasDirection) {
    runTo(runFirstX, runFirstY);
    if (runSegments >= 2) {
      emitJoin(
          runFirstX, runFirstY, runBackX, runBackY, runSecondX, runSecondY);
    }
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
