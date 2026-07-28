import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addOn(DraftDocument doc, Handle owner, Handle layer, EntityKind kind) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
      layer: layer,
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
      scalars: Float64List.fromList(
          kind == EntityKind.attrib || kind == EntityKind.text ? [1.0] : []),
    ),
  ));
  return handle;
}

void main() {
  test('entitiesInRect matches forEachInRect, ascending', () {
    final doc = DraftDocument.empty();
    final handles = [
      for (var i = 0; i < 5; i++)
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
    ];
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rect = Aabb2(Vector2(-1, -1), Vector2(5, 5));
    final viaCallback = <Handle>[];
    index.forEachInRect(rect, const QueryFilter.all(),
        (slot) => viaCallback.add(doc.entities.handleAt(slot)));

    expect(index.entitiesInRect(rect, const QueryFilter.all()).toList(),
        viaCallback);
    expect(viaCallback.toSet(), handles.toSet());
  });

  test('entitiesInRect forwards the filter it was given', () {
    // `entitiesInRect` is pure delegation to `forEachInRect`, which is exactly
    // the shape a dropped or hard-coded argument hides in: every assertion
    // that only compares the two against each other still passes when the
    // wrapper substitutes `QueryFilter.all()` for the caller's filter,
    // because both sides then use the same wrong value. This asserts the
    // filter's *effect* instead, so the two filters must disagree on the
    // same document.
    final doc = DraftDocument.empty();
    const hiddenLayer = Handle(60);
    doc.tables.layers.add(LayerRecord(
      handle: hiddenLayer,
      name: 'Hidden',
      color: const IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    final visible =
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    final hidden = addOn(doc, doc.rootHandle, hiddenLayer, EntityKind.line);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rect = Aabb2(Vector2(-1, -1), Vector2(5, 5));

    expect(index.entitiesInRect(rect, const QueryFilter.all()).toList(),
        [visible, hidden],
        reason: 'QueryFilter.all() keeps the entity on the hidden layer');
    expect(index.entitiesInRect(rect, const QueryFilter.rendering()).toList(),
        [visible],
        reason: 'QueryFilter.rendering() drops it -- if this returns both, '
            'the wrapper is not passing the caller\'s filter through');
  });

  test('onLayer returns only that layer, ascending', () {
    final doc = DraftDocument.empty();
    const other = Handle(60);
    doc.tables.layers.add(LayerRecord(
      handle: other,
      name: 'Other',
      color: const IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: false,
    ));
    final onZero = [
      addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
      addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line),
    ];
    addOn(doc, doc.rootHandle, other, EntityKind.line);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.onLayer(ReservedHandles.layerZero).toList(), onZero);
    expect(index.onLayer(other).toList(), hasLength(1));
    expect(index.onLayer(const Handle(9999)).toList(), isEmpty);
  });

  test('onLayer returns handle order, not slot order', () {
    // Slot order and handle order coincide on a fresh document, which would
    // hide an implementation that returns liveSlots order (allocation order)
    // instead of sorting by handle. Delete the first entity so its slot is
    // freed, then add a third entity with a higher handle than the second:
    // the free list is LIFO, so the third entity reuses the first entity's
    // slot. Slot order is then [third, second]; handle order is [second,
    // third].
    final doc = DraftDocument.empty();
    final first =
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    final second =
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    doc.commands.execute(RemoveEntityCommand(first));
    final third =
        addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    expect(third.value, greaterThan(second.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.onLayer(ReservedHandles.layerZero).toList(), [second, third],
        reason: 'must be ascending by handle, not by slot (allocation order)');
  });

  test('instancesOf finds every placement of a definition, ascending', () {
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    for (final d in [defA, defB]) {
      doc.tree.addDefinition(Definition(
        handle: d,
        name: 'D${d.value}',
        basePoint: Vector2.zero(),
        children: const [],
      ));
    }
    for (final (handle, definition) in [
      (const Handle(405), defA),
      (const Handle(401), defA),
      (const Handle(403), defB),
    ]) {
      doc.commands.execute(AddNodeCommand(
        InstanceNode(
          handle: handle,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          definition: definition,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.instancesOf(defA).toList(),
        [const Handle(401), const Handle(405)]);
    expect(index.instancesOf(defB).toList(), [const Handle(403)]);
    expect(index.instancesOf(const Handle(9999)).toList(), isEmpty);
  });

  test('attributesOf returns attrib entities owned by an instance', () {
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
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final attrib =
        addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    addOn(doc, instance, ReservedHandles.layerZero, EntityKind.line);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.attributesOf(instance).toList(), [attrib],
        reason: 'a line owned by the instance is not an attribute');
    expect(index.attributesOf(const Handle(9999)).toList(), isEmpty);
  });

  test('attributesOf excludes attributes owned by a different instance', () {
    // A single-instance fixture cannot tell "attributes of this instance"
    // from "every attribute in the document" -- two instances, each with its
    // own attribute, can.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instanceA = Handle(400);
    const instanceB = Handle(410);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    for (final instance in [instanceA, instanceB]) {
      doc.commands.execute(AddNodeCommand(
        InstanceNode(
          handle: instance,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          definition: def,
          layer: ReservedHandles.layerZero,
        ),
      ));
    }
    final attribA =
        addOn(doc, instanceA, ReservedHandles.layerZero, EntityKind.attrib);
    final attribB =
        addOn(doc, instanceB, ReservedHandles.layerZero, EntityKind.attrib);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.attributesOf(instanceA).toList(), [attribA]);
    expect(index.attributesOf(instanceB).toList(), [attribB]);
  });

  test('attributesOf returns handle order, not slot order', () {
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
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final first =
        addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    final second =
        addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    doc.commands.execute(RemoveEntityCommand(first));
    final third =
        addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    expect(third.value, greaterThan(second.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.attributesOf(instance).toList(), [second, third],
        reason: 'must be ascending by handle, not by slot (allocation order)');
  });

  test('every convenience query is empty on an empty document', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        index
            .entitiesInRect(Aabb2(Vector2(-1e9, -1e9), Vector2(1e9, 1e9)),
                const QueryFilter.all())
            .toList(),
        isEmpty);
    expect(index.onLayer(ReservedHandles.layerZero).toList(), isEmpty);
    expect(index.instancesOf(const Handle(200)).toList(), isEmpty);
    expect(index.attributesOf(const Handle(400)).toList(), isEmpty);
  });

  test('results are materialised, so mutating after the call is safe', () {
    final doc = DraftDocument.empty();
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final result = index.onLayer(ReservedHandles.layerZero);
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);

    expect(result.toList(), hasLength(1),
        reason: 'a lazy iterable would observe the new entity, and would also '
            'be a query running outside the reentrancy guard');
  });

  test('entitiesInRect is materialised, not lazy', () {
    final doc = DraftDocument.empty();
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final rect = Aabb2(Vector2(-1, -1), Vector2(5, 5));
    final result = index.entitiesInRect(rect, const QueryFilter.all());
    addOn(doc, doc.rootHandle, ReservedHandles.layerZero, EntityKind.line);

    expect(result.toList(), hasLength(1),
        reason: 'a lazy iterable would observe the entity added after the '
            'call, and would run forEachInRect outside the reentrancy guard');
  });

  test('instancesOf is materialised, not lazy', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final result = index.instancesOf(def);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(401),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    expect(result.toList(), hasLength(1),
        reason: 'a lazy iterable would observe the instance added after the '
            'call');
  });

  test('attributesOf is materialised, not lazy', () {
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
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final result = index.attributesOf(instance);
    addOn(doc, instance, ReservedHandles.layerZero, EntityKind.attrib);

    expect(result.toList(), hasLength(1),
        reason: 'a lazy iterable would observe the attribute added after the '
            'call');
  });
}
