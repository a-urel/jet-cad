// POS-host Task 10 (spec D14): the Salon's three sections, the inspector's
// combo that links a table, a bar counter and a room to the demo's own fake
// records, and the side panel's section of each table. Named LK1-LK3 here
// (the plan's DL1-DL3: the look tests already own those numbers).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show boxOfDefinition;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/samples/place_tables.dart' show kSheetMin;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/demo_rig.dart';

/// The table labels of each section, as the sample draws it: the Garden
/// holds 2 and 3 (outside the south wall), the VIP corner the booths 6 and
/// 7, the Salon the rest.
const Map<String, Set<String>> kExpected = {
  'S-SALON': {'1', '4', '5', '8', '9', '10', '11'},
  'S-VIP': {'6', '7'},
  'S-GARDEN': {'2', '3'},
};

/// Table labels grouped by the section they stand in: one entry per distinct
/// section, none for a table in no section.
Map<PlanObjectRef, Set<String>> bySection(PlanController c) {
  final out = <PlanObjectRef, Set<String>>{};
  for (final d in c.unitDetails) {
    final s = d.section;
    expect(s, isNotNull, reason: 'table ${d.unit.label} stands in a section');
    out.putIfAbsent(s!.ref, () => {}).add(d.unit.label!);
  }
  return out;
}

/// A tap by the mouse at world point [at] (millimetres, y up), as a person
/// selects what stands there.
Future<void> tapWorld(WidgetTester tester, PlanController c, Offset at) async {
  await tester.tapAt(c.worldToGlobal(at)!, kind: PointerDeviceKind.mouse);
  await settle(tester);
}

/// The instance of definition [key] (`key@1`).
Handle instanceOf(PlanController c, String key) => [
      for (final n in c.document.tree.nodes)
        if (n is InstanceNode && definitionName(c, n.handle) == key) n.handle,
    ].single;

/// The centre of [h]'s box in world millimetres.
Offset centreOfInstance(PlanController c, Handle h) {
  final node = c.document.tree[h]! as InstanceNode;
  final b = boxOfDefinition(c.document, node.definition)!;
  final p = node.transform
      .transformPoint(Vector2((b.left + b.right) / 2, (b.front + b.back) / 2));
  return Offset(p.x, p.y);
}

/// The VIP room's label (sheet-relative 12500, 7375, off the origin): a tap on
/// a room's label selects the room; its floor picks nothing.
final Offset kVipLabel = Offset(kSheetMin.x + 12500, kSheetMin.y + 7375);

/// Moves [h] by ([dx], [dy]) mm in the design, one undo step.
void shift(PlanController c, Handle h, double dx, double dy) {
  final node = c.document.tree[h]! as InstanceNode;
  c.document.commands.execute(CompoundCommand([
    TransformNodeCommand(
        h, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

void main() {
  testWidgets(
      'LK1 (DL1) the Salon has three sections, and every sample table\'s '
      'section is the expected one, by label', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    final groups = bySection(c);
    expect(groups.length, 3, reason: 'Salon, VIP and Garden');
    expect(groups.values.toSet().map((s) => (s.toList()..sort()).join(',')),
        {for (final s in kExpected.values) (s.toList()..sort()).join(',')});
    // Not linked yet: the side panel names them all the same, and only
    // "Link sections" tells the rooms apart, by their probe tables.
    expect(textOf(tester, 'table-sections'), contains('6: not linked'));
    await pressInPanel(tester, 'link-sections');
    expect(demo.log.first, 'Salon: 3 sections linked');
    final linked = {
      for (final d in c.unitDetails) d.unit.label!: d.section!.data['id'],
    };
    for (final MapEntry(key: id, value: labels) in kExpected.entries) {
      for (final l in labels) {
        expect(linked[l], id, reason: 'table $l');
      }
    }
    expect(
        textOf(tester, 'table-sections'),
        '1: Salon, 2: Garden, 3: Garden, 4: Salon, 5: Salon, 6: VIP, 7: VIP, '
        '8: Salon, 9: Salon, 10: Salon, 11: Salon');
    // A second press links nothing more.
    await pressInPanel(tester, 'link-sections');
    expect(demo.log.first, 'Salon: 0 sections linked');
  });

  testWidgets(
      'LK2 (DL2) the inspector\'s combo links a table, a bar counter and the '
      'VIP room to fake records; the data round-trips through Save and '
      'Revert', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;

    // A table (the Tables profile), off the origin and in the VIP corner.
    await pressInPanel(tester, 'editor-tables');
    await tester.tapAt(unitScreen(c, '7'), kind: PointerDeviceKind.mouse);
    await settle(tester);
    expect(c.selectedUnits.value, {'7'});
    await pickRecord(tester, 'T-07');
    expect(c.unitDetails.singleWhere((d) => d.unit.label == '7').data,
        {'id': 'T-07'});
    expect(demo.log.first, 'Salon: table 7 is T-07');

    // The bar counter and the VIP room (the Full profile).
    await pressInPanel(tester, 'editor-full');
    await tapWorld(tester, c,
        centreOfInstance(c, instanceOf(c, 'restaurant.bar.counter@1')));
    // Only the bars are offered for the counter, never a table or a section.
    await tester.tap(byKey('pos-id'));
    await tester.pumpAndSettle();
    expect(byKey('pos-id-B-01'), findsWidgets);
    expect(byKey('pos-id-B-02'), findsWidgets);
    expect(byKey('pos-id-T-01'), findsNothing);
    expect(byKey('pos-id-S-VIP'), findsNothing);
    await tester.tap(byKey('pos-id-B-02').last);
    await tester.pumpAndSettle();
    expect(demo.log.first, 'Salon: bar counter is B-02');

    await tapWorld(tester, c, kVipLabel);
    await pickRecord(tester, 'S-VIP');
    expect(demo.log.first, 'Salon: room is S-VIP');

    Map<String, String> linkedNow() => {
          for (final d in c.objectDetails)
            '${d.kind.name}:${d.label ?? d.symbolKey}': d.data['id']!,
        };
    final want = {
      'unit:7': 'T-07',
      'symbol:restaurant.bar.counter': 'B-02',
      'type:Room': 'S-VIP',
    };
    expect(linkedNow(), want);

    // Save, unlink everything, Revert: the links are back.
    await pressInPanel(tester, 'save');
    expect(c.setObjectsData({for (final d in c.objectDetails) d.ref: const {}}),
        isTrue);
    await settle(tester);
    expect(linkedNow(), isEmpty);
    await pressInPanel(tester, 'revert');
    expect(linkedNow(), want);
    // And the combo shows the room's link after the reload.
    await tapWorld(tester, demo.area.controller, kVipLabel);
    expect(pickedId(tester), 'S-VIP');

    // Unlinking through the empty entry.
    await pickRecord(tester, '');
    expect(
        demo.area.controller.objectDetails
            .where((d) => d.kind == PlanObjectKind.type),
        isEmpty);
    expect(demo.log.first, 'Salon: room unlinked');
  });

  testWidgets(
      'LK3 (DL3) the side panel shows each table\'s section and updates when '
      'a table is moved into the Garden', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await pressInPanel(tester, 'link-sections');
    String line(String n) => RegExp('(?:^|, )$n: ([A-Za-z ]+)')
        .firstMatch(textOf(tester, 'table-sections'))!
        .group(1)!;
    expect(line('1'), 'Salon');
    expect(line('6'), 'VIP');
    expect(line('2'), 'Garden');

    // Table 1 (off the origin, rotated by the sheet's own offsets) south
    // into the Garden: 8850 mm down is its y, -1250 from the sheet corner.
    final one = unitInstance(c, '1')!;
    shift(c, one, 0, -8850);
    await settle(tester);
    expect(line('1'), 'Garden');
    expect(line('6'), 'VIP', reason: 'only the moved table changed');
    // And into the VIP corner: 8850 up and 9500 right of the Salon's seat.
    shift(c, one, 9000, 9000);
    await settle(tester);
    expect(line('1'), 'VIP');
    // Undo twice: back to the Salon.
    c.undo();
    c.undo();
    await settle(tester);
    expect(line('1'), 'Salon');
  });
}
