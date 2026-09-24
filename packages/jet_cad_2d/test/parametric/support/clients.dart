// Test-only parametric types. RectType duplicates the app's BoxType on
// purpose (Ruling 06-9): a fixture must not share a bug with the code it
// checks.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

abstract class RectParams implements Component {
  double get width;
  double get height;
}

final class ClipRect implements RectParams {
  const ClipRect(this.width, this.height);
  static const String id = 'test.clipRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static ClipRect fromJson(Map<String, Object?> j) => ClipRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is ClipRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

/// Same shape, but its parameter edits need only `components` (spec D7).
final class SoftRect implements RectParams {
  const SoftRect(this.width, this.height);
  static const String id = 'test.softRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static SoftRect fromJson(Map<String, Object?> j) => SoftRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is SoftRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

enum TripMode { off, throwing, reentrant, throwingReach }

/// A rectangle whose generation can be made to throw, or to call back into
/// the dispatcher (G6-G8).
final class Trip implements RectParams {
  const Trip(this.width, this.height);
  static const String id = 'test.trip';
  static TripMode mode = TripMode.off;
  static DraftDocument? document;
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static Trip fromJson(Map<String, Object?> j) =>
      Trip((j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Trip && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

RectParams? rectOf(ParametricView v, Handle h) =>
    v.paramsOf<ClipRect>(h) ?? v.paramsOf<SoftRect>(h) ?? v.paramsOf<Trip>(h);

List<Vector2> corners(RectParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// The open parameter interval of a->b strictly inside the convex quad [q],
/// or null. "Strictly": a segment lying on q's edge is outside.
(double, double)? insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
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
  return (hi - lo) * d.length > Tolerance.standard.linear ? (lo, hi) : null;
}

/// The rectangle [0,w]x[0,h] in local space, minus every neighbour's
/// interior: four edges in order, each split into ascending pieces.
List<Generated> clippedRect(ParametricView view, Handle self) {
  final p = rectOf(view, self)!;
  final toLocal = view.toWorld(self).invert();
  final quads = [
    for (final n in view.neighbours(self))
      if (rectOf(view, n) case final q?)
        [
          for (final c in corners(q))
            toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
        ],
  ];
  final c = corners(p);
  final out = <Generated>[];
  for (var i = 0; i < 4; i++) {
    final a = c[i], b = c[(i + 1) % 4];
    final len = (b - a).length;
    var keep = <(double, double)>[(0, 1)];
    for (final q in quads) {
      final inside = insideInterval(a, b, q);
      if (inside == null) continue;
      keep = [
        for (final (lo, hi) in keep) ...[
          if ((math.min(hi, inside.$1) - lo) * len > Tolerance.standard.linear)
            (lo, math.min(hi, inside.$1)),
          if ((hi - math.max(lo, inside.$2)) * len > Tolerance.standard.linear)
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

Aabb2 rectReach(RectParams p, Transform2 toWorld) =>
    Aabb2.fromPoints([for (final c in corners(p)) toWorld.transformPoint(c)]);

final class RectType<T extends RectParams> extends ParametricType<T> {
  const RectType(this.editCapability);
  @override
  final Capability editCapability;
  @override
  Aabb2 reach(T params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      clippedRect(view, self);
}

final class TripType extends ParametricType<Trip> {
  const TripType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Trip params, Transform2 toWorld) {
    // M-06w: a client's `reach` throwing on the *new* parameters, exercised
    // only for a non-positive width so the pre-edit survey (still the old
    // parameters) never trips it.
    if (Trip.mode == TripMode.throwingReach && params.width <= 0) {
      throw StateError('tripwire reach');
    }
    return rectReach(params, toWorld);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    switch (Trip.mode) {
      case TripMode.off:
      case TripMode.throwingReach:
        break;
      case TripMode.throwing:
        throw StateError('tripwire');
      case TripMode.reentrant:
        Trip.document!.commands
            .execute(SetComponentCommand<Trip>(self, const Trip(10, 10)));
    }
    return clippedRect(view, self);
  }
}

/// Generates one LINE and one ARC, in an order its parameter flips (M-06m).
final class Hinge implements Component {
  const Hinge(this.flip);
  static const String id = 'test.hinge';
  final bool flip;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'flip': flip};
  static Hinge fromJson(Map<String, Object?> j) => Hinge(j['flip']! as bool);
  @override
  bool operator ==(Object o) => o is Hinge && o.flip == flip;
  @override
  int get hashCode => flip.hashCode;
}

final class HingeType extends ParametricType<Hinge> {
  const HingeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Hinge params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(100, 100)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final line =
        Generated(EntityKind.line, linePayload(Vector2(0, 0), Vector2(100, 0)));
    final arc =
        Generated(EntityKind.arc, arcPayload(Vector2(50, 50), 40, 0.3, 1.2));
    return view.paramsOf<Hinge>(self)!.flip ? [arc, line] : [line, arc];
  }
}

ParametricCatalog testCatalog() => ParametricCatalog()
  ..register<ClipRect>(ClipRect.id, ClipRect.fromJson,
      const RectType<ClipRect>(Capability.geometry))
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType());
