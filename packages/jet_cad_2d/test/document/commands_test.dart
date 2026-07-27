import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

class TestTarget implements CommandTarget {
  @override
  final EntityStore entities = EntityStore();
  @override
  final GeometryStore geometry = GeometryStore();
  @override
  final DocumentTables tables = DocumentTables.standard();
  @override
  final ComponentRegistry components = ComponentRegistry()..registerBuiltIns();
  @override
  final HandleSeed handleSeed = HandleSeed(ReservedHandles.firstFree);
  late final Handle rootHandle = handleSeed.next();
  @override
  late final DocumentTree tree = DocumentTree(
    rootNode: GroupNode(
      handle: rootHandle,
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    ),
  );
  @override
  void invalidateDerived() {}
}

GeometryPayload line(double x1, double y1, double x2, double y2) =>
    GeometryPayload(
      coords: Float64List.fromList([x1, y1, x2, y2]),
      scalars: Float64List(0),
    );

EntityRecord recordFor(Handle handle, Handle owner) => EntityRecord(
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
  test('AddEntityCommand stores geometry and record, and reports the handle',
      () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final handle = target.handleSeed.next();

    dispatcher.execute(AddEntityCommand(
      record: recordFor(handle, target.rootHandle),
      payload: line(0, 0, 10, 0),
    ));

    final slot = target.entities.slotOf(handle)!;
    expect(target.entities.read(slot).handle, handle);
    expect(target.geometry.read(target.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(10, 0));
  });

  test('AddEntityCommand needs the geometry capability', () {
    final dispatcher = CommandDispatcher(
      target: TestTarget(),
      permissions: DraftPermissions.runtime,
    );
    expect(
      () => dispatcher.execute(AddEntityCommand(
        record: recordFor(const Handle(50), const Handle(16)),
        payload: line(0, 0, 1, 1),
      )),
      throwsA(isA<PermissionDeniedError>()),
    );
  });

  test('a rejected AddEntityCommand leaks no geometry slot', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final handle = target.handleSeed.next();
    dispatcher.execute(AddEntityCommand(
      record: recordFor(handle, target.rootHandle),
      payload: line(0, 0, 1, 1),
    ));

    // Four attempts, not one: the leak was one slot per rejected call, so a
    // single attempt could not tell "one orphan" from "the entity's own
    // slot". The counts must not drift at all.
    for (var attempt = 1; attempt <= 4; attempt++) {
      expect(
        () => dispatcher.execute(AddEntityCommand(
          record: recordFor(handle, target.rootHandle),
          payload: line(2, 2, 3, 3),
        )),
        throwsA(isA<DuplicateHandleError>()),
        reason: 'attempt $attempt duplicates a live handle',
      );
      // An orphaned geometry slot is *live*, so purge() would keep it for the
      // life of the document rather than reclaim it.
      expect(target.geometry.liveCount, 1, reason: 'after attempt $attempt');
      expect(target.entities.liveCount, 1, reason: 'after attempt $attempt');
    }

    // History matches what actually mutated: one add, and nothing else.
    dispatcher.undo();
    expect(dispatcher.canUndo, isFalse);
    expect(target.geometry.liveCount, 0);
    expect(target.entities.liveCount, 0);
  });

  test('undo of an add removes both the record and the geometry', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final handle = target.handleSeed.next();
    dispatcher.execute(AddEntityCommand(
      record: recordFor(handle, target.rootHandle),
      payload: line(0, 0, 1, 1),
    ));
    dispatcher.undo();
    expect(target.entities.slotOf(handle), isNull);
    expect(target.geometry.liveCount, 0);
  });

  test("a delete's inverse carries the payload, so undo may use another slot",
      () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);

    final first = target.handleSeed.next();
    final second = target.handleSeed.next();
    dispatcher.execute(AddEntityCommand(
        record: recordFor(first, target.rootHandle),
        payload: line(0, 0, 1, 1)));
    dispatcher.execute(AddEntityCommand(
        record: recordFor(second, target.rootHandle),
        payload: line(9, 9, 8, 8)));
    final firstOriginalSlot = target.entities.slotOf(first)!;
    final secondOriginalSlot = target.entities.slotOf(second)!;

    dispatcher.execute(RemoveEntityCommand(first));
    dispatcher.execute(RemoveEntityCommand(second));

    // A fresh allocation written directly to the stores — outside this
    // dispatcher's history, and so never itself reversible by it —
    // permanently claims the slot the removes just freed. A "remove N, undo
    // N" round trip alone cannot prove this: undo is a perfect inverse of
    // every command it replays, so with nothing claiming the freed slots in
    // between, both entities would land back exactly where they started
    // regardless of removal order — which would pass even against an
    // inverse that carried slot numbers instead of payloads.
    final fillerGeom = target.geometry.add(line(5, 5, 6, 6));
    target.entities.add(recordFor(target.handleSeed.next(), target.rootHandle)
        .copyWith(geomIndex: fillerGeom));

    dispatcher.undo(); // restores `second`
    dispatcher.undo(); // restores `first`

    final firstSlot = target.entities.slotOf(first)!;
    final secondSlot = target.entities.slotOf(second)!;
    expect(firstSlot, isNot(firstOriginalSlot),
        reason: 'first was restored into a claimed slot, not its own');
    expect(secondSlot, isNot(secondOriginalSlot),
        reason: 'second was restored into a claimed slot, not its own');
    // Both are back with their own geometry, whatever slots they landed in.
    expect(
        target.geometry.read(target.entities.geomIndexAt(firstSlot)).pointAt(0),
        Vector2(0, 0));
    expect(
        target.geometry
            .read(target.entities.geomIndexAt(secondSlot))
            .pointAt(0),
        Vector2(9, 9));
  });

  test('TransformNodeCommand needs only the transform capability', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(
      target: target,
      permissions: DraftPermissions.runtime,
    );
    final node = GroupNode(
      handle: target.handleSeed.next(),
      parent: target.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    );
    target.tree.addNode(node);

    dispatcher.execute(
        TransformNodeCommand(node.handle, Transform2.translation(3, 4)));
    expect(
      target.tree[node.handle]!.transform.transformPoint(Vector2.zero()),
      Vector2(3, 4),
    );

    dispatcher.undo();
    expect(target.tree[node.handle]!.transform.isIdentity, isTrue);
  });

  test('AddNodeCommand and RemoveNodeCommand need the structure capability',
      () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final node = GroupNode(
      handle: target.handleSeed.next(),
      parent: target.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    );

    dispatcher.execute(AddNodeCommand(node));
    expect(target.tree[node.handle], isNotNull);

    dispatcher.execute(RemoveNodeCommand(node.handle));
    expect(target.tree[node.handle], isNull);

    dispatcher.undo();
    expect(target.tree[node.handle], isNotNull);

    dispatcher.permissions = DraftPermissions.runtime;
    expect(() => dispatcher.execute(RemoveNodeCommand(node.handle)),
        throwsA(isA<PermissionDeniedError>()));
  });

  test('AddNodeCommand refuses a handle already in the tree', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    final group = target.handleSeed.next();
    final child = target.handleSeed.next();

    dispatcher.execute(AddNodeCommand(GroupNode(
      handle: group,
      parent: target.rootHandle,
      transform: Transform2.translation(5, 0),
      children: const [],
    )));
    dispatcher.execute(AddNodeCommand(GroupNode(
      handle: child,
      parent: group,
      transform: Transform2.identity(),
      children: const [],
    )));
    expect((target.tree[group]! as GroupNode).children, [child]);

    // DocumentTree.addNode does support overwriting a handle it holds. The
    // command cannot: its inverse is RemoveNodeCommand, which deletes rather
    // than restores, so an accepted overwrite would silently discard this
    // group's transform and its child list, and undo would then remove the
    // handle outright and orphan `child`. Three states, none the original.
    final replacement = GroupNode(
      handle: group,
      parent: target.rootHandle,
      transform: Transform2.identity(),
      children: const [],
    );
    expect(() => dispatcher.execute(AddNodeCommand(replacement)),
        throwsA(isA<StateError>()));

    // Nothing moved, and the rejected command left no history behind.
    expect(target.tree[group]!.transform.transformPoint(Vector2.zero()),
        Vector2(5, 0));
    expect((target.tree[group]! as GroupNode).children, [child]);

    dispatcher.undo(); // undoes the *child*, not the rejected overwrite
    expect(target.tree[child], isNull);
    expect(target.tree[group], isNotNull);
    expect(target.tree[group]!.transform.transformPoint(Vector2.zero()),
        Vector2(5, 0));
  });

  test('SetComponentCommand attaches, detaches, and reverses both', () {
    final target = TestTarget();
    final dispatcher = CommandDispatcher(target: target);
    const handle = Handle(1000);

    dispatcher.execute(SetComponentCommand<OriginComponent>(
      handle,
      const OriginComponent(source: SourceKind.dxf, id: '2A'),
    ));
    expect(target.components.get<OriginComponent>(handle)!.id, '2A');

    dispatcher.execute(SetComponentCommand<OriginComponent>(handle, null));
    expect(target.components.get<OriginComponent>(handle), isNull);

    dispatcher.undo();
    expect(target.components.get<OriginComponent>(handle)!.id, '2A');

    dispatcher.undo();
    expect(target.components.get<OriginComponent>(handle), isNull);
  });

  test('SetComponentCommand runs under runtime permissions', () {
    // Editing a table's properties is exactly what a runtime is allowed to do.
    final target = TestTarget();
    final dispatcher = CommandDispatcher(
      target: target,
      permissions: DraftPermissions.runtime,
    );
    dispatcher.execute(SetComponentCommand<OriginComponent>(
      const Handle(1000),
      const OriginComponent(source: SourceKind.native, id: 'x'),
    ));
    expect(
        target.components.get<OriginComponent>(const Handle(1000)), isNotNull);
  });
}
