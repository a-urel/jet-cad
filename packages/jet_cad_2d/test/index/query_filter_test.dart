import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord lineOn(Handle handle, Handle owner, Handle layer) => EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: layer,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    );

int addOn(DraftDocument doc, Handle owner, Handle layer) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: lineOn(handle, owner, layer),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return doc.entities.slotOf(handle)!;
}

void main() {
  test('the three presets differ in exactly the documented way', () {
    const all = QueryFilter.all();
    const rendering = QueryFilter.rendering();
    const picking = QueryFilter.picking();

    expect(all.visibleOnly, isFalse);
    expect(all.excludeLocked, isFalse);
    expect(all.isPassthrough, isTrue);

    expect(rendering.visibleOnly, isTrue);
    expect(rendering.excludeLocked, isFalse);
    expect(rendering.isPassthrough, isFalse);

    expect(picking.visibleOnly, isTrue);
    expect(picking.excludeLocked, isTrue);
  });

  test('an entity on a hidden layer fails visibleOnly but passes all', () {
    final doc = DraftDocument.empty();
    const hidden = Handle(50);
    doc.tables.layers.add(LayerRecord(
      handle: hidden,
      name: 'Hidden',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    final slot = addOn(doc, doc.rootHandle, hidden);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.all()), isTrue);
    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse);
    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isFalse);
  });

  test('an entity on a locked layer is visible but not pickable', () {
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    doc.tables.layers.add(LayerRecord(
      handle: locked,
      name: 'Locked',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: true,
    ));
    final slot = addOn(doc, doc.rootHandle, locked);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isTrue,
        reason: 'a locked layer still draws');
    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isFalse,
        reason: 'a locked layer is not selectable');
  });

  test('an entity under a hidden ancestor group is hidden', () {
    final doc = DraftDocument.empty();
    const group = Handle(100);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
      visible: false,
    )));
    final slot = addOn(doc, group, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse,
        reason: 'visibility is inherited down the container chain');
    expect(evaluator.acceptsEntity(slot, const QueryFilter.all()), isTrue);
  });

  test('an entity two hidden levels up is still hidden', () {
    final doc = DraftDocument.empty();
    const outer = Handle(100);
    const inner = Handle(101);
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: outer,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
      visible: false,
    )));
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: inner,
      parent: outer,
      transform: Transform2.identity(),
      children: const [],
      visible: true,
    )));
    final slot = addOn(doc, inner, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse);
  });

  test('acceptsNode applies the same rules to an instance', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: ReservedHandles.layerZero,
      visible: false,
    )));
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsNode(instance, const QueryFilter.all()), isTrue);
    expect(evaluator.acceptsNode(instance, const QueryFilter.rendering()),
        isFalse);
  });

  test(
      'acceptsNode: an instance on a hidden layer fails visibleOnly even '
      'though the node itself is visible', () {
    final doc = DraftDocument.empty();
    const def = Handle(201);
    const instance = Handle(401);
    const hidden = Handle(53);
    doc.tables.layers.add(LayerRecord(
      handle: hidden,
      name: 'HiddenLayer',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T2',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: hidden,
      visible: true,
    )));
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsNode(instance, const QueryFilter.all()), isTrue);
    expect(
        evaluator.acceptsNode(instance, const QueryFilter.rendering()), isFalse,
        reason: 'the instance node itself is visible, but its layer is not');
  });

  test(
      'acceptsNode: an instance on a locked layer is visible but not '
      'pickable', () {
    final doc = DraftDocument.empty();
    const def = Handle(202);
    const instance = Handle(402);
    const locked = Handle(54);
    doc.tables.layers.add(LayerRecord(
      handle: locked,
      name: 'LockedLayer',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: true,
    ));
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T3',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: locked,
      visible: true,
    )));
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsNode(instance, const QueryFilter.rendering()), isTrue,
        reason: 'a locked layer still draws');
    expect(
        evaluator.acceptsNode(instance, const QueryFilter.picking()), isFalse,
        reason: 'a locked layer is not selectable');
  });

  test('invalidate picks up a layer flipped after the first query', () {
    final doc = DraftDocument.empty();
    const layer = Handle(52);
    doc.tables.layers.add(LayerRecord(
      handle: layer,
      name: 'L',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: false,
    ));
    final slot = addOn(doc, doc.rootHandle, layer);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isTrue);

    doc.tables.layers.remove(layer);
    doc.tables.layers.add(LayerRecord(
      handle: layer,
      name: 'L',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: false,
      locked: false,
    ));
    evaluator.invalidate();

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse,
        reason: 'a cached answer must not outlive an invalidate()');
  });

  test('an entity on a layer that does not exist is accepted', () {
    final doc = DraftDocument.empty();
    final slot = addOn(doc, doc.rootHandle, const Handle(9999));
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.picking()), isTrue,
        reason: 'a missing layer is validate()s problem, not a reason to make '
            'geometry silently unselectable');
  });
}
