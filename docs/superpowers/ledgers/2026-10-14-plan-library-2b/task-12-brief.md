### Task 12: Service state: statuses, groups, focus and the group rules (spec S3 "Service state", "The unit API" `select`; S2 "Locked units", "Unlabelled, duplicate and bad labels"; S5 controller rows 9-15)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/service/service_state.dart` (`UnitStatus`, `UnitGroup`, `validateUnitGroups`, `GroupUnit`, `UnitGroupLookup`, the Merge and Split rules, the lead order, `statusOfUnit`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the service state's members; group expansion in `_select`; `selectedGroup` and `mergeCandidate` refreshed with the selection)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `UnitStatus`, `UnitGroup`), `packages/jet_cad_2d_plan/test/barrel_test.dart` (ED-9)
- Modify (test support): `packages/jet_cad_2d_plan/test/support/service_plans.dart` (`groupsPlanText`, `keysOf`, `unlabelledKey`, `setRowCount`, `bill`; `servicePlanText(unlabelled:)`)
- Test: `packages/jet_cad_2d_plan/test/service/service_state_test.dart` (ported TG-U1…TG-U15), `packages/jet_cad_2d_plan/test/controller/unit_groups_controller_test.dart` (ported TG-C1…TG-C9, TG-C12…TG-C16; new SS-mixed-group, SS-shrink-group, SS-locked-not-selected, SS-relabel), `packages/jet_cad_2d_plan/test/controller/service_state_controller_test.dart` (ported C15, CF1, CF2, CF5; new SS-dup-label-status)

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Task 11: `PlanMode`, `setMode`, `activeSelection`, `serviceSession`; the private `_service`, `_onServiceChanged()`; Task 9's seams as Task 11 re-points them: `_select(Set<String>)` (whose loop reads `_expandLabels`, the seam this task fills), `_refreshSelected()` (which this task ends with `_refreshSelectedGroup()`), `_activeUnits` (a `UnitIndexCache`).
  - Task 9: `_selectedUnits` (`ValueNotifier<Set<String>>`), `_expandLabels` (the seam), `@internal unitIndex`, `revision`, `save`-time behaviour unchanged. Task 11: `selectedUnits`.
  - Task 6: `UnitIndex.units`, `withLabel`, `UnitInfo.instance`, `text`, `visible`, `locked` (`isLockedUnit`: the layer or the lock set), `generated`.
  - Task 5 (through Task 11's `hall()`): the rows; the row component (`RowComponent`, its `count`, `copyWith(count:)`).
- Produces (Shared interfaces, Task 12):
  - `final class UnitStatus { UnitStatus({required Color color, String? caption}); static const int maxCaption = 12; final Color color; final String? caption; }` (exported).
  - `final class UnitGroup { UnitGroup({required Set<String> members, String? label}); static const int maxLabel = 24; final Set<String> members; final String? label; }` (exported).
  - `Map<String, UnitGroup> validateUnitGroups(Map<String, UnitGroup> groups)` (internal, as today's `validateTableGroups`; `ArgumentError` as today).
  - On `PlanController`: `ValueListenable<Map<String, UnitStatus>> get unitStatuses`, `void setUnitStatus(Map<String, UnitStatus>)`; `ValueListenable<Map<String, UnitGroup>> get unitGroups`, `void setUnitGroups(Map<String, UnitGroup>)`; `ValueListenable<Map<String, UnitStatus>> get groupStatuses`, `void setGroupStatus(Map<String, UnitStatus>)`; `ValueListenable<Set<String>?> get unitFocus`, `void setUnitFocus(Set<String>?)`; `ValueListenable<String?> get selectedGroup`; `ValueListenable<Set<String>?> get mergeCandidate`; `Set<String> selectableMembers(String groupId)`. (`selectedUnits` is Task 11's; the Shared interfaces list it here.)
  - Internal, for Tasks 13-16: `GroupUnit({handle, label, visible, locked, generated})` (`selectable`); `UnitGroupLookup(groups, units)` with `byLabel`, `groupOf`, `visibleMembers`, `selectableMembers`, `hasLockedVisibleMember`, `hasGeneratedVisibleMember` (Task 14: such a group is never dragged, spec S4 "A drag"), `splitGroup(selectedLabels, {required bool unlabelledSelected})`; `groupIdsByLabel`, `groupUnitsOf(UnitIndex)`, `mergeQualifies`, `unitLabelOrder`, `inLeadOrder` (Task 15's chips and captions); `statusOfUnit(label, {statuses, groupStatuses, groupByLabel})` (the group's status over the unit's, spec S4 "Painting", today's `TableStatusPainter` order); on `PlanController`, `@internal UnitGroupLookup get groupLookup` and `@internal UnitStatus? statusOf(UnitInfo unit)` (Tasks 15 and 16: the painters and `PlanUnitOverlay.status`).

Plan decisions:
- **A unit's lock in the group rules is `UnitInfo.locked`** (`isLockedUnit`, spec S2): a placed unit of a missing kit's symbol and a seat of a frozen row count as locked members (visible, never selectable, the group never dragged), where today's `GroupTable.locked` read the layer alone (`jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart:1906-1914`).
- **A seat is a member like a table** (spec S3: "a group may mix kinds"); `GroupUnit.generated` is carried so that Task 14 can refuse to drag a group holding one (`hasGeneratedVisibleMember`).
- **The lookup is rebuilt when the active unit index or the groups change** (identity of `UnitIndexCache.current`, which moves with the state id, the layers' revision and `locked`, Task 6; identity of the groups map): today's three keys (`floor_plan_controller.dart:1896-1920`) in one.
- **A status resolves by label** (`statusOfUnit`): the status of the label's group when that group has one, else the label's own; an unlabelled unit has none. So two units sharing a label both take it (spec S2), and a locked member takes its group's (spec S2 "its group's status paints on it").
- `serviceChanges` on `setUnitGroups` in service is Task 13's (it owns `serviceChanges`).

- [ ] **Step 1: The test support.** In `test/support/service_plans.dart`:
  1. `servicePlanText` gains `bool unlabelled = false`: when true, a fourth table, unlabelled, at `placementTransform(at: Vector2(-4000, -3000), basePoint: table.base)` (today's C13 placement, `controller_test.dart:324-325`), placed after the planter.
  2. Add (today's `table_groups_controller_test.dart:20-110`, ported):

```dart
/// The labels given to the tables in handle order: not sorted.
const List<String> kGroupLabels = ['12', '3', '7', '20', '5', '8', '9'];

/// Today's `groupsPlanJson` (table_groups_controller_test.dart:23-85),
/// saved: tables labelled [kGroupLabels] in handle order, each off the
/// origin, turned or mirrored; table 8 on a visible locked layer, table 9
/// on a hidden one; an unlabelled table last. [duplicate] labels table 5
/// "3"; [hideNine] false leaves table 9 on layer 0. [eightTwice] labels
/// table 5 "8", so 8 is carried by table 5's unlocked table and the locked
/// one; [lockFive] then puts table 5's table on the locked layer instead,
/// so the locked carrier of 8 comes first in handle order.
String groupsPlanText(
        {bool duplicate = false,
        bool hideNine = true,
        bool eightTwice = false,
        bool lockFive = false}) =>
    planText([testKit()], (d) {
      final locked = addLayer(d, 'Locked', visible: true, locked: true);
      final hidden = addLayer(d, 'Hidden', visible: false, locked: false);
      final table = unitDefinition(d, key: 'test.table.square.four');
      final placements = [
        turned(table, -2600, 1400, kDeg37, mirrored: true),
        turned(table, 2300, 1700, kDeg37 * 2),
        turned(table, 5100, -900, -kDeg37, mirrored: true),
        turned(table, -4300, -2600, 0, mirrored: true),
        turned(table, 800, -3300, kDeg37),
        turned(table, 7400, 2200, kDeg37 * 3),
        turned(table, -7100, 3900, -kDeg37 * 2, mirrored: true),
      ];
      final units = <Handle>[];
      for (var i = 0; i < placements.length; i++) {
        final label = switch (kGroupLabels[i]) {
          '5' when duplicate => '3',
          '5' when eightTwice => '8',
          final l => l,
        };
        units.add(placeDef(d, table, placements[i], label: label));
      }
      placeDef(d, table,
          placementTransform(
              at: Vector2(3600, 5200), basePoint: table.base, quarterTurns: 3));
      d.commands.execute(
          SetInstanceLayerCommand(units[lockFive ? 4 : 5], locked));
      if (hideNine) {
        d.commands.execute(SetInstanceLayerCommand(units[6], hidden));
      }
    });

/// The selection keys of the units labelled [labels] in the active
/// document (today's `keysOf`).
Set<SelectionKey> keysOf(PlanController c, Set<String> labels) => {
      for (final l in labels)
        for (final n in unitNodes(c.activeDocument, l))
          SelectionKey.root(n.handle),
    };

/// The key of the unlabelled unit of the active document.
SelectionKey unlabelledKey(PlanController c) => SelectionKey.root(
    c.unitIndex.units.firstWhere((u) => u.text == null).instance);

/// One design edit: [row]'s seat count set to [count] (Task 5's row).
void setRowCount(PlanController c, Handle row, int count) {
  final r = c.document.components.get<RowComponent>(row)!;
  if (!c.execute(
      SetComponentCommand<RowComponent>(row, r.copyWith(count: count)))) {
    throw StateError('the row edit was refused');
  }
}

/// Today's `bill` (table_groups_controller_test.dart:109-110).
final UnitStatus bill =
    UnitStatus(color: const Color(0x80E53935), caption: 'Bill');
```

     The file's imports gain `import 'dart:ui' show Color;` and `import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;`.

- [ ] **Step 2: Port the group rules' tests.** Create `test/service/service_state_test.dart` from `jet_cad_floor_plan/test/service/table_groups_test.dart` (the whole file): TG-U1, TG-U2, TG-U3 (`TableGroup`), TG-U4, TG-U5, TG-U6 (validation), TG-U7, TG-U8, TG-U9 (the lookup), TG-U10, TG-U11 (Merge), TG-U12, TG-U13 (Split), TG-U14, TG-U15 (the lead order): 15 tests, **assertions unchanged**. Adaptations (names and imports only): imports `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` (`UnitGroup`) and `package:jet_cad_2d_plan/src/service/service_state.dart`; `TableGroup` → `UnitGroup`; `GroupTable` → `GroupUnit` and its `number:` → `label:` (the helper `t(...)` becomes `u(int handle, String? label, {bool visible = true, bool locked = false})`, `generated: false`); `validateTableGroups` → `validateUnitGroups`; `TableGroupLookup` → `UnitGroupLookup`; `tableNumberOrder` → `unitLabelOrder`; `splitGroup(…, unnumberedSelected:)` → `unlabelledSelected:`; "number"/"table" read "label"/"unit" in the names. The group names keep their spec references.

- [ ] **Step 3: Port the controller's group tests.** Create `test/controller/unit_groups_controller_test.dart` from `jet_cad_floor_plan/test/host/table_groups_controller_test.dart`: TG-C1 (`:113-140`), TG-C2 (`:142-173`), TG-C3 (`:175-192`), TG-C4 (`:194-217`), TG-C5 (`:219-238`), TG-C6 (`:240-253`), TG-C7 (`:255-272`), TG-C8 (`:274-314`), TG-C9 (`:316-342`), TG-C12 (`:403-435`), TG-C13 (`:440-460`), TG-C14 (`:462-474`), TG-C15 (`:476-493`), TG-C16 (`:495-529`): 14 tests, **assertions unchanged**. TG-C10 and TG-C11 read `serviceEdited` and `resetLayout`: Task 13 ports them. Adaptations:
  - `controller(json)` → `controllerFor(kits: [testKit()], json: json)`; `groupsPlanJson` → `groupsPlanText`; `group(members, [label])` → `UnitGroup(members: members, label: label)`;
  - `FloorPlanMode.selection` → `PlanMode.service`; `setTableGroups` → `setUnitGroups`; `tableGroups` → `unitGroups`; `tableStatuses` → `unitStatuses`; `selectedTables` → `selectedUnits`; `TableStatus` → `UnitStatus`; `c.designJson()` → `c.save()`;
  - `keysOf`, `unnumberedKey` → the support's `keysOf`, `unlabelledKey`; TG-C15's `TableSurvey.of(c.activeDocument).withNumber('8')` → `unitNodes(c.activeDocument, '8')`;
  - the file's lead comment says "labels" for "numbers";
  - imports: `dart:ui show Color`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show SelectionKey`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `../support/harness.dart show controllerFor`, `../support/service_fixture.dart show seatsOf`, `../support/service_plans.dart`, `../support/test_kit.dart show testKit, unitKit`.

- [ ] **Step 4: Port the controller's status and focus tests.** Create `test/controller/service_state_controller_test.dart` from `jet_cad_floor_plan/test/host/controller_test.dart`: C15 (`:389-410`) as `SS-C15`, CF1 (`:692-719`), CF2 (`:721-731`) and CF5 (`:800-805`) as `SS-CF1`, `SS-CF2`, `SS-CF5`: 4 tests, **assertions unchanged** (CF3 and CF4 read `resetLayout`, `restoreServiceLayout` and `serviceLayoutChanges`: Task 13 ports them). Adaptations: `FloorPlanController(json:)` → `controllerFor(kits: [testKit()], json:)` (CF5: `PlanController(kits: [testKit()], json: servicePlanText())`, disposed by the test itself); `planJson()` and `zonePlanJson()` → `servicePlanText()`; `zoned(tester)` → that controller with `c.camera.value = ViewportTransform(worldToScreenMatrix: const Transform2(0.0375, 0, 0, -0.0375, 612.5, 431.25))` (a camera off the identity, as `zoneCamera()` was); `setTableStatus` → `setUnitStatus`; `TableStatus` → `UnitStatus`; `setTableFocus` → `setUnitFocus`; `tableFocus` → `unitFocus`; `designJson()` → `save()`; `FloorPlanMode.selection` → `PlanMode.service`. Imports: `dart:ui show Color`, `package:flutter/foundation.dart show ChangeNotifier`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show ViewportTransform`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `../support/harness.dart show controllerFor`, `../support/service_plans.dart`, `../support/test_kit.dart show testKit`.

- [ ] **Step 5: Write the failing tests (new).** Append to `test/controller/unit_groups_controller_test.dart` (Step 3's imports); the rows are Task 5's, through `hall()`, over `unitKit()`:

```dart
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
    expect(
        c.document.tables.layers[unitNode(c.document, '5').layer]!.locked,
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
```

  Append to `test/controller/service_state_controller_test.dart`:

```dart
  testWidgets(
      'SS-dup-label-status a label two units share: a status on each, the '
      'group\'s over it, none for an unlabelled unit; a group lists the '
      'label once and select takes both', (tester) async {
    final c = controllerFor(
        kits: [testKit()],
        json: servicePlanText(duplicate: true, unlabelled: true));
    final red = UnitStatus(color: const Color(0xFFE53935), caption: 'Bill');
    final blue = UnitStatus(color: const Color(0x801E88E5));
    c.setUnitStatus({'2': red, '': blue});
    c.setMode(PlanMode.service);
    final twos = [
      for (final u in c.unitIndex.units)
        if (u.text == '2') u
    ];
    expect(twos, hasLength(2), reason: 'premise: a label two units share');
    for (final u in twos) {
      expect(c.statusOf(u), red);
    }
    final bare = c.unitIndex.units.singleWhere((u) => u.text == null);
    // M-SS3: `statusOfUnit` reads an unlabelled unit as ''.
    expect(c.statusOf(bare), isNull);
    c.setUnitGroups({
      'g': UnitGroup(members: {'2', '1'})
    });
    c.setGroupStatus({'g': blue});
    // M-SS4: the unit's own status wins over its group's.
    for (final u in twos) {
      expect(c.statusOf(u), blue);
    }
    expect(c.selectableMembers('g'), {'1', '2'},
        reason: 'a shared label listed once');
    c.select({'2'});
    expect(c.activeSelection.keys, hasLength(3), reason: '1 and both 2s');
    expect(c.selectedUnits.value, {'1', '2'});
    await tester.pump();
  });
```

- [ ] **Step 6: Run the tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_state_test.dart test/controller/unit_groups_controller_test.dart test/controller/service_state_controller_test.dart`. Expected: compilation errors, `Undefined name 'UnitGroup'` and `The method 'setUnitGroups' isn't defined for the type 'PlanController'`.

- [ ] **Step 7: The service state.** Create `lib/src/service/service_state.dart`:

```dart
// Service state (spec 2b S3 "Service state"): a unit's status, a group of
// units, the validation of a host's groups, and the group rules the
// controller, the service tool, the painters and the service bar share, so
// each applies one rule. Ported from jet_cad_floor_plan's
// lib/src/host/floor_plan_types.dart (TableStatus :128-159, TableGroup
// :244-300) and lib/src/service/table_groups.dart (whole file), keyed by
// label instead of number; a unit's lock is `isLockedUnit` (spec S2
// "Locked units"), not its layer's alone.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter/widgets.dart' show Color, StringCharacters;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;

import '../units/unit_index.dart';

/// A unit's status as the host colours it in service (spec S3): a fill
/// under the drafting and an optional short caption. Not document state:
/// never saved, exported, printed or undone.
@immutable
final class UnitStatus {
  /// [caption] is cut to [maxCaption] characters (grapheme clusters).
  UnitStatus({required this.color, String? caption})
      : caption = caption?.characters.take(maxCaption).toString();

  /// The longest caption, in characters.
  static const int maxCaption = 12;

  /// The fill, drawn as given: a translucent colour lets the paper show.
  final Color color;

  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is UnitStatus && other.color == color && other.caption == caption;

  @override
  int get hashCode => Object.hash(color, caption);

  @override
  String toString() => 'UnitStatus($color, $caption)';
}

/// A group of units the host merged (spec S3): in service its members are
/// framed, labelled, selected and moved as one. Addressed by the host's
/// group id. Not document state.
@immutable
final class UnitGroup {
  /// [members] are unit labels, each trimmed, a blank one dropped. [label]
  /// is trimmed, a blank one meaning none, then cut to [maxLabel]
  /// characters (grapheme clusters).
  UnitGroup({required Set<String> members, String? label})
      : members = Set.unmodifiable(<String>{
          for (final m in members)
            if (m.trim().isNotEmpty) m.trim()
        }),
        label = switch (label?.trim()) {
          null || '' => null,
          final l => l.characters.take(maxLabel).toString(),
        };

  /// The longest label, in characters.
  static const int maxLabel = 24;

  /// The member labels, trimmed, none blank; unmodifiable. A label with no
  /// live unit is kept and resolves once such a unit exists.
  final Set<String> members;

  /// The host's text for the group's chip, or null for its labels.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is UnitGroup &&
      other.label == label &&
      setEquals(other.members, members);

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(members), label);

  @override
  String toString() => 'UnitGroup($members, $label)';
}

/// [groups] with their ids trimmed, in their given order, unmodifiable.
///
/// Throws an [ArgumentError], before anything is returned, for an empty or
/// blank id, for two ids that are the same after trimming, for a group
/// with no member (a [UnitGroup] drops blank members), and for a label in
/// two groups; the message names the label and both ids.
Map<String, UnitGroup> validateUnitGroups(Map<String, UnitGroup> groups) {
  final out = <String, UnitGroup>{};
  final owner = <String, String>{};
  for (final MapEntry(key: raw, value: group) in groups.entries) {
    final id = raw.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(raw, 'groups', 'A group id is blank');
    }
    if (out.containsKey(id)) {
      throw ArgumentError.value(
          raw, 'groups', 'Two group ids are "$id" after trimming');
    }
    if (group.members.isEmpty) {
      throw ArgumentError.value(raw, 'groups', 'Group "$id" has no member');
    }
    for (final l in group.members) {
      final other = owner[l];
      if (other != null) {
        throw ArgumentError.value(raw, 'groups',
            'Unit label "$l" is in two groups, "$other" and "$id"');
      }
      owner[l] = id;
    }
    out[id] = group;
  }
  return Map.unmodifiable(out);
}

/// The id of the group each member label of [groups] belongs to; [groups]
/// as [validateUnitGroups] returns them, so a label has one group.
Map<String, String> groupIdsByLabel(Map<String, UnitGroup> groups) => {
      for (final MapEntry(key: id, value: g) in groups.entries)
        for (final l in g.members) l: id,
    };

/// One unit as the group rules see it.
final class GroupUnit {
  const GroupUnit(
      {required this.handle,
      required this.label,
      required this.visible,
      required this.locked,
      this.generated = false});

  /// The unit's instance.
  final Handle handle;

  /// Its label, trimmed, or null while it has none.
  final String? label;

  /// On a shown layer (a hidden unit counts for nothing).
  final bool visible;

  /// `isLockedUnit`: shown and tapped, never selected (spec S2).
  final bool locked;

  /// Made by its object's type: never dragged (spec S4).
  final bool generated;

  /// Visible and unlocked: what a selection may hold.
  bool get selectable => visible && !locked;

  @override
  String toString() => 'GroupUnit(${handle.toHex()}, $label'
      '${visible ? '' : ', hidden'}${locked ? ', locked' : ''}'
      '${generated ? ', generated' : ''})';
}

/// [index]'s units as the group rules see them.
List<GroupUnit> groupUnitsOf(UnitIndex index) => [
      for (final u in index.units)
        GroupUnit(
            handle: u.instance,
            label: u.text,
            visible: u.visible,
            locked: u.locked,
            generated: u.generated),
    ];

/// The groups resolved against one document's units. Built at
/// document-change or groups-change rate, never per frame or per pointer
/// event.
final class UnitGroupLookup {
  /// [groups] as [validateUnitGroups] returns them; [units] in any order.
  factory UnitGroupLookup(
      Map<String, UnitGroup> groups, Iterable<GroupUnit> units) {
    final byLabel = groupIdsByLabel(groups);
    final sorted = units.toList()
      ..sort((a, b) => a.handle.value.compareTo(b.handle.value));
    final visible = <String, List<GroupUnit>>{};
    for (final u in sorted) {
      final l = u.label;
      if (l == null || !u.visible) continue;
      final id = byLabel[l];
      if (id != null) (visible[id] ??= []).add(u);
    }
    return UnitGroupLookup._(
      groups,
      Map.unmodifiable(byLabel),
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          id: List.unmodifiable(list),
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          id: List.unmodifiable([
            for (final u in list)
              if (u.selectable) u
          ]),
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          if (list.any((u) => u.locked)) id,
      },
      {
        for (final MapEntry(key: id, value: list) in visible.entries)
          if (list.any((u) => u.generated)) id,
      },
    );
  }

  UnitGroupLookup._(this.groups, this.byLabel, this._visible,
      this._selectable, this._locked, this._generated);

  /// The groups this lookup resolves.
  final Map<String, UnitGroup> groups;

  /// The id of each member label's group; unmodifiable.
  final Map<String, String> byLabel;

  final Map<String, List<GroupUnit>> _visible;
  final Map<String, List<GroupUnit>> _selectable;
  final Set<String> _locked;
  final Set<String> _generated;

  /// The id of the group [label] (trimmed) belongs to, or null.
  String? groupOf(String label) => byLabel[label.trim()];

  /// The group's members on a shown layer, a locked one included,
  /// ascending by handle; every unit carrying a member label counts (a
  /// shared label gives several). Empty for an unknown id.
  List<GroupUnit> visibleMembers(String id) => _visible[id] ?? const [];

  /// The group's visible, unlocked members, ascending by handle: what a
  /// tap, a drag or a selection by label may select.
  List<GroupUnit> selectableMembers(String id) => _selectable[id] ?? const [];

  /// Whether a visible member of the group is locked: the group is then
  /// never dragged. A locked member on a hidden layer does not count.
  bool hasLockedVisibleMember(String id) => _locked.contains(id);

  /// Whether a visible member of the group is generated (a seat): the
  /// group is then never dragged (spec S4 "A drag").
  bool hasGeneratedVisibleMember(String id) => _generated.contains(id);

  /// The Split rule, the id `PlanController.selectedGroup` holds: the group
  /// whose selectable members' labels are exactly [selectedLabels], when
  /// that set is not empty and no unlabelled unit is selected
  /// ([unlabelledSelected]); else null.
  String? splitGroup(Set<String> selectedLabels,
      {required bool unlabelledSelected}) {
    if (unlabelledSelected || selectedLabels.isEmpty) return null;
    // A label is in one group at most, so only the first's can match.
    final id = groupOf(selectedLabels.first);
    if (id == null) return null;
    final labels = <String>{
      for (final u in selectableMembers(id)) u.label!,
    };
    final selected = <String>{for (final l in selectedLabels) l.trim()};
    if (labels.length != selected.length || !labels.containsAll(selected)) {
      return null;
    }
    return id;
  }
}

/// The Merge rule: whether [selectedLabels] span two or more units of
/// merging, each a group of [groups] or a selected label in no group. One
/// unit, two units sharing one label, and exactly one group do not;
/// unlabelled units carry no label and count for nothing.
bool mergeQualifies(Set<String> selectedLabels, Map<String, UnitGroup> groups) {
  final byLabel = groupIdsByLabel(groups);
  final parts = <(bool, String)>{};
  for (final raw in selectedLabels) {
    final l = raw.trim();
    if (l.isEmpty) continue;
    final id = byLabel[l];
    parts.add(id == null ? (false, l) : (true, id));
    if (parts.length >= 2) return true;
  }
  return false;
}

/// The lead order over [labels]: numeric when every one is all ASCII
/// digits -- (length after stripping leading zeros, then that string,
/// then the label as written), never `int.parse`, so any length compares
/// -- else plain string order.
Comparator<String> unitLabelOrder(Iterable<String> labels) {
  if (labels.isNotEmpty && labels.every(_digits.hasMatch)) return _numeric;
  return _plain;
}

final RegExp _digits = RegExp(r'^[0-9]+$');

int _plain(String a, String b) => a.compareTo(b);

int _numeric(String a, String b) {
  final sa = _stripZeros(a), sb = _stripZeros(b);
  final byLength = sa.length.compareTo(sb.length);
  if (byLength != 0) return byLength;
  final byValue = sa.compareTo(sb);
  if (byValue != 0) return byValue;
  return a.compareTo(b);
}

String _stripZeros(String s) {
  var i = 0;
  while (i < s.length && s.codeUnitAt(i) == 0x30) {
    i++;
  }
  return s.substring(i);
}

/// The labelled units of [members] in lead order: by [unitLabelOrder] over
/// their labels, ties (a shared label) to the lowest handle. The first is
/// the lead.
List<GroupUnit> inLeadOrder(Iterable<GroupUnit> members) {
  final list = [
    for (final u in members)
      if (u.label != null) u
  ];
  final order = unitLabelOrder([for (final u in list) u.label!]);
  list.sort((a, b) {
    final byLabel = order(a.label!, b.label!);
    if (byLabel != 0) return byLabel;
    return a.handle.value.compareTo(b.handle.value);
  });
  return list;
}

/// The status a unit labelled [label] shows: its group's when the group
/// has one, else its own; none for an unlabelled unit (today's
/// `TableStatusPainter` order, group over table).
UnitStatus? statusOfUnit(String? label,
    {required Map<String, UnitStatus> statuses,
    required Map<String, UnitStatus> groupStatuses,
    required Map<String, String> groupByLabel}) {
  if (label == null) return null;
  final id = groupByLabel[label];
  if (id != null) {
    final group = groupStatuses[id];
    if (group != null) return group;
  }
  return statuses[label];
}
```

- [ ] **Step 8: The controller's service state.** In `lib/src/controller/plan_controller.dart`, import `'../service/service_state.dart'`, then:
  1. Add the focus notifier beside `_Requests` (today's `_Focus`, `floor_plan_controller.dart:205-218`):

```dart
/// The unit focus: each [replace] notifies, an equal set or a second null
/// included.
final class _Focus extends ChangeNotifier
    implements ValueListenable<Set<String>?> {
  Set<String>? _value;

  @override
  Set<String>? get value => _value;

  void replace(Set<String>? next) {
    _value = next;
    notifyListeners();
  }
}
```

  2. Add the section (today's `floor_plan_controller.dart:575-672`, `:765-779`, `:1872-1920`, `:1942-1964`, by label):

```dart
  // ---------------------------------------------------------------------
  // Service state (spec 2b S3 "Service state"), by label. Kept for the
  // controller's life: across mode switches, resetService, restoreService,
  // load and newPlan. Not document state: no command, undo step, dirty or
  // revision; never saved, exported or printed.

  final ValueNotifier<Map<String, UnitStatus>> _statuses =
      ValueNotifier(const <String, UnitStatus>{});
  final ValueNotifier<Map<String, UnitGroup>> _groups =
      ValueNotifier(const <String, UnitGroup>{});
  final ValueNotifier<Map<String, UnitStatus>> _groupStatuses =
      ValueNotifier(const <String, UnitStatus>{});
  final ValueNotifier<String?> _selectedGroup = ValueNotifier(null);
  final ValueNotifier<Set<String>?> _mergeCandidate = ValueNotifier(null);
  final _Focus _focus = _Focus();

  /// The units' statuses by label, as [setUnitStatus] last set them; drawn
  /// in service only, on every live, visible unit carrying the label.
  ValueListenable<Map<String, UnitStatus>> get unitStatuses => _statuses;

  /// Replaces every status at once: labels trimmed.
  void setUnitStatus(Map<String, UnitStatus> statuses) {
    _statuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The unit groups by trimmed id, as [setUnitGroups] last set them; they
  /// act in service only.
  ValueListenable<Map<String, UnitGroup>> get unitGroups => _groups;

  /// Replaces every group at once: ids trimmed. Throws an [ArgumentError]
  /// for a blank id, two ids the same after trimming, a group with no
  /// member after trimming, or a label in two groups; then nothing is
  /// assigned and no listener is notified. A member label with no live
  /// unit is kept; a shared label is allowed; a group may mix kinds.
  void setUnitGroups(Map<String, UnitGroup> groups) {
    final valid = validateUnitGroups(groups);
    _groups.value = valid;
    _refreshSelectedGroup();
  }

  /// The groups' statuses by trimmed id, as [setGroupStatus] last set them.
  ValueListenable<Map<String, UnitStatus>> get groupStatuses => _groupStatuses;

  /// Replaces every group status at once: ids trimmed. A group's status
  /// fills every visible member and overrides each member's own status
  /// while it is set. A status whose id has no group is kept, draws
  /// nothing, and applies again when a group with that id comes back.
  void setGroupStatus(Map<String, UnitStatus> statuses) {
    _groupStatuses.value = Map.unmodifiable(
        {for (final e in statuses.entries) e.key.trim(): e.value});
  }

  /// The labels in focus, as [setUnitFocus] last set them: null for none.
  /// In service every unit outside a focus lies under a veil.
  ValueListenable<Set<String>?> get unitFocus => _focus;

  /// Replaces the focus: null for none, else [labels] trimmed, blanks
  /// dropped, copied into an unmodifiable set, so `{}` and `{''}` are a
  /// focus with no unit. Every call notifies [unitFocus], an equal set
  /// included. Presentation only: no command, undo step, dirty, revision,
  /// service change or notification of this controller.
  void setUnitFocus(Set<String>? labels) {
    _focus.replace(labels == null
        ? null
        : Set<String>.unmodifiable({
            for (final l in labels)
              if (l.trim() case final t when t.isNotEmpty) t,
          }));
  }

  /// The id of the group the selection is exactly (the Split rule): the
  /// selected labels are that group's selectable members' labels, and no
  /// unlabelled unit is selected. Null otherwise, and always in design.
  /// It updates after [selectedUnits] and [unitGroups] have notified.
  ValueListenable<String?> get selectedGroup => _selectedGroup;

  /// The labels the service bar's Merge would send: in service
  /// [selectedUnits], unmodifiable, when they span two or more groups or
  /// ungrouped labels; null otherwise, and always in design.
  ValueListenable<Set<String>?> get mergeCandidate => _mergeCandidate;

  /// The labels of group [groupId]'s (trimmed) selectable members in the
  /// active document: its live members on a shown layer that no lock
  /// covers. A label several units carry is in it once. Empty for an
  /// unknown id; unmodifiable; valid in both modes, fresh at every call.
  Set<String> selectableMembers(String groupId) => Set.unmodifiable({
        for (final u in _groupLookup.selectableMembers(groupId.trim()))
          u.label!,
      });

  /// The groups resolved against the active document's units (Tasks
  /// 14-16).
  @internal
  UnitGroupLookup get groupLookup => _groupLookup;

  /// The status [unit] shows (Tasks 15-16): its group's over its own.
  @internal
  UnitStatus? statusOf(UnitInfo unit) => statusOfUnit(unit.text,
      statuses: _statuses.value,
      groupStatuses: _groupStatuses.value,
      groupByLabel: _groupLookup.byLabel);

  UnitGroupLookup? _lookup;
  UnitIndex? _lookupUnits;
  Map<String, UnitGroup>? _lookupGroups;

  /// The groups resolved against the active units, made again when the
  /// unit index (a state, layer or lock change) or the groups move.
  UnitGroupLookup get _groupLookup {
    final units = _activeUnits.current;
    final groups = _groups.value;
    if (_lookup == null ||
        !identical(_lookupUnits, units) ||
        !identical(_lookupGroups, groups)) {
      _lookup = UnitGroupLookup(groups, groupUnitsOf(units));
      _lookupUnits = units;
      _lookupGroups = groups;
    }
    return _lookup!;
  }

  /// [labels], each label of a group replaced by all its members: in
  /// service only, where groups act. (Task 9's seam, given its body here.)
  Set<String> _expandLabels(Set<String> labels) {
    final groups = _groups.value;
    if (_service == null || groups.isEmpty) return labels;
    final lookup = _groupLookup;
    return {
      for (final l in labels)
        ...switch (lookup.groupOf(l)) {
          null => [l],
          final id => groups[id]!.members,
        }
    };
  }

  /// [selectedGroup] and [mergeCandidate] over the active document.
  void _refreshSelectedGroup() {
    final service = _service != null;
    String? id;
    if (service && _groups.value.isNotEmpty) {
      final keys = activeSelection.keys;
      final unlabelled = _activeUnits.current.units.any((u) =>
          u.text == null && keys.contains(SelectionKey.root(u.instance)));
      id = _groupLookup.splitGroup(_selectedUnits.value,
          unlabelledSelected: unlabelled);
    }
    _selectedGroup.value = id;
    final selected = _selectedUnits.value;
    final candidate =
        service && mergeQualifies(selected, _groups.value) ? selected : null;
    final last = _mergeCandidate.value;
    if (candidate == null ? last != null : !setEquals(candidate, last)) {
      _mergeCandidate.value = candidate;
    }
  }
```

  3. Task 9's `_select` already reads `for (final l in _expandLabels(labels))`; the method above replaces Task 9's seam body (`=> labels`). `_select`'s doc gains: "In service a label in a group stands for the group's selectable members (the same filter)."
  4. Task 9's `_refreshSelected` (re-pointed by Task 11) ends with `_refreshSelectedGroup();`.
  5. `dispose`: after `_mode.dispose();` add `_statuses.dispose(); _groups.dispose(); _groupStatuses.dispose(); _selectedGroup.dispose(); _mergeCandidate.dispose(); _focus.dispose();`.

- [ ] **Step 9: Export.** In `lib/jet_cad_2d_plan.dart` add `export 'src/service/service_state.dart' show UnitGroup, UnitStatus;` (sorted). In `test/barrel_test.dart`, ED-9's set gains `// 2b Task 12` and `'UnitGroup', 'UnitStatus',`.

- [ ] **Step 10: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_state_test.dart test/controller/unit_groups_controller_test.dart test/controller/service_state_controller_test.dart test/barrel_test.dart`. Expected: `All tests passed!`. Then `flutter test`. Expected: `All tests passed!`.

- [ ] **Step 11: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. From the root, `git status --short`: only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/service/service_state.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/barrel_test.dart packages/jet_cad_2d_plan/test/support/service_plans.dart packages/jet_cad_2d_plan/test/service/service_state_test.dart packages/jet_cad_2d_plan/test/controller/unit_groups_controller_test.dart packages/jet_cad_2d_plan/test/controller/service_state_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): unit statuses, groups and focus by label (2b S3)

PlanController gains the service state today's controller holds by
table number, now by unit label: statuses, groups with today's
validation, group statuses, the focus, selectedGroup, mergeCandidate
and selectableMembers. In service a label in a group selects the
group's selectable members; a seat is a member like a table; a unit
under a lock is grouped and takes its group's status but is never
selected.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test file, see the named test red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-SS1 `lib/src/controller/plan_controller.dart`: in `setUnitStatus`, `e.key.trim()` → `e.key` → SS-C15 red (`keys` is `[' 1 ']`).
  - M-SS2 `plan_controller.dart`: in `_groupLookup`, delete `!identical(_lookupUnits, units) ||` → SS-shrink-group red (`selectableMembers` still holds 11 and 12); SS-relabel red (it still holds the old label); TG-C12 and TG-C16 red too.
  - M-SS3 `lib/src/service/service_state.dart`: in `statusOfUnit`, `if (label == null) return null;` → `label ??= '';` → SS-dup-label-status red (the unlabelled unit takes `''`'s status).
  - M-SS4 `service_state.dart`: in `statusOfUnit`, delete the `if (id != null) { … }` block → SS-dup-label-status red (red over blue).
  - M-SS5 `service_state.dart`: in `groupUnitsOf`, `locked: u.locked,` → `locked: false,` → SS-locked-not-selected red (`selectableMembers` holds 5); TG-C7 red too.
  - M-SS6 `plan_controller.dart`: in `_select`, `if (!u.visible || u.locked) continue;` → `if (!u.visible) continue;` → SS-locked-not-selected red (5 selected).
  - M-SS7 `service_state.dart`: in `groupUnitsOf`, the loop's body guarded by `if (!u.generated)` → SS-mixed-group red (the seats are not selected).
  - M-SS8 `service_state.dart`: `bool hasGeneratedVisibleMember(String id) => _generated.contains(id);` → `=> false;` → SS-mixed-group red.
  - M-TG1 `service_state.dart`: in `validateUnitGroups`, delete the `if (other != null) { throw … }` block → TG-U5 and TG-C1 red.
  - M-TG2 `plan_controller.dart`: `_expandLabels` returns `labels` first thing → TG-C5 red.
  - M-TG3 `plan_controller.dart`: in `_refreshSelectedGroup`, `service && _groups.value.isNotEmpty` → `_groups.value.isNotEmpty` → TG-C9 red (`selectedGroup` `G2` in design).
  - M-TG4 `plan_controller.dart`: `selectableMembers(groupId.trim())` → `selectableMembers(groupId)` → TG-C14 red.
  - M-TG5 `service_state.dart`: in `splitGroup`, delete `if (unlabelledSelected || selectedLabels.isEmpty) return null;`'s `unlabelledSelected ||` → TG-C8 and TG-U13 red.
  - M-TG6 `service_state.dart`: in `UnitGroupLookup`'s factory, `if (l == null || !u.visible) continue;` → `if (l == null) continue;` → TG-U8 red.
  - M-TG7 `service_state.dart`: `unitLabelOrder` returns `_plain` always → TG-U14 red.
  - M-TG8 `service_state.dart`: in `mergeQualifies`, `if (l.isEmpty) continue;` deleted → TG-U10 red.
  - M-SS9 `plan_controller.dart`: in `_Focus.replace`, `if (setEquals(next, _value) && next != null) return;` added first → SS-CF1 red (an equal set does not notify).
  - M-SS10 `plan_controller.dart`: `setUnitFocus`'s body → `_focus.replace(labels);` (no copy) → SS-CF2 red (the host's later change shows); SS-CF1 red too.
  - M-SS11 `plan_controller.dart`: delete `_focus.dispose();` → SS-CF5 red.

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 11: `_service`, `activeSelection`, Task 9's `_select`, `_refreshSelected`, `_expandLabels`, `_activeUnits` (`UnitIndexCache get _activeUnits`, re-pointed by Task 11), the support file `test/support/service_plans.dart` (`unitDefinition`, `placeDef`, `turned`, `kDeg37`, `addLayer`, `servicePlanText`, `lockedPlanText`, `unitNode`, `unitNodes`, `labelOf`, `hall`).
- Task 9: `_selectedUnits`, `@internal unitIndex`; Task 11: `selectedUnits`; `revision`, `undo` acting on the design in design.
- Task 6: `UnitInfo.text`, `visible`, `locked`, `generated`, `instance`; `UnitIndex.units`, `operator []`.
- Task 5: `unitKit()` (`test/support/test_kit.dart`); `RowComponent` (component type `test.row`) with `count` and `copyWith({int? count})`; `seatsOf(DraftDocument, Handle row)` (`test/support/service_fixture.dart`, the row's instance children ascending); a row edit through `PlanController.execute` regenerates its seats with E5's matching (seats 1-10 keep their handles when 12 become 10); `hall()`'s row A holds six seats and row B five.

---

