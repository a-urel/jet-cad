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

