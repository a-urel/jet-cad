import 'dart:math' as math;
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

GeometryPayload segment(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

GeometryPayload point(double x, double y) => GeometryPayload(
      coords: Float64List.fromList([x, y]),
      scalars: Float64List(0),
    );

/// Adds a line entity owned by [owner] and returns its handle.
Handle addLine(DraftDocument doc, Handle owner, double x1, double y1, double x2,
    double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: segment(x1, y1, x2, y2),
  ));
  return handle;
}

/// Adds an ATTRIB entity owned by [owner] (an [InstanceNode]) at
/// instance-local point ([x], [y]) and returns its handle.
Handle addAttrib(DraftDocument doc, Handle owner, double x, double y) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: attrib(handle, owner),
    payload: point(x, y),
  ));
  return handle;
}

List<int> leafHits(ContainerIndex index, Aabb2 q) {
  final out = <int>[];
  index.searchLeaves(q, out.add);
  out.sort();
  return out;
}

Aabb2 box(double minX, double minY, double maxX, double maxY) =>
    Aabb2(Vector2(minX, minY), Vector2(maxX, maxY));

void main() {
  test('indexes leaves owned directly by the container', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, doc.rootHandle, 10, 10, 11, 11);

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, 2);
    expect(leafHits(index, box(-1, -1, 2, 2)), hasLength(1));
    expect(leafHits(index, box(-1, -1, 20, 20)), hasLength(2));
  });

  test('flattens a group: its leaves land in the enclosing index', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 0),
        children: const [],
      ),
    ));
    addLine(doc, group, 0, 0, 1, 1);

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, 1,
        reason: 'a group is flattened into its nearest indexed ancestor');
    expect(index.instanceCount, 0, reason: 'a group is not an instance');

    // The group transform must be composed in: the leaf lives at x=100.
    expect(leafHits(index, box(-1, -1, 2, 2)), isEmpty);
    expect(leafHits(index, box(99, -1, 102, 2)), hasLength(1));
  });

  test('composes nested group transforms in the right order', () {
    // Two groups: outer rotates 90 degrees, inner translates +10 in x.
    // A point at inner-local (0,0) is at outer-local (10,0), and after the
    // outer rotation it is at container (0,10). Reversing the composition
    // order puts it at (10,0) instead, which is what this pins.
    final doc = DraftDocument.empty();
    const outer = Handle(100);
    const inner = Handle(101);

    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: outer,
        parent: doc.rootHandle,
        transform: Transform2.rotation(math.pi / 2),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: inner,
        parent: outer,
        transform: Transform2.translation(10, 0),
        children: const [],
      ),
    ));
    addLine(doc, inner, 0, 0, 0, 0); // a degenerate point at inner origin

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(leafHits(index, box(-1, 9, 1, 11)), hasLength(1),
        reason: 'expected the leaf near (0, 10)');
    expect(leafHits(index, box(9, -1, 11, 1)), isEmpty,
        reason: 'a leaf near (10, 0) means the composition order is reversed');
  });

  test('an instance is an entry, not a recursion', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const inDef = Handle(300);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Table',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 2, 2);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(50, 50),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final byOwner = ContainerIndex.leavesByOwner(doc);
    final rootIndex = ContainerIndex.build(doc, doc.rootHandle, byOwner);

    expect(rootIndex.leafCount, 0,
        reason: 'the definition body must NOT be flattened into the root');
    expect(rootIndex.instanceCount, 1);

    final defIndex = ContainerIndex.build(doc, def, byOwner);
    expect(defIndex.leafCount, 1);

    // The instance box is the definition box moved to (50,50)..(52,52).
    final found = <Handle>[];
    rootIndex.searchInstances(box(49, 49, 53, 53), found.add);
    expect(found, [instance]);

    found.clear();
    rootIndex.searchInstances(box(0, 0, 10, 10), found.add);
    expect(found, isEmpty);

    // `bounds` must include the instance box even though this container has
    // no direct leaves of its own (leafCount above is 0) — a document whose
    // content is entirely instances must not report empty bounds.
    expect(rootIndex.bounds.minX, closeTo(50, 1e-9));
    expect(rootIndex.bounds.minY, closeTo(50, 1e-9));
    expect(rootIndex.bounds.maxX, closeTo(52, 1e-9));
    expect(rootIndex.bounds.maxY, closeTo(52, 1e-9));

    // Unused reference kept so the linter does not flag it.
    expect(inDef.value, 300);
  });

  test(
      'bounds unions leaf boxes and instance boxes, in the container\'s own '
      'space', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Widget',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);

    addLine(doc, doc.rootHandle, -10, -10, -9, -9);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(50, 50),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.bounds.minX, closeTo(-10, 1e-9));
    expect(index.bounds.minY, closeTo(-10, 1e-9));
    expect(index.bounds.maxX, closeTo(51, 1e-9),
        reason: 'must include the instance box (50,50)..(51,51), not just '
            'the direct leaf');
    expect(index.bounds.maxY, closeTo(51, 1e-9));
  });

  test('an instance nested inside a group is flattened up, with its transform',
      () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(100);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Chair',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(0, 200),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: group,
        transform: Transform2.translation(5, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.instanceCount, 1);
    final found = <Handle>[];
    index.searchInstances(box(4, 199, 7, 202), found.add);
    expect(found, [instance],
        reason: 'group translate (0,200) then instance translate (5,0)');
  });

  test('transformOfInstance returns the composed container-space transform',
      () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(100);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Chair',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.translation(0, 200),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: group,
        transform: Transform2.translation(5, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    final t = index.transformOfInstance(instance);
    final mapped = t.transformPoint(Vector2.zero());
    expect(mapped.x, closeTo(5, 1e-12));
    expect(mapped.y, closeTo(200, 1e-12));
  });

  test(
      'instance composition order composes the accumulated transform first, '
      'not the instance transform first', () {
    // The enclosing group rotates 90 degrees; the instance under it merely
    // translates. Because rotation and translation do not commute, this
    // pins the operand order of `acc.multiply(instanceTransform)`
    // specifically on the InstanceNode path — unlike a test built entirely
    // from translations (which commute either way and cannot distinguish
    // the two orders).
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const group = Handle(100);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Marker',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 0, 0); // a degenerate point at the origin

    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.rotation(math.pi / 2),
        children: const [],
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: group,
        transform: Transform2.translation(10, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    final t = index.transformOfInstance(instance);
    final mapped = t.transformPoint(Vector2.zero());
    expect(mapped.x, closeTo(0, 1e-9),
        reason: 'acc (the group rotation) must be applied to the instance '
            'transform, not the reverse');
    expect(mapped.y, closeTo(10, 1e-9));

    final found = <Handle>[];
    index.searchInstances(box(-1, 9, 1, 11), found.add);
    expect(found, [instance], reason: 'expected the instance near (0, 10)');

    found.clear();
    index.searchInstances(box(9, -1, 11, 1), found.add);
    expect(found, isEmpty,
        reason: 'a hit near (10, 0) means the instance composition order is '
            'reversed');
  });

  test(
      'an ATTRIB owned by an instance is indexed per placement, into the '
      'enclosing container, not the definition', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instanceA = Handle(400);
    const instanceB = Handle(401);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Tag',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);

    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instanceA,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instanceB,
        parent: doc.rootHandle,
        transform: Transform2.translation(200, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    // Both ATTRIBs are authored at the same instance-local point (3, 0);
    // their placed positions differ per instance because each is
    // transformed by its own owning instance, not shared through the
    // definition.
    final attribA = addAttrib(doc, instanceA, 3, 0);
    final attribB = addAttrib(doc, instanceB, 3, 0);

    final byOwner = ContainerIndex.leavesByOwner(doc);
    final rootIndex = ContainerIndex.build(doc, doc.rootHandle, byOwner);

    expect(rootIndex.leafCount, 2,
        reason: 'both attributes are indexed into the root');
    expect(leafHits(rootIndex, box(102, -1, 104, 1)),
        [doc.entities.slotOf(attribA)!],
        reason: "instanceA's attribute is placed at (103, 0)");
    expect(leafHits(rootIndex, box(202, -1, 204, 1)),
        [doc.entities.slotOf(attribB)!],
        reason: "instanceB's attribute is placed at (203, 0)");

    final defIndex = ContainerIndex.build(doc, def, byOwner);
    expect(defIndex.leafCount, 1,
        reason: 'the definition holds only its own leaf line, never an '
            'attribute — an attribute differs per instance and cannot live '
            'in the shared definition index');
    expect(leafHits(defIndex, box(2, -1, 4, 1)), isEmpty,
        reason: 'an attribute must not appear in the definition index at '
            'its instance-local coordinates either');
  });

  test('a container with many sibling groups indexes every one of them', () {
    // Regression test for a defect in an earlier draft: capping the walk on
    // the number of items momentarily pending on the explicit stack
    // (`stack.length < maxDepth`) conflates pending breadth with path depth.
    // A container with many sibling groups pushes all of them in one pass
    // before any is popped, so a width-shaped cap silently drops siblings
    // past the cap even though the tree is only one level deep.
    final doc = DraftDocument.empty();
    const siblingCount = 300;
    for (var i = 0; i < siblingCount; i++) {
      final g = Handle(1000 + i);
      doc.commands.execute(AddNodeCommand(
        GroupNode(
          handle: g,
          parent: doc.rootHandle,
          transform: Transform2.translation(i.toDouble(), 0),
          children: const [],
        ),
      ));
      addLine(doc, g, 0, 0, 0, 0);
    }

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, siblingCount,
        reason: 'a wide-but-shallow tree must not be capped by pending '
            'stack size, which is unrelated to path depth');
  });

  test('a deeply nested group chain has no artificial depth limit', () {
    final doc = DraftDocument.empty();
    var parent = doc.rootHandle;
    const depth = 300;
    for (var i = 0; i < depth; i++) {
      final g = Handle(2000 + i);
      doc.commands.execute(AddNodeCommand(
        GroupNode(
          handle: g,
          parent: parent,
          transform: Transform2.translation(1, 0),
          children: const [],
        ),
      ));
      parent = g;
    }
    addLine(doc, parent, 0, 0, 0, 0);

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.leafCount, 1,
        reason: 'a legitimately deep, acyclic chain must not be truncated');
    expect(leafHits(index, box(depth - 1.0, -1, depth + 1.0, 1)), hasLength(1),
        reason: 'the leaf must have accumulated all $depth translations');
  });

  test(
      'a children list naming the same instance twice does not crash the '
      'build', () {
    // `DocumentTree._withoutAll`'s doc comment states that a malformed file
    // can list the same child twice, and that shape is tolerated rather than
    // rejected on load. `PackedRTree.build` requires unique payloads, so a
    // walk that pushed such a duplicate straight through into
    // `instanceHandles` would assert (debug) or silently corrupt `markDead`
    // (release, where a duplicate payload leaves the earlier item
    // permanently un-killable). This reaches that shape without a real
    // importer, by writing a corrupted `children` list directly the way
    // `addNodeUnchecked` allows.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);

    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'Duplicated',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0, 1, 1);

    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(10, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final root = doc.tree[doc.rootHandle]! as GroupNode;
    doc.tree.addNodeUnchecked(
        root.copyWith(children: [...root.children, instance]));

    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.instanceCount, 1,
        reason: 'a duplicate children entry must not produce a duplicate '
            'instance entry');
  });

  test('rebuild threshold is max(64, 5 percent of leaves)', () {
    final doc = DraftDocument.empty();
    for (var i = 0; i < 4000; i++) {
      addLine(doc, doc.rootHandle, i.toDouble(), 0, i + 0.5, 1);
    }
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));

    expect(index.rebuildThreshold, 200);
    expect(index.needsRebuild, isFalse);

    // Exactly 200 distinct entries: dirty.length sits at the threshold,
    // not past it. `slot <= 200` here would insert 201 (slots 0..200
    // inclusive), which is already past the threshold and would make
    // this assertion fail — that off-by-one was found while implementing
    // this test; see task-5-report.md.
    for (var slot = 0; slot < 200; slot++) {
      index.dirty
          .put(slot, box(0, 0, 1, 1), DirtyList.noCentre, DirtyList.noCentre);
    }
    expect(index.needsRebuild, isFalse, reason: 'threshold is exclusive');
    index.dirty
        .put(200, box(0, 0, 1, 1), DirtyList.noCentre, DirtyList.noCentre);
    expect(index.needsRebuild, isTrue);
  });

  test('a small index still gets a floor of 64', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    expect(index.rebuildThreshold, 64);
  });

  test('an empty container builds and searches without error', () {
    final doc = DraftDocument.empty();
    final index = ContainerIndex.build(
        doc, doc.rootHandle, ContainerIndex.leavesByOwner(doc));
    expect(index.leafCount, 0);
    expect(index.instanceCount, 0);
    expect(index.bounds.isEmpty, isTrue);
    expect(leafHits(index, box(-1e9, -1e9, 1e9, 1e9)), isEmpty);
  });

  test('leavesByOwner buckets every live entity exactly once, ascending', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [],
      ),
    ));
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, group, 0, 0, 1, 1);
    addLine(doc, group, 2, 2, 3, 3);

    final byOwner = ContainerIndex.leavesByOwner(doc);
    expect(byOwner[doc.rootHandle], hasLength(1));
    expect(byOwner[group], hasLength(2));

    final all = [for (final bucket in byOwner.values) ...bucket]..sort();
    expect(all, doc.entities.liveSlots.toList());
    for (final bucket in byOwner.values) {
      final sorted = [...bucket]..sort();
      expect(bucket, sorted, reason: 'each bucket must be ascending by slot');
    }
  });
}
