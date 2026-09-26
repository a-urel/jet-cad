// SPIKE 10 -- throwaway. Fixtures for the room tracer: plans written in plan
// millimetres, placed at the origin, at the corpus's far origin and at
// +1e9 mm (1e6 m), rotated, with every wall at the identity or in its own
// rotated group. Expected areas are written out by hand in the tests.
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A centre-justified wall in plan millimetres.
typedef W = (double sx, double sy, double ex, double ey, double t);

/// A separator in plan millimetres.
typedef S = (double sx, double sy, double ex, double ey);

/// Where a plan is placed: plan point -> world point.
final class Placement {
  const Placement(this.name, this.dx, this.dy, this.deg, {this.groups = false});

  final String name;
  final double dx, dy, deg;

  /// Every wall and separator in its own rotated, translated group (06's
  /// M-06o lesson), its parameters the world points taken back through it.
  final bool groups;

  Transform2 get m => Transform2.translation(dx, dy)
      .multiply(Transform2.rotation(deg * math.pi / 180));

  Vector2 at(double x, double y) => m.transformPoint(Vector2(x, y));

  @override
  String toString() => name;
}

const origin = Placement('origin', 0, 0, 0);
const corpus = Placement('corpus far origin, 23 deg', 4500000, 1200000, 23);
const corpusGroups = Placement(
    'corpus far origin, 23 deg, own groups', 4500000, 1200000, 23,
    groups: true);
const km1000 = Placement('+1e9 mm (1e6 m), 23 deg', 1e9, 1e9, 23);
const km1000Axis = Placement('+1e9 mm (1e6 m), 0 deg', 1e9, 1e9, 0);
const km1000Groups = Placement(
    '+1e9 mm (1e6 m), 23 deg, own groups', 1e9, 1e9, 23,
    groups: true);

const placements = [
  origin,
  corpus,
  corpusGroups,
  km1000,
  km1000Axis,
  km1000Groups,
];

/// A group transform for object number [k] of a [Placement.groups] plan.
Transform2 _groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// A built plan: its document (the parametric system installed) and the
/// handles of its walls and separators, in the order given.
final class Plan {
  Plan(this.doc, this.place, this.walls, this.seps, this.system);
  final DraftDocument doc;
  final Placement place;
  final List<Handle> walls;
  final List<Handle> seps;
  final ParametricSystem system;

  Vector2 at(double x, double y) => place.at(x, y);
}

Plan buildPlan(List<W> walls,
    {List<S> seps = const [], Placement place = origin, DraftDocument? into}) {
  final doc = into ?? DraftDocument.empty();
  final system = installParametric(doc);
  ensureSeparatorLinetype(doc);
  final wh = <Handle>[], sh = <Handle>[];
  var k = 0;
  for (final (sx, sy, ex, ey, t) in walls) {
    final h = doc.handleSeed.next();
    final g = place.groups ? _groupFor(place, k++) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(place.at(sx, sy));
    final e = inv.transformPoint(place.at(ex, ey));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: g, children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(s.x, s.y, e.x, e.y, t, Justification.centre)),
    ], label: 'Add wall'));
    wh.add(h);
  }
  for (final (sx, sy, ex, ey) in seps) {
    sh.add(addSeparator(doc, place.at(sx, sy), place.at(ex, ey),
        at: place.groups ? _groupFor(place, k++) : null));
  }
  return Plan(doc, place, wh, sh, system);
}

/// A separator from world [s] to world [e], in group [at] (identity).
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

/// The Room tool's click at world [seed]: the room's handle, or null.
Handle? clickRoom(DraftDocument doc, Vector2 seed, String name) {
  final p = roomAt(doc, seed, name);
  if (p == null) return null;
  final h = doc.handleSeed.next();
  doc.commands.execute(addRoom(h, doc, p));
  return h;
}

/// Adds an opening to wall [host].
Handle addOpening(DraftDocument doc, OpeningParams o) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<OpeningParams>(h, o),
  ], label: 'Add opening'));
  return h;
}

/// The tracer over every wall and separator of [doc] (the all-walls
/// oracle of Q3, and the Room tool's own view).
TraceResult traceAll(DraftDocument doc, Vector2 seed) =>
    traceRoom(seed, documentInputs(doc));

double areaOf(TraceResult r) => (r as Traced).area;

/// [group]'s children, ascending.
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

EntityKind kindOf(DraftDocument doc, Handle h) =>
    doc.entities.kindAt(doc.entities.slotOf(h)!);

EntityRecord recordOf(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// A room's TEXT children's strings, in handle order.
List<String> labelsOf(DraftDocument doc, Handle room) => [
      for (final k in kids(doc, room))
        if (kindOf(doc, k) == EntityKind.text) recordOf(doc, k).text,
    ];

// ---------------------------------------------------------------------------
// The fixtures, in plan millimetres.

/// The sample plan's nine walls (startup_plan.dart, spec 08 D18), plan
/// coordinates with the flat's outer corner at (12000, 8000).
List<W> sampleWalls() {
  const x0 = 12000.0, y0 = 8000.0, x1 = 26000.0, y1 = 17000.0;
  const h = 125.0, e = 250.0, p = 120.0;
  return const [
    (x0 + h, y0 + h, x1 - h, y0 + h, e), // E1 south
    (x1 - h, y0 + h, x1 - h, y1 - h, e), // E2 east
    (x1 - h, y1 - h, x0 + h, y1 - h, e), // E3 north
    (x0 + h, y1 - h, x0 + h, y0 + h, e), // E4 west
    (x0 + 5000, y0 + h, x0 + 5000, y1 - h, p), // P1 hall/living
    (x0 + h, y0 + 5000, x0 + 5000, y0 + 5000, p), // P2 bedrooms
    (x0 + 5000, y0 + 3500, x1 - h, y0 + 3500, p), // P3 kitchen+bath/living
    (x0 + 2600, y0 + 5000, x0 + 2600, y1 - h, p), // P4 bed1/bed2
    (x0 + 9500, y0 + h, x0 + 9500, y0 + 3500, p), // P5 kitchen/bath
  ];
}

/// Seeds of the sample plan's six rooms, plan coordinates.
const sampleSeeds = {
  'Hall': (14500.0, 10500.0),
  'Bedroom 1': (13300.0, 15000.0),
  'Bedroom 2': (15800.0, 15000.0),
  'Kitchen': (19000.0, 10000.0),
  'Bath': (23500.0, 10000.0),
  'Living': (21000.0, 14000.0),
};

/// Decision 16's separator: Living | Dining at x0 + 9500, from P3's north
/// face (y0 + 3500 + 60) to E3's inner face (y1 - 250).
const S sampleSeparator = (21500.0, 11560.0, 21500.0, 16750.0);

/// Decision 16's column: one short thick wall, 400 x 400, in Living.
const W sampleColumn = (23500.0, 14000.0, 23900.0, 14000.0, 400.0);

/// An L (six walls, 200 mm, centre): drawn with mixed directions.
const List<W> lWalls = [
  (0, 0, 6000, 0, 200), // bottom, anticlockwise
  (6000, 3000, 6000, 0, 200), // right, drawn downwards (clockwise)
  (6000, 3000, 3000, 3000, 200), // step, anticlockwise
  (3000, 5000, 3000, 3000, 200), // step up, drawn downwards
  (3000, 5000, 0, 5000, 200), // top, anticlockwise
  (0, 0, 0, 5000, 200), // left, drawn upwards (clockwise)
];

/// A rectangle of four walls of differing thickness.
const List<W> mixedWalls = [
  (0, 0, 5000, 0, 300), // bottom
  (5000, 0, 5000, 4000, 100), // right
  (5000, 4000, 0, 4000, 200), // top
  (0, 4000, 0, 0, 250), // left
];

/// A rectangle 8000 x 4000 (200 mm) with a 100 mm partition at x = 3000,
/// T at both ends.
const List<W> twoRoomWalls = [
  (0, 0, 8000, 0, 200),
  (8000, 0, 8000, 4000, 200),
  (8000, 4000, 0, 4000, 200),
  (0, 4000, 0, 0, 200),
  (3000, 0, 3000, 4000, 100),
];

/// The same rectangle without the partition: a separator's box.
const List<W> boxWalls = [
  (0, 0, 8000, 0, 200),
  (8000, 0, 8000, 4000, 200),
  (8000, 4000, 0, 4000, 200),
  (0, 4000, 0, 0, 200),
];
