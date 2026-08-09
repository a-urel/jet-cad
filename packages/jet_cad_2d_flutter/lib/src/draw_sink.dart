import 'dart:typed_data';

// The engine's `listEquals`, not Flutter's: nothing in this file needs
// `dart:ui`, so the seam and the recording sink stay usable from a plain
// `dart:test` suite.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

/// Where the painter writes.
///
/// **Every coordinate passed between [beginResidual] and [endResidual] is in
/// that residual's local space** — already rebased, never a world coordinate,
/// never rebased twice. The rule is on the interface because
/// [RecordingDrawSink] equality is the project's primary correctness
/// mechanism, and an ambiguous coordinate space lets two correct
/// implementations disagree.
abstract class DrawSink {
  void beginResidual(Transform2 residual);
  void endResidual();
  void point(double x, double y, ResolvedStyle style);
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed});
  void circle(double cx, double cy, double r, ResolvedStyle style);
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style);
}

/// One recorded call. Compared by value, so two painters that agree produce
/// two equal op lists.
@immutable
sealed class DrawOp {
  const DrawOp();
}

@immutable
final class BeginResidualOp extends DrawOp {
  const BeginResidualOp(this.residual);

  final Transform2 residual;

  // `Transform2` deliberately has no `operator ==` — exact equality on a
  // composed transform is usually a bug — so the comparison is spelled out
  // here, where exactness is the point: the oracle in Task 11 asks whether two
  // painters pushed the same residual, not whether they nearly did.
  @override
  bool operator ==(Object other) =>
      other is BeginResidualOp &&
      other.residual.a == residual.a &&
      other.residual.b == residual.b &&
      other.residual.c == residual.c &&
      other.residual.d == residual.d &&
      other.residual.e == residual.e &&
      other.residual.f == residual.f;

  @override
  int get hashCode => Object.hash(
      residual.a, residual.b, residual.c, residual.d, residual.e, residual.f);

  @override
  String toString() => 'BeginResidualOp($residual)';
}

@immutable
final class EndResidualOp extends DrawOp {
  const EndResidualOp();

  @override
  bool operator ==(Object other) => other is EndResidualOp;

  @override
  int get hashCode => (EndResidualOp).hashCode;

  @override
  String toString() => 'EndResidualOp()';
}

@immutable
final class PointOp extends DrawOp {
  const PointOp(this.x, this.y, this.style);

  final double x;
  final double y;
  final ResolvedStyle style;

  @override
  bool operator ==(Object other) =>
      other is PointOp && other.x == x && other.y == y && other.style == style;

  @override
  int get hashCode => Object.hash(x, y, style);

  @override
  String toString() => 'PointOp($x, $y)';
}

@immutable
final class PolylineOp extends DrawOp {
  const PolylineOp(this.points, this.style, {required this.closed});

  /// Flat `[x0, y0, x1, y1, ...]`, already trimmed to the drawn point count.
  final List<double> points;
  final ResolvedStyle style;
  final bool closed;

  @override
  bool operator ==(Object other) =>
      other is PolylineOp &&
      other.closed == closed &&
      other.style == style &&
      listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(Object.hashAll(points), style, closed);

  @override
  String toString() => 'PolylineOp($points, closed: $closed)';
}

@immutable
final class CircleOp extends DrawOp {
  const CircleOp(this.cx, this.cy, this.r, this.style);

  final double cx;
  final double cy;
  final double r;
  final ResolvedStyle style;

  @override
  bool operator ==(Object other) =>
      other is CircleOp &&
      other.cx == cx &&
      other.cy == cy &&
      other.r == r &&
      other.style == style;

  @override
  int get hashCode => Object.hash(cx, cy, r, style);

  @override
  String toString() => 'CircleOp($cx, $cy, $r)';
}

@immutable
final class ArcOp extends DrawOp {
  const ArcOp(this.cx, this.cy, this.r, this.start, this.sweep, this.style);

  final double cx;
  final double cy;
  final double r;
  final double start;
  final double sweep;
  final ResolvedStyle style;

  @override
  bool operator ==(Object other) =>
      other is ArcOp &&
      other.cx == cx &&
      other.cy == cy &&
      other.r == r &&
      other.start == start &&
      other.sweep == sweep &&
      other.style == style;

  @override
  int get hashCode => Object.hash(cx, cy, r, start, sweep, style);

  @override
  String toString() => 'ArcOp($cx, $cy, $r, $start, $sweep)';
}

/// Keeps every op, for tests and for the differential oracle.
class RecordingDrawSink implements DrawSink {
  final List<DrawOp> _ops = <DrawOp>[];

  List<DrawOp> get ops => _ops;

  void clear() => _ops.clear();

  @override
  void beginResidual(Transform2 residual) =>
      _ops.add(BeginResidualOp(residual));

  @override
  void endResidual() => _ops.add(const EndResidualOp());

  @override
  void point(double x, double y, ResolvedStyle style) =>
      _ops.add(PointOp(x, y, style));

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
          {required bool closed}) =>
      // Copied, not retained: the painter hands over one scratch buffer per
      // depth and overwrites it for the next entity.
      _ops.add(PolylineOp(points.sublist(0, count * 2), style, closed: closed));

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _ops.add(CircleOp(cx, cy, r, style));

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _ops.add(ArcOp(cx, cy, r, start, sweep, style));
}

/// Counts ops and keeps none, so a measurement rig can time the walk without
/// timing the rasteriser.
class NullDrawSink implements DrawSink {
  int opCount = 0;

  @override
  void beginResidual(Transform2 residual) => opCount++;

  @override
  void endResidual() => opCount++;

  @override
  void point(double x, double y, ResolvedStyle style) => opCount++;

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
          {required bool closed}) =>
      opCount++;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) => opCount++;

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      opCount++;
}
