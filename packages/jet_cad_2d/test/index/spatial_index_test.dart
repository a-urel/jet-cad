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

  test('dispose detaches the hook and is idempotent', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);

    index.dispose();

    // This is the assertion that actually exercises what dispose() exists
    // to do: `returnsNormally` alone cannot fail for the reason a leaked
    // hook would fail, since a leaked hook is silent, not throwing.
    expect(doc.commands.onAfterMutate, isNull,
        reason: 'a disposed index must stop being driven by every future '
            'mutation on the document, not just stop being queried');
    // Same reasoning as above, for the reentrancy guard's hook: dispose()
    // compares with `==`, not `identical`, precisely because two tear-offs
    // of the same instance method are `==` but never `identical`. A
    // regression to `identical` here would make this comparison always
    // false and leave the hook attached forever — silently, since nothing
    // observable breaks until a second index is installed over the same
    // document — which is exactly the failure mode this assertion exists to
    // catch.
    expect(doc.commands.onBeforeMutate, isNull,
        reason: 'a disposed index must stop guarding every future mutation '
            'on the document too, not just stop rebuilding itself');
    expect(index.dispose, returnsNormally);
  });

  test('a DocumentPurged event rebuilds the index via the synchronous hook',
      () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.rootIndex.leafCount, 0);

    addLine(doc, doc.rootHandle, 0, 0, 1, 1);
    addLine(doc, doc.rootHandle, 1, 1, 2, 2);
    expect(index.rootIndex.leafCount, 0,
        reason: 'CommandApplied is not consumed by this task; Task 7 adds '
            'that path, so the index is deliberately stale here');

    doc.purge();

    expect(index.rootIndex.leafCount, 2,
        reason: 'DocumentPurged must reach the index through onAfterMutate, '
            'the same hook execute() uses, not only the async changes '
            'stream');
  });

  test('a DocumentLoaded event rebuilds the index via the synchronous hook',
      () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    expect(index.containerCount, 1);

    // Added directly on the tree, bypassing the index entirely, so the only
    // way the index can possibly know about it is the notifyLoaded() call
    // below reaching onAfterMutate.
    doc.tree.addDefinition(Definition(
      handle: const Handle(200),
      name: 'Late',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    doc.commands.notifyLoaded();

    expect(index.containerCount, 2,
        reason: 'DocumentLoaded must reach the index through onAfterMutate');
    expect(index.indexFor(const Handle(200)), isNotNull);
  });

  test('rebuildContainer refuses a handle that is not an indexed container',
      () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
        () => index.rebuildContainer(const Handle(999)), throwsArgumentError);
    expect(index.indexFor(const Handle(999)), isNull,
        reason: 'a rejected call must not leave a phantom entry behind');
    expect(index.containerCount, 1);
  });

  test('rootIndex after dispose throws a diagnosable StateError', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc)..dispose();

    expect(() => index.rootIndex, throwsA(isA<StateError>()));
  });
}
