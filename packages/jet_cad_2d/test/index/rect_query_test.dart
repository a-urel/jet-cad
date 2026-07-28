import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner, double x, double y) {
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
      coords: Float64List.fromList([x, y, x + 1, y + 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Aabb2 rect(double minX, double minY, double maxX, double maxY) =>
    Aabb2(Vector2(minX, minY), Vector2(maxX, maxY));

void main() {
  test('returns overlapping root leaves in ascending handle order', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 20; i++) addLine(doc, doc.rootHandle, i * 10.0, 0),
    ];
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    index.forEachInRect(rect(-1, -1, 35, 5), const QueryFilter.all(),
        (slot) => seen.add(doc.entities.handleAt(slot)));

    expect(seen, [handles[0], handles[1], handles[2], handles[3]]);
    expect(
        seen,
        orderedEquals(
            List<Handle>.of(seen)..sort((a, b) => a.value.compareTo(b.value))));
  });

  test(
      'sorts by handle, not slot, when a removal makes them disagree '
      '(the headline guarantee, not just QueryScratch.sortByHandle in '
      'isolation)', () {
    final doc = DraftDocument.empty();
    // The first test above never removes anything, so slot order and handle
    // order coincide there and a plain numeric-slot sort would pass it too.
    // This fixture forces disagreement: remove the middle entity, then add a
    // new one, which reuses the freed slot while taking a larger handle —
    // see SlotAllocator's LIFO free list.
    final a = addLine(doc, doc.rootHandle, 0, 0);
    final b = addLine(doc, doc.rootHandle, 0, 0);
    final c = addLine(doc, doc.rootHandle, 0, 0);
    doc.commands.execute(RemoveEntityCommand(b));
    final d = addLine(doc, doc.rootHandle, 0, 0); // reuses b's slot

    final slotC = doc.entities.slotOf(c)!;
    final slotD = doc.entities.slotOf(d)!;
    expect(slotD, lessThan(slotC),
        reason: 'the fixture is only meaningful if slot order disagrees '
            'with handle order');

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    index.forEachInRect(rect(-10, -10, 10, 10), const QueryFilter.all(),
        (slot) => seen.add(doc.entities.handleAt(slot)));

    expect(seen, [a, c, d],
        reason: 'a query that sorted the raw Int32List of slots instead of '
            'the entity handles would put d (slot $slotD) before c '
            '(slot $slotC)');
  });

  test('does NOT descend into instances', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0);

    for (var i = 0; i < 5; i++) {
      doc.commands.execute(AddNodeCommand(
        InstanceNode(
          handle: Handle(400 + i),
          parent: doc.rootHandle,
          transform: Transform2.translation(i * 2.0, 0),
          definition: def,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var leafVisits = 0;
    index.forEachInRect(
        rect(-10, -10, 100, 100), const QueryFilter.all(), (_) => leafVisits++);
    expect(leafVisits, 0,
        reason: 'descending would report the shared slot once per instance, '
            'with no way to tell the instances apart');

    final instances = <Handle>[];
    index.forEachInstanceInRect(
        rect(-10, -10, 100, 100), const QueryFilter.all(), instances.add);
    expect(instances, hasLength(5));
  });

  test('instances come back in ascending handle order', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0);
    for (final h in [Handle(407), Handle(401), Handle(404)]) {
      doc.commands.execute(AddNodeCommand(
        InstanceNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          definition: def,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    index.forEachInstanceInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), seen.add);
    expect(seen, [const Handle(401), const Handle(404), const Handle(407)]);
  });

  test('the filter is applied to instance queries too, not just entities', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0);
    const hidden = Handle(51);
    doc.tables.layers.add(LayerRecord(
      handle: hidden,
      name: 'H',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(401),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(402),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: hidden,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var all = 0, rendering = 0;
    index.forEachInstanceInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) => all++);
    index.forEachInstanceInRect(rect(-10, -10, 10, 10),
        const QueryFilter.rendering(), (_) => rendering++);

    expect(all, 2);
    expect(rendering, 1,
        reason: 'an instance on a hidden layer must be excluded by '
            'QueryFilter.rendering, not just entities on a hidden layer');
  });

  test('the filter is applied inside the query, not by the caller', () {
    final doc = DraftDocument.empty();
    const hidden = Handle(50);
    doc.tables.layers.add(LayerRecord(
      handle: hidden,
      name: 'H',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    addLine(doc, doc.rootHandle, 0, 0);
    final onHidden = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: onHidden,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: hidden,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 1, 1]),
        scalars: Float64List(0),
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var all = 0, rendering = 0;
    index.forEachInRect(
        rect(-1, -1, 5, 5), const QueryFilter.all(), (_) => all++);
    index.forEachInRect(
        rect(-1, -1, 5, 5), const QueryFilter.rendering(), (_) => rendering++);

    expect(all, 2);
    expect(rendering, 1);
  });

  test('an empty query rect returns nothing', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var visits = 0;
    index.forEachInRect(
        Aabb2.empty(), const QueryFilter.all(), (_) => visits++);
    expect(visits, 0);
  });

  test('an empty rect on a disposed index still throws, like a non-empty one',
      () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    index.dispose();

    expect(
        () =>
            index.forEachInRect(Aabb2.empty(), const QueryFilter.all(), (_) {}),
        throwsStateError,
        reason: 'the empty-rect early return must not run before the '
            'disposed check, or a disposed index would answer silently for '
            'an empty rect while throwing for every other rect');
    expect(
        () => index.forEachInstanceInRect(
            Aabb2.empty(), const QueryFilter.all(), (_) {}),
        throwsStateError);
  });

  test('the instance scratch does not shrink between queries', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, def, 0, 0);
    // More than QueryScratch's default initial capacity (1024), so the
    // buffer must grow past its starting size at least once.
    for (var i = 0; i < 1500; i++) {
      doc.commands.execute(AddNodeCommand(
        InstanceNode(
          handle: Handle(10000 + i),
          parent: doc.rootHandle,
          transform: Transform2.translation(i * 0.001, 0),
          definition: def,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    index.forEachInstanceInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {});
    final grown = index.instanceScratchCapacity;
    expect(grown, greaterThanOrEqualTo(1500));

    index.forEachInstanceInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {});
    expect(index.instanceScratchCapacity, grown,
        reason: 'a List.clear()-backed buffer would shrink to empty here '
            'and regrow on every subsequent query');
  });

  test('the entity scratch does not shrink between queries', () {
    final doc = DraftDocument.empty();
    for (var i = 0; i < 1500; i++) {
      addLine(doc, doc.rootHandle, i * 0.001, 0);
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    index.forEachInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {});
    final grown = index.entityScratchCapacity;
    expect(grown, greaterThanOrEqualTo(1500));

    index.forEachInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {});
    expect(index.entityScratchCapacity, grown,
        reason: 'reset() must not shrink, or every query would regrow');
  });

  test('a slot that is both in the tree and dirty is reported once', () {
    final doc = DraftDocument.empty();
    final handle = addLine(doc, doc.rootHandle, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Move it: the tree entry is marked dead and a dirty entry is written.
    doc.commands.execute(RemoveEntityCommand(handle));
    doc.commands.undo();

    var visits = 0;
    index.forEachInRect(
        rect(-10, -10, 10, 10), const QueryFilter.all(), (_) => visits++);
    expect(visits, 1,
        reason: 'the dead bitmask exists to prevent a double report');
  });
}
