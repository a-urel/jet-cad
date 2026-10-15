// Spec 3a C1.5, C2: the room inputs as the kit's code sees them in a plan.
// roomInputsOf(services) is the kit's one RoomInputs per document
// (PlanServices.shared, disposed with it), and its live rule is the plan's
// liveTypeIdOf: a frozen wall or separator is no input, exactly as it is in
// no survey (E2), while the catalog still answers its type id.
//
// The plan is the two-room box (a 100 mm partition at x 3,000) with a
// separator face to face at x 6,250.5, at the corpus far origin turned 23°,
// every wall and the separator in its own rotated, translated group.
// Expected areas are hand arithmetic: inner faces 100 in. RR-freeze adds a
// second separator at x 1,500.25 and freezes one object at a time with no
// document change, as a plan does (Task 12's WL4 for the bands).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTypes;
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart';

import '../support/room_fixture.dart';

/// The plan of both cases.
Plan fixture() => buildPlan(twoRoomWalls,
    seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);

void main() {
  test(
      'RR-live a frozen wall and a frozen separator are no input to rooms; '
      'the catalog still names them (M-RR-1, M-RR-2)', () {
    final plan = fixture();
    final doc = plan.doc;
    final partition = plan.walls[4], sep = plan.seps.single;
    final frozen = FakePlanServices(
        document: doc, catalog: testCatalog(), frozen: {partition, sep});
    addTearDown(frozen.dispose);
    // Premises: the catalog names both; the plan's live rule names neither.
    expect(testCatalog().typeIdOf(doc, partition), ArchitectureTypes.wall);
    expect(testCatalog().typeIdOf(doc, sep), ArchitectureTypes.separator);
    expect(frozen.liveTypeIdOf(partition), isNull);
    expect(frozen.liveTypeIdOf(sep), isNull);

    final inputs = roomInputsOf(frozen);
    expect(inputs.inputOf(partition), isNull);
    expect(inputs.inputOf(sep), isNull);
    expect(inputs.placedIn(everywhere), plan.walls.take(4).toList(),
        reason: 'the four outer walls only, ascending');
    expect(inputs.wallNeighboursOf(plan.walls[0]), isNot(contains(partition)));
    // Traced among them, the seed's face is the whole box:
    // 7,800 × 3,800 = 29,640,000.
    final whole = traceRoomAmong(plan.at(1500.25, 2000.5), inputs);
    expect(whole, isA<Traced>());
    expect((whole as Traced).area, closeTo(29640000, 1e-2));

    // The control: nothing frozen. The partition and the separator are
    // inputs; the left face is 2,850 × 3,800 = 10,830,000.
    final live = FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(live.dispose);
    final all = roomInputsOf(live);
    expect(all.inputOf(partition), isNotNull);
    expect(all.inputOf(sep), isNotNull);
    expect(all.placedIn(everywhere), [...plan.walls, sep]);
    final left = traceRoomAmong(plan.at(1500.25, 2000.5), all) as Traced;
    expect(left.area, closeTo(10830000, 1e-2));
  });

  test(
      'RR-shared one RoomInputs per services; it follows the document\'s '
      'changes and is released with its services (M-RR-3, M-RR-4)', () async {
    final plan = fixture();
    final doc = plan.doc;
    final s = FakePlanServices(document: doc, catalog: testCatalog());
    final inputs = roomInputsOf(s);
    expect(roomInputsOf(s), same(inputs), reason: 'one per document');
    expect(inputs.live(plan.walls[4]), ArchitectureTypes.wall,
        reason: 'the services\' live rule');

    // A change stales it once delivered (today's `changes` subscription).
    final g0 = inputs.generation;
    doc.commands
        .execute(moveWall(plan, 4, const W(3300.5, 0, 3300.5, 4000, 100)));
    await Future<void>.delayed(Duration.zero);
    expect(inputs.generation, greaterThan(g0), reason: 'invalidated');

    // Released with its services: no subscription is left.
    s.dispose();
    final g1 = inputs.generation;
    doc.commands.execute(moveWall(plan, 4, const W(3000, 0, 3000, 4000, 100)));
    await Future<void>.delayed(Duration.zero);
    expect(inputs.generation, g1, reason: 'disposed with its services');
  });

  test(
      'RR-freeze a wall or separator frozen with no document change stops '
      'being an input at the next read, whichever reader comes first: the '
      "services' frozen set grows, no change is reported, and inputOf, "
      'traceRoomAmong, placedIn, wallNeighboursOf and generation each see it '
      'gone at once (spec 3a C1.5; M-RR-9)', () {
    // Two separators, face to face: x 6,250.5 in the right room and
    // x 1,500.25 in the left one, at the corpus far origin turned 23°, every
    // object in its own rotated, translated group.
    final plan = buildPlan(twoRoomWalls,
        seps: const [
          (6250.5, 100, 6250.5, 3900),
          (1500.25, 100, 1500.25, 3900)
        ],
        place: corpusGroups);
    final doc = plan.doc;
    final partition = plan.walls[4];
    final (right, left) = (plan.seps[0], plan.seps[1]);
    final frozen = <Handle>{};
    final services =
        FakePlanServices(document: doc, catalog: testCatalog(), frozen: frozen);
    addTearDown(services.dispose);
    final inputs = roomInputsOf(services);
    final seed = plan.at(750.5, 2000.5);
    double areaAt() => (traceRoomAmong(seed, inputs) as Traced).area;

    // Read once with everything live: the left separator bounds the seed's
    // face, 1,400.25 × 3,800 = 5,320,950.
    expect(inputs.placedIn(everywhere), [...plan.walls, right, left]);
    expect(areaAt(), closeTo(5320950, 1e-2));
    expect(inputs.wallNeighboursOf(plan.walls[0]), contains(partition));
    final state = doc.commands.stateId;
    final rebuilds = inputs.debugRebuilds;
    expect(inputs.inputOf(left), isNotNull);
    expect(inputs.debugRebuilds, rebuilds, reason: 'nothing frozen yet');

    // The left separator frozen; the first reader is inputOf.
    frozen.add(left);
    expect(inputs.inputOf(left), isNull);
    expect(inputs.inputOf(right), isNotNull, reason: 'the right one stays');
    // The whole left room, 2,850 × 3,800 = 10,830,000.
    expect(areaAt(), closeTo(10830000, 1e-2));

    // The partition frozen; the first reader is the trace: the face runs to
    // the right separator, 6,150.5 × 3,800 = 23,371,900.
    frozen.add(partition);
    expect(areaAt(), closeTo(23371900, 1e-2));
    expect(inputs.inputOf(partition), isNull);

    // What the rebuilt cache lists: the four outer walls and the right
    // separator; wall 0's neighbours no longer name the partition.
    expect(inputs.placedIn(everywhere), [...plan.walls.take(4), right]);
    expect(inputs.wallNeighboursOf(plan.walls[0]), isNot(contains(partition)));

    // The right separator frozen; the first reader is generation, which
    // moves at once, so a tool's memo keyed on it drops; then placedIn.
    final g = inputs.generation;
    frozen.add(right);
    expect(inputs.generation, greaterThan(g), reason: 'the cache went stale');
    expect(inputs.placedIn(everywhere), plan.walls.take(4).toList());
    // The whole box, 7,800 × 3,800 = 29,640,000.
    expect(areaAt(), closeTo(29640000, 1e-2));

    // A wall frozen whose first reader is wallNeighboursOf: wall 0 leaves
    // wall 1's neighbours.
    expect(inputs.wallNeighboursOf(plan.walls[1]), contains(plan.walls[0]));
    frozen.add(plan.walls[0]);
    expect(
        inputs.wallNeighboursOf(plan.walls[1]), isNot(contains(plan.walls[0])));
    expect(doc.commands.stateId, state, reason: 'no document change');
  });
}
