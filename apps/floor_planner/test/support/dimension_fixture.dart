// Fixtures for dimensions (spec 11's Testing section), over 10's room
// fixtures: the six placements, plans in plan millimetres, and the walls of
// spec 11 D4's hand-worked table. Expected points are hand arithmetic in the
// tests; nothing here computes an attach point.
//
// `groupFor`, `worldWalls` and `othersOf` are ported from the spike's
// support file (`spike/11-dimensions`,
// `apps/floor_planner/test/spike_dims/support.dart`); the C1-C10 walls from
// its `corner_test.dart`; C11 and the acute-L sweep from 07's `WR13`
// (`wall_regen_test.dart`); the flush-door fixtures from spec 11's flush
// probe (D10, S-13); `dimGridWalls` from 10's `room_cost_test.dart`;
// `addDimension`, `fixedAt`, `dimText`, `dimLines`, `dimTextGeometry` and
// `mmPage` from the spike's support file and its `rotate_test.dart`;
// `oracleEnd` and `oracleFailures` from its support file and its
// `drift_test.dart`, the oracle widened to every child (spec 11 D5).
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_fixture.dart';
import 'wall_fixture.dart' show addWallLocal, far, polar, wallDoc;

export 'room_fixture.dart';

/// A group transform for wall number [k] of a [Placement.groups] fixture:
/// a translation near the placement times a rotation that is never a
/// multiple of 90°. The same transform as `buildPlan`'s own (private) one,
/// so [worldWalls] and `buildPlan` place a plan's walls identically.
Transform2 groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// [walls] as world walls at [place], handles 1, 2, ..., each in its own
/// group when [Placement.groups] (its parameters the world points taken
/// back through it), at the identity otherwise.
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

/// The corpus far origin **unturned** (the plan's Ruling 11-9): the tool
/// places a dimension's group at the identity, so its horizontal and
/// vertical measure along world x and y.
const corpusAxis = Placement('corpus far origin, 0 deg', 4500000, 1200000, 0);

// ---------------------------------------------------------------------------
// Spec 11 D4's hand-worked cases, plan coordinates, mm.

/// C1: one free wall, (0, 0) -> (4000, 0), 200 centred.
const List<W> c1Walls = [W(0, 0, 4000, 0, 200)];

/// C2: an L, A east then B north, 200 each.
const List<W> c2Walls = [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)];

/// C3: the L with A 300 and B 100.
const List<W> c3Walls = [W(0, 0, 4000, 0, 300), W(4000, 0, 4000, 3000, 100)];

/// C4's three justifications with each wall's (left, right) face offsets
/// along its left normal: A 200 thick, B 120 thick (07 D2: centre
/// `(t/2, −t/2)`, left `(t, 0)`, right `(0, −t)`).
const List<(Justification, double, double)> c4A = [
  (Justification.centre, 100, -100),
  (Justification.left, 200, 0),
  (Justification.right, 0, -200),
];
const List<(Justification, double, double)> c4B = [
  (Justification.centre, 60, -60),
  (Justification.left, 120, 0),
  (Justification.right, 0, -120),
];

/// C4: the L of C2 with A 200 justified [ja] and B 120 justified [jb].
List<W> c4Walls(Justification ja, Justification jb) =>
    [W(0, 0, 4000, 0, 200, ja), W(4000, 0, 4000, 3000, 120, jb)];

/// C5: a T. The through wall C (0, 0) -> (6000, 0), 200; the stem S from
/// (2500, 0) north, 100 centred.
const List<W> c5Walls = [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)];

/// C5b: the stem drawn the other way, ending (`k = 1`) on C.
const List<W> c5bWalls = [
  W(0, 0, 6000, 0, 200),
  W(2500, 3000, 2500, 0, 100),
];

/// C5c: the stem south of C, 100 left-justified.
const List<W> c5cWalls = [
  W(0, 0, 6000, 0, 200),
  W(2500, 0, 2500, -3000, 100, Justification.left),
];

/// C6: an X, two 200 mm walls crossing mid-span.
const List<W> c6Walls = [
  W(0, 0, 4000, 0, 200),
  W(2000, -2000, 2000, 2000, 200),
];

/// C7: a Y, three 200 mm walls out of (0, 0) at 0°, 120° and 240°, 3000
/// long.
final List<W> c7Walls = [
  const W(0, 0, 3000, 0, 200),
  W(0, 0, 3000 * math.cos(2 * math.pi / 3), 3000 * math.sin(2 * math.pi / 3),
      200),
  W(0, 0, 3000 * math.cos(4 * math.pi / 3), 3000 * math.sin(4 * math.pi / 3),
      200),
];

/// C8: a + node, four 200 mm walls out of (0, 0) at 0°, 90°, 180°, 270°,
/// 3000 long.
const List<W> c8Walls = [
  W(0, 0, 3000, 0, 200),
  W(0, 0, 0, 3000, 200),
  W(0, 0, -3000, 0, 200),
  W(0, 0, 0, -3000, 200),
];

/// C9: 07's short-wall fallback. A short base A (0, 0) -> (100, 0) between
/// B north from its end and C north from its start, all 200.
const List<W> c9Walls = [
  W(0, 0, 100, 0, 200),
  W(100, 0, 100, 3000, 200),
  W(0, 0, 0, 3000, 200),
];

/// C10: degenerate walls (07 D2): a zero thickness, a zero length, and a
/// length of 5e-7 mm, at or below `wallJoin.linear` but not zero. The first
/// two have no face offset or no direction, so a free cap at their end would
/// collapse onto it; the third's free cap would not (its faces would lie
/// ±100 off), so only it tells "every side is the centreline end" from "a
/// degenerate wall's faces from its free caps".
const List<W> c10Walls = [
  W(0, 0, 4000, 0, 0),
  W(0, 1000, 0, 1000, 200),
  W(0, 2000, 5e-7, 2000, 200),
];

/// C11's and the sweep's hub: 07's `WR13` hub, at the far origin.
final Vector2 c11Hub = far(1234.5, 678.25);

/// The rotation about [hub] by [deg] degrees, applied to a group at the
/// identity: 07's `rotateAbout` (`T(hub)·R·T(−hub)` premultiplied onto the
/// node's transform).
Transform2 turnedAbout(Vector2 hub, double deg) =>
    Transform2.translation(hub.x, hub.y)
        .multiply(Transform2.rotation(deg * math.pi / 180))
        .multiply(Transform2.translation(-hub.x, -hub.y))
        .multiply(Transform2.identity());

/// C11 (spec 11 D4), 07's `WR13` (`wall_regen_test.dart`): A 200
/// right-justified into the hub from `far(−2500, 678.25)`, B 200
/// left-justified out of it at 178°, 600 long, both drawn at the identity,
/// then turned [turn] degrees (`WR13`'s 133° by default) about the hub.
/// Handles 1 and 2 (A the lower, as in `WR13`). At 133° A's world outline
/// is simple and its local image is not, so 07 stores A's free rectangle in
/// local space (a premise `AP2` asserts). Whether the local image folds is
/// rounding, so it depends on the turn and on a group's scale: `AP2`'s
/// scaled variant takes a turn where it does, and asserts it.
List<WorldWall> c11({double turn = 133}) {
  final g = turnedAbout(c11Hub, turn);
  final a0 = far(-2500, 678.25), b1 = polar(c11Hub, 178, 600);
  return [
    WorldWall(
        const Handle(1),
        WallParams(a0.x, a0.y, c11Hub.x, c11Hub.y, 200, Justification.right),
        g),
    WorldWall(const Handle(2),
        WallParams(c11Hub.x, c11Hub.y, b1.x, b1.y, 200, Justification.left), g),
  ];
}

/// 07's `WR13` sweep (`expectAcuteLRotates`): A from `polar(hub, 180,
/// 3734.5)` into [c11Hub] justified [ja], B out of it at `180 − deg`, 600
/// long, justified [jb], both 200, drawn at the identity and turned [turn]
/// degrees about the hub. Handles 1 and 2.
List<WorldWall> acuteL(
    double deg, double turn, Justification ja, Justification jb) {
  final g = turnedAbout(c11Hub, turn);
  final a0 = polar(c11Hub, 180, 3734.5), b1 = polar(c11Hub, 180 - deg, 600);
  return [
    WorldWall(const Handle(1),
        WallParams(a0.x, a0.y, c11Hub.x, c11Hub.y, 200, ja), g),
    WorldWall(const Handle(2),
        WallParams(c11Hub.x, c11Hub.y, b1.x, b1.y, 200, jb), g),
  ];
}

/// The sweep's parameters (`wall_regen_test.dart`'s `WR13`): acute Ls of 2,
/// 3, 4.5 and 5°, three justification pairs, four turns.
const List<double> acuteDegrees = [2.0, 3.0, 4.5, 5.0];
const List<(Justification, Justification)> acuteJustifications = [
  (Justification.right, Justification.left),
  (Justification.left, Justification.right),
  (Justification.right, Justification.right),
];
const List<double> acuteTurns = [17.0, 133.0, 211.5, 299.0];

/// [walls] with each group wrapped in a uniform [scale] (file only: no
/// gesture scales a group): the group becomes `toWorld · S(scale)` and the
/// parameters' points are taken back through `S(scale)`, so the world
/// centreline is the same to rounding, while the stored thickness is kept
/// and so drawn `t · scale` thick.
List<WorldWall> scaledGroups(List<WorldWall> walls, [double scale = 1.5]) => [
      for (final w in walls)
        () {
          final s = Transform2.scale(scale, scale);
          final inv = s.invert();
          final p = w.params;
          final a = inv.transformPoint(p.start), b = inv.transformPoint(p.end);
          return WorldWall(
              w.handle,
              WallParams(a.x, a.y, b.x, b.y, p.thickness, p.justification),
              w.toWorld.multiply(s));
        }(),
    ];

/// A document holding [walls], each one command in its own root group at
/// its `toWorld` with its parameters, in order, with the floor planner's
/// parametric system installed (so the walls generate). The document's
/// handles are its own, ascending in [walls]' order; they are returned in
/// that order.
(DraftDocument, List<Handle>) docOfWalls(List<WorldWall> walls) {
  final doc = wallDoc();
  final hs = <Handle>[];
  for (final w in walls) {
    final h = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(doc, h, w.params, w.toWorld));
    hs.add(h);
  }
  return (doc, hs);
}

/// Every live wall of [doc] as a world wall, ascending by handle: its
/// stored parameters under its group's accumulated transform.
List<WorldWall> allWorldWalls(DraftDocument doc) => [
      for (final h
          in doc.components.withComponent<WallParams>().toList()
            ..sort((a, b) => a.value.compareTo(b.value)))
        WorldWall(h, doc.components.get<WallParams>(h)!,
            doc.tree.accumulatedTransform(h)),
    ];

/// The brute-force attach candidates at world point [q] (spec 11 D10's
/// oracle, Tasks 3 and 4): every live wall of [doc] (a root-level group
/// carrying `WallParams`), each of its six points computed among every
/// other live wall (the document adapter, `wallsInDocument`), and every
/// `(W, k, side)` whose point lies within `dimAttach.linear` of [q],
/// Euclidean. Ascending by wall handle, then `k`, then side (left, centre,
/// right). No index, no line test.
List<AttachedEnd> bruteCandidates(DraftDocument doc, Vector2 q) {
  final out = <AttachedEnd>[];
  final hs = doc.components.withComponent<WallParams>().toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final h in hs) {
    final ws = wallsInDocument(doc, h);
    if (ws == null) continue;
    for (final (k, side, p) in wallEndPoints(ws.host, ws.walls)) {
      if ((p - q).length <= dimAttach.linear) out.add(AttachedEnd(h, k, side));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Flush openings (spec 11 D10, S-13): a door whose cut ends exactly at a
// flat wall end, so none of that end's three points is stored.

/// Spike C5's T at [place] with a 900 mm door on the stem: the through wall
/// C (0, 0) -> (6000, 0), 200, and the stem S (2500, 0) -> (2500, 3000),
/// 100, both centred; the door on S centred at [c] along S's centreline,
/// swinging to [swing]. C's face is at y = 100, so S's first stretch starts
/// at 100 along S: at `c` = 450 the cut `[0, 900]` is clamped to `[100,
/// 1000]` (`placeCut`), and at `c` = 550 it is `[100, 1000]` itself; either
/// way it is flush with S's butt end. `walls` is `[C, S]`, `openings` the
/// door.
Plan flushT(Placement place,
        {double c = 450, SwingSide swing = SwingSide.left}) =>
    buildPlan(c5Walls,
        openings: [(1, c, 900, OpeningKind.door, swing)], place: place);

/// A free wall A (0, 0) -> (4000, 0), 200 centred, at [place], with a 900 mm
/// door centred at 450 along it, swinging to [swing]: the cut `[0, 900]`
/// is flush with A's free start. `walls` is `[A]`.
Plan flushFree(Placement place, {SwingSide swing = SwingSide.left}) =>
    buildPlan(const [W(0, 0, 4000, 0, 200)],
        openings: [(0, 450, 900, OpeningKind.door, swing)], place: place);

/// [flushFree] with A's group scaled [scale] (file only: no gesture scales
/// a group; the plan's `X4-thickestStored` clause): A is `scaledGroups`'
/// image of the free wall at [place], so its world centreline is (0, 0) ->
/// (4000, 0) and its stored thickness 200 is drawn `200 · scale` thick where
/// 08 lays it out in the group's frame. The door is stored in A's local
/// frame, centred 450 along it, 900 wide, so its cut starts at A's free
/// start whatever the scale. Returns the document, A and the door.
(DraftDocument, Handle, Handle) flushFreeScaled(Placement place,
    {SwingSide swing = SwingSide.left, double scale = 1.5}) {
  final (doc, hs) = docOfWalls(
      scaledGroups(worldWalls(const [W(0, 0, 4000, 0, 200)], place), scale));
  ensureDashedLinetype(doc);
  final door = addOpening(
      doc, OpeningParams(hs[0], 450, 900, OpeningKind.door, swing: swing));
  return (doc, hs[0], door);
}

// ---------------------------------------------------------------------------
// Cost fixtures.

/// The side of a cell of [dimGridWalls], mm.
const double dimGridCell = 3000;

/// A grid of [rows] × [cols] cells of [dimGridCell], 200 mm centred walls,
/// one wall per cell edge, so four walls meet at every inner node: `2rc + r
/// + c` walls (17 × 17 gives 612, the grid nearest 600 walls, as 10's `RK2`
/// picks it). Copied from 10's `gridWalls` (`room_cost_test.dart`), the
/// plan's Ruling 11-22: a test file is never imported from another.
List<W> dimGridWalls(int rows, int cols) => [
      for (var r = 0; r <= rows; r++)
        for (var c = 0; c < cols; c++)
          W(c * dimGridCell, r * dimGridCell, (c + 1) * dimGridCell,
              r * dimGridCell, 200),
      for (var c = 0; c <= cols; c++)
        for (var r = 0; r < rows; r++)
          W(c * dimGridCell, r * dimGridCell, c * dimGridCell,
              (r + 1) * dimGridCell, 200),
    ];

/// The wall of `dimGridWalls(17, 17)` that `TL8`'s hover path crosses: row
/// 8's ninth horizontal wall, (24,000, 24,000) -> (27,000, 24,000), index
/// 8 · 17 + 8 = 144 (the horizontal walls come first, row by row).
const int dimGridPathWall = 8 * 17 + 8;

/// `dimGridWalls(17, 17)`, 612 walls, at the origin, with one 900 mm door
/// on [dimGridPathWall] centred 1,500 along it, swinging left: its cut runs
/// x 25,050-25,950 (the plan's Ruling 11-22, `TL8`).
Plan dimGridDoor() => buildPlan(dimGridWalls(17, 17), openings: const [
      (dimGridPathWall, 1500, 900, OpeningKind.door, SwingSide.left),
    ]);

// ---------------------------------------------------------------------------
// Dimensions (Task 6).

/// A page at 1:50 in millimetres: the unit whose value strings are the
/// integer millimetres a hand value states.
PageComponent get mmPage =>
    PageComponent().copyWith(displayUnit: DisplayUnit.millimeters);

/// A dimension from [a] to [b], of [kind], at [offset] (local units), in its
/// own root group at [at] (default the identity): the commit the Dimension
/// tool makes, a group and its `DimensionParams`, one compound. Its handle
/// is allocated here, before the compound runs. Returns it.
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

/// A fixed end at world point [w] in a dimension group at [at] (default the
/// identity): [w] taken back through the group.
FixedEnd fixedAt(Vector2 w, [Transform2? at]) {
  final l = (at ?? Transform2.identity()).invert().transformPoint(w);
  return FixedEnd(l.x, l.y);
}

/// Dimension [h]'s TEXT child: its one TEXT.
Handle dimTextHandle(DraftDocument doc, Handle h) => [
      for (final k in kids(doc, h))
        if (kindOf(doc, k) == EntityKind.text) k,
    ].single;

/// Dimension [h]'s value string.
String dimText(DraftDocument doc, Handle h) =>
    recordOf(doc, dimTextHandle(doc, h)).text;

/// Dimension [h]'s LINE children, world points, ascending by handle: the
/// dimension line, the extension lines at `a` and `b`, the slashes at `a`
/// and `b`.
List<(Vector2, Vector2)> dimLines(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  return [
    for (final k in kids(doc, h))
      if (kindOf(doc, k) == EntityKind.line)
        () {
          final c = payloadOf(doc, k).coords;
          return (
            m.transformPoint(Vector2(c[0], c[1])),
            m.transformPoint(Vector2(c[2], c[3])),
          );
        }(),
  ];
}

/// Dimension [h]'s TEXT in world: its insertion point, its height (the
/// stored height times the group's scale) and its rotation (radians, the
/// stored rotation plus the group's world rotation).
(Vector2, double, double) dimTextGeometry(DraftDocument doc, Handle h) {
  final m = doc.tree.accumulatedTransform(h);
  final p = payloadOf(doc, dimTextHandle(doc, h));
  return (
    m.transformPoint(Vector2(p.coords[0], p.coords[1])),
    p.scalars[0] * m.scaleMagnitude,
    p.scalars[1] + math.atan2(m.b, m.a),
  );
}

// ---------------------------------------------------------------------------
// The all-walls oracle (Task 8; spec 11 D5, the Differential check).

/// The world point of [end] of dimension [dim] as the oracle reads it
/// (spec 11 D5): an attached end among **every** live wall of [doc] (the
/// document adapter, `wallsInDocument`, not the view's reach neighbours),
/// a fixed end through the dimension's group. Null where D7 calls the end
/// broken: a wall that is not a live wall, a `k` outside {0, 1}, a
/// non-finite fixed coordinate. Ported from the spike's `oracleEnd`.
Vector2? oracleEnd(DraftDocument doc, Handle dim, DimEnd end) {
  switch (end) {
    case FixedEnd(:final x, :final y):
      if (!x.isFinite || !y.isFinite) return null;
      return doc.tree.accumulatedTransform(dim).transformPoint(end.point);
    case AttachedEnd(:final wall, :final k, :final side):
      if (k != 0 && k != 1) return null;
      final ws = wallsInDocument(doc, wall);
      if (ws == null) return null;
      return wallEndPoint(ws.host, ws.walls, k, side);
  }
}

/// Every live dimension of [doc] (a root-level group carrying
/// `DimensionParams`) checked against the all-walls oracle (spec 11 D5):
/// its ends from [oracleEnd], re-laid out by `layoutDimension` (Ruling
/// 11-3) on the page [pageOf] gives, then compared with its stored
/// children:
///
/// - the TEXT's string exactly;
/// - every LINE's two world points, and the TEXT's world insertion point,
///   within 1e-6 mm;
/// - the TEXT's world height and rotation within 1e-9;
/// - no child at all where the oracle finds the dimension broken (an end,
///   the offset, or no layout).
///
/// The layout is shared with the code under test, so this is differential
/// for the closure (which dimensions rebuild, from which walls), not for
/// the layout (D5). Returns one line per failure, empty when all agree.
List<String> oracleFailures(DraftDocument doc) {
  final out = <String>[];
  final page = pageOf(doc);
  final dims = doc.components.withComponent<DimensionParams>().toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  for (final h in dims) {
    final node = doc.tree[h];
    if (node is! GroupNode || node.parent != doc.tree.root) continue;
    final p = doc.components.get<DimensionParams>(h)!;
    final name = h.toHex();
    final p0 = oracleEnd(doc, h, p.a), p1 = oracleEnd(doc, h, p.b);
    final m = doc.tree.accumulatedTransform(h);
    final want = p0 == null || p1 == null || !p.offset.isFinite
        ? null
        : layoutDimension(p0, p1, p.kind, m, p.offset, page);
    final ks = kids(doc, h);
    if (want == null) {
      if (ks.isNotEmpty) out.add('$name: ${ks.length} children, want none');
      continue;
    }
    if (ks.length != 6) {
      out.add('$name: ${ks.length} children, want 6');
      continue;
    }
    final text = dimText(doc, h);
    if (text != want.text) out.add('$name: text $text, want ${want.text}');
    final lines = dimLines(doc, h);
    final pairs = [
      (want.q0, want.q1),
      want.ext0,
      want.ext1,
      want.slash0,
      want.slash1,
    ];
    for (var i = 0; i < pairs.length; i++) {
      final err = math.max((lines[i].$1 - pairs[i].$1).length,
          (lines[i].$2 - pairs[i].$2).length);
      if (!(err <= 1e-6)) out.add('$name: line $i off by $err mm');
    }
    final (at, height, angle) = dimTextGeometry(doc, h);
    final atErr = (at - want.textAt).length;
    if (!(atErr <= 1e-6)) out.add('$name: text point off by $atErr mm');
    final hErr = (height - want.textHeight).abs();
    if (!(hErr <= 1e-9)) out.add('$name: text height off by $hErr');
    final aErr = (angle - want.textAngle).abs();
    if (!(aErr <= 1e-9)) out.add('$name: text angle off by $aErr');
  }
  return out;
}
