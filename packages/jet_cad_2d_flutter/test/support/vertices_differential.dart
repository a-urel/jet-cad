// The differential oracle for `VerticesDrawSink`.
//
// `expectPainterSupersetOfReference` compares two op streams, which is why it
// survived the sink swap it was designed for. This sink emits no ops at all —
// it emits triangles — so the comparison has to move down a level: from "did
// the two walks agree on the ops" to "is there ink where the ops say there
// should be, and nowhere else".
//
// The two directions answer different questions and both are needed:
//
//   `expectInkCovers`  every point the primitives pass through is inside some
//                      triangle of the right colour. Catches a dropped op, a
//                      dropped residual, a wrong transform, a wrong colour and
//                      a curve flattened too coarsely.
//   `expectNoStrayInk` every triangle sits on a primitive. Catches invented
//                      geometry, a stale buffer that was never rewound, and a
//                      residual applied twice.
//
// ## What this cannot see
//
// **A stroke that is too thin, on a straight line.** The samples run along the
// centreline, and the centreline is inside the quad at any positive width. The
// halved-width mutant dies here, but only through the curves: a chord's sag
// pushes the true arc outside a quad that has become thinner than the sag, and
// a drawing of nothing but straight lines would not catch it. Width is
// `vertices_draw_sink_test.dart`'s to pin, against Impeller's own two rules.
//
// **Alpha.** [InkSample] carries RGB and no more. The alpha a stroke is drawn
// at is the sub-pixel coverage rule the sink applies itself, so asserting it
// here would be asserting the sink's arithmetic back at it rather than against
// an independent account of the drawing.
//
// **Anything about order.** Two triangles overlapping in the buffer are both
// found by a point-in-triangle test whichever came first. Draw order is pinned
// by construction — the buffer is appended to and submitted once — and by the
// unit test that reads the colours back in emission order.
//
// Neither direction re-implements the sink. The samples are taken along the
// *true* primitive — the real arc, not its chords — and transformed by the
// residual; the sink builds chord quads. A test that walked the chords would
// be comparing the sink against itself.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'fixtures.dart';

/// About one logical pixel between samples along a primitive.
///
/// Fine enough that [expectNoStrayInk] can use "near a sample" as a stand-in
/// for "near the primitive" without the gaps between samples reading as stray
/// ink, and fine enough that [expectInkCovers] cannot step over a hole.
const double kSampleSpacingPx = 1.0;

/// A point ink is expected at, in screen space, with the colour it should be.
class InkSample {
  InkSample(this.x, this.y, this.rgb, this.from);

  final double x, y;

  /// RGB only. Alpha is Impeller's sub-pixel coverage rule, which
  /// `vertices_draw_sink_test.dart` owns; folding it in here would make this
  /// oracle assert the sink's own arithmetic back at it.
  final int rgb;

  /// What produced this sample, for a failure message that names a primitive
  /// rather than a coordinate.
  final String from;

  @override
  String toString() => '$from at (${x.toStringAsFixed(2)}, '
      '${y.toStringAsFixed(2)})';
}

/// Samples the ops along the geometry they describe, in screen space.
///
/// Curves are sampled on the true curve and then transformed, so a non-uniform
/// residual gives points on the ellipse `Canvas` would have drawn. Sampling a
/// circle of the flattened radius would agree with a sink that drew circles
/// where it should have drawn ellipses.
List<InkSample> inkSamples(List<DrawOp> ops) {
  final out = <InkSample>[];
  var residual = Transform2.identity();

  Vector2 toScreen(double x, double y) =>
      residual.transformPoint(Vector2(x, y));

  void sampleSegment(Vector2 a, Vector2 b, int rgb, String from) {
    final length = (b - a).length;
    final steps = math.max(2, (length / kSampleSpacingPx).ceil());
    // Endpoints excluded: a cap or a join is the one place the sink and the
    // primitive are allowed to disagree, and neither is under test here.
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      out.add(
          InkSample(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, rgb, from));
    }
  }

  void sampleCurve(double cx, double cy, double r, double start, double sweep,
      int rgb, String from) {
    // The arc's on-screen length sets the sample count, so a curve zoomed to
    // fill the viewport is sampled as finely as a straight line of the same
    // length.
    final screenRadius = r * residual.scaleMagnitude;
    final arcLength = (screenRadius * sweep).abs();
    final steps = math.max(8, (arcLength / kSampleSpacingPx).ceil());
    // Ends excluded for the same reason segment ends are: a butt end is the
    // boundary of the ink, not its interior, and a sample sitting exactly on
    // it is neither in nor out.
    for (var i = 1; i < steps; i++) {
      final angle = start + sweep * (i / steps);
      final p = toScreen(cx + r * math.cos(angle), cy + r * math.sin(angle));
      out.add(InkSample(p.x, p.y, rgb, from));
    }
  }

  for (final op in ops) {
    switch (op) {
      case BeginResidualOp(residual: final pushed):
        residual = pushed;
      case EndResidualOp():
        residual = Transform2.identity();
      case PointOp(:final x, :final y, :final style):
        final p = toScreen(x, y);
        out.add(InkSample(p.x, p.y, style.argb & 0x00FFFFFF, 'point'));
      case PolylineOp(:final points, :final style, :final closed):
        final rgb = style.argb & 0x00FFFFFF;
        final screen = <Vector2>[
          for (var i = 0; i < points.length; i += 2)
            toScreen(points[i], points[i + 1])
        ];
        for (var i = 1; i < screen.length; i++) {
          sampleSegment(screen[i - 1], screen[i], rgb, 'polyline');
        }
        if (closed && screen.length > 2) {
          sampleSegment(screen.last, screen.first, rgb, 'polyline(closed)');
        }
      case CircleOp(:final cx, :final cy, :final r, :final style):
        sampleCurve(
            cx, cy, r, 0, 2 * math.pi, style.argb & 0x00FFFFFF, 'circle');
      case ArcOp(
          :final cx,
          :final cy,
          :final r,
          :final start,
          :final sweep,
          :final style
        ):
        sampleCurve(cx, cy, r, start, sweep, style.argb & 0x00FFFFFF, 'arc');
      case FillPolygonOp():
      case FillCircleOp():
        // Not batched: a fill goes to the fallback sink, same as text. Task
        // 12 gives VerticesDrawSink its own triangle batching for these.
        break;
      case TextOp():
        // Not batched: text goes to the fallback sink as a paragraph.
        break;
      case BeginDashOp():
      case EndDashOp():
        // `VerticesDrawSink.shadesDashes` is false, so `DraftPainter` never
        // opens a bracket on it -- this backend still receives cut spans
        // through ordinary `polyline`/`arc` calls. Task 5 gives the shading
        // sink its own reference; this switch stays exhaustive rather than
        // reachable.
        break;
    }
  }
  return out;
}

/// One emitted triangle, read back out of the sink's buffer.
class _Triangle {
  _Triangle(this.ax, this.ay, this.bx, this.by, this.cx, this.cy, this.rgb);

  final double ax, ay, bx, by, cx, cy;
  final int rgb;

  double get centroidX => (ax + bx + cx) / 3;
  double get centroidY => (ay + by + cy) / 3;

  /// Barycentric sign test, with a slack of [epsilon] so a sample exactly on a
  /// shared edge is inside one of the two triangles that meet there rather
  /// than outside both.
  bool contains(double px, double py, double epsilon) {
    double edge(double x0, double y0, double x1, double y1) =>
        (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
    final d1 = edge(ax, ay, bx, by);
    final d2 = edge(bx, by, cx, cy);
    final d3 = edge(cx, cy, ax, ay);
    final hasNeg = d1 < -epsilon || d2 < -epsilon || d3 < -epsilon;
    final hasPos = d1 > epsilon || d2 > epsilon || d3 > epsilon;
    return !(hasNeg && hasPos);
  }
}

List<_Triangle> _trianglesOf(VerticesDrawSink sink) {
  final v = sink.debugPositions();
  final c = sink.debugColors();
  final out = <_Triangle>[];
  for (var i = 0; i + 5 < c.length; i += 3) {
    out.add(_Triangle(v[i * 2], v[i * 2 + 1], v[i * 2 + 2], v[i * 2 + 3],
        v[i * 2 + 4], v[i * 2 + 5], c[i].toUnsigned(32) & 0x00FFFFFF));
  }
  return out;
}

/// A uniform grid over the triangles, so the two O(samples x triangles) loops
/// below do not become the slowest test in the suite.
class _TriangleGrid {
  _TriangleGrid(this.triangles) {
    for (var i = 0; i < triangles.length; i++) {
      final t = triangles[i];
      final minX = math.min(t.ax, math.min(t.bx, t.cx));
      final maxX = math.max(t.ax, math.max(t.bx, t.cx));
      final minY = math.min(t.ay, math.min(t.by, t.cy));
      final maxY = math.max(t.ay, math.max(t.by, t.cy));
      for (var gx = (minX / cell).floor(); gx <= (maxX / cell).floor(); gx++) {
        for (var gy = (minY / cell).floor();
            gy <= (maxY / cell).floor();
            gy++) {
          (_buckets[(gx, gy)] ??= <int>[]).add(i);
        }
      }
    }
  }

  final List<_Triangle> triangles;
  static const double cell = 16.0;
  final Map<(int, int), List<int>> _buckets = {};

  Iterable<_Triangle> near(double x, double y) sync* {
    final gx = (x / cell).floor(), gy = (y / cell).floor();
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final i in _buckets[(gx + dx, gy + dy)] ?? const <int>[]) {
          yield triangles[i];
        }
      }
    }
  }
}

/// Slack for the point-in-triangle test, in the edge function's own units.
///
/// The edge function is a cross product, so its units are area and not
/// distance: an epsilon meant as "a thousandth of a pixel" is wrong by a
/// factor of the edge length. The number that matters is the buffer's
/// precision. Positions are `Float32List`, so at the few hundred pixels of a
/// viewport the quantum is about 6e-5 px; three perturbed vertices across an
/// edge of up to ~20 px put the cross product out by about 2.4e-3. This is
/// four times that, and still four orders of magnitude below the area of the
/// thinnest quad the sink emits.
const double kEdgeEpsilon = 1e-2;

/// Every sample sits inside a triangle of its own colour.
void expectInkCovers(VerticesDrawSink sink, List<InkSample> samples,
    {double epsilon = kEdgeEpsilon}) {
  final grid = _TriangleGrid(_trianglesOf(sink));
  expect(grid.triangles, isNotEmpty, reason: 'the sink emitted no triangles');
  expect(samples, isNotEmpty, reason: 'nothing was sampled — vacuous');

  final missed = <InkSample>[];
  var wrongColour = 0;
  for (final s in samples) {
    var covered = false, coveredWrongColour = false;
    for (final t in grid.near(s.x, s.y)) {
      if (!t.contains(s.x, s.y, epsilon)) continue;
      if (t.rgb == s.rgb) {
        covered = true;
        break;
      }
      coveredWrongColour = true;
    }
    if (!covered) {
      if (coveredWrongColour) wrongColour++;
      missed.add(s);
    }
  }

  expect(missed, isEmpty,
      reason: '${missed.length} of ${samples.length} sampled points have no '
          'ink of their own colour under them ($wrongColour of them have ink '
          'of a different colour, which is a colour bug rather than a missing '
          'primitive). First few: ${missed.take(5).join("; ")}');
}

/// Every triangle sits on a primitive.
///
/// "On" means its centroid is within [slackPx] of a sample, which is a stand-in
/// for the distance to the primitive itself: samples are one pixel apart, so
/// the slack has to cover half that plus the stroke's own half-width.
void expectNoStrayInk(VerticesDrawSink sink, List<InkSample> samples,
    {required double slackPx}) {
  final triangles = _trianglesOf(sink);
  expect(triangles, isNotEmpty, reason: 'the sink emitted no triangles');

  const cell = 16.0;
  final buckets = <(int, int), List<InkSample>>{};
  for (final s in samples) {
    (buckets[((s.x / cell).floor(), (s.y / cell).floor())] ??= <InkSample>[])
        .add(s);
  }
  // The neighbourhood has to reach `slackPx`, not just one cell.
  final reach = (slackPx / cell).ceil() + 1;

  final stray = <String>[];
  for (final t in triangles) {
    final px = t.centroidX, py = t.centroidY;
    final gx = (px / cell).floor(), gy = (py / cell).floor();
    var near = false;
    outer:
    for (var dx = -reach; dx <= reach && !near; dx++) {
      for (var dy = -reach; dy <= reach; dy++) {
        for (final s in buckets[(gx + dx, gy + dy)] ?? const <InkSample>[]) {
          final ddx = s.x - px, ddy = s.y - py;
          if (ddx * ddx + ddy * ddy <= slackPx * slackPx && s.rgb == t.rgb) {
            near = true;
            break outer;
          }
        }
      }
    }
    if (!near) {
      stray.add('(${px.toStringAsFixed(2)}, ${py.toStringAsFixed(2)}) '
          'rgb=${t.rgb.toRadixString(16)}');
    }
  }

  expect(stray, isEmpty,
      reason: '${stray.length} of ${triangles.length} triangles are more than '
          '$slackPx px from any primitive of their colour. First few: '
          '${stray.take(5).join("; ")}');
}

/// Paints [doc] through the vertices sink and hands the filled sink back.
///
/// `devicePixelRatio: 1` so a logical pixel is a device pixel and the widths
/// the assertions reason about need no conversion.
VerticesDrawSink paintToVertices(DraftDocument doc, [ViewportTransform? view]) {
  final index = SpatialIndex(doc);
  final camera = view ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = VerticesDrawSink(
      pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 1.0);
  DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc))
      .paint(sink, camera, kViewport);
  index.dispose();
  return sink;
}

/// The widest stroke the ops carry, in logical pixels — the slack
/// [expectNoStrayInk] needs before a triangle counts as off its primitive.
double widestHalfStroke(List<DrawOp> ops) {
  var widest = 0.0;
  for (final op in ops) {
    final style = switch (op) {
      PointOp(:final style) => style,
      PolylineOp(:final style) => style,
      CircleOp(:final style) => style,
      ArcOp(:final style) => style,
      _ => null,
    };
    if (style == null) continue;
    final w = style.lineweightHundredths / 100.0 * kLogicalPixelsPerMm;
    widest = math.max(widest, math.max(w, 1.0));
  }
  return widest / 2;
}
