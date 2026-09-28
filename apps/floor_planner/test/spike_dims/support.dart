// SPIKE 11 -- throwaway. Fixtures for the dimensions spike, over 10's room
// fixtures (plans in plan millimetres at six placements).
import 'dart:math' as math;

import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_geometry.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';

export '../support/room_fixture.dart';

/// A group transform for wall number [k] of a [Placement.groups] fixture (as
/// room_fixture's private one): a translation near the placement times a
/// rotation that is never a multiple of 90°.
Transform2 groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// [walls] as world walls at [place], handles 1, 2, ..., each in its own
/// group when [Placement.groups].
List<WorldWall> worldWalls(List<W> walls, Placement place) => [
      for (var i = 0; i < walls.length; i++)
        () {
          final w = walls[i];
          final g = place.groups ? groupFor(place, i) : Transform2.identity();
          final inv = g.invert();
          final s = inv.transformPoint(place.at(w.sx, w.sy));
          final e = inv.transformPoint(place.at(w.ex, w.ey));
          return WorldWall(
              Handle(i + 1), WallParams(s.x, s.y, e.x, e.y, w.t, w.j), g);
        }(),
    ];

/// Every other wall of [all] than [w].
List<WorldWall> othersOf(WorldWall w, List<WorldWall> all) => [
      for (final o in all)
        if (o.handle != w.handle) o,
    ];

/// A dimension at [a] -> [b], one compound, in a root group [at] (default
/// the identity). Returns its handle.
Handle addDimension(DraftDocument doc, DimEnd a, DimEnd b,
    {DimKind kind = DimKind.aligned, double offset = 500, Transform2? at}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: at ?? Transform2.identity(),
        children: const [])),
    SetComponentCommand<DimensionParams>(
        h, DimensionParams(a, b, kind, offset)),
  ], label: 'Add dimension'));
  return h;
}

/// A fixed end at world [w] in dimension group [at] (identity default).
FixedEnd fixedAt(Vector2 w, [Transform2? at]) {
  final l = (at ?? Transform2.identity()).invert().transformPoint(w);
  return FixedEnd(l.x, l.y);
}

/// The TEXT string of dimension [h].
String dimText(DraftDocument doc, Handle h) {
  final t = [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.text) k,
  ];
  return recordOf(doc, t.single).text;
}

/// Dimension [h]'s LINE children, world points, ascending handle: the
/// dimension line, the two extension lines, the two slashes.
List<(Vector2, Vector2)> dimLines(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.line)
        () {
          final c = payloadOf(doc, k).coords;
          return (
            m.transformPoint(Vector2(c[0], c[1])),
            m.transformPoint(Vector2(c[2], c[3]))
          );
        }(),
  ];
}

/// Dimension [h]'s TEXT: world insertion point, stored height, world
/// rotation (radians, the group's rotation added back).
(Vector2, double, double) dimTextGeometry(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  final t = [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.text) k,
  ].single;
  final p = payloadOf(doc, t);
  return (
    m.transformPoint(Vector2(p.coords[0], p.coords[1])),
    p.scalars[0] * m.scaleMagnitude,
    p.scalars[1] + math.atan2(m.b, m.a),
  );
}

/// Every wall of [doc] as a world wall.
List<WorldWall> allWorldWalls(DraftDocument doc) => [
      for (final h in doc.components.withComponent<WallParams>())
        WorldWall(h, doc.components.get<WallParams>(h)!,
            doc.tree.accumulatedTransform(h)),
    ];

/// The oracle for an end: an attached end's point among **every** wall of
/// the document (not the view's neighbours), a fixed end through its
/// group's transform.
Vector2 oracleEnd(DraftDocument doc, Handle dim, DimEnd end) {
  switch (end) {
    case FixedEnd():
      return doc.tree.accumulatedTransform(dim).transformPoint(end.point);
    case AttachedEnd(:final wall, :final k, :final side):
      final all = allWorldWalls(doc);
      final w = all.firstWhere((x) => x.handle == wall);
      return wallEndPoint(w, othersOf(w, all), k, side);
  }
}
