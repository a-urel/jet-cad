import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Builds a fill naming [boundary] directly, bypassing AddRegionCommand, which
/// is the only way to produce the malformed documents this test is about.
Handle rawFill(DraftDocument doc, Handle boundary,
    {Handle? owner, Handle? handle}) {
  final h = handle ?? doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x3366CC),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List(0),
        scalars: Float64List.fromList([boundary.value.toDouble()])),
  ));
  return h;
}

/// Adds a leaf of [kind] with [coords] and returns its handle. `rawFill` and
/// these three tests are the only way to build the malformed documents
/// `validate()` is about -- `AddRegionCommand` refuses every one of them.
Handle rawLeaf(DraftDocument doc, EntityKind kind, List<double> coords,
    {Handle? owner, List<double> scalars = const [], String text = ''}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
      text: text,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
  return h;
}

/// A minimal line entity owned by [owner].
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

void main() {
  test('a document built by commands validates clean', () {
    final doc = DraftDocument.empty();
    doc.commands.execute(AddEntityCommand(
      record: line(doc.handleSeed.next(), doc.rootHandle),
      payload: segment(0, 0, 10, 10),
    ));

    expect(doc.validate(), isEmpty);
  });

  test('reports a root that names no node', () {
    final doc = DraftDocument.empty();
    final oldRoot = doc.rootHandle;
    doc.tree.setRoot(const Handle(999));

    // Asserting the full list, not just `contains(rootMissing)`: setRoot
    // does not touch the old root node, which is still in the tree with
    // parent Handle.none and nothing listing it — so it legitimately also
    // trips parentChildMismatch. A `contains` assertion would not notice if
    // the intended rootMissing diagnostic regressed as long as some other
    // diagnostic happened to still contain the code.
    final result = doc.validate();
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.rootMissing,
      ValidationCodes.parentChildMismatch,
    ]);
    expect(result[0].handles, [const Handle(999)]);
    expect(result[1].handles, [oldRoot, Handle.none]);
  });

  test('reports an entity whose owner names no container', () {
    final doc = DraftDocument.empty();
    doc.entities.add(line(const Handle(500), const Handle(4242)));

    final found = doc
        .validate()
        .where((d) => d.code == ValidationCodes.ownerMissing)
        .toList();
    expect(found, hasLength(1));
    expect(found.single.handles, contains(const Handle(500)));
  });

  test('reports a children entry that resolves to nothing', () {
    final doc = DraftDocument.empty();
    // addNodeUnchecked skips linking, so `children` is authored directly
    // here — which also means 100 is never linked into the root's own
    // `children`, so a parentChildMismatch is legitimately expected too.
    // Asserted as the full ordered list, not `contains`, so an extra or
    // changed diagnostic cannot slip past unnoticed.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(777)],
    ));

    final result = doc.validate();
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.danglingChild,
      ValidationCodes.parentChildMismatch,
    ]);
    expect(result[0].handles, [const Handle(100), const Handle(777)]);
    expect(result[1].handles, [const Handle(100), doc.rootHandle]);
  });

  test('reports parent and children disagreeing', () {
    final doc = DraftDocument.empty();
    // Neither node is linked by addNodeUnchecked: 100 says its parent is the
    // root, but the root's own `children` was never updated to list it, and
    // likewise 101 says its parent is 100 while 100's `children` stays [].
    // That is two mismatches, not one — asserted as the full list below, so
    // a regression that drops either one cannot hide behind `contains`.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101),
      parent: const Handle(100),
      transform: Transform2.identity(),
      children: const [],
    ));

    final result = doc.validate();
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.parentChildMismatch,
      ValidationCodes.parentChildMismatch,
    ]);
    expect(result[0].handles, [const Handle(100), doc.rootHandle]);
    expect(result[1].handles, [const Handle(101), const Handle(100)]);
  });

  test(
      'a parent/children mismatch names the actual lister, not just the '
      'claimed parent', () {
    // 102 names 100 (P) as its parent, but a different container, 101 (Q),
    // is the one that actually lists it — the three-way disagreement the
    // `if (listed != null) listed` element on parentChildMismatch exists
    // for. Every other mismatch fixture in this file happens to produce
    // `listed == null` (nobody lists the node at all), which would leave
    // that element permanently untested without this case.
    final doc = DraftDocument.empty();
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100), // P
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101), // Q
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(102)],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(102),
      parent: const Handle(100), // claims P
      transform: Transform2.identity(),
      children: const [],
    ));

    final result = doc.validate();
    // P and Q are themselves unlinked from the root (same shape as every
    // other addNodeUnchecked fixture in this file), so both also trip a
    // two-element mismatch; only 102's is three-element.
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.parentChildMismatch,
      ValidationCodes.parentChildMismatch,
      ValidationCodes.parentChildMismatch,
    ]);
    expect(result[0].handles, [const Handle(100), doc.rootHandle]);
    expect(result[1].handles, [const Handle(101), doc.rootHandle]);
    expect(result[2].handles,
        [const Handle(102), const Handle(100), const Handle(101)]);
  });

  test('reports a group cycle rather than hanging', () {
    final doc = DraftDocument.empty();
    // 100 -> 101 -> 100, consistent in BOTH directions, so no mismatch is
    // reported and only the cycle check can catch it.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: const Handle(101),
      transform: Transform2.identity(),
      children: const [Handle(101)],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101),
      parent: const Handle(100),
      transform: Transform2.identity(),
      children: const [Handle(100)],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.cycle));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reports a definition that reaches itself', () {
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    const nodeInA = Handle(300);
    const nodeInB = Handle(301);

    doc.tree.addDefinition(Definition(
      handle: defA,
      name: 'A',
      basePoint: Vector2.zero(),
      children: const [nodeInA],
    ));
    doc.tree.addDefinition(Definition(
      handle: defB,
      name: 'B',
      basePoint: Vector2.zero(),
      children: const [nodeInB],
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: nodeInA,
      parent: defA,
      transform: Transform2.identity(),
      definition: defB,
      layer: ReservedHandles.layerZero,
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: nodeInB,
      parent: defB,
      transform: Transform2.identity(),
      definition: defA,
      layer: ReservedHandles.layerZero,
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.definitionCycle));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test(
      'does not throw when a group cycle sits inside a definition reachable '
      'from another definition', () {
    // Regression for a NodeCycleError that used to escape validate()
    // uncaught. D contains an instance of E; E contains group A, which
    // contains group B, which contains group A again — a group `children`
    // cycle nested inside E's subtree. Checking whether E reaches D walks
    // into that cycle via tree.definitionReaches, which is documented to
    // throw NodeCycleError rather than report on a group cycle. Before the
    // fix, that exception propagated straight out of validate(), discarding
    // the tree.cycle diagnostic step 5 had already collected for the same
    // cycle. validate() must return normally and must still report it.
    final doc = DraftDocument.empty();
    const defD = Handle(200);
    const defE = Handle(201);
    const instanceOfE = Handle(300);
    const groupA = Handle(400);
    const groupB = Handle(401);

    doc.tree.addDefinition(Definition(
      handle: defD,
      name: 'D',
      basePoint: Vector2.zero(),
      children: const [instanceOfE],
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: instanceOfE,
      parent: defD,
      transform: Transform2.identity(),
      definition: defE,
      layer: ReservedHandles.layerZero,
    ));
    doc.tree.addDefinition(Definition(
      handle: defE,
      name: 'E',
      basePoint: Vector2.zero(),
      children: const [groupA],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: groupA,
      parent: defE,
      transform: Transform2.identity(),
      children: const [groupB],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: groupB,
      parent: groupA,
      transform: Transform2.identity(),
      children: const [groupA],
    ));

    // The call itself must not throw.
    final result = doc.validate();
    final codes = [for (final d in result) d.code];
    expect(codes, contains(ValidationCodes.cycle));
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reports a definition cycle through every shared edge, not just one',
      () {
    // A has two instance children: one of B, one of C. B's own instance
    // reaches back to A, and so does C's — two distinct cycles (A<->B and
    // A<->C) that share the definition A. A caller that repairs only
    // whichever edge is reported first and re-validates must still see the
    // other one on the very next call, not discover it a pass later.
    final doc = DraftDocument.empty();
    const defA = Handle(200);
    const defB = Handle(201);
    const defC = Handle(202);
    const instAtoB = Handle(300);
    const instAtoC = Handle(301);
    const instBtoA = Handle(302);
    const instCtoA = Handle(303);

    doc.tree.addDefinition(Definition(
      handle: defA,
      name: 'A',
      basePoint: Vector2.zero(),
      children: const [instAtoB, instAtoC],
    ));
    doc.tree.addDefinition(Definition(
      handle: defB,
      name: 'B',
      basePoint: Vector2.zero(),
      children: const [instBtoA],
    ));
    doc.tree.addDefinition(Definition(
      handle: defC,
      name: 'C',
      basePoint: Vector2.zero(),
      children: const [instCtoA],
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: instAtoB,
      parent: defA,
      transform: Transform2.identity(),
      definition: defB,
      layer: ReservedHandles.layerZero,
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: instAtoC,
      parent: defA,
      transform: Transform2.identity(),
      definition: defC,
      layer: ReservedHandles.layerZero,
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: instBtoA,
      parent: defB,
      transform: Transform2.identity(),
      definition: defA,
      layer: ReservedHandles.layerZero,
    ));
    doc.tree.addNodeUnchecked(InstanceNode(
      handle: instCtoA,
      parent: defC,
      transform: Transform2.identity(),
      definition: defA,
      layer: ReservedHandles.layerZero,
    ));

    final cycles = doc
        .validate()
        .where((d) => d.code == ValidationCodes.definitionCycle)
        .toList();
    expect(cycles.any((d) => d.handles.contains(defB)), isTrue,
        reason: 'the A<->B cycle must be reported');
    expect(cycles.any((d) => d.handles.contains(defC)), isTrue,
        reason: 'the A<->C cycle must be reported');
  }, timeout: const Timeout(Duration(seconds: 5)));

  test('reports a leaf handle sitting in a children list', () {
    final doc = DraftDocument.empty();
    final entityHandle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: line(entityHandle, doc.rootHandle),
      payload: segment(0, 0, 1, 1),
    ));
    // As above: addNodeUnchecked leaves 100 unlinked from the root's own
    // `children`, so a parentChildMismatch is expected alongside
    // leafInChildren. Full ordered list, not `contains`, for the same
    // reason.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: [entityHandle],
    ));

    final result = doc.validate();
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.leafInChildren,
      ValidationCodes.parentChildMismatch,
    ]);
    expect(result[0].handles, [const Handle(100), entityHandle]);
    expect(result[1].handles, [const Handle(100), doc.rootHandle]);
  });

  test('diagnostics come back in ascending-handle order, not insertion order',
      () {
    final doc = DraftDocument.empty();
    // Added out of ascending order on purpose — 103, then 101, then 102 —
    // so a pass would prove the order is a property of the handles, not an
    // accident of the order addNodeUnchecked happened to be called in.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(103),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(973)],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(101),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(971)],
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(102),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(972)],
    ));

    final result = doc.validate();

    // Each group's dangling child is reported first, in ascending container
    // order (101, 102, 103); each group also mismatches the root, which was
    // never updated to list it, reported next in the same ascending order.
    expect([
      for (final d in result) d.code
    ], [
      ValidationCodes.danglingChild,
      ValidationCodes.danglingChild,
      ValidationCodes.danglingChild,
      ValidationCodes.parentChildMismatch,
      ValidationCodes.parentChildMismatch,
      ValidationCodes.parentChildMismatch,
    ]);
    expect([
      for (final d in result) d.handles
    ], [
      [const Handle(101), const Handle(971)],
      [const Handle(102), const Handle(972)],
      [const Handle(103), const Handle(973)],
      [const Handle(101), doc.rootHandle],
      [const Handle(102), doc.rootHandle],
      [const Handle(103), doc.rootHandle],
    ]);
  });

  test('a fill naming nothing is reported', () {
    final doc = DraftDocument.empty();
    rawFill(doc, const Handle(9999));
    expect(doc.validate().map((d) => d.code),
        [ValidationCodes.fillBoundaryMissing]);
  });

  test('a fill on a text entity is reported as not fillable', () {
    final doc = DraftDocument.empty();
    // The fill's handle is allocated before the boundary's, the way
    // AddRegionCommand.allocate does it, so this fixture is malformed in
    // exactly one way: fill.value < boundary.value here, which keeps
    // fillDrawOrderInverted from also firing alongside the code under test.
    final fillHandle = doc.handleSeed.next();
    final textHandle =
        rawLeaf(doc, EntityKind.text, [0, 0], scalars: [2.5], text: 'ROOM 3');
    rawFill(doc, textHandle, handle: fillHandle);
    expect(doc.validate().map((d) => d.code),
        [ValidationCodes.fillBoundaryNotFillable]);
  });

  test('a fill on an open polyline is reported as not closed', () {
    final doc = DraftDocument.empty();
    // Fill handle allocated before the boundary's — see the comment in the
    // not-fillable test above.
    final fillHandle = doc.handleSeed.next();
    final open = rawLeaf(doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10]);
    rawFill(doc, open, handle: fillHandle);
    expect(doc.validate().map((d) => d.code),
        [ValidationCodes.fillBoundaryNotClosed]);
  });

  test('a fill in a different owner than its boundary is reported', () {
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    )));
    // Fill handle allocated before the boundary's — see the comment in the
    // not-fillable test above. The boundary still lives under `group` while
    // the fill defaults to the root, so the foreign-owner mismatch is real;
    // only the handle order changes.
    final fillHandle = doc.handleSeed.next();
    final boundary = rawLeaf(
        doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
        owner: group);
    rawFill(doc, boundary, handle: fillHandle); // owner defaults to the root
    expect(doc.validate().map((d) => d.code),
        [ValidationCodes.fillBoundaryForeignOwner]);
  });

  test('an inverted pair is reported and nothing is changed', () {
    final doc = DraftDocument.empty();
    final boundary = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: boundary,
        owner: doc.rootHandle,
        kind: EntityKind.polyline,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const TrueColor(0x000000),
        lineweight: 30,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
    ));
    final fill = rawFill(doc, boundary); // allocated after, so higher
    expect(fill.value, greaterThan(boundary.value));
    final before = DraftDocumentCodec.encodeToString(doc);
    expect(doc.validate().map((d) => d.code),
        [ValidationCodes.fillDrawOrderInverted]);
    expect(DraftDocumentCodec.encodeToString(doc), before,
        reason: 'validate reports and never mutates; a loader that re-sorted '
            'to defend the draw-order rule would make the drawing differ '
            'from the file');
  });
}
