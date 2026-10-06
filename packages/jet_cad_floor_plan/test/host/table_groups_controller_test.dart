// Table-groups spec G1, G2, G4 (selecting by number) and G5 (the Split
// rule, through `selectedGroup`): the controller's groups. Tables are placed
// off the origin, turned and mirrored, numbered out of handle order (`G7`
// holds 12, 3 and 7); one sits on a locked layer and one on a hidden layer;
// one is unnumbered; a variant carries a number twice (a hand-edited file).
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// The numbers given to the tables in handle order: not sorted.
const List<String> kNumbers = ['12', '3', '7', '20', '5', '8', '9'];

/// A plan: tables numbered [kNumbers] in handle order, each placed off the
/// origin, turned or mirrored; table 8 on a visible locked layer, table 9
/// on a hidden one; an unnumbered table last. [duplicate] renames table 5
/// to "3"; [hideNine] false leaves table 9 on layer 0. [eightTwice] renames
/// table 5 to "8", so 8 is carried by table 5's unlocked table and the
/// locked one; [lockFive] then puts table 5's table on the locked layer
/// instead, so the locked carrier of 8 comes first in handle order.
String groupsPlanJson(
    {bool duplicate = false,
    bool hideNine = true,
    bool eightTwice = false,
    bool lockFive = false}) {
  final doc = plan();
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle layer(String name, {required bool visible, required bool locked}) {
    final h = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: h,
        name: name,
        color: const IndexedColor(5),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: visible,
        locked: locked)));
    return h;
  }

  final locked = layer('Locked', visible: true, locked: true);
  final hidden = layer('Hidden', visible: false, locked: false);
  final table = entryOf(tableSymbol());
  final placements = [
    placementAt(-2600, 1400, kDeg37, mirrored: true),
    placementAt(2300, 1700, kDeg37 * 2),
    placementAt(5100, -900, -kDeg37, mirrored: true),
    placementAt(-4300, -2600, 0, mirrored: true),
    placementAt(800, -3300, kDeg37),
    placementAt(7400, 2200, kDeg37 * 3),
    placementAt(-7100, 3900, -kDeg37 * 2, mirrored: true),
  ];
  for (final p in placements) {
    doc.commands
        .execute(placeSymbol(doc, table, at: Vector2.zero(), transform: p));
  }
  doc.commands.execute(placeSymbol(doc, table,
      at: Vector2(3600, 5200), quarterTurns: 3, numbered: false));
  final tables = tablesOf(doc);
  for (var i = 0; i < kNumbers.length; i++) {
    final n = switch (kNumbers[i]) {
      '5' when duplicate => '3',
      '5' when eightTwice => '8',
      final n => n,
    };
    doc.commands
        .execute(SetEntityTextCommand(tables[i].label!, n, kTableLabelTag));
  }
  doc.commands.execute(
      SetInstanceLayerCommand(tables[lockFive ? 4 : 5].instance, locked));
  if (hideNine) {
    doc.commands.execute(SetInstanceLayerCommand(tables[6].instance, hidden));
  }
  return DraftDocumentCodec.encodeToString(doc);
}

FloorPlanController controller(String json) {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  return c;
}

TableGroup group(Set<String> members, [String? label]) =>
    TableGroup(members: members, label: label);

/// The selection keys of the tables numbered [numbers] in the active plan.
Set<SelectionKey> keysOf(FloorPlanController c, Set<String> numbers) => {
      for (final n in numbers)
        for (final t in TableSurvey.of(c.activeDocument).withNumber(n))
          SelectionKey.root(t.instance)
    };

SelectionKey unnumberedKey(FloorPlanController c) =>
    SelectionKey.root(TableSurvey.of(c.activeDocument)
        .tables
        .firstWhere((t) => t.number == null)
        .instance);

final TableStatus bill =
    TableStatus(color: const Color(0x80E53935), caption: 'Bill');

void main() {
  testWidgets(
      'TG-C1 an overlap throws, trimmed numbers included, keeping the old '
      'groups and notifying no one (M-TG-1)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    c.select({'3'});
    final kept = c.tableGroups.value;
    expect(c.selectedGroup.value, 'G7');
    var heardGroups = 0, heardSelected = 0;
    c.tableGroups.addListener(() => heardGroups++);
    c.selectedGroup.addListener(() => heardSelected++);

    expect(
        () => c.setTableGroups({
              'G4': group({'20', '5'}),
              'G5': group({' 5 ', '8'}),
            }),
        throwsA(isA<ArgumentError>().having((e) => e.toString(), 'message',
            stringContainsInOrder(['"5"', '"G4"', '"G5"']))));
    expect(c.tableGroups.value, same(kept));
    expect(c.selectedGroup.value, 'G7');
    expect(heardGroups, 0);
    expect(heardSelected, 0);
    await tester.pump();
  });

  testWidgets(
      'TG-C2 a blank id, ids the same after trimming and a group with no '
      'member after trimming throw, keeping the old groups, notifying no '
      'one (G2)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    final kept = c.tableGroups.value;
    var heard = 0;
    c.tableGroups.addListener(() => heard++);
    for (final bad in <Map<String, TableGroup>>[
      {
        '': group({'5'})
      },
      {
        '  ': group({'5'})
      },
      {
        'G1': group({'5'}),
        ' G1 ': group({'20'})
      },
      {
        'G1': group({' ', ''})
      },
    ]) {
      expect(() => c.setTableGroups(bad), throwsArgumentError, reason: '$bad');
      expect(c.tableGroups.value, same(kept), reason: '$bad');
    }
    expect(heard, 0);
    await tester.pump();
  });

  testWidgets(
      'TG-C3 ids and numbers are trimmed: " G1 " and " 5 " are G1 and 5, '
      'for the groups and the group statuses (M-TG-2)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      ' G1 ': group({' 5 ', '20 '})
    });
    expect(c.tableGroups.value.keys, ['G1']);
    expect(c.tableGroups.value['G1']!.members, {'5', '20'});
    c.select({'5'});
    expect(c.selectedTables.value, {'5', '20'});
    expect(c.selectedGroup.value, 'G1');
    c.setGroupStatus({' G1 ': bill});
    expect(c.groupStatuses.value.keys, ['G1']);
    expect(c.groupStatuses.value['G1'], bill);
    await tester.pump();
  });

  testWidgets(
      'TG-C4 a group status with no group is kept, and a groups change '
      'leaves the statuses alone; neither is plan state (G2)', (tester) async {
    final c = controller(groupsPlanJson());
    final json = c.designJson();
    final revision = c.revision.value;
    var heard = 0;
    c.groupStatuses.addListener(() => heard++);
    c.setGroupStatus({'G9': bill});
    expect(heard, 1);
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    c.setTableGroups(const {});
    expect(c.groupStatuses.value, {'G9': bill});
    expect(heard, 1);
    expect(c.tableStatuses.value, isEmpty,
        reason: 'the two status maps are apart');
    expect(c.revision.value, revision);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.designJson(), json);
    await tester.pump();
  });

  testWidgets(
      'TG-C5 in the selection mode a number selects its whole group; in '
      'the design mode it does not (M-TG-9)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    c.select({'3'});
    expect(c.selectedTables.value, {'3'}, reason: 'the design mode');
    expect(c.activeSelection.keys, keysOf(c, {'3'}));

    c.setMode(FloorPlanMode.selection);
    expect(c.selectedTables.value, {'3', '7', '12'},
        reason: 'the switch selects by number again');
    c.select(const {});
    c.select({'12', '20'});
    expect(c.selectedTables.value, {'3', '7', '12', '20'});
    expect(c.activeSelection.keys, keysOf(c, {'3', '7', '12', '20'}));
    await tester.pump();
  });

  testWidgets(
      'TG-C6 the expansion selects every table of a member number, a file '
      'duplicate included (G2, M-TG-9)', (tester) async {
    final c = controller(groupsPlanJson(duplicate: true));
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    c.select({'7'});
    expect(c.selectedTables.value, {'3', '7', '12'});
    expect(c.activeSelection.keys, hasLength(4));
    expect(c.selectedGroup.value, 'G7');
    await tester.pump();
  });

  testWidgets(
      'TG-C7 the expansion never selects a member on a locked or a hidden '
      'layer (M-TG-9b)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G7': group({'12', '3', '7', '8', '9'})
    });
    c.select({'3'});
    expect(c.selectedTables.value, {'3', '7', '12'});
    expect(c.activeSelection.keys, keysOf(c, {'3', '7', '12'}));
    c.select({'8'});
    expect(c.selectedTables.value, {'3', '7', '12'},
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
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G7': group({'12', '3', '8'}),
      'G9': group({'9', '5'}),
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
      unnumberedKey(c)
    });
    await tester.pump();
    expect(c.selectedTables.value, {'3', '12'});
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
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.select({'3', '20'});
    expect(c.selectedGroup.value, isNull);
    final heard = <String?>[];
    c.selectedGroup.addListener(() => heard.add(c.selectedGroup.value));
    c.setTableGroups({
      'G2': group({'20', '3'})
    });
    expect(c.selectedTables.value, {'3', '20'});
    expect(c.selectedGroup.value, 'G2');
    c.setTableGroups({
      'G2': group({'20', '3', '7'})
    });
    expect(c.selectedGroup.value, isNull, reason: 'now part of G2');
    c.setTableGroups({
      'G2': group({'20', '3'})
    });
    c.setMode(FloorPlanMode.design);
    expect(c.selectedTables.value, {'3', '20'});
    expect(c.selectedGroup.value, isNull, reason: 'groups do not act here');
    expect(heard, ['G2', null, 'G2', null]);
    await tester.pump();
  });

  testWidgets(
      'TG-C10 groups never reach the document: designJson and the service '
      'copy are byte-identical with and without them (M-TG-19, invariant)',
      (tester) async {
    final c = controller(groupsPlanJson());
    final design = c.designJson();
    c.setMode(FloorPlanMode.selection);
    final copy = DraftDocumentCodec.encodeToString(c.activeDocument);
    c.setTableGroups({
      'G7': group({'12', '3', '7'}, 'Window bay')
    });
    c.setGroupStatus({'G7': bill});
    c.select({'3'});
    expect(DraftDocumentCodec.encodeToString(c.activeDocument), copy);
    expect(c.designJson(), design);
    expect(c.serviceEdited, isFalse);
    await tester.pump();
  });

  testWidgets(
      'TG-C11 groups and group statuses survive a mode round trip, '
      'resetLayout and a load of the same plan, and still act (M-TG-20)',
      (tester) async {
    final json = groupsPlanJson();
    final c = controller(json);
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    c.setGroupStatus({'G7': bill});
    final groups = c.tableGroups.value;
    final statuses = c.groupStatuses.value;
    void expectKept(String reason) {
      expect(c.tableGroups.value, same(groups), reason: reason);
      expect(c.groupStatuses.value, same(statuses), reason: reason);
    }

    c.setMode(FloorPlanMode.selection);
    c.setMode(FloorPlanMode.design);
    c.setMode(FloorPlanMode.selection);
    expectKept('a mode round trip');
    c.select({'7'});
    expect(c.selectedTables.value, {'3', '7', '12'});
    expect(c.selectedGroup.value, 'G7');

    c.resetLayout();
    expectKept('resetLayout');
    expect(c.selectedTables.value, {'3', '7', '12'});
    expect(c.selectedGroup.value, 'G7');

    c.load(json);
    expectKept('load');
    expect(c.selectedGroup.value, isNull,
        reason: 'a load clears the selection');
    c.select({'12'});
    expect(c.selectedTables.value, {'3', '7', '12'});
    expect(c.selectedGroup.value, 'G7');
    await tester.pump();
  });

  testWidgets(
      'TG-C12 selectedGroup reads the active plan as it is: after a load of '
      'another plan, and after a layer edit that made no command (M-C1-16, '
      'M-C1-17)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G9': group({'9', '5'})
    });
    c.select({'5'});
    expect(c.selectedTables.value, {'5'});
    expect(c.selectedGroup.value, 'G9', reason: 'its 9 is hidden');

    c.load(groupsPlanJson(hideNine: false));
    c.select({'5'});
    expect(c.selectedTables.value, {'5', '9'});
    expect(c.selectedGroup.value, 'G9', reason: 'its 9 is visible now');

    c.load(groupsPlanJson());
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
    expect(c.selectedTables.value, {'5', '9'});
    expect(c.selectedGroup.value, 'G9');
    await tester.pump();
  });

  // Table-groups fixes spec X1: `selectableMembers`, the host's view of the
  // rule Merge and Split use.

  testWidgets(
      'TG-C13 selectableMembers gives the visible, unlocked members\' '
      'numbers, in both modes; a group of only a locked and a hidden member '
      'gives none; the set is unmodifiable (M-TGF-1)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setTableGroups({
      'G7': group({'12', '3', '8', '9'}),
      'G2': group({'20', '5'}),
    });
    expect(c.selectableMembers('G7'), {'12', '3'}, reason: 'the design mode');
    c.setMode(FloorPlanMode.selection);
    expect(c.selectableMembers('G7'), {'12', '3'},
        reason: '8 is locked, 9 hidden');
    expect(c.selectableMembers('G2'), {'20', '5'});
    expect(() => c.selectableMembers('G2').add('7'), throwsUnsupportedError);
    c.setTableGroups({
      'G9': group({'8', '9'})
    });
    expect(c.selectableMembers('G9'), isEmpty);
    await tester.pump();
  });

  testWidgets(
      'TG-C14 selectableMembers trims the id; an unknown id gives the empty '
      'set (M-TGF-2)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setMode(FloorPlanMode.selection);
    c.setTableGroups({
      'G7': group({'12', '3', '8', '9'})
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
      final c =
          controller(groupsPlanJson(eightTwice: true, lockFive: lockFive));
      c.setMode(FloorPlanMode.selection);
      c.setTableGroups({
        'G7': group({'12', '3', '8'})
      });
      final eights = TableSurvey.of(c.activeDocument).withNumber('8');
      expect(eights, hasLength(2), reason: 'premise: 8 twice');
      expect(c.selectableMembers('G7'), {'12', '3', '8'},
          reason: 'lockFive: $lockFive');
    }
    await tester.pump();
  });

  testWidgets(
      'TG-C16 selectableMembers is fresh after setTableGroups with the same '
      'id, after a design layer was locked and the mode switched, and after '
      'a layer edit that made no command (M-TGF-10)', (tester) async {
    final c = controller(groupsPlanJson());
    c.setTableGroups({
      'G7': group({'12', '3', '7'})
    });
    expect(c.selectableMembers('G7'), {'12', '3', '7'});
    c.setTableGroups({
      'G7': group({'20', '12', '5', '8'})
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
    c.setMode(FloorPlanMode.selection);
    expect(c.selectableMembers('G7'), isEmpty,
        reason: 'the service copy carries the locked layer');

    setZeroLocked(false);
    expect(c.selectableMembers('G7'), {'20', '12', '5'},
        reason: 'only the layers\' revision moved');
    await tester.pump();
  });
}
