import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord line(Handle handle, Handle owner) => EntityRecord(
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
    );

EntityRecord attrib(Handle handle, Handle owner) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

Handle addLine(DraftDocument doc, Handle owner, double x1, double y1, double x2,
    double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('adding an entity dirties it without a full rebuild', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rebuildsBefore = index.rebuildCount;
    addLine(doc, doc.rootHandle, 10, 10, 11, 11);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'one add must not rebuild the whole index');
    expect(index.rootIndex.dirty.length, 1);
  });

  test('a newly added entity is immediately findable', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    addLine(doc, doc.rootHandle, 50, 50, 51, 51);

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(49, 49), Vector2(52, 52)), found.add);
    expect(found, hasLength(1),
        reason: 'the dirty list is searched alongside the tree');
  });

  test('a component edit dirties nothing — the load-bearing guarantee', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final dirtyBefore = index.dirtyCount;
    final rebuildsBefore = index.rebuildCount;

    doc.commands.execute(SetComponentCommand(
      handle,
      const OriginComponent(source: SourceKind.dxf, id: 'probe'),
    ));

    expect(index.dirtyCount, dirtyBefore,
        reason: 'SetComponentCommand touches the entity handle exactly as a '
            'geometry edit does; re-derivation must find the box unchanged');
    expect(index.rebuildCount, rebuildsBefore);
    expect(index.rootIndex.dirty.isEmpty, isTrue);
  });

  test('removing an entity marks its tree entry dead', () {
    final doc = DraftDocument.empty();
    final keep = addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final drop = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rebuildsBefore = index.rebuildCount;
    doc.commands.execute(RemoveEntityCommand(drop));

    // Asserting `rebuildCount` is not just belt-and-braces here: without
    // `_lastKnownSlot` populated in `rebuildAll`, `_reconcileEntity` cannot
    // find the removed slot to mark dead and falls back to a full
    // `rebuildAll()` — which still produces the right *answer* below, so a
    // version of this test that checked only `found` would pass against
    // that regression too. This is the one assertion that forces the fast,
    // incremental path rather than the conservative fallback.
    expect(index.rebuildCount, rebuildsBefore,
        reason: 'a plain removal must be reconciled without a full rebuild');

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(-1, -1), Vector2(100, 100)), found.add);
    expect(found, hasLength(1));
    expect(doc.entities.handleAt(found.single), keep);
  });

  test(
      'a slot reused by a different entity is found at its own box, not the '
      "dead entity's", () {
    // Regression test for the hazard `_sameBox`'s exact `==` exists to
    // close: `SlotAllocator` reuses a freed slot immediately, so the next
    // entity added after a removal can land in the very slot the removed
    // entity left dead. Reconciliation must not mistake the new entity's
    // touch for "this dead slot came back with its old box" — only an exact
    // match against the *dead* entry's stored box may revive it, and a real
    // new entity at a different location must not match.
    final doc = DraftDocument.empty();
    final dropped = addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveEntityCommand(dropped));
    final replacement = addLine(doc, doc.rootHandle, 100, 100, 101, 101);

    final atDeadEntitysOldBox = <int>[];
    index.rootIndex.searchLeaves(
        Aabb2(Vector2(-1, -1), Vector2(2, 2)), atDeadEntitysOldBox.add);
    expect(atDeadEntitysOldBox, isEmpty,
        reason: 'the replacement must not be findable at the coordinates of '
            'the entity it replaced');

    final atItsOwnBox = <int>[];
    index.rootIndex.searchLeaves(
        Aabb2(Vector2(99, 99), Vector2(102, 102)), atItsOwnBox.add);
    expect(atItsOwnBox, hasLength(1));
    expect(doc.entities.handleAt(atItsOwnBox.single), replacement);
  });

  test('undo restores findability', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveEntityCommand(handle));
    doc.commands.undo();

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(9, 9), Vector2(12, 12)), found.add);
    expect(found, hasLength(1));
  });

  test('moving a node re-derives and dirties the instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(
        TransformNodeCommand(instance, Transform2.translation(500, 500)));

    final found = <Handle>[];
    index.rootIndex.searchInstances(
        Aabb2(Vector2(499, 499), Vector2(502, 502)), found.add);
    expect(found, [instance],
        reason: 'the instance must be findable at its new position');
  });

  test('removing an instance node (via undo) invalidates the index', () {
    // Regression test: a touched handle that no longer resolves to a node
    // — because it was just removed — used to fall through `_reconcile`'s
    // structural check (which only fires for a handle that *still*
    // resolves) into `_reconcileEntity`, where it was neither a live
    // entity nor a previously-seen one, and reconciliation did nothing.
    // The removed instance stayed indexed and stayed findable forever.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    // The definition must hold a leaf, or `definitionBounds` is empty and
    // `Aabb2.transformedBy` short-circuits an empty box to itself — the
    // instance's indexed box would then be empty regardless of the
    // placement transform, unfindable by any query before removal even
    // enters the picture, and the test would pass whether or not removal
    // is reconciled correctly.
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(500, 500),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Sanity check: the instance is findable before the removal we are
    // about to test invalidation for. Without this, the assertion below
    // would pass just as vacuously as it did before this fix.
    final before = <Handle>[];
    index.rootIndex.searchInstances(
        Aabb2(Vector2(499, 499), Vector2(502, 502)), before.add);
    expect(before, [instance],
        reason: 'setup check: the instance must be findable before removal, '
            'or the assertion below proves nothing');

    doc.commands.undo(); // applies the inverse: RemoveNodeCommand(instance)

    final found = <Handle>[];
    index.rootIndex.searchInstances(
        Aabb2(Vector2(-1e6, -1e6), Vector2(1e6, 1e6)), found.add);
    expect(found, isEmpty,
        reason: 'a removed instance must not still be indexed');
  });

  test('removing a group node invalidates the index for its leaf', () {
    // Same regression as above, but via `RemoveNodeCommand` directly and
    // exercising a group's leaf rather than an instance: the leaf entity
    // itself is untouched by the command (its record still lives in the
    // entity store, unowned by anything reachable from the tree), so the
    // only signal reconciliation gets is the group handle's own touch.
    final doc = DraftDocument.empty();
    const group = Handle(300);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [],
      ),
    ));
    addLine(doc, group, 0, 0, 1, 1);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    doc.commands.execute(RemoveNodeCommand(group));

    final found = <int>[];
    index.rootIndex
        .searchLeaves(Aabb2(Vector2(-1e6, -1e6), Vector2(1e6, 1e6)), found.add);
    expect(found, isEmpty,
        reason: "a removed group's leaf must not still be indexed");
  });

  test('an ATTRIB owned by an instance dirties nothing on a component edit',
      () {
    // Regression test for a gap found while reviewing the reference
    // `_groupTransformOf`: an ATTRIB entity's owner is the *instance node*
    // itself (see `EntityRecord.owner` and `ContainerIndex.build`'s INSERT
    // case), not a group. A walk that stops composing at the first
    // non-`GroupNode` it meets never picks up the owning instance's own
    // transform, so the re-derived box lands in the wrong space and this
    // entity would be marked dirty on every touch — breaking the
    // appearance-edits-do-not-dirty guarantee for this one entity shape.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(50, 50),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final attribHandle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: attrib(attribHandle, instance),
      payload: GeometryPayload(
        coords: Float64List.fromList([5, 5]),
        scalars: Float64List.fromList([1.0]),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final dirtyBefore = index.dirtyCount;
    final rebuildsBefore = index.rebuildCount;

    doc.commands.execute(SetComponentCommand(
      attribHandle,
      const OriginComponent(source: SourceKind.dxf, id: 'attrib-probe'),
    ));

    expect(index.dirtyCount, dirtyBefore,
        reason: "the ATTRIB box must be composed with its owning instance's "
            'own transform, or reconciliation derives it in the wrong space '
            'and dirties it on every touch');
    expect(index.rebuildCount, rebuildsBefore);
  });

  test('DocumentPurged forces a full rebuild', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final drop = addLine(doc, doc.rootHandle, 10, 10, 11, 11);
    doc.commands.execute(RemoveEntityCommand(drop));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;

    doc.purge();

    expect(index.rebuildCount, greaterThan(before),
        reason: 'purge renumbers slots, so every slot-keyed structure dies');
    expect(index.rootIndex.dirty.isEmpty, isTrue);
  });

  test('crossing the rebuild threshold rebuilds and clears the dirty list', () {
    final doc = DraftDocument.empty();
    for (var i = 0; i < 2000; i++) {
      addLine(doc, doc.rootHandle, i.toDouble(), 0, i + 0.5, 1);
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final threshold = index.rootIndex.rebuildThreshold;
    final before = index.rebuildCount;

    // Each add dirties one entity.
    for (var i = 0; i <= threshold; i++) {
      addLine(doc, doc.rootHandle, 5000.0 + i, 0, 5000.5 + i, 1);
    }

    expect(index.rebuildCount, greaterThan(before));
    expect(index.rootIndex.dirty.length, lessThanOrEqualTo(threshold),
        reason: 'a rebuild folds the dirty list into the tree');
  });
}
