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
