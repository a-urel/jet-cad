import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

const double _dpr = 2.0;
const double _ppmm = 3.78;

/// Float32 rounding, and nothing looser. The collector stores `float32`
/// (about 1.2e-7 relative) while this oracle works in `double`; the largest
/// coordinate this fixture reaches is a few thousand collection units, so
/// rounding alone is on the order of 1e-3. Every defect these tests aim at
/// moves a value by whole units or flips a sign.
const double _eps = 1e-2;

/// One instance the collector must have written.
///
/// Carries only what the **dash rule** determines -- the kind, the two
/// endpoints and the dash quad. Half-width and colour are deliberately not
/// compared here: they are `_halfWidthFor` and `_coveredArgb`'s business,
/// gated by `geometry_collector_test.dart` and by the record assertions in
/// `collector_differential_test.dart`, and folding them in would make a
/// failure of this oracle ambiguous about which rule broke.
class _Expected {
  const _Expected({
    required this.kind,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.period,
    required this.phase,
    required this.fracStart,
    required this.fracEnd,
    required this.why,
  });

  final double kind, x0, y0, x1, y1, period, phase, fracStart, fracEnd;

  /// What rule produced this instance, quoted into the failure message so a
  /// red run names the rule rather than an index.
  final String why;

  @override
  String toString() => '$why -> kind $kind ($x0, $y0)-($x1, $y1) '
      'period $period phase $phase frac [$fracStart, $fracEnd)';
}

/// What the collector must have written, derived from the painter's op
/// stream and the pattern -- **never from the collector**.
///
/// **No bookkeeping, and that is the point.** There is no run state machine
/// here, no `hasDirection` flag and no "previous point" variable: each
/// polyline op is transformed, its zero-length steps dropped, and the answer
/// read straight off the surviving indices. Plan B shipped an oracle whose
/// locals were the collector's own private field names minus the underscore
/// -- it agreed with the implementation because it *was* the implementation,
/// and could not have caught a state-machine defect in the thing it checked.
/// This one cannot share such a defect, because it has no state machine to
/// share.
///
/// The rule, for a dashed open polyline of `n` surviving points and a pattern
/// with `D` drawn elements:
///
///     for i in 0 .. n-2:  for k in 0 .. D-1:  Stroke(p[i], p[i+1], k)
///
/// with **no joins at all** (Ruling C3 -- the reference gives every span its
/// own two-point `polyline` op, so a dashed polyline has no join geometry
/// anywhere), every phase 0 (`dasher.dart:94-96` -- the pattern restarts at
/// each vertex), and element `k`'s extent taken from the cumulative sums of
/// `|dashes|`.
List<_Expected> _expectedDashInstances(List<DrawOp> ops) {
  final out = <_Expected>[];
  var residual = Transform2.identity();
  DashPattern? pattern;
  var patternToLocal = 0.0;

  for (final op in ops) {
    if (op is BeginResidualOp) {
      residual = op.residual;
    } else if (op is BeginDashOp) {
      pattern = op.pattern;
      patternToLocal = op.patternToLocal;
    } else if (op is EndDashOp) {
      pattern = null;
    } else if (op is PolylineOp) {
      out.addAll(_expectPolyline(op, residual, pattern, patternToLocal));
    } else if (op is CircleOp || op is ArcOp) {
      throw StateError(
          'this oracle covers polyline ops only -- the document under test '
          'must have its curve entities removed, because reproducing the '
          'flattener here would be transcription rather than an independent '
          'derivation. See the test that removes handles 911 and 912.');
    }
  }
  return out;
}

List<_Expected> _expectPolyline(
    PolylineOp op, Transform2 t, DashPattern? pattern, double patternToLocal) {
  // Transform into collection space and drop the steps the collector drops.
  // The predicate is the reference's own -- `sqrt(dx*dx + dy*dy) == 0`, not
  // `x == prevX && y == prevY`: near the underflow boundary `dx * dx` rounds
  // to zero while `dx` does not, and the two predicates then disagree.
  final cx = <double>[], cy = <double>[], lx = <double>[], ly = <double>[];
  for (var i = 0; i * 2 + 1 < op.points.length; i++) {
    final px = op.points[i * 2], py = op.points[i * 2 + 1];
    final qx = t.a * px + t.c * py + t.e;
    final qy = t.b * px + t.d * py + t.f;
    if (cx.isNotEmpty) {
      final dx = qx - cx.last, dy = qy - cy.last;
      if (math.sqrt(dx * dx + dy * dy) == 0) continue;
    }
    cx.add(qx);
    cy.add(qy);
    lx.add(px);
    ly.add(py);
  }
  final n = cx.length;
  if (n < 2) return const <_Expected>[];

  // The cycle is summed from the array, never read from `totalLength`:
  // nothing enforces that the declared total agrees with the entries that
  // produced it (`dasher.dart` says so twice), and `shadedDashFixture`'s
  // handle 903 exists to make the two disagree.
  var cycle = 0.0;
  final fracStart = <double>[], fracEnd = <double>[];
  if (pattern != null) {
    for (final d in pattern.dashes) {
      cycle += d.abs();
    }
    if (cycle.isFinite && cycle > 0) {
      var at = 0.0;
      for (final d in pattern.dashes) {
        final w = d.abs();
        if (d >= 0) {
          fracStart.add(at / cycle);
          fracEnd.add((at + w) / cycle);
        }
        at += w;
      }
    }
  }
  final dashed = pattern != null && cycle.isFinite && cycle > 0;
  final periodLocal = cycle * patternToLocal;

  final out = <_Expected>[];
  for (var i = 1; i < n; i++) {
    if (!dashed) {
      // The join comes BEFORE its segment, and there is none at the first
      // step because a run needs two segments to have a corner.
      if (i >= 2) {
        out.add(_Expected(
            kind: kKindJoin,
            x0: cx[i - 1],
            y0: cy[i - 1],
            x1: cx[i - 2],
            y1: cy[i - 2],
            period: 0,
            phase: 0,
            fracStart: 0,
            fracEnd: 0,
            why: 'solid join at vertex $i'));
      }
      out.add(_Expected(
          kind: kKindStroke,
          x0: cx[i - 1],
          y0: cy[i - 1],
          x1: cx[i],
          y1: cy[i],
          period: 0,
          phase: 0,
          fracStart: 0,
          fracEnd: 0,
          why: 'solid segment $i'));
      continue;
    }
    // This segment's own local-to-collection length ratio, not the
    // residual's `scaleMagnitude`: under an anisotropic residual the two
    // disagree, and only the first is right for this segment.
    final ldx = lx[i] - lx[i - 1], ldy = ly[i] - ly[i - 1];
    final cdx = cx[i] - cx[i - 1], cdy = cy[i] - cy[i - 1];
    final localLen = math.sqrt(ldx * ldx + ldy * ldy);
    final period = localLen > 0
        ? periodLocal * (math.sqrt(cdx * cdx + cdy * cdy) / localLen)
        : 0.0;
    // A pattern with no drawn element still emits exactly one instance: it
    // draws nothing until the period collapses below three screen pixels, at
    // which point the reference draws the whole line solid and the collapse
    // representative is what draws it.
    final count = fracStart.isEmpty ? 1 : fracStart.length;
    for (var k = 0; k < count; k++) {
      out.add(_Expected(
          kind: kKindStroke,
          x0: cx[i - 1],
          y0: cy[i - 1],
          x1: cx[i],
          y1: cy[i],
          // Exactly one instance per primitive is the collapse
          // representative, and it is marked by a negative period.
          period: k == 0 ? -period : period,
          phase: 0,
          fracStart: k < fracStart.length ? fracStart[k] : 0.0,
          fracEnd: k < fracEnd.length ? fracEnd[k] : 0.0,
          why: 'dashed segment $i element $k'));
    }
  }
  return out;
}

/// `shadedDashFixture` with its two curve entities removed.
///
/// The oracle above derives its answer from indices; a circle or an arc
/// would first have to be flattened, and the only way to know how many
/// chords the collector chose is to reimplement `_flattenSteps` -- which is
/// transcription, the exact failure this oracle exists to avoid. Curves are
/// gated instead by `geometry_collector_test.dart`'s arc tests (the running
/// phase, the per-chord factor, the suppressed seam) and by the pixel
/// differential below, which sees the whole corpus.
DraftDocument _polylineOnlyFixture() {
  final doc = shadedDashFixture();
  doc.commands.execute(RemoveEntityCommand(const Handle(911)));
  doc.commands.execute(RemoveEntityCommand(const Handle(912)));
  return doc;
}

({List<DrawOp> ops, GeometryCollector collector}) _paint(DraftDocument doc) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = ViewportTransform.fit(doc.extents, kViewport);
  final recording = RecordingDrawSink(shadesDashes: true);
  final collector =
      GeometryCollector(pixelsPerPaperMm: _ppmm, devicePixelRatio: _dpr);
  for (final sink in <DrawSink>[recording, collector]) {
    DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
    ).paint(sink, camera, kViewport);
  }
  return (ops: recording.ops, collector: collector);
}

void main() {
  test(
      'the collector writes exactly the instances the declarative rule '
      'produces, in order, for every dashed entity in the corpus', () {
    final doc = _polylineOnlyFixture();
    final painted = _paint(doc);
    final expected = _expectedDashInstances(painted.ops);
    final data = painted.collector.data;

    expect(painted.collector.instanceCount, expected.length,
        reason: 'the collector must emit exactly one instance per segment '
            'per drawn pattern element -- neither dropping nor duplicating '
            'one');

    for (var i = 0; i < expected.length; i++) {
      final e = expected[i];
      final o = i * kFloatsPerInstance;
      expect(data[o + InstanceFieldOffset.kind], e.kind, reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.x0], closeTo(e.x0, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.y0], closeTo(e.y0, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.x1], closeTo(e.x1, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.y1], closeTo(e.y1, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.dashPeriod], closeTo(e.period, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.dashPhase], closeTo(e.phase, _eps),
          reason: '#$i: $e');
      expect(data[o + InstanceFieldOffset.dashFracStart],
          closeTo(e.fracStart, 1e-6),
          reason: '#$i: $e');
      expect(
          data[o + InstanceFieldOffset.dashFracEnd], closeTo(e.fracEnd, 1e-6),
          reason: '#$i: $e');
    }
  });

  test(
      'the oracle is not vacuous: it produces both dashed and solid '
      'instances, and more than one drawn element', () {
    // A corpus that happened to contain only dashed single-element entities
    // would make the test above pass while checking a third of the rule.
    final expected = _expectedDashInstances(_paint(_polylineOnlyFixture()).ops);
    expect(expected.where((e) => e.period == 0), isNotEmpty,
        reason: 'entity 915 is solid');
    expect(expected.where((e) => e.kind == kKindJoin), isNotEmpty,
        reason: 'the solid entity keeps its joins');
    expect(expected.where((e) => e.period != 0 && e.kind == kKindJoin), isEmpty,
        reason: 'Ruling C3: a dashed run emits no joins');
    expect(expected.where((e) => e.period < 0), isNotEmpty,
        reason: 'every dashed primitive has a collapse representative');
    expect(expected.where((e) => e.fracStart == e.fracEnd && e.period < 0),
        isNotEmpty,
        reason: 'entity 914 is ALLGAP: one instance, empty extent');
  });
}
