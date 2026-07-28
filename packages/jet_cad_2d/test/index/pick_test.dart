import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addEntity(DraftDocument doc, Handle owner, EntityKind kind,
    List<double> coords, List<double> scalars) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: kind,
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
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

void main() {
  test('picks a line by its edge', () {
    final doc = DraftDocument.empty();
    final handle =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0.2), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.edge);
  });

  test('prefers a vertex over the edge it sits on', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // (0.1, 0) is on the line AND within radius of the endpoint at (0,0).
    expect(index.pickInto(Vector2(0.1, 0), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.kind, HitKind.vertex,
        reason: 'a click near an endpoint means the endpoint');
  });

  test('reports fill inside a closed polyline', () {
    final doc = DraftDocument.empty();
    final handle = addEntity(doc, doc.rootHandle, EntityKind.polyline,
        [0, 0, 10, 0, 10, 10, 0, 10, 0, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 5), 0.1, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.fill);
  });

  test('misses cleanly and leaves the path reset', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(500, 500), 1.0, const QueryFilter.all(), hit),
        isFalse);
    expect(hit.chainLength, 0);
  });

  test('a miss leaves no stale entity, point, or kind behind', () {
    final doc = DraftDocument.empty();
    final handle =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0.2), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, handle);

    // A caller that forgets to check the return value must not see the
    // *previous* pick's location and mistake it for a fresh hit at (5, 5).
    expect(index.pickInto(Vector2(500, 500), 1.0, const QueryFilter.all(), hit),
        isFalse);
    expect(hit.entity, Handle.none);
    expect(hit.worldPoint, Vector2.zero());
    expect(hit.chainLength, 0);
    expect(hit.truncated, isFalse);
  });

  test('descends into an instance and reports the whole chain', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    const instance = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 100),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(101, 100), 0.5, const QueryFilter.all(), hit),
        isTrue,
        reason: 'the definition body lives at 100,100 once instanced');
    expect(hit.entity, leaf);
    expect(hit.chainLength, greaterThanOrEqualTo(1));
    expect(Handle(hit.chain[0]), instance,
        reason: 'chain[0] is the root-level ancestor, which is what a viewer '
            'selects when a chair inside a table is tapped');
  });

  test('composes rotation, not just translation, on the way into an instance',
      () {
    // A rotation is non-commutative with translation: getting the transform
    // composition order backwards (child-then-parent instead of
    // parent-then-child) would land the query in the wrong place for this
    // fixture but could still pass a translation-only test.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    // A line from (0,0) to (10,0) in definition space.
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    // Rotate 90 degrees CCW about the origin, then translate by (100, 0).
    // The line now runs from world (100,0) to (100,10).
    final rotate = Transform2.rotation(3.14159265358979 / 2);
    final translate = Transform2.translation(100, 0);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: translate.multiply(rotate),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(100, 5), 0.5, const QueryFilter.all(), hit),
        isTrue,
        reason: 'the rotated line now runs vertically through (100, 0..10)');
    expect(hit.entity, leaf);

    // The un-rotated location, where the line would sit if only the
    // translation applied, must NOT hit.
    final miss = HitPath();
    expect(index.pickInto(Vector2(105, 0), 0.4, const QueryFilter.all(), miss),
        isFalse,
        reason: 'this point is only near the leaf under a wrong composition '
            'order');
  });

  test(
      'composes two nested instance transforms in the right order, not just '
      'one', () {
    // The previous test's single level of nesting cannot actually pin the
    // *recursive* composition order: toWorld is Transform2.identity() at
    // depth 0, and multiplying by identity is commutative on either side,
    // so `toWorld.multiply(instanceTransform)` and
    // `instanceTransform.multiply(toWorld)` produce the same result there
    // regardless of which side is wrong. Two levels are needed so that the
    // inner composition step sees a non-identity toWorld.
    final doc = DraftDocument.empty();
    const inner = Handle(200); // contains the leaf
    const outer = Handle(201); // contains one instance of `inner`
    doc.tree.addDefinition(Definition(
      handle: inner,
      name: 'inner',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addDefinition(Definition(
      handle: outer,
      name: 'outer',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, inner, EntityKind.line, [0, 0, 10, 0], []);
    // Inside `outer`, `inner` is rotated 90 degrees CCW about the origin --
    // added directly to the tree, like the nested levels in the
    // "truncates from the root" fixture below, since only the root-level
    // node goes through a command.
    final rotate = Transform2.rotation(3.14159265358979 / 2);
    doc.tree.addNode(InstanceNode(
      handle: const Handle(300),
      parent: outer,
      transform: rotate,
      definition: inner,
      layer: ReservedHandles.layerZero,
    ));
    // At the root, `outer` is placed with a pure translation.
    final translate = Transform2.translation(100, 0);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: translate,
        definition: outer,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Correct composition (translate(100,0) . rotate90) sends local (0,0)
    // and (10,0) to world (100,0) and (100,10): a vertical line at x=100.
    // Reversing the order at the recursive step -- rotate90 . translate(100,0)
    // -- sends them to world (0,100) and (0,110) instead: nowhere near
    // (100, 5).
    final hit = HitPath();
    expect(index.pickInto(Vector2(100, 5), 0.5, const QueryFilter.all(), hit),
        isTrue,
        reason: 'correct composition puts the line at world x=100, y=0..10');
    expect(hit.entity, leaf);

    final wrongOrderLocation = HitPath();
    expect(
        index.pickInto(
            Vector2(0, 105), 0.5, const QueryFilter.all(), wrongOrderLocation),
        isFalse,
        reason: 'this is only near the leaf if the recursive step composed '
            'the instance transform before toWorld instead of after it');
  });

  test('picks under a mirrored instance, where an ellipse method would fail',
      () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400), parent: doc.rootHandle,
        // Mirror in x and stretch in y: determinant is negative and the
        // scale is non-uniform. The narrow phase measures in world space,
        // so this must still be exact.
        transform: Transform2.scale(-1, 3),
        definition: def, layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(-5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaf);
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isFalse,
        reason: 'the mirrored copy is at negative x only');
  });

  test('two coincident root-level lines: the greater handle wins', () {
    // Both lines are directly at the root, so each is its own root-level
    // ancestor (see the next two tests) and this is decided by the
    // root-ancestor comparison itself, not by the leaf fallback -- the
    // dedicated leaf-fallback test below needs two candidates that instead
    // *share* a root-level ancestor.
    final doc = DraftDocument.empty();
    final lower =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final upper =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    expect(upper.value, greaterThan(lower.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, upper);
  });

  test(
      'two coincident leaves under the SAME instance: the greater leaf '
      'handle wins', () {
    // Both leaves are reached through the one instance, so their
    // root-level-ancestor handles are equal and only the leaf fallback can
    // distinguish them -- the case the previous test cannot exercise, since
    // two different root-level entities can never tie on their own handle.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final lower = addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    final upper = addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    expect(upper.value, greaterThan(lower.value));
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

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, upper);
  });

  test(
      "a root-level leaf's own handle is its root-ancestor, not zero -- it "
      'can outrank a low-handled instance', () {
    // A wrong implementation that defaults every root-level leaf to a
    // synthetic root-ancestor of Handle.none (0) would make it lose this
    // tie to *any* instanced content, regardless of relative handle order --
    // contradicting "draw order is ascending handle value" for the common
    // case of a plain entity added after an instance.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addEntity(doc, def, EntityKind.line, [0, 0, 10, 0], []);
    const instance = Handle(201); // a LOW handle
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    // Added after the instance, so its handle is greater.
    final rootLeaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    expect(rootLeaf.value, greaterThan(instance.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, rootLeaf,
        reason: 'the root leaf (handle ${rootLeaf.value}) was drawn after '
            'the instance (handle ${instance.value}) and must win the tie '
            'on that basis, not lose it by being compared as ancestor 0');
  });

  test(
      'the root-ancestor comparison wins even when it disagrees with the '
      'leaf comparison', () {
    // Two separate instances of two separate definitions, each containing
    // one coincident line. The lower-handled instance holds the
    // higher-handled leaf, and vice versa -- so "greater root ancestor wins"
    // and "greater leaf wins" disagree about which candidate should win.
    // Only the ancestor-first rule is correct.
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    doc.tree.addDefinition(Definition(
      handle: defA,
      name: 'A',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addDefinition(Definition(
      handle: defB,
      name: 'B',
      basePoint: Vector2.zero(),
      children: const [],
    ));

    // defA's leaf gets a LOWER handle than defB's leaf...
    final leafInA = addEntity(doc, defA, EntityKind.line, [0, 0, 10, 0], []);
    final leafInB = addEntity(doc, defB, EntityKind.line, [0, 0, 10, 0], []);
    expect(leafInB.value, greaterThan(leafInA.value));

    // ...but the instance of defA gets the HIGHER root-level handle.
    const instanceOfB = Handle(500);
    const instanceOfA = Handle(501);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instanceOfB,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: defB,
        layer: ReservedHandles.layerZero,
      ),
    ));
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: instanceOfA,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: defA,
        layer: ReservedHandles.layerZero,
      ),
    ));
    expect(instanceOfA.value, greaterThan(instanceOfB.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leafInA,
        reason: 'instanceOfA (501) beats instanceOfB (500) at the root '
            'level, even though leafInA (${leafInA.value}) is less than '
            'leafInB (${leafInB.value}) -- the ancestor comparison must be '
            'checked first and short-circuit before the leaf comparison');
  });

  test(
      'kind priority beats the handle tie-break ACROSS different candidate '
      'entities, not only within one entity', () {
    // "prefers a vertex over the edge it sits on" above only proves
    // vertex-before-edge *within a single entity*'s own switch. It says
    // nothing about whether the same priority governs the choice between
    // two *different* entities. Here a low-handled line offers a vertex hit
    // and a high-handled polyline offers only a fill hit at the same query
    // point; the vertex must still win even though the fill candidate would
    // win any handle-only comparison.
    final doc = DraftDocument.empty();
    final lowVertex =
        addEntity(doc, doc.rootHandle, EntityKind.line, [5, 5, 20, 20], []);
    final highFill = addEntity(doc, doc.rootHandle, EntityKind.polyline,
        [0, 0, 10, 0, 10, 10, 0, 10, 0, 0], []);
    expect(highFill.value, greaterThan(lowVertex.value));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // (5,5) is both the low-handled line's own endpoint (a vertex, within
    // radius) and deep inside the high-handled polyline's fill area.
    expect(index.pickInto(Vector2(5, 5), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, lowVertex,
        reason: 'a vertex hit on the lower-handled line must beat a fill '
            'hit on the higher-handled polyline; the kind priority applies '
            'before the handle tie-break even across different entities');
    expect(hit.kind, HitKind.vertex);
  });

  test('respects the filter', () {
    final doc = DraftDocument.empty();
    const locked = Handle(51);
    doc.tables.layers.add(LayerRecord(
      handle: locked,
      name: 'L',
      color: const IndexedColor(7),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: kLineweightDefault,
      transparency: 0,
      visible: true,
      locked: true,
    ));
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: locked,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0]),
        scalars: Float64List(0),
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(index.pickInto(Vector2(5, 0), 0.5, const QueryFilter.picking(), hit),
        isFalse);
  });

  test('a chain deeper than the buffer truncates from the root', () {
    final doc = DraftDocument.empty();
    // Nest definitions four deep with a two-slot chain buffer.
    var inner = const Handle(200);
    doc.tree.addDefinition(Definition(
      handle: inner,
      name: 'L0',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, inner, EntityKind.line, [0, 0, 2, 0], []);

    for (var level = 1; level <= 3; level++) {
      final outer = Handle(200 + level);
      final node = Handle(300 + level);
      doc.tree.addDefinition(Definition(
        handle: outer,
        name: 'L$level',
        basePoint: Vector2.zero(),
        children: const [],
      ));
      doc.tree.addNode(InstanceNode(
        handle: node,
        parent: outer,
        transform: Transform2.identity(),
        definition: inner,
        layer: ReservedHandles.layerZero,
      ));
      inner = outer;
    }
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(500),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: inner,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath(2);
    expect(index.pickInto(Vector2(1, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaf,
        reason: 'truncation must never change which leaf was hit');
    expect(hit.truncated, isTrue);
    expect(hit.chainLength, lessThanOrEqualTo(2));
  });

  test('a chain that fits the buffer exactly is not marked truncated', () {
    // At-capacity, not over it: a truncated flag that fires whenever
    // chainLength == chain.length (rather than only when the real chain was
    // deeper than the buffer) would falsely flag this fixture.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final leaf = addEntity(doc, def, EntityKind.line, [0, 0, 2, 0], []);
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

    // A single root-level instance produces a chain of length 1.
    final hit = HitPath(1);
    expect(index.pickInto(Vector2(1, 0), 0.5, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, leaf);
    expect(hit.chainLength, 1);
    expect(hit.truncated, isFalse);
  });

  test('a nested query throws QueryReentrancyError', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 10, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
      () => index.pickInto(
          Vector2(5, 0), 1.0, const QueryFilter.all(), hit..reset()),
      returnsNormally,
    );

    var threw = false;
    index.forEachInRect(
      Aabb2(Vector2(-10, -10), Vector2(10, 10)),
      const QueryFilter.all(),
      (_) {
        try {
          index.pickInto(Vector2(5, 0), 1.0, const QueryFilter.all(), hit);
        } on QueryReentrancyError {
          threw = true;
        }
      },
    );
    expect(threw, isTrue,
        reason: 'pickInto shares the index scratch state with every other '
            'query and must refuse to run while one is already in progress');
  });

  test('reset() clears every field, not just chainLength', () {
    final hit = HitPath()
      ..entity = const Handle(42)
      ..kind = HitKind.fill
      ..truncated = true
      ..chainLength = 5;
    // In place, not a reassignment: `worldPoint` is final so that `reset()`
    // cannot allocate a fresh vector on every pick.
    hit.worldPoint.setValues(3, 4);

    hit.reset();

    expect(hit.entity, Handle.none);
    expect(hit.kind, HitKind.edge);
    expect(hit.truncated, isFalse);
    expect(hit.worldPoint, Vector2.zero());
    expect(hit.chainLength, 0);
  });
}
