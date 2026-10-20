// A unit's section (spec D10-D12): the smallest declared area whose outline
// contains the unit's centre. The areas come from kit types that declare
// one (`PlanType.areaOf`); this library names no kit type.
import 'package:flutter/foundation.dart' show immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle, Tolerance;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'object_detail.dart';

/// The units whose section changed, as `PlanController.sectionChanges`
/// reports them: by label, each with the section it has now (null when it
/// stands in no area any more). Only units that exist before and after are
/// listed; a unit added or removed is a `PlanUnitAdded` or `PlanUnitRemoved`.
@immutable
final class PlanSectionChange {
  const PlanSectionChange(this.byLabel);

  /// The label of each unit whose section changed, and its section now.
  final Map<String, PlanObjectDetail?> byLabel;

  @override
  bool operator ==(Object other) =>
      other is PlanSectionChange &&
      other.byLabel.length == byLabel.length &&
      byLabel.entries.every((e) =>
          other.byLabel.containsKey(e.key) && other.byLabel[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
      [for (final e in byLabel.entries) Object.hash(e.key, e.value)]);

  @override
  String toString() => 'PlanSectionChange($byLabel)';
}

/// One declared area: [owner]'s outline, anticlockwise, in the world.
final class SectionArea {
  SectionArea(this.owner, List<Vector2> ring)
      : ring = List.unmodifiable(ring),
        size = _shoelace(ring).abs(),
        perimeter = _perimeter(ring);

  final Handle owner;
  final List<Vector2> ring;

  /// The outline's area (shoelace), square millimetres.
  final double size;

  /// The outline's length, millimetres: scales the band within which two
  /// areas are equal.
  final double perimeter;

  static double _perimeter(List<Vector2> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      sum += ring[i].distanceTo(ring[(i + 1) % ring.length]);
    }
    return sum;
  }

  static double _shoelace(List<Vector2> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i], b = ring[(i + 1) % ring.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  /// Whether ([x], [y]) is inside the outline; the boundary, within
  /// [tolerance], counts as inside.
  bool contains(double x, double y, Tolerance tolerance) {
    final n = ring.length;
    if (n < 3) return false;
    var inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final a = ring[j], b = ring[i];
      if (_onSegment(a, b, x, y, tolerance)) return true;
      if ((a.y > y) != (b.y > y) &&
          x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _onSegment(
      Vector2 a, Vector2 b, double x, double y, Tolerance t) {
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    var u = len2 == 0 ? 0.0 : ((x - a.x) * dx + (y - a.y) * dy) / len2;
    u = u < 0 ? 0 : (u > 1 ? 1 : u);
    final ex = a.x + u * dx - x, ey = a.y + u * dy - y;
    return ex * ex + ey * ey <= t.linear * t.linear;
  }
}

/// The areas of a plan, found once per unit-index rebuild.
final class SectionFinder {
  /// [areas] in any order.
  SectionFinder(List<SectionArea> areas)
      : _areas = [...areas]
          ..sort((a, b) => a.owner.value.compareTo(b.owner.value));

  final List<SectionArea> _areas;

  bool get isEmpty => _areas.isEmpty;

  /// The owner of the smallest area containing ([x], [y]); equal areas: the
  /// lower handle; null when none does. O(areas).
  Handle? sectionAt(double x, double y,
      {Tolerance tolerance = Tolerance.standard}) {
    SectionArea? best;
    for (final area in _areas) {
      if (!area.contains(x, y, tolerance)) continue;
      // Ascending handle: a strictly smaller area wins, an equal one keeps
      // the lower handle.
      // Equal within the linear tolerance's squared-unit band (a length
      // times the two perimeters), not 1e-9 mm^2 of float noise.
      if (best == null ||
          (area.size < best.size &&
              best.size - area.size >
                  tolerance.linear * (area.perimeter + best.perimeter))) {
        best = area;
      }
    }
    return best?.owner;
  }
}
