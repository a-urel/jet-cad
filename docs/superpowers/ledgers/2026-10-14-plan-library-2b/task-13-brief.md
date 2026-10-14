### Task 13: The service record (spec S3 "The service record", `serviceEdited`, `serviceChanges`, `resetService`; decision 4; S5 controller rows 3-8)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/service/service_record.dart` (`kServiceFormat`, `kServiceVersion`, `ServiceMove`, `RecordGroup`, `ServiceRecord`, `sameTransform`, `serviceMovesOf`, `encodeServiceRecord`, `decodeServiceRecord`, `matchServiceMoves`, `matchServiceGroups`, `ServiceRestore`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`serviceJson`, `restoreService`, `resetService`, `serviceEdited`, `serviceChanges`; the announce on a copy's change, undo and redo; the groups held on entering; `setUnitGroups` in service)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `ServiceRestore`), `packages/jet_cad_2d_plan/test/barrel_test.dart` (ED-9)
- Test: `packages/jet_cad_2d_plan/test/service/service_record_test.dart` (ported LC1-LC6; new SR-codec-shapes), `packages/jet_cad_2d_plan/test/controller/service_record_controller_test.dart` (ported C2, C10, C14, C16-C20, CF3, CF4, TG-C10, TG-C11; new SR-*)

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `Handle.toHex`, `Handle.parseHex`, `HandleRangeError`, `Transform2.toJson`, `TransformNodeCommand`, `CompoundCommand`, `CommandDispatcher.clearHistory` (`undo.dart:277`, the state id unmoved), `SetEntityTextCommand`.
  - Task 6: `UnitIndex.units`, `operator []`, `withLabel`; `UnitInfo.instance`, `text`, `generated`, `locked` (`isLockedUnit`); `PlanController.unitIndex` (`@internal`); `DocumentSession.units`.
  - Task 11: `_service`, `_buildService()`, `_attachService(ServiceSession)`, `_dropService(ServiceSession)`, `_onServiceChanged()`, `_select`, `_refreshSelected`, `_refreshFlags`, `setMode`, `undo`, `redo`, `_replace`'s service branch; `ServiceSession.document`, `units`; the support file (`servicePlanText`, `lockedPlanText`, `unitDefinition`, `placeDef`, `addLayer`, `unitNode`, `labelEntityOf`, `labelOf`, `move`, `drawLine`, `parts`, `hall`).
  - Task 12: `UnitGroup`, `_groups`, `setUnitGroups`, `unitGroups`, `setUnitStatus`, `setGroupStatus`, `setUnitFocus`, `unitFocus`, `selectedGroup`; the support's `groupsPlanText`, `bill`.
  - Task 9: `_selectedUnits`, `revision` (`_revision`); Task 11: `selectedUnits`.
- Produces (Shared interfaces, Task 13):
  - `const String kServiceFormat = 'jet_cad.service'; const int kServiceVersion = 1;` (internal, as today's `kServiceLayoutFormat`).
  - `final class ServiceRestore { final List<String?> appliedMoves, droppedMoves; final List<String> appliedGroups, droppedGroups; }` (exported).
  - On `PlanController`: `String? serviceJson()`; `ServiceRestore restoreService(String json)`; `void resetService()`; `bool get serviceEdited`; `Listenable get serviceChanges` (Task 16's view, bar and events read them).
  - Internal: `ServiceMove({handle, label, from, to})`, `RecordGroup({id, members, label})`, `ServiceRecord({moves, groups})`, `bool sameTransform(Transform2, Transform2)`, `List<ServiceMove> serviceMovesOf(DraftDocument design, DraftDocument copy, UnitIndex copyUnits)`, `String encodeServiceRecord(List<ServiceMove>, Map<String, UnitGroup>)`, `ServiceRecord decodeServiceRecord(String)`, `({List<ServiceMove> applied, List<ServiceMove> dropped}) matchServiceMoves(DraftDocument design, UnitIndex designUnits, List<ServiceMove>)`, `({Map<String, UnitGroup> applied, List<String> appliedIds, List<String> droppedIds}) matchServiceGroups(List<RecordGroup>, UnitIndex designUnits)`.

Plan decisions:
- **The record's shape** is the spec's (S3): `{"format", "version", "moves": [{"handle", "label", "from", "to"}], "groups": [{"id", "members", "label"}]}`, in that key order. Moves are ascending by handle (today's `serviceLayoutOf`, `jet_cad_floor_plan/lib/src/host/service_layout.dart:47-64`); groups in the controller's order, members in each group's set order, so `serviceJson()` after a restore is byte for byte the record restored.
- **What is a `FormatException`** (nothing changed): text that is not JSON or not an object; a `format` other than `jet_cad.service` (today's `jet_cad.service_layout` included); a `version` other than 1; `moves` or `groups` missing or not a list; a move as today's layout entry would be refused (`service_layout.dart:86-130`, `number` read as `label`); a group that is not an object, whose `id` is not a string, whose `members` is not a list of strings, or whose `label` is neither a string nor null (absent counts as null). Groups that break `setUnitGroups`' validation are **not** a `FormatException` (spec S3): they are dropped by the match.
- **The groups' match**, in record order, each group checked against the groups applied before it: its `id` trimmed must not be blank nor equal one applied; its members (trimmed, blanks dropped by `UnitGroup`) must not be empty; every member must name a unit of the design (any unit carrying the label, hidden or locked included; a shared label is kept, spec S3); no member may already belong to an applied group (the later group drops). A group failing any check is dropped whole, never shrunk; `appliedGroups` and `droppedGroups` list the trimmed ids in record order.
- **The moves' strict match** is today's (`service_layout.dart:138-169`) over the design's `UnitIndex`: the handle is a unit of the design, **placed** (`!generated`, spec S3 "Only placed units move"), not `isLockedUnit` (spec S3), on a visible unlocked layer (a missing layer counts as visible), carrying the same label (null for an unlabelled one), exactly at `from`, `to` a translation of `from`, every value finite.
- **A restore builds the new copy before it drops the old one**: the applied moves are executed on the new copy (its systems installed, so a place reader regenerates as on any service move; a translation re-stamps no label), its history cleared, and only then is the controller attached to it (`_attachService`), so the restore is no step and fires no change of its own; a failure while applying disposes the new copy and leaves everything as it was. Today's restore executed before attaching too (`floor_plan_controller.dart:1142-1155`).
- **The groups held when service was entered** (`_groupsAtEnter`, for `serviceEdited`): set by `setMode` into service and by a load or a new plan in service (a fresh copy, as today a fresh copy reads unedited), set to none by `resetService` (which clears the groups), left as they were by `restoreService` (so a record's groups that differ from those held on entering read as an edit).
- **`serviceChanges` timing** is today's (`floor_plan_controller.dart:1103-1111`, `:1425-1436`): on a change of the active copy's history state (a move, an undo, a redo), announced by `undo`/`redo` before they return and heard once; `resetService`; `restoreService`; and, new (spec S3, S5 row 4), `setUnitGroups` in service. Never on `setMode`, `load` or `newPlan`. In design `setUnitGroups` notifies `unitGroups` only.

Rulings for the ported tests, accepted by controller ruling R-11 (each a premise the spec changed; each an execution ruling the ledger records):
- **R13-a (the format is the premise):** LC2's `contains('"format":"jet_cad.service_layout"')` becomes `contains('"format":"jet_cad.service"')`; LC3's and LC4's texts are written in the new format (`moves`, `label`, `groups: []`), each bad text keeping its kind of breakage; C16's `jsonDecode(…)['tables']` reads `['moves']`; C20's `contains('"tables":[{')` and `contains('"tables":[]')` read `'"moves":[{'` and `'"moves":[]'`. Spec S3 (the record), S5 row 7 (no compatibility).
- **R13-b (renames):** `serviceLayoutJson` → `serviceJson`, `restoreServiceLayout` → `restoreService`, `ServiceLayoutRestore.applied`/`dropped` → `ServiceRestore.appliedMoves`/`droppedMoves`, `resetLayout` → `resetService`, `serviceLayoutChanges` → `serviceChanges` (S5 rows 3-8). No assertion changes.
- **R13-c (TG-C10):** its last line, `expect(c.serviceEdited, isFalse)` after groups set in service, reads `isTrue`: groups count (spec S3 `serviceEdited`, S5 row 3, a marked difference).
- **R13-d (TG-C11):** its `resetLayout` step (`table_groups_controller_test.dart:388-391`: the groups kept, the selection kept with its group) is retired: `resetService` clears the groups (spec S3, S5 row 9, a marked difference). Its other steps are ported unchanged; SR-reset pins the new rule.

- [ ] **Step 1: Port the record's codec and match tests.** Create `test/service/service_record_test.dart` from `jet_cad_floor_plan/test/host/service_layout_test.dart` (the whole file): LC1, LC2, LC3, LC4, LC6, and LC5's six cases: 11 tests, **assertions unchanged** but for ruling R13-a. Fixtures, names and imports adapted: `design()` builds today's plan with the support's units; `copyOf` decodes under runtime permissions with the plan's registry; `TableSurvey` → `UnitIndex` (`unitsOf`); `table(doc, n)` → `unitNode`; `move(doc, …)` → `moveIn`; `serviceLayoutOf` → `serviceMovesOf`; `encodeServiceLayout(entries)` → `encodeServiceRecord(moves, const {})`; `decodeServiceLayout` → `decodeServiceRecord(…).moves`; `matchServiceLayout(d, entries)` → `matchServiceMoves(d, unitsOf(d), entries)`; `ServiceLayoutEntry(number:)` → `ServiceMove(label:)`; `.number` → `.label`; a renumber → a relabel through `labelEntityOf` and `kUnitLabelTag`. Then the new SR-codec-shapes at the end.

```dart
// jet_cad_floor_plan's test/host/service_layout_test.dart (LC1-LC6),
// ported to the service record (spec 2b S3 "The service record"):
// assertions unchanged but where the format itself is the premise
// (ruling R13-a). Units are turned, mirrored and off the origin; moves are
// off-grid; the copy is a decoded copy of the design under runtime
// permissions, as the controller makes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/service/service_record.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placementTransform;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart'
    show catalogOf, planDocument, registerPlanComponents;
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit;

/// Units 1 (a quarter turn, mirrored), 2, 3 (a stool, half-turned) and 4
/// (on layer `L`), and a planter (today's `design()`,
/// service_layout_test.dart:16-45).
DraftDocument design() {
  final d = planDocument([testKit()]);
  final table = unitDefinition(d, key: 'test.table.square.four');
  final stool = unitDefinition(d,
      key: 'test.stool.round.one', name: 'Stool', capacity: 1, round: true);
  final planter = unitDefinition(d,
      key: 'test.planter.square.one', name: 'Planter', unit: false);
  placeDef(
      d,
      table,
      placementTransform(
          at: Vector2(-2600.25, 1400.5),
          basePoint: table.base,
          quarterTurns: 1,
          mirrored: true),
      label: '1');
  placeDef(
      d,
      table,
      placementTransform(at: Vector2(2300.75, 1400), basePoint: table.base),
      label: '2');
  placeDef(
      d,
      stool,
      placementTransform(
          at: Vector2(300, -2100.125), basePoint: stool.base, quarterTurns: 2),
      label: '3');
  final four = placeDef(
      d,
      table,
      placementTransform(
          at: Vector2(5100.5, -3300.25),
          basePoint: table.base,
          quarterTurns: 3),
      label: '4');
  placeDef(d, planter,
      placementTransform(at: Vector2(4100, -900), basePoint: planter.base));
  final layer = addLayer(d, 'L', visible: true, locked: false);
  d.commands.execute(SetInstanceLayerCommand(four, layer));
  return d;
}

DraftDocument copyOf(DraftDocument doc) => DraftDocumentCodec.decodeString(
    DraftDocumentCodec.encodeToString(doc),
    permissions: DraftPermissions.runtime,
    registerComponents: (r) => registerPlanComponents(r, catalogOf([testKit()])));

/// [d]'s units, every kit but the test kit missing.
UnitIndex unitsOf(DraftDocument d) => UnitIndex.of(d,
    catalog: catalogOf([testKit()]),
    locks: LockSet.scan(d, (kit) => kit == 'test'));

InstanceNode table(DraftDocument doc, String label) => unitNode(doc, label);

void moveIn(DraftDocument doc, String label, double dx, double dy) {
  final node = table(doc, label);
  doc.commands.execute(TransformNodeCommand(
      node.handle, Transform2.translation(dx, dy).multiply(node.transform)));
}

/// [d]'s copy with every unit moved, the highest handle first.
DraftDocument movedCopy(DraftDocument d) {
  final copy = copyOf(d);
  for (final (l, dx, dy) in const [
    ('4', 111.125, -37.5),
    ('3', -250.5, 75.25),
    ('2', 640.375, 12.5),
    ('1', -95.75, -410.625),
  ]) {
    moveIn(copy, l, dx, dy);
  }
  return copy;
}

List<ServiceMove> movesOf(DraftDocument d, DraftDocument copy) =>
    serviceMovesOf(d, copy, unitsOf(copy));

void main() {
  test(
      'LC1 the record lists the moved units, ascending by handle although '
      'moved highest first; a unit moved back exactly is not listed (S1, '
      'M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    moveIn(copy, '2', -640.375, -12.5);
    final entries = movesOf(d, copy);
    expect([for (final e in entries) e.label], ['1', '3', '4']);
    final handles = [for (final e in entries) e.handle.value];
    expect(handles, [...handles]..sort());
    expect(handles.first < handles.last, isTrue, reason: 'premise');
    for (final e in entries) {
      expect(parts(e.from), parts(table(d, e.label!).transform));
      expect(parts(e.to), parts(table(copy, e.label!).transform));
    }
    expect(parts(entries.first.to)[4],
        closeTo(parts(entries.first.from)[4] - 95.75, 1e-9));
  });

  test(
      'LC2 the encoding round-trips, and is byte-equal twice and after the '
      'design is encoded and decoded (S1, M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    final text = encodeServiceRecord(movesOf(d, copy), const {});
    expect(encodeServiceRecord(movesOf(d, copy), const {}), text);
    expect(encodeServiceRecord(movesOf(copyOf(d), copy), const {}), text);
    final back = decodeServiceRecord(text);
    expect(encodeServiceRecord(back.moves, const {}), text);
    // Ruling R13-a: today's 'jet_cad.service_layout'.
    expect(text, contains('"format":"jet_cad.service"'));
    expect(text, contains('"version":1'));
  });

  test('LC3 a text that is not a version-1 record is refused (S2, R13-a)', () {
    String record(String moves, {String format = 'jet_cad.service'}) =>
        '{"format":"$format","version":1,"moves":$moves,"groups":[]}';
    const ok = '[1,0,0,1,10.5,-3]';
    String entry(
            {String handle = '"2F"',
            String label = '"1"',
            String from = ok,
            String to = ok}) =>
        '{"handle":$handle,"label":$label,"from":$from,"to":$to}';
    expect(decodeServiceRecord(record('[${entry()}]')).moves, hasLength(1));
    expect(
        decodeServiceRecord(record('[${entry(label: 'null')}]'))
            .moves
            .single
            .label,
        isNull);
    for (final bad in [
      'not json',
      '[]',
      record('[]', format: 'other'),
      '{"format":"jet_cad.service","version":2,"moves":[],"groups":[]}',
      record('{}'),
      record('[3]'),
      record('[${entry(handle: '"XYZ"')}]'),
      record('[${entry(handle: '47')}]'),
      record('[${entry(label: '5')}]'),
      record('[${entry(from: '[1,0,0,1,10]')}]'),
      record('[${entry(to: '[1,0,0,1,10,"x"]')}]'),
      record('[${entry()},${entry(label: '"2"')}]'),
    ]) {
      expect(() => decodeServiceRecord(bad), throwsFormatException,
          reason: bad);
    }
  });

  test('LC4 `1` and `1.0` read alike (V-21, R13-a)', () {
    final a = decodeServiceRecord('{"format":"jet_cad.service",'
        '"version":1,"moves":[{"handle":"A","label":null,'
        '"from":[1,0,0,1,2,3],"to":[1,0,0,1,4,5]}],"groups":[]}');
    final b = decodeServiceRecord('{"format":"jet_cad.service",'
        '"version":1,"moves":[{"handle":"A","label":null,'
        '"from":[1.0,0.0,0.0,1.0,2.0,3.0],"to":[1.0,0.0,0.0,1.0,4.0,5.0]}],'
        '"groups":[]}');
    expect(parts(a.moves.single.to), parts(b.moves.single.to));
    expect(sameTransform(a.moves.single.from, b.moves.single.from), isTrue);
  });

  test(
      'LC6 an unlabelled unit moved is listed with a null label and '
      'applied by the match (S1, S2, review F-3)', () {
    final d = design();
    final spare = table(d, '2');
    d.commands.execute(SetEntityTextCommand(
        labelEntityOf(d, spare.handle)!, '', kUnitLabelTag));
    expect(unitsOf(d).units.where((u) => u.text == null), hasLength(1),
        reason: 'premise: one unlabelled unit');
    final copy = copyOf(d);
    final node = copy.tree[spare.handle]! as InstanceNode;
    copy.commands.execute(TransformNodeCommand(node.handle,
        Transform2.translation(-310.375, 58.25).multiply(node.transform)));
    final entries =
        decodeServiceRecord(encodeServiceRecord(movesOf(d, copy), const {}))
            .moves;
    expect([for (final e in entries) e.label], [null]);
    expect(entries.single.handle, spare.handle);
    final m = matchServiceMoves(d, unitsOf(d), entries);
    expect([for (final e in m.applied) e.label], [null]);
    expect(m.dropped, isEmpty);
  });

  group('LC5 the strict match (S2, M-14d-l)', () {
    late DraftDocument d;
    late List<ServiceMove> entries;
    setUp(() {
      d = design();
      entries = decodeServiceRecord(
              encodeServiceRecord(movesOf(d, movedCopy(d)), const {}))
          .moves;
    });
    List<String?> dropped() => [
          for (final e in matchServiceMoves(d, unitsOf(d), entries).dropped)
            e.label
        ];

    test('an unchanged design applies every entry', () {
      final m = matchServiceMoves(d, unitsOf(d), entries);
      expect([for (final e in m.applied) e.label], ['1', '2', '3', '4']);
      expect(m.dropped, isEmpty);
    });

    test('a unit moved in the design since is dropped', () {
      moveIn(d, '2', 0.5, 0);
      expect(dropped(), ['2']);
    });

    test('a unit relabelled in the design since is dropped', () {
      d.commands.execute(SetEntityTextCommand(
          labelEntityOf(d, table(d, '3').handle)!, '9', kUnitLabelTag));
      expect(dropped(), ['3']);
    });

    test('a unit locked or hidden in the design since is dropped', () {
      final layer = d.tables.layers[table(d, '4').layer]!;
      d.commands.execute(SetLayerCommand(layer.copyWith(locked: true)));
      expect(dropped(), ['4']);
      d.commands.execute(
          SetLayerCommand(layer.copyWith(locked: false, visible: false)));
      expect(dropped(), ['4']);
    });

    test(
        'an entry for a missing node, a non-unit, or another unit with the '
        'label of the first is dropped', () {
      final first = entries.first;
      final units = unitsOf(d);
      final planter = d.tree.nodes
          .whereType<InstanceNode>()
          .where((n) => units[n.handle] == null)
          .single
          .handle;
      entries = [
        for (final h in [
          Handle(d.handleSeed.current.value + 50),
          planter,
          table(d, '2').handle,
        ])
          ServiceMove(
              handle: h, label: first.label, from: first.from, to: first.to),
      ];
      expect(matchServiceMoves(d, unitsOf(d), entries).applied, isEmpty);
    });

    test(
        'an entry that turns the unit, shears it in one term, or holds a '
        'NaN or an infinity, is dropped (review F-5)', () {
      final e = entries.first;
      final t = e.to;
      for (final to in [
        Transform2.rotation(0.25).multiply(t),
        Transform2(t.a, t.b + 0.25, t.c, t.d, t.e, t.f),
        Transform2(t.a, t.b, t.c, t.d, double.nan, t.f),
        Transform2(t.a, t.b, t.c, t.d, t.e, double.infinity),
      ]) {
        final one = [
          ServiceMove(handle: e.handle, label: e.label, from: e.from, to: to)
        ];
        expect(matchServiceMoves(d, unitsOf(d), one).applied, isEmpty,
            reason: '$to');
      }
      expect(matchServiceMoves(d, unitsOf(d), [e]).applied, hasLength(1),
          reason: 'premise: the entry itself applies');
    });
  });

  test(
      'SR-codec-shapes the groups: a list of objects with a string id, a list '
      'of string members and a string or null label; anything else is a '
      'FormatException; a group the validation would refuse decodes as '
      'written', () {
    String record(String groups) =>
        '{"format":"jet_cad.service","version":1,"moves":[],"groups":$groups}';
    final ok = decodeServiceRecord(record(
        '[{"id":" ","members":[],"label":null},{"id":"g1","members":["1"," 1 "]}]'));
    expect([for (final g in ok.groups) g.id], [' ', 'g1']);
    expect(ok.groups.last.members, ['1', ' 1 ']);
    expect(ok.groups.last.label, isNull);
    for (final bad in [
      // M-SR19: `groups` missing read as none.
      '{"format":"jet_cad.service","version":1,"moves":[]}',
      record('{}'),
      record('[3]'),
      record('[{"members":["1"]}]'),
      record('[{"id":3,"members":["1"]}]'),
      record('[{"id":"g","members":"1"}]'),
      record('[{"id":"g","members":[1]}]'),
      record('[{"id":"g","members":["1"],"label":5}]'),
    ]) {
      expect(() => decodeServiceRecord(bad), throwsFormatException,
          reason: bad);
    }
  });
}
```

- [ ] **Step 2: Port the controller's record tests.** Create `test/controller/service_record_controller_test.dart` from `jet_cad_floor_plan/test/host/controller_test.dart` — C2 (`:95-141`), C10 (`:251-283`), C14 (`:358-387`), C16 (`:412-445`), C17 (`:447-468`), C18 (`:470-495`), C20 (`:497-516`), C19 (`:518-546`), CF3 (`:733-756`), CF4 (`:758-798`) — and from `test/host/table_groups_controller_test.dart` — TG-C10 (`:344-361`), TG-C11 (`:363-401`): 12 tests, **assertions unchanged** but for rulings R13-a (C16, C20), R13-c (TG-C10) and R13-d (TG-C11). Ids: `SR-C2`, `SR-C10`, `SR-C14`, `SR-C16` … `SR-C20`, `SR-CF3`, `SR-CF4`; TG-C10, TG-C11 keep theirs. Adaptations:
  - `FloorPlanController(json:)` and `controller(tester, json)` → `controllerFor(kits: [testKit()], json:)`; `planJson()` and `zonePlanJson()` → `servicePlanText()`; `groupsPlanJson()` → `groupsPlanText()`; `zoned(tester)` → that controller with `c.camera.value = ViewportTransform(worldToScreenMatrix: const Transform2(0.0375, 0, 0, -0.0375, 612.5, 431.25))`;
  - `tableNode` → `unitNode`; `designJson()` → `save()`; `FloorPlanMode.selection` → `PlanMode.service`; `selectedTables` → `selectedUnits`; `setTableFocus`/`tableFocus` → `setUnitFocus`/`unitFocus`; `setTableGroups`/`tableGroups` → `setUnitGroups`/`unitGroups`; `setGroupStatus` unchanged; `group(…)` → `UnitGroup(members: …, label: …)`; `TableStatus` → `UnitStatus`; R13-b's renames;
  - C10's `AddLayerCommand(LayerRecord(… 'Locked' …))` → `addLayer(doc, 'Locked', visible: true, locked: true)`;
  - SR-C16: `expect(jsonDecode(c.serviceJson()!)['moves'], isEmpty);` (R13-a);
  - SR-C20: `expect(saved.last, contains('"moves":[{'), reason: 'premise: a move');` and `expect(saved.last, contains('"moves":[]'));` (R13-a);
  - TG-C10's last line: `expect(c.serviceEdited, isTrue, reason: 'ruling R13-c: groups count (spec S3, S5)');`;
  - TG-C11: lines `:388-391` (the `resetLayout` step and its three expectations) are not ported (R13-d), the rest as written;
  - imports: `dart:convert`, `dart:ui show Color`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart show ViewportTransform`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_plan/src/service/service_record.dart`, `../support/harness.dart show controllerFor`, `../support/service_plans.dart`, `../support/test_kit.dart show testKit, unitKit`.

- [ ] **Step 3: Write the failing tests (new).** Append to `test/controller/service_record_controller_test.dart`, with these helpers at the top of the file:

```dart
/// A version-1 record of [moves] and [groups], as a host would store one.
String record(
        {List<Map<String, Object?>> moves = const [],
        List<Map<String, Object?>> groups = const []}) =>
    jsonEncode({
      'format': 'jet_cad.service',
      'version': 1,
      'moves': moves,
      'groups': groups,
    });

/// A record's move of [node] (labelled [label]) by ([dx], [dy]).
Map<String, Object?> moveOf(
        InstanceNode node, String? label, double dx, double dy) =>
    {
      'handle': node.handle.toHex(),
      'label': label,
      'from': node.transform.toJson(),
      'to': Transform2.translation(dx, dy).multiply(node.transform).toJson(),
    };

/// A record's group.
Map<String, Object?> groupOf(String id, List<String> members,
        [String? label]) =>
    {'id': id, 'members': members, 'label': label};
```

```dart
  testWidgets(
      'SR-roundtrip moves and groups saved, then restored into a fresh copy: '
      'every move and group applied, the host\'s groups replaced by the '
      'record\'s in its order, and the record written again byte for byte',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '3', -125.125, 400.75);
    move(c, '1', 750.25, -250.5);
    c.setUnitGroups({
      'g2': UnitGroup(members: {'3', '2'}, label: 'Smith'),
      'g1': UnitGroup(members: {'1'}),
    });
    final json = c.serviceJson()!;
    final decoded = jsonDecode(json) as Map<String, Object?>;
    expect(decoded['format'], 'jet_cad.service');
    expect(decoded['version'], 1);
    expect([for (final m in decoded['moves']! as List) (m as Map)['label']],
        ['1', '3'],
        reason: 'ascending by handle');
    // M-SR1: the encoding drops a group's label.
    expect(decoded['groups'], [
      {
        'id': 'g2',
        'members': ['3', '2'],
        'label': 'Smith'
      },
      {
        'id': 'g1',
        'members': ['1'],
        'label': null
      },
    ]);
    final want1 = parts(unitNode(c.activeDocument, '1').transform);
    final want3 = parts(unitNode(c.activeDocument, '3').transform);
    c.setMode(PlanMode.design);
    c.setUnitGroups({
      'gX': UnitGroup(members: {'2'})
    });
    c.setMode(PlanMode.service);
    final r = c.restoreService(json);
    expect(r.appliedMoves, ['1', '3']);
    expect(r.droppedMoves, isEmpty);
    expect(r.appliedGroups, ['g2', 'g1']);
    expect(r.droppedGroups, isEmpty);
    expect(c.unitGroups.value.keys, ['g2', 'g1']);
    expect(c.unitGroups.value['g2'], UnitGroup(members: {'3', '2'}, label: 'Smith'));
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(parts(unitNode(c.activeDocument, '3').transform), want3);
    expect(c.serviceJson(), json, reason: 'byte for byte');
    await tester.pump();
  });

  testWidgets(
      'SR-design-edited (Review Focus 2) a record saved, the design edited '
      '(table 2 relabelled 9), the record restored: the unchanged table\'s '
      'move applies, the relabelled one\'s drops, a group naming the old '
      'label drops whole and is reported, the copy\'s history is cleared',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '1', 750.25, -250.5);
    move(c, '2', -125.125, 400.75);
    c.setUnitGroups({
      'g1': UnitGroup(members: {'2', '3'}),
      'g2': UnitGroup(members: {'1'}),
    });
    final json = c.serviceJson()!;
    final want1 = parts(unitNode(c.activeDocument, '1').transform);
    c.setMode(PlanMode.design);
    final two = unitNode(c.document, '2');
    c.document.commands.execute(SetEntityTextCommand(
        labelEntityOf(c.document, two.handle)!, '9', kUnitLabelTag));
    c.setMode(PlanMode.service);
    move(c, '3', 15.5, 15.5);
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: a service step');
    final r = c.restoreService(json);
    // M-SR7: the strict match ignores the label.
    expect(r.appliedMoves, ['1']);
    expect(r.droppedMoves, ['2']);
    // M-SR8: a group whose label names no unit is applied.
    expect(r.appliedGroups, ['g2']);
    expect(r.droppedGroups, ['g1']);
    expect(c.unitGroups.value.keys, ['g2']);
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(parts(unitNode(c.activeDocument, '9').transform),
        parts(two.transform),
        reason: 'the relabelled table at its design place');
    expect(parts(unitNode(c.activeDocument, '3').transform),
        parts(unitNode(c.document, '3').transform),
        reason: 'a new copy: the move of 3 is gone');
    // M-SR9: the restore's command is left in the copy's history.
    expect(c.canUndo.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'SR-groups-replaced restoreService replaces the groups a host set in '
      'design with the record\'s; a record with none clears them',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'gX': UnitGroup(members: {'2', '3'})
    });
    c.setMode(PlanMode.service);
    final r = c.restoreService(record(groups: [
      groupOf('g1', ['1'])
    ]));
    // M-SR3: the record's groups merged into the host's.
    expect(c.unitGroups.value.keys, ['g1']);
    expect(r.appliedGroups, ['g1']);
    final none = c.restoreService(record());
    expect(c.unitGroups.value, isEmpty);
    expect(none.appliedGroups, isEmpty);
    expect(none.droppedGroups, isEmpty);
    await tester.pump();
  });

  testWidgets(
      'SR-invalid-groups groups breaking the validation are dropped and '
      'reported, never a FormatException: a blank id, an id equal after '
      'trimming, an empty group, a label already in a group, a label naming '
      'no unit (dropped whole); a shared label is kept', (tester) async {
    final c = controllerFor(
        kits: [testKit()], json: servicePlanText(duplicate: true));
    c.setMode(PlanMode.service);
    late ServiceRestore r;
    // M-SR4: the restore validates the groups with validateUnitGroups.
    expect(
        () => r = c.restoreService(record(groups: [
              groupOf('', ['1']),
              groupOf('g1', ['1']),
              groupOf(' g1 ', ['2']),
              groupOf('g2', [' ', '']),
              groupOf('g3', ['1', '2']),
              groupOf('g5', ['2', '99']),
              groupOf('g4', ['2'], 'Pair'),
            ])),
        returnsNormally);
    // M-SR5: a member naming no unit is dropped from its group instead.
    expect(r.appliedGroups, ['g1', 'g4']);
    expect(r.droppedGroups, ['', 'g1', 'g2', 'g3', 'g5']);
    expect(c.unitGroups.value, {
      'g1': UnitGroup(members: {'1'}),
      'g4': UnitGroup(members: {'2'}, label: 'Pair'),
    });
    expect(c.selectableMembers('g4'), {'2'},
        reason: 'the label two units share');
    await tester.pump();
  });

  testWidgets(
      'SR-locked-move-dropped a move of a locked unit (a missing kit\'s '
      'table) and a move of a seat are dropped; the unlocked table\'s '
      'applies', (tester) async {
    final c = controllerFor(kits: [testKit()], json: lockedPlanText());
    final one = unitNode(c.document, '1');
    final five = unitNode(c.document, '5');
    final moves = [
      moveOf(one, '1', 410.5, -95.25),
      moveOf(five, '5', 120.25, 33.5),
    ];
    // M-SR10: the strict match ignores isLockedUnit.
    final m = matchServiceMoves(
        c.document, c.unitIndex, decodeServiceRecord(record(moves: moves)).moves);
    expect([for (final e in m.applied) e.label], ['1']);
    expect([for (final e in m.dropped) e.label], ['5']);
    c.setMode(PlanMode.service);
    final r = c.restoreService(record(moves: moves));
    expect(r.appliedMoves, ['1']);
    expect(r.droppedMoves, ['5']);
    expect(parts(unitNode(c.activeDocument, '5').transform),
        parts(five.transform));

    final h = hall();
    final c2 = controllerFor(kits: [unitKit()], json: h.json);
    final seat = c2.document.tree[h.seats[0][0]]! as InstanceNode;
    final label = labelOf(c2.document, seat.handle);
    c2.setMode(PlanMode.service);
    // M-SR11: the strict match lets a generated unit move.
    final r2 = c2.restoreService(record(moves: [moveOf(seat, label, 300.5, 0)]));
    expect(r2.appliedMoves, isEmpty);
    expect(r2.droppedMoves, [label], reason: 'only placed units move');
    await tester.pump();
  });

  testWidgets(
      'SR-old-format-refused today\'s jet_cad.service_layout text, and that '
      'format with the new keys, are FormatExceptions; nothing changes',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    c.setMode(PlanMode.service);
    move(c, '1', 44.5, 0);
    await tester.pump();
    final copy = c.activeDocument;
    final revision = c.revision.value;
    final groups = c.unitGroups.value;
    final one = unitNode(c.document, '1');
    final today = jsonEncode({
      'format': 'jet_cad.service_layout',
      'version': 1,
      'tables': [
        {
          'handle': one.handle.toHex(),
          'number': '1',
          'from': one.transform.toJson(),
          'to': Transform2.translation(44.5, 0).multiply(one.transform).toJson(),
        }
      ],
    });
    final disguised = jsonEncode({
      'format': 'jet_cad.service_layout',
      'version': 1,
      'moves': [],
      'groups': [],
    });
    // M-SR12: the format is not checked.
    for (final text in [today, disguised]) {
      expect(() => c.restoreService(text), throwsFormatException,
          reason: text);
      expect(c.activeDocument, same(copy));
      expect(c.revision.value, revision);
      expect(c.unitGroups.value, same(groups));
      expect(c.serviceEdited, isTrue, reason: 'the move is kept');
    }
  });

  testWidgets(
      'SR-edited-after-enter serviceEdited compares the groups with those '
      'held on entering: false right after entering with groups set in '
      'design, true once they differ, false again when they are equal',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    c.setMode(PlanMode.service);
    // M-SR13: entering service does not take the groups held then.
    expect(c.serviceEdited, isFalse, reason: 'groups set in design, no move');
    c.setUnitGroups({
      'g': UnitGroup(members: {'2', '1'})
    });
    expect(c.serviceEdited, isFalse, reason: 'equal groups');
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    expect(c.serviceEdited, isTrue);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    expect(c.serviceEdited, isFalse);
    c.setMode(PlanMode.design);
    expect(c.serviceEdited, isFalse, reason: 'design');
    c.setUnitGroups(const {});
    c.setMode(PlanMode.service);
    expect(c.serviceEdited, isFalse, reason: 'the groups held on entering');
    await tester.pump();
  });

  testWidgets(
      'SR-reset resetService rebuilds the copy and clears the groups in '
      'service; in design it is a silent no-op', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    var heard = 0;
    c.serviceChanges.addListener(() => heard++);
    final revision = c.revision.value;
    // M-SR15: resetService clears the groups in design.
    c.resetService();
    expect(c.unitGroups.value.keys, ['g']);
    expect(heard, 0);
    expect(c.revision.value, revision);
    c.setMode(PlanMode.service);
    move(c, '1', 600, 0);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '3'})
    });
    await tester.pump();
    heard = 0;
    final copy = c.activeDocument;
    c.resetService();
    // M-SR16: resetService keeps the groups (today's resetLayout).
    expect(c.unitGroups.value, isEmpty);
    expect(c.activeDocument, isNot(same(copy)));
    expect(parts(unitNode(c.activeDocument, '1').transform),
        parts(unitNode(c.document, '1').transform));
    expect(c.serviceEdited, isFalse);
    expect(heard, 1);
    await tester.pump();
  });

  testWidgets(
      'SR-changes-timing setUnitGroups fires serviceChanges in service only; '
      'statuses, group statuses and the focus never; nor setMode, load or '
      'newPlan', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    var heard = 0, groups = 0;
    c.serviceChanges.addListener(() => heard++);
    c.unitGroups.addListener(() => groups++);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    // M-SR17: setUnitGroups fires serviceChanges in design too.
    expect((heard, groups), (0, 1));
    c.setMode(PlanMode.service);
    expect(heard, 0, reason: 'never on setMode');
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    // M-SR18: setUnitGroups does not fire serviceChanges.
    expect((heard, groups), (1, 2));
    c.setUnitStatus({'1': bill});
    c.setGroupStatus({'g': bill});
    c.setUnitFocus({'1'});
    expect(heard, 1, reason: 'not in the record');
    expect(
        () => c.setUnitGroups({
              '': UnitGroup(members: {'1'})
            }),
        throwsArgumentError);
    expect(heard, 1, reason: 'a refused set fires nothing');
    c.load(servicePlanText());
    expect(heard, 1, reason: 'never on load');
    c.newPlan();
    expect(heard, 1, reason: 'never on newPlan');
    c.setMode(PlanMode.design);
    await tester.pump();
    expect(heard, 1);
  });
```

- [ ] **Step 4: Run the tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_record_test.dart test/controller/service_record_controller_test.dart`. Expected: compilation errors, `Target of URI doesn't exist: 'package:jet_cad_2d_plan/src/service/service_record.dart'` and `The method 'serviceJson' isn't defined for the type 'PlanController'`.

- [ ] **Step 5: The record.** Create `lib/src/service/service_record.dart`:

```dart
// The service record (spec 2b S3 "The service record", decision 4): the
// moves the service copy made and the host's groups, as a small JSON a
// host stores apart from the design, and the strict match that decides
// which of a stored record's moves and groups still apply to the design.
// Ported from jet_cad_floor_plan's lib/src/host/service_layout.dart (the
// whole file), keyed by label, with groups added; today's
// `jet_cad.service_layout` text is refused (no compatibility, spec S5).
import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../units/unit_index.dart';
import 'service_state.dart';

/// The record's `format` value.
const String kServiceFormat = 'jet_cad.service';

/// The record's `version` value.
const int kServiceVersion = 1;

/// One moved unit: its instance, its label when it had one, its transform
/// in the design ([from]) and in the copy ([to]).
final class ServiceMove {
  const ServiceMove(
      {required this.handle,
      required this.label,
      required this.from,
      required this.to});

  final Handle handle;
  final String? label;
  final Transform2 from;
  final Transform2 to;

  @override
  String toString() => 'ServiceMove(${handle.toHex()}, $label)';
}

/// One group as a record holds it, before any check: its id, its members
/// and its label as written.
final class RecordGroup {
  const RecordGroup(
      {required this.id, required this.members, required this.label});

  final String id;
  final List<String> members;
  final String? label;
}

/// A decoded record.
final class ServiceRecord {
  const ServiceRecord({required this.moves, required this.groups});

  final List<ServiceMove> moves;
  final List<RecordGroup> groups;
}

/// Whether [a] and [b] are the same stored value: `Transform2` has no
/// `==` on purpose, and a record compares stored transforms exactly.
bool sameTransform(Transform2 a, Transform2 b) =>
    a.a == b.a &&
    a.b == b.b &&
    a.c == b.c &&
    a.d == b.d &&
    a.e == b.e &&
    a.f == b.f;

/// The placed units of [copy] (as [copyUnits] lists them) whose transform
/// differs from the same instance's in [design], ascending by handle.
/// Generated units never move alone, so none is listed.
List<ServiceMove> serviceMovesOf(
    DraftDocument design, DraftDocument copy, UnitIndex copyUnits) {
  final out = <ServiceMove>[];
  for (final u in copyUnits.units) {
    if (u.generated) continue;
    final moved = copy.tree[u.instance];
    final designed = design.tree[u.instance];
    if (moved is! InstanceNode || designed is! InstanceNode) continue;
    if (sameTransform(moved.transform, designed.transform)) continue;
    out.add(ServiceMove(
        handle: u.instance,
        label: u.text,
        from: designed.transform,
        to: moved.transform));
  }
  return out;
}

/// [moves] and [groups] as the record's JSON, in the given orders.
String encodeServiceRecord(
        List<ServiceMove> moves, Map<String, UnitGroup> groups) =>
    jsonEncode({
      'format': kServiceFormat,
      'version': kServiceVersion,
      'moves': [
        for (final m in moves)
          {
            'handle': m.handle.toHex(),
            'label': m.label,
            'from': m.from.toJson(),
            'to': m.to.toJson(),
          }
      ],
      'groups': [
        for (final MapEntry(key: id, value: g) in groups.entries)
          {
            'id': id,
            'members': [...g.members],
            'label': g.label,
          }
      ],
    });

/// The record [text]. Throws a [FormatException] unless it is a version-1
/// `jet_cad.service` record: its moves as today's layout entries (a
/// hexadecimal handle, a string or null label, six numbers in each of
/// `from` and `to`, no handle twice), its groups objects with a string
/// `id`, a list of string `members` and a string or null `label`. Values
/// are not checked for finiteness, nor groups against the validation:
/// [matchServiceMoves] and [matchServiceGroups] drop such entries.
ServiceRecord decodeServiceRecord(String text) {
  Never bad(String why) => throw FormatException('Not a service record: $why');
  final Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    bad(e.message);
  }
  if (json is! Map<String, Object?>) bad('not an object');
  if (json['format'] != kServiceFormat) bad('format');
  if (json['version'] != kServiceVersion) bad('version');
  final moves = json['moves'];
  if (moves is! List<Object?>) bad('moves');
  final groups = json['groups'];
  if (groups is! List<Object?>) bad('groups');
  Transform2 transform(Object? v, String name) {
    if (v is! List<Object?> || v.length != 6 || v.any((x) => x is! num)) {
      bad(name);
    }
    // The web writes `1` where the VM writes `1.0` (V-21).
    final d = [for (final x in v) (x! as num).toDouble()];
    return Transform2(d[0], d[1], d[2], d[3], d[4], d[5]);
  }

  final seen = <Handle>{};
  final outMoves = <ServiceMove>[];
  for (final m in moves) {
    if (m is! Map<String, Object?>) bad('a move');
    final hex = m['handle'];
    if (hex is! String) bad('a handle');
    final Handle handle;
    try {
      handle = Handle.parseHex(hex);
    } on HandleRangeError {
      bad('a handle');
    }
    if (!seen.add(handle)) bad('handle $hex twice');
    final label = m['label'];
    if (label != null && label is! String) bad('a label');
    outMoves.add(ServiceMove(
        handle: handle,
        label: label as String?,
        from: transform(m['from'], 'from'),
        to: transform(m['to'], 'to')));
  }
  final outGroups = <RecordGroup>[];
  for (final g in groups) {
    if (g is! Map<String, Object?>) bad('a group');
    final id = g['id'];
    if (id is! String) bad('a group id');
    final members = g['members'];
    if (members is! List<Object?> || members.any((m) => m is! String)) {
      bad('a group\'s members');
    }
    final label = g['label'];
    if (label != null && label is! String) bad('a group label');
    outGroups.add(RecordGroup(
        id: id,
        members: List.unmodifiable(members.cast<String>()),
        label: label as String?));
  }
  return ServiceRecord(
      moves: List.unmodifiable(outMoves), groups: List.unmodifiable(outGroups));
}

/// The moves of a record that apply to a design, and those dropped.
typedef ServiceMoveMatch = ({
  List<ServiceMove> applied,
  List<ServiceMove> dropped,
});

/// Splits [moves] by the strict match against [design] (spec S3): a move
/// applies iff its handle is a placed unit of [designUnits] that no lock
/// covers (`isLockedUnit`), on a visible, unlocked layer (a missing layer
/// counts as visible), carrying the same label, at exactly
/// [ServiceMove.from], and [ServiceMove.to] only translates it (the same
/// linear part) with every value finite.
ServiceMoveMatch matchServiceMoves(
    DraftDocument design, UnitIndex designUnits, List<ServiceMove> moves) {
  final applied = <ServiceMove>[];
  final dropped = <ServiceMove>[];
  for (final e in moves) {
    final unit = designUnits[e.handle];
    final node = design.tree[e.handle];
    final layer =
        node is InstanceNode ? design.tables.layers[node.layer] : null;
    final ok = unit != null &&
        !unit.generated &&
        !unit.locked &&
        node is InstanceNode &&
        (layer == null || (layer.visible && !layer.locked)) &&
        unit.text == e.label &&
        sameTransform(node.transform, e.from) &&
        _finite(e.from) &&
        _finite(e.to) &&
        e.to.a == e.from.a &&
        e.to.b == e.from.b &&
        e.to.c == e.from.c &&
        e.to.d == e.from.d;
    (ok ? applied : dropped).add(e);
  }
  return (applied: applied, dropped: dropped);
}

bool _finite(Transform2 t) =>
    t.a.isFinite &&
    t.b.isFinite &&
    t.c.isFinite &&
    t.d.isFinite &&
    t.e.isFinite &&
    t.f.isFinite;

/// The groups of a record that apply, and the ids applied and dropped.
typedef ServiceGroupMatch = ({
  Map<String, UnitGroup> applied,
  List<String> appliedIds,
  List<String> droppedIds,
});

/// Applies [groups] in record order, each whole or not at all (spec S3):
/// a group is dropped when its trimmed id is blank or that of a group
/// applied before it, when it has no member after trimming, when a member
/// names no unit of [designUnits] (any unit carrying the label), or when a
/// member is in a group applied before it. The ids are trimmed.
ServiceGroupMatch matchServiceGroups(
    List<RecordGroup> groups, UnitIndex designUnits) {
  final applied = <String, UnitGroup>{};
  final owner = <String, String>{};
  final appliedIds = <String>[];
  final droppedIds = <String>[];
  for (final r in groups) {
    final id = r.id.trim();
    final group = UnitGroup(members: r.members.toSet(), label: r.label);
    final ok = id.isNotEmpty &&
        !applied.containsKey(id) &&
        group.members.isNotEmpty &&
        group.members.every((m) => designUnits.withLabel(m).isNotEmpty) &&
        group.members.every((m) => !owner.containsKey(m));
    if (!ok) {
      droppedIds.add(id);
      continue;
    }
    applied[id] = group;
    appliedIds.add(id);
    for (final m in group.members) {
      owner[m] = id;
    }
  }
  return (
    applied: Map.unmodifiable(applied),
    appliedIds: appliedIds,
    droppedIds: droppedIds,
  );
}

/// What `PlanController.restoreService` did (spec S3): the labels of the
/// moves it applied and dropped, in record order (an unlabelled unit's is
/// null, so a label may repeat and the lengths are the counts), and the
/// ids of the groups it applied and dropped, in record order.
@immutable
final class ServiceRestore {
  ServiceRestore(
      {required List<String?> appliedMoves,
      required List<String?> droppedMoves,
      required List<String> appliedGroups,
      required List<String> droppedGroups})
      : appliedMoves = List.unmodifiable(appliedMoves),
        droppedMoves = List.unmodifiable(droppedMoves),
        appliedGroups = List.unmodifiable(appliedGroups),
        droppedGroups = List.unmodifiable(droppedGroups);

  final List<String?> appliedMoves, droppedMoves;
  final List<String> appliedGroups, droppedGroups;

  @override
  String toString() => 'ServiceRestore(moves: $appliedMoves, dropped '
      '$droppedMoves; groups: $appliedGroups, dropped $droppedGroups)';
}
```

- [ ] **Step 6: The controller.** In `lib/src/controller/plan_controller.dart`, import `'../service/service_record.dart'`, then:
  1. Add the section (today's `floor_plan_controller.dart:1092-1164`, `:1288-1303`, `:1425-1436`):

```dart
  // ---------------------------------------------------------------------
  // The service record (spec 2b S3, decision 4).

  final _Requests _serviceChanges = _Requests();

  /// The active copy's history state last announced on [serviceChanges]:
  /// an undo is announced at once and again by the change stream, which is
  /// heard once.
  int? _announced;

  /// The groups held when service was entered (or the copy rebuilt by a
  /// load or a new plan; none after a reset): what [serviceEdited]
  /// compares the groups with.
  Map<String, UnitGroup> _groupsAtEnter = const {};

  /// Whether service has something to record: the copy has a placed unit
  /// away from its design place, or the groups differ from those held when
  /// service was entered. Not the undo depth. Surveys the copy at each
  /// read: read it on a change, not per frame. False in design.
  bool get serviceEdited {
    final s = _service;
    if (s == null) return false;
    return serviceMovesOf(document, s.document, s.units.current).isNotEmpty ||
        !mapEquals(_groups.value, _groupsAtEnter);
  }

  /// Fires after a move, an undo or a redo of the copy (for [undo] and
  /// [redo], before they return), [resetService], [restoreService], and
  /// [setUnitGroups] in service. Never on [setMode], [load] or [newPlan],
  /// so a host that saves [serviceJson] on it never overwrites its record
  /// with the empty one a new copy starts with.
  Listenable get serviceChanges => _serviceChanges;

  /// The service record as JSON (spec S3): the placed units moved away
  /// from the design, ascending by handle, and the groups. Null in design.
  String? serviceJson() {
    settlePendingInput();
    final s = _service;
    if (s == null) return null;
    return encodeServiceRecord(
        serviceMovesOf(document, s.document, s.units.current), _groups.value);
  }

  /// Puts a stored record back (spec S3): service only (a [StateError] in
  /// design). A [json] that is not a version-1 `jet_cad.service` record
  /// throws a [FormatException] and changes nothing. Otherwise the copy is
  /// rebuilt from the design, every move of the strict match applied and
  /// the copy's history cleared (Undo does not remove them), and the
  /// groups **replaced** by the record's that apply, each whole or not at
  /// all. The focus is kept; the selection is selected again by label;
  /// [revision] moves; [serviceChanges] fires.
  ServiceRestore restoreService(String json) {
    final old = _service;
    if (old == null) {
      throw StateError('restoreService needs the service mode (spec 2b S3)');
    }
    final record = decodeServiceRecord(json);
    settlePendingInput();
    _refreshSelected();
    final labels = _selectedUnits.value;
    final designUnits = _session.units.current;
    final moves = matchServiceMoves(document, designUnits, record.moves);
    final groups = matchServiceGroups(record.groups, designUnits);
    final next = _buildService();
    if (moves.applied.isNotEmpty) {
      final commands = next.document.commands;
      try {
        commands.execute(CompoundCommand([
          for (final m in moves.applied) TransformNodeCommand(m.handle, m.to)
        ], label: 'Restore'));
      } catch (_) {
        next.dispose();
        rethrow;
      }
      // The restore is the copy's floor, no step (today's C16).
      commands.clearHistory();
    }
    _attachService(next);
    _service = next;
    _dropService(old);
    _groups.value = groups.applied;
    _select(labels);
    _refreshFlags();
    _revision.value++;
    _serviceChanges.bump();
    notifyListeners();
    return ServiceRestore(
        appliedMoves: [for (final m in moves.applied) m.label],
        droppedMoves: [for (final m in moves.dropped) m.label],
        appliedGroups: groups.appliedIds,
        droppedGroups: groups.droppedIds);
  }

  /// Service only: the copy rebuilt from the design, every service move
  /// gone, and the groups cleared (today's `resetLayout` kept them: spec
  /// S5). The selection is kept by label. A silent no-op in design.
  void resetService() {
    final old = _service;
    if (old == null) return;
    settlePendingInput();
    _refreshSelected();
    final labels = _selectedUnits.value;
    final next = _buildService();
    _attachService(next);
    _service = next;
    _dropService(old);
    _groups.value = const <String, UnitGroup>{};
    _groupsAtEnter = const <String, UnitGroup>{};
    _select(labels);
    _refreshFlags();
    _revision.value++;
    _serviceChanges.bump();
    notifyListeners();
  }

  /// Fires [serviceChanges] if the active copy's history moved since it
  /// last did. The change stream is asynchronous: without this, a host
  /// that calls [undo] and then [setMode] in one synchronous step would
  /// never hear the undo (review 14d-2).
  void _announceService() {
    final s = _service;
    if (s == null) return;
    final state = s.document.commands.stateId;
    if (state == _announced) return;
    _announced = state;
    _serviceChanges.bump();
  }
```

  2. Task 11's `_attachService` ends with `_announced = s.document.commands.stateId;`; Task 11's `_onServiceChanged` ends with `_announceService();`.
  3. `undo` and `redo` (Task 11's): after the `try`/`on` block, `_announceService();` (it returns at once in design).
  4. `setMode`: in the service branch, after `_service = copy;`, `_groupsAtEnter = _groups.value;`. `_replace`'s service branch (Task 11): after `_service = copy;`, `_groupsAtEnter = _groups.value;`.
  5. Task 12's `setUnitGroups`: after `_refreshSelectedGroup();`, `if (_service != null) _serviceChanges.bump();`; its doc gains: "In service it fires [serviceChanges] (the groups are in the record); in design it notifies [unitGroups] only."
  6. `dispose`: `_serviceChanges.dispose();` beside the other notifiers.

- [ ] **Step 7: Export.** In `lib/jet_cad_2d_plan.dart` add `export 'src/service/service_record.dart' show ServiceRestore;` (sorted). In `test/barrel_test.dart`, ED-9's set gains `// 2b Task 13` and `'ServiceRestore',`.

- [ ] **Step 8: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_record_test.dart test/controller/service_record_controller_test.dart test/barrel_test.dart`. Expected: `All tests passed!`. Then `flutter test`. Expected: `All tests passed!`.

- [ ] **Step 9: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. From the root, `git status --short`: only this task's files.

- [ ] **Step 10: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/service/service_record.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/barrel_test.dart packages/jet_cad_2d_plan/test/service/service_record_test.dart packages/jet_cad_2d_plan/test/controller/service_record_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the service record, jet_cad.service v1 (2b S3)

serviceJson writes the placed units the copy moved and the host's
groups; restoreService rebuilds the copy, applies the moves today's
strict match keeps (a locked or generated unit never moves), clears
the copy's history and replaces the groups with the record's that
still name units of the design, each whole or dropped and reported.
resetService also clears the groups; serviceEdited counts a groups
change since entering; serviceChanges also fires on setUnitGroups in
service. Today's jet_cad.service_layout text is refused.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Mutation check** (committed files only; after each: run the named test file, see the named test red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-SR1 `lib/src/service/service_record.dart`: in `encodeServiceRecord`, delete `'label': g.label,` → SR-roundtrip red.
  - M-SR3 `lib/src/controller/plan_controller.dart`: in `restoreService`, `_groups.value = groups.applied;` → `_groups.value = Map.unmodifiable({..._groups.value, ...groups.applied});` → SR-groups-replaced red.
  - M-SR4 `plan_controller.dart`: in `restoreService`, after `final groups = …;` insert `validateUnitGroups({for (final g in record.groups) g.id: UnitGroup(members: g.members.toSet(), label: g.label)});` → SR-invalid-groups red (an `ArgumentError`).
  - M-SR5 `service_record.dart`: in `matchServiceGroups`, the group built from `r.members.where((m) => designUnits.withLabel(m.trim()).isNotEmpty).toSet()` and the `every((m) => designUnits.withLabel(m).isNotEmpty)` clause deleted → SR-invalid-groups red (`g5` applied as `{'2'}`, `g4` dropped).
  - M-SR7 `service_record.dart`: in `matchServiceMoves`, delete `unit.text == e.label &&` → SR-design-edited red (`appliedMoves` `['1', '2']`).
  - M-SR8 `service_record.dart`: delete `group.members.every((m) => designUnits.withLabel(m).isNotEmpty) &&` → SR-design-edited red (`g1` applied).
  - M-SR9 `plan_controller.dart`: delete `commands.clearHistory();` in `restoreService` → SR-design-edited red (`canUndo` true); SR-C16 red too.
  - M-SR10 `service_record.dart`: delete `!unit.locked &&` → SR-locked-move-dropped red (the codec-level match applies 5).
  - M-SR11 `service_record.dart`: delete `!unit.generated &&` → SR-locked-move-dropped red (the copy refuses the seat's move: an exception out of `restoreService`).
  - M-SR12 `service_record.dart`: delete `if (json['format'] != kServiceFormat) bad('format');` → SR-old-format-refused red (the disguised text accepted).
  - M-SR13 `plan_controller.dart`: delete `setMode`'s `_groupsAtEnter = _groups.value;` → SR-edited-after-enter red.
  - M-SR15 `plan_controller.dart`: `resetService`'s `if (old == null) return;` → `if (old == null) { _groups.value = const <String, UnitGroup>{}; return; }` → SR-reset red.
  - M-SR16 `plan_controller.dart`: delete `resetService`'s `_groups.value = const <String, UnitGroup>{};` → SR-reset red.
  - M-SR17 `plan_controller.dart`: `if (_service != null) _serviceChanges.bump();` in `setUnitGroups` → `_serviceChanges.bump();` → SR-changes-timing red.
  - M-SR18 `plan_controller.dart`: delete that line → SR-changes-timing red.
  - M-SR19 `service_record.dart`: `final groups = json['groups'];` → `final groups = json['groups'] ?? const <Object?>[];` → SR-codec-shapes red.
  - M-SR20 `plan_controller.dart`: delete `undo`'s `_announceService();` → SR-C20 red (heard after the switch, not before).

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 11: `_buildService()` returns a session with its systems installed and nothing listening; `_attachService(s)` subscribes to its changes and selection; `_dropService(s)` detaches now and disposes after the frame; `_onServiceChanged()`; `setMode` and `_replace` assign `_service`; `undo`/`redo` act on the active document; the support file's helpers named in Interfaces.
- Task 12: `_groups` (`ValueNotifier<Map<String, UnitGroup>>`), `setUnitGroups` ending with `_refreshSelectedGroup()`, `selectableMembers`; the support's `groupsPlanText`, `bill`.
- Task 9: `_selectedUnits`, `_revision`; Task 11: `selectedUnits` (over Task 9's `_selectedUnits`).
- Task 6: `DocumentSession.units` (`UnitIndexCache`), `PlanController.unitIndex` (`@internal`), `UnitIndex.of(document, {catalog, locks})`, `withLabel` returning every unit carrying the (trimmed) label, hidden and locked ones included.
- Task 5: `unitKit()`; `hall()` (Task 11) over `serviceFixture()`.
- 2a: `planDocument`, `catalogOf`, `registerPlanComponents`, `controllerFor` (`test/support/harness.dart`); `LockSet.scan` (`lib/src/kits/locks.dart:39-63`).

---

