### Task 2: the floor plan — the table-data expander goes (D-7), TD10, P-1 to P-3

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/tables/table_label_system.dart`
  (`_detachFor` and its branch, the header, `TableLabelEdit`'s doc, the
  catch's comment)
- Modify: `packages/jet_cad_floor_plan/lib/src/planner_shell.dart:925-929`
  (doc only)
- Modify: `packages/jet_cad_floor_plan/test/tables/table_data_test.dart`
  (TD8, TD9 titles; TD10 and `_RefusingTarget` rewritten; the file header)
- Create: `packages/jet_cad_floor_plan/test/delete_components_test.dart`

**Interfaces:**
- Consumes: Task 1's `RemoveNodeCommand` (takes components) and
  `AddNodeCommand.components`.
- Produces: nothing new; `TableLabelEdit` keeps its constructor,
  `capabilities`, `capability` and replay.

- [ ] **Step 1: P-1 to P-3, in the shell's rig.** Create
  `test/delete_components_test.dart`:

```dart
// Spec "A removed node takes its components" (revision 3), P-1 to P-3:
// in the shell's rig (the parametric system, then the table system), a
// delete takes every component of every removed node, a door with its
// wall, and undo writes the plan back byte for byte.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/parametric/opening.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/tables/table_data_component.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart' show addOpening, deleteLikeSelectTool;
import 'support/wall_fixture.dart' show addWallLocal;
import 'tables/table_data_test.dart'
    show rig, placeTable, deleteTable, hostData, dataOf;

String enc(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

bool namesHandle(DraftDocument doc, Handle h) => doc.components
    .toJson()
    .values
    .any((perType) => (perType! as Map).containsKey('${h.value}'));

/// A layer that is not layer 0, added to [doc].
Handle addLayer(DraftDocument doc) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: 'Walls',
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
  return h;
}

void main() {
  test('P-1 a table with data and a newer release\'s payload, and a wall, '
      'deleted together: no entry for either; undo byte for byte', () {
    final doc = rig();
    final layer = addLayer(doc);
    final t = placeTable(doc, Vector2(41200, -27300), quarterTurns: 1,
        mirrored: true);
    doc.commands.execute(SetComponentCommand<FloorPlanTableData>(
        t.instance, FloorPlanTableData(hostData())));
    doc.components.attachUnknown(t.instance, {'typeId': 'z.next', 'v': 2});
    final w = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(
        doc,
        w,
        const WallParams(120, -40, 5120, 310, 200, Justification.left),
        Transform2.translation(38000, -25000)
            .multiply(Transform2.rotation(0.3))));
    doc.commands.execute(SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(CompoundCommand([
      ...(deleteTable(t) as CompoundCommand).children,
      ...(deleteLikeSelectTool(doc, w) as CompoundCommand).children,
    ], label: 'Delete'));

    expect(doc.commands.undoDepth, depth + 1);
    for (final h in [t.instance, w]) {
      expect(doc.tree[h], isNull);
      expect(namesHandle(doc, h), isFalse, reason: '${h.toHex()}');
      expect(doc.components.unknownOf(h), isEmpty);
    }
    doc.commands.undo();
    expect(enc(doc), before);
    expect(dataOf(doc, t.instance), isNotNull);
  });

  test('P-2 a wall deleted alone: WallParams and ObjectLayer gone, the undo '
      'replay restores them through the node\'s snapshot', () {
    final doc = rig();
    final layer = addLayer(doc);
    final w = doc.handleSeed.next();
    const p = WallParams(-300, 75, 4100, 75, 150, Justification.centre);
    doc.commands.execute(addWallLocal(doc, w, p,
        Transform2.translation(-12000, 8000).multiply(Transform2.rotation(-0.8))));
    doc.commands.execute(SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)));
    final before = enc(doc);

    doc.commands.execute(deleteLikeSelectTool(doc, w));
    expect(doc.components.get<WallParams>(w), isNull);
    expect(doc.components.get<ObjectLayer>(w), isNull);
    doc.commands.undo();
    expect(doc.components.get<WallParams>(w), p);
    expect(doc.components.get<ObjectLayer>(w), ObjectLayer(layer));
    expect(enc(doc), before);
  });

  test('P-3 a wall hosting a door: the door goes with it (08 D4\'s '
      'cascade), both components and layers gone; undo restores both', () {
    final doc = rig();
    final layer = addLayer(doc);
    final w = doc.handleSeed.next();
    doc.commands.execute(addWallLocal(
        doc,
        w,
        const WallParams(0, 0, 6000, 0, 200, Justification.centre),
        Transform2.translation(25000, 14000).multiply(Transform2.rotation(1.2))));
    final door = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, door, OpeningParams(w, 2400, 900, OpeningKind.door)));
    doc.commands.execute(CompoundCommand([
      SetComponentCommand<ObjectLayer>(w, ObjectLayer(layer)),
      SetComponentCommand<ObjectLayer>(door, ObjectLayer(layer)),
    ], label: 'Layers'));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(deleteLikeSelectTool(doc, w));

    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.tree[door], isNull, reason: 'premise: the cascade ran');
    for (final h in [w, door]) {
      expect(namesHandle(doc, h), isFalse, reason: '${h.toHex()}');
    }
    doc.commands.undo();
    expect(enc(doc), before);
  });
}
```

  The `show` lists name the fixtures as this plan found them
  (`table_data_test.dart:41-73`, `wall_fixture.dart:180-190`,
  `opening_fixture.dart:136-150`; `WallParams` and `Justification` are in
  `parametric/wall.dart`, `OpeningParams` and `OpeningKind` in
  `parametric/opening.dart`). Importing `table_data_test.dart` brings its
  `main` along unused; if the analyzer objects, move `rig`, `placeTable`,
  `deleteTable`, `hostData` and `dataOf` into `tables/table_fixture.dart`
  instead (a move, not an edit: `table_data_test.dart` then imports them).

- [ ] **Step 2: run them.** With Task 1 in place they pass already (the
  expander is still installed): `flutter test --enable-vmservice
  test/delete_components_test.dart`. Paste the output. Their job is to
  stay green through Step 4 and to kill M-1 and M-2 (Step 7).

- [ ] **Step 3: rewrite TD10 and `_RefusingTarget`.** TD10 now turns two
  tables in one edit and refuses the **second** stamp's geometry read
  after the first stamp has written, so the catch has a derived inverse
  to undo (spec D-7, review V-1):

```dart
    test(
        'TD10 all or nothing: a stamp that throws after another stamp '
        'puts that one back with the edit', () {
      final doc = rig();
      final a = placeTable(doc, Vector2(41200, -27300), quarterTurns: 1);
      final b = placeTable(doc, Vector2(44700, -27300), mirrored: true);
      final before = DraftDocumentCodec.encodeToString(doc);
      Transform2 turned(TableInfo t, double x, double y) => Transform2
          .translation(x, y)
          .multiply(Transform2.rotation(kDeg37))
          .multiply(Transform2.translation(-x, -y))
          .multiply((doc.tree[t.instance]! as InstanceNode).transform);
      final edit = doc.commands.expander!(CompoundCommand([
        TransformNodeCommand(a.instance, turned(a, 41200, -27300)),
        TransformNodeCommand(b.instance, turned(b, 44700, -27300)),
      ], label: 'Turn both'));
      expect(edit, isA<TableLabelEdit>());
      final target =
          _RefusingTarget(doc, a.label!, labelPayload(doc, a.label!));
      expect(() => edit.apply(target), throwsA(isA<_Refused>()));
      expect(target.refused, isTrue,
          reason: 'premise: A\'s stamp wrote before B\'s read was refused');
      expect(DraftDocumentCodec.encodeToString(doc), before,
          reason: 'both tables unturned, A\'s label as it was');
    });
  });
}

final class _Refused implements Exception {}

GeometryPayload labelPayload(DraftDocument doc, Handle label) => doc.geometry
    .read(doc.entities.geomIndexAt(doc.entities.slotOf(label)!));

bool samePayload(GeometryPayload x, GeometryPayload y) =>
    x.coords.length == y.coords.length &&
    x.scalars.length == y.scalars.length &&
    [for (var i = 0; i < x.coords.length; i++) x.coords[i] == y.coords[i]]
        .every((e) => e) &&
    [for (var i = 0; i < x.scalars.length; i++) x.scalars[i] == y.scalars[i]]
        .every((e) => e);

/// [doc] as a command target whose geometry -- read by a label stamp --
/// is refused once, the first time it is asked for after [stamped]'s
/// payload has changed from [unstamped]: so the edit throws with that
/// stamp applied, and the rollback (which reads geometry again) is let
/// through.
final class _RefusingTarget implements CommandTarget {
  _RefusingTarget(this.doc, this.stamped, this.unstamped);

  final DraftDocument doc;
  final Handle stamped;
  final GeometryPayload unstamped;
  bool refused = false;

  @override
  GeometryStore get geometry {
    if (!refused && !samePayload(labelPayload(doc, stamped), unstamped)) {
      refused = true;
      throw _Refused();
    }
    return doc.geometry;
  }

  // The other members as today: entities, tree, tables, components,
  // handleSeed, header, fills, invalidateDerived, each forwarding to doc.
}
```

  (Keep the existing forwarding members of `_RefusingTarget` verbatim;
  only its fields, constructor, `geometry` and doc change.) The touched
  order is the compound's: A's stamp runs first. If the report finds B's
  first, swap `a` and `b` in the `_RefusingTarget` arguments and say so.
  Rename TD8's and TD9's titles so they describe the delete taking the
  data (*"…loses its data too"* stays true; drop "the expander" where a
  title or comment says it does the detach) and the file header's
  sentence about *"the table system's expander that drops it"*.

- [ ] **Step 4: D-7, the expander's detach goes.** In
  `table_label_system.dart`: delete `_detachFor` (`:130-142`, with its
  doc) and its branch, so the loop reads

```dart
      for (final h in r.touched) {
        final DraftCommand derived;
        if (_stampFor(target, h) case final stamp?) {
          derived = stamp;
          stamps++;
        } else {
          continue;
        }
```

  (or the equivalent without the `derived` indirection); the catch's
  comment says *"the stamps written so far, then the edit itself"*;
  `_stamped = stamps > 0` keeps its line, its *"A detach alone…"*
  comment goes. The file header (`:1-4`) and `TableLabelEdit`'s doc say
  the delete itself takes a table's data (`RemoveNodeCommand`, node-
  components D-1), so the edit only stamps labels. In
  `planner_shell.dart:925-929`, *"the table-data expander"* becomes *"the
  delete takes each table's data with it"*.

- [ ] **Step 5: run the floor plan suite.**
  Run: `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice`
  Expected: all pass (1912 at `e281372` plus P-1 to P-3). `flutter
  analyze`: no `unused_element` (the spike saw one for a `_detachFor` left
  behind).

- [ ] **Step 6: M-17.** In `TableLabelEdit.apply`'s catch, delete the
  loop over `inverses.reversed`, keeping `r.inverse.apply(target)`.
  Run TD10: red. Restore from the copy.

- [ ] **Step 7: Task 1's mutants against the floor plan.** M-1, M-2 and
  M-15 (Task 1's table) each applied alone to `commands.dart`: TD7 and
  HD12 red for M-1, TD7 and P-1 red for M-2, TD7b red for M-15 (spec F-14,
  re-checked here with the expander gone). Restore each from its copy.

- [ ] **Step 8: every gate**, as in the Global constraints, in
  `jet_cad_floor_plan`, `apps/floor_planner`, `apps/restaurant_demo`.

- [ ] **Step 9: commit.**

```bash
git add packages/jet_cad_floor_plan
git status --short   # no analysis_options.yaml
git commit -m "feat(floor-plan): the delete takes table data; the expander's detach goes (node-components D-7)"
```

