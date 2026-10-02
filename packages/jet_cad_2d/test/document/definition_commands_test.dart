import 'dart:convert';
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

/// A component type the test defines, with two fields neither of which is a
/// default.
class Tally implements Component {
  static const String id = 'test.tally';
  final int count;
  final String label;
  const Tally(this.count, this.label);

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {'count': count, 'label': label};

  static Tally fromJson(Map<String, Object?> json) =>
      Tally(json['count']! as int, json['label']! as String);

  @override
  bool operator ==(Object other) =>
      other is Tally && other.count == count && other.label == label;

  @override
  int get hashCode => Object.hash(count, label);
}

/// A second test type, registered only by the test that needs a type the
/// snapshot never saw.
class Late implements Component {
  const Late();
  @override
  String get typeId => 'test.late';
  @override
  Map<String, Object?> toJson() => const {};
  @override
  bool operator ==(Object other) => other is Late;
  @override
  int get hashCode => 0;
}

/// Not a default layer: layer 0 is what an absent [ObjectLayer] reads as.
const Handle kLayer = Handle(0x2A1);

Map<String, Object?> futurePayload() => {
      'typeId': 'zz.future',
      'k': [1, 2.5],
      'note': 'kept verbatim',
    };

Map<String, Object?> pastPayload() => {
      'typeId': 'aa.past',
      'v': -3,
    };

/// A document with [Tally] registered and two definitions far from the
/// origin, each carrying two registered components of different types
/// ([Tally], [ObjectLayer] on a non-zero layer) and one unknown payload. The
/// second one, [other], is the neighbour a removal must not touch. History
/// cleared.
({DraftDocument doc, Handle def, Handle other}) withComponents() {
  final doc = DraftDocument.empty();
  doc.components.register<Tally>(Tally.id, Tally.fromJson);
  final def = doc.handleSeed.next();
  final other = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddDefinitionCommand(definitionAt(def, baseX: 1e5 + 40, baseY: -7e4)),
    AddDefinitionCommand(definitionAt(other, baseX: -310, baseY: 925)),
    SetComponentCommand<Tally>(def, const Tally(7, 'north')),
    SetComponentCommand<ObjectLayer>(def, const ObjectLayer(kLayer)),
    SetComponentCommand<Tally>(other, const Tally(3, 'south')),
    SetComponentCommand<ObjectLayer>(other, const ObjectLayer(kLayer)),
  ], label: 'Fixture'));
  doc.components.attachUnknown(def, futurePayload());
  doc.components.attachUnknown(other, pastPayload());
  doc.commands.clearHistory();
  return (doc: doc, def: def, other: other);
}

String componentBytes(DraftDocument doc) => jsonEncode(doc.components.toJson());

/// Allows everything a definition's removal needs except components.
const DraftPermissions kNoComponents = DraftPermissions(
    transform: true, components: false, geometry: true, structure: true);

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
  group('D11 RemoveDefinitionCommand takes the handle\'s components', () {
    test('remove takes them all, undo restores the bytes, redo takes them', () {
      final f = withComponents();
      final doc = f.doc;
      final components = componentBytes(doc);
      final document = DraftDocumentCodec.encodeToString(doc);

      doc.commands.execute(RemoveDefinitionCommand(f.def));
      expect(doc.tree.definition(f.def), isNull);
      expect(doc.components.get<Tally>(f.def), isNull);
      expect(doc.components.get<ObjectLayer>(f.def), isNull);
      expect(doc.components.unknownOf(f.def), isEmpty);
      expect(componentBytes(doc), isNot(components));
      // The neighbour keeps everything it carries.
      expect(doc.components.get<Tally>(f.other), const Tally(3, 'south'));
      expect(
          doc.components.get<ObjectLayer>(f.other), const ObjectLayer(kLayer));
      expect(doc.components.unknownOf(f.other), [pastPayload()]);
      expect(doc.components.withComponent<Tally>(), [f.other]);

      doc.commands.undo();
      expect(componentBytes(doc), components);
      expect(DraftDocumentCodec.encodeToString(doc), document);
      expect(doc.components.get<Tally>(f.def), const Tally(7, 'north'));
      expect(doc.components.unknownOf(f.def), [futurePayload()]);
      expect(doc.tree.definition(f.def)!.basePoint, Vector2(1e5 + 40, -7e4));

      doc.commands.redo();
      expect(doc.tree.definition(f.def), isNull);
      expect(doc.components.get<Tally>(f.def), isNull);
      expect(doc.components.get<ObjectLayer>(f.def), isNull);
      expect(doc.components.unknownOf(f.def), isEmpty);
      expect(componentBytes(doc), isNot(components));

      doc.commands.undo();
      expect(componentBytes(doc), components);
    });

    test('a refused removal takes nothing', () {
      final f = withComponents();
      final l = f.doc.handleSeed.next();
      f.doc.commands.execute(leaf(l, f.def, [20, 30, 60, 30]));
      final components = componentBytes(f.doc);
      expect(() => f.doc.commands.execute(RemoveDefinitionCommand(f.def)),
          throwsA(isA<StateError>()));
      expect(componentBytes(f.doc), components);
    });

    test(
        'the forward capabilities are {structure, components} even with '
        'nothing attached; the summary stays structure', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(definitionAt(h)));
      final cmd = RemoveDefinitionCommand(h);
      expect(cmd.capabilities, {Capability.structure, Capability.components});
      expect(cmd.capability, Capability.structure);
      // An ordinary add needs structure alone.
      expect(
          AddDefinitionCommand(definitionAt(doc.handleSeed.next()))
              .capabilities,
          {Capability.structure});

      final changes = <DocChange>[];
      doc.commands.onAfterMutate = changes.add;
      doc.commands.execute(cmd);
      expect(
          (changes.single as CommandApplied).capability, Capability.structure);
    });

    test(
        'without components the forward command is refused before anything '
        'changes, carrying components or not', () {
      final f = withComponents();
      final doc = f.doc;
      final bare = doc.handleSeed.next();
      doc.commands.execute(
          AddDefinitionCommand(definitionAt(bare, baseX: 5e4, baseY: -2e3)));
      final document = DraftDocumentCodec.encodeToString(doc);
      final depth = doc.commands.undoDepth;
      final state = doc.commands.stateId;
      doc.commands.permissions = kNoComponents;

      for (final h in [f.def, bare]) {
        expect(
            () => doc.commands.execute(RemoveDefinitionCommand(h)),
            throwsA(isA<PermissionDeniedError>().having(
                (e) => e.capability, 'capability', Capability.components)),
            reason: h.toHex());
      }
      expect(DraftDocumentCodec.encodeToString(doc), document);
      expect(doc.commands.undoDepth, depth);
      expect(doc.commands.stateId, state);
    });

    test(
        'the inverse of an empty snapshot runs without components; the '
        'inverse of a non-empty one is refused, and kept', () {
      final f = withComponents();
      final doc = f.doc;
      final bare = doc.handleSeed.next();
      doc.commands.execute(
          AddDefinitionCommand(definitionAt(bare, baseX: 5e4, baseY: -2e3)));
      final components = componentBytes(doc);

      // Empty snapshot: removed with everything allowed, undone without
      // components.
      doc.commands.execute(RemoveDefinitionCommand(bare));
      doc.commands.permissions = kNoComponents;
      final changes = <DocChange>[];
      doc.commands.onAfterMutate = changes.add;
      doc.commands.undo();
      expect(doc.tree.definition(bare)!.basePoint, Vector2(5e4, -2e3));
      expect(
          (changes.single as CommandUndone).capability, Capability.structure);

      // Non-empty snapshot: the undo is refused and the entry stays.
      doc.commands.permissions = DraftPermissions.all;
      doc.commands.execute(RemoveDefinitionCommand(f.def));
      final removed = DraftDocumentCodec.encodeToString(doc);
      final depth = doc.commands.undoDepth;
      final state = doc.commands.stateId;
      doc.commands.permissions = kNoComponents;
      expect(
          () => doc.commands.undo(),
          throwsA(isA<PermissionDeniedError>().having(
              (e) => e.capability, 'capability', Capability.components)));
      expect(DraftDocumentCodec.encodeToString(doc), removed);
      expect(doc.tree.definition(f.def), isNull);
      expect(doc.commands.undoDepth, depth);
      expect(doc.commands.stateId, state);

      // Granted again, the same entry undoes to the same bytes.
      doc.commands.permissions = DraftPermissions.all;
      doc.commands.undo();
      expect(componentBytes(doc), components);
    });
  });

  group('D11 the inverse, at its edges', () {
    test(
        'a snapshot of unknown payloads alone is not empty: its undo needs '
        'components', () {
      final doc = DraftDocument.empty();
      final h = doc.handleSeed.next();
      doc.commands.execute(
          AddDefinitionCommand(definitionAt(h, baseX: -4e4, baseY: 6e3)));
      doc.components.attachUnknown(h, futurePayload());
      doc.commands.execute(RemoveDefinitionCommand(h));
      expect(doc.components.unknownOf(h), isEmpty);
      doc.commands.permissions = kNoComponents;
      expect(
          () => doc.commands.undo(),
          throwsA(isA<PermissionDeniedError>().having(
              (e) => e.capability, 'capability', Capability.components)));
      expect(doc.tree.definition(h), isNull);
      doc.commands.permissions = DraftPermissions.all;
      doc.commands.undo();
      expect(doc.components.unknownOf(h), [futurePayload()]);
    });

    test(
        'an add whose snapshot cannot be restored throws and adds nothing '
        '(all-or-nothing)', () {
      final source = ComponentRegistry()
        ..register<Tally>(Tally.id, Tally.fromJson);
      const h = Handle(0x51F3);
      source.attach(h, const Tally(7, 'north'));
      final snapshot = source.snapshotOf(h);

      // This document never registered Tally.
      final doc = DraftDocument.empty();
      final components = componentBytes(doc);
      final depth = doc.commands.undoDepth;
      expect(
          () => doc.commands.execute(AddDefinitionCommand(
              definitionAt(h, baseX: 1e5, baseY: -7e4),
              components: snapshot)),
          throwsA(isA<StateError>()));
      expect(doc.tree.definition(h), isNull);
      expect(componentBytes(doc), components);
      expect(doc.commands.undoDepth, depth);
    });
  });

  group('D11 ComponentRegistry.snapshotOf and restore', () {
    ComponentRegistry registry() => ComponentRegistry()
      ..registerBuiltIns()
      ..register<Tally>(Tally.id, Tally.fromJson);

    test(
        'registered components by type id, unknown payloads oldest first; '
        'restore puts each back exactly', () {
      final r = registry();
      const h = Handle(0x51F3);
      const n = Handle(0x51F4);
      // Unknown payloads attached out of type-id order.
      r.attachUnknown(h, futurePayload());
      r.attachUnknown(h, pastPayload());
      r.attach(h, const Tally(7, 'north'));
      r.attach(h, const ObjectLayer(kLayer));
      r.attach(n, const Tally(2, 'east'));
      final bytes = jsonEncode(r.toJson());

      final s = r.snapshotOf(h);
      expect(s.isEmpty, isFalse);
      expect(s.components, [
        (ObjectLayer.componentTypeId, const ObjectLayer(kLayer)),
        (Tally.id, const Tally(7, 'north')),
      ]);
      expect(s.unknown, [futurePayload(), pastPayload()]);

      r.detachAll(h);
      expect(r.snapshotOf(h).isEmpty, isTrue);
      expect(r.unknownOf(h), isEmpty);
      expect(r.get<Tally>(n), const Tally(2, 'east'));

      r.restore(h, s);
      expect(jsonEncode(r.toJson()), bytes);
      expect(r.unknownOf(h), [futurePayload(), pastPayload()]);
      expect(r.get<Tally>(h), const Tally(7, 'north'));
      expect(r.get<ObjectLayer>(h), const ObjectLayer(kLayer));
    });

    test('a snapshot does not follow later changes and cannot be edited', () {
      final r = registry();
      const h = Handle(0x51F3);
      r.attach(h, const Tally(7, 'north'));
      r.attachUnknown(h, futurePayload());
      final s = r.snapshotOf(h);
      r.attach(h, const ObjectLayer(kLayer));
      r.attachUnknown(h, pastPayload());
      r.detach<Tally>(h);
      expect(s.components, [(Tally.id, const Tally(7, 'north'))]);
      expect(s.unknown, [futurePayload()]);
      expect(() => s.components.clear(), throwsUnsupportedError);
      expect(() => s.unknown.clear(), throwsUnsupportedError);
    });

    test(
        'a handle carrying nothing gives an empty value; restoring it adds '
        'nothing', () {
      final r = registry();
      const h = Handle(0x51F3);
      r.attach(const Handle(0x51F4), const Tally(2, 'east'));
      final s = r.snapshotOf(h);
      expect(s.isEmpty, isTrue);
      expect(s.components, isEmpty);
      expect(s.unknown, isEmpty);
      final bytes = jsonEncode(r.toJson());
      r.restore(h, s);
      expect(jsonEncode(r.toJson()), bytes);
    });

    test('a type registered after the snapshot is not invented', () {
      final r = registry();
      const h = Handle(0x51F3);
      r.attach(h, const Tally(7, 'north'));
      final s = r.snapshotOf(h);
      r.detachAll(h);
      r.register<Late>('test.late', (_) => const Late());
      r.attach(const Handle(0x51F4), const Late());
      r.restore(h, s);
      expect(r.get<Late>(h), isNull);
      expect(r.withComponent<Late>(), [const Handle(0x51F4)]);
      expect(r.get<Tally>(h), const Tally(7, 'north'));
    });
  });
}
