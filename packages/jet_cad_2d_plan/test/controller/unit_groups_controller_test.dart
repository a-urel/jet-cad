// Ported from jet_cad_floor_plan's test/host/table_groups_controller_test
// .dart (2b Task 12, spec S3 "Service state"): table-groups spec G1, G2, G4
// (selecting by label) and G5 (the Split rule, through `selectedGroup`):
// the controller's groups. Units are placed off the origin, turned and
// mirrored, labelled out of handle order (`G7` holds 12, 3 and 7); one sits
// on a locked layer and one on a hidden layer; one is unlabelled; a variant
// carries a label twice (a hand-edited file). The new SS- tests add the
// rows' seats (Task 5's hall) and a unit locked by a missing kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/harness.dart' show controllerFor;
import '../support/service_fixture.dart' show seatsOf;
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit, unitKit;

void main() {
  testWidgets(
      'TG-C1 an overlap throws, trimmed numbers included, keeping the old '
      'groups and notifying no one (M-TG-1)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    c.select({'3'});
    final kept = c.unitGroups.value;
    expect(c.selectedGroup.value, 'G7');
    var heardGroups = 0, heardSelected = 0;
    c.unitGroups.addListener(() => heardGroups++);
    c.selectedGroup.addListener(() => heardSelected++);

    expect(
        () => c.setUnitGroups({
              'G4': UnitGroup(members: {'20', '5'}),
              'G5': UnitGroup(members: {' 5 ', '8'}),
            }),
        throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message',
            stringContainsInOrder(['"5"', '"G4"', '"G5"']))));
    expect(c.unitGroups.value, same(kept));
    expect(c.selectedGroup.value, 'G7');
    expect(heardGroups, 0);
    expect(heardSelected, 0);
    await tester.pump();
  });

  testWidgets(
      'TG-C2 a blank id, ids the same after trimming and a group with no '
      'member after trimming throw, keeping the old groups, notifying no '
      'one (G2)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    final kept = c.unitGroups.value;
    var heard = 0;
    c.unitGroups.addListener(() => heard++);
    for (final bad in <Map<String, UnitGroup>>[
      {
        '': UnitGroup(members: {'5'})
      },
      {
        '  ': UnitGroup(members: {'5'})
      },
      {
        'G1': UnitGroup(members: {'5'}),
        ' G1 ': UnitGroup(members: {'20'})
      },
      {
        'G1': UnitGroup(members: {' ', ''})
      },
    ]) {
      expect(() => c.setUnitGroups(bad), throwsArgumentError, reason: '$bad');
      expect(c.unitGroups.value, same(kept), reason: '$bad');
    }
    expect(heard, 0);
    await tester.pump();
  });

  testWidgets(
      'TG-C3 ids and numbers are trimmed: " G1 " and " 5 " are G1 and 5, '
      'for the groups and the group statuses (M-TG-2)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      ' G1 ': UnitGroup(members: {' 5 ', '20 '})
    });
    expect(c.unitGroups.value.keys, ['G1']);
    expect(c.unitGroups.value['G1']!.members, {'5', '20'});
    c.select({'5'});
    expect(c.selectedUnits.value, {'5', '20'});
    expect(c.selectedGroup.value, 'G1');
    c.setGroupStatus({' G1 ': bill});
    expect(c.groupStatuses.value.keys, ['G1']);
    expect(c.groupStatuses.value['G1'], bill);
    await tester.pump();
  });

  testWidgets(
      'TG-C4 a group status with no group is kept, and a groups change '
      'leaves the statuses alone; neither is plan state (G2)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    final json = c.save();
    final revision = c.revision.value;
    var heard = 0;
    c.groupStatuses.addListener(() => heard++);
    c.setGroupStatus({'G9': bill});
    expect(heard, 1);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    c.setUnitGroups(const {});
    expect(c.groupStatuses.value, {'G9': bill});
    expect(heard, 1);
    expect(c.unitStatuses.value, isEmpty,
        reason: 'the two status maps are apart');
    expect(c.revision.value, revision);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.save(), json);
    await tester.pump();
  });

  testWidgets(
      'TG-C5 in the selection mode a number selects its whole group; in '
      'the design mode it does not (M-TG-9)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    c.select({'3'});
    expect(c.selectedUnits.value, {'3'}, reason: 'the design mode');
    expect(c.activeSelection.keys, keysOf(c, {'3'}));

    c.setMode(PlanMode.service);
    expect(c.selectedUnits.value, {'3', '7', '12'},
        reason: 'the switch selects by number again');
    c.select(const {});
    c.select({'12', '20'});
    expect(c.selectedUnits.value, {'3', '7', '12', '20'});
    expect(c.activeSelection.keys, keysOf(c, {'3', '7', '12', '20'}));
    await tester.pump();
  });

  testWidgets(
      'TG-C6 the expansion selects every table of a member number, a file '
      'duplicate included (G2, M-TG-9)', (tester) async {
    final c =
        controllerFor(kits: [testKit()], json: groupsPlanText(duplicate: true));
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    c.select({'7'});
    expect(c.selectedUnits.value, {'3', '7', '12'});
    expect(c.activeSelection.keys, hasLength(4));
    expect(c.selectedGroup.value, 'G7');
    await tester.pump();
  });

  testWidgets(
      'TG-C7 the expansion never selects a member on a locked or a hidden '
      'layer (M-TG-9b)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7', '8', '9'})
    });
    c.select({'3'});
    expect(c.selectedUnits.value, {'3', '7', '12'});
    expect(c.activeSelection.keys, keysOf(c, {'3', '7', '12'}));
    c.select({'8'});
    expect(c.selectedUnits.value, {'3', '7', '12'},
        reason: 'a locked member stands for its group');
    expect(c.selectedGroup.value, 'G7',
        reason: 'the locked and the hidden member are never selected');
    await tester.pump();
  });

  testWidgets(
      'TG-C8 selectedGroup: exactly one group\'s selectable members, a '
      'locked third member and a single visible member included; not a '
      'group plus a table, part of one, or a group plus an unnumbered '
      'table (M-TG-17)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '8'}),
      'G9': UnitGroup(members: {'9', '5'}),
    });
    final selection = c.activeSelection;
    selection.replace(keysOf(c, {'3', '12'}));
    await tester.pump();
    expect(c.selectedGroup.value, 'G7', reason: 'its locked 8 is not needed');

    selection.replace(keysOf(c, {'3', '12', '20'}));
    await tester.pump();
    expect(c.selectedGroup.value, isNull, reason: 'a group plus a table');

    selection.replace(keysOf(c, {'12'}));
    await tester.pump();
    expect(c.selectedGroup.value, isNull, reason: 'part of a group');

    selection.replace({
      ...keysOf(c, {'3', '12'}),
      unlabelledKey(c)
    });
    await tester.pump();
    expect(c.selectedUnits.value, {'3', '12'});
    expect(c.selectedGroup.value, isNull,
        reason: 'a group plus an unnumbered table');

    selection.replace(keysOf(c, {'5'}));
    await tester.pump();
    expect(c.selectedGroup.value, 'G9', reason: 'its 9 is hidden');

    selection.replace(keysOf(c, {'20'}));
    await tester.pump();
    expect(c.selectedGroup.value, isNull, reason: 'in no group');
  });

  testWidgets(
      'TG-C9 selectedGroup follows the groups with the selection unchanged, '
      'and is null in the design mode (M-TG-17b, M-C1-15)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.select({'3', '20'});
    expect(c.selectedGroup.value, isNull);
    final heard = <String?>[];
    c.selectedGroup.addListener(() => heard.add(c.selectedGroup.value));
    c.setUnitGroups({
      'G2': UnitGroup(members: {'20', '3'})
    });
    expect(c.selectedUnits.value, {'3', '20'});
    expect(c.selectedGroup.value, 'G2');
    c.setUnitGroups({
      'G2': UnitGroup(members: {'20', '3', '7'})
    });
    expect(c.selectedGroup.value, isNull, reason: 'now part of G2');
    c.setUnitGroups({
      'G2': UnitGroup(members: {'20', '3'})
    });
    c.setMode(PlanMode.design);
    expect(c.selectedUnits.value, {'3', '20'});
    expect(c.selectedGroup.value, isNull, reason: 'groups do not act here');
    expect(heard, ['G2', null, 'G2', null]);
    await tester.pump();
  });

  testWidgets(
      'TG-C12 selectedGroup reads the active plan as it is: after a load of '
      'another plan, and after a layer edit that made no command (M-C1-16, '
      'M-C1-17)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G9': UnitGroup(members: {'9', '5'})
    });
    c.select({'5'});
    expect(c.selectedUnits.value, {'5'});
    expect(c.selectedGroup.value, 'G9', reason: 'its 9 is hidden');

    c.load(groupsPlanText(hideNine: false));
    c.select({'5'});
    expect(c.selectedUnits.value, {'5', '9'});
    expect(c.selectedGroup.value, 'G9', reason: 'its 9 is visible now');

    c.load(groupsPlanText());
    c.select({'5'});
    expect(c.selectedGroup.value, 'G9');
    // Layer `Hidden` shown through its table section: no command, no state
    // change, only the tables' revision.
    final layers = c.activeDocument.tables.layers;
    final hidden = c.activeDocument.tables.layers.byName('Hidden')!;
    layers
      ..remove(hidden.handle)
      ..add(hidden.copyWith(visible: true));
    c.select({'5'});
    expect(c.selectedUnits.value, {'5', '9'});
    expect(c.selectedGroup.value, 'G9');
    await tester.pump();
  });

  // Table-groups fixes spec X1: `selectableMembers`, the host's view of the
  // rule Merge and Split use.

  testWidgets(
      'TG-C13 selectableMembers gives the visible, unlocked members\' '
      'numbers, in both modes; a group of only a locked and a hidden member '
      'gives none; the set is unmodifiable (M-TGF-1)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '8', '9'}),
      'G2': UnitGroup(members: {'20', '5'}),
    });
    expect(c.selectableMembers('G7'), {'12', '3'}, reason: 'the design mode');
    c.setMode(PlanMode.service);
    expect(c.selectableMembers('G7'), {'12', '3'},
        reason: '8 is locked, 9 hidden');
    expect(c.selectableMembers('G2'), {'20', '5'});
    expect(() => c.selectableMembers('G2').add('7'), throwsUnsupportedError);
    c.setUnitGroups({
      'G9': UnitGroup(members: {'8', '9'})
    });
    expect(c.selectableMembers('G9'), isEmpty);
    await tester.pump();
  });

  testWidgets(
      'TG-C14 selectableMembers trims the id; an unknown id gives the empty '
      'set (M-TGF-2)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '8', '9'})
    });
    expect(c.selectableMembers(' G7 '), {'12', '3'});
    expect(c.selectableMembers('G8'), isEmpty);
    expect(c.selectableMembers('12'), isEmpty, reason: 'a number is no id');
    await tester.pump();
  });

  testWidgets(
      'TG-C15 a number carried by an unlocked and a locked table is '
      'selectable, whichever comes first in handle order (M-TGF-3)',
      (tester) async {
    for (final lockFive in [false, true]) {
      final c = controllerFor(
          kits: [testKit()],
          json: groupsPlanText(eightTwice: true, lockFive: lockFive));
      c.setMode(PlanMode.service);
      c.setUnitGroups({
        'G7': UnitGroup(members: {'12', '3', '8'})
      });
      final eights = unitNodes(c.activeDocument, '8');
      expect(eights, hasLength(2), reason: 'premise: 8 twice');
      expect(c.selectableMembers('G7'), {'12', '3', '8'},
          reason: 'lockFive: $lockFive');
    }
    await tester.pump();
  });

  testWidgets(
      'TG-C16 selectableMembers is fresh after setUnitGroups with the same '
      'id, after a design layer was locked and the mode switched, and after '
      'a layer edit that made no command (M-TGF-10)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: groupsPlanText());
    c.setUnitGroups({
      'G7': UnitGroup(members: {'12', '3', '7'})
    });
    expect(c.selectableMembers('G7'), {'12', '3', '7'});
    c.setUnitGroups({
      'G7': UnitGroup(members: {'20', '12', '5', '8'})
    });
    expect(c.selectableMembers('G7'), {'20', '12', '5'},
        reason: 'the same id, new members');

    // Layer 0, which carries 20, 12 and 5, locked in the design through its
    // table section: no command.
    void setZeroLocked(bool locked) {
      final layers = c.activeDocument.tables.layers;
      final zero = layers[ReservedHandles.layerZero]!;
      layers
        ..remove(zero.handle)
        ..add(zero.copyWith(locked: locked));
    }

    setZeroLocked(true);
    c.setMode(PlanMode.service);
    expect(c.selectableMembers('G7'), isEmpty,
        reason: 'the service copy carries the locked layer');

    setZeroLocked(false);
    expect(c.selectableMembers('G7'), {'20', '12', '5'},
        reason: 'only the layers\' revision moved');
    await tester.pump();
  });

  testWidgets(
      'SS-mixed-group a group may mix a table and seats: in service a seat\'s '
      'label selects the whole group, seats included; the Split and Merge '
      'rules count the seats; a group holding a seat is never dragged',
      (tester) async {
    final h = hall();
    final c = controllerFor(kits: [unitKit()], json: h.json);
    final d = c.document;
    final table = labelOf(d, h.table)!;
    final a1 = labelOf(d, h.seats[0][0])!;
    final a2 = labelOf(d, h.seats[0][1])!;
    final b1 = labelOf(d, h.seats[1][0])!;
    c.setUnitGroups({
      'party': UnitGroup(members: {table, a1, a2}, label: 'Smith')
    });
    c.setMode(PlanMode.service);
    c.select({a2});
    // M-SS7: `groupUnitsOf` leaves the generated units out.
    expect(c.activeSelection.keys, {
      SelectionKey.root(h.table),
      SelectionKey.root(h.seats[0][0]),
      SelectionKey.root(h.seats[0][1]),
    });
    expect(c.selectedUnits.value, {table, a1, a2});
    expect(c.selectedGroup.value, 'party');
    expect(c.selectableMembers('party'), {table, a1, a2});
    // M-SS8: `hasGeneratedVisibleMember` answers false.
    expect(c.groupLookup.hasGeneratedVisibleMember('party'), isTrue);
    expect(c.groupLookup.hasLockedVisibleMember('party'), isFalse);
    c.select({a2, b1});
    expect(c.selectedGroup.value, isNull, reason: 'a group plus a seat');
    expect(c.mergeCandidate.value, {table, a1, a2, b1});
    await tester.pump();
  });

  testWidgets(
      'SS-shrink-group (Review Focus 1) a row shrunk from 12 seats to 10 '
      'while seats 11 and 12 are grouped and given a status: the group keeps '
      'their labels as members naming no unit, its selectable members drop '
      'them, the status is kept; undo brings them back into the group',
      (tester) async {
    final h = hall();
    final c = controllerFor(kits: [unitKit()], json: h.json);
    final row = h.rows[0];
    setRowCount(c, row, 12);
    final seats = seatsOf(c.document, row);
    expect(seats, hasLength(12), reason: 'premise');
    final table = labelOf(c.document, h.table)!;
    final two = labelOf(c.document, seats[1])!;
    final eleven = labelOf(c.document, seats[10])!;
    final twelve = labelOf(c.document, seats[11])!;
    c.setUnitGroups({
      'g': UnitGroup(members: {table, two, eleven, twelve})
    });
    c.setUnitStatus({eleven: bill});
    c.setGroupStatus({'g': bill});
    expect(c.selectableMembers('g'), {table, two, eleven, twelve});

    setRowCount(c, row, 10);
    expect(seatsOf(c.document, row), seats.sublist(0, 10),
        reason: 'premise: E5 keeps seats 1-10 under their handles');
    expect(c.unitGroups.value['g']!.members, {table, two, eleven, twelve},
        reason: 'a member naming no unit is kept (today\'s setTableGroups)');
    // M-SS2: the lookup's cache ignores the unit index.
    expect(c.selectableMembers('g'), {table, two});
    expect(c.unitStatuses.value.keys, [eleven]);
    expect(c.groupStatuses.value.keys, ['g']);

    c.setMode(PlanMode.service);
    c.select({two});
    expect(c.selectedUnits.value, {table, two});
    expect(c.selectedGroup.value, 'g',
        reason: 'exactly the selectable members, 11 and 12 gone');
    c.setMode(PlanMode.design);
    c.undo();
    expect(seatsOf(c.document, row), seats);
    expect(c.selectableMembers('g'), {table, two, eleven, twelve});
    c.setMode(PlanMode.service);
    c.select({eleven});
    expect(c.selectedUnits.value, {table, two, eleven, twelve});
    expect(c.selectedGroup.value, 'g');
    await tester.pump();
  });

  testWidgets(
      'SS-locked-not-selected a table of a missing kit is a locked unit: '
      'grouped, its group\'s status its own, never selected by select; its '
      'label stands for its group\'s selectable members', (tester) async {
    final c = controllerFor(kits: [testKit()], json: lockedPlanText());
    final gone = unitNode(c.document, '5').handle;
    expect(c.unitIndex[gone]!.locked, isTrue, reason: 'premise: isLockedUnit');
    expect(c.document.tables.layers[unitNode(c.document, '5').layer]!.locked,
        isFalse,
        reason: 'premise: its layer is not locked');
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '5'})
    });
    c.setMode(PlanMode.service);
    c.select({'5'});
    // M-SS5: `groupUnitsOf` reads no lock.
    expect(c.activeSelection.keys, keysOf(c, {'1'}));
    expect(c.selectedUnits.value, {'1'});
    expect(c.selectableMembers('g'), {'1'});
    expect(c.groupLookup.hasLockedVisibleMember('g'), isTrue);
    expect(c.selectedGroup.value, 'g');
    c.setGroupStatus({'g': bill});
    expect(c.statusOf(c.unitIndex[gone]!), bill,
        reason: 'its group\'s status paints on it');
    c.setUnitGroups(const {});
    // M-SS6: `_select` skips no locked unit.
    c.select({'5'});
    expect(c.activeSelection.keys, isEmpty);
    expect(c.selectedUnits.value, isEmpty);
    await tester.pump();
  });

  testWidgets(
      'SS-relabel a relabelled unit leaves its group, its status and the '
      'focus behind, keyed by its old label (spec S2 "A changed label")',
      (tester) async {
    final h = hall();
    final c = controllerFor(kits: [unitKit()], json: h.json);
    final d = c.document;
    final table = labelOf(d, h.table)!;
    final a1 = labelOf(d, h.seats[0][0])!;
    c.setUnitGroups({
      'g': UnitGroup(members: {table, a1})
    });
    c.setUnitStatus({table: bill});
    c.setUnitFocus({table});
    expect(c.selectableMembers('g'), {table, a1}, reason: 'premise');

    expect(c.setUnitLabel(table, '99'), isTrue);
    expect(labelOf(d, h.table), '99', reason: 'premise: relabelled');
    expect(c.unitGroups.value['g']!.members, {table, a1});
    // M-SS2: the lookup's cache ignores the unit index.
    expect(c.selectableMembers('g'), {a1});
    expect(c.unitStatuses.value.keys, [table]);
    expect(c.statusOf(c.unitIndex[h.table]!), isNull);
    expect(c.unitFocus.value, {table});
    await tester.pump();
  });
}
