// Spec 10 D8 and D16 (points 3, 4 and 6) at the app level, and its
// Differential check: a room reads every live wall and separator by place,
// so every edit that changes a band or a segment its read box touches
// rebuilds it, in the same undo step, two hops included (a neighbour's band
// reshaped at an end far from the edit). A regeneration from scratch agrees
// with the incremental one, and a random run never has an edit refused
// because of rooms.
//
// A page is attached (1:50, metres). Expected areas are hand arithmetic,
// next to the assertion; every expected label string is at least 0.0005 m²
// from a rounding tie, checked in the comment. Seeds are fractional.
// `drift()` is empty after every edit. RG3 and RS1-RS4 run at the origin,
// the corpus far origin turned 23° and the same in own groups (the spike
// found the old rules orientation-dependent exactly there, Q3b); RS5 and
// RS6 at all six placements; DF1 (Ruling 10-21) and FZ1 (Ruling 10-1) on
// the sample plan at the corpus far origin in own groups.
import 'dart:math' as math;

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_grips.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The two-room fixture's left and right seeds, plan mm (fractional).
const (double, double) leftSeed = (1512.5, 1987.25);
const (double, double) rightSeed = (5487.75, 2012.5);

/// The three placements of the relational tests here.
const relational = [origin, corpus, corpusGroups];

/// [walls] at [place] with the app's opening page attached.
Plan withPage(List<W> walls, Placement place) {
  final plan = buildPlan(walls, place: place);
  attachPage(plan.doc, PageComponent());
  return plan;
}

Vector2 seedAt(Plan plan, (double, double) s) => plan.at(s.$1, s.$2);

/// The group of the [k]-th object a test adds at [place]: the identity, or,
/// in own groups, a translation near the placement times a turn that is
/// never a multiple of 90° (not `buildPlan`'s own sequence, so an added
/// object's frame differs from every built one's).
Transform2 groupFor(Placement place, int k) => place.groups
    ? place.m
        .multiply(Transform2.translation(-217.75 * (k % 5), 131.5 * (k % 3)))
        .multiply(Transform2.rotation(0.45 + 0.8 * (k % 7)))
    : Transform2.identity();

/// Adds a wall from world [s] to world [e], [t] thick, centred, in a root
/// group [g] at handle [h]: one compound, as the Wall tool commits.
DraftCommand addWallCommand(
    DraftDocument doc, Handle h, Vector2 s, Vector2 e, double t, Transform2 g) {
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<WallParams>(
        h, WallParams(ls.x, ls.y, le.x, le.y, t, Justification.centre)),
  ], label: 'Add wall');
}

/// Adds a separator from world [s] to world [e] in a root group [g] at
/// handle [h]: one compound, as the Separator tool commits.
DraftCommand addSeparatorCommand(
    DraftDocument doc, Handle h, Vector2 s, Vector2 e, Transform2 g) {
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<SeparatorParams>(
        h, SeparatorParams(ls.x, ls.y, le.x, le.y)),
  ], label: 'Add separator');
}

/// Wall [w] (plan mm) added to [plan] after its build, in the group
/// [groupFor] gives object [k]. Returns its handle.
Handle addPlanWall(Plan plan, W w, int k) {
  final h = plan.doc.handleSeed.next();
  plan.doc.commands.execute(addWallCommand(plan.doc, h, plan.at(w.sx, w.sy),
      plan.at(w.ex, w.ey), w.t, groupFor(plan.place, k)));
  return h;
}

/// Separator [s] (plan mm) added to [plan], in [groupFor]'s group [k].
Handle addPlanSeparator(Plan plan, S s, int k) {
  final h = plan.doc.handleSeed.next();
  plan.doc.commands.execute(addSeparatorCommand(plan.doc, h,
      plan.at(s.$1, s.$2), plan.at(s.$3, s.$4), groupFor(plan.place, k)));
  return h;
}

/// Wall [h] of [doc] to world ends [s] and [e], its thickness and
/// justification kept: one `SetComponentCommand`, taken back through its
/// own group.
DraftCommand wallTo(DraftDocument doc, Handle h, Vector2 s, Vector2 e) {
  final p = doc.components.get<WallParams>(h)!;
  final inv = doc.tree.accumulatedTransform(h).invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return SetComponentCommand<WallParams>(
      h, WallParams(ls.x, ls.y, le.x, le.y, p.thickness, p.justification));
}

/// Separator [h] of [doc] to world ends [s] and [e].
DraftCommand separatorTo(DraftDocument doc, Handle h, Vector2 s, Vector2 e) {
  final inv = doc.tree.accumulatedTransform(h).invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  return SetComponentCommand<SeparatorParams>(
      h, SeparatorParams(ls.x, ls.y, le.x, le.y));
}

/// Wall [h]'s world ends.
(Vector2, Vector2) wallEnds(DraftDocument doc, Handle h) {
  final p = doc.components.get<WallParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  return (m.transformPoint(p.start), m.transformPoint(p.end));
}

/// Separator [h]'s world ends.
(Vector2, Vector2) separatorEnds(DraftDocument doc, Handle h) {
  final p = doc.components.get<SeparatorParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  return (m.transformPoint(p.start), m.transformPoint(p.end));
}

/// Wall [h]'s end [end] (0 start, 1 end) dragged to world [to] by the
/// select tool's end grip (`WallGrips.drag`: joined ends follow).
DraftCommand? dragEnd(DraftDocument doc, Handle h, int end, Vector2 to) {
  final grips = WallGrips();
  return grips.drag(doc, h, grips.gripsOf(doc, h)[end], to);
}

/// The shoelace area of [r], relative to its first point.
double areaOf(List<Vector2> r) {
  final o = r.first;
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i] - o, q = r[(i + 1) % r.length] - o;
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

/// [room]'s tint has exactly the plan corners [corners], each within 1e-5
/// mm of one stored point in world, and encloses [area] mm².
void expectTint(Plan plan, Handle room, List<(double, double)> corners,
    double area, String why) {
  final tint = worldTintOf(plan.doc, room);
  expect(tint, hasLength(corners.length), reason: why);
  for (final (x, y) in corners) {
    final w = plan.at(x, y);
    final d = tint.map((q) => (q - w).length).reduce(math.min);
    expect(d, lessThan(1e-5), reason: '$why: corner ($x, $y) off by $d');
  }
  expect(areaOf(tint), closeTo(area, 1e-2), reason: why);
}

/// The room diagnostics of [doc].
List<Diagnostic> roomDiagnostics(DraftDocument doc) =>
    codedAs(diagnosticsOf(doc), 'room.');

/// `room.shared` for [a] (the lower handle) and [b], named [na] and [nb].
Diagnostic shared(Handle a, String na, Handle b, String nb) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'room.shared',
      message: '$na and $nb share a space',
      handles: [a, b],
    );

/// [room]'s read box as the engine forms it (spec 10 D16.2, S-14): the
/// world box of every `(x, y)` pair of its children's payloads (a fill has
/// none), through the room's transform, handed to [RoomType.readBox].
Aabb2 readBoxOf(DraftDocument doc, Handle room) {
  final m = doc.tree.accumulatedTransform(room);
  var stored = Aabb2.empty();
  for (final k in kids(doc, room)) {
    final c = payloadOf(doc, k).coords;
    for (var i = 0; i + 1 < c.length; i += 2) {
      stored =
          stored.expandedToPoint(m.transformPoint(Vector2(c[i], c[i + 1])));
    }
  }
  return const RoomType()
      .readBox(doc.components.get<RoomParams>(room)!, m, stored);
}

/// [h]'s place box through the document adapter.
Aabb2 placeBoxNow(DraftDocument doc, Handle h) {
  final inputs = RoomInputs(doc);
  try {
    return inputs.placeBoxOf(h)!;
  } finally {
    inputs.dispose();
  }
}

/// The live rooms of [doc], ascending.
List<Handle> liveRooms(DraftDocument doc) => [
      for (final h in doc.components.withComponent<RoomParams>())
        if (doc.tree[h] case GroupNode(:final parent)
            when parent == doc.rootHandle)
          h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Room [h]'s world seed.
Vector2 worldSeedOf(DraftDocument doc, Handle h) => doc.tree
    .accumulatedTransform(h)
    .transformPoint(doc.components.get<RoomParams>(h)!.seed);

void main() {
  test(
      'RG3 the shared partition moved 500 mm: both rooms\' areas and labels '
      'follow, same handles, one undo step', () {
    for (final place in relational) {
      final plan = withPage(twoRoomWalls, place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      // Left 2,850 × 3,800 = 10,830,000 (10.83); right 4,850 × 3,800 =
      // 18,430,000 (18.43); each 0.005 from its ties.
      expect(labelStrings(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: '$place');
      final handles = {
        for (final r in [left, right]) r: kids(doc, r),
      };
      // Premise: the partition's place box, before and after, misses both
      // seeds, so only the rooms' stored tints reach it (the read box's
      // `stored`, X5-noStored). Its T partners' bands do not change, so
      // only its own boxes reach the rooms: at the origin the before box
      // alone reaches Room 1 (M-10before leaves it stale); turned 23°, both
      // boxes reach both rooms (M-10e, one reader per box, leaves Room 2
      // stale).
      final bandBefore = placeBoxNow(doc, plan.walls[4]);
      final before = canon(doc, sortNodes: true);
      final depth = doc.commands.undoDepth;

      doc.commands
          .execute(moveWall(plan, 4, const W(3500, 0, 3500, 4000, 100)));
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step at $place');
      final bandAfter = placeBoxNow(doc, plan.walls[4]);
      for (final s in [leftSeed, rightSeed]) {
        for (final b in [bandBefore, bandAfter]) {
          expect(b.containsPoint(seedAt(plan, s)), isFalse,
              reason: 'the premise at $place');
        }
      }
      expect({
        for (final r in [left, right]) r: kids(doc, r),
      }, handles, reason: 'same handles at $place');
      // Left: x 100..3,450, 3,350 × 3,800 = 12,730,000 (12.73, 0.005 from
      // 12.725 and 12.735). Right: x 3,550..7,900, 4,350 × 3,800 =
      // 16,530,000 (16.53, 0.005 from 16.525 and 16.535).
      expect(labelStrings(doc, left), ['Room 1', '12.73 m²'], reason: '$place');
      expect(labelStrings(doc, right), ['Room 2', '16.53 m²'],
          reason: '$place');
      expectTint(
          plan,
          left,
          const [(100, 100), (3450, 100), (3450, 3900), (100, 3900)],
          12730000,
          'left moved at $place');
      expectTint(
          plan,
          right,
          const [(3550, 100), (7900, 100), (7900, 3900), (3550, 3900)],
          16530000,
          'right moved at $place');
      expect(driftOf(doc), isEmpty, reason: 'moved at $place');
      final after = canon(doc, sortNodes: true);

      doc.commands.undo();
      expect(canon(doc, sortNodes: true), before, reason: 'undo at $place');
      expect(labelStrings(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
      doc.commands.redo();
      expect(canon(doc, sortNodes: true), after, reason: 'redo at $place');
      expect({
        for (final r in [left, right]) r: kids(doc, r),
      }, handles, reason: 'redone at $place');
      expect(driftOf(doc), isEmpty, reason: 'redone at $place');
    }
  });

  test('RS1 a partition drawn face to face after the click splits the room',
      () {
    for (final place in relational) {
      final plan = withPage(twoRoomWalls, place);
      final doc = plan.doc;
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      final handles = kids(doc, right);
      // Its ends on the exterior's inner faces, not on their centrelines:
      // 07 joins it to nothing.
      addPlanWall(plan, const W(6500, 100, 6500, 3900, 100), 0);
      // x 3,050..6,450: 3,400 × 3,800 = 12,920,000 (12.92, 0.005 from the
      // ties).
      expect(labelStrings(doc, right), ['Room 2', '12.92 m²'],
          reason: '$place');
      expectTint(
          plan,
          right,
          const [(3050, 100), (6450, 100), (6450, 3900), (3050, 3900)],
          12920000,
          '$place');
      expect(kids(doc, right), handles, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: 'undone at $place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test('RS2 a freestanding wall drawn inside after the click is a hole', () {
    for (final place in relational) {
      final plan = withPage(twoRoomWalls, place);
      final doc = plan.doc;
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      addPlanWall(plan, const W(6000, 3000, 7000, 3000, 100), 0);
      // 18,430,000 − 1,000 × 100 = 18,330,000 (18.33, 0.005 from the ties).
      expect(labelStrings(doc, right), ['Room 2', '18.33 m²'],
          reason: '$place');
      final face = faceAt(doc, seedAt(plan, rightSeed)) as Traced;
      expect(face.holes, hasLength(1), reason: '$place');
      expect(face.area, closeTo(18330000, 1e-2), reason: '$place');
      // The hole is keyholed into the tint (D9 step 1): a region, the
      // outer ring's four corners, the hole's four and two slit points.
      expect(kindsOf(doc, right), [
        EntityKind.fill,
        EntityKind.polyline,
        EntityKind.text,
        EntityKind.text,
      ]);
      expect(worldTintOf(doc, right), hasLength(10), reason: '$place');
      expect(roomDiagnostics(doc), isEmpty, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: 'undone at $place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test('RS3 a partition T-joined at both ends after the click splits the room',
      () {
    for (final place in relational) {
      final plan = withPage(twoRoomWalls, place);
      final doc = plan.doc;
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      // Centreline to centreline: a T into the south and the north wall.
      addPlanWall(plan, const W(6500, 0, 6500, 4000, 100), 0);
      // 3,400 × 3,800 = 12,920,000 (12.92).
      expect(labelStrings(doc, right), ['Room 2', '12.92 m²'],
          reason: '$place');
      expectTint(
          plan,
          right,
          const [(3050, 100), (6450, 100), (6450, 3900), (3050, 3900)],
          12920000,
          '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: 'undone at $place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'RS4 the room\'s own partition moved into the west wall\'s band merges '
      'the two rooms', () {
    for (final place in relational) {
      final plan = withPage(twoRoomWalls, place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      final handles = {
        for (final r in [left, right]) r: kids(doc, r),
      };
      // Onto the west wall's centreline: its band (−50..50) lies inside the
      // west wall's (−100..100).
      doc.commands.execute(moveWall(plan, 4, const W(0, 0, 0, 4000, 100)));
      // One face: 7,800 × 3,800 = 29,640,000 (29.64, 0.005 from the ties);
      // both rooms survive (D8) and the lower one reports the pair.
      for (final (h, n) in [(left, 'Room 1'), (right, 'Room 2')]) {
        expect(labelStrings(doc, h), [n, '29.64 m²'], reason: '$place');
        expectTint(
            plan,
            h,
            const [(100, 100), (7900, 100), (7900, 3900), (100, 3900)],
            29640000,
            '$n at $place');
      }
      expect({
        for (final r in [left, right]) r: kids(doc, r),
      }, handles, reason: '$place');
      expect(roomDiagnostics(doc), [shared(left, 'Room 1', right, 'Room 2')],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(labelStrings(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: '$place');
      expect(roomDiagnostics(doc), isEmpty, reason: 'undone at $place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'RS5 a stub, then a wall joining its free end: every room follows, at '
      'six placements', () {
    for (final place in placements) {
      final plan = withPage(boxWalls, place);
      final doc = plan.doc;
      final room = addRoom(doc, plan.at(6000.25, 3000.5), 'Room 1');
      // 7,800 × 3,800 = 29,640,000 (29.64).
      expect(labelStrings(doc, room), ['Room 1', '29.64 m²'], reason: '$place');
      // Q (the spike's Q3e): a stub T-joined into the south wall, its free
      // end in the room. The ring walks round it: 29,640,000 − 100 ×
      // (1,500 − 100) = 29,500,000 (29.50, 0.005 from the ties).
      addPlanWall(plan, const W(4000, 0, 4000, 1500, 100), 0);
      expect(labelStrings(doc, room), ['Room 1', '29.50 m²'], reason: '$place');
      expectTint(
          plan,
          room,
          const [
            (100, 100),
            (3950, 100),
            (3950, 1500),
            (4050, 1500),
            (4050, 100),
            (7900, 100),
            (7900, 3900),
            (100, 3900),
          ],
          29500000,
          'Q at $place');
      expect(driftOf(doc), isEmpty, reason: 'Q at $place');
      // X: joins Q's free end at an L, away from every bound, so it
      // reshapes Q's band (the mitre) two hops from the room. The L's two
      // bands: Q's trapezoid 100 × 1,350 + ½ × 100 × 100 = 140,000 and X's
      // 100 × (950 + 1,050) / 2 = 100,000; 29,640,000 − 240,000 =
      // 29,400,000 (29.40, 0.005 from the ties).
      addPlanWall(plan, const W(4000, 1500, 5000, 1500, 100), 1);
      expect(labelStrings(doc, room), ['Room 1', '29.40 m²'], reason: '$place');
      expectTint(
          plan,
          room,
          const [
            (100, 100),
            (3950, 100),
            (3950, 1550),
            (5000, 1550),
            (5000, 1450),
            (4050, 1450),
            (4050, 100),
            (7900, 100),
            (7900, 3900),
            (100, 3900),
          ],
          29400000,
          'X at $place');
      expect(driftOf(doc), isEmpty, reason: 'X at $place');
      doc.commands.undo();
      expect(labelStrings(doc, room), ['Room 1', '29.50 m²'], reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'RS6 the fallback two-hop: moving X squares W\'s far end and opens a '
      'notch into R2, at six placements', () {
    for (final place in placements) {
      final plan = withPage(fbWalls, place);
      final doc = plan.doc;
      final wall = plan.walls[fbW], x = plan.walls[fbX];
      final r2 = addRoom(doc, plan.at(1500.25, 12.5), 'R2');
      // R2 = [−450, 2,987] × [−2,950, 2,950] less [−450, 50] × [−200,
      // 2,950] = 3,437 × 5,900 − 500 × 3,150 = 20,278,300 − 1,575,000 =
      // 18,703,300 (18.70, 0.0017 from 18.705).
      expect(labelStrings(doc, r2), ['R2', '18.70 m²'], reason: '$place');
      expectTint(
          plan,
          r2,
          const [
            (-450, -2950),
            (2987, -2950),
            (2987, 2950),
            (50, 2950),
            (50, -200),
            (-450, -200),
          ],
          18703300,
          'before at $place');
      List<Diagnostic> fallback() => [
            for (final d in diagnosticsOf(doc))
              if (d.code == 'wall.fallback' && d.handles.contains(wall)) d,
          ];
      // Premises: W does not fall back before the edit and does after it;
      // X's place box, before and (unturned) after, misses R2's read box
      // as the trigger forms it, from R2's stored children before the edit,
      // so only X's neighbour W can reach R2.
      expect(fallback(), isEmpty, reason: 'no fallback before at $place');
      final read = readBoxOf(doc, r2);
      final xBefore = placeBoxNow(doc, x);

      final (ex, ey) = fbXEditEnd;
      doc.commands.execute(moveWall(plan, fbX, W(-2000, 0, ex, ey, 100)));
      expect(fallback(), isNotEmpty, reason: 'W falls back at $place');
      final xAfter = placeBoxNow(doc, x);
      expect(xBefore.intersects(read), isFalse, reason: '$place');
      // Unturned, X's after box ends west of x = −1,150 in plan and R2's
      // read box starts at −452 (spec 10's `FB`). Turned 23°, both are world
      // boxes of slanted shapes and X's after box reaches about 44 mm into
      // R2's read box, so there X's own box rebuilds R2: the two-hop is
      // isolated only at the unturned placements, where M-10nbr dies.
      if (place.deg == 0) {
        expect(xAfter.intersects(read), isFalse, reason: '$place');
      }
      // W squares its east end at x = 0; V keeps its mitre at B, so the
      // triangle (0, 0), (0, −200), (50, −200) opens into R2: 18,703,300 +
      // ½ × 50 × 200 = 18,708,300 (18.71, 0.0033 from 18.705).
      expect(labelStrings(doc, r2), ['R2', '18.71 m²'], reason: '$place');
      expectTint(
          plan,
          r2,
          const [
            (-450, -2950),
            (2987, -2950),
            (2987, 2950),
            (50, 2950),
            (50, -200),
            (0, 0),
            (0, -200),
            (-450, -200),
          ],
          18708300,
          'after at $place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(labelStrings(doc, r2), ['R2', '18.70 m²'], reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'DF1 twenty scripted edits on the sample plan: a regeneration from '
      'scratch agrees with the incremental one', () {
    // Ruling 10-21: D23's plan rebuilt by the fixture at the corpus far
    // origin, every wall and separator in its own group.
    const place = corpusGroups;
    final plan = samplePlan(place);
    final doc = plan.doc;
    final rooms = addSampleRooms(plan);
    var k = 0;
    Vector2 at(double x, double y) => plan.at(x, y);
    final w = plan.walls;
    // Handles of what the script adds; filled as it runs.
    late Handle hallSep, livingSep, partition;
    final edits = <(String, void Function())>[
      (
        'P5 moved 300.5 east',
        () => doc.commands
            .execute(wallTo(doc, w[8], at(21800.5, 8125), at(21800.5, 11500)))
      ),
      (
        'P4\'s north end dragged 300.25 along E3',
        () => doc.commands.execute(dragEnd(doc, w[7], 1, at(14900.25, 16875))!)
      ),
      (
        'a separator added in the Hall, face to face',
        () => hallSep =
            addPlanSeparator(plan, (13800.5, 8250, 13800.5, 12940), k++)
      ),
      (
        'the Hall separator moved 500.25 west',
        () => doc.commands.execute(
            separatorTo(doc, hallSep, at(13300.25, 8250), at(13300.25, 12940)))
      ),
      (
        'P2 moved 200.5 north: P4 now stands 140 mm into the Hall',
        () => doc.commands
            .execute(wallTo(doc, w[5], at(12125, 13200.5), at(17000, 13200.5)))
      ),
      (
        'a partition added across Dining, T-joined at both ends',
        () => partition =
            addPlanWall(plan, const W(20000.5, 11500, 20000.5, 16875, 120), k++)
      ),
      (
        'that partition deleted',
        () => doc.commands.execute(deleteObject(doc, partition))
      ),
      (
        'a 300 mm column added in the Kitchen',
        () => addPlanWall(plan, const W(18000.5, 9500, 18300.5, 9500, 300), k++)
      ),
      (
        'the page to ft-in at 1:100',
        () => attachPage(
            doc,
            PageComponent(
                displayUnit: DisplayUnit.feetInches, scaleDenominator: 100))
      ),
      (
        'the north-east corner dragged: E2 and E3 follow; the Living | '
            'Dining separator now ends short of E3\'s face, so Dining takes '
            'in the west of Living',
        () =>
            doc.commands.execute(dragEnd(doc, w[1], 1, at(26100.25, 17050.5))!)
      ),
      (
        'the Living column moved',
        () => doc.commands.execute(
            wallTo(doc, w[9], at(23200.5, 14300.25), at(23600.5, 14300.25)))
      ),
      (
        'P5\'s south end dragged 150.25 west along E1',
        () => doc.commands.execute(dragEnd(doc, w[8], 0, at(21650.25, 8125))!)
      ),
      (
        'the Living | Dining separator moved 99.5 west',
        () => doc.commands.execute(separatorTo(
            doc, plan.seps[0], at(21400.5, 11560), at(21400.5, 16750)))
      ),
      (
        'P3 moved 50.25 north: P5 still ends in its band',
        () => doc.commands.execute(
            wallTo(doc, w[6], at(17000, 11550.25), at(25875, 11550.25)))
      ),
      (
        'a separator added in Living, into P3\'s and E3\'s bands',
        () => livingSep =
            addPlanSeparator(plan, (24000.25, 11600, 24000.25, 16950), k++)
      ),
      (
        'that separator moved 300.5 east',
        () => doc.commands.execute(separatorTo(
            doc, livingSep, at(24300.75, 11600), at(24300.75, 16950)))
      ),
      (
        'the south-west corner dragged: E4 and E1 follow',
        () => doc.commands.execute(dragEnd(doc, w[3], 1, at(11950.5, 8000.25))!)
      ),
      (
        'P4 moved upright at x 15,000.25',
        () => doc.commands.execute(
            wallTo(doc, w[7], at(15000.25, 13000), at(15000.25, 16875)))
      ),
      (
        'the Hall separator deleted',
        () => doc.commands.execute(deleteObject(doc, hallSep))
      ),
      (
        'P1\'s north end dragged 200.5 east: P2\'s east end is left short of '
            'P1\'s face, so the Hall and Bedroom 2 share a space',
        () => doc.commands.execute(dragEnd(doc, w[4], 1, at(17200.5, 16875))!)
      ),
    ];
    expect(edits, hasLength(20));
    for (final (i, (what, edit)) in edits.indexed) {
      final depth = doc.commands.undoDepth;
      edit();
      expect(doc.commands.undoDepth, depth + 1, reason: 'edit $i: $what');
      expect(driftOf(doc), isEmpty, reason: 'edit $i: $what');
    }
    // The script dissolves no room, and leaves one shared space.
    expect(liveRooms(doc),
        [...rooms.values]..sort((a, b) => a.value.compareTo(b.value)));
    expect(roomDiagnostics(doc), [
      shared(rooms['Hall']!, 'Hall', rooms['Bedroom 2']!, 'Bedroom 2'),
    ]);

    // From scratch: a fresh document with the same page, and every live
    // object (walls, separators, openings, rooms) with its final parameters
    // and group, at its own handle, added in **reverse** handle order in one
    // compound, so each is generated once from its final state and in one
    // plan, with no history. Handles are kept so the openings' hosts hold.
    final fresh = DraftDocument.empty();
    installParametric(fresh);
    ensureDashedLinetype(fresh);
    attachPage(fresh, pageOf(doc));
    fresh.handleSeed.raiseTo(doc.handleSeed.current);
    final objects = [
      for (final h in [
        ...doc.components.withComponent<WallParams>(),
        ...doc.components.withComponent<SeparatorParams>(),
        ...doc.components.withComponent<OpeningParams>(),
        ...doc.components.withComponent<RoomParams>(),
      ])
        if (doc.tree[h] case GroupNode(:final parent)
            when parent == doc.rootHandle)
          h,
    ]..sort((a, b) => b.value.compareTo(a.value));
    fresh.commands.execute(CompoundCommand([
      for (final h in objects) ...[
        AddNodeCommand(GroupNode(
            handle: h,
            parent: fresh.rootHandle,
            transform: (doc.tree[h]! as GroupNode).transform,
            children: const [])),
        componentCommand(doc, h),
      ],
    ], label: 'From scratch'));
    expect(driftOf(fresh), isEmpty, reason: 'from scratch');
    expect(diagnosticsOf(fresh), diagnosticsOf(doc), reason: 'from scratch');
    expect(liveRooms(fresh), liveRooms(doc));
    var points = 0;
    for (final r in liveRooms(doc)) {
      final name = doc.components.get<RoomParams>(r)!.name;
      expect(kindsOf(fresh, r), kindsOf(doc, r), reason: name);
      expect(labelStrings(fresh, r), labelStrings(doc, r), reason: name);
      // Exactly: the same world tint points and label points, bit for bit.
      final tint = worldTintOf(doc, r);
      expect(worldTintOf(fresh, r), tint, reason: name);
      points += tint.length;
      expect([
        for (final t in labelsOf(fresh, r)) ...worldPoints(fresh, t)
      ], [
        for (final t in labelsOf(doc, r)) ...worldPoints(doc, t)
      ], reason: name);
    }
    // ignore: avoid_print
    print('DF1: 20 edits, ${liveRooms(doc).length} rooms, $points tint points '
        'equal bit for bit; diagnostics '
        '${[for (final d in diagnosticsOf(doc)) d.message]}; labels ${{
      for (final r in liveRooms(doc)) labelStrings(doc, r).join(' ')
    }}');
  });

  test(
      'FZ1 a seeded random run: no edit is refused because of rooms, drift() '
      'stays empty, every tint triangulates', () {
    const place = corpusGroups;
    // The plan with its rooms, and its twin without them: the same walls,
    // separators and openings, in the same groups.
    final withRooms = samplePlan(place);
    final twin = samplePlan(place);
    addSampleRooms(withRooms);
    attachPage(twin.doc, PageComponent());
    final a = withRooms.doc, b = twin.doc;
    // Each wall and separator as its handle in each document.
    // The four exterior walls only have their ends dragged (a joined
    // corner follows), so the flat stays closed long enough for rooms to
    // live; every other wall is moved, dragged and deleted too.
    final shell = [
      for (var i = 0; i < 4; i++) (withRooms.walls[i], twin.walls[i]),
    ];
    final walls = [
      for (var i = 4; i < withRooms.walls.length; i++)
        (withRooms.walls[i], twin.walls[i]),
    ];
    final seps = [(withRooms.seps.single, twin.seps.single)];
    final rnd = math.Random(1010);
    var k = 0, roomNumber = 0;
    final counts = <String, int>{};
    void count(String what) => counts[what] = (counts[what] ?? 0) + 1;
    double r(double lo, double hi) => lo + (hi - lo) * rnd.nextDouble();
    Vector2 anywhere() => withRooms.at(r(11500, 26500), r(7500, 17500));
    Vector2 near(Vector2 p, double d) =>
        p + withRooms.at(r(-d, d), r(-d, d)) - withRooms.at(0, 0);

    /// [make] run on both documents: whether each landed, and why not.
    void both(String what, DraftCommand? Function(DraftDocument, bool) make,
        {void Function()? landed}) {
      String? run(DraftDocument d, bool isA) {
        final c = make(d, isA);
        if (c == null) return 'no command';
        try {
          d.commands.execute(c);
          return null;
        } catch (e) {
          return '${e.runtimeType}: $e';
        }
      }

      final ra = run(a, true), rb = run(b, false);
      expect(ra, rb, reason: '$what: lands on both or on neither');
      if (ra == null) {
        count(what);
        landed?.call();
      } else {
        count('$what refused on both (${ra.split(':').first})');
      }
    }

    for (var step = 0; step < 200; step++) {
      final alive = liveRooms(a);
      final op = rnd.nextInt(100);
      if (op < 25 && walls.isNotEmpty) {
        final (ha, hb) = walls[rnd.nextInt(walls.length)];
        final d = near(Vector2.zero(), 250);
        final (s, e) = wallEnds(a, ha);
        both('wall move',
            (doc, isA) => wallTo(doc, isA ? ha : hb, s + d, e + d));
      } else if (op < 45) {
        final all = [...shell, ...walls];
        final (ha, hb) = all[rnd.nextInt(all.length)];
        final end = rnd.nextInt(2);
        final (s, e) = wallEnds(a, ha);
        final to = near(end == 0 ? s : e, 300);
        both('end drag', (doc, isA) => dragEnd(doc, isA ? ha : hb, end, to));
      } else if (op < 53 && walls.length + seps.length > 0) {
        final i = rnd.nextInt(walls.length + seps.length);
        final (ha, hb) = i < walls.length ? walls[i] : seps[i - walls.length];
        both('delete', (doc, isA) => deleteObject(doc, isA ? ha : hb),
            landed: () => i < walls.length
                ? walls.removeAt(i)
                : seps.removeAt(i - walls.length));
      } else if (op < 65) {
        final s = anywhere();
        final e = near(s, 5000);
        final t = const [100.0, 120.0, 200.0, 250.0, 400.0][rnd.nextInt(5)];
        final g = groupFor(place, k++);
        final ha = a.handleSeed.next(), hb = b.handleSeed.next();
        both('wall add',
            (doc, isA) => addWallCommand(doc, isA ? ha : hb, s, e, t, g),
            landed: () => walls.add((ha, hb)));
      } else if (op < 75) {
        final s = anywhere();
        final e = near(s, 5000);
        final g = groupFor(place, k++);
        final ha = a.handleSeed.next(), hb = b.handleSeed.next();
        both('separator add',
            (doc, isA) => addSeparatorCommand(doc, isA ? ha : hb, s, e, g),
            landed: () => seps.add((ha, hb)));
      } else if (op < 85 && seps.isNotEmpty) {
        final (ha, hb) = seps[rnd.nextInt(seps.length)];
        final d = near(Vector2.zero(), 250);
        final (s, e) = separatorEnds(a, ha);
        both('separator move',
            (doc, isA) => separatorTo(doc, isA ? ha : hb, s + d, e + d));
      } else {
        // A room click, on the plan with rooms only: as the Room tool
        // places one, in a bounded face that holds no live room's seed. Up
        // to eight points are tried; the misses are counted.
        for (var attempt = 0; attempt < 8; attempt++) {
          final p = anywhere();
          final face = faceAt(a, p);
          if (face is! Traced) {
            count('room click outside a face');
          } else if (liveRooms(a).any((h) {
            final q = worldSeedOf(a, h);
            return pointInRing(q, face.ring) &&
                !face.holes.any((hole) => pointInRing(q, hole));
          })) {
            count('room click in an occupied face');
          } else {
            // It lands and lives: its seed is in a bounded face.
            final h = addRoom(a, p, 'Room ${++roomNumber}');
            expect(liveRooms(a), contains(h), reason: 'step $step: it lives');
            count('room click');
            break;
          }
        }
      }

      for (final h in alive) {
        if (!liveRooms(a).contains(h)) count('room dissolved');
      }
      expect(driftOf(a), isEmpty, reason: 'step $step, with rooms');
      expect(driftOf(b), isEmpty, reason: 'step $step, the twin');
      final inputs = RoomInputs(a);
      try {
        for (final h in liveRooms(a)) {
          final seed = worldSeedOf(a, h);
          final face = traceRoomAmong(seed, inputs);
          expect(face, isA<Traced>(), reason: 'step $step: room $h');
          face as Traced;
          expect(pointInRing(seed, face.ring), isTrue,
              reason: 'step $step: room $h\'s seed in its face');
          expect(face.holes.any((hole) => pointInRing(seed, hole)), isFalse,
              reason: 'step $step: room $h\'s seed in no hole');
          final children = kids(a, h);
          if (kindOf(a, children.first) == EntityKind.fill) {
            final boundary =
                Handle(payloadOf(a, children.first).scalars[0].toInt());
            expect(
                triangulationFor(EntityKind.polyline, payloadOf(a, boundary)),
                isNotEmpty,
                reason: 'step $step: room $h\'s tint triangulates');
            count('tint region checked');
          } else {
            count('tint outline (step 3) checked');
          }
        }
      } finally {
        inputs.dispose();
      }
    }
    counts['rooms alive at the end'] = liveRooms(a).length;
    counts['walls at the end'] = shell.length + walls.length;
    counts['separators at the end'] = seps.length;
    // ignore: avoid_print
    print('FZ1 seed 1010, 200 steps at $place: '
        '${(counts.entries.toList()..sort((x, y) => x.key.compareTo(y.key))).map((e) => '${e.key} ${e.value}').join('; ')}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// [h]'s parametric component in [doc], as a command that sets it.
DraftCommand componentCommand(DraftDocument doc, Handle h) {
  final c = doc.components;
  if (c.get<WallParams>(h) case final p?) {
    return SetComponentCommand<WallParams>(h, p);
  }
  if (c.get<SeparatorParams>(h) case final p?) {
    return SetComponentCommand<SeparatorParams>(h, p);
  }
  if (c.get<OpeningParams>(h) case final p?) {
    return SetComponentCommand<OpeningParams>(h, p);
  }
  return SetComponentCommand<RoomParams>(h, c.get<RoomParams>(h)!);
}
