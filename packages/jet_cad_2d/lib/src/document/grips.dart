import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../core/tolerance.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

/// What dragging a grip does (spec D3).
enum GripRole { stretch, radius, move }

/// One grip of one leaf, in the leaf's **owner** space (spec D3).
///
/// For a root-level leaf that is root space, which is world: the canvas, the
/// index and the oracle all descend from the identity and never apply the
/// root node's own transform (spec preamble, review finding #1).
final class Grip {
  const Grip(this.role, this.index, this.x, this.y);

  final GripRole role;

  /// Vertex index; quadrant 0..3; arc end 0 (start) or 1 (end); else 0.
  /// Not unique across roles — the tie-break uses the list ordinal
  /// (Ruling 03-2).
  final int index;

  final double x, y;

  /// Exact: a grip's position is a stored coordinate, not a decision.
  @override
  bool operator ==(Object other) =>
      other is Grip &&
      other.role == role &&
      other.index == index &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(role, index, x, y);

  @override
  String toString() => 'Grip(${role.name} $index @ $x, $y)';
}

/// First and last coordinate pairs equal, on three or more points — the
/// rule `triangulate.dart` closes a boundary by. A stored-value test, so `==`.
bool isClosedPolyline(GeometryPayload payload) {
  final n = payload.pointCount;
  if (n < 3) return false;
  final c = payload.coords;
  return c[0] == c[(n - 1) * 2] && c[1] == c[(n - 1) * 2 + 1];
}

/// Spec D3's grip set, in owner space. The list order is each grip's
/// ordinal, which D2's tie-break reads (Ruling 03-2).
List<Grip> leafGrips(EntityKind kind, GeometryPayload payload) {
  final c = payload.coords;
  switch (kind) {
    case EntityKind.line:
    case EntityKind.polyline:
      final n = payload.pointCount;
      // A closed polyline's last vertex *is* its first: vertex 0 stands for
      // both, so the shared corner has one grip and moves as one (D3).
      final count =
          kind == EntityKind.polyline && isClosedPolyline(payload) ? n - 1 : n;
      return [
        for (var i = 0; i < count; i++)
          Grip(GripRole.stretch, i, c[i * 2], c[i * 2 + 1]),
      ];
    case EntityKind.circle:
      if (payload.pointCount == 0 || payload.scalars.isEmpty) return const [];
      final cx = c[0], cy = c[1], r = payload.scalars[0];
      return [
        Grip(GripRole.move, 0, cx, cy),
        // The snap engine's own quadrant expression (`_considerSnapLeaf`),
        // so a radius grip sits bit for bit where a quadrant snap lands.
        for (var q = 0; q < 4; q++)
          Grip(GripRole.radius, q, cx + r * math.cos(q * (math.pi / 2)),
              cy + r * math.sin(q * (math.pi / 2))),
      ];
    case EntityKind.arc:
      if (payload.pointCount == 0 || payload.scalars.length < 3) {
        return const [];
      }
      final cx = c[0], cy = c[1];
      final r = payload.scalars[0];
      final start = payload.scalars[1];
      final sweep = payload.scalars[2];
      final end = start + sweep;
      final mid = start + sweep / 2;
      return [
        Grip(GripRole.move, 0, cx, cy),
        Grip(GripRole.stretch, 0, cx + r * math.cos(start),
            cy + r * math.sin(start)),
        Grip(GripRole.stretch, 1, cx + r * math.cos(end),
            cy + r * math.sin(end)),
        Grip(
            GripRole.radius, 0, cx + r * math.cos(mid), cy + r * math.sin(mid)),
      ];
    case EntityKind.point:
    case EntityKind.text:
    case EntityKind.attrib:
    case EntityKind.fill:
      // A point and a text move by their body; an attrib is never
      // root-level; a fill follows its boundary (D3).
      return const [];
  }
}

/// The payload [grip] dragged to [localTarget] (owner space), or null when
/// the result is degenerate — the preview then shows the object unchanged
/// and release dispatches nothing (spec D3).
///
/// Every coordinate and scalar the grip does not own is the stored double,
/// copied, never recomputed. Throws [ArgumentError] for a move grip (the
/// tool routes a centre grip to a move) and for a kind without grips.
GeometryPayload? reshapeLeaf(
    EntityKind kind, GeometryPayload payload, Grip grip, Vector2 localTarget) {
  if (grip.role == GripRole.move) {
    throw ArgumentError.value(
        grip, 'grip', 'a move grip is routed to a move, not a reshape');
  }
  final c = payload.coords;
  switch (kind) {
    case EntityKind.line:
    case EntityKind.polyline:
      final n = payload.pointCount;
      final i = grip.index;
      if (grip.role != GripRole.stretch || i < 0 || i >= n) {
        throw ArgumentError.value(
            grip, 'grip', 'not a vertex of this ${kind.name}');
      }
      final coords = Float64List.fromList(c);
      coords[i * 2] = localTarget.x;
      coords[i * 2 + 1] = localTarget.y;
      // The loop stays closed: the shared corner is written twice (M-03r).
      if (i == 0 && kind == EntityKind.polyline && isClosedPolyline(payload)) {
        coords[(n - 1) * 2] = localTarget.x;
        coords[(n - 1) * 2 + 1] = localTarget.y;
      }
      // Never degenerate: a zero-length segment is legal geometry. An
      // unfillable result is `SetEntityGeometryCommand`'s to drop.
      return GeometryPayload(
          coords: coords, scalars: Float64List.fromList(payload.scalars));
    case EntityKind.circle:
      if (grip.role != GripRole.radius) {
        throw ArgumentError.value(grip, 'grip', 'a circle reshapes by radius');
      }
      final r = _distance(localTarget, c[0], c[1]);
      if (r <= Tolerance.standard.linear) return null;
      final scalars = Float64List.fromList(payload.scalars)..[0] = r;
      return GeometryPayload(coords: Float64List.fromList(c), scalars: scalars);
    case EntityKind.arc:
      final s = payload.scalars;
      final scalars = Float64List.fromList(s);
      if (grip.role == GripRole.radius) {
        final r = _distance(localTarget, c[0], c[1]);
        if (r <= Tolerance.standard.linear) return null;
        scalars[0] = r;
      } else {
        if (grip.index != 0 && grip.index != 1) {
          throw ArgumentError.value(grip, 'grip', 'an arc has ends 0 and 1');
        }
        final start = s[1], sweep = s[2];
        final a = math.atan2(localTarget.y - c[1], localTarget.x - c[0]);
        final double nextStart;
        final double nextSweep;
        if (grip.index == 0) {
          // The end angle e = start + sweep stays; the sweep turns the
          // same way it did (D3).
          nextStart = a;
          nextSweep = _wrapSweep(start + sweep - a, sweep);
        } else {
          nextStart = start;
          nextSweep = _wrapSweep(a - start, sweep);
        }
        if (_degenerateSweep(nextSweep)) return null;
        scalars[1] = nextStart;
        scalars[2] = nextSweep;
      }
      return GeometryPayload(coords: Float64List.fromList(c), scalars: scalars);
    case EntityKind.point:
    case EntityKind.text:
    case EntityKind.attrib:
    case EntityKind.fill:
      throw ArgumentError.value(kind, 'kind', 'has no grips (spec D3)');
  }
}

double _distance(Vector2 p, double cx, double cy) {
  final dx = p.x - cx, dy = p.y - cy;
  return math.sqrt(dx * dx + dy * dy);
}

/// The value congruent to [raw] mod 2π that turns the way [direction] does:
/// in [0, 2π) for a positive sweep, (−2π, 0] for a negative one. The two
/// closed ends are [_degenerateSweep]'s business.
double _wrapSweep(double raw, double direction) {
  const twoPi = 2 * math.pi;
  final w = raw % twoPi; // Dart's % is Euclidean: w is in [0, 2π).
  return direction < 0 && w != 0 ? w - twoPi : w;
}

/// A decision, so `Tolerance` (spec D3, invariant 8).
bool _degenerateSweep(double sweep) {
  final a = sweep.abs();
  return a <= Tolerance.standard.angular ||
      (2 * math.pi - a) <= Tolerance.standard.angular;
}
