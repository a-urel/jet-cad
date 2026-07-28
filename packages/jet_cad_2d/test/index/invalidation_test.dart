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

/// A group scaled (2, 5) holding a line, plus a warm broad-phase margin.
///
/// The group's anisotropy is what makes the margin non-zero once anything
/// round is inside it; the line is what makes the index non-empty while
/// the margin is still zero, so the warming query caches a zero.
({DraftDocument doc, SpatialIndex index, Handle group}) _warmedNonUniform() {
  final doc = DraftDocument.empty();
  const group = Handle(800);
  doc.commands.execute(AddNodeCommand(
    GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.scale(2, 5),
      children: const [],
    ),
  ));
  addLine(doc, group, 0, 0, 1, 1);

  final index = SpatialIndex(doc);
  final hit = HitPath();
  index.pickInto(Vector2(0, 0), 1.0, const QueryFilter.all(), hit);
  return (doc: doc, index: index, group: group);
}

/// A circle of radius 2 at the group's local origin.
///
/// Under the (2, 5) scale its indexed box stops at x = 4, while the narrow
/// phase measures against the geometric-mean radius `2 * sqrt(10)`, about
/// 6.32. So x = 5.5 is inside the approximated circle and outside the
/// indexed box: reachable only if the query was widened by the margin.
Handle _addGapCircle(DraftDocument doc, Handle owner) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.circle,
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
      coords: Float64List.fromList([0, 0]),
      scalars: Float64List.fromList([2.0]),
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

  test('a reused slot does not inherit the removed leaf\'s group transform',
      () {
    // Slots are recycled from a LIFO free list, so the very next entity added
    // after a removal lands on the freed slot. `ContainerIndex` keys its
    // composed group transforms by slot, so if a removed leaf's matrix
    // outlives it, the unrelated entity that claims the slot is measured in
    // the removed leaf's space -- found by the broad phase at its own
    // coordinates, then narrow-phased a hundred units away.
    //
    // Two lines guard this: `forgetLeaf` on the removal path, and
    // `noteLeaf`'s clear-when-identity on the add path. Deleting *either*
    // alone still passes; deleting both together used to pass too, which is
    // what this test exists to stop.
    final doc = DraftDocument.empty();
    const group = Handle(700);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 100),
        children: const [],
      ),
    ));
    final inGroup = addLine(doc, group, 0, 0, 1, 0);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final slot = doc.entities.slotOf(inGroup)!;
    expect(index.rootIndex.transformOfLeaf(slot), isNotNull,
        reason: 'the fixture must actually put a transform on this slot');

    final rebuildsBefore = index.rebuildCount;
    doc.commands.execute(RemoveEntityCommand(inGroup));
    final reuser = addLine(doc, doc.rootHandle, 0, 0, 1, 0);

    expect(doc.entities.slotOf(reuser), slot,
        reason: 'the fixture must actually reuse the freed slot');
    expect(index.rebuildCount, rebuildsBefore,
        reason: 'this must exercise the dirty overlay, not a rebuild');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(0.5, 0), 0.25, const QueryFilter.all(), hit),
      isTrue,
      reason: 'a root-owned entity must be measured in root space, not in '
          'the space of whatever used to hold its slot',
    );
    expect(hit.entity, reuser);

    expect(
      index.pickInto(Vector2(100.5, 100), 0.25, const QueryFilter.all(), hit),
      isFalse,
      reason: 'nothing is drawn where the removed leaf used to be',
    );
  });

  // --- the cached broad-phase margin ----------------------------------
  //
  // `SpatialIndex._margin` caches the document-wide narrow-phase slack --
  // how much wider than its own radius a pick must search so its broad phase
  // is never tighter than what its narrow phase would accept. It is non-zero
  // only where a circle or an arc sits under a non-conformal transform, and
  // it is dropped in exactly two places: `_reconcile` and `rebuildContainer`.
  // Deleting *either* line left all 567 tests green, because every existing
  // margin test built its fixture and then queried once -- with a null cache
  // there is nothing stale to read. These two warm the cache first, which is
  // the only state in which the invalidation is observable at all.
  //
  // The failure this guards is the hit-*dropping* direction: a stale margin
  // of zero leaves a round leaf correctly indexed, correctly transformed and
  // unpickable in the gap between its exact bound and its approximated
  // radius.

  test('_reconcile drops the cached broad-phase margin', () {
    final fixture = _warmedNonUniform();
    addTearDown(fixture.index.dispose);
    final index = fixture.index;
    final rebuildsBefore = index.rebuildCount;

    final circle = _addGapCircle(fixture.doc, fixture.group);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'this must exercise reconciliation, not a rebuild -- a '
            'rebuild would drop the margin for its own reasons');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
      reason: 'the margin cached by the warming query predates this circle, '
          'so reconciliation has to drop it or the broad phase never reaches '
          'x = 5.5',
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  test('rebuildContainer drops the cached broad-phase margin', () {
    // The other path, reached the only way it can be reached on its own: a
    // change the index was never told about, followed by an explicit
    // `rebuildContainer`. Along the command path `_reconcile` has already
    // dropped the margin before it ever calls `rebuildContainer`, so the two
    // lines are redundant there and only this shape separates them.
    //
    // Writing straight to the stores stands in for any allocation this
    // index's change hook does not own -- a bulk import, or a second
    // `SpatialIndex` over the same document, which takes the hook over (see
    // `SpatialIndex.dispose`). `slot_lifetime_test.dart` uses the same
    // stand-in for the same reason.
    final fixture = _warmedNonUniform();
    addTearDown(fixture.index.dispose);
    final doc = fixture.doc;
    final index = fixture.index;
    final rebuildsBefore = index.rebuildCount;

    final circle = doc.handleSeed.next();
    final geomIndex = doc.geometry.add(GeometryPayload(
      coords: Float64List.fromList([0, 0]),
      scalars: Float64List.fromList([2.0]),
    ));
    doc.entities.add(EntityRecord(
      handle: circle,
      owner: fixture.group,
      kind: EntityKind.circle,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: geomIndex,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ));

    index.rebuildContainer(doc.rootHandle);

    expect(index.rebuildCount, rebuildsBefore + 1,
        reason: 'exactly one container was rebuilt -- a rebuildAll here '
            'would drop the margin for its own reasons and prove nothing');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
      reason: 'the rebuilt container knows its own slack, but the query is '
          'widened by the document-wide cache, which predates this circle',
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  // --- growing a definition after the index exists ----------------------
  //
  // An instance is indexed by its definition's bound, derived once, when the
  // *placing* container was built. Adding an entity to that definition
  // dirties one leaf inside the definition's own index -- far below the
  // rebuild floor of 64 -- and touches nothing above it. Until
  // `SpatialIndex._growPlacements` existed, every instance box therefore went
  // on describing the definition as it was, and the new entity was invisible
  // to `forEachInstanceInRect`, `pickInto` and `snapInto` alike while
  // `DraftDocument.extents` reported it perfectly well.

  test('an entity added to a definition is visible through its instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(900);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Grows',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 0);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(901),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: ReservedHandles.layerZero,
    )));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    final added = addLine(doc, def, 100, 100, 101, 100);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'one add must not rebuild; the whole failure lived in the '
            'gap between one dirty entry and the rebuild threshold');
    expect(doc.extents.maxX, closeTo(101.0, 1e-9),
        reason: 'the document can see it, which is what made the index '
            'losing it so quiet');

    final over = Aabb2(Vector2(99, 99), Vector2(102, 101));
    final instances = <Handle>[];
    index.forEachInstanceInRect(over, const QueryFilter.all(), instances.add);
    expect(instances, [const Handle(901)],
        reason: 'the renderer culls with this: an instance box that does not '
            'cover its definition draws nothing over the new geometry');

    final hit = HitPath();
    expect(
        index.pickInto(Vector2(100.5, 100), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, added);

    final snap = SnapResult();
    index.snapInto(Vector2(100, 100), 0.5, SnapMask.cheap, snap);
    expect(snap.found, isTrue);
    expect(snap.entity, added);
  });

  test('growing a definition reaches every one of its placements', () {
    final doc = DraftDocument.empty();
    const def = Handle(910);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'GrowsEverywhere',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 0);
    for (var i = 0; i < 4; i++) {
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: Handle(920 + i),
        parent: doc.rootHandle,
        transform: Transform2.translation(i * 1000.0, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      )));
    }

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    addLine(doc, def, 100, 100, 101, 100);
    expect(index.rebuildCount, rebuildsBefore);

    for (var i = 0; i < 4; i++) {
      final hit = HitPath();
      expect(
        index.pickInto(Vector2(i * 1000.0 + 100.5, 100), 0.5,
            const QueryFilter.all(), hit),
        isTrue,
        reason: 'placement $i must see the growth too -- fixing only the '
            'first placement would pass a single-instance test',
      );
      expect(hit.chainLength, 1);
      expect(hit.chain[0], Handle(920 + i));
    }
  });

  test('growth carries through a definition nested inside a definition', () {
    // Inner is placed by Outer, Outer is placed by the root. Growing Inner
    // grows Outer's instance box for it, which grows Outer's own bound,
    // which has to grow the root's instance box for Outer in turn.
    final doc = DraftDocument.empty();
    const inner = Handle(930);
    const outer = Handle(931);
    for (final (handle, name) in const [(inner, 'Inner'), (outer, 'Outer')]) {
      doc.tree.addDefinition(Definition(
        handle: handle,
        name: name,
        basePoint: Vector2.zero(),
        children: const [],
      ));
    }
    addLine(doc, inner, 0, 0, 1, 0);
    addLine(doc, outer, 0, 0, 1, 0);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(932),
      parent: outer,
      transform: Transform2.translation(10, 0),
      definition: inner,
      layer: ReservedHandles.layerZero,
    )));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(933),
      parent: doc.rootHandle,
      transform: Transform2.translation(0, 500),
      definition: outer,
      layer: ReservedHandles.layerZero,
    )));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    final added = addLine(doc, inner, 200, 200, 201, 200);
    expect(index.rebuildCount, rebuildsBefore);

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(210.5, 700), 0.5, const QueryFilter.all(), hit),
      isTrue,
      reason: 'stopping after one level up leaves the root still holding the '
          "pre-growth box for Outer's instance",
    );
    expect(hit.entity, added);
    expect(hit.chainLength, 2);
    expect(hit.chain[0], const Handle(933));
    expect(hit.chain[1], const Handle(932));
  });

  test('an instance of an untouched definition is not widened', () {
    // The other direction: growth is targeted, not a blanket widening of
    // every instance box in the document.
    final doc = DraftDocument.empty();
    const grown = Handle(940);
    const still = Handle(941);
    for (final (handle, name) in const [(grown, 'Grown'), (still, 'Still')]) {
      doc.tree.addDefinition(Definition(
        handle: handle,
        name: name,
        basePoint: Vector2.zero(),
        children: const [],
      ));
    }
    addLine(doc, grown, 0, 0, 1, 0);
    addLine(doc, still, 0, 0, 1, 0);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(942),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: grown,
      layer: ReservedHandles.layerZero,
    )));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: const Handle(943),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: still,
      layer: ReservedHandles.layerZero,
    )));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    addLine(doc, grown, 100, 100, 101, 100);

    final instances = <Handle>[];
    index.forEachInstanceInRect(Aabb2(Vector2(99, 99), Vector2(102, 101)),
        const QueryFilter.all(), instances.add);
    expect(instances, [const Handle(942)],
        reason: 'only the definition that actually grew reaches out here');
  });

  test('ContainerIndex.bounds tracks an entity added on the dirty path', () {
    // `bounds` is public and documented as the union of everything the
    // container holds. It used to be `final`, set once in `build`, so it
    // stayed at the pre-edit box while every query found the new entity
    // perfectly well -- a lower bound wearing the label of an exact one.
    // `benchmark/query_throughput.dart` derives its query rects from it.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.bounds.maxX, closeTo(1.0, 1e-9));

    final rebuildsBefore = index.rebuildCount;
    addLine(doc, doc.rootHandle, 500, 500, 501, 501);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'a rebuild would re-derive bounds for its own reasons');
    expect(index.rootIndex.bounds.maxX, closeTo(501.0, 1e-9));
    expect(index.rootIndex.bounds.maxY, closeTo(501.0, 1e-9));
  });

  test('ContainerIndex.bounds does not shrink again, as documented', () {
    // The stated limit of the guarantee above, pinned rather than left to
    // prose: `bounds` only ever grows between rebuilds, because narrowing it
    // would mean rescanning every leaf on every edit. Too large costs
    // broad-phase candidates; too small would drop hits.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final far = addLine(doc, doc.rootHandle, 500, 500, 501, 501);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.bounds.maxX, closeTo(501.0, 1e-9));

    final rebuildsBefore = index.rebuildCount;
    doc.commands.execute(RemoveEntityCommand(far));

    expect(index.rebuildCount, rebuildsBefore);
    expect(index.rootIndex.bounds.maxX, closeTo(501.0, 1e-9),
        reason: 'an upper bound, not an exact one, between rebuilds');
    index.rebuildAll();
    expect(index.rootIndex.bounds.maxX, closeTo(1.0, 1e-9),
        reason: 'and exact again immediately after a rebuild');
  });
}
