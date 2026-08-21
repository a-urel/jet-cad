// Joins. Every case here is at a lineweight where the corner is several pixels
// across, because a join is invisible at a hairline and most of a CAD drawing
// is hairlines — a fixture at the shipped corpus's widths would pass with the
// join code deleted.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart';

/// 1.0 mm at 4 px/mm is 4 logical pixels, so the half-width is 2 and every
/// expected coordinate below is exact in binary.
const _lw = 100;
const _pxPerMm = 4.0;
const _half = 2.0;

ResolvedStyle _style({int argb = 0xFF000000}) => ResolvedStyle(
      argb: argb,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

VerticesDrawSink _sink() => VerticesDrawSink(pixelsPerPaperMm: _pxPerMm);

Float64List _pts(List<double> xy) => Float64List.fromList(xy);

int _triangleCount(VerticesDrawSink s) => s.debugPositions().length ~/ 6;

/// Whether any emitted triangle contains the point.
bool _inked(VerticesDrawSink s, double px, double py) {
  final v = s.debugPositions();
  // `i + 2` is the last vertex the triangle starting at `i` needs, so the
  // loop must keep visiting while that index is still valid -- `i + 5` here
  // stopped one triangle short, leaving the very last triangle in the buffer
  // invisible to every probe.
  for (var i = 0; i + 2 < v.length ~/ 2; i += 3) {
    final ax = v[i * 2], ay = v[i * 2 + 1];
    final bx = v[i * 2 + 2], by = v[i * 2 + 3];
    final cx = v[i * 2 + 4], cy = v[i * 2 + 5];
    double edge(double x0, double y0, double x1, double y1) =>
        (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
    final d1 = edge(ax, ay, bx, by);
    final d2 = edge(bx, by, cx, cy);
    final d3 = edge(cx, cy, ax, ay);
    const eps = 1e-2;
    final neg = d1 < -eps || d2 < -eps || d3 < -eps;
    final pos = d1 > eps || d2 > eps || d3 > eps;
    if (!(neg && pos)) return true;
  }
  return false;
}

void main() {
  test('the miter limit and its cosine are Impellers own', () {
    // painting.dart:1535 and stroke_path_geometry.cc:442. Written down as a
    // test so a change to either constant is a red test rather than a drawing
    // that quietly stops matching CanvasDrawSink.
    expect(VerticesDrawSink.kMiterLimit, 4.0);
    expect(VerticesDrawSink.kMinMiterCosine, closeTo(-0.875, 1e-12));
  });

  test('a right-angle corner is mitred out to the square corner', () {
    // P(0,0) -> V(10,0) -> Q(10,10) turns left, so the outer side is the right
    // one and the miter point is the outer corner of the square: (12, -2).
    // (11.5, -1.5) sits inside that notch and outside both segments' own
    // quads (quad1 is x in [0,10] x [-2,2], quad2 is x in [8,12] x [0,10]),
    // so nothing but a correctly-sided join inks it.
    //
    // A probe on the *inside* of the turn, e.g. (8, 2), cannot discriminate
    // this mutation: at exactly 90 degrees the wrong-side bevel and tip
    // triangles land entirely inside quad1's and quad2's own overlap, which
    // is already double-covered before any join exists, so such a probe reads
    // inked under both the correct and the mutated code and was dropped after
    // being checked against the code it was meant to describe.
    //
    // MUTATION: take the miter on the inside of the turn (flip the sign
    // choice in `_emitJoin`, `s = cross > 0 ? -half : half` -> `? half :
    // -half`) and (11.5, -1.5) goes uninked, because the notch is filled on
    // the wrong side instead.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter tip');
  });

  test('a right (clockwise) turn is mitred out on its own outer side', () {
    // P(0,0) -> V(10,0) -> Q(10,-10) turns right (`cross` is negative, the
    // mirror of the left-turn fixture above), so the outer side is now
    // *below* the path: V=(10,0), A=(10,2), the miter tip M=(12,2), B=(12,0).
    // (11.5, 1.5) sits inside that notch and outside both segments' own
    // quads (quad1 is x in [0,10] x [-2,2], quad2 is x in [8,12] x [-10,0]),
    // so nothing but a correctly-sided join inks it.
    //
    // Every other fixture in this file turns left. A sign bug in the
    // `cross > 0` branch selection would show up only on this side of the
    // turn.
    //
    // MUTATION: collapse `s = cross > 0 ? -half : half` to `s = -half`,
    // always taking the left-turn side, and (11.5, 1.5) goes uninked because
    // the wedge is mirrored onto the wrong side of this clockwise corner.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, -10]), 3, _style(), closed: false)
      ..endResidual();

    expect(_inked(sink, 11.5, 1.5), isTrue, reason: 'the miter tip');
  });

  test('a mitred corner emits both the bevel and the tip triangle', () {
    // MUTATION: swap the bevel triangle's two outer corners for the *inner*
    // ones (`_emitTriangle(vx, vy, vx - n0x, vy - n0y, vx - n1x, vy - n1y,
    // argb)`), leaving the tip triangle's own `A`/`B` untouched. Still two
    // triangles -- the count stays 6 -- but the bevel no longer connects `V`
    // to the tip, so the point just inside the wedge -- between the vertex
    // and the chord AB -- goes uninked. That is the hairline crack: dropping
    // the bevel outright changes the *count* (5, not 6) and would fail this
    // test before the wedge probe below ever ran; misplacing it instead
    // keeps the count honest and dies on the probe the comment names.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    // Two segments are 4 triangles; the join adds 2.
    expect(_triangleCount(sink), 6);
    // A = (10, -2), B = (12, 0), V = (10, 0). The wedge's centroid.
    expect(_inked(sink, 10.6, -0.6), isTrue, reason: 'the bevel wedge');
  });

  test('a corner past the miter limit is bevelled, one triangle', () {
    // A 170-degree direction change: dot = cos(170 deg) = -0.985, below
    // -0.875.
    //
    // MUTATION: miter every corner and this reads 6 triangles and a spike
    // reaching about 23 units out.
    const a = 170 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]),
          3, _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 5, reason: '4 for the segments, 1 bevel');
  });

  test('a corner just inside the limit is still mitred', () {
    // 150 degrees: dot = -0.866, above -0.875. The boundary is a real edge and
    // both sides of it are pinned.
    //
    // MUTATION: bevel every corner and this reads 5.
    const a = 150 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]),
          3, _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 6);
  });

  test('an open polyline gets no join between its ends', () {
    // MUTATION: join the first and last segment of an open run and this reads
    // 8 -- the L gets a phantom corner at the origin.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
  });

  test('a zero-length step is skipped and the join spans it', () {
    // A repeated point carries no direction. Skipping it must not also skip
    // the corner it sits on.
    //
    // MUTATION: return early from the whole run on a zero-length step and the
    // second segment and its join both vanish.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 0, 10, 10]), 4, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter still fires');
  });

  test('joins are emitted under the residual, not in local space', () {
    // Degenerate-fixture guard: every case above is at the identity, and a
    // join computed before the transform would pass all of them.
    //
    // MUTATION: compute the join from local-space directions and the miter
    // lands at (2, 12) instead.
    const t = Transform2(0, 1, -1, 0, 0, 0); // quarter turn
    final sink = _sink()
      ..beginResidual(t)
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    // (12, -2) rotated a quarter turn is (2, 12).
    expect(_inked(sink, 1.5, 11.5), isTrue);
  });

  test('a flattened curve joins its chords', () {
    // MUTATION: skip the join between two chords and a thick arc shows a notch
    // at every one of them. Sampled just outside the chord and inside the
    // stroke, at the arc's midpoint.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..arc(0, 0, 40, 0, math.pi / 2, _style())
      ..endResidual();

    // The outer edge of the stroke at 45 degrees is at radius 42, and the
    // chord there falls short of it by the sag. Without joins that sliver is
    // uninked.
    final r = 40 + _half - 0.15;
    expect(_inked(sink, r * math.cos(math.pi / 4), r * math.sin(math.pi / 4)),
        isTrue);
  });

  test('a circle joins at its seam, so there is no notch at the start angle',
      () {
    // A circle is a full-sweep flatten whose last chord lands on its first
    // point. The corner there is a corner, and it is the one that is easy to
    // forget because no vertex list contains it.
    //
    // MUTATION: end a closed run without the seam join and the sample just
    // outside the two chords that meet at angle 0 goes uninked.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..circle(0, 0, 40, _style())
      ..endResidual();

    // Just inside the outer edge of the stroke, on the seam's bisector — the
    // notch's deepest point if the join is missing.
    expect(_inked(sink, 40 + _half - 0.15, 0.0), isTrue);
  });

  test('the seam is one join, not two, and not a cap', () {
    // MUTATION: emit the closing segment without the join and this reads one
    // triangle pair short; MUTATION: join both ends and it reads two too many.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0, 30, 30, 0, 30]), 4, _style(), closed: true)
      ..endResidual();

    // Four segments (8 triangles) and four corners (2 triangles each, all four
    // right angles so all four mitre).
    expect(_triangleCount(sink), 8 + 8);
  });

  test('an open run of the same points has two corners, not four', () {
    // The control for the row above: an open run of 4 points is 3 segments
    // with a join at each of its 2 interior vertices (p1, p2) and nothing at
    // p0 or p3 -- there is no following segment to join against there.
    // Closing adds the segment p3 -> p0 and picks up two more corners: the
    // join at p3 that only exists because the run keeps going past it now,
    // and the explicit seam join at p0. That is 1 quad (2 triangles) plus 2
    // joins (4 triangles) more than this row -- 10 + 6 = 16, matching the row
    // above.
    //
    // MUTATION: treat every run as closed and this reads 16.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0, 30, 30, 0, 30]), 4, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6 + 4);
  });

  test('a closed run of two points closes without a phantom seam', () {
    // Two points make one segment out and one back along the same line. There
    // is no corner: both joins -- the automatic one at (30, 0), inside the
    // closing `_runTo`, and the explicit seam join at (0, 0) -- are exact
    // 180-degree reversals.
    //
    // `_endRun`'s own `_runSegments >= 2` guard turns out not to be what
    // saves this fixture: by the time it is checked, the closing `_runTo`
    // has already run, and a closed run can only reach that point with
    // `_runSegments == 2` or more (checked by hand and confirmed empirically
    // by disabling the guard -- every test here, including this one, stayed
    // green). What actually keeps this finite is `_emitJoin`'s own layering,
    // all three bails at once for an exact reversal: `cross == 0` fires
    // first; even without it `dot < kMinMiterCosine` fires next (a reversal's
    // cosine is exactly -1); even without both of those `mlen == 0` fires
    // last, because `n0` and `n1` are exact opposites and their sum is the
    // zero vector before it is ever divided into.
    //
    // MUTATION: disable all three of `_emitJoin`'s bails (`cross == 0`,
    // `dot < kMinMiterCosine` and `mlen == 0`) at once and `mx /= mlen`
    // divides zero by zero -- confirmed empirically: this test is the one
    // that goes red (`v.isFinite` reads false), and it does so only when all
    // three are gone together, not for any one of them alone.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0]), 2, _style(), closed: true)
      ..endResidual();
    for (final v in sink.debugPositions()) {
      expect(v.isFinite, isTrue);
    }
  });
}
