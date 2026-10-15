### Task 7: The label system, the placed unit's number, rotation (spec S2 "The label" placed rules, "The label system"; S4 "The unit inspector" ±90 buttons' command)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_label_system.dart`, `packages/jet_cad_2d_plan/lib/src/units/unit_rotate.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (the stack: parametric → labels → lock; disposal in reverse), `packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart` (`placeSymbol(units:)`), `packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart` (`units`), `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (passes the session's index to plan.symbol)
- Test: `packages/jet_cad_2d_plan/test/units/unit_label_system_test.dart`, `unit_placement_test.dart`, `unit_data_delete_test.dart`, `unit_rotate_test.dart` (ported), `unit_label_stack_test.dart` (new)

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `CommandDispatcher.expander` (`undo.dart:187-203`), `DraftCommand`, `CommandResult`, `CompoundCommand`, `ParametricReplay(CompoundCommand, Set<Capability>)` (`parametric_system.dart:912-935`), `SetEntityGeometryCommand`, `TransformNodeCommand`, `GeometryPayload`.
  - Kit (Task 3): `kUnitLabelMaxHeight`, `unitLabelStamp(Transform2)`, `unitLabelHeight(Aabb2)`, `unitLabelPayload({anchor, height, instanceToWorld})`, `unitLabelAttrib`, `UnitComponent`, `UnitLabelling`.
  - Task 6: `UnitIndex`, `nextUnitNumber(UnitIndex)`, `unitLabelRecord`, `placedLabelTop`, `unitLabelOf(CommandTarget, Handle)`, `addUnitLabelCommand`, `DocumentSession.units`, `PlanController.unitIndex`; test support `unit_fixtures.dart` (`plan`, `entryOf`, `tableSymbol`, `stoolSymbol`, `planterSymbol`, `placementAt`, `kDeg37`, `unitIndexOf`).
  - Task 5: `unitKit()`, `RowComponent`, `rowSeatTransform`, `tableSymbolId`, `rowSeatKey`, `boothSymbolId`; `serviceFixture()`, `testEntry`, `seatsOf`, `unitLabelsOf`, `expectUprightLabel`.
  - 2a: `LockExpander` (`lib/src/kits/locks.dart:167-226`), `DocumentSession` (`session.dart:84-89`, `:267-283`), `placeSymbol` (`symbol_placer.dart:151-181`), `PlanSymbolTool` (`plan_symbol_tool.dart:69-88`, `:440-450`), `PlanController.lockBroken`, `lockHint`, `armSymbol`, `symbolById`, `symbolThumbnailDocument(PlanSymbol)` (`thumbnail_document.dart:11-18`); test support `boxKit`, `Switches`, `SquareParams` (`test/support/box_kit.dart`), `useTestCamera`, `tapAt`, `settle`.
- Produces:
  - `lib/src/units/unit_label_system.dart`: `final class UnitLabelSystem` (`UnitLabelSystem(DraftDocument document)`, `install()`, `dispose()`; Shared interfaces); `final class UnitLabelEdit extends DraftCommand` (made only by the system); `GeometryPayload? restampedUnitLabel(GeometryPayload payload, Transform2 placement)`.
  - `lib/src/units/unit_rotate.dart`: `DraftCommand? rotateUnitCommand(DraftDocument doc, Handle instance, int quarterTurns)` (Shared interfaces; Task 10's ±90 buttons).
  - `placeSymbol(…, UnitIndex? units)`: with an index, a placed `numbered` unit gets `nextUnitNumber(units)` as a UNIT ATTRIB in the same command; without one, no label (a thumbnail, 2a's callers).
  - `PlanSymbolTool(…, {UnitIndex Function()? units})`.
  - `DocumentSession.labels` (`UnitLabelSystem`); the expander stack per document: parametric system → `UnitLabelSystem` → `LockExpander` (Shared interfaces, Task 7). Task 11's `ServiceSession` stacks the copy's the same way.

Plan decision (how the placer reads the next number): `placeSymbol` takes the index as a parameter (`UnitIndex? units`), not a document scan. The number must skip a seat's label (spec S2), and only an index built with the catalog and the lock set knows a seat (Task 6's predicate). The symbol tool reads `units` (`() => session.units.current`, the cached index) at the press. A caller with no index (the gallery's thumbnail, `thumbnail_document.dart:16`; 2a's ported placer tests) places no label, as today's `numbered: false` (`jet_cad_floor_plan/lib/src/symbols/symbol_placer.dart:176-189`). `units` replaces today's `numbered` flag.

Plan decision (the placed label): the record is Task 6's `unitLabelRecord`; the payload is the kit's `unitLabelPayload(anchor: the entry's base point, height: unitLabelHeight(top), instanceToWorld: placement)`, `top` being Task 6's `placedLabelTop` of the entry's leaves (controller ruling R-21: the first leaf's box when it is a circle or a polyline, else empty). This is today's rule (`symbol_placer.dart:218-232`, `table_label.dart:22-44`), with the height read from that box. The instance's handle is allocated before the label's, as today, so a redo replays the same handles and number.

Plan decision (the label system's scope, spec S2): it stamps **placed** units only: a touched live instance whose parent is the root and whose definition carries `UnitComponent` (today's `_stampFor`, `table_label_system.dart:127-139`, with `SeatingComponent` → `UnitComponent`). A generated unit's label is its type's, restamped by its row's regeneration (spec S1, S2: "Generated labels are the type's"). The cheap path passes a plan with no unit definition through unwrapped.

Plan decision (the stack, spec S2 "The label system"): `DocumentSession` installs the parametric system, then `UnitLabelSystem`, then `LockExpander`, so the lock checks every handle a stamp touches too; disposal runs in reverse (each asserts LIFO: `locks.dart:184-191`, `table_label_system.dart:37-44`).

- [ ] **Step 1: The new failing tests.** Create `test/units/unit_label_stack_test.dart`:

```dart
// Spec 2b S2 "The label system", "The label" (placed rules): the label
// system stacks between the parametric system and the lock, so the lock
// sees its stamps; a placed numbered unit gets the next number, upright, in
// the placement's one step, from the controller's index and through its
// symbol tool; an assigned one gets none; a seat's label stays its type's.
// On the service fixture: a mirrored, turned table, a turned row and a
// curved one, off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show unitLabelAttrib;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placeSymbol;
import 'package:jet_cad_2d_plan/src/units/unit_rotate.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart';
import '../support/symbol_fixtures.dart' show settle;
import '../support/test_kit.dart';
import '../support/tool_events.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

GeometryPayload payloadOf(DraftDocument d, Handle entity) =>
    d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(entity)!));

/// The one new root-level instance [action] adds to [c]'s document.
Handle placedBy(PlanController c, void Function() action) {
  final d = c.document;
  final before = {for (final n in d.tree.nodes) n.handle};
  action();
  return d.tree.nodes
      .whereType<InstanceNode>()
      .singleWhere((n) => !before.contains(n.handle))
      .handle;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'UL-stack the lock sees the label system\'s stamps: a turn whose stamp '
      'writes a locked handle is refused, nothing changed; unlocked, the '
      'same turn passes and stamps (M-UL-stack)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final start = (d.tree[f.table]! as InstanceNode).transform;
    final label0 = payloadOf(d, f.tableLabel);
    // Positive control: the turn applies and stamps the label.
    expect(c.execute(rotateUnitCommand(d, f.table, 1)!), isTrue);
    expect(payloadOf(d, f.tableLabel), isNot(label0));
    c.undo();
    expect(payloadOf(d, f.tableLabel), label0);
    // The label alone locked: it stands for any handle only a stamp
    // touches. The turn itself touches the table, which is not locked.
    c.lockBroken({f.tableLabel});
    expect(c.isLocked(f.table), isFalse, reason: 'premise');
    expect(c.execute(rotateUnitCommand(d, f.table, 1)!), isFalse);
    expect(c.lockHint.value, isTrue);
    expect((d.tree[f.table]! as InstanceNode).transform.equals(start, exact),
        isTrue);
    expect(payloadOf(d, f.tableLabel), label0);
  });

  test(
      'UL-place-number a placed numbered unit gets the next number as its '
      'UNIT label in the placement\'s one step, upright though turned and '
      'mirrored; the symbol tool numbers through the controller\'s index '
      '(M-UL-number, M-UL-tool)', () async {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    await settle();
    final d = c.document;
    final entry = c.symbolById(tableSymbolId)!.entry;
    final depth = d.commands.undoDepth;
    final first = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, entry,
                at: Vector2(-6100.25, 4300.5),
                quarterTurns: 3,
                mirrored: true,
                units: c.unitIndex)),
            isTrue));
    expect(d.commands.undoDepth, depth + 1, reason: 'one step');
    final [(label, text)] = unitLabelsOf(d, first);
    expect(text, '13', reason: 'the table is 12; seats do not count');
    final node = d.tree[first]! as InstanceNode;
    expect(node.transform.determinant, lessThan(0), reason: 'premise');
    expectUprightLabel(d, label, node.transform);
    expect(payloadOf(d, label).coords,
        [entry.definition.basePoint.x, entry.definition.basePoint.y]);

    useTestCamera(c);
    expect(c.armSymbol(c.symbolById(tableSymbolId)!), isTrue);
    final second = placedBy(c, () => tapAt(c, Vector2(7300.75, -5200.5)));
    expect([for (final l in unitLabelsOf(d, second)) l.$2], ['14']);
  });

  test(
      'UL-assigned an assigned unit placed gets no label; a numbered one '
      'placed after it takes the next number (M-UL-assigned)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final seat = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, testEntry(rowSeatKey),
                at: Vector2(3300.5, 6100.25),
                quarterTurns: 2,
                units: c.unitIndex)),
            isTrue));
    expect(unitLabelsOf(d, seat), isEmpty);
    final booth = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, testEntry(boothSymbolId),
                at: Vector2(-7200.75, -1100.5),
                quarterTurns: 1,
                mirrored: true,
                units: c.unitIndex)),
            isTrue));
    expect([for (final l in unitLabelsOf(d, booth)) l.$2], ['13']);
  });

  test(
      'UL-seat a seat a row\'s regeneration adds keeps its type\'s label, '
      'stamped for the world: the label system stamps placed units only '
      '(M-UL-root)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final p = d.components.get<RowComponent>(f.rowA)!;
    final grown = p.copyWith(count: 7);
    expect(c.execute(SetComponentCommand<RowComponent>(f.rowA, grown)),
        isTrue);
    final seven = seatsOf(d, f.rowA);
    expect(seven.sublist(0, 6), f.seatsA);
    final added = seven.last;
    final [(label, text)] = unitLabelsOf(d, added);
    expect(text, 'A7');
    final group = (d.tree[f.rowA]! as GroupNode).transform;
    final toWorld =
        group.multiply((d.tree[added]! as InstanceNode).transform);
    final want = unitLabelAttrib('A7',
            instanceToWorld: toWorld, anchor: grown.base, top: grown.top)
        .payload;
    final got = payloadOf(d, label);
    expect(got.coords, want.coords);
    expect(got.scalars[0], want.scalars[0]);
    expect(got.scalars[1], closeTo(want.scalars[1], 1e-12));
    expect(got.scalars[2], want.scalars[2]);
    expectUprightLabel(d, label, toWorld);
  });
}
```

- [ ] **Step 2: Run the tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/unit_label_stack_test.dart`. Expected: compilation errors (`Target of URI doesn't exist: 'package:jet_cad_2d_plan/src/units/unit_rotate.dart'`, `The named parameter 'units' isn't defined`).

- [ ] **Step 3: `unit_label_system.dart`.** Create `lib/src/units/unit_label_system.dart`, ported from `jet_cad_floor_plan/lib/src/tables/table_label_system.dart:1-157` and `table_label.dart:84-104` (`restampedTableLabel`). Every line not shown below is copied unchanged, with these renames: `TableLabelSystem` → `UnitLabelSystem` (declared `final class`), `TableLabelEdit` → `UnitLabelEdit`, "table" → "placed unit" in comments. The changed regions:

```dart
// The unit label system (spec 2b S2 "The label system"): keeps every placed
// unit's label upright, inside the edit that turns or mirrors the unit, as
// one undo step. Ported from jet_cad_floor_plan's
// tables/table_label_system.dart (TableLabelSystem, TableLabelEdit) and
// table_label.dart (restampedTableLabel): the servable check is the
// definition's UnitComponent, the root rule is kept. A generated unit's
// label is its type's, restamped by its regeneration (spec S1). A deleted
// unit's data and colour are not this file's: the delete takes them
// (`RemoveNodeCommand`, node-components D-1).
//
// No Flutter import: Dart over package:jet_cad_2d and the kit's model.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show UnitComponent, kUnitLabelMaxHeight, unitLabelStamp;

import 'unit_label.dart' show unitLabelOf;

/// [payload] re-stamped for [placement]: anchor and height kept, rotation
/// and width factor replaced. Null when they already match by exact `==`
/// (stored values), so a translation writes nothing.
GeometryPayload? restampedUnitLabel(
    GeometryPayload payload, Transform2 placement) {
  final s = unitLabelStamp(placement);
  final scalars = payload.scalars;
  if (scalars.length >= 3 &&
      scalars[1] == s.rotation &&
      scalars[2] == s.widthFactor) {
    return null;
  }
  return GeometryPayload(
    coords: Float64List.fromList(payload.coords),
    scalars: Float64List.fromList([
      scalars.isEmpty ? kUnitLabelMaxHeight : scalars[0],
      s.rotation,
      s.widthFactor,
    ]),
  );
}
```

  In `UnitLabelSystem`: `install`'s message `'the unit label system is installed already'`; `dispose`'s assert message `'UnitLabelSystem disposed out of order (spec 2b S2)'`; its doc names the stack "parametric system → this → lock expander". `_expand` becomes:

```dart
  DraftCommand _expand(DraftCommand command) {
    final inner = _previous?.call(command) ?? command;
    // The cheap path: a plan with no unit definition has no placed unit.
    if (document.components.withComponent<UnitComponent>().isEmpty) {
      return inner;
    }
    return UnitLabelEdit._(inner);
  }
```

  In `UnitLabelEdit`, `_stampFor` and `_labelOf` (`:124-156`) become:

```dart
  /// The stamp [h] needs, or null: [h] is a placed unit (a live, root-level
  /// instance of a definition carrying `jetcad.unit`) with a `UNIT` label
  /// whose rotation or width factor differs from its transform's stamp.
  static DraftCommand? _stampFor(CommandTarget target, Handle h) {
    final node = target.tree[h];
    if (node is! InstanceNode || node.parent != target.tree.root) return null;
    if (target.components.get<UnitComponent>(node.definition) == null) {
      return null;
    }
    final label = unitLabelOf(target, h);
    if (label == null) return null;
    final payload = target.geometry
        .read(target.entities.geomIndexAt(target.entities.slotOf(label)!));
    final next = restampedUnitLabel(payload, node.transform);
    return next == null ? null : SetEntityGeometryCommand(label, next);
  }
```

  (`_labelOf` is deleted: Task 6's `unitLabelOf` is the same lowest-handle rule.) `label`, `capabilities`, `capability` and `apply` (`:64-122`) are copied unchanged.

- [ ] **Step 4: `unit_rotate.dart`.** Create `lib/src/units/unit_rotate.dart`, ported from `jet_cad_floor_plan/lib/src/tables/table_rotate.dart:1-44` with the body unchanged. Changes: the header reads "Turning a placed unit by a quarter (spec 2b S4, the unit section's ±90 buttons), ported from jet_cad_floor_plan's tables/table_rotate.dart (spec 14a T16): about its base point, so the unit turns in place and its label does not move. The label system stamps the label upright in the same step."; `rotateTableCommand` → `rotateUnitCommand`; its doc says "unit" for "table".

- [ ] **Step 5: The placer numbers a placed numbered unit.** In `lib/src/symbols/symbol_placer.dart`:
  1. Header (`:1-8`): replace "the table number goes to 2b with the units." with "a placed `numbered` unit gets the plan's next number as its UNIT label in the same command (spec 2b S2)."; "It writes no table record" stays.
  2. Imports: the kit's `show` list gains `UnitLabelling, unitLabelHeight, unitLabelPayload`; add `import '../units/unit_index.dart' show UnitIndex;`, `import '../units/unit_label.dart' show placedLabelTop, unitLabelRecord;`, `import '../units/unit_numbers.dart' show nextUnitNumber;`.
  3. `placeSymbol` (`:145-181`) becomes:

```dart
/// The command that places [entry] in [doc] at [at], labelled
/// `Place <name>`; it does not execute. Every handle is allocated here,
/// once, so a redo reuses them. The instance takes the current layer
/// (`drawingLayer`) and [style]; [transform], when given, is used as is
/// (an attachment's), else [placementTransform] of [at], [quarterTurns]
/// and [mirrored].
///
/// With [units] (the plan's index), a `numbered` unit gets
/// `nextUnitNumber(units)` as its `UNIT` label after the instance, anchored
/// at the base point, the height of its top, stamped upright for the
/// placement (spec 2b S2). The number is fixed here, with the handles, so
/// a redo replays the same one. An `assigned` unit, and any placement
/// without [units] (a thumbnail), gets no label.
CompoundCommand placeSymbol(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  Transform2? transform,
  InstanceStyle style = const InstanceStyle(),
  UnitIndex? units,
}) {
  final made = definitionForEntry(doc, entry);
  final commands = <DraftCommand>[...made.commands];
  final instance = doc.handleSeed.next();
  final placement = transform ??
      placementTransform(
        at: at,
        basePoint: entry.definition.basePoint,
        quarterTurns: quarterTurns,
        mirrored: mirrored,
      );
  commands.add(AddNodeCommand(InstanceNode(
    handle: instance,
    parent: doc.rootHandle,
    definition: made.definition,
    layer: drawingLayer(doc),
    transform: placement,
    color: style.color,
    lineweight: style.lineweight,
    transparency: style.transparency,
    linetype: style.linetype,
    linetypeScale: style.linetypeScale,
  )));
  final unit = entry.unit;
  if (units != null &&
      unit != null &&
      unit.labelling == UnitLabelling.numbered) {
    commands.add(AddEntityCommand(
      record: unitLabelRecord(
          handle: doc.handleSeed.next(),
          instance: instance,
          text: nextUnitNumber(units)),
      payload: unitLabelPayload(
        anchor: entry.definition.basePoint,
        height: unitLabelHeight(placedLabelTop([
          for (final leaf in entry.leaves) (leaf.record.kind, leaf.payload),
        ])),
        instanceToWorld: placement,
      ),
    ));
  }
  return CompoundCommand(commands, label: 'Place ${entry.symbol.name}');
}
```

  The handle order is unchanged (the definition's, then the instance's), so 2a's `symbol_placer_test.dart` keeps its handles.

- [ ] **Step 6: The symbol tool and the controller.**
  1. `lib/src/tools/plan_symbol_tool.dart`: import `'../units/unit_index.dart' show UnitIndex;`. The constructor (`:70-71`) becomes `PlanSymbolTool(this.armed, {this.attachments, this.canRotate, this.canMirror, this.units})`; after `canMirror` (`:88`) add:

```dart
  /// The plan's units, read at each placement: a numbered unit takes the
  /// next number (spec 2b S2). Null places no label.
  final UnitIndex Function()? units;
```

     `_place` (`:440-450`) passes `units: units?.call(),` after `transform: _attached?.transform,`.
  2. `lib/src/controller/plan_controller.dart` `_open` (`:663-666`): the `PlanSymbolTool(…)` call gains `units: () => session.units.current,`.
  3. `lib/src/controller/session.dart`: import `'../units/unit_label_system.dart';`. The construction's last lines (`:84-88`) become:

```dart
    // :1050-1057: the document arrives built; the system installs last.
    // Spec 2b S2: parametric system → unit label system → lock expander,
    // so the lock checks the stamps too.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
    labels = UnitLabelSystem(document)..install();
    lockExpander = LockExpander(document, locks)..install();
```

     After `late final ParametricSystem parametric;` (`:115`) add `/// The placed units' label stamps (spec 2b S2). late final UnitLabelSystem labels;`. In `dispose()`, between `lockExpander.dispose();` and `parametric.dispose();`, add `labels.dispose();`.

- [ ] **Step 7: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/unit_label_stack_test.dart`. Expected: `All tests passed!` (four tests).

- [ ] **Step 8: Port the tests.** Assertions unchanged in every ported test; only the fixture, the subjects named below, the imports and the names change. Each file starts with `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` and imports `../support/unit_fixtures.dart` and the units' files in place of the `jet_cad_floor_plan` imports. A shared adaptation, everywhere below: a placement that numbered today (`placeSymbol(doc, entry, …)` with today's default `numbered: true`) passes `units: unitIndexOf(doc)`; one that passed `numbered: false` passes none. Already ported or elsewhere: `symbol_placer_test.dart` (whole, 2a Task 13; it holds no label test, `grep -n TABLE` finds none); `table_label_test.dart`'s `TL1`, `TL2`, `TL4` (Task 3) and `TL5`-`TL7` (Task 6); `table_section_test.dart`'s widget tests `TS1`-`TS8` (Task 10, the unit section). `host/against_wall_rotate_test.dart` turns symbols against a wall (sub-project 3) and does not call `rotateTableCommand` (`grep -rn rotateTableCommand test` finds only `table_section_test.dart:337`): not ported.
  1. **`test/units/unit_label_system_test.dart`** from `floor_plan/test/tables/table_label_system_test.dart`: `LS1` (`:88-123`), `LS2` (`:125-147`), `LS3` (`:149-170`), `LS4` (`:172-191`), `LS5` (`:193-206`), `LS6` (`:208-221`), `LS6b` (`:223-271`), `LS7` (`:273-318`), with the helpers `rig`, `placeTable`, `rotate`, `labelPayload`, `labelWorldLinear`, `expectUpright`, `pivot` (`:20-85`); from `floor_plan/test/tables/table_data_test.dart`: `TD10` (`:416-440`) with `_Refused`, `samePayload` and `_RefusingTarget` (`:444-495`); from `floor_plan/test/tables/table_label_test.dart`: `TL3` (`:78-92`). Adaptations:
     - `rig({doc})`: `installParametric(d)` → `ParametricSystem(d, catalogOf([boxKit(Switches())]))..install()` (import `../support/box_kit.dart` `show Switches, SquareParams, boxKit`: it also declares `addLine` and `coordsOf`, as `harness.dart` does); `TableLabelSystem(d)` → `UnitLabelSystem(d)`; the tear-down disposes the label system, then the system, as before. `LS4`'s two `installParametric(doc)` → `ParametricSystem(doc, ParametricCatalog())..install()`.
     - `placeTable` passes `units: unitIndexOf(doc)`; `tablesOf(doc)…label!` → `unitIndexOf(doc)[instance]!.label!` (`labelPayload`) and `unitIndexOf(doc).units.single.label!` (`LS1`, `LS2`, `LS6b`).
     - `LS3`: `BoxParams` (an app type) → the box kit's square: `SetComponentCommand<SquareParams>(box, const SquareParams(side: 1200))`; its four generated lines are the assertion's `4`.
     - `LS6`: `isNot(isA<TableLabelEdit>())` → `isNot(isA<UnitLabelEdit>())`. `LS6b`: `addTableLabelCommand(…, number: '8')` and `(…, number: '9')` → `addUnitLabelCommand(…, text: '8')` and `(…, text: '9')`; its nested instance sits in a plain group, so it is `unit.nested`, which the system does not stamp, as today.
     - `LS7`: `registerAppComponents(doc.components)` → `registerPlanComponents(doc.components, ParametricCatalog())`.
     - `TD10`: its `placeTable` is this file's (`UnitInfo` for `TableInfo`, from `unitIndexOf(doc)`); `isA<TableLabelEdit>()` → `isA<UnitLabelEdit>()`; its `labelPayload(doc, label)` is renamed `payloadOfLabel` (this file's `labelPayload` reads by instance).
     - `TL3`: `tableLabelPayload(anchor:, height:, placement: p)` → `unitLabelPayload(anchor:, height:, instanceToWorld: p)`; `restampedTableLabel` → `restampedUnitLabel`; `tableLabelStamp` → `unitLabelStamp`.
  2. **`test/units/unit_placement_test.dart`** from `floor_plan/test/tables/table_placement_test.dart`: `TP1`-`TP7` (`:47-157`) with `place`, `attribs`, `numbers` (`:21-44`). Adaptations:
     - `place` passes `units: unitIndexOf(doc)`; `numbers(doc)` → `[for (final u in unitIndexOf(doc).units) u.text]`.
     - The tag: `'TABLE'` → `'UNIT'` in `TP1`'s two record expectations and in `TP3`'s and `TP5`'s `SetEntityTextCommand(…, 'TABLE')` (the tag renamed, spec S2, as Task 6's `TL5`); `tableLabelStamp` → `unitLabelStamp`.
     - `TP6`: `symbolThumbnailDocument(entryOf(tableSymbol()), MetricModelMeasurer())` → `symbolThumbnailDocument(PlanSymbol(kitId: fxKitId, names: KitNames.empty, entry: entryOf(tableSymbol())))` (2a's signature; the fixture's symbols are the fixture kit's, controller ruling R-19).
     - `TP7`'s premise is the furniture library (`buildFurnitureLibrary`, `dining.table.round`), which the plan library may not depend on. **Finding P-2, for the ledger:** the subject becomes the unit kit's square table (`testEntry(tableSymbolId)`), placed the same way; every assertion holds unchanged (text `'1'`, the base point, height 200: its top is 900 mm, `0.4 × 900 > 200`; rotation `−π/2` for one quarter turn). The test's name becomes "the unit kit's square table places numbered, its label inside the top".
  3. **`test/units/unit_data_delete_test.dart`** from `floor_plan/test/tables/table_data_test.dart`: `TD7` (`:251-287`), `TD7b` (`:289-309`), `TD7c` (`:311-355`), `TD8` (`:357-391`), `TD9` (`:393-414`), with `hostData`, `key64`, `value1024`, `rig`, `placeTable`, `deleteTable`, `dataOf`, `rootChildren` (`:22-82`). Adaptations: `FloorPlanTableData` → `UnitData`; `TD7`'s `'jetcad.table_data'` → `'jetcad.unit_data'`; `TableInfo` → `UnitInfo`; `rig()` → `plan()` with `ParametricSystem(d, ParametricCatalog())..install()` and `UnitLabelSystem(d)..install()`, torn down in reverse with `d.dispose()`; `placeTable` places with `units: unitIndexOf(doc)` and returns the highest-handle `UnitInfo` of `unitIndexOf(doc).units`.
  4. **`test/units/unit_rotate_test.dart`** from `floor_plan/test/tables/table_section_test.dart`: `TS9` (`:326-347`), `TS10` (`:349-381`), with `rig`, `placeOne`, `parts` (`:33-54`, `:86`). Adaptations: `rig` as in 1 above (no box kit needed: `ParametricCatalog()`); `placeOne` passes `units: unitIndexOf(doc)`; `rotateTableCommand` → `rotateUnitCommand`; `TS10`'s `tablesOf(doc).single.label!` → `unitIndexOf(doc).units.single.label!`.

- [ ] **Step 9: Run the ported tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units test/symbols test/tools test/panels`. Expected: `All tests passed!` (2a's placer, symbol tool and gallery tests are unchanged by the optional `units`). A ported test that fails on an assertion is a finding: stop and report it; never change the assertion.

- [ ] **Step 10: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`. Each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/units/unit_label_system.dart packages/jet_cad_2d_plan/lib/src/units/unit_rotate.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/test/units/unit_label_stack_test.dart packages/jet_cad_2d_plan/test/units/unit_label_system_test.dart packages/jet_cad_2d_plan/test/units/unit_placement_test.dart packages/jet_cad_2d_plan/test/units/unit_data_delete_test.dart packages/jet_cad_2d_plan/test/units/unit_rotate_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the unit label system, the placed number, rotation (2b S2)

UnitLabelSystem keeps a placed unit's UNIT label upright inside the
edit that turns or mirrors it, one undo step; a seat's label stays its
type's. Each document stacks the parametric system, the label system,
then the lock, so the lock sees the stamps. A placed numbered unit
takes the next number in its placement's command, through the
session's unit index; an assigned one takes none. rotateUnitCommand
turns a unit a quarter about its base point.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-UL-stack `lib/src/controller/session.dart`: swap the two lines `labels = UnitLabelSystem(document)..install();` and `lockExpander = LockExpander(document, locks)..install();`, and in `dispose()` swap `lockExpander.dispose();` and `labels.dispose();` → `UL-stack` red (the locked turn applies: `true` for `false`).
  - M-UL-number `lib/src/symbols/symbol_placer.dart`: `instanceToWorld: placement,` (in the label's payload) → `instanceToWorld: Transform2.identity(),` → `UL-place-number` red (the label is not upright).
  - M-UL-tool `lib/src/tools/plan_symbol_tool.dart`: delete `units: units?.call(),` → `UL-place-number` red (`[]` for `['14']`).
  - M-UL-assigned `symbol_placer.dart`: `unit.labelling == UnitLabelling.numbered` → `true` → `UL-assigned` red (the seat is labelled).
  - M-UL-root `lib/src/units/unit_label_system.dart`: `if (node is! InstanceNode || node.parent != target.tree.root) return null;` → `if (node is! InstanceNode) return null;` → `UL-seat` red (the added seat's label is stamped for its row-space transform).
  - M-LS-stamp (the ported `LS1`'s, M-14a-8) `unit_label_system.dart`: `return next == null ? null : SetEntityGeometryCommand(label, next);` → `return null;` → `LS1` red.
  - M-LS-cheap (the ported `LS6`'s) `unit_label_system.dart`: `if (document.components.withComponent<UnitComponent>().isEmpty) {` → `if (false) {` → `LS6` red.
  - M-TD10 (the ported `TD10`'s) `unit_label_system.dart`: in `UnitLabelEdit.apply`'s `catch`, delete `r.inverse.apply(target);` → `TD10` red (the tables stay turned).
  - M-TP-number (the ported `TP2`'s, M-14a-13) `symbol_placer.dart`: `text: nextUnitNumber(units)` → `text: '1'` → `TP2` red.
  - M-TS9 (the ported `TS9`'s) `lib/src/units/unit_rotate.dart`: `final e = worldX - (a * bp.x + c * bp.y);` → `final e = t.e;` → `TS9` red (the base point moves).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 1: a regeneration that grows a row adds the seat with `AddNodeCommand` and its ATTRIBs with `AddEntityCommand`, inside the plan `_run` applies one by one; `_run` adds each applied command's `touched` to the edit's result (`jet_cad_2d/lib/src/parametric/regeneration.dart:1064`, `:1084`, unchanged by Task 1), so the added seat's handle and its label's are in the `touched` the label system reads (Task 1's "What the consumers can rely on"). `UL-seat`'s M-UL-root relies on it. The index does not read `touched`: it rebuilds on `stateId` (Task 6).
- Task 3: `kUnitLabelMaxHeight`, `unitLabelStamp`, `unitLabelHeight`, `unitLabelPayload`, `unitLabelAttrib` in the kit's barrel, the stamp being today's `tableLabelStamp` (`table_label.dart:55-64`).
- Task 6: the names in its Produces, `DocumentSession.units` among them; `PlanController.unitIndex`.
- Task 5: the names in its Produces.
- 2a: `PlanController.lockBroken` adds any handle it is given to the lock set (`plan_controller.dart:533-541`; `LockSet.addBroken`, `locks.dart:116-119`), and `covers` holds for it (`:112-113`); `UL-stack` locks a label this way.

---

