import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/differential.dart';
import 'support/fixtures.dart';

double f32(double v) => (Float32List(1)..[0] = v)[0];

Transform2 asFloat32(Transform2 t) =>
    Transform2(f32(t.a), f32(t.b), f32(t.c), f32(t.d), f32(t.e), f32(t.f));

List<DrawOp> paint(DraftDocument doc, ViewportTransform camera,
    {bool disableRebasing = false}) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final sink = RecordingDrawSink();
  DraftPainter(
    document: doc,
    index: index,
    resolver: DocumentStyleResolver(doc),
    debugDisableRebasing: disableRebasing,
  ).paint(sink, camera, kViewport);
  return sink.ops;
}

/// The worst world-space error the ops would suffer on the way through
/// `Canvas`.
///
/// Skia holds matrices and points as 32-bit floats, so both the residual and
/// the coordinates handed to it are rounded — this rounds both the same way and
/// asks how far the drawn point moved, measured against the same op evaluated
/// in Float64. Nothing else changes, so the number is the float32 damage and
/// only that.
double maxWorldErrorOf(List<DrawOp> ops, ViewportTransform camera) {
  var worst = 0.0;
  var residual = Transform2.identity();
  for (final op in ops) {
    if (op is BeginResidualOp) {
      residual = op.residual;
      continue;
    }
    final rounded = asFloat32(residual);
    for (final p in _localPointsOf(op)) {
      final exact = camera.screenToWorld(residual.transformPoint(p));
      final approx = camera
          .screenToWorld(rounded.transformPoint(Vector2(f32(p.x), f32(p.y))));
      final error = (exact - approx).length;
      if (error > worst) worst = error;
    }
  }
  return worst;
}

List<Vector2> _localPointsOf(DrawOp op) => switch (op) {
      PointOp(:final x, :final y) => [Vector2(x, y)],
      PolylineOp(:final points) => [
          for (var i = 0; i < points.length; i += 2)
            Vector2(points[i], points[i + 1])
        ],
      CircleOp(:final cx, :final cy) => [Vector2(cx, cy)],
      ArcOp(:final cx, :final cy) => [Vector2(cx, cy)],
      _ => const <Vector2>[],
    };

void main() {
  test('every residual reaching Canvas is small at 4.5e6', () {
    // float32 has a 24-bit mantissa: at 4.5e6 the representable spacing is
    // about 0.5 units. The whole chain composes in Float64 and only the
    // residual crosses over, so its translation must stay far below that.
    final doc = differentialFixture(originX: 4.5e6);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final residuals = paint(doc, camera).whereType<BeginResidualOp>();

    expect(residuals, isNotEmpty);
    for (final op in residuals) {
      expect(op.residual.e.abs(), lessThan(1 << 20));
      expect(op.residual.f.abs(), lessThan(1 << 20));
    }
  });

  test('every coordinate reaching Canvas is small at 4.5e6', () {
    // The residual is half of what crosses the boundary. The points do too,
    // and a rebase that left them at 4.5e6 while keeping the matrix small
    // would pass the test above and still lose the drawing.
    final doc = differentialFixture(originX: 4.5e6);
    final camera = ViewportTransform.fit(doc.extents, kViewport);
    final ops = paint(doc, camera);

    var checked = 0;
    for (final op in ops) {
      for (final p in _localPointsOf(op)) {
        expect(p.x.abs(), lessThan(1 << 20));
        expect(p.y.abs(), lessThan(1 << 20));
        checked++;
      }
    }
    expect(checked, greaterThan(10), reason: 'the fixture must draw something');
  });

  test('recorded points reproduce world coordinates through the residual', () {
    // Small is not enough — small and *right*. The reference walk composes the
    // same document by another route, so agreeing with it in world space says
    // the rebase moved nothing.
    final doc = differentialFixture(originX: 4.5e6);
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    final painted = flatten(paint(doc, camera));
    final reference = flatten(referenceToRecording(doc, camera));
    expect(reference, isNotEmpty);

    for (final item in reference) {
      final match = painted.firstWhere((d) => d.matches(item),
          orElse: () => throw TestFailure('no painter op matched $item'));
      for (var i = 0; i < item.points.length; i++) {
        final a = camera.screenToWorld(item.points[i]);
        final b = camera.screenToWorld(match.points[i]);
        expect(b.x, closeTo(a.x, 1e-3));
        expect(b.y, closeTo(a.y, 1e-3));
      }
    }
  });

  test('with rebasing disabled, float32 rounding is observable', () {
    // Documents what the failure looks like, so the assertions above are
    // measured against something real rather than against an argument. If this
    // ever stops failing, the two above stopped proving anything.
    final doc = differentialFixture(originX: 4.5e6);
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    final rounded =
        maxWorldErrorOf(paint(doc, camera, disableRebasing: true), camera);
    final exact =
        maxWorldErrorOf(paint(doc, camera, disableRebasing: false), camera);

    expect(rounded, greaterThan(0.05),
        reason: 'without the rebase, float32 must visibly move the drawing');
    expect(exact, lessThan(1e-3),
        reason: 'with it, the damage must be far below a drawing unit');
    expect(exact * 50, lessThan(rounded),
        reason: 'the rebase must buy orders of magnitude, not a few percent');
  });

  test('at the origin the rebase changes nothing measurable', () {
    // The same fixture near zero: float32 carries it either way, so the flag
    // is a no-op there. This is what makes the test above about magnitude
    // rather than about the flag.
    final doc = differentialFixture();
    final camera = ViewportTransform.fit(doc.extents, kViewport);

    expect(maxWorldErrorOf(paint(doc, camera, disableRebasing: true), camera),
        lessThan(1e-3));
  });
}
