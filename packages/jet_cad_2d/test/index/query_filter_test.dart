import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

EntityRecord lineOn(Handle handle, Handle owner, Handle layer,
        {int flags = 0}) =>
    EntityRecord(
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
      flags: flags,
    );

int addOn(DraftDocument doc, Handle owner, Handle layer, {int flags = 0}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: lineOn(handle, owner, layer, flags: flags),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return doc.entities.slotOf(handle)!;
}

/// Chains [depth] nested [GroupNode]s under the document root, each parented
/// to the previous, and returns the innermost one. Only the outermost node's
/// visibility is controlled by [outermostVisible] — every other level stays
/// visible, so a hidden outermost ancestor is the only thing that can make a
/// leaf beneath the chain fail `visibleOnly`. [depth] is chosen by callers to
/// sit past any plausible numeric step cap a walk up the chain might carry.
Handle buildChain(DraftDocument doc, int depth,
    {required bool outermostVisible}) {
  var parent = doc.rootHandle;
  for (var i = 0; i < depth; i++) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: handle,
      parent: parent,
      transform: Transform2.identity(),
      children: const [],
      visible: i == 0 ? outermostVisible : true,
    )));
    parent = handle;
  }
  return parent;
}

void main() {
  test('the four presets differ in exactly the documented way', () {
    const all = QueryFilter.all();
    const rendering = QueryFilter.rendering();
    const picking = QueryFilter.picking();
    const snapping = QueryFilter.snapping();

    expect(all.visibleOnly, isFalse);
    expect(all.excludeLocked, isFalse);
    expect(all.excludeUnpickable, isFalse);
    expect(all.isPassthrough, isTrue);

    expect(rendering.visibleOnly, isTrue);
    expect(rendering.excludeLocked, isFalse);
    expect(rendering.excludeUnpickable, isFalse,
        reason: 'a not-pickable entity still draws (spec 11 D19)');
    expect(rendering.isPassthrough, isFalse);

    expect(picking.visibleOnly, isTrue);
    expect(picking.excludeLocked, isTrue);
    expect(picking.excludeUnpickable, isTrue);
    expect(picking.isPassthrough, isFalse);

    expect(snapping.visibleOnly, isTrue);
    expect(snapping.excludeLocked, isFalse,
        reason: 'a locked layer is still snapped to');
    expect(snapping.excludeUnpickable, isTrue);
    expect(snapping.isPassthrough, isFalse);
  });

  test(
      'QF1 an entity carrying EntityFlags.unpickable passes all() and '
      'rendering() and fails picking() and snapping(); an invisible one '
      'still fails every preset but all(); a filter asking only for the '
      'flag is no passthrough and rejects it', () {
    // The bits first: bit 1, disjoint from bit 0 (invisible).
    expect(EntityFlags.unpickable, 2);
    expect(EntityFlags.unpickable & EntityFlags.invisible, 0);

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
    // Off the origin at fractional coordinates, each segment its own.
    int addAt(Handle layer, int flags, double x, double y) {
      final handle = doc.handleSeed.next();
      doc.commands.execute(AddEntityCommand(
        record: lineOn(handle, doc.rootHandle, layer, flags: flags),
        payload: GeometryPayload(
          coords: Float64List.fromList([x, y, x + 812.25, y - 97.5]),
          scalars: Float64List(0),
        ),
      ));
      return doc.entities.slotOf(handle)!;
    }

    final slots = {
      for (final flags in [0, 1, 2, 3])
        flags: addAt(ReservedHandles.layerZero, flags, 4310.5 + 100.25 * flags,
            -2275.75 + 60.5 * flags),
    };
    final lockedPlain = addAt(locked, 0, 6120.25, 1340.75);
    final lockedFlagged =
        addAt(locked, EntityFlags.unpickable, 6120.25, 1460.75);
    final evaluator = FilterEvaluator(doc);

    Map<int, bool> accepted(QueryFilter f) => {
          for (final e in slots.entries)
            e.key: evaluator.acceptsEntity(e.value, f),
        };

    expect(
        accepted(const QueryFilter.all()), {0: true, 1: true, 2: true, 3: true},
        reason: 'all() rejects nothing');
    expect(accepted(const QueryFilter.rendering()),
        {0: true, 1: false, 2: true, 3: false},
        reason: 'rendering() draws a not-pickable entity; an invisible one '
            'is not drawn');
    expect(accepted(const QueryFilter.picking()),
        {0: true, 1: false, 2: false, 3: false},
        reason: 'picking() refuses the flag and invisibility alike');
    expect(accepted(const QueryFilter.snapping()),
        {0: true, 1: false, 2: false, 3: false},
        reason: 'snapping() refuses the flag and invisibility alike');

    // On a locked, visible layer: snapping() keeps locked geometry and
    // refuses only the flag; picking() refuses both.
    expect(evaluator.acceptsEntity(lockedPlain, const QueryFilter.snapping()),
        isTrue,
        reason: 'how you draw relative to a locked reference');
    expect(evaluator.acceptsEntity(lockedFlagged, const QueryFilter.snapping()),
        isFalse);
    expect(evaluator.acceptsEntity(lockedPlain, const QueryFilter.picking()),
        isFalse);
    expect(evaluator.acceptsEntity(lockedFlagged, const QueryFilter.picking()),
        isFalse);
    expect(
        evaluator.acceptsEntity(lockedFlagged, const QueryFilter.rendering()),
        isTrue);

    // A filter that asks for the flag alone: no visibility, no lock.
    const onlyFlag = QueryFilter(
        visibleOnly: false, excludeLocked: false, excludeUnpickable: true);
    expect(onlyFlag.isPassthrough, isFalse);
    expect(accepted(onlyFlag), {0: true, 1: true, 2: false, 3: false},
        reason: 'flags 1 is invisible but pickable; flags 2 and 3 carry the '
            'flag');
    expect(evaluator.acceptsEntity(lockedPlain, onlyFlag), isTrue);
    expect(evaluator.acceptsEntity(lockedFlagged, onlyFlag), isFalse);
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

  test("an entity's own invisible flag fails visibleOnly but passes all", () {
    // DXF group code 60: the entity exists but is not drawn. The bit has a
    // column and a constant, and until this test nothing read it — an entity
    // marked not-drawn was drawn by the renderer and selectable by a click.
    final doc = DraftDocument.empty();
    final slot = addOn(doc, doc.rootHandle, ReservedHandles.layerZero,
        flags: EntityFlags.invisible);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.all()), isTrue,
        reason: 'a hidden entity is still in the document');
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

  test(
      'a leaf beneath 300 ancestors stays hidden when the outermost is '
      'hidden, past any plausible depth cap', () {
    final doc = DraftDocument.empty();
    final innermost = buildChain(doc, 300, outermostVisible: false);
    final slot = addOn(doc, innermost, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(
        evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isFalse,
        reason: 'the outermost of 300 ancestors is hidden; a walk that gives '
            'up before reaching it would wrongly report this leaf visible');
  });

  test('a leaf beneath 300 all-visible ancestors is visible', () {
    final doc = DraftDocument.empty();
    final innermost = buildChain(doc, 300, outermostVisible: true);
    final slot = addOn(doc, innermost, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(slot, const QueryFilter.rendering()), isTrue,
        reason: 'pairs with the hidden-outermost case above: a walk that '
            'gives up too eagerly and defaults to hidden must not fail this '
            'one');
  });

  test(
      'a genuine parent cycle terminates and answers, from inside it and '
      'from outside it', () {
    final doc = DraftDocument.empty();
    const a = Handle(300);
    const b = Handle(301);
    const c = Handle(302);

    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: a,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    )));
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: b,
      parent: a,
      transform: Transform2.identity(),
      children: const [],
    )));
    // Close the loop directly on the tree: A -> B -> A. No re-parent command
    // exists yet, so this is the only way to build the malformed graph
    // validate() exists to catch — and exactly what a parent-chain walk must
    // survive rather than hang on.
    doc.tree.replaceNode(GroupNode(
      handle: a,
      parent: b,
      transform: Transform2.identity(),
      children: const [],
    ));
    // A third node outside the cycle whose own parent chain leads into it.
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: c,
      parent: a,
      transform: Transform2.identity(),
      children: const [],
    )));

    final insideSlot = addOn(doc, a, ReservedHandles.layerZero);
    final outsideSlot = addOn(doc, c, ReservedHandles.layerZero);
    final evaluator = FilterEvaluator(doc);

    expect(evaluator.acceptsEntity(insideSlot, const QueryFilter.rendering()),
        isTrue,
        reason: 'nothing on the cycle is hidden, and a cycle must not hang '
            'the query');
    expect(evaluator.acceptsEntity(outsideSlot, const QueryFilter.rendering()),
        isTrue,
        reason: 'walking in from outside the cycle must terminate too');
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
