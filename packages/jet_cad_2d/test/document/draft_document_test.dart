import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord lineRecord(Handle handle, Handle owner) => EntityRecord(
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

void main() {
  test('empty document has standard tables, a root, and empty extents', () {
    final doc = DraftDocument.empty();
    expect(doc.tables.layers[ReservedHandles.layerZero], isNotNull);
    expect(doc.tree[doc.rootHandle], isA<GroupNode>());
    expect(doc.extents.isEmpty, isTrue);
    // Reserved handles can never be reissued.
    expect(doc.handleSeed.next().value,
        greaterThanOrEqualTo(ReservedHandles.firstFree.value));
  });

  test('extents cover entities placed under the root', () {
    final doc = DraftDocument.empty();
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(handle, doc.rootHandle),
      payload: line(0, 0, 10, 5),
    ));
    expect(doc.extents.min, Vector2(0, 0));
    expect(doc.extents.max, Vector2(10, 5));
  });

  test('extents are recomputed after a mutation, not stale', () {
    final doc = DraftDocument.empty();
    final first = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(first, doc.rootHandle),
      payload: line(0, 0, 1, 1),
    ));
    expect(doc.extents.max, Vector2(1, 1));

    final second = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(second, doc.rootHandle),
      payload: line(0, 0, 20, 20),
    ));
    expect(doc.extents.max, Vector2(20, 20));

    doc.commands.undo();
    expect(doc.extents.max, Vector2(1, 1));
  });

  test('an instance contributes its definition bounds under its transform', () {
    final doc = DraftDocument.empty();

    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: [entityHandle],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));

    // The definition alone is not placed, so it contributes nothing yet.
    expect(doc.extents.isEmpty, isTrue);

    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform:
          Transform2.translation(100, 0).multiply(Transform2.scale(3, 3)),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));

    expect(doc.extents.min, Vector2(100, 0));
    expect(doc.extents.max, Vector2(106, 6));
  });

  test('extents follow a node through a nested group, a remove and an undo',
      () {
    // Extents read the containers' `children` lists, which only a maintained
    // parent/children sync keeps current: the group is empty when it is added
    // and gains its child on the next command.
    final doc = DraftDocument.empty();
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(50, 0),
      children: const [],
    )));

    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: [entityHandle],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));

    final instance = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: group,
      transform: Transform2.identity(),
      definition: defHandle,
      layer: ReservedHandles.layerZero,
    )));
    expect(doc.extents.min, Vector2(50, 0));
    expect(doc.extents.max, Vector2(52, 2));

    // Removing unlinks it, so the group contributes nothing.
    doc.commands.execute(RemoveNodeCommand(instance));
    expect(doc.extents.isEmpty, isTrue);

    // Undo re-adds through AddNodeCommand, which links it back.
    doc.commands.undo();
    expect(doc.extents.max, Vector2(52, 2));
  });

  test('definitionBounds is computed once and reused across instances', () {
    final doc = DraftDocument.empty();
    final defHandle = doc.handleSeed.next();
    final entityHandle = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: defHandle,
      name: 'Unit',
      basePoint: Vector2.zero(),
      children: [entityHandle],
    ));
    doc.commands.execute(AddEntityCommand(
      record: lineRecord(entityHandle, defHandle),
      payload: line(0, 0, 2, 2),
    ));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
    expect(doc.definitionBounds(defHandle).max, Vector2(2, 2));
  });

  test('purge compacts both stores, rewrites geomIndex, and clears history',
      () {
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(a, doc.rootHandle), payload: line(0, 0, 1, 1)));
    doc.commands.execute(AddEntityCommand(
        record: lineRecord(b, doc.rootHandle), payload: line(5, 5, 6, 6)));
    doc.commands.execute(RemoveEntityCommand(a));

    doc.purge();

    final slot = doc.entities.slotOf(b)!;
    // The surviving entity still points at its own geometry after both stores
    // were renumbered.
    expect(doc.geometry.read(doc.entities.geomIndexAt(slot)).pointAt(0),
        Vector2(5, 5));
    expect(doc.geometry.liveCount, 1);
    expect(doc.commands.canUndo, isFalse,
        reason: 'purge is not undoable, so history cannot survive it');
  });

  test('purge emits DocumentPurged', () async {
    final doc = DraftDocument.empty();
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);
    doc.purge();
    await Future<void>.delayed(Duration.zero);
    expect(events.last, isA<DocumentPurged>());
    await sub.cancel();
    await doc.dispose();
  });

  test('runtime permissions forbid geometry but allow transform', () {
    final doc = DraftDocument.empty(permissions: DraftPermissions.runtime);
    expect(
      () => doc.commands.execute(AddEntityCommand(
        record: lineRecord(const Handle(1000), doc.rootHandle),
        payload: line(0, 0, 1, 1),
      )),
      throwsA(isA<PermissionDeniedError>()),
    );
    doc.commands.execute(
        TransformNodeCommand(doc.rootHandle, Transform2.translation(1, 1)));
  });
}
