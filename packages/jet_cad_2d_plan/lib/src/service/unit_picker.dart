// Picking a unit (spec 2b S4 "The unit picker"; today's TablePicker, spec
// 14c S1, S2): a point inside a unit's top picks it, whatever else is drawn
// there; failing that, a point inside the unit symbol's bounding box (its
// chairs, the space between them) does; for a touch, failing both, the unit
// whose box is nearest within the finger's reach. Ported from
// jet_cad_floor_plan/lib/src/service/table_picker.dart over UnitIndex: placed
// and generated units alike, each through its world transform (group ×
// instance for a seat).
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../units/unit_index.dart';
import '../units/unit_label.dart' show firstLeafOf;

/// A unit's top in definition space (14s S4): its first leaf.
sealed class UnitTop {
  const UnitTop();

  /// Whether ([x], [y]) is inside, a point within [tolerance] of the
  /// boundary counting as inside (S1). [containsAt] with the point in a
  /// list of its own.
  bool contains(double x, double y, Tolerance tolerance) => containsAt(
      Float64List(2)
        ..[0] = x
        ..[1] = y,
      tolerance);

  /// [contains] for the point `(point[0], point[1])`. The picker's own
  /// call: the point reaches the top in a list it keeps, never as two
  /// doubles through this dynamic call, which the VM's JIT boxes unless it
  /// inlines the call -- two objects per table at every pick (Slice 2's
  /// final review F-2).
  bool containsAt(Float64List point, Tolerance tolerance);
}

/// A closed polyline's vertices, `x0, y0, x1, y1, ...`.
final class PolygonTop extends UnitTop {
  PolygonTop(this.xy);

  final Float64List xy;

  @override
  bool containsAt(Float64List point, Tolerance tolerance) {
    final x = point[0], y = point[1];
    final n = xy.length ~/ 2;
    if (n < 3) return false;
    var inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = xy[2 * i], yi = xy[2 * i + 1];
      final xj = xy[2 * j], yj = xy[2 * j + 1];
      if (_segmentDistance(x, y, xi, yi, xj, yj) <= tolerance.linear) {
        return true;
      }
      // Even-odd: a ray to +x crosses the edge.
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _segmentDistance(
      double px, double py, double ax, double ay, double bx, double by) {
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx - px, cy = ay + t * dy - py;
    return math.sqrt(cx * cx + cy * cy);
  }
}

/// A circle's centre and radius.
final class CircleTop extends UnitTop {
  const CircleTop(this.cx, this.cy, this.r);

  final double cx, cy, r;

  @override
  bool containsAt(Float64List point, Tolerance tolerance) {
    final dx = point[0] - cx, dy = point[1] - cy;
    return math.sqrt(dx * dx + dy * dy) <= r + tolerance.linear;
  }
}

/// The top of [definition] in [doc]: its lowest-handle leaf, when that is
/// a closed polyline (its last vertex repeating its first, by exact `==`)
/// or a circle; null otherwise (such a unit is picked by its box alone).
/// [leavesByOwner] as for [firstLeafOf]. (table_picker.dart:88-110.)
UnitTop? unitTopOf(DraftDocument doc, Handle definition,
    [Map<Handle, List<int>>? leavesByOwner]) {
  final leaf = firstLeafOf(doc, definition, leavesByOwner);
  if (leaf == null) return null;
  final payload = leaf.payload;
  switch (leaf.kind) {
    case EntityKind.circle:
      return CircleTop(
          payload.coords[0], payload.coords[1], payload.scalars[0]);
    case EntityKind.polyline:
      if (!isClosedPolyline(payload)) return null;
      final xy = payload.coords;
      return PolygonTop(
          Float64List.fromList(Float64List.sublistView(xy, 0, xy.length - 2)));
    default:
      return null;
  }
}

/// A unit the planner can show and act on (zone spec Z0): a unit on a
/// visible layer, its world transform's determinant finite and non-zero,
/// its box non-empty, the box's four corners finite in the world. The one
/// rule for the picker, the framing, the details and the focus.
final class UnitCandidate {
  UnitCandidate(
      {required this.unit,
      required this.transform,
      required this.box,
      required this.corners,
      required this.locked});

  final UnitInfo unit;

  /// Definition space to world: the unit's [UnitInfo.toWorld].
  final Transform2 transform;

  /// The symbol's bounding box in definition space.
  final Aabb2 box;

  /// [box]'s corners in the world, `x0, y0, ..., x3, y3`: its (min, min),
  /// (max, min), (max, max) and (min, max) through [transform].
  final Float64List corners;

  /// [UnitInfo.locked]: picked and reported, never selected or moved.
  final bool locked;

  /// The axis-aligned bound of [corners] (zone spec Z2).
  Aabb2 get worldBounds {
    var minX = corners[0], minY = corners[1], maxX = minX, maxY = minY;
    for (var i = 2; i < 8; i += 2) {
      minX = math.min(minX, corners[i]);
      maxX = math.max(maxX, corners[i]);
      minY = math.min(minY, corners[i + 1]);
      maxY = math.max(maxY, corners[i + 1]);
    }
    return Aabb2.raw(minX, minY, maxX, maxY);
  }
}

/// One unit the picker can hit.
final class PickCandidate {
  PickCandidate(
      {required this.unit,
      required this.inverse,
      required this.top,
      required this.box,
      required this.locked,
      required this.scale});

  final UnitInfo unit;

  /// World to definition space.
  final Transform2 inverse;

  /// Null when the first leaf is no top.
  final UnitTop? top;
  final Aabb2 box;
  final bool locked;

  /// The world transform's linear scale, `sqrt(|det|)`.
  final double scale;
}

/// The units of one document, ready to pick. The candidates are rebuilt
/// when [units] gives a new index (a state, a layer or a lock change),
/// never per pointer event; the tops and boxes are kept per definition for
/// the picker's life. A pick allocates nothing per unit (CLAUDE.md; the
/// ported `pick_allocation_test`, Task 14).
class UnitPicker {
  UnitPicker(this.document, this.units,
      {this.skipLocked = false,
      this.placedOnly = false,
      @visibleForTesting Map<Handle, List<int>> Function()? leavesByOwner,
      @visibleForTesting Transform2 Function(Transform2 transform)? invert})
      : _leavesByOwner = leavesByOwner ?? document.leavesByOwner,
        _invert = invert ?? _inverseOf;

  final DraftDocument document;
  final UnitIndexCache units;

  /// Whether [pick] passes over a locked unit as if it were not there (the
  /// design's units-only pick, today's `skipLocked: true`); false in
  /// service, which picks a locked unit and never selects it (spec S2).
  final bool skipLocked;

  /// Whether [pick] passes over a generated unit (the design's units-only
  /// pick: placed units only, spec S4).
  final bool placedOnly;

  final Map<Handle, List<int>> Function() _leavesByOwner;
  final Transform2 Function(Transform2 transform) _invert;

  static Transform2 _inverseOf(Transform2 transform) => transform.invert();

  /// The boundary tolerance: a point on a top's edge is inside.
  static const Tolerance tolerance = Tolerance(linear: 1e-6, angular: 1e-9);

  final Float64List _point = Float64List(2);
  List<PickCandidate> _candidates = const [];
  final Map<Handle, UnitTop?> _tops = {};
  final Map<Handle, Aabb2> _boxes = {};
  UnitIndex? _index;

  /// The candidates, ascending by instance handle.
  List<PickCandidate> get candidates {
    final index = units.current;
    if (!identical(index, _index)) {
      _candidates = _build(index);
      _index = index;
    }
    return _candidates;
  }

  List<PickCandidate> _build(UnitIndex index) {
    Map<Handle, List<int>>? leaves;
    Map<Handle, List<int>> scan() => leaves ??= _leavesByOwner();
    return [
      for (final c
          in candidatesOf(document, index, boxes: _boxes, leaves: scan))
        PickCandidate(
            unit: c.unit,
            inverse: _invert(c.transform),
            top: _tops.putIfAbsent(c.unit.definition,
                () => unitTopOf(document, c.unit.definition, scan())),
            box: c.box,
            locked: c.locked,
            scale: math.sqrt(c.transform.determinant.abs())),
    ];
  }

  /// The candidates of [index] over [document] (zone spec Z0), ascending by
  /// instance handle. [boxes] caches the definitions' boxes; [leaves] is
  /// [DraftDocument.leavesByOwner] or a stand-in, called at most once.
  /// O(units + entities) at document-change rate, never per frame.
  static List<UnitCandidate> candidatesOf(
      DraftDocument document, UnitIndex index,
      {required Map<Handle, Aabb2> boxes,
      required Map<Handle, List<int>> Function() leaves}) {
    final out = <UnitCandidate>[];
    Map<Handle, List<int>>? scanned;
    for (final u in index.units) {
      if (!u.visible) continue;
      final m = u.toWorld;
      final det = m.determinant;
      if (det == 0 || !det.isFinite) continue;
      final box = boxes.putIfAbsent(u.definition,
          () => document.definitionBounds(u.definition, scanned ??= leaves()));
      if (box.isEmpty) continue;
      final corners = Float64List(8);
      void corner(int i, double x, double y) {
        corners[2 * i] = m.a * x + m.c * y + m.e;
        corners[2 * i + 1] = m.b * x + m.d * y + m.f;
      }

      corner(0, box.minX, box.minY);
      corner(1, box.maxX, box.minY);
      corner(2, box.maxX, box.maxY);
      corner(3, box.minX, box.maxY);
      if (!corners.every((v) => v.isFinite)) continue;
      out.add(UnitCandidate(
          unit: u, transform: m, box: box, corners: corners, locked: u.locked));
    }
    return out;
  }

  /// Today's `TablePicker.pick` (table_picker.dart:306-363): the unit whose
  /// top holds [world], the highest handle among several; else the unit
  /// whose box holds it, the highest handle among several; else, with a
  /// [reach], the unit whose box is nearest within [reach] world units, the
  /// higher handle on a tie; else null. A unit [skipLocked] or [placedOnly]
  /// passes over is not there. Allocates nothing per unit.
  UnitInfo? pick(Vector2 world, {double reach = 0}) {
    final list = candidates;
    final storage = world.storage;
    final wx = storage[0], wy = storage[1];
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final top = c.top;
      if (top == null) continue;
      _point
        ..[0] = m.a * wx + m.c * wy + m.e
        ..[1] = m.b * wx + m.d * wy + m.f;
      if (top.containsAt(_point, tolerance)) return c.unit;
    }
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final x = m.a * wx + m.c * wy + m.e, y = m.b * wx + m.d * wy + m.f;
      if (_boxDistance(c.box, x, y) <= tolerance.linear) return c.unit;
    }
    if (reach <= 0) return null;
    PickCandidate? best;
    var bestDistance = reach;
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final x = m.a * wx + m.c * wy + m.e, y = m.b * wx + m.d * wy + m.f;
      final d = _boxDistance(c.box, x, y) * c.scale;
      if (d < bestDistance || (best == null && d <= bestDistance)) {
        best = c;
        bestDistance = d;
      }
    }
    return best?.unit;
  }

  bool _passes(PickCandidate c) =>
      (skipLocked && c.locked) || (placedOnly && c.unit.generated);

  /// The distance from ([x], [y]) to [box]; zero inside it.
  static double _boxDistance(Aabb2 box, double x, double y) {
    final dx = math.max(math.max(box.minX - x, x - box.maxX), 0.0);
    final dy = math.max(math.max(box.minY - y, y - box.maxY), 0.0);
    return math.sqrt(dx * dx + dy * dy);
  }
}
