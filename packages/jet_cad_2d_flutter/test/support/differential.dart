import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// How far apart two drawings may be and still count as the same drawing.
///
/// Measured, not guessed: regrouping the same composition — which is exactly
/// what the anisotropy bypass does, and what Plan 3b's picture cache will do —
/// moves a drawn point by about 1e-8 logical pixels at site-plan magnitude.
/// This is a hundred times that, and a thousandth of a pixel anyone could see.
/// `Tolerance.standard`'s 1e-9 is *too tight* for absolute screen coordinates
/// out there; 417 of 500 sampled chains fail it on noise alone.
const double kScreenTolerance = 1e-6;

/// One drawn thing, in screen space, with its residual already applied.
///
/// Comparing raw op fields would be comparing arithmetic routes, not pictures:
/// the painter's bypass hands the sink screen-space points under a
/// translation-only residual where the reference hands it local points under a
/// full one. Both draw the same line.
class DrawnItem {
  DrawnItem(this.kind, this.style, this.points,
      {this.radius = 0, this.start = 0, this.sweep = 0, this.closed = false});

  final String kind;
  final ResolvedStyle style;
  final List<Vector2> points;
  final double radius;
  final double start;
  final double sweep;
  final bool closed;

  bool matches(DrawnItem other) {
    if (kind != other.kind ||
        style != other.style ||
        closed != other.closed ||
        points.length != other.points.length) {
      return false;
    }
    if ((radius - other.radius).abs() > kScreenTolerance) return false;
    if ((start - other.start).abs() > kScreenTolerance) return false;
    if ((sweep - other.sweep).abs() > kScreenTolerance) return false;
    for (var i = 0; i < points.length; i++) {
      if ((points[i].x - other.points[i].x).abs() > kScreenTolerance ||
          (points[i].y - other.points[i].y).abs() > kScreenTolerance) {
        return false;
      }
    }
    return true;
  }

  bool outside(Rect viewport) {
    final margin = radius + 1.0;
    for (final p in points) {
      if (p.x >= viewport.left - margin &&
          p.x <= viewport.right + margin &&
          p.y >= viewport.top - margin &&
          p.y <= viewport.bottom + margin) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => '$kind${points.map((p) => '(${p.x.toStringAsFixed(2)},'
          '${p.y.toStringAsFixed(2)})').join()}'
      '${radius == 0 ? '' : ' r=${radius.toStringAsFixed(2)}'}';
}

/// Applies each residual to the geometry drawn under it.
List<DrawnItem> flatten(List<DrawOp> ops) {
  final out = <DrawnItem>[];
  var residual = Transform2.identity();
  for (final op in ops) {
    switch (op) {
      case BeginResidualOp(residual: final pushed):
        residual = pushed;
      case EndResidualOp():
        residual = Transform2.identity();
      case PointOp(:final x, :final y, :final style):
        out.add(DrawnItem(
            'point', style, [residual.transformPoint(Vector2(x, y))]));
      case PolylineOp(:final points, :final style, :final closed):
        out.add(DrawnItem(
            'polyline',
            style,
            [
              for (var i = 0; i < points.length; i += 2)
                residual.transformPoint(Vector2(points[i], points[i + 1]))
            ],
            closed: closed));
      case CircleOp(:final cx, :final cy, :final r, :final style):
        out.add(DrawnItem(
            'circle', style, [residual.transformPoint(Vector2(cx, cy))],
            radius: r * residual.scaleMagnitude));
      case ArcOp(
          :final cx,
          :final cy,
          :final r,
          :final start,
          :final sweep,
          :final style
        ):
        out.add(DrawnItem(
            'arc', style, [residual.transformPoint(Vector2(cx, cy))],
            radius: r * residual.scaleMagnitude, start: start, sweep: sweep));
      case FillPolygonOp(:final points, :final style):
        out.add(DrawnItem(
            'fillPolygon',
            style,
            [
              for (var i = 0; i < points.length; i += 2)
                residual.transformPoint(Vector2(points[i], points[i + 1]))
            ],
            closed: true));
      case FillCircleOp(:final cx, :final cy, :final r, :final style):
        out.add(DrawnItem(
            'fillCircle', style, [residual.transformPoint(Vector2(cx, cy))],
            radius: r * residual.scaleMagnitude));
      case TextOp(:final text, :final resolved):
        // Three points, not one: the origin plus the images of the local
        // unit vectors, so `kScreenTolerance` covers scale, rotation and
        // shear with the machinery already here. The string rides in
        // `kind`, which compares exactly.
        out.add(DrawnItem('text:$text', resolved, [
          residual.transformPoint(Vector2.zero()),
          residual.transformPoint(Vector2(1, 0)),
          residual.transformPoint(Vector2(0, 1)),
        ]));
    }
  }
  return out;
}

/// Asserts the painter drew everything the reference did, in the same relative
/// order, and that anything extra it drew is off screen.
///
/// Superset, not equality: the painter culls against index boxes carrying
/// narrow-phase slack, in container space, while the reference culls against
/// entity bounds in root space. Demanding equality would fail on every rotated
/// instance whose box is looser than its geometry. What must never happen is
/// the other direction — something the reference drew inside the view that the
/// painter did not.
/// [edgeBandPx] excludes a band along the inside of the frame from the
/// *extra-ops* half of the comparison only. The superset half — everything
/// the reference drew, the painter drew — is never relaxed.
///
/// Zero is the tight reading and is right for any camera with margin around
/// the drawing, which is every fixture-sized one. A camera that **crops** needs
/// a band, and the reason is structural rather than a tolerance fudge: the
/// painter culls against index boxes carrying narrow-phase slack, in container
/// space, against a clip inflated by [kScreenClipInflate]; the reference culls
/// against exact entity bounds in root space against the viewport itself. An
/// entity whose geometry falls a fraction of a pixel outside the frame edge is
/// therefore drawn by one and dropped by the other, and **both are right**.
/// Measured on the Task 10 text corpus: a circle 0.29 px below the bottom edge
/// and a polyline 20 px below it. Without a band this comparison reports the
/// difference between the two culling strategies as a wrong drawing.
void expectPainterSupersetOfReference(
    List<DrawOp> painter, List<DrawOp> reference, Size viewport,
    {double edgeBandPx = 0}) {
  final drawn = flatten(painter);
  final expected = flatten(reference);
  final rect =
      Rect.fromLTWH(0, 0, viewport.width, viewport.height).deflate(edgeBandPx);

  final matched = List<bool>.filled(drawn.length, false);
  var cursor = 0;
  for (var i = 0; i < drawn.length && cursor < expected.length; i++) {
    if (drawn[i].matches(expected[cursor])) {
      matched[i] = true;
      cursor++;
    }
  }

  expect(cursor, expected.length,
      reason: 'the painter missed ${expected.length - cursor} of '
          '${expected.length} reference ops, first unmatched: '
          '${cursor < expected.length ? expected[cursor] : "-"}\n'
          'painter drew ${drawn.length}: '
          '${drawn.take(8).join(", ")}');

  for (var i = 0; i < drawn.length; i++) {
    if (matched[i]) continue;
    expect(drawn[i].outside(rect), isTrue,
        reason: 'the painter drew ${drawn[i]} inside the view and the '
            'reference did not — that is a wrong drawing, not loose culling');
  }
}
