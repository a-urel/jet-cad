// Plans for the separator's integration tests, built through the plan
// library's build seam (spec 3a C1.9) with the kit's public names: walls
// and separators by command, each in its own root group, as today's room
// fixture adds them (jet_cad_floor_plan/test/support/room_fixture.dart:
// 118-178).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords, PlanKit;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A wall from world [s] to world [e], [thickness] thick, centred, in its
/// own root group [at] (the identity by default): its stored ends are [s]
/// and [e] taken back through [at]. One command.
Handle addWall(DraftDocument doc, Vector2 s, Vector2 e,
    {double thickness = 200, Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<WallParams>(
        h, WallParams(ls.x, ls.y, le.x, le.y, thickness, Justification.centre)),
  ], label: 'Add wall'));
  return h;
}

/// A separator from world [s] to world [e] in its own root group [at]
/// (room_fixture.dart:165-178's addSeparator).
Handle addSeparator(DraftDocument doc, Vector2 s, Vector2 e, {Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<SeparatorParams>(
        h, SeparatorParams(ls.x, ls.y, le.x, le.y)),
  ], label: 'Add separator'));
  return h;
}

/// room_fixture.dart:469-475's boxWalls: an 8,000 × 4,000 rectangle of
/// 200 mm walls, centred on their centrelines, in plan millimetres.
const List<(double, double, double, double)> boxWalls = [
  (0, 0, 8000, 0),
  (8000, 0, 8000, 4000),
  (8000, 4000, 0, 4000),
  (0, 4000, 0, 0),
];

/// Where the box's plan points go: centred on the world origin (a new
/// plan's sheet), then turned 23°.
final Transform2 boxPlace = Transform2.rotation(23 * math.pi / 180)
    .multiply(Transform2.translation(-4000, -2000));

Vector2 boxAt(double x, double y) => boxPlace.transformPoint(Vector2(x, y));

/// Wall [k]'s own group: today's `_groupFor` (room_fixture.dart:94-96) on
/// [boxPlace], a turn that is never a multiple of 90°.
Transform2 groupFor(int k) => boxPlace
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// A [PlanBuild]: [boxWalls] at [boxPlace], each wall in its own group.
void buildBox(DraftDocument doc, KitWords words) {
  for (final (k, (sx, sy, ex, ey)) in boxWalls.indexed) {
    addWall(doc, boxAt(sx, sy), boxAt(ex, ey), at: groupFor(k));
  }
}

/// A [PlanBuild]: a wall, and well clear of it (over 1 m) a separator in a
/// turned, mirrored group, both on a new plan's sheet (A4 landscape at 1:50
/// about the world origin).
void buildWallAndSeparator(DraftDocument doc, KitWords words) {
  addWall(doc, Vector2(-5000.25, 3000.5), Vector2(4000.75, 3600.25),
      at: Transform2.translation(120.5, -80.25)
          .multiply(Transform2.rotation(0.05)));
  addSeparator(doc, Vector2(-3000.5, -1200.25), Vector2(2500.75, 1800.5),
      at: Transform2.translation(-310.25, 140.5)
          .multiply(Transform2.rotation(0.3))
          .multiply(Transform2.scale(-1, 1)));
}

/// A [PlanBuild] of the sample flat's shape for new_document_test's ND4
/// (ruling R17-2): ten walls, each in its own turned group, and the page
/// off the world origin.
void buildTenWalls(DraftDocument doc, KitWords words) {
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, PageComponent(originX: 2100.5, originY: -1300.25)));
  for (var k = 0; k < 10; k++) {
    addWall(
        doc, Vector2(900.5 * k, 250.25), Vector2(900.5 * k + 600.75, 1700.5),
        at: Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5))
            .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9))));
  }
}

/// [architectureKit] without its prepare: a plan it writes has no DASHED
/// record (a file from a writer that never had one).
PlanKit get unpreparedKit => PlanKit(
      id: architectureKit.id,
      version: architectureKit.version,
      symbols: architectureKit.symbols,
      types: architectureKit.types,
      tools: architectureKit.tools,
      attachments: architectureKit.attachments,
      names: architectureKit.names,
    );

/// Separator [h]'s ends in world.
(Vector2, Vector2) separatorEnds(DraftDocument doc, Handle h) {
  final p = doc.components.get<SeparatorParams>(h)!;
  final t = doc.tree.accumulatedTransform(h);
  return (t.transformPoint(p.start), t.transformPoint(p.end));
}

/// The kit's DASHED record, written out (it is not exported):
/// jet_cad_floor_plan/lib/src/parametric/separator.dart:128-133.
const LinetypeRecord dashed = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);
