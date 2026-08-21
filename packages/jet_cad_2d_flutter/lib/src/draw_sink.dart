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
  /// [debugHandle] names the leaf or instance this residual belongs to. It is
  /// diagnostic only — [RecordingDrawSink] keeps it so a test can assert draw
  /// order, `==` ignores it, and the other sinks drop it. `Handle` is an
  /// extension type over `int`, so carrying it costs nothing at runtime.
  void beginResidual(Transform2 residual, {Handle debugHandle});
  void endResidual();
  void point(double x, double y, ResolvedStyle style);
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed});
  void circle(double cx, double cy, double r, ResolvedStyle style);
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style);

  /// Fills a closed loop.
  ///
  /// [points] is the boundary's loop in this residual's local space, [count]
  /// its point count including the duplicated closing point. [triangles] is
  /// the loop's triangulation as triple-indices into [points]' point
  /// numbering -- computed once, off the frame path, and passed through
  /// because a sink must not reach into the document to get it.
  ///
  /// A sink that fills paths natively ignores [triangles]; a sink that batches
  /// geometry needs them. Both receive the same call, which is what keeps
  /// [RecordingDrawSink] equality meaningful.
  ///
  /// The painter never calls this with an empty [triangles]: an unfillable
  /// boundary is skipped and counted before it reaches a sink. See
  /// `DraftPainter.skippedFillCount`.
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style);

  /// Fills a circle. Never triangulated ahead of time: a circle's
  /// tessellation is scale-dependent, so a batching sink fans it per frame at
  /// the step count its own stroke would use.
  void fillCircle(double cx, double cy, double r, ResolvedStyle style);

  /// Draws [text] at the residual's local origin.
  ///
  /// No offset and no second matrix: the painter pushes `residual ∘
  /// textLocal` as the residual itself, so by the time this is called the
  /// text's own placement is already folded in.
  void text(String text, Handle style, ResolvedStyle resolved);
}

/// One recorded call. Compared by value, so two painters that agree produce
/// two equal op lists.
@immutable
sealed class DrawOp {
  const DrawOp();
}

@immutable
final class BeginResidualOp extends DrawOp {
  const BeginResidualOp(this.residual, {this.debugHandle = Handle.none});

  final Transform2 residual;

  /// Which leaf or instance this residual belongs to, or [Handle.none].
  ///
  /// Deliberately outside `==` and `hashCode`: the oracle compares two
  /// painters' op lists, and the same picture drawn from different slots must
  /// still compare equal.
  final Handle debugHandle;

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

@immutable
final class FillPolygonOp extends DrawOp {
  const FillPolygonOp(this.points, this.triangles, this.style);

  /// Flat `[x0, y0, x1, y1, ...]`, already trimmed to the drawn point count.
  final List<double> points;

  /// Triple-indices into [points]' point numbering. Part of `==`: a painter
  /// that hands one sink a stale triangulation and the other a fresh one must
  /// produce two op lists the oracle sees as different, not two lists that
  /// happen to compare equal because only the boundary was checked.
  final List<int> triangles;

  final ResolvedStyle style;

  @override
  bool operator ==(Object other) =>
      other is FillPolygonOp &&
      other.style == style &&
      listEquals(other.points, points) &&
      listEquals(other.triangles, triangles);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(points), Object.hashAll(triangles), style);

  @override
  String toString() => 'FillPolygonOp($points, $triangles)';
}

@immutable
final class FillCircleOp extends DrawOp {
  const FillCircleOp(this.cx, this.cy, this.r, this.style);

  final double cx;
  final double cy;
  final double r;
  final ResolvedStyle style;

  @override
  bool operator ==(Object other) =>
      other is FillCircleOp &&
      other.cx == cx &&
      other.cy == cy &&
      other.r == r &&
      other.style == style;

  @override
  int get hashCode => Object.hash(cx, cy, r, style);

  @override
  String toString() => 'FillCircleOp($cx, $cy, $r)';
}

@immutable
final class TextOp extends DrawOp {
  const TextOp(this.text, this.style, this.resolved);

  final String text;
  final Handle style;
  final ResolvedStyle resolved;

  @override
  bool operator ==(Object other) =>
      other is TextOp &&
      other.text == text &&
      other.style == style &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(text, style, resolved);

  @override
  String toString() => 'TextOp($text, $style)';
}

/// Keeps every op, for tests and for the differential oracle.
class RecordingDrawSink implements DrawSink {
  final List<DrawOp> _ops = <DrawOp>[];

  List<DrawOp> get ops => _ops;

  void clear() => _ops.clear();

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) =>
      _ops.add(BeginResidualOp(residual, debugHandle: debugHandle));

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

  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      // Copied, not retained, same reason as `polyline`: the painter reuses
      // one scratch buffer per depth.
      _ops.add(FillPolygonOp(
          points.sublist(0, count * 2), triangles.toList(), style));

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _ops.add(FillCircleOp(cx, cy, r, style));

  @override
  void text(String text, Handle style, ResolvedStyle resolved) =>
      _ops.add(TextOp(text, style, resolved));
}

/// Counts ops and keeps none, so a measurement rig can time the walk without
/// timing the rasteriser.
class NullDrawSink implements DrawSink {
  int opCount = 0;

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) =>
      opCount++;

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

  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      opCount++;

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      opCount++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => opCount++;
}
