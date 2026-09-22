import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

/// Copied from `test/index/pick_test.dart`, never imported from a test file.
Handle addEntity(DraftDocument doc, Handle owner, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle addGroup(DraftDocument doc, Handle parent, Transform2 transform) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(GroupNode(
    handle: handle,
    parent: parent,
    transform: transform,
    children: const [],
  )));
  return handle;
}

/// Nothing below sits at the identity transform or the origin.
final Transform2 kPlacement = Transform2.translation(500, 300)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, 1.5));

class _RollbackFailure implements Exception {
  @override
  String toString() => 'bad inverse';
}

/// Applies cleanly and hands back an inverse that throws, so a compound
/// rolling it back fails inside the rollback itself.
class _BadInverseCommand extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'bad';
  @override
  CommandResult apply(CommandTarget target) =>
      CommandResult(inverse: _ThrowingInverse(), touched: const {});
}

class _ThrowingInverse extends DraftCommand {
  @override
  Capability get capability => Capability.geometry;
  @override
  String get label => 'throwing inverse';
  @override
  CommandResult apply(CommandTarget target) => throw _RollbackFailure();
}

void main() {
  test('an empty compound is rejected at construction', () {
    expect(() => CompoundCommand(const [], label: 'Delete'),
        throwsA(isA<ArgumentError>()));
  });

  test(
      'applies every child, is one undo step, and one undo restores every '
      'child', () async {
    // M-C4 (touched = first child's only) and M-C6 (empty compound
    // accepted, above) are the mutants this file fires here; the ordering
    // guarantee is carried by the node-then-edit fixture further down.
    final doc = DraftDocument.empty();
    final leaf = addEntity(doc, doc.rootHandle, [990, 500, 1010, 500]);
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    final grouped = addEntity(doc, group, [0, 0, 2, 0]);
    final depthBefore = doc.commands.undoDepth;
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);

    doc.commands.execute(CompoundCommand([
      RemoveEntityCommand(leaf),
      RemoveEntityCommand(grouped),
      RemoveNodeCommand(group),
    ], label: 'Delete'));
    await Future<void>.delayed(Duration.zero);

    expect(doc.entities.slotOf(leaf), isNull);
    expect(doc.entities.slotOf(grouped), isNull);
    expect(doc.tree[group], isNull);
    expect(doc.commands.undoDepth, depthBefore + 1,
        reason: 'three removals, one history entry');
    final applied = events.single as CommandApplied;
    expect(applied.label, 'Delete');
    expect(applied.touched, {leaf, grouped, group},
        reason: 'touched is the union of the children, so the index '
            'reconciles every removed handle, not only the first');

    doc.commands.undo();

    expect(doc.entities.slotOf(leaf), isNotNull);
    expect(doc.entities.slotOf(grouped), isNotNull);
    expect(doc.tree[group], isNotNull);
    expect(doc.commands.undoDepth, depthBefore);
    expect(
        (doc.tree[group]! as GroupNode).transform.toJson(), kPlacement.toJson(),
        reason: 'the inverse carries the node value, not a default');

    doc.commands.redo();

    expect(doc.entities.slotOf(leaf), isNull);
    expect(doc.entities.slotOf(grouped), isNull);
    expect(doc.tree[group], isNull);
    unawaited(sub.cancel());
  });

  test("the inverse applies the children's inverses in reverse order", () {
    // M-C1: forward order would remove the node first and then try to
    // restore a transform on a node that no longer exists. Two independent
    // children could not tell the orders apart, which is why the fixture
    // is a node and an edit *of that node*.
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    final moved = Transform2.translation(-40, 25)
        .multiply(Transform2.rotation(math.pi / 3));

    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
        handle: handle,
        parent: doc.rootHandle,
        transform: kPlacement,
        children: const [],
      )),
      TransformNodeCommand(handle, moved),
    ], label: 'Place'));

    expect((doc.tree[handle]! as GroupNode).transform.toJson(), moved.toJson());

    doc.commands.undo();

    expect(doc.tree[handle], isNull);

    doc.commands.redo();

    expect((doc.tree[handle]! as GroupNode).transform.toJson(), moved.toJson(),
        reason: 'redo replays the compound forward again');
  });

  test(
      'a child that throws rolls the earlier children back and leaves '
      'no history behind', () async {
    // M-C2: without the rollback, `leaf` would be gone while the dispatcher
    // reports nothing happened, which is exactly the hazard
    // `DraftCommand.apply`'s all-or-nothing contract exists to close.
    final doc = DraftDocument.empty();
    final leaf = addEntity(doc, doc.rootHandle, [990, 500, 1010, 500]);
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    final missing = doc.handleSeed.next();
    final depthBefore = doc.commands.undoDepth;
    final liveBefore = doc.entities.liveCount;
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);

    expect(
      () => doc.commands.execute(CompoundCommand([
        RemoveEntityCommand(leaf),
        RemoveNodeCommand(group),
        RemoveEntityCommand(missing),
      ], label: 'Delete')),
      throwsA(isA<StateError>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(doc.entities.slotOf(leaf), isNotNull);
    expect(doc.tree[group], isNotNull);
    expect((doc.tree[group]! as GroupNode).transform.toJson(),
        kPlacement.toJson());
    expect(doc.entities.liveCount, liveBefore);
    expect(doc.commands.undoDepth, depthBefore);
    expect(doc.commands.canRedo, isFalse,
        reason: 'the rollback is not a redo-able undo');
    expect(events, isEmpty,
        reason: 'nothing happened, so nothing is announced: the index must '
            'not reconcile a change that was rolled back');
    unawaited(sub.cancel());
  });

  test(
      'a rollback inverse that throws surfaces both failures and does not '
      'pretend nothing happened', () {
    // M-C7: without the guard the rollback's own exception would escape as
    // if it were the child's, and a caller catching the child's error type
    // would conclude the target is untouched when it is not.
    final doc = DraftDocument.empty();
    final missing = doc.handleSeed.next();

    expect(
      () => doc.commands.execute(CompoundCommand([
        _BadInverseCommand(),
        RemoveEntityCommand(missing),
      ], label: 'Delete')),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('rollback'))
          .having((e) => e.message, 'message', contains('bad inverse'))),
    );
    expect(doc.commands.canUndo, isFalse);
  });

  test('the spatial index rebuilds at most once for one compound', () {
    // M-C8: a removed node and every removed leaf each fall to the index's
    // "no longer resolves" fallback, which is a full rebuild; once one has
    // happened it already reflects every child, so the rest must be
    // skipped. Without the early return a group of N leaves is N + 1 full
    // rebuilds per Delete.
    final doc = DraftDocument.empty();
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    final leaves = [
      for (var i = 0; i < 4; i++)
        addEntity(doc, group, [i * 10.0, 0, i * 10.0 + 2, 0]),
    ];
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;

    doc.commands.execute(CompoundCommand([
      for (final leaf in leaves) RemoveEntityCommand(leaf),
      RemoveNodeCommand(group),
    ], label: 'Delete'));

    expect(index.rebuildCount - before, 1);
  });

  test('permissions are checked for every child before anything mutates', () {
    // M-C3: a compound that reports only its first child's capability would
    // let a runtime document remove geometry through a compound whose first
    // child is a permitted move.
    final doc = DraftDocument.empty();
    final leaf = addEntity(doc, doc.rootHandle, [990, 500, 1010, 500]);
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    doc.commands.permissions = DraftPermissions.runtime;
    final depthBefore = doc.commands.undoDepth;
    final moved = Transform2.translation(1, 1);

    expect(
      () => doc.commands.execute(CompoundCommand([
        TransformNodeCommand(group, moved),
        RemoveEntityCommand(leaf),
      ], label: 'Delete')),
      throwsA(isA<PermissionDeniedError>()),
    );

    expect(
        (doc.tree[group]! as GroupNode).transform.toJson(), kPlacement.toJson(),
        reason: 'the permitted first child must not run either');
    expect(doc.entities.slotOf(leaf), isNotNull);
    expect(doc.commands.undoDepth, depthBefore);
  });

  test('the dispatcher checks the whole set, not the summary capability', () {
    // M-C5: `runtime` cannot tell the two apart, because every capability it
    // denies outranks every one it allows. These permissions deny only the
    // lowest-ranked one, so a dispatcher that checked the summary (geometry,
    // allowed) would let the compound through.
    final doc = DraftDocument.empty();
    final leaf = addEntity(doc, doc.rootHandle, [990, 500, 1010, 500]);
    final group = addGroup(doc, doc.rootHandle, kPlacement);
    doc.commands.permissions = const DraftPermissions(
        transform: false, components: true, geometry: true, structure: true);
    final depthBefore = doc.commands.undoDepth;

    expect(
      () => doc.commands.execute(CompoundCommand([
        TransformNodeCommand(group, Transform2.translation(1, 1)),
        RemoveEntityCommand(leaf),
      ], label: 'Delete')),
      throwsA(isA<PermissionDeniedError>()),
    );

    expect((doc.tree[group]! as GroupNode).transform.toJson(),
        kPlacement.toJson());
    expect(doc.entities.slotOf(leaf), isNotNull);
    expect(doc.commands.undoDepth, depthBefore);
  });

  test("capabilities is the union of the children's", () {
    final compound = CompoundCommand([
      TransformNodeCommand(const Handle(50), Transform2.identity()),
      RemoveEntityCommand(const Handle(51)),
      RemoveNodeCommand(const Handle(52)),
    ], label: 'Delete');
    expect(compound.capabilities,
        {Capability.transform, Capability.geometry, Capability.structure});
    // "Highest-ranked" is the declaration order of `enum Capability`
    // (transform, components, geometry, structure); the getter is
    // informational and nothing in the repo dispatches on it.
    expect(compound.capability, Capability.structure,
        reason: 'the summary capability is the highest-ranked child');
  });

  test('the spatial index sees every handle a compound removes', () {
    // Belt to the `touched` assertion above: a stale entry for the second
    // leaf would answer this pick from a slot that no longer holds it.
    final doc = DraftDocument.empty();
    final a = addEntity(doc, doc.rootHandle, [990, 500, 1010, 500]);
    final b = addEntity(doc, doc.rootHandle, [-700, -300, -680, -300]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final hit = HitPath();
    expect(index.pickInto(Vector2(-690, -300), 2.0, QueryFilter.picking(), hit),
        isTrue);
    expect(hit.entity, b);

    doc.commands.execute(CompoundCommand(
        [RemoveEntityCommand(a), RemoveEntityCommand(b)],
        label: 'Delete'));

    expect(index.pickInto(Vector2(1000, 500), 2.0, QueryFilter.picking(), hit),
        isFalse);
    expect(index.pickInto(Vector2(-690, -300), 2.0, QueryFilter.picking(), hit),
        isFalse);
  });
}
