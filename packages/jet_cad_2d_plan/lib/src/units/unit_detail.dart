// A unit for an embedding host (spec 2b S3 "The unit API"): what the
// controller lists (PlanUnit), with its geometry, layer, lock and the
// host's data and colour (PlanUnitDetail), and the design's unit changes
// (PlanUnitChange). Ported from jet_cad_floor_plan's FloorPlanTable
// (host/floor_plan_types.dart:17-58), FloorPlanTableDetail and its builders
// (host/table_detail.dart) and the design changes (host/design_changes.dart).
// Never a handle (umbrella D18).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Aabb2, Handle, Transform2;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;

/// One unit of the active plan, as a host sees it: never a handle.
@immutable
final class PlanUnit {
  const PlanUnit(
      {required this.label,
      required this.kind,
      required this.capacity,
      required this.symbolKey,
      this.visible = true,
      this.generatedBy});

  /// The unit's label, trimmed, or null while it has none.
  final String? label;

  /// Its kind (`table`, `seat`, a kit's own): its definition's.
  final String kind;

  /// How many it serves: its definition's.
  final int capacity;

  /// The library key of its symbol, or null for a hand-made one.
  final String? symbolKey;

  /// Whether its layer is shown: false for a unit on a hidden layer, which
  /// the view neither shows nor lets anyone pick.
  final bool visible;

  /// The type id of the object that generates it (a seat's row), or null
  /// for a placed unit.
  final String? generatedBy;

  @override
  bool operator ==(Object other) =>
      other is PlanUnit &&
      other.label == label &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.symbolKey == symbolKey &&
      other.visible == visible &&
      other.generatedBy == generatedBy;

  @override
  int get hashCode =>
      Object.hash(label, kind, capacity, symbolKey, visible, generatedBy);

  @override
  String toString() => 'PlanUnit($label, $kind, $capacity, $symbolKey, '
      'visible: $visible${generatedBy == null ? '' : ', generatedBy: $generatedBy'})';
}

/// One unit of the active plan with its geometry (today's
/// `FloorPlanTableDetail`, table_detail.dart:14-124), as
/// `PlanController.unitDetails` lists it. World coordinates are
/// millimetres with y up. A unit's placement (its world transform: group ×
/// instance for a generated one) is read as `R(rotation) · diag(sx, sy)`
/// with `sx > 0`: [mirrored] means `sy < 0`. A unit the planner neither
/// shows nor picks -- on a hidden layer, or a placement that is singular or
/// has a corner that is not finite -- reports no geometry: [center] and
/// [size] null, [corners] empty, [rotation] 0 and [mirrored] false.
@immutable
final class PlanUnitDetail {
  const PlanUnitDetail({
    required this.unit,
    required this.center,
    required this.size,
    required this.rotation,
    required this.mirrored,
    required this.corners,
    required this.layer,
    required this.locked,
    this.data = const <String, String>{},
    this.colour,
  });

  final PlanUnit unit;

  /// The centre of the symbol's bounding box in the world.
  final Offset? center;

  /// The symbol box's width and height in world millimetres.
  final Size? size;

  /// The unit's turn, radians, counter-clockwise (y up), in `(-π, π]`.
  final double rotation;

  /// Whether the placement mirrors (its determinant is negative).
  final bool mirrored;

  /// The symbol box's four corners in the world, counter-clockwise (y up)
  /// whatever the mirror, starting at the image of the box's (min x, min
  /// y) corner. Unmodifiable as the controller lists it.
  final List<Offset> corners;

  /// The name of the instance's layer (a generated unit's is its object's);
  /// empty when the layer is missing from the plan's layers.
  final String layer;

  /// Whether the unit is locked (`isLockedUnit`: a locked layer, or a
  /// frozen or a missing kit's object or symbol): tapped and reported,
  /// never selected or moved.
  final bool locked;

  /// The host's data on the unit, keys ascending, unmodifiable. Empty for
  /// a unit with none, and for one whose stored data is outside the limits
  /// (kept as read, never refused).
  final Map<String, String> data;

  /// The unit's colour, or null for none and for a stored name this
  /// release cannot read (kept as read).
  final PlanSwatch? colour;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitDetail &&
      other.unit == unit &&
      other.center == center &&
      other.size == size &&
      other.rotation == rotation &&
      other.mirrored == mirrored &&
      listEquals(other.corners, corners) &&
      other.layer == layer &&
      other.locked == locked &&
      mapEquals(other.data, data) &&
      other.colour == colour;

  @override
  int get hashCode => Object.hash(
      unit,
      center,
      size,
      rotation,
      mirrored,
      Object.hashAll(corners),
      layer,
      locked,
      Object.hashAllUnordered(
          [for (final e in data.entries) Object.hash(e.key, e.value)]),
      colour);

  @override
  String toString() => 'PlanUnitDetail($unit, center: $center, '
      'size: $size, rotation: $rotation, mirrored: $mirrored, '
      'corners: $corners, layer: $layer, locked: $locked, data: $data'
      '${colour == null ? '' : ', colour: $colour'})';
}

/// The detail of [unit], placed by [transform] over the symbol box [box],
/// whose world corners are [corners] (`x0, y0, ..., x3, y3`, as
/// `UnitCandidate` carries them). table_detail.dart:132-167.
PlanUnitDetail unitDetailOf(
    {required PlanUnit unit,
    required Transform2 transform,
    required Aabb2 box,
    required Float64List corners,
    required String layer,
    required bool locked,
    Map<String, String> data = const <String, String>{},
    PlanSwatch? colour}) {
  final m = transform;
  var rotation = math.atan2(m.b, m.a);
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  if (rotation == 0) rotation = 0.0;
  final mirrored = m.determinant < 0;
  final cx = (box.minX + box.maxX) / 2, cy = (box.minY + box.maxY) / 2;
  Offset at(int i) => Offset(corners[2 * i], corners[2 * i + 1]);
  return PlanUnitDetail(
    unit: unit,
    center: Offset(m.a * cx + m.c * cy + m.e, m.b * cx + m.d * cy + m.f),
    size: Size((box.maxX - box.minX) * math.sqrt(m.a * m.a + m.b * m.b),
        (box.maxY - box.minY) * math.sqrt(m.c * m.c + m.d * m.d)),
    rotation: rotation,
    mirrored: mirrored,
    corners: List.unmodifiable(
        mirrored ? [at(0), at(3), at(2), at(1)] : [at(0), at(1), at(2), at(3)]),
    layer: layer,
    locked: locked,
    data: data,
    colour: colour,
  );
}

/// The detail of a unit that reports no geometry (table_detail.dart:
/// 169-188).
PlanUnitDetail unitDetailWithoutGeometry(
        {required PlanUnit unit,
        required String layer,
        required bool locked,
        Map<String, String> data = const <String, String>{},
        PlanSwatch? colour}) =>
    PlanUnitDetail(
        unit: unit,
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: const <Offset>[],
        layer: layer,
        locked: locked,
        data: data,
        colour: colour);

/// One change of the design's units (today's `FloorPlanDesignChange`), as
/// `PlanController.unitChanges` reports it.
@immutable
sealed class PlanUnitChange {
  const PlanUnitChange();
}

/// A unit now in the design that was not: placed, generated by a grown
/// row, or a delete undone (then [unit] equals the [PlanUnitRemoved.unit]
/// the delete reported, its data included).
final class PlanUnitAdded extends PlanUnitChange {
  const PlanUnitAdded(this.unit);
  final PlanUnitDetail unit;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitAdded && other.unit == unit;

  @override
  int get hashCode => Object.hash(PlanUnitAdded, unit);

  @override
  String toString() => 'PlanUnitAdded($unit)';
}

/// A unit no longer in the design: deleted, dropped by a shrunk row, or
/// its placement undone.
final class PlanUnitRemoved extends PlanUnitChange {
  const PlanUnitRemoved(this.unit);
  final PlanUnitDetail unit;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitRemoved && other.unit == unit;

  @override
  int get hashCode => Object.hash(PlanUnitRemoved, unit);

  @override
  String toString() => 'PlanUnitRemoved($unit)';
}

/// One unit whose detail changed: its label, kind, capacity, symbol,
/// geometry, layer, lock, visibility, data or colour. [before] and [after]
/// are the same unit (the same instance), whatever its label reads.
final class PlanUnitChanged extends PlanUnitChange {
  const PlanUnitChanged(this.before, this.after);
  final PlanUnitDetail before;
  final PlanUnitDetail after;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitChanged &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(PlanUnitChanged, before, after);

  @override
  String toString() => 'PlanUnitChanged($before, $after)';
}

/// The design was replaced whole (`load`, `newPlan`): a host reads
/// `unitDetails` again.
final class PlanUnitsReplaced extends PlanUnitChange {
  const PlanUnitsReplaced();

  @override
  bool operator ==(Object other) => other is PlanUnitsReplaced;

  @override
  int get hashCode => (PlanUnitsReplaced).hashCode;

  @override
  String toString() => 'PlanUnitsReplaced()';
}

/// The changes from [before] to [after] (design_changes.dart:101-129), each
/// list ascending by instance with [beforeInstances] and [afterInstances]
/// naming each entry's instance index for index. O(before + after).
List<PlanUnitChange> diffUnitDetails(
    List<Handle> beforeInstances,
    List<PlanUnitDetail> before,
    List<Handle> afterInstances,
    List<PlanUnitDetail> after) {
  final out = <PlanUnitChange>[];
  var i = 0, j = 0;
  while (i < before.length || j < after.length) {
    final a = i < before.length ? beforeInstances[i].value : null;
    final b = j < after.length ? afterInstances[j].value : null;
    if (b == null || (a != null && a < b)) {
      out.add(PlanUnitRemoved(before[i++]));
    } else if (a == null || b < a) {
      out.add(PlanUnitAdded(after[j++]));
    } else {
      if (before[i] != after[j]) {
        out.add(PlanUnitChanged(before[i], after[j]));
      }
      i++;
      j++;
    }
  }
  return out;
}
