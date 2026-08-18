import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A text entity with a real string, style and packed attributes — the three
/// things `addEntity` cannot carry.
///
/// Separate helper rather than four more optional parameters on [addEntity]:
/// every text fixture below needs all three together, and a text entity with
/// a default style and `textAttrs: 0` is exactly the degenerate fixture the
/// tests at the bottom of this file exist to rule out.
Handle addText(
  DraftDocument doc,
  Handle owner, {
  required String text,
  required Handle textStyle,
  required List<double> coords,
  required List<double> scalars,
  int textAttrs = 0,
  EntityKind kind = EntityKind.text,
}) {
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
      text: text,
      textStyle: textStyle,
      textAttrs: textAttrs,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    ),
  ));
  return handle;
}

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
    expect(hit.chainLength, 2);
    // *Which* two survive is the whole claim in this test's name, and it was
    // unpinned: asserting only the flag and the length leaves "truncates
    // from the root" and "truncates from the leaf" indistinguishable. The
    // full root-first path here is 500, 303, 302, 301, so keeping the
    // deepest two means the pair nearest the leaf.
    expect([hit.chain[0], hit.chain[1]], [302, 301],
        reason: 'truncation drops from the ROOT end; the surviving entries '
            'must be the instances nearest the leaf, so that chain and '
            'HitPath.entity still describe the same place');
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

  test('picks a leaf owned by a transformed group, at the group location', () {
    // Nothing else in pick_test.dart or snap_test.dart builds a GroupNode at
    // all, which is how a flattened group's transform came to be composed
    // into the broad-phase box and dropped everywhere else: the leaf was
    // correctly *found* by forEachInRect and unpickable at every point.
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
    final handle = addEntity(doc, group, EntityKind.line, [0, 0, 1, 1], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The broad phase always got this right -- it is the narrow phase this
    // pins.
    final seen = <int>[];
    index.forEachInRect(Aabb2(Vector2(99, -1), Vector2(102, 2)),
        const QueryFilter.all(), seen.add);
    expect(seen, hasLength(1), reason: 'broad phase has always found this');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(100.5, 0.5), 0.6, const QueryFilter.all(), hit),
      isTrue,
      reason: "the group's transform must reach the narrow phase, not only "
          'the box',
    );
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.edge);
    expect(hit.worldPoint.x, closeTo(100.5, 1e-9));

    expect(
      index.pickInto(Vector2(0.5, 0.5), 0.6, const QueryFilter.all(), hit),
      isFalse,
      reason: 'and it must not be pickable at its raw local coordinates',
    );
  });

  test('picks a circle at its approximated radius under a non-uniform scale',
      () {
    // A circle under scale(2,5) is an ellipse with semi-axes 4 and 10, but
    // the narrow phase deliberately approximates it by the circle of radius
    // r * scaleMagnitude = 2 * sqrt(10) ~= 6.3246 (see distance.dart: this
    // package does no ellipse math). The exact ellipse's box only reaches
    // x = 4, so a query out at x = 5.5 -- squarely between the two -- was
    // rejected by the broad phase before the narrow phase, which accepts it,
    // ever ran.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'NonUniform',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final circle = addEntity(doc, def, EntityKind.circle, [0, 0], [2.0]);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(201),
        parent: doc.rootHandle,
        transform: Transform2.scale(2, 5),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final approximated = 2.0 * math.sqrt(10.0);
    expect(approximated, greaterThan(4.0),
        reason: 'the approximating circle must stick out past the exact '
            "ellipse's x extent of 4, or this test pins nothing");
    expect((5.5 - approximated).abs(), lessThan(1.0),
        reason: 'the query point must be a hit under the narrow phase\'s own '
            'formula');

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
      reason: 'the broad phase must never be tighter than the region the '
          'narrow phase tests',
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  test('composes a group under a definition as toWorld-after-group', () {
    // The composition ORDER, which every other group test here is blind to:
    // they all hang their group off the root, where `toWorld` is the
    // identity and multiplying by it commutes, so a transposed composition
    // passes them all. This one puts a non-commuting group transform under a
    // non-identity `toWorld`.
    //
    // rotation(pi/2) carries the line (0,0)->(1,0) to (0,0)->(0,1) in the
    // definition, and the instance then translates it to (100,0)->(100,1).
    // Transposed -- translate first, then rotate -- it would land at
    // (0,100)->(0,101) instead, which is what the two picks below tell
    // apart.
    final doc = DraftDocument.empty();
    const def = Handle(400);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'RotatedGroup',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    const group = Handle(401);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: def,
        transform: Transform2.rotation(math.pi / 2),
        children: const [],
      ),
    ));
    final line = addEntity(doc, group, EntityKind.line, [0, 0, 1, 0], []);
    doc.commands.execute(AddNodeCommand(
      // From the seed, not written out: `addEntity` above draws from the same
      // seed, and a handle names one thing across both stores.
      InstanceNode(
        handle: doc.handleSeed.next(),
        parent: doc.rootHandle,
        transform: Transform2.translation(100, 0),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    // The broad phase composes in the same order and has always been right,
    // so this pins the geometry the narrow phase must agree with.
    expect(doc.extents.minX, closeTo(100, 1e-9));
    expect(doc.extents.maxX, closeTo(100, 1e-9));
    expect(doc.extents.minY, closeTo(0, 1e-9));
    expect(doc.extents.maxY, closeTo(1, 1e-9));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(100, 0.5), 0.2, const QueryFilter.all(), hit),
      isTrue,
      reason: 'the group is applied first and toWorld second, so the line is '
          'at x=100 -- transposing the two puts it at y=100 instead',
    );
    expect(hit.entity, line);
    expect(
      index.pickInto(Vector2(0, 100.5), 0.2, const QueryFilter.all(), hit),
      isFalse,
      reason: 'and nothing is at the transposed location',
    );
  });

  test('picks a group-owned leaf that arrived through the dirty overlay', () {
    // The same group transform, but reaching the index by the incremental
    // route rather than by a build: an entity added after the index exists
    // is reconciled into the dirty overlay, not packed into the tree. Its
    // composed group transform has to be recorded there too, or a leaf is
    // pickable before an edit and unpickable after one.
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
    addEntity(doc, group, EntityKind.line, [0, 0, 1, 1], []);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    final late_ = addEntity(doc, group, EntityKind.line, [0, 4, 1, 5], []);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'this must exercise the dirty overlay, not a rebuild that '
            'would quietly re-derive everything from ContainerIndex.build');
    expect(index.indexFor(doc.rootHandle)!.dirty.length, 1);

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(100.5, 4.5), 0.6, const QueryFilter.all(), hit),
      isTrue,
    );
    expect(hit.entity, late_);
  });

  test('picks a circle at its approximated radius under a non-uniform group',
      () {
    // The same boundary as the test above, but with the non-uniform scale on
    // a flattened *group* rather than on an instance. The two reach the
    // narrow phase by different routes -- a group's transform is composed
    // into the leaf's own indexed box, an instance's is applied at descent
    // time -- so the broad phase has to account for them separately, and a
    // fix that only handled the instance route would pass the test above and
    // fail this one.
    final doc = DraftDocument.empty();
    const group = Handle(300);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.scale(2, 5),
        children: const [],
      ),
    ));
    final circle = addEntity(doc, group, EntityKind.circle, [0, 0], [2.0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // The exact bound of the transformed shape stops at x = 4; the
    // approximating circle the narrow phase measures against reaches
    // 2 * sqrt(10).
    expect(doc.extents.maxX, closeTo(4.0, 1e-9));

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  test(
      'a circle added to a non-uniform group after the index exists is '
      'still pickable in the approximation gap', () {
    // The dirty-overlay sibling of the test above, and the *slack* half of
    // reconciliation rather than the transform half: the broad-phase margin
    // is a maximum over the leaves the index knows about, so a round leaf
    // that arrives after the build has to be folded into it. Without that,
    // this circle is indexed and transformed correctly and still unpickable
    // in the gap between its exact bound and its approximated radius.
    final doc = DraftDocument.empty();
    const group = Handle(500);
    doc.commands.execute(AddNodeCommand(
      GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: Transform2.scale(2, 5),
        children: const [],
      ),
    ));
    addEntity(doc, group, EntityKind.line, [0, 0, 1, 1], []);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    final circle = addEntity(doc, group, EntityKind.circle, [0, 0], [2.0]);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'this must exercise the dirty overlay, not a rebuild');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  test(
      'a circle added inside a definition after the index exists is still '
      'pickable through a non-uniform instance', () {
    // The same slack half, one container deeper: the margin the *root*
    // query is widened by is lifted from the definition's own slack through
    // the instance transform, so a round leaf reconciled into the
    // definition's dirty overlay has to reach that lift too.
    //
    // The definition already spans [-2, 2] in both axes before the circle is
    // added, so the instance box stored in the root stays adequate and this
    // test is about the margin rather than about stale instance bounds.
    final doc = DraftDocument.empty();
    const def = Handle(600);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'GrowsACircle',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addEntity(doc, def, EntityKind.line, [-2, -2, 2, 2], []);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(601),
        parent: doc.rootHandle,
        transform: Transform2.scale(2, 5),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final rebuildsBefore = index.rebuildCount;

    final circle = addEntity(doc, def, EntityKind.circle, [0, 0], [2.0]);

    expect(index.rebuildCount, rebuildsBefore,
        reason: 'this must exercise the dirty overlay, not a rebuild');

    final hit = HitPath();
    expect(
      index.pickInto(Vector2(5.5, 0), 1.0, const QueryFilter.all(), hit),
      isTrue,
    );
    expect(hit.entity, circle);
    expect(hit.kind, HitKind.edge);
  });

  // --- arcs -----------------------------------------------------------
  //
  // `pickInto` had no arc coverage here at all, which is how a `worldPoint`
  // that ignored the sweep entirely survived: the hit *test* uses
  // `distanceToArc` and was always right, so an arc-free pick suite could
  // not tell the reported point apart from the query's own verdict.

  test('picks an arc by its drawn sweep', () {
    final doc = DraftDocument.empty();
    final arc = addEntity(
        doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(7.5, 7.5), 1.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, arc);
    expect(hit.kind, HitKind.edge);
    // Inside the sweep, so the reported point is the radial foot: 45
    // degrees out at the arc's own radius.
    expect(hit.worldPoint.x, closeTo(10 / math.sqrt2, 1e-9));
    expect(hit.worldPoint.y, closeTo(10 / math.sqrt2, 1e-9));
  });

  test('misses an arc off its sweep even though the full circle would hit', () {
    final doc = DraftDocument.empty();
    addEntity(
        doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(-10, 0), 1.0, const QueryFilter.all(), hit),
        isFalse,
        reason: 'a point on the circle but off the sweep is not on the arc');
  });

  test('an arc hit past its end reports the endpoint, not a point off the arc',
      () {
    final doc = DraftDocument.empty();
    final arc = addEntity(
        doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // (10, -1) is one unit past the start endpoint (10, 0), measured along
    // the circle it is at angle -0.0997 rad -- outside the sweep [0, pi/2].
    expect(index.pickInto(Vector2(10, -1), 2.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.entity, arc);
    expect(hit.kind, HitKind.edge);

    final angle = math.atan2(hit.worldPoint.y, hit.worldPoint.x);
    expect(angle, greaterThanOrEqualTo(-1e-12),
        reason: 'the reported point must lie on the drawn sweep [0, pi/2], '
            'not on the part of the circle the arc never draws');
    expect(angle, lessThanOrEqualTo(math.pi / 2 + 1e-12));
    expect(hit.worldPoint.x, closeTo(10, 1e-9));
    expect(hit.worldPoint.y, closeTo(0, 1e-9));
  });

  test('pick and snap agree on the point of an arc near its endpoint', () {
    final doc = DraftDocument.empty();
    addEntity(
        doc, doc.rootHandle, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(10, -1), 2.0, const QueryFilter.all(), hit),
        isTrue);

    final snap = SnapResult();
    index.snapInto(Vector2(10, -1), 2.0, SnapMask.all, snap);
    expect(snap.found, isTrue);
    expect(snap.kind, SnapKind.endpoint,
        reason: 'the arc endpoint is the nearest snappable feature here');
    expect(hit.worldPoint.x, closeTo(snap.point.x, 1e-9));
    expect(hit.worldPoint.y, closeTo(snap.point.y, 1e-9));
  });

  test('an arc under a mirroring instance still reports a point on its sweep',
      () {
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'ArcDef',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addEntity(doc, def, EntityKind.arc, [0, 0], [10, 0, math.pi / 2]);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      // Mirrors about the Y axis: the drawn sweep becomes [pi/2, pi].
      transform: Transform2.scale(-1, 1),
      definition: def,
      layer: ReservedHandles.layerZero,
    )));

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(-10, -1), 2.0, const QueryFilter.all(), hit),
        isTrue);
    expect(hit.kind, HitKind.edge);
    final angle = math.atan2(hit.worldPoint.y, hit.worldPoint.x);
    expect(angle, greaterThanOrEqualTo(math.pi / 2 - 1e-12),
        reason: 'the mirrored sweep is [pi/2, pi]');
    expect(angle, lessThanOrEqualTo(math.pi + 1e-12));
  });

  // --- text picks by its laid-out box -----------------------------------
  //
  // Every fixture here uses `MetricModelMeasurer`, never the default
  // `InsertionPointMeasurer`: that one answers `TextMetrics.zero` for every
  // string, which collapses the glyph box to a single point and would let
  // *any* containment rule -- including one that never fires at all -- pass
  // every test below for the wrong reason.

  test('a pointer inside a text box hits it as a fill', () {
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    // 'LONG ROOM NAME' is 14 characters, so under MetricModelMeasurer's
    // defaults (advanceRatio 0.55, ascent 0.8, descent 0.2, cap 0.7, all of
    // kNominalTextPixels = 100) it lays out 770 wide, 80 up and 20 down at
    // the nominal size, scaled by height/capHeight = 200/70. The world box
    // is therefore x in [0, 2200], y in [-57.14, 228.57].
    final textHandle = addText(doc, doc.rootHandle,
        text: 'LONG ROOM NAME',
        textStyle: style.handle,
        coords: [0, 0],
        scalars: [200, 0, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // Well inside the box and far from the insertion point: 404 units away
    // from (0, 0), against a pick radius of 1.
    expect(
        index.pickInto(Vector2(400, 60), 1.0, const QueryFilter.picking(), hit),
        isTrue);
    expect(hit.kind, HitKind.fill);
    expect(hit.entity, textHandle);
    // A fill has no feature of its own, so the query point stands in for it
    // -- the same convention the closed-polyline fill case uses.
    expect(hit.worldPoint.x, closeTo(400, 1e-9));
    expect(hit.worldPoint.y, closeTo(60, 1e-9));
  });

  test('a pointer near the insertion point is no longer a vertex hit', () {
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    addText(doc, doc.rootHandle,
        text: 'LONG ROOM NAME',
        textStyle: style.handle,
        coords: [0, 0],
        scalars: [200, 0, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // (-5, -5) is outside the box (x < 0) but 7 units from the insertion
    // point, well inside the 10-unit radius that used to make it a vertex.
    expect(
        index.pickInto(Vector2(-5, -5), 10.0, const QueryFilter.picking(), hit),
        isFalse,
        reason: 'picking and snapping are different questions: the insertion '
            'point stays a snap candidate and is no longer a pick candidate');
    expect(hit.kind, isNot(HitKind.vertex));
  });

  test('a point entity still picks as a vertex', () {
    // The switch case used to be shared between point, text and attrib;
    // splitting it must not move `point`.
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final handle = addEntity(doc, doc.rootHandle, EntityKind.point, [7, 9], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(8, 9), 5.0, const QueryFilter.picking(), hit),
        isTrue);
    expect(hit.kind, HitKind.vertex);
    expect(hit.entity, handle);
    expect(hit.worldPoint.x, closeTo(7, 1e-9));
    expect(hit.worldPoint.y, closeTo(9, 1e-9));
  });

  test('the insertion point is still a snap candidate', () {
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final textHandle = addText(doc, doc.rootHandle,
        text: 'LONG ROOM NAME',
        textStyle: style.handle,
        coords: [0, 0],
        scalars: [200, 0, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final out = SnapResult();
    index.snapInto(
        Vector2(2, 2), 20.0, SnapMask.none.with_(SnapKind.insertion), out);
    expect(out.found, isTrue);
    expect(out.kind, SnapKind.insertion);
    expect(out.entity, textHandle);
    expect(out.point.x, closeTo(0, 1e-9));
    expect(out.point.y, closeTo(0, 1e-9));
  });

  test('an attrib picks by its box too', () {
    // ATTRIB shares the case with TEXT, and its owner is the INSERT node
    // rather than a container -- so this also pins that the box is measured
    // in the instance's space, not the root's.
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'WithAttrib',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addEntity(doc, def, EntityKind.line, [0, 0, 1, 1], []);
    final inst = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: inst,
      parent: doc.rootHandle,
      // Rotated, not merely translated, and the text itself is rotated too:
      // two pure translations commute, so a fixture built from them cannot
      // tell the composition `world-after-layout` from `layout-after-world`.
      // With both rotations present the two orders land in different places.
      transform: Transform2.rotation(math.pi / 2)
          .multiply(Transform2.translation(1000, 500)),
      definition: def,
      layer: ReservedHandles.layerZero,
    )));
    // 'AB' is 2 characters: 110 wide at the nominal size, scaled by 70/70,
    // so the glyph box is x in [0, 110], y in [-20, 80]. Its own transform
    // rotates that by 0.3 rad and anchors it at instance-local (2, 3); the
    // instance then translates by (1000, 500) and turns a quarter turn, so
    // instance-local (X, Y) lands at world (-(Y + 500), X + 1000).
    final attrib = addText(doc, inst,
        kind: EntityKind.attrib,
        text: 'AB',
        textStyle: style.handle,
        coords: [2, 3],
        scalars: [70, 0.3, 0, 0]);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    // The glyph-box centre (55, 30) is at instance-local (45.678, 47.914)
    // and therefore world (-547.914, 1045.678).
    expect(
        index.pickInto(
            Vector2(-547.914, 1045.678), 0.5, const QueryFilter.picking(), hit),
        isTrue);
    expect(hit.entity, attrib);
    expect(hit.kind, HitKind.fill);
    expect(
        index.pickInto(
            Vector2(45.678, 47.914), 0.5, const QueryFilter.picking(), hit),
        isFalse,
        reason: "the attrib's coordinates are instance-local; a box measured "
            'in root space would hit here instead');
  });

  test('a justified text box is where its justification puts it', () {
    // Right/top justification, so the box hangs to the *left of* and *below*
    // the insertion point. A pick path that hard-coded `textAttrs: 0` would
    // put the box on the opposite side of the anchor on both axes and miss
    // every point this test hits.
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final handle = addText(doc, doc.rootHandle,
        text: 'ABCDE',
        textStyle: style.handle,
        coords: [1000, 1000],
        scalars: [70, 0, 0, 0],
        textAttrs: packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // 'ABCDE' lays out 275 wide at scale 1, so the world box is
    // x in [725, 1000], y in [900, 1000].
    final hit = HitPath();
    expect(
        index.pickInto(
            Vector2(800, 950), 0.5, const QueryFilter.picking(), hit),
        isTrue,
        reason: 'inside the right/top box; outside the left/baseline one');
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.fill);

    expect(
        index.pickInto(
            Vector2(1100, 1020), 0.5, const QueryFilter.picking(), hit),
        isFalse,
        reason: 'inside the left/baseline box the unjustified reading would '
            'produce, and outside the real one');
  });

  test("a non-STANDARD style's fixed height sizes the pickable box", () {
    // Every other text fixture here uses STANDARD, whose fixedHeight is 0 --
    // so "resolve STANDARD" and "resolve the entity's own style" give the
    // same answer and neither can tell a hard-coded STANDARD lookup from a
    // correct one. BIG's fixedHeight overrides the entity's own height
    // scalar, and the two readings differ by 7.14x.
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    const big = TextStyleRecord(
      handle: Handle(600),
      name: 'BIG',
      fontFamily: 'Roboto',
      fixedHeight: 500,
    );
    doc.tables.textStyles.add(big);
    final handle = addText(doc, doc.rootHandle,
        text: 'AB',
        textStyle: big.handle,
        coords: [0, 0],
        scalars: [70, 0, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Under BIG the scale is 500/70, so the box is x in [0, 785.7],
    // y in [-142.9, 571.4]; under STANDARD it would be x in [0, 110],
    // y in [-20, 80].
    final hit = HitPath();
    expect(
        index.pickInto(
            Vector2(400, 300), 0.5, const QueryFilter.picking(), hit),
        isTrue,
        reason: "inside BIG's box, far outside the one a STANDARD lookup "
            'would give');
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.fill);
  });

  test('a rotated text is picked by its oriented box, not its bounds', () {
    // The indexed box is the axis-aligned *bound* of the rotated glyph box.
    // Testing the query point against that bound instead of against the
    // oriented box would hit here, in a corner the glyphs never reach.
    final doc = DraftDocument.empty(measurer: MetricModelMeasurer());
    final style = doc.tables.textStyles.byName('STANDARD')!;
    final handle = addText(doc, doc.rootHandle,
        text: 'AAAA',
        textStyle: style.handle,
        coords: [0, 0],
        // Height 70 (scale 1) rotated by 45 degrees.
        scalars: [70, math.pi / 4, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    // Glyph-space box x in [0, 220], y in [-20, 80]; rotated by 45 degrees
    // its four corners land at (14.1, -14.1), (169.7, 141.4), (99.0, 212.1)
    // and (-56.6, 56.6), whose axis-aligned bound is x in [-56.6, 169.7],
    // y in [-14.1, 212.1].
    final hit = HitPath();
    // Glyph-space (110, 30) -> world (56.57, 98.99): inside the real box.
    expect(
        index.pickInto(
            Vector2(56.57, 98.99), 0.5, const QueryFilter.picking(), hit),
        isTrue);
    expect(hit.entity, handle);
    expect(hit.kind, HitKind.fill);

    // Inside the axis-aligned bound, but glyph-space y = -123.7 there --
    // far below the descent line.
    expect(
        index.pickInto(
            Vector2(165, -10), 0.5, const QueryFilter.picking(), hit),
        isFalse,
        reason: 'a bounds test rather than an oriented-box test would report '
            'a fill here');
  });

  test('a text entity with no laid-out box is not pickable', () {
    // The default measurer answers TextMetrics.zero for every string, which
    // collapses the box to a point and the local transform to a singular
    // matrix. Inverting that throws; the pick must answer "no hit" rather
    // than propagate a SingularTransformError out of a pointer move.
    final doc = DraftDocument.empty();
    final style = doc.tables.textStyles.byName('STANDARD')!;
    addText(doc, doc.rootHandle,
        text: 'INVISIBLE',
        textStyle: style.handle,
        coords: [0, 0],
        scalars: [200, 0, 0, 0]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    expect(index.pickInto(Vector2(0, 0), 5.0, const QueryFilter.picking(), hit),
        isFalse);
  });
}
