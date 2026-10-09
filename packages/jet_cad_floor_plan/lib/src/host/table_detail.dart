// A table's detail for an embedding host (host embedding API spec G-1):
// what `FloorPlanTable` lacks -- its place, size, turn and mirror, its
// corners, its layer and lock -- in a new value type, so `FloorPlanTable`
// keeps its `==` (P-1, review V-2).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Aabb2, Transform2;

import 'floor_plan_types.dart';

/// One table of the active plan with its geometry (spec G-1), as
/// `FloorPlanController.tableDetails` lists it. World coordinates are
/// millimetres with y up. Never a handle (umbrella D18).
///
/// A table's placement is read as `R(rotation) · diag(sx, sy)` with
/// `sx > 0`: [mirrored] means `sy < 0`, the reading the table's number
/// label is stamped by. A table the planner neither shows nor picks -- on a
/// hidden layer, or a placement that is singular or has a corner that is
/// not finite -- reports no geometry: [center] and [size] null, [corners]
/// empty, [rotation] 0 and [mirrored] false.
@immutable
final class FloorPlanTableDetail {
  const FloorPlanTableDetail({
    required this.table,
    required this.center,
    required this.size,
    required this.rotation,
    required this.mirrored,
    required this.corners,
    required this.layer,
    required this.locked,
    this.data = const <String, String>{},
  });

  /// The table as [FloorPlanTable] carries it: number, seats, symbol,
  /// whether its layer is shown.
  final FloorPlanTable table;

  /// The centre of the table symbol's bounding box in the world: the box's
  /// own centre through the placement, not the placement's translation
  /// (the symbol's base point need not be the box's centre). Null when the
  /// table reports no geometry.
  final Offset? center;

  /// The symbol box's width and height in world millimetres: the box's
  /// width times the length of the placement's first column, its height
  /// times the length of the second. Null when the table reports no
  /// geometry.
  final Size? size;

  /// The table's turn, radians, counter-clockwise (y up), in `(-π, π]`:
  /// `atan2(b, a)` of the placement's linear part. 0 when the table
  /// reports no geometry.
  final double rotation;

  /// Whether the placement mirrors (its determinant is negative): the
  /// symbol's local y axis is flipped after the turn. False when the table
  /// reports no geometry.
  final bool mirrored;

  /// The symbol box's four corners in the world, counter-clockwise (y up)
  /// whatever the mirror, starting at the image of the box's (min x, min y)
  /// corner. Empty when the table reports no geometry. Unmodifiable as the
  /// controller lists it.
  final List<Offset> corners;

  /// The name of the instance's layer; empty when the layer is missing
  /// from the plan's layers (a hand-edited file).
  final String layer;

  /// Whether the instance's layer is locked: such a table is picked and
  /// tapped, never moved.
  final bool locked;

  /// The host's data on the table. Empty until host data is stored with a
  /// plan (spec E-6).
  final Map<String, String> data;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableDetail &&
      other.table == table &&
      other.center == center &&
      other.size == size &&
      other.rotation == rotation &&
      other.mirrored == mirrored &&
      listEquals(other.corners, corners) &&
      other.layer == layer &&
      other.locked == locked &&
      mapEquals(other.data, data);

  @override
  int get hashCode => Object.hash(
      table,
      center,
      size,
      rotation,
      mirrored,
      Object.hashAll(corners),
      layer,
      locked,
      Object.hashAllUnordered(
          [for (final e in data.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'FloorPlanTableDetail($table, center: $center, '
      'size: $size, rotation: $rotation, mirrored: $mirrored, '
      'corners: $corners, layer: $layer, locked: $locked, data: $data)';
}

/// The detail of [table], placed by [transform] (definition space to world)
/// over the symbol box [box] (definition space), whose world corners are
/// [corners] (`x0, y0, ..., x3, y3`: the box's (min, min), (max, min),
/// (max, max) and (min, max) through [transform], every one finite), as
/// `TableCandidate` carries them (spec F-8).
FloorPlanTableDetail tableDetailOf(
    {required FloorPlanTable table,
    required Transform2 transform,
    required Aabb2 box,
    required Float64List corners,
    required String layer,
    required bool locked}) {
  final m = transform;
  var rotation = math.atan2(m.b, m.a);
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  // `-0.0 == 0.0`, but their hash codes need not agree.
  if (rotation == 0) rotation = 0.0;
  final mirrored = m.determinant < 0;
  final cx = (box.minX + box.maxX) / 2, cy = (box.minY + box.maxY) / 2;
  Offset at(int i) => Offset(corners[2 * i], corners[2 * i + 1]);
  return FloorPlanTableDetail(
    table: table,
    center: Offset(m.a * cx + m.c * cy + m.e, m.b * cx + m.d * cy + m.f),
    size: Size((box.maxX - box.minX) * math.sqrt(m.a * m.a + m.b * m.b),
        (box.maxY - box.minY) * math.sqrt(m.c * m.c + m.d * m.d)),
    rotation: rotation,
    mirrored: mirrored,
    // A mirror turns the box's corner order clockwise: walked backwards
    // from the same first corner it is counter-clockwise again.
    corners: List.unmodifiable(
        mirrored ? [at(0), at(3), at(2), at(1)] : [at(0), at(1), at(2), at(3)]),
    layer: layer,
    locked: locked,
  );
}

/// The detail of a table that reports no geometry (spec G-1): on a hidden
/// layer, or no candidate of the picker.
FloorPlanTableDetail tableDetailWithoutGeometry(
        {required FloorPlanTable table,
        required String layer,
        required bool locked}) =>
    FloorPlanTableDetail(
        table: table,
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: const <Offset>[],
        layer: layer,
        locked: locked);
