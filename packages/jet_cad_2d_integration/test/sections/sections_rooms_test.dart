// Spec D10-D12 (POS-host Task 4) over the architecture kit's real rooms: a
// unit's section is the room whose traced outline holds its centre. Walls
// and a separator (a wall-less boundary) far off the origin and turned 23
// degrees, in groups of their own; tables are the fixture table whose box
// centre is its base point, so a placement at (x, y) puts the centre there.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/plans.dart';
import '../support/units.dart';

const Placement turned = Placement(
    'off origin, 23 deg, own groups', 40000, -30000, 23,
    groups: true);
const Placement axis = Placement(
    'off origin, axis aligned, own groups', 40000, -30000, 0,
    groups: true);

late Handle kitchen, room2, east, left, right;
late Plan layout;

void table(DraftDocument d, Plan plan, String label, double x, double y,
    {bool mirrored = false}) {
  final p = plan.at(x, y);
  final h = placeUnit(d, tableSymbol(),
      transform: placementAt(p.x, p.y, 37 * math.pi / 180, mirrored: mirrored));
  labelUnit(d, h, label);
}

/// Kitchen | Room 2 | East, the last two split by a separator at x = 6250.5.
String threeRooms({bool kitchenToo = true}) => planWith((d) {
      layout = buildPlan(d, twoRoomWalls,
          seps: const [(6250.5, 100, 6250.5, 3900)], place: turned);
      if (kitchenToo) kitchen = addRoom(d, layout.at(1500, 2000), 'Kitchen');
      room2 = addRoom(d, layout.at(4700, 2000), 'Room 2');
      east = addRoom(d, layout.at(7000, 2000), 'East');
      table(d, layout, 'K', 1500, 1000);
      table(d, layout, 'R', 4500, 3000, mirrored: true);
      table(d, layout, 'E', 7000, 3000);
      table(d, layout, 'O', 9500, 2000);
      table(d, layout, 'SEP', 6250.5, 2000, mirrored: true);
      d.commands.clearHistory();
    });

PlanController open(String json) {
  final c = PlanController(kits: [architectureKit, fxKit()], json: json);
  addTearDown(c.dispose);
  return c;
}

PlanUnitDetail unit(PlanController c, String label) =>
    c.unitDetails.singleWhere((u) => u.unit.label == label);

void expectSection(PlanController c, String label, Handle? room) {
  final section = unit(c, label).section;
  if (room == null) {
    expect(section, isNull, reason: label);
  } else {
    expect(section?.ref, refOf(room), reason: label);
    expect(section!.typeId, 'architecture.room');
  }
}

/// The reference to the object with [h]; handles are internal to the
/// package, which hands the host references it read, so a test that knows
/// the handle builds one.
// ignore: invalid_use_of_internal_member
PlanObjectRef refOf(Handle h) => PlanObjectRef.of(h);

void main() {
  test(
      'SC1 SC2 SC4 real rooms: each table in its room, one outside none, '
      'the separator line goes to the smaller room', () {
    final c = open(threeRooms());
    expectSection(c, 'K', kitchen);
    expectSection(c, 'R', room2);
    expectSection(c, 'E', east);
    expectSection(c, 'O', null);
    // Room 2 is 3200 wide, East 1650: the smaller (the higher handle) wins.
    expectSection(c, 'SEP', east);
    expect(room2.value < east.value, isTrue);
    expect(unit(c, 'SEP').mirrored, isTrue);
    // The same after save and load.
    final again = open(c.save());
    expectSection(again, 'SEP', east);
    expectSection(again, 'K', kitchen);
  });

  test('SC4 equal rooms either side of a separator: the lower handle', () {
    late Handle lower, higher;
    final json = planWith((d) {
      layout = buildPlan(d, boxWalls,
          seps: const [(4000, 100, 4000, 3900)], place: axis);
      // Right half first: the lower handle is the right room.
      lower = addRoom(d, layout.at(6000, 2000), 'Right');
      higher = addRoom(d, layout.at(2000, 2000), 'Left');
      table(d, layout, 'B', 4000, 2000);
      d.commands.clearHistory();
    });
    final c = open(json);
    expectSection(c, 'B', lower);
    expect(unit(c, 'B').section!.ref, isNot(refOf(higher)));
    expectSection(open(c.save()), 'B', lower);
  });

  testWidgets(
      'SC8 deleting one wall of a room (unbounded): its tables lose the '
      'section, one change reported', (tester) async {
    final c = open(threeRooms());
    final seen = <PlanSectionChange>[];
    final sub = c.sectionChanges.listen(seen.add);
    addTearDown(sub.cancel);
    expectSection(c, 'K', kitchen);
    // The kitchen's west wall (plan wall 3).
    final doc = c.document;
    doc.commands.execute(deleteObject(doc, layout.walls[3]));
    await tester.pump();
    expectSection(c, 'K', null);
    expectSection(c, 'R', room2);
    expect(seen, hasLength(1));
    expect(seen.single.byLabel, {'K': null});

    seen.clear();
    c.undo();
    await tester.pump();
    expectSection(c, 'K', kitchen);
    expect(seen.single.byLabel.keys, ['K']);
    expect(seen.single.byLabel['K']!.ref, refOf(kitchen));
  });

  testWidgets(
      'SC10 after load() of a different plan into the same controller, '
      'sections are those of the loaded plan', (tester) async {
    final c = open(threeRooms());
    expectSection(c, 'K', kitchen);
    final first = <PlanSectionChange>[];
    final sub = c.sectionChanges.listen(first.add);
    addTearDown(sub.cancel);
    // The same walls, no Kitchen: K stands in no room; the other handles
    // (and so the history counters) differ from the first plan's.
    final other = threeRooms(kitchenToo: false);
    c.load(other);
    await tester.pump();
    expectSection(c, 'K', null);
    expectSection(c, 'R', room2);
    expectSection(c, 'SEP', east);
    expect(first, isEmpty, reason: 'a load reports no section change');
    // And back.
    c.load(threeRooms());
    await tester.pump();
    expectSection(c, 'K', kitchen);
  });
}
