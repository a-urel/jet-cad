// Spec 10 D4: the trace inputs, through the view adapter and the document
// adapter, agree bit for bit (RI1); a wall whose local ring falls back is
// traced as drawn (RT5).
import 'dart:math' as math;

import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';
import 'support/wall_fixture.dart'
    show addWall, far, polar, wallDoc, worldWallOf;

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
        expect(seen.placedAll, [...plan.walls, ...plan.seps],
            reason: '$what: every wall and separator, ascending, and only '
                'those (no opening)');
      }
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
