# Plan — a removed node takes its components

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** deleting a node removes every component on its handle
(registered and preserve-unknown), and undo restores them exactly, with
the node back at its index; plans stay schema 9.

**Spec:** [2026-10-09-node-components-on-delete-design.md](../specs/2026-10-09-node-components-on-delete-design.md),
**revision 3** (`c307166`), approved by the human on 2026-10-10
(*"approved, write the plan"*). It closes the host embedding API spec's
**O-8**. Every fact, decision, invariant and named mutant (M-1 to M-17)
this plan cites is the spec's; read it beside this plan.

**Branch:** `fix/node-components-on-delete`, cut from
`spec/node-components-on-delete` at this plan's commit (the spec's three
revisions and this plan, on `main` at `e281372`).

**Ledger:** `.superpowers/sdd/2026-10-09-node-components-on-delete/`
(git-ignored; it already holds the spec review): `task-<n>-report.md`,
`task-<n>-review.md`, archived to `docs/superpowers/ledgers/` on merge.

**Architecture:** the fix lives in the engine's two node commands, as
`RemoveDefinitionCommand` already does for definitions:
`RemoveNodeCommand` snapshots the handle's components, detaches them all,
and hands the snapshot to its inverse; `AddNodeCommand` checks the
snapshot is restorable before anything mutates, adds the node, then
restores it. The parametric planner's detaches become no-ops and go
(D-4); the 0.4.0 table-data expander becomes dead code and goes (D-7),
with TD10 rewritten so the table system's rollback stays pinned.

**Tech stack:** Dart 3, `package:test` (engine), `flutter_test`
(render, planner). Flutter 3.47.6 (`/opt/homebrew/bin/flutter`).

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`) and every image
  golden stay untouched. **Draw order stays ascending handle value**:
  nothing here touches the spatial index, the tile cache or a painter.
- **Additive API only.** `AddNodeCommand` gains an optional named
  `components` (default `ComponentSnapshot.empty`); `ComponentRegistry`
  gains `checkRestorable`. No signature, `==`, `hashCode` or `toString`
  changes otherwise. `AddNodeCommand(node)` and
  `AddNodeCommand(node, index: i)` keep their meaning.
- **`capability` (the summary) stays `structure`** on both node commands
  (D-2): `SpatialIndex`, `TileCache` and `CompoundCommand.capability`
  read what they read today. Only `capabilities` (the set) changes.
- **Existing tests pass unedited**, with these named exceptions and
  nothing else:
  - Task 1: `jet_cad_2d/test/document/compound_command_test.dart`
    *"capabilities is the union of the children's"* (`:300-313`, the
    expected set gains `Capability.components`); `test/parametric/`
    `cascade_test.dart` CS7 (`:405-431`) and LV2 (`:773-800`),
    `objects_of_test.dart` OB1 (`:122-124`), `misplaced_test.dart` MP6
    (`:246-249`), `dissolve_test.dart` DV1 (`:214-238`, `:290-298`),
    `page_test.dart` PG1 (`:205-228`). The spike at `e281372` saw exactly
    these seven go red under D-1 (spec F-14).
  - Task 2: `jet_cad_floor_plan/test/tables/table_data_test.dart` TD8's
    and TD9's titles, TD10 (rewritten) and `_RefusingTarget` (rewritten
    with TD10).

  Any other test that has to change is a finding for the task's report,
  not an edit to make.
- **Fixtures are never degenerate** (spec, *Testing*): the removed node
  is not the first handle, sits under a non-root parent at a
  non-identity transform and not last among its parent's `children`,
  carries two registered components with non-default values and two
  unknown payloads attached out of type-id order; a sibling carries the
  same types with other values. Snapshots in all-or-nothing tests are
  non-empty.
- **Each named mutant is applied, seen red, and reverted** from a saved
  copy (`cp file /tmp/x.bak` … `cp /tmp/x.bak file`), **never
  `git checkout`**. The report names each mutant, its killing test, and
  the line of output that shows it red. Every mutant belongs to exactly
  one task.
- **Never synthesize test output.** Paste real output into reports.
- **Never commit an `analysis_options.yaml`**: `flutter pub get` rewrites
  three. Check `git status` before each commit.
- **Gates, every task**, in every package it touches and every package
  that depends on one it changed:
  - `packages/jet_cad_2d`: `dart test`, `dart analyze --fatal-infos`,
    `dart format --output=none --set-exit-if-changed .`;
  - `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d_gpu`,
    `packages/jet_cad_restaurant_symbols`, `apps/floor_planner`,
    `apps/restaurant_demo`: `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice`
    (the pick allocation test needs it, as CI passes it), analyze, format.
- **Standing failures on this machine (macOS), measured at `e281372`:**
  `jet_cad_2d`'s two `generate_document_test` fingerprints and
  `jet_cad_2d_flutter`'s five text-ladder goldens. Anything else red is a
  finding. CI on Linux compares its own lists exactly
  (`tool/ci/standing_failures.txt`); the branch's CI run is the check of
  record for those.

## Review focus

Inputs the spec implies that a person will meet, most likely first; each
has its test in the owning task.

1. **Delete then Undo of a wall that hosts a door**, in the planner: the
   door goes with the wall (08 D4's cascade) and both come back exactly,
   parameters and layers included. Task 2, **P-3**.
2. **Delete then Undo of a group holding a nested group and an
   instance**, each carrying data (registered and a newer release's
   unknown payload): one undo step, all three exact. Task 1, **S-1**.
3. **A plan saved by 0.4.0 or earlier with orphaned entries** opens and
   saves byte for byte, orphans kept. Task 1, **N-7**.
4. **A delete that fails part-way** (a compound whose later removal
   throws) leaves every component where it was. Task 1, **N-5**.
5. **A permission profile that allows structure but not components**: a
   delete is refused and the key stays selected; an add is allowed but
   its undo is refused and stays on the stack. Task 1, **N-3**.

---

### Task 1: the engine — the node commands carry components (D-1 to D-4)

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/component.dart`
  (`checkRestorable`; `restore` calls it; `restore`'s doc)
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
  (`AddNodeCommand`, `RemoveNodeCommand`, their docs)
- Modify: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
  (D-4: the cleanup, the dissolve's detaches, `_detachLayer`, docs)
- Modify: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`
  (docs only, `:386-392`, `:442-446`, `:598-604`)
- Create: `packages/jet_cad_2d/test/document/node_components_test.dart`
- Modify (re-pin, named above): `test/document/compound_command_test.dart`,
  `test/parametric/{cascade,objects_of,misplaced,dissolve,page}_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/select_tool_test.dart` (S-1)

**Interfaces:**
- Produces:
  - `void ComponentRegistry.checkRestorable(Handle handle, ComponentSnapshot snapshot)`
    — throws `StateError` (the message `restore` throws today) when a
    registered type id of [snapshot] maps to no store; writes nothing.
  - `AddNodeCommand(Node node, {int? index, ComponentSnapshot? components})`,
    `final ComponentSnapshot components` (never null; empty by default),
    `Set<Capability> get capabilities` = `{structure}` when empty, else
    `{structure, components}`.
  - `RemoveNodeCommand.capabilities` = `{structure, components}` (static);
    its inverse is `AddNodeCommand(node, index: i, components: snapshot)`.

- [ ] **Step 1: the new engine tests, failing.** Create
  `packages/jet_cad_2d/test/document/node_components_test.dart`:

```dart
// Spec "A removed node takes its components" (revision 3), N-1 to N-7:
// RemoveNodeCommand takes every component of its handle, registered and
// unknown, and its inverse puts them back exactly, the node at its index.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A registered test type with two non-default fields.
final class Mark implements Component {
  static const String id = 'test.mark';
  const Mark(this.count, this.label);
  final int count;
  final String label;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'count': count, 'label': label};
  static Mark fromJson(Map<String, Object?> j) =>
      Mark(j['count']! as int, j['label']! as String);
  @override
  bool operator ==(Object other) =>
      other is Mark && other.count == count && other.label == label;
  @override
  int get hashCode => Object.hash(count, label);
}

/// Registered only in a second document: a type this one does not map.
/// Its id sorts after `jet_cad.object_layer` (spec N-4, M-16).
final class Foreign implements Component {
  static const String id = 'test.foreign';
  const Foreign();
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => const {'f': 1};
  static Foreign fromJson(Map<String, Object?> j) => const Foreign();
  @override
  bool operator ==(Object other) => other is Foreign;
  @override
  int get hashCode => 1;
}

/// Not layer 0, which is what an absent ObjectLayer reads as.
const Handle kLayer = Handle(0x2A1);

/// Unknown payloads, attached `later` first: not in type-id order.
Map<String, Object?> later() => {
      'typeId': 'z.later',
      'nested': {
        'k': [1, 2.5]
      },
      'note': 'kept verbatim',
    };
Map<String, Object?> earlier() => {'typeId': 'a.earlier', 'v': -3};

typedef Scene = ({
  DraftDocument doc,
  Handle parent,
  Handle node,
  Handle sibling,
  Handle last,
});

/// A group [parent] 40 m off the origin, turned, holding [node], [sibling]
/// and [last] in that order (not ascending: [sibling] < [node]). [node]
/// carries Mark, ObjectLayer and two unknown payloads; [sibling] Mark,
/// ObjectLayer and one unknown payload, with other values. History cleared.
Scene scene() {
  final doc = DraftDocument.empty();
  doc.components.register<Mark>(Mark.id, Mark.fromJson);
  final parent = doc.handleSeed.next();
  final sibling = doc.handleSeed.next();
  final node = doc.handleSeed.next();
  final last = doc.handleSeed.next();
  GroupNode group(Handle h, Handle p, Transform2 t) =>
      GroupNode(handle: h, parent: p, transform: t, children: const []);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(group(
        parent,
        doc.rootHandle,
        Transform2.translation(4e4, -2.7e4)
            .multiply(Transform2.rotation(0.6)))),
    AddNodeCommand(group(node, parent,
        Transform2.translation(310, -925).multiply(Transform2.rotation(-1.1)))),
    AddNodeCommand(group(sibling, parent, Transform2.translation(-75, 40))),
    AddNodeCommand(group(last, parent, Transform2.translation(12, 13))),
    SetComponentCommand<Mark>(node, const Mark(7, 'north')),
    SetComponentCommand<ObjectLayer>(node, const ObjectLayer(kLayer)),
    SetComponentCommand<Mark>(sibling, const Mark(3, 'south')),
    SetComponentCommand<ObjectLayer>(sibling, const ObjectLayer(kLayer)),
  ], label: 'Fixture'));
  doc.components
    ..attachUnknown(node, later())
    ..attachUnknown(node, earlier())
    ..attachUnknown(sibling, earlier());
  doc.commands.clearHistory();
  return (
    doc: doc,
    parent: parent,
    node: node,
    sibling: sibling,
    last: last
  );
}

String enc(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

List<Handle> childrenOf(DraftDocument doc, Handle g) =>
    (doc.tree[g]! as GroupNode).children;

/// Snapshots compared field by field: registered `==` in order, unknown
/// payloads by their JSON in order.
void expectSameSnapshot(ComponentSnapshot actual, ComponentSnapshot expected) {
  expect([for (final (id, _) in actual.components) id],
      [for (final (id, _) in expected.components) id]);
  expect([for (final (_, c) in actual.components) c],
      [for (final (_, c) in expected.components) c]);
  expect(jsonEncode(actual.unknown), jsonEncode(expected.unknown));
}

bool namesHandle(DraftDocument doc, Handle h) => doc.components
    .toJson()
    .values
    .any((perType) => (perType! as Map).containsKey('${h.value}'));

const DraftPermissions kNoComponents = DraftPermissions(
    transform: true, components: false, geometry: true, structure: true);

void main() {
  test('N-1 a removal takes every component of its handle, no other', () {
    final s = scene();
    final doc = s.doc;
    final siblingBefore = doc.components.snapshotOf(s.sibling);
    expect(doc.components.unknownOf(s.node), hasLength(2), reason: 'premise');

    doc.commands.execute(RemoveNodeCommand(s.node));

    expect(doc.tree[s.node], isNull);
    expect(doc.components.get<Mark>(s.node), isNull);
    expect(doc.components.get<ObjectLayer>(s.node), isNull);
    expect(doc.components.unknownOf(s.node), isEmpty);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    expect(namesHandle(doc, s.node), isFalse);
    expectSameSnapshot(doc.components.snapshotOf(s.sibling), siblingBefore);
  });

  test('N-2 undo restores the snapshot and the index byte for byte; redo '
      'removes them again', () {
    final s = scene();
    final doc = s.doc;
    final before = enc(doc);
    final snapshot = doc.components.snapshotOf(s.node);
    final order = childrenOf(doc, s.parent);
    expect(order.indexOf(s.node), 0, reason: 'premise: not the append');

    doc.commands.execute(RemoveNodeCommand(s.node));
    final removed = enc(doc);
    doc.commands.undo();
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
    expect(childrenOf(doc, s.parent), order);
    expect(enc(doc), before);
    doc.commands.redo();
    expect(enc(doc), removed);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    doc.commands.undo();
    expect(enc(doc), before);
  });

  test('N-3 capabilities, and a profile without components', () {
    final s = scene();
    final doc = s.doc;
    final remove = RemoveNodeCommand(s.node);
    expect(remove.capabilities, {Capability.structure, Capability.components});
    expect(remove.capability, Capability.structure);
    final bare = AddNodeCommand(GroupNode(
        handle: const Handle(0x9000),
        parent: s.parent,
        transform: Transform2.identity(),
        children: const []));
    expect(bare.capabilities, {Capability.structure});
    final carrying = AddNodeCommand(bare.node,
        components: doc.components.snapshotOf(s.sibling));
    expect(carrying.capabilities, {Capability.structure, Capability.components});
    expect(carrying.capability, Capability.structure);

    doc.commands.permissions = kNoComponents;
    final before = enc(doc);
    expect(() => doc.commands.execute(RemoveNodeCommand(s.node)),
        throwsA(isA<PermissionDeniedError>()));
    expect(enc(doc), before);

    // D-2: an add is allowed, its undo (a removal) is not, and stays.
    doc.commands.execute(bare);
    final depth = doc.commands.undoDepth;
    expect(() => doc.commands.undo(), throwsA(isA<PermissionDeniedError>()));
    expect(doc.commands.undoDepth, depth);
    expect(doc.tree[bare.node.handle], isNotNull);
  });

  group('N-4 a refused add leaves everything as it was', () {
    /// A snapshot from a second document: ObjectLayer (mapped here) and
    /// Foreign (not mapped here), plus an unknown payload.
    ComponentSnapshot foreignSnapshot() {
      final other = DraftDocument.empty();
      other.components.register<Foreign>(Foreign.id, Foreign.fromJson);
      final h = other.handleSeed.next();
      other.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: other.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<ObjectLayer>(h, const ObjectLayer(kLayer)),
        SetComponentCommand<Foreign>(h, const Foreign()),
      ], label: 'Other'));
      other.components.attachUnknown(h, later());
      final snap = other.components.snapshotOf(h);
      expect([for (final (id, _) in snap.components) id],
          ['jet_cad.object_layer', 'test.foreign'],
          reason: 'premise: the mapped type sorts first');
      return snap;
    }

    void expectNothingOn(DraftDocument doc, Handle h) {
      expect(doc.tree[h], isNull);
      expect(doc.components.snapshotOf(h).isEmpty, isTrue);
    }

    test('an unmapped type id, the mapped one sorting first', () {
      final s = scene();
      final doc = s.doc;
      final before = enc(doc);
      final order = childrenOf(doc, s.parent);
      final h = doc.handleSeed.next();
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: h,
                  parent: s.parent,
                  transform: Transform2.translation(5, 6),
                  children: const []),
              components: foreignSnapshot())),
          throwsA(isA<StateError>()));
      expectNothingOn(doc, h);
      expect(childrenOf(doc, s.parent), order);
      expect(enc(doc), before);
      expect(doc.commands.undoDepth, 0);
    });

    test('the same under a parent that already lists the handle, the raw '
        'list compared (the encoder filters a dangling entry)', () {
      final s = scene();
      final doc = s.doc;
      final g = doc.handleSeed.next();
      final x = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: g,
          parent: doc.rootHandle,
          transform: Transform2.translation(-3e3, 2e3),
          children: [x])));
      expect(childrenOf(doc, g), [x], reason: 'premise: dangling entry');
      expect(doc.tree[x], isNull, reason: 'premise');
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: x,
                  parent: g,
                  transform: Transform2.identity(),
                  children: const []),
              components: foreignSnapshot())),
          throwsA(isA<StateError>()));
      expect(childrenOf(doc, g), [x], reason: 'M-14: the raw list kept');
      expectNothingOn(doc, x);
    });

    test('a definition cycle, with a mapped snapshot', () {
      final s = scene();
      final doc = s.doc;
      final d = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(Definition(
          handle: d,
          name: 'D',
          basePoint: Vector2(40, 30),
          children: const [])));
      final i = doc.handleSeed.next();
      expect(
          () => doc.commands.execute(AddNodeCommand(
              InstanceNode(
                  handle: i,
                  parent: d,
                  transform: Transform2.rotation(math.pi / 2),
                  definition: d,
                  layer: ReservedHandles.layerZero),
              components: doc.components.snapshotOf(s.sibling))),
          throwsA(isA<CycleDetectedError>()));
      expectNothingOn(doc, i);
    });

    test('an index out of range, with a mapped snapshot', () {
      final s = scene();
      final doc = s.doc;
      final before = enc(doc);
      final h = doc.handleSeed.next();
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: h,
                  parent: s.parent,
                  transform: Transform2.identity(),
                  children: const []),
              index: 99,
              components: doc.components.snapshotOf(s.sibling))),
          throwsA(isA<RangeError>()));
      expectNothingOn(doc, h);
      expect(enc(doc), before);
    });
  });

  test('N-5 a compound delete whose second removal fails rolls the first '
      'back with its components', () {
    final s = scene();
    final doc = s.doc;
    final before = enc(doc);
    final snapshot = doc.components.snapshotOf(s.node);
    expect(
        () => doc.commands.execute(CompoundCommand(
            [RemoveNodeCommand(s.node), RemoveNodeCommand(const Handle(0xDEAD))],
            label: 'Delete')),
        throwsA(isA<StateError>()));
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
    expect(enc(doc), before);
  });

  test('N-6 re-parent: bare drops the components, carrying keeps them, '
      'unknown order included', () {
    final s = scene();
    final doc = s.doc;
    final snapshot = doc.components.snapshotOf(s.node);
    final moved = GroupNode(
        handle: s.node,
        parent: s.last,
        transform: Transform2.translation(1, 2),
        children: const []);

    doc.commands.execute(CompoundCommand(
        [RemoveNodeCommand(s.node), AddNodeCommand(moved)],
        label: 'Re-parent, bare'));
    expect(doc.tree[s.node]!.parent, s.last);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    doc.commands.undo();

    doc.commands.execute(CompoundCommand([
      RemoveNodeCommand(s.node),
      AddNodeCommand(moved, components: doc.components.snapshotOf(s.node)),
    ], label: 'Re-parent'));
    expect(doc.tree[s.node]!.parent, s.last);
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
  });

  test('N-7 a plan carrying orphans loads and saves byte for byte', () {
    final s = scene();
    final doc = s.doc;
    const dead = Handle(0x7777);
    doc.components.attach<Mark>(dead, const Mark(9, 'orphan'));
    doc.components.attachUnknown(dead, later());
    expect(doc.tree[dead], isNull, reason: 'premise: names nothing');
    final json = enc(doc);
    final loaded = DraftDocumentCodec.decodeString(json,
        registerComponents: (r) => r.register<Mark>(Mark.id, Mark.fromJson));
    expect(loaded.components.get<Mark>(dead), const Mark(9, 'orphan'));
    expect(enc(loaded), json);
  });
}
```

- [ ] **Step 2: run them and see them fail.**
  Run: `cd packages/jet_cad_2d && dart test test/document/node_components_test.dart`
  Expected: compile errors first (`components:` is not a parameter of
  `AddNodeCommand`). Note it in the report; the failures to see red come
  after Step 3 of each mutant, below.

- [ ] **Step 3: `checkRestorable`.** In `component.dart`, split the
  check out of `restore` and have `restore` call it:

```dart
  /// Throws [StateError] when a registered type id of [snapshot] maps to
  /// no store in this registry, and writes nothing: the check [restore]
  /// makes before its first write, for a caller that must make it before
  /// any other mutation (`AddNodeCommand`, spec D-1). Only a snapshot from
  /// another document can fail it.
  void checkRestorable(Handle handle, ComponentSnapshot snapshot) {
    for (final (typeId, _) in snapshot.components) {
      if (_stores[_typeOf[typeId]] == null) {
        throw StateError('cannot restore $typeId on ${handle.toHex()}: '
            'the type is not registered');
      }
    }
  }

  /// Re-attaches each component of [snapshot] to [handle], exactly: …
  /// (keep the existing paragraph; change its last sentence to:) Meant for
  /// a handle that carries nothing, which is how `RemoveDefinitionCommand`'s
  /// and `RemoveNodeCommand`'s inverses use it: on a handle that already
  /// carries unknown payloads, the snapshot's are appended after them, and
  /// the encoding keeps only the last payload per type id and handle.
  ///
  /// All-or-nothing: [checkRestorable] runs first, before anything is
  /// written.
  void restore(Handle handle, ComponentSnapshot snapshot) {
    checkRestorable(handle, snapshot);
    for (final (typeId, component) in snapshot.components) {
      _stores[_typeOf[typeId]]!.set(handle, component);
    }
    for (final payload in snapshot.unknown) {
      attachUnknown(handle, payload);
    }
  }
```

- [ ] **Step 4: the node commands.** In `commands.dart`:

```dart
class AddNodeCommand extends DraftCommand {
  final Node node;
  final int? index;

  /// What `RemoveNodeCommand`'s inverse puts back on the handle with the
  /// node (spec "A removed node takes its components", D-1); empty for an
  /// ordinary add. A re-parent built by hand carries
  /// `components.snapshotOf(handle)`, read when the compound is built
  /// (D-3); without it the re-added node starts empty.
  final ComponentSnapshot components;

  AddNodeCommand(this.node, {this.index, ComponentSnapshot? components})
      : components = components ?? ComponentSnapshot.empty;

  @override
  Capability get capability => Capability.structure;

  /// `{structure}`, plus `components` when [components] is not empty (D-2).
  @override
  Set<Capability> get capabilities => components.isEmpty
      ? const {Capability.structure}
      : const {Capability.structure, Capability.components};

  @override
  String get label => 'Add node';

  @override
  CommandResult apply(CommandTarget target) {
    if (target.tree[node.handle] != null ||
        target.entities.containsHandle(node.handle)) {
      throw DuplicateHandleError(node.handle);
    }
    // Every refusal before the first write (D-1): the snapshot's types,
    // then the tree's own (cycle, index), then the writes.
    target.components.checkRestorable(node.handle, components);
    target.tree.addNode(node, index: index);
    target.components.restore(node.handle, components);
    target.handleSeed.raiseTo(node.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: RemoveNodeCommand(node.handle),
      touched: {node.handle},
    );
  }
}
```

  and in `RemoveNodeCommand`:

```dart
  /// Static, as `RemoveDefinitionCommand`'s (spec 09c W-1): the dispatcher
  /// checks before [apply], when the handle's components are not known.
  @override
  Set<Capability> get capabilities =>
      const {Capability.structure, Capability.components};

  @override
  CommandResult apply(CommandTarget target) {
    final node = target.tree[handle];
    if (node == null) {
      throw StateError('no node with handle ${handle.toHex()}');
    }
    final index = target.tree.indexInParent(handle);
    final components = target.components.snapshotOf(handle);
    target.tree.removeNode(handle);
    target.components.detachAll(handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddNodeCommand(node, index: index, components: components),
      touched: {handle},
    );
  }
```

  Rewrite both class docs: `RemoveNodeCommand` removes the node **and
  every component on its handle** (registered and unknown), its inverse
  carrying the node, its index and the snapshot; `AddNodeCommand`'s doc
  gains the order of refusals and the `components` paragraph.

- [ ] **Step 5: D-4, the planner stops planning detaches.** In
  `regeneration.dart`:
  - delete `_detachLayer` and its doc (`:483-490`);
  - in `_plan`, the dissolve becomes
    `out.addAll(_subtreeRemoval(t, s, h)); continue;` (drop
    `..add(registration.detach(h))..addAll(_detachLayer(t, h))`), and its
    doc (`:540-551`) says the removal takes the dissolving object's
    component and layer with its node (spec D-4), so nothing else is
    planned;
  - in `_run`, delete `final List<DraftCommand> cleanup;` and its
    assignment (`:976-983`, with the 12b comment above it); keep `lost`
    and its Ruling 06-3 comment; `if (seeds.isEmpty && cleanup.isEmpty)`
    becomes `if (seeds.isEmpty)`; `for (final c in [...cleanup, ...plan])`
    becomes `for (final c in plan)`;
  - rewrite the docs that name the cleanup: `_run`'s list (step 5 and the
    paragraph after it, `:913-932`), `_written`'s list (`:686-708`: a
    delete no longer keeps the component until a cleanup; the removal
    takes it), and `parametric_system.dart:386-392, 442-446, 598-604` (an
    object an edit lost no longer keeps its component until a cleanup; a
    re-parented one keeps it only when the re-add carries the snapshot).

- [ ] **Step 6: re-pin the seven named tests**, wording kept but for
  what the spec changes:
  - `compound_command_test.dart:306-307`: expected
    `{Capability.transform, Capability.geometry, Capability.structure, Capability.components}`
    (the comment names spec D-2's static set).
  - CS7 and LV2: the re-add carries the snapshot, read when the compound
    is built (D-3):

```dart
    doc.commands.execute(CompoundCommand([
      RemoveNodeCommand(hA),
      AddNodeCommand(
          GroupNode(handle: hA, parent: g, transform: atA, children: const []),
          components: doc.components.snapshotOf(hA)),
    ], label: 'Re-parent'));
```

  - OB1: the same for `h5300`'s re-add.
  - MP6 (`:246-249`): removing the nested group now detaches its Hinge
    (D-4, Ruling 06-3's cost shrinks):

```dart
    doc.commands.execute(RemoveNodeCommand(s.nested));
    expect(doc.commands.undoDepth, ++depth);
    expect(doc.components.get<Hinge>(s.nested), isNull,
        reason: 'the node takes its component (node-components spec D-4)');
    doc.commands.undo();
    expect(doc.components.get<Hinge>(s.nested), const Hinge(true));
    doc.commands.redo();
```

    then the test's remaining lines unchanged (the line's Hinge still
    refuses a new value).
  - DV1 and PG1: the restore travels in the node's snapshot, not in a
    `SetComponentCommand`. Add to each file, beside `flatten`:

```dart
/// The [T] values the [AddNodeCommand]s on [h] inside [c] restore.
List<T> restoredBy<T extends Component>(DraftCommand c, Handle h) => [
      for (final k in flatten(c))
        if (k is AddNodeCommand && k.node.handle == h)
          for (final (_, v) in k.components.components)
            if (v is T) v,
    ];
```

    DV1: `expect(fuseSets(undoReplay), isEmpty)` and
    `expect(restoredBy<Fuse>(undoReplay, hF), [fuse])`;
    `expect(fuseSets(redoReplay), isEmpty)`; the order list loses its
    last entry (`'detach ${hF.value}'`): entities, then `'node ${hF.value}'`;
    the delete: `expect(fuseSets(deleteReplay), isEmpty)` and
    `expect(restoredBy<Fuse>(deleteReplay, hF), [fuse])`.
    PG1: `restores` becomes `restoredBy<Gauge>(result.inverse, hG2)`,
    still `[gauge2]`, and a new `expect` that no
    `SetComponentCommand<Gauge>` on `hG2` is in `result.inverse`.
    Comments that say "detached once (06 D8)" say "taken by the removal
    (node-components D-4)".

- [ ] **Step 7: S-1, the select tool's Delete.** In
  `packages/jet_cad_2d_flutter/test/select_tool_test.dart`, in
  `group('keys and delete')`:

```dart
    test('S-1 Delete takes the components of an instance and of a group '
        'holding a nested group; one undo step restores all three', () {
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, 'Chair');
      final instance = addInstance(doc, def,
          Transform2.translation(700, -350).multiply(Transform2.rotation(0.4)));
      final outer =
          addGroup(doc, doc.rootHandle, Transform2.translation(-900, 260));
      final nested = addGroup(doc, outer, Transform2.rotation(-0.7));
      const layer = Handle(0x2B3);
      doc.commands.execute(CompoundCommand([
        SetComponentCommand<ObjectLayer>(instance, const ObjectLayer(layer)),
        SetComponentCommand<ObjectLayer>(outer, const ObjectLayer(layer)),
        SetComponentCommand<ObjectLayer>(nested, const ObjectLayer(layer)),
      ], label: 'Fixture'));
      for (final h in [instance, outer, nested]) {
        doc.components
          ..attachUnknown(h, {'typeId': 'z.later', 'h': h.value})
          ..attachUnknown(h, {'typeId': 'a.earlier'});
      }
      final before = DraftDocumentCodec.encodeToString(doc);
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final selection = SelectionController(doc);
      addTearDown(selection.dispose);
      final camera = cameraAt(2.0, const Offset(-1600, 1300));
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      final depth = doc.commands.undoDepth;
      selection.replace([SelectionKey.root(instance), SelectionKey.root(outer)]);

      expect(SelectTool().onKey(_deleteDown(), ctx), KeyEventResult.handled);

      expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
      for (final h in [instance, outer, nested]) {
        expect(doc.tree[h], isNull);
        expect(doc.components.snapshotOf(h).isEmpty, isTrue,
            reason: '${h.toHex()} keeps nothing');
      }
      final deleted = DraftDocumentCodec.encodeToString(doc);
      doc.commands.undo();
      expect(DraftDocumentCodec.encodeToString(doc), before);
      doc.commands.redo();
      expect(DraftDocumentCodec.encodeToString(doc), deleted);
    });
```

- [ ] **Step 8: run the engine and render suites.**
  Run: `cd packages/jet_cad_2d && dart test`
  Expected: all pass but the two standing `generate_document_test`
  fingerprints. Then `cd ../jet_cad_2d_flutter && flutter test`:
  all pass but the five text-ladder goldens.

- [ ] **Step 9: the mutants.** Apply each alone, run the named tests,
  see red, restore from the copy:

| Mutant | Edit | Killed by |
|---|---|---|
| M-1 | drop `target.components.detachAll(handle);` in `RemoveNodeCommand` | N-1, S-1 |
| M-2 | the inverse built without `components:` | N-2, S-1 |
| M-3 | `snapshotOf` moved after `detachAll` | N-2 |
| M-4 | `detachAll` drops `_stores` only, not `_unknown` | N-1 |
| M-5 | `restore` appends `snapshot.unknown.reversed` | N-2, N-6 |
| M-6 | `detachAll(handle)` replaced by `clear()` | N-1 (sibling) |
| M-7 | `RemoveNodeCommand.capabilities` deleted (inherits `{structure}`) | N-3 |
| M-8 | `AddNodeCommand.capabilities` deleted | N-3 |
| M-9 | `restore` moved before `tree.addNode`, no check | N-4 (cycle, index) |
| M-10 | `checkRestorable` line deleted in `AddNodeCommand` | N-4 (unmapped) |
| M-11 | the dissolve's `registration.detach(h)` put back | DV1 |
| M-12 | the cleanup list put back and applied | PG1 |
| M-13 | `loadJson` skips a handle whose key is not in the tree (a sweep, in `DraftDocumentCodec.decode` after the tree is read) | N-7 |
| M-14 | revision 1's rollback: no check; `try { restore } catch (_) { tree.removeNode(h); rethrow; }` | N-4 (dangling) |
| M-15 | the inverse built without `index:` | N-2 |
| M-16 | `checkRestorable` `break`s after the first entry | N-4 (unmapped, mapped first) |

- [ ] **Step 10: every gate** of the Global constraints, in
  `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`,
  `jet_cad_floor_plan` (`--enable-vmservice`; TD7 to TD10 and HD12 stay
  green here: the expander is still installed), `jet_cad_restaurant_symbols`,
  `apps/floor_planner`, `apps/restaurant_demo`. Paste each summary line.

- [ ] **Step 11: commit.**

```bash
git add packages/jet_cad_2d packages/jet_cad_2d_flutter/test/select_tool_test.dart
git status --short   # no analysis_options.yaml
git commit -m "feat(engine): a removed node takes its components (node-components D-1 to D-4)"
```

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

### Task 3: docs, results and the record

**Files:**
- Modify: `CHANGELOG.md` (**Unreleased**)
- Create: `docs/superpowers/notes/2026-10-10-node-components-results.md`
- Modify: `STATUS.md` (In flight)
- Modify: the spec's status line (implemented, the branch)

- [ ] **Step 1: CHANGELOG, Unreleased** (replacing *"Nothing yet."*):

```markdown
- **Deleting a node removes everything attached to it.** A deleted
  group's, nested group's or instance's components — including data a
  newer release wrote — now go with it, as a table's host data already
  did in 0.4.0; Undo brings them back exactly. Plans are unchanged
  (schema 9): orphaned entries an older release left in a plan load and
  save as they are.
- **For code that builds commands by hand:** `RemoveNodeCommand` now
  declares `{structure, components}`, so a permission profile that denies
  components refuses a node delete (and the undo of a node add). A
  re-parent built as `RemoveNodeCommand` then `AddNodeCommand` must pass
  `components: doc.components.snapshotOf(handle)` to the re-add to keep
  the node's components; without it the node comes back empty.
```

- [ ] **Step 2: the results note.** Record: the spec and plan; each
  task's commits; the gate summaries; every mutant M-1 to M-17 with its
  killing test and the red line; the tests re-pinned and why; what
  discharges the host embedding spec's F-14, Slice 2 orphaning note and
  **O-8**, and that its line on walls and rooms orphaning
  (`host-embedding-api-design.md:587-589`) overstated (spec F-8); the
  out-of-scope items O-1 to O-7 unchanged.

- [ ] **Step 3: STATUS.** The In flight entry names the plan, the
  branch, the results note and the next step (the human's look, then
  the merge on their word; the ledger archived onto the branch before the
  merge).

- [ ] **Step 4: commit.**

```bash
git add CHANGELOG.md STATUS.md docs/superpowers
git commit -m "docs: node-components results, CHANGELOG and STATUS"
```

## After the tasks

A whole-branch review by a fresh reviewer, its fixes, then the ledger
archived to `docs/superpowers/ledgers/2026-10-09-node-components-on-delete/`
as the branch's last commit. Merge into `main` and push only on the
human's word.
