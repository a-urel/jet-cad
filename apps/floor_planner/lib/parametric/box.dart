import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The demo parametric object's parameters (spec 06 D13), in mm.
final class BoxParams implements Component {
  const BoxParams(this.width, this.height);

  static const String componentTypeId = 'floor_planner.box';

  final double width;
  final double height;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};

  static BoxParams fromJson(Map<String, Object?> json) => BoxParams(
      (json['width']! as num).toDouble(), (json['height']! as num).toDouble());

  BoxParams copyWith({double? width, double? height}) =>
      BoxParams(width ?? this.width, height ?? this.height);

  @override
  bool operator ==(Object other) =>
      other is BoxParams && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

List<Vector2> _corners(BoxParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// A rectangle whose outline loses what lies strictly inside any
/// overlapping box: overlapping boxes read as one outline, the wall
/// clean-up preview (spec 06 D13).
final class BoxType extends ParametricType<BoxParams> {
  const BoxType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BoxParams params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in _corners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<BoxParams>(self)!;
    final toLocal = view.toWorld(self).invert();
    final quads = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<BoxParams>(n) case final q?)
          [
            for (final c in _corners(q))
              toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
          ],
    ];
    final c = _corners(p);
    const tol = Tolerance.standard;
    final out = <Generated>[];
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      final len = (b - a).length;
      var keep = <(double, double)>[(0, 1)];
      for (final q in quads) {
        final inside = _insideInterval(a, b, q);
        if (inside == null) continue;
        keep = [
          for (final (lo, hi) in keep) ...[
            if ((math.min(hi, inside.$1) - lo) * len > tol.linear)
              (lo, math.min(hi, inside.$1)),
            if ((hi - math.max(lo, inside.$2)) * len > tol.linear)
              (math.max(lo, inside.$2), hi),
          ],
        ];
      }
      for (final (lo, hi) in keep) {
        out.add(Generated(
            EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
      }
    }
    return out;
  }
}

/// The open parameter interval of a->b strictly inside the convex quad [q].
(double, double)? _insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > tol.linear ? (lo, hi) : null;
}

/// The floor planner's parametric types.
final ParametricCatalog boxCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType());

/// Builds and installs the document's parametric system.
ParametricSystem installBoxes(DraftDocument doc) =>
    ParametricSystem(doc, boxCatalog)..install();
