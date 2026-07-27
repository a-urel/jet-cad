import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

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
    doc.tree.setRoot(const Handle(999));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.rootMissing));
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
    // addNodeUnchecked skips linking, so `children` is authored directly here.
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: const [Handle(777)],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.danglingChild));
  });

  test('reports parent and children disagreeing', () {
    final doc = DraftDocument.empty();
    // The node says its parent is 100; 100 does not list it.
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

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.parentChildMismatch));
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

  test('reports a leaf handle sitting in a children list', () {
    final doc = DraftDocument.empty();
    final entityHandle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: line(entityHandle, doc.rootHandle),
      payload: segment(0, 0, 1, 1),
    ));
    doc.tree.addNodeUnchecked(GroupNode(
      handle: const Handle(100),
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      children: [entityHandle],
    ));

    final codes = [for (final d in doc.validate()) d.code];
    expect(codes, contains(ValidationCodes.leafInChildren));
  });

  test('diagnostics come back in a stable order across runs', () {
    DraftDocument broken() {
      final doc = DraftDocument.empty();
      doc.entities.add(line(const Handle(500), const Handle(4242)));
      doc.entities.add(line(const Handle(501), const Handle(4243)));
      doc.tree.addNodeUnchecked(GroupNode(
        handle: const Handle(100),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [Handle(777)],
      ));
      return doc;
    }

    final first = [
      for (final d in broken().validate()) '${d.code}:${d.handles}'
    ];
    final second = [
      for (final d in broken().validate()) '${d.code}:${d.handles}'
    ];
    expect(first, equals(second));
    expect(first, isNotEmpty);
  });
}
