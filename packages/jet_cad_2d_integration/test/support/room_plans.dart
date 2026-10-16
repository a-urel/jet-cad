// Room plans for the integration tests (spec 3a C6): the kit's room
// fixture's plans (jet_cad_floor_plan/test/support/room_fixture.dart, whose
// plan model and helpers are copied here), built in code by a PlanBuild
// over the architecture kit (spec 3a C1.9). The plan library makes the
// document, prepares it, installs its own system, runs the build and clears
// the history: the controller opens clean, as today's shell fixtures made
// it by hand. Each wall, separator, opening and room is one command, in the
// fixture's order, so the handles are the fixture's.
//
// The editor is driven through the public API only: PlanEditor in
// planEditorApp, the controller's camera, selection and worldToGlobal.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart';
import 'wall_fixture.dart';

export 'editor_rig.dart'
    show
        clickAt,
        dragWorld,
        globalAt,
        kitCatalog,
        press,
        pumpEditor,
        select,
        status,
        undoKey;
export 'wall_fixture.dart' show canon, driftOf, enc, kids, kindOf, payloadOf;

// ---------------------------------------------------------------------------
// The plan model, copied (room_fixture.dart:26-96).

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
Transform2 groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

// ---------------------------------------------------------------------------
// Entity helpers, copied (room_fixture.dart:196-210).

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
// The plans, copied (room_fixture.dart:356-413, 457-474).

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

// ---------------------------------------------------------------------------
// Room helpers, copied (room_fixture.dart:561-579, 581-630, 660-667,
// 699-705).

/// A room at world [seed], named [name], with label offset [label]: the
/// commit the Room tool will make, a root-level group at the identity and
/// its `RoomParams`, one compound. Returns the room's handle.
///
/// With [at], the group has that transform instead (only a file makes one,
/// D21) and the stored seed is [seed] taken back through it.
Handle addRoom(DraftDocument doc, Vector2 seed, String name,
    {(double, double)? label, Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final s = at == null ? seed : g.invert().transformPoint(seed);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<RoomParams>(
        h, RoomParams(s.x, s.y, name, label: label)),
  ], label: 'Add room'));
  return h;
}

/// [room]'s TEXT children, ascending: its name label, then its area label.
List<Handle> labelsOf(DraftDocument doc, Handle room) => [
      for (final k in kids(doc, room))
        if (kindOf(doc, k) == EntityKind.text) k,
    ];

/// The string of TEXT [h].
String textOf(DraftDocument doc, Handle h) => recordOf(doc, h).text;

/// [room]'s tint, world points, no closing duplicate: the boundary its fill
/// names (D9 steps 1 and 2), or its closed POLYLINE child (step 3). Empty
/// when it has neither.
List<Vector2> worldTintOf(DraftDocument doc, Handle room) {
  final all = kids(doc, room);
  final fills = [
    for (final k in all)
      if (kindOf(doc, k) == EntityKind.fill) k,
  ];
  final Handle boundary;
  if (fills.isNotEmpty) {
    boundary = Handle(payloadOf(doc, fills.single).scalars[0].toInt());
  } else {
    final lines = [
      for (final k in all)
        if (kindOf(doc, k) == EntityKind.polyline) k,
    ];
    if (lines.isEmpty) return const [];
    boundary = lines.single;
  }
  return worldPoints(doc, boundary, closed: true);
}

/// The page [doc]'s rooms read: the root's, or `PageComponent()`'s defaults
/// (spec 10 R-14).
PageComponent pageOf(DraftDocument doc) =>
    (doc.components.isRegistered<PageComponent>()
        ? doc.components.get<PageComponent>(doc.rootHandle)
        : null) ??
    PageComponent();

/// [room]'s label anchor in world, from its name TEXT's stored insertion
/// point `q` (D21's frames): `toWorld(room)(q) − (0, 0.7 · h_name_w)`,
/// `h_name_w` = 2.5 mm × the page's scale (D11).
Vector2 anchorOf(DraftDocument doc, Handle room) {
  final name = labelsOf(doc, room).first;
  final c = payloadOf(doc, name).coords;
  final q =
      doc.tree.accumulatedTransform(room).transformPoint(Vector2(c[0], c[1]));
  return q - Vector2(0, 0.7 * 2.5 * pageOf(doc).scaleDenominator);
}

/// The select tool's group delete (`select_tool.dart` `_groupCascade`, as
/// `opening_fixture.dart` has it): every leaf except a fill whose boundary
/// goes too, then the node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// [room]'s name and area strings.
List<String> labelStrings(DraftDocument doc, Handle room) =>
    [for (final h in labelsOf(doc, room)) textOf(doc, h)];

/// The kinds of [h]'s children, ascending by handle.
List<EntityKind> kindsOf(DraftDocument doc, Handle h) =>
    [for (final k in kids(doc, h)) kindOf(doc, k)];

// ---------------------------------------------------------------------------
// The plans, built by a PlanBuild, and the editor driven.

/// A room the build adds at plan point ([x], [y]), named [name], with label
/// offset [label] (null: auto) and, with [at], in a group of that world
/// transform (only a file makes one), its seed taken back through it
/// (today's `addRoom`, room_fixture.dart:561-579).
typedef R = ({
  double x,
  double y,
  String name,
  (double, double)? label,
  Transform2? at,
});

/// A plan built by [roomPlan] and its controller.
final class RoomPlan {
  RoomPlan._(
      this.c, this.place, this.walls, this.seps, this.openings, this.rooms);

  final PlanController c;
  final Placement place;

  /// The handles the build allocated, in the order given.
  final List<Handle> walls, seps, openings, rooms;

  DraftDocument get doc => c.document;
  Vector2 at(double x, double y) => place.at(x, y);
}

/// A controller over the architecture kit whose plan is [walls], [seps],
/// [openings] (hosted by the walls they index) and [rooms], at [place],
/// each one command, built in that order (today's `buildPlan`, then
/// `attachPage` and `addRoom`), with [page] on the root when given.
/// Disposed at tear-down.
RoomPlan roomPlan(List<W> walls,
    {List<S> seps = const [],
    List<O> openings = const [],
    List<R> rooms = const [],
    Placement place = origin,
    PageComponent? page}) {
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[], rh = <Handle>[];
  void group(DraftDocument doc, Handle h, Transform2 g, DraftCommand set,
          String label) =>
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: g,
            children: const [])),
        set,
      ], label: label));
  final c = PlanController(
    kits: [architectureKit],
    build: (doc, _) {
      var k = 0;
      for (final w in walls) {
        final h = doc.handleSeed.next();
        final g = place.groups ? groupFor(place, k++) : Transform2.identity();
        final inv = g.invert();
        final s = inv.transformPoint(place.at(w.sx, w.sy));
        final e = inv.transformPoint(place.at(w.ex, w.ey));
        group(
            doc,
            h,
            g,
            SetComponentCommand<WallParams>(
                h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
            'Add wall');
        wh.add(h);
      }
      for (final (sx, sy, ex, ey) in seps) {
        final h = doc.handleSeed.next();
        final g = place.groups ? groupFor(place, k++) : Transform2.identity();
        final inv = g.invert();
        final s = inv.transformPoint(place.at(sx, sy));
        final e = inv.transformPoint(place.at(ex, ey));
        group(
            doc,
            h,
            g,
            SetComponentCommand<SeparatorParams>(
                h, SeparatorParams(s.x, s.y, e.x, e.y)),
            'Add separator');
        sh.add(h);
      }
      for (final (i, position, width, kind, swing) in openings) {
        final h = doc.handleSeed.next();
        group(
            doc,
            h,
            Transform2.identity(),
            SetComponentCommand<OpeningParams>(
                h, OpeningParams(wh[i], position, width, kind, swing: swing)),
            'Add opening');
        oh.add(h);
      }
      if (page != null) {
        doc.commands
            .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
      }
      for (final r in rooms) {
        final h = doc.handleSeed.next();
        final g = r.at ?? Transform2.identity();
        final seed = place.at(r.x, r.y);
        final s = r.at == null ? seed : g.invert().transformPoint(seed);
        group(
            doc,
            h,
            g,
            SetComponentCommand<RoomParams>(
                h, RoomParams(s.x, s.y, r.name, label: r.label)),
            'Add room');
        rh.add(h);
      }
    },
  );
  addTearDown(c.dispose);
  return RoomPlan._(c, place, wh, sh, oh, rh);
}

/// Every live room of [doc], ascending.
List<Handle> rooms(DraftDocument doc) =>
    doc.components.withComponent<RoomParams>().toList();

String nameOf(DraftDocument doc, Handle room) =>
    doc.components.get<RoomParams>(room)!.name;

/// The rig's [pumpEditor] with a rotated, non-reflecting camera of [scale]
/// px per mm, turned [turn] rad, centred on [centre] (today's shell tests'
/// `pumpShell`, room_grips_test.dart:145-162).
Future<void> pumpAt(WidgetTester tester, PlanController c, Vector2 centre,
        {double scale = 0.15, double turn = 0.35}) =>
    pumpEditor(tester, c, centre: centre, scale: scale, turn: turn);

Future<void> toggleF3(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.f3);
  await tester.pump();
}

String osnap(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;
