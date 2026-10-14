### Task 2: Engine E5, the guard, seeding, adds and the dissolve gap; CHANGELOG; the rooms spec amendment (spec S1 "The guard", "The dissolve gap closes", "Version")

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`, `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` (`GeneratedGeometryError`'s doc comment only), `packages/jet_cad_2d/CHANGELOG.md`
- Modify: `packages/jet_cad_2d/test/parametric/cascade_test.dart` (CS11's fixture, controller ruling R-4)
- Modify: `docs/superpowers/specs/2026-09-26-rooms-design.md` (one amendment line under D12)
- Test: `packages/jet_cad_2d/test/parametric/instance_guard_test.dart`

(Paths below are under `packages/jet_cad_2d/` unless they start at the repository root.)

**Interfaces:**
- Consumes (Task 1's code; find each site by the code quoted):
  - `_Survey.instances` (object → generated `InstanceNode`s, ascending), `_Survey.generated` (instance handle → its node value; its object is `node.parent`), `_Survey.leaves` (instance → its entities, ascending), `_Survey.owned` (now including generated ATTRIBs → their object).
  - `_survey`'s instance loop (`for (final c in (t.tree[h]! as GroupNode).children) { … }`).
  - `_refused` (`regeneration.dart`, at `7f6add5d` `:664-693`), `_subtreeRemoval` (`:836-912`), `_run`'s refusal branch (`:973-977`) and seeds (`:1015-1022`).
  - Task 1's test support `test/parametric/support/row_clients.dart`: `hall()`, `rowDoc()`, `seats`, `leavesOf`, `labelsOf`, `recordOf`, `payloadOf`, `enc`, `canon`, `drift`, `loadedWith`, `applying`, `addLayer`, `resetRowCalls`, `rowGenerateCalls`, `rowInstanceCalls`, `Row` (its `dissolve` field), `SeatNote`, `seatAt`, `row1`, `row2`, `atRow1`, `atRow2`, `hSeat`, `hStool`, `hRow1`, `hRow2`, `kSeatTag`.
- Produces: no new public symbol. The guard's behaviour (spec S1 "The guard"):
  - `_refused` has two disjoint branches by what the touched handle was in the before-survey, then the add checks:
    - **an owned entity** (today's branch, unchanged): refused while it exists, and when removed while its object's group lives;
    - **a generated instance**: refused when, after the edit, it is gone while its object's group lives, or `tree[h] != ` its survey node value (`InstanceNode.==`, exact);
    - **an add**: an entity whose owner is a live object (today's), or a generated instance of a live object, and which the survey did not hold; a node, a `GroupNode` included, whose parent is a live object, unless the survey held it there (a nested group a file brought in).
  - A components-only write on a generated instance passes and seeds nothing: no regeneration, no `_checkDangling`, the index skips it.
  - `_subtreeRemoval` removes the entities of every instance it removes: the object's generated instances from the survey, any other instance (a nested group's) by the scan it already makes for nested groups.
- What the consumers (Tasks 6, 9, 11, 14) can rely on: a refused edit throws `GeneratedGeometryError(handle)` with `inner` undone and nothing in history, as today. Per-unit data and colour reach a seat through `SetComponentCommand` and nothing else. A dissolve or cascade leaves no orphan ATTRIB.

Plan decisions:
- **"Added" is read from the survey, not from the handle seed.** An entity owned by a generated instance is an add when it is not in `before.leaves[owner]`; a node under a live object is an add when it is not in the survey's new `nested` map at that parent. So editing a non-ATTRIB entity a file put on a seat, or moving a nested group a file put in an object, passes as today (spec S1: "A nested group already inside an object … stays what it is today").
- **`_Survey` gains `nested`** (nested group handle → its object), filled by the same walk of each object's group list that Task 1 added. Cost: one map entry per nested group.
- **The node-branch condition is one ternary**, so that removing the "gone" half and removing the "value" half are separate mutations.
- **No change to `_run`'s seeds.** A generated instance was never a seed (it is neither an object nor in `owned`). The doc comment says so, and M-E5G-seed pins it.
- **`_subtreeRemoval`'s order**: every fill of the subtree first (the groups' leaves, then the instances' leaves), then per group its other leaves, its child groups recursively, each child instance's other leaves followed by the instance's node, and the group's node last. For `d`'s own generated instances the survey already holds their entities; only nested groups and the instances it does not know (a nested group's) pay the live-slot scan, as nested groups do today.

- [ ] **Step 1: Write the failing tests.** Create `test/parametric/instance_guard_test.dart`:

```dart
// Spec 2b S1 "The guard" and "The dissolve gap closes" (E5): 06 D6's guard
// gains a node branch for generated instances; any node or entity added
// into a live object, or onto one of its generated instances, is refused;
// a components-only write on a generated instance passes and seeds
// nothing; a removed subtree takes its instances' entities with it.
// Fixture: support/row_clients.dart (two rows off the origin, row 2 turned,
// mirrored and curved).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/row_clients.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

/// Runs [edit]: it must be refused with [GeneratedGeometryError] naming
/// [handle], and leave the bytes, the history and the state as they were.
/// A handle the edit adds is taken from the seed before this call.
void expectRefused(
    DraftDocument doc, DraftCommand edit, Handle handle, String what) {
  final bytes = enc(doc);
  final depth = doc.commands.undoDepth;
  final state = doc.commands.stateId;
  expect(
      () => doc.commands.execute(edit),
      throwsA(isA<GeneratedGeometryError>()
          .having((e) => e.handle, 'handle', handle)),
      reason: what);
  expect(enc(doc), bytes, reason: what);
  expect(doc.commands.undoDepth, depth, reason: what);
  expect(doc.commands.stateId, state, reason: what);
}

/// Every live entity's owner is a live node or definition.
void expectNoOrphan(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    final owner = doc.entities.ownerAt(slot);
    expect(doc.tree[owner] != null || doc.tree.definition(owner) != null,
        isTrue,
        reason: '${doc.entities.handleAt(slot).toHex()} is owned by '
            '${owner.toHex()}, which is gone');
  }
}

void main() {
  setUp(resetRowCalls);

  test(
      'E5G-refuse a seat\'s move, removal, definition change and layer '
      'change, and an edit or removal of its label, are each refused; the '
      'row moved whole passes and its seats ride along untouched '
      '(M-E5G-value, M-E5G-gone)', () {
    final doc = hall();
    final balcony = addLayer(doc, 'Balcony', 5);
    final seat = seats(doc, hRow2)[3];
    final label = leavesOf(doc, seat.handle).single;
    expectRefused(
        doc,
        TransformNodeCommand(seat.handle,
            seat.transform.multiply(Transform2.translation(25.5, -10.25))),
        seat.handle,
        'move');
    expectRefused(doc, RemoveNodeCommand(seat.handle), seat.handle, 'removal');
    expectRefused(doc, SetInstanceDefinitionCommand(seat.handle, hStool),
        seat.handle, 'definition');
    expectRefused(doc, SetInstanceLayerCommand(seat.handle, balcony),
        seat.handle, 'layer');
    expectRefused(doc, SetEntityTextCommand(label, 'Z9', kSeatTag), label,
        'label text');
    expectRefused(doc, RemoveEntityCommand(label), label, 'label removal');
    expectRefused(
        doc,
        CompoundCommand(
            [RemoveEntityCommand(label), RemoveNodeCommand(seat.handle)],
            label: 'Delete seat'),
        seat.handle,
        'the select tool\'s delete of one seat');

    // Positive control: the row moved whole.
    doc.commands.execute(TransformNodeCommand(
        hRow2, atRow2.multiply(Transform2.translation(400.5, -120.25))));
    expect(identical(doc.tree[seat.handle], seat), isTrue);
    expect(leavesOf(doc, seat.handle), [label]);
    expect(drift(doc), isEmpty);
  });

  test(
      'E5G-component a components-only write on a seat passes, seeds '
      'nothing, regenerates nothing and leaves the index alone; one undo '
      'step (M-E5G-seed)', () async {
    final doc = hall();
    final seat = seats(doc, hRow1)[6].handle;
    final index = SpatialIndex(doc);
    index.forEachInRect(Aabb2(Vector2(-20000, -20000), Vector2(30000, 30000)),
        const QueryFilter.all(), (_) {});
    final rebuilds = index.rebuildCount;
    final depth = doc.commands.undoDepth;
    resetRowCalls();
    final applied = await applying(
        doc,
        () => doc.commands
            .execute(SetComponentCommand<SeatNote>(seat, const SeatNote('vip'))));
    expect(rowGenerateCalls, isEmpty);
    expect(rowInstanceCalls, isEmpty);
    expect(applied.single.touched, {seat});
    expect(applied.single.capability, Capability.components);
    expect(index.rebuildCount, rebuilds);
    expect(doc.components.get<SeatNote>(seat), const SeatNote('vip'));
    expect(doc.commands.undoDepth, depth + 1);
    doc.commands.undo();
    expect(doc.components.get<SeatNote>(seat), isNull);
    doc.commands.redo();
    expect(doc.components.get<SeatNote>(seat), const SeatNote('vip'));
    expect(rowGenerateCalls, isEmpty);
    expect(rowInstanceCalls, isEmpty);
    index.dispose();
  });

  test(
      'E5G-add a node added into a live row is refused, a GroupNode '
      'included, and so is an entity added onto one of its seats; the same '
      'adds at the root pass, and a nested group a file brought in stays '
      'editable (M-E5G-add-node, M-E5G-add-onto, M-E5G-nested)', () {
    final doc = hall();
    final seat = seats(doc, hRow1).first.handle;
    final label = leavesOf(doc, seat).single;
    final group = doc.handleSeed.next();
    final instance = doc.handleSeed.next();
    final attrib = doc.handleSeed.next();
    final line = doc.handleSeed.next();
    expectRefused(
        doc,
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(50.5, 20.25),
            children: const [])),
        group,
        'a group into the row');
    expectRefused(
        doc,
        AddNodeCommand(InstanceNode(
            handle: instance,
            parent: hRow1,
            transform: seatAt(row1, 12),
            definition: hSeat,
            layer: ReservedHandles.layerZero)),
        instance,
        'an instance into the row');
    expectRefused(
        doc,
        AddEntityCommand(
            record: recordOf(doc, label)
                .copyWith(handle: attrib, tag: 'NOTE', text: 'aisle'),
            payload: payloadOf(doc, label)),
        attrib,
        'an ATTRIB onto a seat');
    expectRefused(
        doc,
        AddEntityCommand(
            record: draftRecord(line, seat, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload:
                linePayload(Vector2(-120.5, 0), Vector2(120.5, 40.25))),
        line,
        'a LINE onto a seat');

    // Positive controls: a group and an instance at the root, and an ATTRIB
    // onto that plain instance, pass.
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: atRow1.multiply(Transform2.translation(-2000.5, 0)),
        children: const [])));
    doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: atRow2.multiply(Transform2.translation(0, -1500.25)),
        definition: hStool,
        layer: ReservedHandles.layerZero)));
    doc.commands.execute(AddEntityCommand(
        record: recordOf(doc, label).copyWith(
            handle: attrib, owner: instance, tag: 'NOTE', text: 'aisle'),
        payload: payloadOf(doc, label)));
    expect(doc.tree[group]!.parent, doc.rootHandle);
    expect(doc.entities.ownerAt(doc.entities.slotOf(attrib)!), instance);

    // A nested group a file brought into the row: moving it is not an add.
    late Handle nested;
    final loaded = loadedWith(doc, (raw) {
      nested = raw.handleSeed.next();
      raw.commands.execute(AddNodeCommand(GroupNode(
          handle: nested,
          parent: hRow1,
          transform: Transform2.translation(-300.5, 450.25),
          children: const [])));
    });
    expect(loaded.tree[nested]!.parent, hRow1);
    final moved =
        Transform2.translation(80.25, -40.5).multiply(Transform2.rotation(0.3));
    loaded.commands.execute(TransformNodeCommand(nested, moved));
    expect(loaded.tree[nested]!.transform.equals(moved, exact), isTrue);
    expect(drift(loaded), isEmpty);
  });

  test(
      'E5G-dissolve a dissolving row takes its seats\' labels with it, and a '
      'loaded row takes a nested group\'s instance and its label too; undo '
      'restores every one (M-E5G-dissolve, M-E5G-scan)', () {
    final doc = hall();
    final labels = labelsOf(doc, hRow1);
    final ss = [for (final s in seats(doc, hRow1)) s.handle];
    final row2Labels = labelsOf(doc, hRow2);
    final placed = canon(doc);
    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(dissolve: true)));
    expect(doc.tree[hRow1], isNull);
    for (final s in ss) {
      expect(doc.tree[s], isNull);
    }
    for (final l in labels) {
      expect(doc.entities.slotOf(l), isNull, reason: l.toHex());
    }
    expect(labelsOf(doc, hRow2), row2Labels);
    expectNoOrphan(doc);
    doc.commands.undo();
    expect(canon(doc), placed);

    late Handle group, instance, attrib;
    final loaded = loadedWith(hall(), (raw) {
      group = raw.handleSeed.next();
      instance = raw.handleSeed.next();
      attrib = raw.handleSeed.next();
      raw.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(-300.5, 450.25)
                .multiply(Transform2.rotation(0.4)),
            children: const [])),
        AddNodeCommand(InstanceNode(
            handle: instance,
            parent: group,
            transform: Transform2.translation(20.5, -15.25),
            definition: hStool,
            layer: ReservedHandles.layerZero)),
        AddEntityCommand(
            record: draftRecord(attrib, instance, EntityKind.attrib,
                    layer: ReservedHandles.layerZero, text: 'Z1')
                .copyWith(tag: kSeatTag),
            payload: textPayload(Vector2(5.5, -8.25), 120.5)),
      ], label: 'A nested group'));
    });
    expect(loaded.tree[instance]!.parent, group);
    expect(drift(loaded), isEmpty);
    final before = canon(loaded);
    loaded.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(dissolve: true)));
    expect(loaded.tree[group], isNull);
    expect(loaded.tree[instance], isNull);
    expect(loaded.entities.slotOf(attrib), isNull);
    expectNoOrphan(loaded);
    loaded.commands.undo();
    expect(canon(loaded), before);
  });

  test(
      'E5G-undo refused edits leave nothing behind: undo and redo across '
      'refused and allowed edits walk the same states (M-E5G-undo)', () {
    final doc = hall();
    final seat = seats(doc, hRow1)[4];
    // Taken first: a refused add raises the seed no further.
    final group = doc.handleSeed.next();
    final s0 = canon(doc);
    expectRefused(
        doc,
        TransformNodeCommand(
            seat.handle, seat.transform.multiply(Transform2.rotation(0.25))),
        seat.handle,
        'move');
    doc.commands.execute(
        SetComponentCommand<SeatNote>(seat.handle, const SeatNote('window')));
    final s1 = canon(doc);
    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final s2 = canon(doc);
    expectRefused(
        doc,
        AddNodeCommand(GroupNode(
            handle: group,
            parent: hRow1,
            transform: Transform2.translation(10.5, 0),
            children: const [])),
        group,
        'a group into the row');
    doc.commands.execute(SetComponentCommand<Row>(
        hRow1, row1.copyWith(count: 10, prefix: 'K')));
    final s3 = canon(doc);
    expect({s0, s1, s2, s3}, hasLength(4));

    doc.commands.undo();
    expect(canon(doc), s2);
    doc.commands.undo();
    expect(canon(doc), s1);
    doc.commands.undo();
    expect(canon(doc), s0);
    doc.commands.redo();
    expect(canon(doc), s1);
    doc.commands.redo();
    expect(canon(doc), s2);
    doc.commands.redo();
    expect(canon(doc), s3);
  });
}
```

- [ ] **Step 2: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d && dart test test/parametric/instance_guard_test.dart`. Expected:
  - `E5G-refuse`, `E5G-undo`: red at the move (`Expected: throws <Instance of 'GeneratedGeometryError'…>`, the move returned normally);
  - `E5G-add`: red at the group added into the row;
  - `E5G-dissolve`: red at the first label (`slotOf` not null: Task 1's `_subtreeRemoval` leaves it);
  - `E5G-component`: passes already. A generated instance was never a seed. The test pins that against M-E5G-seed.

  Quote each failing line.

- [ ] **Step 3: The survey's nested groups.** In `regeneration.dart`:

  (a) `_Survey`: append `this.nested` to the constructor after `this.leaves`, and add after `leaves`:

```dart
  /// Each nested group of a live object (a `GroupNode` child of its group,
  /// which a file brought in), to the object. The guard leaves it what it
  /// is today (spec 2b S1): not generated, and not an add when edited.
  final Map<Handle, Handle> nested;
```

  (b) In `_survey`, replace Task 1's walk

```dart
  for (final h in order) {
    for (final c in (t.tree[h]! as GroupNode).children) {
      final node = t.tree[c];
      if (node is InstanceNode &&
          node.parent == h &&
          !generated.containsKey(c)) {
        (instances[h] ??= []).add(node);
        generated[c] = node;
      }
    }
  }
```

  with

```dart
  final nested = <Handle, Handle>{};
  for (final h in order) {
    for (final c in (t.tree[h]! as GroupNode).children) {
      final node = t.tree[c];
      if (node == null || node.parent != h) continue;
      if (node is InstanceNode) {
        if (generated.containsKey(c)) continue;
        (instances[h] ??= []).add(node);
        generated[c] = node;
      } else {
        nested[c] = h;
      }
    }
  }
```

  and append `nested` to `return _Survey(…)` after `leaves`.

- [ ] **Step 4: The guard.** Replace `_refused` and its doc comment with:

```dart
/// The first touched handle, ascending, that the guard refuses (spec 06 D6,
/// as amended by 2b S1), or null. Two disjoint branches by what the handle
/// was in [before], then the adds:
///
/// - **An owned entity** (`before.owned`: a child of a live object, or an
///   ATTRIB of one of its generated instances): refused if it **still
///   exists** — a direct edit, regardless of what else the same command did
///   to its owner — or, when it was removed, if its object's group node
///   still exists (spec D6's amendment for F4: whatever its component now
///   is; a compound that detaches the component and then removes a
///   still-live child must still be refused). Only a child removed
///   *together with* its object's group is allowed.
/// - **A generated instance** (`before.generated`): refused when, after the
///   edit, it is gone while its object's group lives, or its node differs
///   from the survey's value by `InstanceNode.==` (exact, every field): a
///   move, a definition, a layer or a style change. A components-only
///   write leaves the node as it was and passes (2b S1: per-unit data); it
///   seeds nothing (`_run`).
/// - **An add**: an entity the survey did not hold, owned by a live object
///   or by a generated instance of one; a node, a `GroupNode` included,
///   whose parent is a live object, unless the survey held it there (a
///   nested group a file brought in stays what it is).
///
/// A frozen object (spec 2a E2) is a plain group: a child added into it, or
/// one of its children or instances edited, is not refused.
Handle? _refused(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, Set<Handle> touched, bool Function(Handle)? frozen) {
  for (final h in touched.toList()..sort(_byValue)) {
    final owner = before.owned[h];
    if (owner != null) {
      if (t.entities.slotOf(h) != null) return h;
      if (t.tree[owner] != null) return h;
      continue;
    }
    final seat = before.generated[h];
    if (seat != null) {
      final now = t.tree[h];
      if (now == null ? t.tree[seat.parent] != null : now != seat) return h;
      continue;
    }
    final slot = t.entities.slotOf(h);
    if (slot != null) {
      final holder = t.entities.ownerAt(slot);
      if (_isObject(t, types, holder, frozen)) return h;
      final held = before.generated[holder];
      if (held != null &&
          t.tree[held.parent] != null &&
          !(before.leaves[holder]?.contains(h) ?? false)) {
        return h;
      }
      continue;
    }
    final node = t.tree[h];
    if (node != null &&
        before.nested[h] != node.parent &&
        _isObject(t, types, node.parent, frozen)) {
      return h;
    }
  }
  return null;
}
```

  `contains` on `before.leaves[holder]` scans one seat's entities (one or two ATTRIBs): O(1) per touched handle in practice.

- [ ] **Step 5: No seed for a generated instance.** In `_run`, above `final seeds = <Handle>{`, add the comment (the code is unchanged):

```dart
    // Spec 2b S1: a generated instance seeds nothing. It is neither an
    // object nor in `owned`, so a components-only write on one (per-unit
    // data) regenerates nothing and pays no `_checkDangling`. Any other
    // edit of it was refused above.
```

- [ ] **Step 6: The dissolve gap.** Replace `_subtreeRemoval` and the last two paragraphs of its doc comment (from "[d]'s own leaves are the survey's" to the end) with:

```dart
/// [d]'s own leaves are the survey's (an edit cannot add into a live
/// object, 06 D6 as amended by 2b S1), and so are its generated instances'
/// entities (2b S1). A nested group's leaves, and the entities of an
/// instance the survey does not know (a nested group's), are found by one
/// scan of the live slots, paid only when there is one. Every instance
/// removed takes its entities first, so no ATTRIB is left behind (2b S1,
/// "The dissolve gap closes").
///
/// Two callers: [_cascade], with the before-survey, for a doomed referrer;
/// [_plan], with the after-survey, for a dissolving object (spec 10 D15).
List<DraftCommand> _subtreeRemoval(CommandTarget t, _Survey before, Handle d) {
  final groups = <Handle>[];
  final instances = <Handle>[];
  void collect(Handle g) {
    groups.add(g);
    final node = t.tree[g];
    if (node is! GroupNode) return;
    for (final c in t.tree.childNodesOf(node.children)) {
      final child = t.tree[c];
      if (child is GroupNode) {
        collect(c);
      } else if (child is InstanceNode) {
        instances.add(c);
      }
    }
  }

  collect(d);
  bool live(Handle c) => t.entities.slotOf(c) != null;
  final leaves = <Handle, List<Handle>>{
    d: [
      for (final c in before.children[d] ?? const <Handle>[])
        if (live(c)) c,
    ],
    for (final i in before.instances[d] ?? const <InstanceNode>[])
      i.handle: [
        for (final c in before.leaves[i.handle] ?? const <Handle>[])
          if (live(c)) c,
      ],
  };
  final scanned = <Handle>{
    ...groups.skip(1),
    for (final i in instances)
      if (!leaves.containsKey(i)) i,
  };
  if (scanned.isNotEmpty) {
    for (final slot in t.entities.liveSlots) {
      final owner = t.entities.ownerAt(slot);
      if (scanned.contains(owner)) {
        (leaves[owner] ??= []).add(t.entities.handleAt(slot));
      }
    }
    for (final o in scanned) {
      leaves[o]?.sort(_byValue);
    }
  }
  bool isFill(Handle c) =>
      t.entities.kindAt(t.entities.slotOf(c)!) == EntityKind.fill;
  final out = <DraftCommand>[
    for (final g in [...groups, ...instances])
      for (final c in leaves[g] ?? const <Handle>[])
        if (isFill(c)) RemoveEntityCommand(c),
  ];
  void remove(Handle g) {
    for (final c in leaves[g] ?? const <Handle>[]) {
      if (!isFill(c)) out.add(RemoveEntityCommand(c));
    }
    final node = t.tree[g];
    if (node is GroupNode) {
      for (final c in t.tree.childNodesOf(node.children)) {
        final child = t.tree[c];
        if (child is GroupNode) {
          remove(c);
        } else if (child is InstanceNode) {
          for (final e in leaves[c] ?? const <Handle>[]) {
            if (!isFill(e)) out.add(RemoveEntityCommand(e));
          }
          out.add(RemoveNodeCommand(c));
        }
      }
    }
    out.add(RemoveNodeCommand(g));
  }

  remove(d);
  return out;
}
```

  Keep the comment's first two paragraphs (the select tool's order, every fill first) as they are.

- [ ] **Step 7: The error's doc comment.** In `parametric_system.dart`, replace `GeneratedGeometryError`'s doc comment `/// A direct edit of a generated entity (spec D6). Propagates like` / `/// \`PermissionDeniedError\`; the UI never offers the edit.` with:

```dart
/// A direct edit of a generated entity or a generated instance, or a node
/// or entity added into a live object or onto one of its generated
/// instances (spec D6, as amended by 2b S1). Propagates like
/// `PermissionDeniedError`; the UI never offers the edit.
```

- [ ] **Step 8: CS11's fixture (controller ruling R-4).** In `test/parametric/cascade_test.dart`, CS11 adds an instance and a nested group into P1, and a leaf into the nested group (`:636-654`), all through `doc.commands.execute`. The guard now refuses the first two. Make the three adds come in as a file brings them. Insert before `final instance = doc.handleSeed.next();`:

```dart
    // Spec 2b S1: an edit may not add a node into a live object. A loaded
    // file's shape: these come in past the parametric system.
    final expander = doc.commands.expander;
    doc.commands.expander = null;
```

  and after the leaf's `doc.commands.execute(AddEntityCommand(…));`, before `expect(doc.validate(), isEmpty);`:

```dart
    doc.commands.expander = expander;
```

  Every assertion of CS11 stays as Task 1 left it. R-4 prefers a direct tree/store write where one exists; none covers all three adds (the engine has `DocumentTree.addNode`, `tree.dart:165`, but no public store call that adds an entity with its geometry: `AddEntityCommand.apply`, `commands.dart:49-67`, does `geometry.add`, `entities.add`, the seed and `invalidateDerived` itself), so the expander is set aside, R-4's fallback. Record it in the ledger as ruling R-4 (an existing engine test's premise changed by the spec, not a weakened assertion).

- [ ] **Step 9: The CHANGELOG.** In `CHANGELOG.md`, under `## Unreleased`, add after Task 1's E5 bullet:

```markdown
- The edit guard covers generated instances. Moving, removing,
  re-pointing or re-layering one, or editing or removing its ATTRIBs, is
  refused with `GeneratedGeometryError`. A components-only write on one
  passes and regenerates nothing. Any node or entity added into a live
  object by anything but the planner is refused, and so is an entity added
  onto one of its generated instances. This includes a `GroupNode`: until
  now a group added into an object passed. A nested group a file brought in
  stays editable. Removing an object's subtree (a dissolve, a reference
  cascade) also removes the entities its instances own, so no ATTRIB is
  left behind.
```

- [ ] **Step 10: The rooms spec amendment.** In `docs/superpowers/specs/2026-09-26-rooms-design.md`, under the heading `### D12 — Engine (a): generated text` (`:1076`), insert one paragraph between the heading and its first bullet (one blank line on each side):

```markdown
**Amended by the 2b spec (2026-10-14, [S1](2026-10-14-plan-library-service-mode-design.md#s1-e5-a-parametric-type-generates-instances)):** "an ATTRIB needs a tag nobody generates" no longer holds for generated instances: `ParametricType.instances` returns `GeneratedInstance`s whose `GeneratedAttrib`s name their tag. `Generated` itself still refuses `attrib`, and a TEXT still needs `Generated.text`.
```

- [ ] **Step 11: Run the new tests.** Run: `cd packages/jet_cad_2d && dart test test/parametric/instance_guard_test.dart test/parametric/instances_test.dart test/parametric/cascade_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 12: The gates.** Run, one at a time:
  - `cd packages/jet_cad_2d && dart format .`
  - `cd packages/jet_cad_2d && dart test test/parametric`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart` (the standing hash tests). Expected: the only failures are the two `packages/jet_cad_2d` lines of `tool/ci/standing_failures.txt`; quote the summary line.
  - `cd packages/jet_cad_2d && dart test`. Expected: the only failures are those same two.
  - `cd packages/jet_cad_2d && dart analyze`. Expected: `No issues found!`.
  - `cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .`. Expected: exit 0.

- [ ] **Step 13: The dependents, unchanged.** The guard now refuses a node added into a live object, so run every package that executes edits under a parametric system, one at a time: `cd packages/jet_cad_2d_plan && flutter test`, `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice`, `cd packages/jet_cad_2d_flutter && flutter test`, `cd packages/jet_cad_2d_kit && flutter test`, and the other entries of CI's test matrix that run the planner over the engine (`.github/workflows/ci.yml:36-60`): `cd packages/jet_cad_restaurant_symbols && flutter test`, `cd apps/floor_planner && flutter test`, `cd apps/restaurant_demo && flutter test`, `cd tool/screenshots && flutter test`. Expected for each: the result of clean `main`; the only failures are the lines `tool/ci/standing_failures.txt` lists for that package.
  - A new failure is a finding. If a dependent test adds a node into a live object and is now refused, stop and report it with the test's name and line; do not edit the dependent.
  - Then run `git status --short`: only this task's files. Leave any rewritten `analysis_options.yaml` unstaged.

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/parametric/regeneration.dart packages/jet_cad_2d/lib/src/parametric/parametric_system.dart packages/jet_cad_2d/CHANGELOG.md packages/jet_cad_2d/test/parametric/instance_guard_test.dart packages/jet_cad_2d/test/parametric/cascade_test.dart docs/superpowers/specs/2026-09-26-rooms-design.md
git commit -m "$(cat <<'EOF'
feat(engine): E5, the guard for generated instances (2b S1)

06 D6's guard gains a node branch: a generated instance moved, removed,
re-pointed or re-layered is refused, by InstanceNode equality against
the before-survey; a components-only write on one passes and seeds
nothing. Any node or entity added into a live object, a GroupNode
included, or onto one of its generated instances, is refused; a nested
group a file brought in stays editable. A removed subtree takes its
instances' entities, so a dissolve leaves no ATTRIB. The rooms spec's
D12 gains the amendment line.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 15: Mutation check.** On the committed files only. For each mutation:
  1. apply the edit;
  2. run `cd packages/jet_cad_2d && dart test test/parametric/instance_guard_test.dart --name '<id>'`;
  3. see it red and quote the failing expectation line;
  4. `git checkout -- <file>`;
  5. `git diff --quiet -- <file>`, which must exit 0.

  All in `lib/src/parametric/regeneration.dart`:
  - M-E5G-value: in `_refused`, `: now != seat) return h;` → `: false) return h;` → `E5G-refuse` red (the move passes).
  - M-E5G-gone: in `_refused`, `now == null ? t.tree[seat.parent] != null :` → `now == null ? false :` → `E5G-refuse` red (the removal passes).
  - M-E5G-seed (an addition): in `_run`'s seeds, after `if (before.owned[h] case final owner?) owner,` add `if (before.generated[h] case final seat?) seat.parent,` → `E5G-component` red (`rowGenerateCalls` holds `hRow1: 1`).
  - M-E5G-add-node: in `_refused`, delete the statement `if (node != null && before.nested[h] != node.parent && _isObject(…)) { return h; }` → `E5G-add` red (the group into the row passes).
  - M-E5G-add-onto: in `_refused`, delete the statement `if (held != null && t.tree[held.parent] != null && !(…)) { return h; }` → `E5G-add` red (the ATTRIB onto a seat passes).
  - M-E5G-nested: in `_refused`, delete `before.nested[h] != node.parent &&` → `E5G-add` red (the loaded nested group's move is refused).
  - M-E5G-dissolve: in `_subtreeRemoval`'s `remove`, delete the `for (final e in leaves[c] ?? const <Handle>[]) { if (!isFill(e)) out.add(RemoveEntityCommand(e)); }` loop of the `InstanceNode` branch → `E5G-dissolve` red (the first label remains).
  - M-E5G-scan: in `_subtreeRemoval`, delete `for (final i in instances) if (!leaves.containsKey(i)) i,` from `scanned` → `E5G-dissolve` red at the nested instance's ATTRIB.
  - M-E5G-undo: in `_run`'s refusal branch, delete `_undoInner(t, edit.label, r0, GeneratedGeometryError(refused));` → `E5G-undo` red (the bytes after the refused move differ).

  Two parts of the new code have no behavioural mutant, stated for the reviewer:
  - **The survey entries for `d`'s generated instances in `_subtreeRemoval`.** Deleting them makes the scan find the same entities. That mutant is equivalent in behaviour and changes only the cost, which is the reason for the entries.
  - **The instances' half of the fills-first pass.** No fixture puts a fill on an instance.

  Then run `cd packages/jet_cad_2d && dart test test/parametric` once more: `All tests passed!`.

#### Interface problem

Resolved by R-4 (Step 8: the expander set aside around CS11's three adds, "a loaded file's shape"; no assertion changes).

---

