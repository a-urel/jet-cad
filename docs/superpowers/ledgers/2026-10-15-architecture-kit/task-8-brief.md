### Task 8: Plan-library pins carried in (spec C1.12, C7's SE8)

**Files:**
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/shortcuts/plan_shortcuts.dart` (the idle keys follow the shortcuts mounted last); tests `test/shortcuts/plan_shortcuts_test.dart` (PN-remount), `test/attach/attachment_registry_test.dart` (PN-kind, PN-dispose), `test/tools/move_resolver_test.dart` (MV-2's mutation comment; PN-MV-nested, PN-MV-node, PN-MV-live), `test/controller/attachment_controller_test.dart` (PN-open)
- Create (`packages/jet_cad_2d_plan/`): `test/symbols/unit_copy_test.dart` (SE8)

**Interfaces:**
- Consumes:
  - Plan library today: `PlanShortcuts` and its state (`shortcuts/plan_shortcuts.dart:34-107`), `PlanSelectGates.idleKeys` (`tools/plan_select_gates.dart:90`), `PlanController.isDisposed`; `PlanAttachmentRegistry.add`/`dispose` (`attach/attachment_registry.dart:27-44, 97-116`); `PlanMoveResolver.resolveMove` and `_sync` (`tools/move_resolver.dart`, as Task 1 left it: its `isOrthonormal` is the contract's); `PlanController._reportUnofferedKinds` called at the end of `_open` (`controller/plan_controller.dart:1550`) and after a symbol load (`:2280`); `placeSymbol` (`symbols/symbol_placer.dart:169-219`).
  - Test support: `RecordingProvider`, `DisposableProvider`, `queryAt`, `attachment` (`test/support/attach_fixtures.dart`); `box`, `settle` (`test/support/symbol_fixtures.dart:146-165, 248`); the `Scene`, `entry`, `delta`, `partsOf` of `test/tools/move_resolver_test.dart`; `shelfBytes`, `problemsOf` of `test/controller/attachment_controller_test.dart`.
  - Contract (Task 1): `boxOfDefinition`, `boxOfEntry`, `footprintOf`, `isOrthonormal` from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`; `UnitComponent`, `UnitKinds`, `registerKitComponents`, `SymbolLibrary`, `SymbolEntry`; authoring `Catalog`, `CatalogSymbol`, `CatalogUnit`, `CatalogPolyline`, `encodeLibrary`.
- Produces: no public name.

**Appendix A rows closed:** D-44 (PN-remount), D-45 (PN-kind, PN-dispose; the move resolver's four branches: M-PN-ortho on MV-2, PN-MV-nested, PN-MV-node, PN-MV-live; PN-open), D-17's SE8 (ported, `test/symbols/unit_copy_test.dart`). D-17's SE10, SE10b and SE11 are dropped on the human's word (spec decision 7) and SE9 is not owed (the spec's C7 names SE8 alone); recorded here and in the results note (Task 29). Old test file: `jet_cad_floor_plan/test/symbols/seating_test.dart` SE8.

Plan decisions:
- **D-44, the cause.** A `PlanShortcuts` remounted on the same controller (a new key, a new parent) gets a new `State`: the new one's `initState` closes the idle keys during the build, and the old one's `dispose` runs later, at the frame's `finalizeTree`, and reopens them (`plan_shortcuts.dart:89-100`). KB-14 (`plan_shortcuts_test.dart:417-440`) pins a controller swap and a removal, not this. **The fix:** each controller's mounted shortcuts states are kept in mount order (a static `Expando<List<_PlanShortcutsState>>` keyed by the controller); the last mounted speaks for its controller's idle keys; a state that leaves (disposed, or its controller swapped out) hands the say to the one before it, or, with none left, gives the keys back (today's rule). KB-14 keeps passing: a swap leaves the old controller with no state (keys back), a removal likewise.
- **D-45, the registry.** Both untested behaviours exist (`attachment_registry.dart:31-33`: the `kind` read inside the factory's try; `:101-111`: one provider's dispose that throws is reported and the others still disposed): pinned by PN-kind and PN-dispose, each with its mutation. No code change.
- **D-45, the move resolver** (2a `task-14-review.md:51-57`, item 3):
  - the scaled instance: MV-2 already fails when `if (!isOrthonormal(t)) return null;` is deleted (its scaled instance is then asked, and `expect(scaled.edge.queries, isEmpty)` fails); only the mutation was unnamed: M-PN-ortho, named in MV-2's comment and run here;
  - the non-symbol arm: MV-2's line case is an entity, refused by `n is! InstanceNode`, whose deletion does not compile (`n.parent` and `n.definition` read an `InstanceNode`): a positive control. The parent check (`n.parent != doc.rootHandle`) had no case: PN-MV-nested (an instance of the same attaching definition inside a root group);
  - the node reset (`_sync`'s `_last = null` on a new node within one state): PN-MV-node;
  - the definition's box against the entry's: MV-4 cannot tell them apart (the leaves are unedited); PN-MV-live edits the definition's outline between two asks in one drag's life and expects the live box (`_sync` clears `_boxes` on a new state).
- **D-45, `_open`'s report.** AT-16 cannot see `_open`'s `_reportUnofferedKinds()`: after `newPlan()` the same kind is deduplicated by the log. PN-open makes the new document's providers offer another kind, so `_open` has a new kind to report (the libraries load once, in the constructor, `plan_controller.dart:366`: after `newPlan`, `_open`'s call is the only report).
- **SE8 (C7).** 2b's placement tests pin the copy's unit (`symbol_placer_test.dart` SP-1, M-SP1a) on a quarter-turned, mirrored, off-origin placement, but not SE8's other two lines: the unit survives a save, and one undo step takes it away with the definition. So SE8 is ported, over the plan's placer and a library written as the test kit's unit library is (a `Catalog` of kit `test` with a `CatalogUnit`, `test/support/test_kit.dart:759-818`), with SE8's own table (600 x 400 top, one 300 x 300 seat, base `(300, 500)`, three seats) so its numbers stay. Changes: the key `test.table` → `test.table.plain` (C7 class 1: K2 needs two segments after the kit); `jetcad.seating` → the contract's `jetcad.unit` (2b's successor, 2b spec S2: `SeatingComponent(seats: 3)` → `UnitComponent(kind: UnitKinds.table, capacity: 3)`, the same three seats); `registerAppComponents` → `registerKitComponents`. The component's rename is C7 class 1 by ruling R-P16 (2b's `SeatingComponent` → `UnitComponent(kind: table, capacity: n)` counts as an id change).

- [ ] **Step 1: Precondition.** Task 7 is committed. Run `git status --short` (nothing under `packages/`) and `grep -n "isOrthonormal\|n.parent != doc.rootHandle\|_last = null\|_boxes.clear" packages/jet_cad_2d_plan/lib/src/tools/move_resolver.dart`. Expected: the call `if (!isOrthonormal(t)) return null;` (the function itself is the contract's since Task 1), `n.parent != doc.rootHandle`, two `_last = null;` and one `_boxes.clear();`. Otherwise stop and report.

- [ ] **Step 2: The failing D-44 test.** `packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart`: after KB-14 (`:440`), add:

```dart

  testWidgets(
      'PN-remount (D-44) shortcuts: false remounted on the same controller '
      'keeps the idle keys closed (the new one mounts before the old one is '
      'disposed); of two at once the later speaks, and removed, the earlier '
      'speaks again', (tester) async {
    final c = PlanController(kits: const []);
    addTearDown(c.dispose);
    Widget keys(int n) => MaterialApp(
        home: PlanShortcuts(
            key: ValueKey(n),
            controller: c,
            shortcuts: false,
            child: const SizedBox()));
    await tester.pumpWidget(keys(1));
    expect(c.selectGates.idleKeys, isFalse, reason: 'premise');
    await tester.pumpWidget(keys(2));
    // M-PN-1: `dispose` giving the keys back whoever speaks now.
    expect(c.selectGates.idleKeys, isFalse);
    Widget both({required bool second}) => MaterialApp(
            home: Column(children: [
          PlanShortcuts(
              key: const ValueKey(2),
              controller: c,
              shortcuts: false,
              child: const SizedBox()),
          if (second)
            PlanShortcuts(
                key: const ValueKey(3), controller: c, child: const SizedBox()),
        ]));
    await tester.pumpWidget(both(second: true));
    expect(c.selectGates.idleKeys, isTrue, reason: 'the later speaks');
    await tester.pumpWidget(both(second: false));
    // M-PN-2: a leaving state giving the keys back while another still
    // speaks for the controller.
    expect(c.selectGates.idleKeys, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(c.selectGates.idleKeys, isTrue, reason: 'none left: keys back');
  });
```

  Run `cd packages/jet_cad_2d_plan && flutter test test/shortcuts/plan_shortcuts_test.dart --plain-name PN-remount`. Expected: fails after `keys(2)` (`Expected: false Actual: <true>`).

- [ ] **Step 3: The D-44 fix.** `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart`, `_PlanShortcutsState` (`:63-107`): `initState`, `didUpdateWidget`, `dispose`, `_restoreIdleKeys` and `_applyIdleKeys` become:

```dart
class _PlanShortcutsState extends State<PlanShortcuts> {
  /// Each controller's mounted shortcuts, in mount order: the last one
  /// speaks for the controller's idle keys. A remount mounts the new state
  /// before the old one is disposed (D-44), so the old one's leaving must
  /// not undo the new one's say.
  static final Expando<List<_PlanShortcutsState>> _speakers =
      Expando<List<_PlanShortcutsState>>('plan shortcuts');

  @override
  void initState() {
    super.initState();
    _join(widget.controller);
    widget.controller.addListener(_applyIdleKeys);
    _applyIdleKeys();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PlanLocaleScope.push(context, widget.controller);
  }

  @override
  void didUpdateWidget(PlanShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_applyIdleKeys);
      _leave(oldWidget.controller);
      _join(widget.controller);
      widget.controller.addListener(_applyIdleKeys);
      PlanLocaleScope.push(context, widget.controller);
    }
    _applyIdleKeys();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_applyIdleKeys);
    _leave(widget.controller);
    super.dispose();
  }

  void _join(PlanController c) =>
      (_speakers[c] ??= <_PlanShortcutsState>[]).add(this);

  /// This state no longer speaks for [c]: the shortcuts mounted before it
  /// speak again; with none left, [c]'s select tool gets its idle keys
  /// back (final review), so a removed `shortcuts: false` leaves Delete
  /// and Escape working in the canvas.
  void _leave(PlanController c) {
    final speakers = _speakers[c];
    speakers?.remove(this);
    if (speakers == null || speakers.isEmpty) {
      _speakers[c] = null;
      if (!c.isDisposed) c.selectGates.idleKeys = true;
      return;
    }
    speakers.last._applyIdleKeys();
  }

  /// The select tool's idle keys are the shortcuts (S-16), set by the
  /// shortcuts that speak for the controller (mounted last). The gates
  /// are per document, so this runs again after a swap (the controller
  /// notifies).
  void _applyIdleKeys() {
    final c = widget.controller;
    if (c.isDisposed || !identical(_speakers[c]?.last, this)) return;
    c.selectGates.idleKeys = widget.shortcuts;
  }
```

  (`didChangeDependencies` is unchanged and shown for place; `_restoreIdleKeys` is folded into `_leave`.) Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/shortcuts/`. Expected: `All tests passed!` (PN-remount and KB-14 among them).

- [ ] **Step 4: The registry pins.** `packages/jet_cad_2d_plan/test/attach/attachment_registry_test.dart`: before `void main() {` add:

```dart
/// A provider whose `kind` throws (2a Task 14's deviation 2: the kind is
/// read inside the factory's guard).
final class _NoKind implements AttachmentProvider {
  @override
  String get kind => throw StateError('no kind');
  @override
  Attachment? attach(AttachmentQuery query) => null;
}

/// A provider whose `dispose` throws (deviation 1: a guarded dispose).
final class _BrokenDispose implements AttachmentProvider, Disposable {
  _BrokenDispose(this.kind);
  @override
  final String kind;
  @override
  Attachment? attach(AttachmentQuery query) => null;
  @override
  void dispose() => throw StateError('the $kind provider broke on dispose');
}
```

  and after AT-7, at the end of `main`:

```dart

  test(
      'PN-kind (D-45) a provider whose kind throws adds nothing and reports '
      "hookFailed under 'attachments'", () {
    final r = Rig();
    // M-PN-kind: `kind = provider.kind;` moved out of `add`'s try.
    expect(() => r.registry.add('alpha', (_) => _NoKind(), r.services),
        returnsNormally);
    r.add('beta', RecordingProvider('room-corner', (_) => null));
    expect(r.registry.kinds, {'room-corner'});
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'attachments', KitDiagnosticCode.hookFailed)]);
  });

  test(
      "PN-dispose (D-45) a provider's dispose that throws is reported under "
      'its kind; the others are still disposed, and the registry empties',
      () {
    final r = Rig();
    final healthy = DisposableProvider('room-corner', (_) => null);
    r
      ..add('alpha', _BrokenDispose('wall-face'))
      ..add('beta', healthy);
    // M-PN-dispose: `dispose` calling `disposable.dispose()` bare.
    expect(r.registry.dispose, returnsNormally);
    expect(healthy.disposals, 1);
    expect(r.registry.kinds, isEmpty);
    expect([for (final d in r.reported) (d.kitId, d.subject, d.code)],
        [('alpha', 'wall-face', KitDiagnosticCode.hookFailed)]);
  });
```

  Run `cd packages/jet_cad_2d_plan && flutter test test/attach/attachment_registry_test.dart`. Expected: `All tests passed!` (pins of behaviour that exists; their mutations are in Step 9).

- [ ] **Step 5: The move resolver pins.** `packages/jet_cad_2d_plan/test/tools/move_resolver_test.dart`:
  1. MV-2: before `expect(scaled.resolver.resolveMove(scaled.ctx, scaled.instance, delta),` add the comment `// M-PN-ortho (D-45): \`if (!isOrthonormal(t)) return null;\` deleted in resolveMove: the scaled instance is asked.` (split over two lines); before `final line = addDrafted(` add `// A positive control: an entity is no InstanceNode (that test cannot be deleted and still compile).`.
  2. After MV-4, at the end of `main`, add:

```dart

  test(
      'PN-MV-nested (D-45) an instance of an attaching symbol inside a root '
      'group is not asked: only a root-level instance attaches', () {
    final s = Scene();
    s.answer = (_) => attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    final def = (s.doc.tree[s.instance]! as InstanceNode).definition;
    final group = s.doc.handleSeed.next();
    final nested = s.doc.handleSeed.next();
    s.doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: group,
          parent: s.doc.rootHandle,
          transform: Transform2.translation(98000.5, -71000.25)
              .multiply(Transform2.rotation(0.35)),
          children: const [])),
      AddNodeCommand(InstanceNode(
          handle: nested,
          parent: group,
          transform: Transform2.translation(420.5, -310.25),
          definition: def,
          layer: ReservedHandles.layerZero)),
    ], label: 'Nest'));
    // M-PN-nested: `|| n.parent != doc.rootHandle` deleted in resolveMove.
    expect(s.resolver.resolveMove(s.ctx, nested, delta), isNull);
    expect(s.edge.queries, isEmpty);
    expect(s.asked, 0);
    expect(s.resolver.resolveMove(s.ctx, s.instance, delta), isNotNull,
        reason: 'positive control: the root-level instance is asked');
  });

  test(
      'PN-MV-node (D-45) within one document state, another node starts '
      'afresh: its first query keeps no answer', () {
    final s = Scene();
    final a = attachment(Transform2.translation(99000.5, -69000.25),
        Vector2(99010.25, -69020.5), 'face');
    s.answer = (_) => a;
    s.doc.commands.execute(placeSymbol(s.doc, entry('demo.shelf.wall'),
        at: Vector2(104000.75, -66000.5), quarterTurns: 3));
    final other = s.doc.tree.nodes
        .whereType<InstanceNode>()
        .map((n) => n.handle)
        .singleWhere((h) => h != s.instance);
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    expect(s.edge.queries.last.keep, same(a), reason: 'premise: kept');
    s.resolver.resolveMove(s.ctx, other, delta);
    // M-PN-node: `_sync`'s `_last = null;` under `if (node != _node)`
    // deleted.
    expect(s.edge.queries.last.keep, isNull);
  });

  test(
      "PN-MV-live (D-45) the footprint is the definition's live box: an "
      "outline edited between two asks is read again, not the entry's box",
      () {
    final s = Scene();
    s.answer = (_) => null;
    final def = (s.doc.tree[s.instance]! as InstanceNode).definition;
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    final e = s.doc.entities;
    final outline = [
      for (final slot in e.liveSlots)
        if (e.ownerAt(slot) == def && e.kindAt(slot) == EntityKind.polyline)
          e.handleAt(slot),
    ].single;
    s.doc.commands.execute(SetEntityGeometryCommand(
        outline,
        polylinePayload([
          Vector2(150, 210),
          Vector2(2050.5, 210),
          Vector2(2050.5, 1180.25),
          Vector2(150, 1180.25),
        ], closed: true)));
    final live = boxOfDefinition(s.doc, def)!;
    expect(live, isNot(boxOfEntry(entry('demo.shelf.wall'))),
        reason: "premise: the definition's leaves were edited");
    s.resolver.resolveMove(s.ctx, s.instance, delta);
    final f = s.edge.queries.last.footprint;
    // M-PN-live: `_sync` without `_boxes.clear();`: the first ask's box.
    expect([f.minX, f.minY, f.maxX, f.maxY],
        [live.left, live.front, live.right, live.back]);
  });
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/tools/move_resolver_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 6: The `_open` pin.** `packages/jet_cad_2d_plan/test/controller/attachment_controller_test.dart`, after AT-16 (`:86-110`), add:

```dart

  test(
      "PN-open (D-45) a new plan's providers are checked against the loaded "
      'symbols when it opens: a kind they no longer offer is reported', () async {
    var documents = 0;
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ], attachments: [
        (_) => RecordingProvider(
            ++documents == 1 ? 'test-edge' : 'room-corner', (_) => null),
      ]),
    ]);
    addTearDown(c.dispose);
    await settle();
    List<(String, String?, KitDiagnosticCode)> unoffered() => [
          for (final p in problemsOf(c))
            if (p.$3 == KitDiagnosticCode.attachmentKindUnoffered) p,
        ];
    expect(unoffered(),
        [('demo', 'room-corner', KitDiagnosticCode.attachmentKindUnoffered)],
        reason: 'premise: the first document offers test-edge');
    c.newPlan();
    expect(documents, 2, reason: 'premise: the providers ran again');
    // M-PN-open: `_open` without its `_reportUnofferedKinds()`.
    expect(unoffered(),
        contains(('demo', 'test-edge', KitDiagnosticCode.attachmentKindUnoffered)));
  });
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/controller/attachment_controller_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 7: SE8.** Create `packages/jet_cad_2d_plan/test/symbols/unit_copy_test.dart`. Source: `packages/jet_cad_floor_plan/test/symbols/seating_test.dart` SE8 (`:132-150`) and its fixtures `table` (`:18-33`), `plan` (`:53-58`), `definitionOfOnlyInstance` (`:60-61`). Adaptations as in the plan decision; the assertions otherwise unchanged.

```dart
// D-17's SE8 (spec 3a C7, C1.12; Task 8): jet_cad_floor_plan's
// test/symbols/seating_test.dart SE8, ported over the plan library's
// placer. 2b's SP-1 (symbol_placer_test.dart) pins the copy's unit; SE8
// also pins that it survives a save and goes with the definition in one
// undo step. The library is written as the test kit's unit library is (a
// Catalog of kit "test" with a CatalogUnit), with SE8's own table. 2b
// replaced jetcad.seating with the contract's jetcad.unit (2b spec S2):
// SeatingComponent(seats: 3) is UnitComponent(kind: table, capacity: 3);
// the key test.table is test.table.plain (K2).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogPolyline, CatalogSymbol, CatalogUnit, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 600 x 400 table with one 300 x 300 seat below it, its base point at
/// the top's centre (off the origin); three seats.
SymbolEntry table() => SymbolLibrary.decode(encodeLibrary(Catalog(
      kit: 'test',
      symbols: [
        CatalogSymbol(
          key: 'test.table.plain',
          name: 'Test table',
          category: 'Tests',
          tags: const ['table', 'test'],
          unit: const CatalogUnit(kind: UnitKinds.table, capacity: 3),
          base: (300, 500),
          shapes: const [
            CatalogPolyline([(0, 300), (600, 300), (600, 700), (0, 700)],
                closed: true),
            CatalogPolyline([(150, 0), (450, 0), (450, 300), (150, 300)],
                closed: true),
          ],
        ),
      ],
    ))).entries.single;

DraftDocument plan() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOfOnlyInstance(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().single.definition;

void main() {
  test(
      'SE8 a quarter-turned, mirrored, off-origin placement copies the '
      'seats with the definition, and they survive a save (M-14s-3)', () {
    final entry = table();
    final doc = plan();
    doc.commands.execute(placeSymbol(doc, entry,
        at: Vector2(12345, -6789), quarterTurns: 3, mirrored: true));
    final def = definitionOfOnlyInstance(doc);
    expect(doc.components.get<UnitComponent>(def),
        UnitComponent(kind: UnitKinds.table, capacity: 3));
    final reloaded = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(doc),
        registerComponents: registerKitComponents);
    expect(reloaded.components.get<UnitComponent>(def),
        UnitComponent(kind: UnitKinds.table, capacity: 3));
    // One undo step takes it away with the definition.
    doc.commands.undo();
    expect(doc.components.get<UnitComponent>(def), isNull);
  });
}
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter test test/symbols/unit_copy_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 8: The gates.** `dart format .` first, then from the repository root:
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcuts.dart packages/jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart packages/jet_cad_2d_plan/test/attach/attachment_registry_test.dart packages/jet_cad_2d_plan/test/tools/move_resolver_test.dart packages/jet_cad_2d_plan/test/controller/attachment_controller_test.dart packages/jet_cad_2d_plan/test/symbols/unit_copy_test.dart
git commit -m "$(cat <<'EOF'
fix(plan): the pins 2a parked for sub-project 3 (spec 3a C1.12, D-44, D-45)

PlanShortcuts remounted on the same controller no longer reopens the
select tool's idle keys: the shortcuts mounted last speak for it. Pinned
with mutations: the attachment registry's guarded kind and dispose, the
move resolver's scaled, nested, node-reset and live-box branches, and
_open's unoffered-kind report. seating_test SE8 is ported over the unit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0). Run `cd packages/jet_cad_2d_plan && flutter test <the named file>`.
  - M-PN-1 `lib/src/shortcuts/plan_shortcuts.dart`: in `dispose`, `_leave(widget.controller);` → `if (!widget.controller.isDisposed) widget.controller.selectGates.idleKeys = true;` → PN-remount red (after `keys(2)`).
  - M-PN-2 `plan_shortcuts.dart`: in `_leave`, replace `speakers.last._applyIdleKeys();` with `if (!c.isDisposed) c.selectGates.idleKeys = true;` → PN-remount red (already after `keys(2)`: the old state leaves while the new one speaks, and the keys reopen; the `both(second: false)` check would go red the same way).
  - M-PN-kind `lib/src/attach/attachment_registry.dart`: move `kind = provider.kind;` from inside `add`'s `try` to the line after the `catch` block → PN-kind red (`StateError: no kind` thrown).
  - M-PN-dispose `attachment_registry.dart`: in `dispose`, replace the `try { disposable.dispose(); } catch (e) { ... }` with `disposable.dispose();` → PN-dispose red.
  - M-PN-ortho `lib/src/tools/move_resolver.dart`: delete `if (!isOrthonormal(t)) return null;` → MV-2 red (`scaled.edge.queries` not empty).
  - M-PN-nested `move_resolver.dart`: `if (n is! InstanceNode || n.parent != doc.rootHandle) return null;` → `if (n is! InstanceNode) return null;` → PN-MV-nested red.
  - M-PN-node `move_resolver.dart`: in `_sync`, delete the `_last = null;` inside `if (node != _node) { ... }` → PN-MV-node red (`keep` is `a`).
  - M-PN-live `move_resolver.dart`: in `_sync`, delete `_boxes.clear();` → PN-MV-live red (the unedited box).
  - M-PN-open `lib/src/controller/plan_controller.dart`: delete the `_reportUnofferedKinds();` that ends `_open` → `attachment_controller_test.dart` PN-open red (no `test-edge` report).
  - M-PN-SE8 `lib/src/symbols/symbol_placer.dart`: delete `commands.add(SetComponentCommand<UnitComponent>(copy, unit));` (with its `if`) → `unit_copy_test.dart` SE8 red (and SP-1).

  Quote each red line.

#### Assumed from earlier tasks

- Task 1: `isOrthonormal`, `boxOfDefinition`, `boxOfEntry` are the contract's (`package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, already imported by `move_resolver_test.dart`), and `move_resolver.dart` keeps its `isOrthonormal(t)` call.

---

