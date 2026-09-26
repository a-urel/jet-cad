// Spec 10 D4: the trace inputs, through the view adapter and the document
// adapter, agree bit for bit (RI1); an input is equal only to the same
// input, bit for bit, as `placeInput` needs (RI2); a wall whose local ring
// falls back is traced as drawn (RT5).
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';
import 'support/wall_fixture.dart'
    show addWall, addWallLocal, far, polar, wallDoc, worldWallOf;

/// Asserts that [RoomInputs] over [doc] and the view adapter, seen through
/// [probeView], give the same contributors, inputs, place boxes, wall
/// neighbours and bounds, bit for bit. Returns the probe's record.
ViewInputs expectAdaptersAgree(DraftDocument doc, String what) {
  final seen = probeView(doc);
  final inputs = RoomInputs(doc);
  addTearDown(inputs.dispose);
  expect(inputs.placedIn(everywhere), seen.placedAll, reason: what);
  var u = Aabb2.empty();
  for (final h in seen.contributors) {
    final input = seen.inputs[h];
    expect(inputs.inputOf(h), input, reason: '$what: ${h.value}\'s input');
    expect(sameBox(seen.adapterBoxes[h], input?.box), isTrue,
        reason: '$what: ${h.value}');
    expect(sameBox(seen.engineBoxes[h], input?.box), isTrue,
        reason: '$what: ${h.value}\'s place box in the engine');
    expect(sameBox(inputs.placeBoxOf(h), input?.box), isTrue,
        reason: '$what: ${h.value}\'s place box in the document');
    expect(inputs.wallNeighboursOf(h), seen.wallNeighbours[h],
        reason: '$what: ${h.value}\'s wall neighbours');
    if (input != null) u = u.union(input.box);
  }
  expect(sameBox(inputs.bounds, u), isTrue, reason: '$what: bounds');
  return seen;
}

/// [plan]'s premises: every wall and separator is placed (no fixture here
/// is degenerate), and at least one wall has a wall neighbour.
void expectPlaced(Plan plan, ViewInputs seen, String what) {
  for (final h in [...plan.walls, ...plan.seps]) {
    expect(seen.inputs[h], isNotNull, reason: '$what: ${h.value} placed');
  }
  expect(seen.wallNeighbours.values.any((n) => n.isNotEmpty), isTrue,
      reason: '$what: walls join');
}

/// Wall [h]'s stored outline boundary: the polyline its one fill names.
Handle boundaryOfWall(DraftDocument doc, Handle h) {
  final fill =
      kids(doc, h).firstWhere((k) => kindOf(doc, k) == EntityKind.fill);
  return Handle(payloadOf(doc, fill).scalars[0].toInt());
}

/// The double one ulp farther from zero than [x] (the next bit pattern).
double ulpAway(double x) {
  final b = ByteData(8)..setFloat64(0, x);
  b.setInt64(0, b.getInt64(0) + 1);
  return b.getFloat64(0);
}

List<List<double>> xy(List<Vector2> ps) => [
      for (final p in ps) [p.x, p.y]
    ];

void main() {
  final fixtures = <String, Plan Function(Placement)>{
    'the sample plan, its openings, separator and column': samplePlan,
    'the L with a door, a window and a gap': (p) =>
        buildPlan(lWalls, openings: lOpenings, place: p),
    'four thicknesses': (p) => buildPlan(fourThickWalls, place: p),
    'JM': (p) => buildPlan(jmWalls, place: p),
    'two rooms': (p) => buildPlan(twoRoomWalls, place: p),
    'the box, the hollow column and the separator': boxAndSeparatorPlan,
    'TR': (p) => buildPlan(trWalls, place: p),
    'FB': (p) => buildPlan(fbWalls, place: p),
    // A wall added after a separator: its handle is above the separator's,
    // so the inputs' handle order is not the order they were read in.
    'the sample plan with its column added after the separator': (p) =>
        buildPlan(sampleWalls(),
            seps: const [sampleSeparator],
            wallsAfter: const [sampleColumn],
            openings: sampleOpenings,
            place: p),
  };

  test(
      'RI1 the view and document adapters give the same inputs, place '
      'boxes and wall neighbours, bit for bit, on every fixture at every '
      'placement', () async {
    for (final place in placements) {
      for (final MapEntry(key: name, value: build) in fixtures.entries) {
        final what = '$name at $place';
        final plan = build(place);
        final seen = expectAdaptersAgree(plan.doc, what);
        expectPlaced(plan, seen, what);
        final ascending = [...plan.walls, ...plan.seps]
          ..sort((a, b) => a.value.compareTo(b.value));
        expect(seen.placedAll, ascending,
            reason: '$what: every wall and separator, ascending, and only '
                'those (no opening)');
      }
    }
    // Premise of the column-last fixture: a wall's handle above a
    // separator's.
    final columnLast = buildPlan(sampleWalls(),
        seps: const [sampleSeparator], wallsAfter: const [sampleColumn]);
    expect(
        columnLast.walls.last.value, greaterThan(columnLast.seps.single.value));
    final lateInputs = RoomInputs(columnLast.doc);
    addTearDown(lateInputs.dispose);
    expect(lateInputs.placedIn(everywhere), [
      ...columnLast.walls.take(9),
      columnLast.seps.single,
      columnLast.walls.last
    ]);

    // 07's wide node cluster (Ruling 07-3): B's start is the anchor, A's
    // and C's ends lie within wallJoin.linear of it on either side but
    // about 2e-6 apart, so A and C are node members of each other's joint
    // yet not reach neighbours. A's band is the one its neighbours shape,
    // never one shaped by every wall. At the identity, and in own groups
    // each turned an exact quarter turn about (1234.5, -678.25).
    for (final (label, at) in [
      ('identity', Transform2.identity()),
      (
        'own groups, quarter turn',
        const Transform2(0, 1, -1, 0, 1234.5, -678.25)
      ),
    ]) {
      const hB = Handle(100), hA = Handle(200), hC = Handle(300);
      const d = 1e-6 - 1e-12;
      final doc = wallDoc();
      ensureDashedLinetype(doc);
      doc.commands.execute(CompoundCommand([
        addWallLocal(doc, hB,
            const WallParams(0, 0, 0, 3000, 200, Justification.centre), at),
        addWallLocal(doc, hA,
            const WallParams(d, 0, 3000, 0, 200, Justification.centre), at),
        addWallLocal(doc, hC,
            const WallParams(-d, 0, -3000, 0, 200, Justification.centre), at),
      ], label: 'Add cluster'));
      final a = worldWallOf(doc, hA),
          b = worldWallOf(doc, hB),
          c = worldWallOf(doc, hC);
      // Premises: A's and C's ends join B's start, A and C are not reach
      // neighbours, and C would change A's band.
      expect((a.s - b.s).length, lessThanOrEqualTo(wallJoin.linear));
      expect((c.s - b.s).length, lessThanOrEqualTo(wallJoin.linear));
      final seen = expectAdaptersAgree(doc, 'wide cluster, $label');
      expect(seen.neighbours[hA], [hB], reason: label);
      expect(seen.neighbours[hC], [hB], reason: label);
      expect(seen.neighbours[hB], [hA, hC], reason: label);
      expect(xy(localOutlineOf(a, [b]).ring),
          isNot(xy(localOutlineOf(a, [b, c]).ring)),
          reason: '$label: C would reshape A');
    }

    // Live objects only (08's final review m5): a WallParams on a group
    // nested under a plain root group, and one on a handle with no node (a
    // deleted wall's component, as 08's HF9 builds it), both crossing the
    // partition of the two rooms, are neither inputs nor neighbours.
    for (final place in [origin, corpusGroups]) {
      final plan = buildPlan(twoRoomWalls, place: place);
      final doc = plan.doc;
      final partition = plan.walls[4];
      const plain = Handle(5000), nested = Handle(5100), bare = Handle(5200);
      final inv = doc.tree.accumulatedTransform(plain).invert();
      WallParams across(double y) {
        final s = plan.at(2000, y), e = plan.at(4000, y + 150);
        final ls = inv.transformPoint(s), le = inv.transformPoint(e);
        return WallParams(ls.x, ls.y, le.x, le.y, 150, Justification.centre);
      }

      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: plain,
            parent: doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        AddNodeCommand(GroupNode(
            handle: nested,
            parent: plain,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(nested, across(1800)),
        SetComponentCommand<WallParams>(bare, across(2600)),
      ], label: 'Add strays'));
      expect(doc.tree[nested]!.parent, plain, reason: 'not root-level');
      expect(doc.tree[bare], isNull, reason: 'no node');
      // Premise: live, either would join the partition (a crossing).
      const control = WallType();
      for (final h in [nested, bare]) {
        final r = control.reach(doc.components.get<WallParams>(h)!,
            doc.tree.accumulatedTransform(h));
        final p = control.reach(doc.components.get<WallParams>(partition)!,
            doc.tree.accumulatedTransform(partition));
        expect(r.intersects(p), isTrue, reason: '$place: ${h.value} crosses');
      }
      final seen = expectAdaptersAgree(doc, 'strays at $place');
      final inputs = RoomInputs(doc);
      addTearDown(inputs.dispose);
      for (final h in [nested, bare]) {
        expect(seen.contributors, isNot(contains(h)));
        expect(inputs.inputOf(h), isNull, reason: '$place: ${h.value}');
        expect(inputs.placedIn(everywhere), isNot(contains(h)));
        expect(inputs.wallNeighboursOf(partition), isNot(contains(h)));
      }
      expect(inputs.placedIn(everywhere), plan.walls);
    }

    // The cache follows the document: an edit marks it stale, and the next
    // query rebuilds it once.
    final plan = buildPlan(twoRoomWalls, place: corpusGroups);
    final inputs = RoomInputs(plan.doc);
    addTearDown(inputs.dispose);
    final partition = plan.walls[4];
    final before = inputs.inputOf(partition)!;
    expect(inputs.debugRebuilds, 1);
    expect(inputs.bounds.isEmpty, isFalse);
    expect(inputs.debugRebuilds, 1, reason: 'no change, no rebuild');
    final p = plan.doc.components.get<WallParams>(partition)!;
    plan.doc.commands.execute(SetComponentCommand<WallParams>(
        partition, p.copyWith(thickness: 180.5)));
    await Future<void>.delayed(Duration.zero);
    expect(inputs.inputOf(partition), isNot(before));
    expect(inputs.debugRebuilds, 2);
    expectAdaptersAgree(plan.doc, 'after an edit');
    expect(inputs.inputOf(partition), probeView(plan.doc).inputs[partition]);

    // A tool that has just committed calls invalidate(): the next query
    // sees the edit without waiting for the document's `changes`.
    await Future<void>.delayed(Duration.zero);
    final seenBefore = inputs.inputOf(partition)!;
    final generation = inputs.generation;
    final q = plan.doc.components.get<WallParams>(partition)!;
    plan.doc.commands.execute(SetComponentCommand<WallParams>(
        partition, q.copyWith(thickness: 140.25)));
    expect(inputs.inputOf(partition), seenBefore,
        reason: 'premise: the stream has not delivered yet');
    inputs.invalidate();
    expect(inputs.generation, greaterThan(generation));
    final now = inputs.inputOf(partition)!;
    expect(now, isNot(seenBefore));
    final fresh = RoomInputs(plan.doc);
    addTearDown(fresh.dispose);
    expect(now, fresh.inputOf(partition));
  });

  test(
      'RI2 a RoomInput is equal only to the same source, kind and points, '
      'bit for bit; equal inputs hash alike', () {
    // Off the origin and fractional: one ulp here is ~9.3e-10.
    List<Vector2> pts() => [
          Vector2(4501234.5625, 1200678.125),
          Vector2(4503456.25, 1201876.375),
          Vector2(4502345.75, -1203210.5),
        ];
    final base = RoomInput(const Handle(40), pts(), closed: true);
    final same = RoomInput(const Handle(40), pts(), closed: true);
    expect(same, base);
    expect(same.hashCode, base.hashCode);
    for (var i = 0; i < 3; i++) {
      for (final axis in [0, 1]) {
        final p = pts();
        final v = axis == 0 ? p[i].x : p[i].y;
        final w = ulpAway(v);
        expect(w, isNot(v), reason: 'premise: one ulp is a different double');
        if (axis == 0) {
          p[i].x = w;
        } else {
          p[i].y = w;
        }
        expect(RoomInput(const Handle(40), p, closed: true) == base, isFalse,
            reason: 'point $i, axis $axis moved one ulp');
      }
    }
    expect(RoomInput(const Handle(41), pts(), closed: true) == base, isFalse,
        reason: 'another source');
    expect(RoomInput(const Handle(40), pts(), closed: false) == base, isFalse,
        reason: 'open');
    expect(
        RoomInput(const Handle(40), pts().sublist(0, 2), closed: true) == base,
        isFalse,
        reason: 'fewer points');
  });

  test(
      'RT5 a wall whose local ring falls back is traced as drawn: its '
      'input is its stored band in world, not 07\'s world outline', () {
    // 07's WR13 (the final review's I1): A 200 right into the hub, B 200
    // left out of it at 178°, both at the identity, turned 133° about the
    // hub at the far origin.
    const hA = Handle(1300), hB = Handle(2600);
    final hub = far(1234.5, 678.25);
    final doc = wallDoc();
    final id = Transform2.identity();
    doc.commands.execute(CompoundCommand([
      addWall(doc, hA, far(-2500, 678.25), hub, 200, Justification.right,
          at: id),
      addWall(doc, hB, hub, polar(hub, 178, 600), 200, Justification.left,
          at: id),
    ], label: 'Add L'));
    final turn = Transform2.translation(hub.x, hub.y)
        .multiply(Transform2.rotation(133 * math.pi / 180))
        .multiply(Transform2.translation(-hub.x, -hub.y));
    doc.commands.execute(CompoundCommand([
      for (final h in [hA, hB])
        TransformNodeCommand(h, turn.multiply(doc.tree[h]!.transform)),
    ], label: 'Rotate'));
    expect(driftOf(doc), isEmpty);

    // Premises: A's world outline is simple, its local image is not, and A
    // reports its fallback.
    final a = worldWallOf(doc, hA);
    final world = outline(a, [worldWallOf(doc, hB)]);
    expect(world.fellBack, isFalse);
    final toLocal = doc.tree.accumulatedTransform(hA).invert();
    expect(isSimpleCcw([for (final q in world.ring) toLocal.transformPoint(q)]),
        isFalse);
    expect([
      for (final d in diagnosticsOf(doc))
        if (d.code == 'wall.fallback') d.handles.single
    ], contains(hA));

    // A's input is its stored boundary in world, bit for bit, through both
    // adapters; and it is not 07's world outline.
    final stored = worldPoints(doc, boundaryOfWall(doc, hA), closed: true);
    final inputs = RoomInputs(doc);
    addTearDown(inputs.dispose);
    final viaDoc = inputs.inputOf(hA)!;
    expect(viaDoc.closed, isTrue);
    expect(xy(viaDoc.points), xy(stored));
    expect(probeView(doc).inputs[hA], viaDoc);
    expect(xy(viaDoc.points), isNot(xy(world.ring)),
        reason: 'the world outline is not what 07 draws here');

    // Control: B, which falls back in world already, is traced as stored
    // too.
    expect(xy(inputs.inputOf(hB)!.points),
        xy(worldPoints(doc, boundaryOfWall(doc, hB), closed: true)));
  });
}
