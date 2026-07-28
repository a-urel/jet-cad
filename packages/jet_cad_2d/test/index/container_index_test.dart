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

GeometryPayload segment(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
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

    // Unused reference kept so the linter does not flag it.
    expect(inDef.value, 300);
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
      index.dirty.put(slot, box(0, 0, 1, 1));
    }
    expect(index.needsRebuild, isFalse, reason: 'threshold is exclusive');
    index.dirty.put(201, box(0, 0, 1, 1));
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
