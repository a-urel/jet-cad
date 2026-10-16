// Ported from the old apps/restaurant_demo/test/demo_test.dart (audit
// section 4, docs/superpowers/specs/2026-10-16-restaurant-kit-test-audit.md):
// the table groups of table-groups spec G6 and fixes spec X2 -- Merge (grow
// or a new `G<n>`), Split, the status buttons by `selectedGroup`, the
// groups line and `onGroupTap`: D16 G6, D17b, D17 G6, D18 G6, D20 G6, D21
// X2 to D24 X2, D19 G6 (dark).
//
// The old fixture was a plan of eight tables numbered 12, 3, 7, 20, 5, 11,
// 8, 9 in handle order, 8 on a locked layer and 9 on a hidden one. Here it
// is the Salon's first eight units relabelled the same way by raw commands
// before the service is entered (units 7 and 8 of the Salon are a booth and
// a stool), its last three renamed out of the way; the tables 1-8 of the old
// numbering keep their roles.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/demo_rig.dart';

/// The numbers of the fixture's units in handle order: not sorted. 8 sits on
/// a visible locked layer, 9 on a hidden one.
const groupNumbers = ['12', '3', '7', '20', '5', '11', '8', '9'];

/// [DemoHomeState]'s Salon in the service, relabelled as [groupNumbers].
Future<DemoHomeState> pumpGroups(WidgetTester tester,
    {bool dark = false}) async {
  if (dark) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  final demo = await pumpDemo(tester);
  final c = demo.area.controller;
  relabel(c, {
    for (var i = 0; i < groupNumbers.length; i++) '${i + 1}': groupNumbers[i],
    '9': '31',
    '10': '32',
    '11': '33',
  });
  putOnLayer(c, '8', 'Locked', locked: true);
  putOnLayer(c, '9', 'Hidden', visible: false);
  await tester.pump();
  await enterService(tester);
  return demo;
}

Future<void> tapTable(WidgetTester tester, DemoHomeState demo, String n,
    {bool add = false}) async {
  if (add) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(unitScreen(demo.area.controller, n),
      kind: PointerDeviceKind.mouse);
  if (add) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> selectByField(WidgetTester tester, String text) async {
  await tester.enterText(byKey('select-number'), text);
  await tester.tap(byKey('select'));
  await tester.pump();
}

Future<void> press(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.pump();
}

String groupsLine(WidgetTester tester) =>
    tester.widget<Text>(byKey('groups')).data!;

Map<String, Set<String>> membersOf(DemoHomeState demo) => {
      for (final e in demo.area.controller.unitGroups.value.entries)
        e.key: e.value.members
    };

void main() {
  testWidgets(
      'D16 G6: Merge makes G1, Merge again grows it; a tap on a member is '
      'logged as the group\'s; Bill goes to the group; a drag moves the '
      'group; Split drops the group and its status', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    expect(groupsLine(tester), 'none');

    // Two tables by Shift taps, out of order.
    await tapTable(tester, demo, '12');
    await tapTable(tester, demo, '3', add: true);
    expect(c.selectedUnits.value, {'12', '3'});
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G1': {'3', '12'}
    });
    expect(demo.log.first, 'Salon: Merged {3, 12} as G1');
    expect(groupsLine(tester), 'G1: 3+12');
    expect(c.selectedGroup.value, 'G1');

    // G1 plus a third table by the number field: 3 selects all of G1.
    await selectByField(tester, '3, 7');
    expect(c.selectedUnits.value, {'3', '7', '12'});
    await press(tester, 'service-merge');
    expect(
        membersOf(demo),
        {
          'G1': {'3', '7', '12'}
        },
        reason: 'grown under its id, no new group');
    expect(demo.log.first, 'Salon: Merged {3, 7, 12} as G1');
    expect(groupsLine(tester), 'G1: 3+7+12');

    // A tap on a table in no group reports no group.
    await tapTable(tester, demo, '20');
    expect(demo.log.first, 'Salon: tapped 20');
    expect(c.selectedGroup.value, isNull);
    // Per table while no group is selected.
    await press(tester, 'status-eating');
    expect(c.unitStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(c.groupStatuses.value, isEmpty);

    // A tap on a member selects the group and is logged as the group's.
    await tapTable(tester, demo, '7');
    expect(demo.log.take(3).toList(), [
      'Salon: group G1 tapped at 7',
      'Salon: tapped 7',
      'Salon: selected {12, 3, 7}',
    ]);
    expect(c.selectedGroup.value, 'G1');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value, {'G1': DemoHomeState.kStatuses['Bill']});
    expect(c.unitStatuses.value, {'20': DemoHomeState.kStatuses['Eating']},
        reason: 'the members\' own statuses are left alone');
    expect(demo.log.first, 'Salon: Bill for G1');
    expect(groupsLine(tester), 'G1: 3+7+12 (Bill)');

    // A drag on a member moves every member by the same step, nothing else.
    final before = {for (final n in groupNumbers.take(5)) n: placementOf(c, n)};
    await tapTable(tester, demo, '20');
    final g = await tester.startGesture(unitScreen(c, '3'),
        kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(30, 25));
    await g.up();
    await tester.pump();
    expect(demo.log.where((l) => l == 'Salon: layout changed'), hasLength(1));
    final after = {for (final n in before.keys) n: placementOf(c, n)};
    final step =
        Vector2(after['3']!.e - before['3']!.e, after['3']!.f - before['3']!.f);
    expect(step.length, greaterThan(100), reason: 'the drag moved 3');
    for (final n in ['12', '7']) {
      expect(after[n]!.e - before[n]!.e, moreOrLessEquals(step.x), reason: n);
      expect(after[n]!.f - before[n]!.f, moreOrLessEquals(step.y), reason: n);
      expect((
        after[n]!.a,
        after[n]!.b,
        after[n]!.c,
        after[n]!.d
      ), (
        before[n]!.a,
        before[n]!.b,
        before[n]!.c,
        before[n]!.d
      ), reason: 'only moved');
    }
    for (final n in ['20', '5']) {
      expect(after[n], before[n], reason: '$n is in no group');
    }

    // Free on the selected group clears its status only.
    expect(c.selectedGroup.value, 'G1', reason: 'the drag selected G1');
    await press(tester, 'status-free');
    expect(c.groupStatuses.value, isEmpty);
    expect(c.unitStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Free for G1');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value, {'G1': DemoHomeState.kStatuses['Bill']});

    // Split: the group and its status go; table 20's own status stays.
    await press(tester, 'service-split');
    expect(c.unitGroups.value, isEmpty);
    expect(c.groupStatuses.value, isEmpty);
    expect(c.unitStatuses.value, {'20': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Split G1');
    expect(groupsLine(tester), 'none');
    expect(tester.takeException(), isNull);
  });

  test(
      'D17b G6: the next id counts every id\'s trailing digits, a POS\'s own '
      'prefix included (Copilot review on #8)', () {
    expect(DemoHomeState.nextGroupId(const []), 'G1');
    expect(DemoHomeState.nextGroupId(const ['VIP9', 'G3']), 'G10');
    expect(DemoHomeState.nextGroupId(const ['Window', 'G2']), 'G3',
        reason: 'an id with no digits counts for nothing');
    expect(DemoHomeState.nextGroupId(const ['T007']), 'G8');
  });

  testWidgets(
      'D17 G6: a new group is G<largest suffix + 1> after a split; a merge '
      'spanning two groups makes a new one, and the groups it empties go '
      'with their statuses', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    for (final pair in ['12, 3', '7, 20', '5, 11']) {
      await selectByField(tester, pair);
      await press(tester, 'service-merge');
    }
    expect(membersOf(demo), {
      'G1': {'12', '3'},
      'G2': {'7', '20'},
      'G3': {'5', '11'},
    });
    await selectByField(tester, '7');
    expect(c.selectedGroup.value, 'G2');
    await press(tester, 'service-split');
    expect(c.unitGroups.value.keys, unorderedEquals(['G1', 'G3']));

    await selectByField(tester, '20, 7');
    await press(tester, 'service-merge');
    expect(
        membersOf(demo),
        {
          'G1': {'12', '3'},
          'G3': {'5', '11'},
          'G4': {'7', '20'},
        },
        reason: 'G4, not a second G3');
    expect(demo.log.first, 'Salon: Merged {7, 20} as G4');

    await selectByField(tester, '3');
    await press(tester, 'status-ordered');
    await selectByField(tester, '11');
    await press(tester, 'status-bill');
    expect(c.groupStatuses.value.keys, unorderedEquals(['G1', 'G3']));
    expect(groupsLine(tester), 'G1: 3+12 (Ordered), G3: 5+11 (Bill), G4: 7+20');

    // G1 and G3 together touch two groups: a new group, not a grown one.
    await selectByField(tester, '11, 3');
    expect(c.selectedUnits.value, {'12', '3', '5', '11'});
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G4': {'7', '20'},
      'G5': {'12', '3', '5', '11'},
    });
    expect(demo.log.first, 'Salon: Merged {3, 5, 11, 12} as G5');
    expect(c.groupStatuses.value, isEmpty,
        reason: 'G1 and G3 are gone, so are their statuses (R-C5-2)');
    expect(groupsLine(tester), 'G4: 7+20, G5: 3+5+11+12');

    // The id comes from the groups before the merge: G6, not a reused G1.
    await selectByField(tester, '20, 5');
    await press(tester, 'service-merge');
    expect(membersOf(demo), {
      'G6': {'7', '20', '12', '3', '5', '11'},
    });
    expect(demo.log.first, 'Salon: Merged {3, 5, 7, 11, 12, 20} as G6');
  });

  testWidgets(
      'D18 G6: a POS-restored group with a locked and a hidden member grows '
      '(neither is ever selected) and keeps its label', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
    });
    await tester.pump();
    await tapTable(tester, demo, '3');
    expect(c.selectedUnits.value, {'12', '3'}, reason: '8 is locked, 9 hidden');
    expect(c.selectedGroup.value, 'G7');
    await tapTable(tester, demo, '20', add: true);
    expect(c.selectedUnits.value, {'12', '3', '20'});
    await press(tester, 'service-merge');
    expect(c.unitGroups.value, {
      'G7': UnitGroup(members: {'12', '3', '8', '9', '20'}, label: 'Window')
    });
    expect(demo.log.first, 'Salon: Merged {3, 12, 20} as G7');
    expect(groupsLine(tester), 'G7: 3+8+9+12+20');
  });

  testWidgets(
      'D20 G6, R-C5-4: a new-group merge leaves what remains of a POS group '
      'under its id and label, and drops a group it empties (review 5)',
      (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
      'G1': UnitGroup(members: {'5', '11'}),
    });
    await tester.pump();
    await tapTable(tester, demo, '3');
    await tapTable(tester, demo, '5', add: true);
    expect(c.selectedUnits.value, {'12', '3', '5', '11'},
        reason: 'premise: 8 locked, 9 hidden, both groups whole');
    await press(tester, 'service-merge');
    expect(c.unitGroups.value, {
      'G7': UnitGroup(members: {'8', '9'}, label: 'Window'),
      'G8': UnitGroup(members: {'12', '3', '5', '11'}),
    });
  });

  // Table-groups fixes spec X2: the grow rule is G6's literal one, over
  // `PlanController.selectableMembers` (R-C5-1 retired).

  testWidgets(
      'D21 X2, M-TGF-4: groups set under a live selection that holds part of '
      'a group make a new group, not a grown one', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    await selectByField(tester, '3, 20');
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'}),
    });
    await tester.pump();
    expect(c.selectedUnits.value, {'3', '20'},
        reason: 'premise: half of G7 selected');
    await press(tester, 'service-merge');
    expect(c.unitGroups.value, {
      'G7': UnitGroup(members: {'12', '7'}),
      'G8': UnitGroup(members: {'3', '20'}),
    });
    expect(demo.log.first, 'Salon: Merged {3, 20} as G8');
  });

  testWidgets('D22 X2, M-TGF-6: a group with no selectable member never grows',
      (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setUnitGroups({
      'G9': UnitGroup(members: {'8', '9'}, label: 'Back'),
    });
    await tester.pump();
    await selectByField(tester, '20, 5');
    expect(c.selectedUnits.value, {'5', '20'});
    expect(c.selectableMembers('G9'), isEmpty,
        reason: 'premise: 8 locked, 9 hidden');
    await press(tester, 'service-merge');
    expect(c.unitGroups.value, {
      'G9': UnitGroup(members: {'8', '9'}, label: 'Back'),
      'G10': UnitGroup(members: {'20', '5'}),
    });
    expect(demo.log.first, 'Salon: Merged {5, 20} as G10');
  });

  testWidgets(
      'D23 X2, M-TGF-7: a grow takes a number from another group, which '
      'keeps its id, label and group status', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3'}),
    });
    await tester.pump();
    await selectByField(tester, '3, 5');
    expect(c.selectedUnits.value, {'12', '3', '5'});
    final bill = DemoHomeState.kStatuses['Bill']!;
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3'}),
      'G1': UnitGroup(members: {'5', '11'}, label: 'Bar'),
    });
    c.setGroupStatus({'G1': bill});
    await tester.pump();
    expect(c.selectedUnits.value, {'12', '3', '5'},
        reason: 'premise: part of G1 selected');
    await press(tester, 'service-merge');
    expect(tester.takeException(), isNull);
    expect(c.unitGroups.value, {
      'G7': UnitGroup(members: {'12', '3', '5'}),
      'G1': UnitGroup(members: {'11'}, label: 'Bar'),
    });
    expect(c.groupStatuses.value, {'G1': bill});
    expect(demo.log.first, 'Salon: Merged {3, 5, 12} as G7');
    expect(groupsLine(tester), 'G1: 11 (Bill), G7: 3+5+12');
  });

  testWidgets(
      'D24 X2 edge cases from a host: a request of exactly one group\'s '
      'selectable members is a logged no-op grow; an empty request changes '
      'nothing', (tester) async {
    final demo = await pumpGroups(tester);
    final c = demo.area.controller;
    final groups = {
      'G7': UnitGroup(members: {'12', '3', '8', '9'}, label: 'Window'),
      'G2': UnitGroup(members: {'20', '5'}),
    };
    c.setUnitGroups(groups);
    c.setGroupStatus({'G7': DemoHomeState.kStatuses['Eating']!});
    await tester.pump();
    final merge =
        tester.widget<PlanEditor>(find.byType(PlanEditor)).onMergeRequested!;
    merge({'3', '12'});
    await tester.pump();
    expect(c.unitGroups.value, groups);
    expect(c.groupStatuses.value, {'G7': DemoHomeState.kStatuses['Eating']});
    expect(demo.log.first, 'Salon: Merged {3, 12} as G7');

    final log = [...demo.log];
    merge(const {});
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(c.unitGroups.value, groups);
    expect(demo.log, log, reason: 'nothing logged');
  });

  testWidgets(
      'D19 G6 under a dark platform: merge, a group status, split paint '
      'without an exception', (tester) async {
    final demo = await pumpGroups(tester, dark: true);
    final c = demo.area.controller;
    expect(Theme.of(tester.element(find.byType(DemoHome))).brightness,
        Brightness.dark);
    await selectByField(tester, '20, 5, 7');
    await press(tester, 'service-merge');
    expect(c.unitGroups.value.keys, ['G1']);
    expect(tester.takeException(), isNull, reason: 'merged');
    await press(tester, 'status-eating');
    expect(c.groupStatuses.value.keys, ['G1']);
    expect(tester.takeException(), isNull, reason: 'group status');
    await press(tester, 'service-split');
    expect(c.unitGroups.value, isEmpty);
    expect(c.groupStatuses.value, isEmpty);
    expect(tester.takeException(), isNull, reason: 'split');
  });
}
