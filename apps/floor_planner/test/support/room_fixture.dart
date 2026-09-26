// Fixtures for rooms (spec 10's Testing section), ported from the spike's
// `test/spike_rooms/support.dart`: plans written in plan millimetres, placed
// at six placements (the origin, the corpus's far origin and +1e9 mm, turned
// and not, with every wall and separator at the identity or in its own
// rotated, translated group). Expected areas are hand arithmetic in the
// tests; nothing here calls the tracer.
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall_fixture.dart' show payloadOf;

export 'wall_fixture.dart'
    show kids, kindOf, payloadOf, driftOf, diagnosticsOf, canon, reload, enc;

/// A wall in plan millimetres: its centreline, thickness and justification
/// (centre unless given).
final class W {
  const W(this.sx, this.sy, this.ex, this.ey, this.t,
      [this.j = Justification.centre]);

  final double sx, sy, ex, ey, t;
  final Justification j;
}

/// A separator in plan millimetres.
typedef S = (double sx, double sy, double ex, double ey);

/// An opening: the index of its host in the plan's wall list, its position
/// along the host's centreline, its width, kind and swing side.
typedef O = (
  int wall,
  double position,
  double width,
  OpeningKind kind,
  SwingSide swing
);

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

/// The six placements (the spec's Testing section; the plan's Global
/// constraints).
const placements = [
  origin,
  corpus,
  corpusGroups,
  km1000,
  km1000Axis,
  km1000Groups,
];

/// A group transform for object number [k] of a [Placement.groups] plan: a
/// translation near the placement times a rotation that is never a multiple
/// of 90°.
Transform2 _groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// A built plan: its document (the floor planner's parametric system
/// installed, the DASHED record written) and the handles of its walls,
/// separators and openings, in the order given.
final class Plan {
  Plan(this.doc, this.place, this.walls, this.seps, this.openings, this.system);
  final DraftDocument doc;
  final Placement place;
  final List<Handle> walls;
  final List<Handle> seps;
  final List<Handle> openings;
  final ParametricSystem system;

  Vector2 at(double x, double y) => place.at(x, y);
}

/// Builds [walls], then [seps], then [openings] (hosted by the walls they
/// index), each object one command, at [place].
Plan buildPlan(List<W> walls,
    {List<S> seps = const [],
    List<O> openings = const [],
    Placement place = origin}) {
  final doc = DraftDocument.empty();
  final system = installParametric(doc);
  ensureDashedLinetype(doc);
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[];
  var k = 0;
  for (final w in walls) {
    final h = doc.handleSeed.next();
    final g = place.groups ? _groupFor(place, k++) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(place.at(w.sx, w.sy));
    final e = inv.transformPoint(place.at(w.ex, w.ey));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: g, children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
    ], label: 'Add wall'));
    wh.add(h);
  }
  for (final (sx, sy, ex, ey) in seps) {
    sh.add(addSeparator(doc, place.at(sx, sy), place.at(ex, ey),
        at: place.groups ? _groupFor(place, k++) : null));
  }
  for (final (i, position, width, kind, swing) in openings) {
    oh.add(addOpening(
        doc, OpeningParams(wh[i], position, width, kind, swing: swing)));
  }
  return Plan(doc, place, wh, sh, oh, system);
}

/// A separator from world [s] to world [e], in its own root group [at]
/// (default the identity): its stored ends are [s] and [e] taken back
/// through [at].
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

/// Adds opening [o] in its own root group at the identity, one command.
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

// ---------------------------------------------------------------------------
// Entity helpers (07's `wall_fixture.dart` has the rest, re-exported above).

EntityRecord recordOf(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

/// Entity [h]'s payload points, less a closed polyline's repeated first
/// point, taken to world through its owner's accumulated transform.
List<Vector2> worldPoints(DraftDocument doc, Handle h, {bool closed = false}) {
  final slot = doc.entities.slotOf(h)!;
  final m = doc.tree.accumulatedTransform(doc.entities.ownerAt(slot));
  final c = payloadOf(doc, h).coords;
  final n = c.length ~/ 2 - (closed ? 1 : 0);
  return [
    for (var i = 0; i < n; i++)
      m.transformPoint(Vector2(c[2 * i], c[2 * i + 1])),
  ];
}

// ---------------------------------------------------------------------------
// The view adapter, seen from inside a view (Ruling 10-12).

/// What one view says about every live wall and separator: `RI1`'s probe.
typedef ViewInputs = ({
  /// The live walls and separators of the view, ascending.
  List<Handle> contributors,

  /// Each one's [roomInputInView].
  Map<Handle, RoomInput?> inputs,

  /// Each one's [placeBoxInView] and the engine's `placeBoxOf`, which asks
  /// the type.
  Map<Handle, Aabb2?> adapterBoxes,
  Map<Handle, Aabb2?> engineBoxes,

  /// Each one's `view.neighbours`, and the walls among them.
  Map<Handle, List<Handle>> neighbours,
  Map<Handle, List<Handle>> wallNeighbours,

  /// `view.placedIn` of the whole plane.
  List<Handle> placedAll,
});

/// The whole plane, as a box.
const Aabb2 everywhere = Aabb2.raw(double.negativeInfinity,
    double.negativeInfinity, double.infinity, double.infinity);

final class _ProbeParams implements Component {
  const _ProbeParams();
  static const String componentTypeId = 'test.room_inputs_probe';
  @override
  String get typeId => componentTypeId;
  @override
  Map<String, Object?> toJson() => const {};
  static _ProbeParams fromJson(Map<String, Object?> json) =>
      const _ProbeParams();
}

ViewInputs? _seen;

/// A test-only type whose `diagnose` records what its view says about every
/// live wall and separator (Ruling 10-12): a `ParametricView` exists only
/// inside a client call.
final class _Probe extends ParametricType<_ProbeParams> {
  const _Probe();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(_ProbeParams params, Transform2 toWorld) => Aabb2.empty();

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    final hs = [
      ...view.objectsOf<WallParams>(),
      ...view.objectsOf<SeparatorParams>(),
    ]..sort((a, b) => a.value.compareTo(b.value));
    _seen = (
      contributors: hs,
      inputs: {for (final h in hs) h: roomInputInView(view, h)},
      adapterBoxes: {for (final h in hs) h: placeBoxInView(view, h)},
      engineBoxes: {for (final h in hs) h: view.placeBoxOf(h)},
      neighbours: {for (final h in hs) h: view.neighbours(h)},
      wallNeighbours: {
        for (final h in hs)
          h: [
            for (final n in view.neighbours(h))
              if (view.paramsOf<WallParams>(n) != null) n,
          ],
      },
      placedAll: view.placedIn(everywhere),
    );
    return const [];
  }
}

/// [doc]'s walls and separators through the view adapter: a catalog of the
/// Wall, the Opening, the Separator and [_Probe], a system over [doc], and
/// one probe object (a root group, added as one command) whose `diagnose`
/// records its view. The probe relates to nothing: its reach is empty.
ViewInputs probeView(DraftDocument doc) {
  final catalog = ParametricCatalog()
    ..register<WallParams>(
        WallParams.componentTypeId, WallParams.fromJson, const WallType())
    ..register<OpeningParams>(OpeningParams.componentTypeId,
        OpeningParams.fromJson, const OpeningType())
    ..register<SeparatorParams>(SeparatorParams.componentTypeId,
        SeparatorParams.fromJson, const SeparatorType())
    ..register<_ProbeParams>(
        _ProbeParams.componentTypeId, _ProbeParams.fromJson, const _Probe());
  final system = ParametricSystem(doc, catalog);
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<_ProbeParams>(h, const _ProbeParams()),
  ], label: 'Add probe'));
  _seen = null;
  system.diagnostics();
  final seen = _seen!;
  _seen = null;
  return seen;
}

/// Whether [a] and [b] are the same box, bit for bit (`Aabb2` has no `==`).
bool sameBox(Aabb2? a, Aabb2? b) =>
    (a == null && b == null) ||
    (a != null &&
        b != null &&
        a.minX == b.minX &&
        a.minY == b.minY &&
        a.maxX == b.maxX &&
        a.maxY == b.maxY);

// ---------------------------------------------------------------------------
// The plans, in plan millimetres.

/// The sample plan's nine walls (`startup_plan.dart`, spec 08 D18), in its
/// order E1, E2, E3, E4, P1, P2, P3, P4, P5, with the flat's outer corner
/// at (12000, 8000): exterior 250 centred (inner faces x 12,250 and 25,750,
/// y 8,250 and 16,750), partitions 120 centred (faces ±60).
List<W> sampleWalls() {
  const x0 = 12000.0, y0 = 8000.0, x1 = 26000.0, y1 = 17000.0;
  const h = 125.0, e = 250.0, p = 120.0;
  return const [
    W(x0 + h, y0 + h, x1 - h, y0 + h, e), // E1 south
    W(x1 - h, y0 + h, x1 - h, y1 - h, e), // E2 east
    W(x1 - h, y1 - h, x0 + h, y1 - h, e), // E3 north
    W(x0 + h, y1 - h, x0 + h, y0 + h, e), // E4 west
    W(x0 + 5000, y0 + h, x0 + 5000, y1 - h, p), // P1 hall/living
    W(x0 + h, y0 + 5000, x0 + 5000, y0 + 5000, p), // P2 bedrooms
    W(x0 + 5000, y0 + 3500, x1 - h, y0 + 3500, p), // P3 kitchen+bath/living
    W(x0 + 2600, y0 + 5000, x0 + 2600, y1 - h, p), // P4 bed1/bed2
    W(x0 + 9500, y0 + h, x0 + 9500, y0 + 3500, p), // P5 kitchen/bath
  ];
}

/// The sample plan's fifteen openings (`startup_plan.dart`, spec 08 D18),
/// indexing [sampleWalls]: seven doors, eight windows.
const List<O> sampleOpenings = [
  (4, 5875, 900, OpeningKind.door, SwingSide.left),
  (4, 1375, 900, OpeningKind.door, SwingSide.right),
  (7, 2800, 800, OpeningKind.door, SwingSide.right),
  (5, 1075, 800, OpeningKind.door, SwingSide.right),
  (6, 2000, 800, OpeningKind.door, SwingSide.left),
  (6, 6500, 700, OpeningKind.door, SwingSide.left),
  (0, 6375, 1000, OpeningKind.door, SwingSide.left), // the front door
  (2, 12575, 1200, OpeningKind.window, SwingSide.left),
  (2, 9975, 1200, OpeningKind.window, SwingSide.left),
  (2, 6675, 1200, OpeningKind.window, SwingSide.left),
  (2, 3075, 1200, OpeningKind.window, SwingSide.left),
  (1, 1675, 1200, OpeningKind.window, SwingSide.left),
  (1, 6075, 1800, OpeningKind.window, SwingSide.left),
  (3, 6675, 1000, OpeningKind.window, SwingSide.left),
  (3, 2275, 1400, OpeningKind.window, SwingSide.left),
];

/// D23's separator: Living | Dining at x = 21,500, from P3's north face
/// (y 11,560) to E3's inner face (y 16,750).
const S sampleSeparator = (21500.0, 11560.0, 21500.0, 16750.0);

/// D23's column: one short thick wall, 400 × 400, x 23,500-23,900, y
/// 13,800-14,200, in Living. The sample plan's tenth wall.
const W sampleColumn = W(23500, 14000, 23900, 14000, 400);

/// D23's seven seeds, plan coordinates.
const Map<String, (double, double)> sampleSeeds = {
  'Hall': (14500, 10500),
  'Bedroom 1': (13300, 15000),
  'Bedroom 2': (15800, 15000),
  'Kitchen': (19000, 10000),
  'Bath': (23500, 10000),
  'Living': (24500, 16000),
  'Dining': (19000, 16000),
};

/// D23's plan: the nine walls and the column, the separator, and the
/// fifteen openings, at [place].
Plan samplePlan(Placement place) => buildPlan([...sampleWalls(), sampleColumn],
    seps: const [sampleSeparator], openings: sampleOpenings, place: place);

/// An L of six 200 mm walls, centred, drawn in mixed directions (spike).
/// Inner faces 100 in: 5,800 × 2,800 + 2,800 × 2,000 = 21,840,000.
const List<W> lWalls = [
  W(0, 0, 6000, 0, 200), // bottom, anticlockwise
  W(6000, 3000, 6000, 0, 200), // right, drawn downwards (clockwise)
  W(6000, 3000, 3000, 3000, 200), // step, anticlockwise
  W(3000, 5000, 3000, 3000, 200), // step up, drawn downwards
  W(3000, 5000, 0, 5000, 200), // top, anticlockwise
  W(0, 0, 0, 5000, 200), // left, drawn upwards (clockwise)
];

/// The L's door, window and gap (spike Q2j), indexing [lWalls].
const List<O> lOpenings = [
  (0, 1500, 900, OpeningKind.door, SwingSide.left),
  (1, 1500, 1200, OpeningKind.window, SwingSide.left),
  (5, 2500, 800, OpeningKind.gap, SwingSide.left),
];

/// A rectangle of four thicknesses, 300, 100, 200, 250, centred (spike).
/// Inner faces x 125..4,950, y 150..3,900: 4,825 × 3,750 = 18,093,750
/// (centrelines: 20,000,000).
const List<W> fourThickWalls = [
  W(0, 0, 5000, 0, 300), // bottom
  W(5000, 0, 5000, 4000, 100), // right
  W(5000, 4000, 0, 4000, 200), // top
  W(0, 4000, 0, 0, 250), // left
];

/// The justification mix `JM` (spec 10's Testing table): inner faces y 200,
/// x 6,000, y 3,850, x 250: 5,750 × 3,650 = 20,987,500.
const List<W> jmWalls = [
  W(0, 0, 6000, 0, 200, Justification.left),
  W(6000, 0, 6000, 4000, 100, Justification.right),
  W(6000, 4000, 0, 4000, 300),
  W(0, 0, 0, 4000, 250, Justification.right), // drawn upwards
];

/// Two rooms: an 8,000 × 4,000 rectangle of 200 mm walls with a 100 mm
/// partition at x = 3,000, T-joined at both ends (spike). Left 2,850 ×
/// 3,800 = 10,830,000; right 4,850 × 3,800 = 18,430,000.
const List<W> twoRoomWalls = [
  W(0, 0, 8000, 0, 200),
  W(8000, 0, 8000, 4000, 200),
  W(8000, 4000, 0, 4000, 200),
  W(0, 4000, 0, 0, 200),
  W(3000, 0, 3000, 4000, 100),
];

/// The same rectangle without the partition.
const List<W> boxWalls = [
  W(0, 0, 8000, 0, 200),
  W(8000, 0, 8000, 4000, 200),
  W(8000, 4000, 0, 4000, 200),
  W(0, 4000, 0, 0, 200),
];

/// A hollow column (spike Q2g): a 600 × 600 centreline square of 100 mm
/// walls, mitred; outer contour 700 × 700 = 490,000, courtyard 500 × 500 =
/// 250,000.
const List<W> hollowColumnWalls = [
  W(5000, 1500, 5600, 1500, 100),
  W(5600, 1500, 5600, 2100, 100),
  W(5600, 2100, 5000, 2100, 100),
  W(5000, 2100, 5000, 1500, 100),
];

/// The box's separator, face to face at x = 3,000 (spike Q2g): left 2,900 ×
/// 3,800 = 11,020,000; right 4,900 × 3,800 = 18,620,000, less the hollow
/// column's 490,000 when it stands there: 18,130,000.
const S boxSeparator = (3000.0, 100.0, 3000.0, 3900.0);

/// The box, the hollow column and the separator (spike Q2g).
Plan boxAndSeparatorPlan(Placement place) =>
    buildPlan([...boxWalls, ...hollowColumnWalls],
        seps: const [boxSeparator], place: place);

/// The triangle `TR` (spec 10 D7's certificate): centred 200 mm walls and a
/// column (the fourth wall) at the acute corner. Area 34,235,000 −
/// 585,000√5 ≈ 32,926,900.23, less the column's 160,000: ≈ 32,766,900.23.
const List<W> trWalls = [
  W(0, 0, 12000, 0, 200),
  W(12000, 0, 0, 6000, 200),
  W(0, 6000, 0, 0, 200),
  W(10000, 400, 10400, 400, 400), // the column
];

/// `TR`'s seed.
const (double, double) trSeed = (800, 800);

/// The fallback two-hop `FB` (spec 10 D16.3): W, V, U (a T into W), the
/// bottom, right and top, and X, in that order. R2's area 18,703,300; after
/// [fbXEditEnd] W falls back and a notch opens into R2: 18,708,300.
const List<W> fbWalls = [
  W(-2000, 0, 0, 0, 400), // W
  W(0, 0, 0, 3000, 100), // V
  W(-500, 0, -500, -3000, 100), // U
  W(-500, -3000, 3037, -3000, 100), // bottom
  W(3037, -3000, 3037, 3000, 100), // right
  W(3037, 3000, 0, 3000, 100), // top
  W(-2000, 0, -2000, -800, 100), // X
];

/// `FB`'s wall indices.
const int fbW = 0, fbX = 6;

/// `FB`'s room R2's seed.
const (double, double) fbSeed = (1500, 0);

/// `FB`'s edit: X's end moved to (−2000 + 800 cos 5°, −800 sin 5°), so X
/// meets W at 5°.
(double, double) get fbXEditEnd => (
      -2000 + 800 * math.cos(5 * math.pi / 180),
      -800 * math.sin(5 * math.pi / 180),
    );

/// A thin L (spike Q4a): arms 1,200 on the centrelines, 200 mm walls, so
/// 1,000 clear. Inner faces 100 in: 5,800 × 1,000 + 1,000 × 4,800 =
/// 10,600,000.
const List<W> thinLWalls = [
  W(0, 0, 6000, 0, 200),
  W(6000, 0, 6000, 1200, 200),
  W(6000, 1200, 1200, 1200, 200),
  W(1200, 1200, 1200, 6000, 200),
  W(1200, 6000, 0, 6000, 200),
  W(0, 6000, 0, 0, 200),
];
