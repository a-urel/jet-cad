// Spec D10-D12 (POS-host Task 4): a unit's section and its change events.
// Fixture over the test zone kit (a rectangle that declares its outline):
// every zone and table sits tens of metres off the origin; the Salon is
// turned 20 degrees, its VIP corner shares that turn, the Garden is
// mirrored; tables are turned 37 degrees, mirrored, scaled. The kit's
// real room is exercised in jet_cad_2d_integration.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/objects/sections.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart' show planText;
import '../support/unit_embedding_fixture.dart'
    show embeddingPlacement, embeddingTable;
import '../support/unit_fixtures.dart';
import '../support/zone_kit.dart';

/// The Salon: 12000 x 8000, turned 20 degrees, at (30000, -40000).
final Transform2 salonT = Transform2.translation(30000, -40000)
    .multiply(Transform2.rotation(20 * math.pi / 180));

/// The VIP corner: 3000 x 2000 inside the Salon at local (1000, 1000).
final Transform2 vipT = salonT.multiply(Transform2.translation(1000, 1000));

/// The Garden: 5000 x 5000, mirrored in y, east of the Salon.
final Transform2 gardenT = Transform2(1, 0, 0, -1, 52000, -30000);

late Handle salon, vip, garden;

/// The world point of local ([x], [y]) in [zone].
Offset at(Transform2 zone, double x, double y) {
  final p = zone.transformPoint(Vector2(x, y));
  return Offset(p.x, p.y);
}

/// Places the embedding table so its box centre is [centre], turned
/// [degrees] (and mirrored when [sy] < 0); labels it [label].
Handle tableAt(DraftDocument d, String label, Offset centre, double degrees,
    {double sy = 1, double sx = 1}) {
  final zero = embeddingPlacement(0, 0, degrees, sx: sx, sy: sy);
  final c0 = zero.transformPoint(Vector2(700, 100));
  final h = placeUnit(d, embeddingTable,
      transform: embeddingPlacement(centre.dx - c0.x, centre.dy - c0.y, degrees,
          sx: sx, sy: sy));
  addUnitLabel(d, h, label);
  return h;
}

String plan({void Function(DraftDocument d)? more}) =>
    planText([fxKit(), zoneKit], (d) {
      salon = addZone(d, 12000, 8000, salonT);
      vip = addZone(d, 3000, 2000, vipT);
      garden = addZone(d, 5000, 5000, gardenT);
      tableAt(d, 'S1', at(salonT, 9000, 6000), 37);
      tableAt(d, 'S2', at(salonT, 7000, 1500), 37, sy: -1);
      tableAt(d, 'V1', at(vipT, 1500, 1000), 37, sx: 1.4);
      tableAt(d, 'G1', at(gardenT, 2500, 2500), 37, sy: -1);
      tableAt(d, 'O1', const Offset(40000, -60000), 37);
      more?.call(d);
      d.commands.clearHistory();
    });

PlanController controller([String? json]) {
  final c = PlanController(kits: [fxKit(), zoneKit], json: json ?? plan());
  addTearDown(c.dispose);
  return c;
}

PlanUnitDetail unit(PlanController c, String label) =>
    c.unitDetails.singleWhere((u) => u.unit.label == label);

/// The section a unit stands in, by the zone it names (the zone's handle
/// through the plan's own reference).
void expectSection(PlanController c, String label, Handle? zone) {
  final section = unit(c, label).section;
  if (zone == null) {
    expect(section, isNull, reason: label);
  } else {
    expect(section, isNotNull, reason: label);
    expect(section!.ref, PlanObjectRef.of(zone), reason: label);
    expect(section.kind, PlanObjectKind.type);
    expect(section.typeId, 'zone.area');
    expect(section.label, 'Zone');
  }
}

List<PlanSectionChange> listen(PlanController c) {
  final seen = <PlanSectionChange>[];
  final sub = c.sectionChanges.listen(seen.add);
  addTearDown(sub.cancel);
  return seen;
}

void moveTo(DraftDocument d, PlanController c, String label, Offset centre) {
  final h = c.unitIndex.withLabel(label).single.instance;
  final node = d.tree[h]! as InstanceNode;
  final now = c.unitDetails.singleWhere((u) => u.unit.label == label).center!;
  d.commands.execute(TransformNodeCommand(
      h,
      Transform2.translation(centre.dx - now.dx, centre.dy - now.dy)
          .multiply(node.transform)));
}

void main() {
  test('SC1 two rooms, tables in each: each table\'s section is its room', () {
    final c = controller();
    expectSection(c, 'S1', salon);
    expectSection(c, 'S2', salon);
    expectSection(c, 'G1', garden);
  });

  test('SC2 a table outside every room: null', () {
    final c = controller();
    expectSection(c, 'O1', null);
  });

  test(
      'SC3 a VIP room inside the Salon: tables in the VIP corner get VIP, '
      'the rest Salon', () {
    final c = controller();
    expectSection(c, 'V1', vip);
    expectSection(c, 'S1', salon);
  });

  testWidgets(
      'SC4 a table on the boundary shared by two zones: the smaller; equal '
      'zones: the lower handle; the same after save and load', (tester) async {
    late Handle small, big, left, right;
    String twoPlans(bool equal) => planText([fxKit(), zoneKit], (d) {
          // Shared edge x = 61000, no turn (an exact boundary).
          // Unequal: the lower handle (left) is the larger zone.
          final wide = equal ? 4000.0 : 9000.0;
          left = addZone(
              d, wide, 6000, Transform2.translation(61000 - wide, -33000));
          right = addZone(d, 4000, 6000, Transform2(1, 0, 0, 1, 61000, -33000));
          small = right;
          big = left;
          tableAt(d, 'B', const Offset(61000, -30000), 37);
          d.commands.clearHistory();
        });
    var c = controller(twoPlans(false));
    expectSection(c, 'B', small);
    expect(unit(c, 'B').section!.ref, isNot(PlanObjectRef.of(big)));

    c = controller(twoPlans(true));
    expectSection(c, 'B', left);
    expect(unit(c, 'B').section!.ref, isNot(PlanObjectRef.of(right)));
    final reloaded = controller(c.save());
    // Handles persist across save and load: the same zone, the lower one.
    expect(
        reloaded.unitDetails
            .singleWhere((u) => u.unit.label == 'B')
            .section!
            .ref,
        PlanObjectRef.of(left));
    expect(left.value < right.value, isTrue);
  });

  test(
      'SC5 rotated (37 deg) and mirrored tables, a zone not at the origin: '
      'the centre decides', () {
    final c = controller();
    // A table whose box pokes out of the Salon but whose centre is inside,
    // and one whose box reaches in with its centre outside.
    final d = c.document;
    tableAt(d, 'IN', at(salonT, 11800, 7800), 37, sx: 3);
    tableAt(d, 'OUT', at(salonT, 12100, 4000), 37, sx: 3);
    expectSection(c, 'IN', salon);
    expectSection(c, 'OUT', null);
    expect(unit(c, 'S2').mirrored, isTrue);
    expect(unit(c, 'S2').rotation, isNot(0));
  });

  testWidgets(
      'SC6 moving a table across rooms in design reports one change with '
      'that label only; within its room reports nothing', (tester) async {
    final c = controller();
    final seen = listen(c);
    final d = c.document;
    moveTo(d, c, 'S1', at(salonT, 6000, 2000));
    await tester.pump();
    expect(seen, isEmpty, reason: 'within the Salon');

    moveTo(d, c, 'S1', at(gardenT, 1000, 4000));
    await tester.pump();
    expect(seen, hasLength(1));
    expect(seen.single.byLabel.keys, ['S1']);
    expect(seen.single.byLabel['S1']!.ref, PlanObjectRef.of(garden));

    seen.clear();
    moveTo(d, c, 'S1', const Offset(70000, -70000));
    await tester.pump();
    expect(seen.single.byLabel, {'S1': null});

    seen.clear();
    c.undo();
    await tester.pump();
    expect(seen.single.byLabel['S1']!.ref, PlanObjectRef.of(garden));
  });

  testWidgets(
      'SC7 a service-mode layout move across rooms reports the change; '
      'leaving service reports the discarded move back', (tester) async {
    final c = controller();
    final seen = listen(c);
    c.setMode(PlanMode.service);
    await tester.pump();
    expect(seen, isEmpty, reason: 'entering service changes no section');
    moveTo(c.serviceSession!.document, c, 'S2', at(gardenT, 2000, 1000));
    await tester.pump();
    expect(seen, hasLength(1));
    expect(seen.single.byLabel.keys, ['S2']);
    expect(seen.single.byLabel['S2']!.ref, PlanObjectRef.of(garden));
    expectSection(c, 'S2', garden);

    seen.clear();
    c.setMode(PlanMode.design);
    await tester.pump();
    expect(seen, hasLength(1));
    expect(seen.single.byLabel['S2']!.ref, PlanObjectRef.of(salon));
  });

  testWidgets(
      'SC8 a zone resized so its table is outside: the table loses the '
      'section, one change; a unit added or removed is no section change',
      (tester) async {
    final c = controller();
    final seen = listen(c);
    final units = <PlanUnitChange>[];
    final unitSub = c.unitChanges.listen(units.add);
    addTearDown(unitSub.cancel);
    final d = c.document;
    d.commands.execute(SetComponentCommand<ZoneComponent>(
        garden, const ZoneComponent(5000, 1000)));
    await tester.pump();
    expect(units, isEmpty,
        reason: 'a section change alone is no PlanUnitChanged');
    expect(seen, hasLength(1));
    expect(seen.single.byLabel, {'G1': null});
    expectSection(c, 'G1', null);

    seen.clear();
    tableAt(d, 'NEW', at(salonT, 5000, 5000), 37);
    await tester.pump();
    expect(seen, isEmpty, reason: 'a unit placed is a PlanUnitAdded');
    expectSection(c, 'NEW', salon);
    c.undo();
    c.undo();
    await tester.pump();
    expect(seen, isEmpty, reason: 'a unit removed is a PlanUnitRemoved');
  });

  testWidgets(
      'SC9 sections are computed when the unit index rebuilds, not per read: '
      'two reads and a frame call the area capability once per zone',
      (tester) async {
    final c = controller();
    c.unitDetails;
    final calls = zoneAreaCalls;
    for (var i = 0; i < 5; i++) {
      c.unitDetails;
      c.unitAt(const Offset(10, 10));
    }
    await tester.pump();
    expect(zoneAreaCalls, calls, reason: 'cached with the unit index');
    final first = c.unitDetails;
    expect(identical(first, c.unitDetails), isTrue);
    moveTo(c.document, c, 'S1', at(salonT, 5000, 2000));
    c.unitDetails;
    expect(zoneAreaCalls, calls + 3, reason: 'three zones, once, on rebuild');
  });

  testWidgets(
      'SC10 after load() of a different plan into the same controller, '
      'sections are those of the loaded plan', (tester) async {
    final c = controller();
    expectSection(c, 'S1', salon);
    final seen = listen(c);
    // A different plan: the Salon exists but moved far away; S1 stands where
    // the old Salon was; and a table "S2" stands in the moved Salon.
    late Handle moved;
    final other = planText([fxKit(), zoneKit], (d) {
      moved = addZone(d, 12000, 8000, Transform2.translation(-50000, 60000));
      tableAt(d, 'S1', at(salonT, 9000, 6000), 37);
      tableAt(d, 'S2', const Offset(-45000, 63000), 37);
      d.commands.clearHistory();
    });
    c.load(other);
    await tester.pump();
    expectSection(c, 'S1', null);
    expectSection(c, 'S2', moved);
    expect(seen, isEmpty, reason: 'a load reports no section change');
    // The baseline moved with the load: only the next move is reported.
    moveTo(c.document, c, 'S1', const Offset(-46000, 61000));
    await tester.pump();
    expect(seen, hasLength(1));
    expect(seen.single.byLabel.keys, ['S1']);
    expect(seen.single.byLabel['S1']!.ref, PlanObjectRef.of(moved));
  });

  test('the section is part of the detail\'s equality and hash', () {
    final c = controller();
    final s1 = unit(c, 'S1');
    final bare = s1.withSection(null);
    expect(bare, isNot(s1));
    expect(s1.withSection(s1.section), s1);
    expect(s1.withSection(s1.section).hashCode, s1.hashCode);
    expect(bare.sameBesidesSection(s1), isTrue);
  });

  test('SectionFinder: smallest area, ties to the lower handle', () {
    Vector2 v(double x, double y) => Vector2(x, y);
    final big =
        SectionArea(Handle(9), [v(0, 0), v(10, 0), v(10, 10), v(0, 10)]);
    final small = SectionArea(Handle(7), [v(2, 2), v(4, 2), v(4, 4), v(2, 4)]);
    final twin = SectionArea(Handle(3), [v(2, 2), v(4, 2), v(4, 4), v(2, 4)]);
    expect(SectionFinder([big, small]).sectionAt(3, 3), Handle(7));
    expect(SectionFinder([big, small, twin]).sectionAt(3, 3), Handle(3));
    expect(SectionFinder([twin, small, big]).sectionAt(3, 3), Handle(3));
    expect(SectionFinder([big, small]).sectionAt(8, 8), Handle(9));
    expect(SectionFinder([big, small]).sectionAt(11, 5), isNull);
    expect(SectionFinder([big]).sectionAt(10, 5), Handle(9),
        reason: 'the boundary is inside');
  });
}
