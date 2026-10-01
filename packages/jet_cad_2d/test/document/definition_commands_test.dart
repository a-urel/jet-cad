import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Every fixture here sits off the origin: the definition's base point is
/// (40, 30), the leaf runs (20, 30) to (60, 30) in local space, and the
/// instance is rotated a quarter turn and moved to (1000, 500). The leaf
/// therefore lands on the vertical (970, 520)-(970, 560) in world space.
final Transform2 kPlace = Transform2.translation(1000, 500)
    .multiply(Transform2.rotation(math.pi / 2));

Definition definitionAt(Handle handle,
        {double baseX = 40, double baseY = 30}) =>
    Definition(
      handle: handle,
      name: 'D${handle.value}',
      basePoint: Vector2(baseX, baseY),
      children: const [],
    );

AddEntityCommand leaf(Handle handle, Handle owner, List<double> coords) =>
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byBlockLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByBlockColor(),
        lineweight: kByBlock,
        transparency: kByBlock,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List(0),
      ),
    );

AddNodeCommand instanceOf(Handle handle, Handle definition, Handle parent) =>
    AddNodeCommand(InstanceNode(
      handle: handle,
      parent: parent,
      transform: kPlace,
      definition: definition,
      layer: ReservedHandles.layerZero,
    ));

bool picks(SpatialIndex index, double x, double y, Handle expectedLeaf) {
  final hit = HitPath();
  return index.pickInto(Vector2(x, y), 1.0, const QueryFilter.all(), hit) &&
      hit.entity == expectedLeaf;
}

bool picksAnything(SpatialIndex index, double x, double y) =>
    index.pickInto(Vector2(x, y), 1.0, const QueryFilter.all(), HitPath());

void main() {
  group('AddDefinitionCommand', () {
    test('adds, undoes and redoes the same value', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      final def = definitionAt(h);

      doc.commands.execute(AddDefinitionCommand(def));
      final added = doc.tree.definition(h)!;
      expect(added.name, def.name);
      expect(added.basePoint, Vector2(40, 30));
      expect(added.children, isEmpty);

      doc.commands.undo();
      expect(doc.tree.definition(h), isNull);

      doc.commands.redo();
      final again = doc.tree.definition(h)!;
      expect(again.handle, h);
      expect(again.name, def.name);
      expect(again.basePoint, Vector2(40, 30));
    });

    test('raises the handle seed past a handle it is given', () {
      final doc = DraftDocument.empty();
      const far = Handle(5000);
      doc.commands.execute(AddDefinitionCommand(definitionAt(far)));
      expect(doc.handleSeed.next().value, greaterThan(far.value));
    });

    test('refuses a handle that names a definition, a node or an entity', () {
      final doc = DraftDocument.empty();
      final defHandle = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(defHandle)));
      final nodeHandle = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
        handle: nodeHandle,
        parent: doc.rootHandle,
        transform: kPlace,
        children: const [],
      )));
      final entityHandle = doc.handleSeed.next();
      doc.commands
          .execute(leaf(entityHandle, doc.rootHandle, [100, 100, 200, 100]));
      final depth = doc.commands.undoDepth;
      final state = doc.commands.stateId;

      for (final taken in [defHandle, nodeHandle, entityHandle]) {
        expect(
            () => doc.commands.execute(
                AddDefinitionCommand(definitionAt(taken, baseX: 7, baseY: 9))),
            throwsA(isA<DuplicateHandleError>()),
            reason: '${taken.toHex()} is already taken');
      }
      expect(doc.commands.undoDepth, depth);
      expect(doc.commands.stateId, state);
      // The refused add did not overwrite the existing definition.
      expect(doc.tree.definition(defHandle)!.basePoint, Vector2(40, 30));
    });

    test('refuses a definition that lists children, and mutates nothing', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      final depth = doc.commands.undoDepth;
      expect(
          () => doc.commands.execute(AddDefinitionCommand(Definition(
                handle: h,
                name: 'nested',
                basePoint: Vector2(40, 30),
                children: [doc.handleSeed.next()],
              ))),
          throwsA(isA<ArgumentError>()));
      expect(doc.tree.definition(h), isNull);
      expect(doc.commands.undoDepth, depth);
    });

    test('is refused by a read-only document, and so is its removal', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(h)));
      doc.commands.permissions = DraftPermissions.readOnly;

      expect(
          () => doc.commands.execute(
              AddDefinitionCommand(definitionAt(doc.handleSeed.next()))),
          throwsA(isA<PermissionDeniedError>()));
      expect(() => doc.commands.execute(RemoveDefinitionCommand(h)),
          throwsA(isA<PermissionDeniedError>()));
      expect(doc.tree.definition(h), isNotNull);
    });

    test('moves stateId on add and again on remove', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      final s0 = doc.commands.stateId;
      doc.commands.execute(AddDefinitionCommand(definitionAt(h)));
      final s1 = doc.commands.stateId;
      doc.commands.execute(RemoveDefinitionCommand(h));
      final s2 = doc.commands.stateId;
      expect({s0, s1, s2}, hasLength(3));
    });

    test('capability is structure and touched names the handle', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      final cmd = AddDefinitionCommand(definitionAt(h));
      expect(cmd.capability, Capability.structure);
      final changes = <DocChange>[];
      doc.commands.onAfterMutate = changes.add;
      doc.commands.execute(cmd);
      expect((changes.single as CommandApplied).touched, {h});
      expect(changes.single, isA<CommandApplied>());
    });
  });

  group('RemoveDefinitionCommand', () {
    test('capability is structure and touched names the handle', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(h)));
      final cmd = RemoveDefinitionCommand(h);
      expect(cmd.capability, Capability.structure);
      final changes = <DocChange>[];
      doc.commands.onAfterMutate = changes.add;
      doc.commands.execute(cmd);
      expect((changes.single as CommandApplied).touched, {h});
    });

    test('refuses an unknown handle', () {
      final doc = DraftDocument.empty();
      expect(
          () => doc.commands.execute(RemoveDefinitionCommand(const Handle(77))),
          throwsA(isA<StateError>()));
    });

    test('refuses while an instance names it, allows once it is gone', () {
      final doc = DraftDocument.empty();
      final d = doc.handleSeed.next();
      final i = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      doc.commands.execute(instanceOf(i, d, doc.rootHandle));

      expect(() => doc.commands.execute(RemoveDefinitionCommand(d)),
          throwsA(isA<StateError>()));
      expect(doc.tree.definition(d), isNotNull);

      doc.commands.execute(RemoveNodeCommand(i));
      doc.commands.execute(RemoveDefinitionCommand(d));
      expect(doc.tree.definition(d), isNull);
    });

    test('refuses while a leaf is owned by it, allows once it is gone', () {
      final doc = DraftDocument.empty();
      final d = doc.handleSeed.next();
      final l = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      doc.commands.execute(leaf(l, d, [20, 30, 60, 30]));

      expect(() => doc.commands.execute(RemoveDefinitionCommand(d)),
          throwsA(isA<StateError>()));
      expect(doc.tree.definition(d), isNotNull);

      doc.commands.execute(RemoveEntityCommand(l));
      doc.commands.execute(RemoveDefinitionCommand(d));
      expect(doc.tree.definition(d), isNull);
    });

    test('refuses while a node is parented to it', () {
      final doc = DraftDocument.empty();
      final d = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      final g = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
        handle: g,
        parent: d,
        transform: kPlace,
        children: const [],
      )));
      expect(() => doc.commands.execute(RemoveDefinitionCommand(d)),
          throwsA(isA<StateError>()));
    });

    test('its undo restores the same definition value', () {
      final doc = DraftDocument.empty();
      final d = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      doc.commands.execute(RemoveDefinitionCommand(d));
      expect(doc.tree.definition(d), isNull);

      doc.commands.undo();
      final back = doc.tree.definition(d)!;
      expect(back.handle, d);
      expect(back.name, 'D${d.value}');
      expect(back.basePoint, Vector2(40, 30));
      expect(back.children, isEmpty);
    });
  });

  group('through the spatial index and the extents', () {
    // The pick test proves the index is wired to command changes, not the
    // touched-definition structural arm of its reconcile (equivalent per
    // spec F-13: every alternative falls back to a full rebuild).
    test('a pick finds an instance of an added definition with no rebuild', () {
      final doc = DraftDocument.empty();
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final d = doc.handleSeed.next();
      final l = doc.handleSeed.next();
      final i = doc.handleSeed.next();

      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      doc.commands.execute(leaf(l, d, [20, 30, 60, 30]));
      doc.commands.execute(instanceOf(i, d, doc.rootHandle));

      expect(picks(index, 970, 540, l), isTrue);
      expect(picksAnything(index, 500, 500), isFalse);

      doc.commands.undo();
      doc.commands.undo();
      doc.commands.undo();
      expect(picksAnything(index, 970, 540), isFalse);

      // The same handle comes back as a different definition; a container the
      // index kept from before would still answer at the old place.
      doc.commands.execute(AddDefinitionCommand(definitionAt(d)));
      doc.commands.execute(leaf(l, d, [20, 80, 60, 80]));
      doc.commands.execute(instanceOf(i, d, doc.rootHandle));
      // Local (20,80)-(60,80) lands on (920,520)-(920,560).
      expect(picks(index, 920, 540, l), isTrue);
      expect(picksAnything(index, 970, 540), isFalse);
    });

    test('the extents follow a compound placement and its undo', () {
      final doc = DraftDocument.empty();
      // A non-empty pre-state, so undo is compared against a real box.
      doc.commands.execute(
          leaf(doc.handleSeed.next(), doc.rootHandle, [100, 100, 200, 140]));
      final before = doc.extents;
      expect(before.isEmpty, isFalse);
      final d = doc.handleSeed.next();
      final l = doc.handleSeed.next();
      final i = doc.handleSeed.next();

      doc.commands.execute(CompoundCommand([
        AddDefinitionCommand(definitionAt(d)),
        leaf(l, d, [20, 30, 60, 30]),
        instanceOf(i, d, doc.rootHandle),
      ], label: 'Place'));

      final placed = doc.extents;
      expect(placed.isEmpty, isFalse);
      expect(placed.minX, closeTo(100, 1e-6));
      expect(placed.maxX, closeTo(970, 1e-6));
      expect(placed.minY, closeTo(100, 1e-6));
      expect(placed.maxY, closeTo(560, 1e-6));

      doc.commands.undo();
      expect(doc.commands.undoDepth, 1);
      expect(doc.tree.definition(d), isNull);
      final after = doc.extents;
      expect([after.minX, after.minY, after.maxX, after.maxY],
          [before.minX, before.minY, before.maxX, before.maxY]);

      doc.commands.redo();
      expect(doc.extents.maxX, closeTo(970, 1e-6));
      expect(doc.extents.maxY, closeTo(560, 1e-6));
    });
  });
}
