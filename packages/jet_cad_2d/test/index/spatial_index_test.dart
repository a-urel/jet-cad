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

Handle addLine(DraftDocument doc, Handle owner, double x1, double y1, double x2,
    double y2) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: line(handle, owner),
    payload: GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('builds an index for the root and for every definition', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'A',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.tree.addDefinition(Definition(
      handle: const Handle(201),
      name: 'B',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, doc.rootHandle, 0, 0, 1, 1);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.containerCount, 3, reason: 'root plus two definitions');
    expect(index.rootIndex.leafCount, 1);
    expect(index.indexFor(const Handle(200)), isNotNull);
    expect(index.indexFor(const Handle(201)), isNotNull);
    expect(index.indexFor(const Handle(999)), isNull);
  });

  test('builds an index for a definition with no instances', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'Unused',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    addLine(doc, const Handle(200), 0, 0, 5, 5);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(index.indexFor(const Handle(200))!.leafCount, 1,
        reason: 'an unplaced definition may be placed at any moment; '
            'building on demand would put an unbounded build in a query');
  });

  test('rebuildAll picks up entities added since construction', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.leafCount, 0);

    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    index.rebuildAll();

    expect(index.rootIndex.leafCount, 1);
  });

  test('rebuildContainer rebuilds only the one named', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'A',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, const Handle(200), 0, 0, 1, 1);

    index.rebuildContainer(const Handle(200));

    expect(index.indexFor(const Handle(200))!.leafCount, 1);
    expect(index.rootIndex.leafCount, 0,
        reason: 'the root was not named and must be untouched');
  });

  test('a definition added after construction gets an index on rebuildAll', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.containerCount, 1);

    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'Late',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    index.rebuildAll();

    expect(index.containerCount, 2);
    expect(index.indexFor(const Handle(200)), isNotNull);
  });

  test('a definition removed after construction loses its index', () {
    final doc = DraftDocument.empty();
    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'Doomed',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.containerCount, 2);

    doc.tree.removeDefinition(const Handle(200));
    index.rebuildAll();

    expect(index.containerCount, 1);
    expect(index.indexFor(const Handle(200)), isNull);
  });

  test('dispose is idempotent', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc)..dispose();
    expect(index.dispose, returnsNormally);
  });
}
