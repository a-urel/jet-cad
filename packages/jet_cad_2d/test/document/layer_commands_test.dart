import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Spec 12b D1 (the layer commands), D2 (`ObjectLayer`, `objectLayer`) and
/// D5 (empty).
///
/// Fixture (plan P-6): layers A (ACI 1), B (ACI 5, locked), C (ACI 3,
/// hidden) and an unused D (ACI 2) beside a visible layer 0. A group under a
/// non-identity transform holds a line on A away from the origin; a
/// definition placed by an instance on A. No colour is ACI 7; the hidden
/// layer is not layer 0.
class _Fixture {
  final DraftDocument doc;
  late final Handle a = _addLayer('A', 1);
  late final Handle b = _addLayer('B', 5, locked: true);
  late final Handle c = _addLayer('C', 3, visible: false);
  late final Handle d = _addLayer('D', 2);
  late final Handle group;
  late final Handle line;
  late final Handle definition;
  late final Handle instance;

  _Fixture({DraftPermissions permissions = DraftPermissions.all})
      : doc = DraftDocument.empty(permissions: permissions) {
    a;
    b;
    c;
    d;
    group = doc.handleSeed.next();
    doc.tree.addNode(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(500, -300)
          .multiply(Transform2.rotation(math.pi / 6)),
      children: const [],
    ));
    line = addLine(owner: group, layer: a);
    definition = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
      handle: definition,
      name: 'Table',
      basePoint: Vector2(40, 30),
      children: const [],
    ));
    instance = addInstance(layer: a);
  }

  Handle _addLayer(String name, int aci,
      {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.tables.layers
        .add(record(handle, name, aci, visible: visible, locked: locked));
    return handle;
  }

  LayerRecord record(Handle handle, String name, int aci,
      {bool visible = true, bool locked = false}) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    return LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    );
  }

  /// A direct store write (no command, no history): a line on [layer].
  Handle addLine({required Handle owner, required Handle layer}) {
    final handle = doc.handleSeed.next();
    AddEntityCommand(
      record: draftRecord(handle, owner, EntityKind.line,
              layer: ReservedHandles.layerZero)
          .copyWith(
        layer: layer,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList([320, 210, 455, 280]),
        scalars: Float64List(0),
      ),
    ).apply(doc);
    return handle;
  }

  /// A direct tree write: an instance of [definition] on [layer].
  Handle addInstance({required Handle layer}) {
    final handle = doc.handleSeed.next();
    doc.tree.addNode(InstanceNode(
      handle: handle,
      parent: doc.rootHandle,
      transform: Transform2.translation(1200, 800)
          .multiply(Transform2.rotation(math.pi / 2)),
      definition: definition,
      layer: layer,
    ));
    return handle;
  }

  String get bytes => DraftDocumentCodec.encodeToString(doc);

  LayerRecord layer(Handle handle) => doc.tables.layers[handle]!;
}

/// Runs [command] through the dispatcher and expects the user-form
/// refusal: an [ArgumentError], with the document's encoded bytes and the
/// undo depth unchanged.
void _expectRefused(_Fixture f, DraftCommand command) {
  final before = f.bytes;
  final depth = f.doc.commands.undoDepth;
  expect(() => f.doc.commands.execute(command), throwsArgumentError);
  expect(f.bytes, before, reason: 'a refusal mutates nothing');
  expect(f.doc.commands.undoDepth, depth);
}

/// Executes [command], then undoes and redoes it, checking the document's
/// bytes return exactly to the state before and after.
void _expectRoundTrip(
    _Fixture f, DraftCommand command, void Function() checkApplied) {
  final before = f.bytes;
  f.doc.commands.execute(command);
  checkApplied();
  final after = f.bytes;
  expect(after, isNot(before));
  f.doc.commands.undo();
  expect(f.bytes, before, reason: 'the inverse restores exactly');
  f.doc.commands.redo();
  checkApplied();
  expect(f.bytes, after, reason: 're-apply gives the same document');
}

/// Reloads [doc] through the codec, as a file would bring it in.
DraftDocument reload(DraftDocument doc) =>
    DraftDocumentCodec.decodeString(DraftDocumentCodec.encodeToString(doc));

void main() {
  group('ObjectLayer', () {
    test('serialises its layer, compares by value and is registered', () {
      const component = ObjectLayer(Handle(0x2a));
      expect(component.typeId, 'jet_cad.object_layer');
      expect(component.toJson(), {'layer': 0x2a});
      expect(ObjectLayer.fromJson(component.toJson()), component);
      expect(component, isNot(const ObjectLayer(Handle(0x2b))));
      final registry = DraftDocument.empty().components;
      expect(registry.isRegistered<ObjectLayer>(), isTrue);
      expect(registry.isInternal('jet_cad.object_layer'), isFalse,
          reason: 'document content, not engine bookkeeping (S-16)');
    });

    test('round-trips through the codec on a fresh document', () {
      final f = _Fixture();
      f.doc.components.attach(f.group, ObjectLayer(f.b));
      final loaded = reload(f.doc);
      expect(loaded.components.get<ObjectLayer>(f.group), ObjectLayer(f.b));
      expect(DraftDocumentCodec.encodeToString(loaded), f.bytes);
    });

    test('objectLayer: the component layer, else layer 0', () {
      final f = _Fixture();
      expect(objectLayer(f.doc, f.group), ReservedHandles.layerZero,
          reason: 'no component means layer 0');
      f.doc.components.attach(f.group, ObjectLayer(f.c));
      expect(objectLayer(f.doc, f.group), f.c,
          reason: 'a hidden layer is still the object\'s layer');
      final missing = f.doc.handleSeed.next();
      f.doc.components.attach(f.group, ObjectLayer(missing));
      expect(objectLayer(f.doc, f.group), ReservedHandles.layerZero,
          reason: 'a missing layer reads as layer 0');
      expect(f.doc.components.get<ObjectLayer>(f.group), ObjectLayer(missing),
          reason: 'and the stored value is kept');
    });
  });

  group('AddLayerCommand', () {
    test('adds the record exactly, undoes and redoes', () {
      final f = _Fixture();
      final h = f.doc.handleSeed.next();
      final rec = f.record(h, 'Furniture', 6, locked: true);
      final command = AddLayerCommand(rec);
      expect(command.label, 'Add layer');
      _expectRoundTrip(f, command, () => expect(f.layer(h), rec));
    });

    test('raises the seed past its handle', () {
      final f = _Fixture();
      final h = Handle(f.doc.handleSeed.current.value + 40);
      f.doc.commands.execute(AddLayerCommand(f.record(h, 'Far', 4)));
      expect(f.doc.handleSeed.current, h);
      expect(f.doc.handleSeed.next().value, h.value + 1);
    });

    test(
        'refuses a duplicate name under toLowerCase(), an invalid name and '
        'a used handle', () {
      final f = _Fixture();
      final h = f.doc.handleSeed.next();
      _expectRefused(f, AddLayerCommand(f.record(h, 'a', 6)));
      _expectRefused(f, AddLayerCommand(f.record(h, 'Bad:name', 6)));
      _expectRefused(f, AddLayerCommand(f.record(h, ' Padded', 6)));
      // A handle names one thing: an entity, a node, a definition or a layer.
      for (final used in [f.line, f.group, f.definition, f.c]) {
        final before = f.bytes;
        expect(
            () =>
                f.doc.commands.execute(AddLayerCommand(f.record(used, 'E', 6))),
            throwsA(isA<DuplicateHandleError>()));
        expect(f.bytes, before);
      }
    });
  });

  group('RemoveLayerCommand', () {
    test('removes an empty layer, undo restores the record exactly', () {
      final f = _Fixture();
      final rec = f.layer(f.d);
      final command = RemoveLayerCommand(f.d);
      expect(command.label, 'Delete layer');
      _expectRoundTrip(
          f, command, () => expect(f.doc.tables.layers[f.d], isNull));
      f.doc.commands.undo();
      expect(f.layer(f.d), rec);
    });

    test('refuses layer 0, the effective current layer and a missing layer',
        () {
      final f = _Fixture();
      _expectRefused(f, RemoveLayerCommand(ReservedHandles.layerZero));
      f.doc.header.currentLayer = f.d;
      _expectRefused(f, RemoveLayerCommand(f.d));
      _expectRefused(f, RemoveLayerCommand(f.doc.handleSeed.next()));
    });

    test('a hidden stored current layer is not the effective one and may go',
        () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.c;
      f.doc.commands.execute(RemoveLayerCommand(f.c));
      expect(f.doc.tables.layers[f.c], isNull);
    });

    test('refuses a layer a root entity uses', () {
      final f = _Fixture();
      f.addLine(owner: f.doc.rootHandle, layer: f.d);
      expect(layerIsEmpty(f.doc, f.d), isFalse);
      _expectRefused(f, RemoveLayerCommand(f.d));
    });

    test('refuses a layer a definition leaf uses (M-LP-10)', () {
      final f = _Fixture();
      f.addLine(owner: f.definition, layer: f.d);
      expect(layerIsEmpty(f.doc, f.d), isFalse);
      _expectRefused(f, RemoveLayerCommand(f.d));
    });

    test('refuses a layer an instance uses', () {
      final f = _Fixture();
      f.addInstance(layer: f.d);
      expect(layerIsEmpty(f.doc, f.d), isFalse);
      _expectRefused(f, RemoveLayerCommand(f.d));
    });

    test('refuses a layer an ObjectLayer on a live node uses (M-LP-10)', () {
      final f = _Fixture();
      f.doc.components.attach(f.group, ObjectLayer(f.d));
      expect(layerIsEmpty(f.doc, f.d), isFalse);
      _expectRefused(f, RemoveLayerCommand(f.d));
    });

    test('an ObjectLayer on a dead handle does not keep a layer (M-LP-10)', () {
      final f = _Fixture();
      final dead = f.doc.handleSeed.next();
      f.doc.components.attach(dead, ObjectLayer(f.d));
      expect(f.doc.tree[dead], isNull);
      expect(layerIsEmpty(f.doc, f.d), isTrue);
      f.doc.commands.execute(RemoveLayerCommand(f.d));
      expect(f.doc.tables.layers[f.d], isNull);
    });

    test(
        'layerIsEmpty: an unused layer is, layer 0 and the effective current '
        'are not', () {
      final f = _Fixture();
      expect(layerIsEmpty(f.doc, f.d), isTrue);
      expect(layerIsEmpty(f.doc, f.a), isFalse);
      expect(layerIsEmpty(f.doc, ReservedHandles.layerZero), isFalse);
      f.doc.header.currentLayer = f.d;
      expect(layerIsEmpty(f.doc, f.d), isFalse);
    });

    test(
        'layer 0 is never empty and never deleted, even when it is not the '
        'current layer (Task 2 review R1, R2)', () {
      final f = _Fixture();
      // A is current, so the current-layer check cannot mask layer 0's own
      // guard; nothing in the fixture is on layer 0.
      f.doc.header.currentLayer = f.a;
      expect(drawingLayer(f.doc), f.a);
      expect(layerIsEmpty(f.doc, ReservedHandles.layerZero), isFalse);
      final before = f.bytes;
      expect(
          () => f.doc.commands
              .execute(RemoveLayerCommand(ReservedHandles.layerZero)),
          throwsA(isA<ArgumentError>().having(
              (e) => e.message, 'message', 'Layer 0 cannot be deleted.')));
      expect(f.bytes, before);
    });
  });

  group('SetLayerCommand', () {
    test(
        'rename, recolour, hide, show, lock and unlock each apply exactly, '
        'undo and redo, with a label naming what changed', () {
      final f = _Fixture();
      final cases = <(LayerRecord, String)>[
        (f.layer(f.a).copyWith(name: 'Walls'), 'Rename layer'),
        (
          f.layer(f.a).copyWith(color: const IndexedColor(4)),
          'Change layer colour'
        ),
        (f.layer(f.a).copyWith(visible: false), 'Hide layer'),
        (f.layer(f.c).copyWith(visible: true), 'Show layer'),
        (f.layer(f.a).copyWith(locked: true), 'Lock layer'),
        (f.layer(f.b).copyWith(locked: false), 'Unlock layer'),
        (f.layer(f.a).copyWith(name: 'Walls', locked: true), 'Edit layer'),
      ];
      for (final (record, label) in cases) {
        final command = SetLayerCommand(record);
        _expectRoundTrip(
            f, command, () => expect(f.layer(record.handle), record));
        expect(command.label, label);
        f.doc.commands.undo();
      }
    });

    test('a case-only rename of self is valid', () {
      final f = _Fixture();
      final renamed = f.layer(f.a).copyWith(name: 'a');
      f.doc.commands.execute(SetLayerCommand(renamed));
      expect(f.layer(f.a), renamed);
    });

    test(
        'a rename to a case-folded duplicate is refused and keeps the record '
        '(M-LP-8)', () {
      final f = _Fixture();
      final old = f.layer(f.a);
      _expectRefused(f, SetLayerCommand(old.copyWith(name: 'b')));
      expect(f.layer(f.a), old, reason: 'the record is not lost');
    });

    test('a rename to an invalid name is refused and keeps the record', () {
      final f = _Fixture();
      final old = f.layer(f.a);
      _expectRefused(f, SetLayerCommand(old.copyWith(name: 'A|B')));
      _expectRefused(f, SetLayerCommand(old.copyWith(name: 'A ')));
      _expectRefused(f, SetLayerCommand(old.copyWith(name: '')));
      expect(f.layer(f.a), old);
    });

    test(
        'a loaded layer whose stored name fails D4 can be hidden, locked and '
        'recoloured; a rename to another invalid name is still refused '
        '(final review finding 1)', () {
      final f = _Fixture();
      final colon = f.record(f.doc.handleSeed.next(), 'Walls:Ext', 4);
      final space = f.record(f.doc.handleSeed.next(), ' Walls', 6);
      // Direct table writes: no user form would let these names in.
      f.doc.tables.layers
        ..add(colon)
        ..add(space);
      final loaded = reload(f.doc);
      String bytes() => DraftDocumentCodec.encodeToString(loaded);
      for (final bad in [colon, space]) {
        final edits = <(LayerRecord, String)>[
          (bad.copyWith(visible: false), 'Hide layer'),
          (bad.copyWith(locked: true), 'Lock layer'),
          (bad.copyWith(color: const IndexedColor(2)), 'Change layer colour'),
        ];
        for (final (record, label) in edits) {
          final before = bytes();
          final depth = loaded.commands.undoDepth;
          final command = SetLayerCommand(record);
          loaded.commands.execute(command);
          expect(loaded.tables.layers[bad.handle], record);
          expect(command.label, label);
          expect(loaded.commands.undoDepth, depth + 1, reason: 'one step');
          loaded.commands.undo();
          expect(loaded.tables.layers[bad.handle], bad);
          expect(bytes(), before, reason: 'the inverse restores exactly');
        }
        final before = bytes();
        final depth = loaded.commands.undoDepth;
        for (final name in ['Walls|Ext', 'Walls ', '']) {
          expect(
              () => loaded.commands
                  .execute(SetLayerCommand(bad.copyWith(name: name))),
              throwsArgumentError);
        }
        expect(bytes(), before, reason: 'a refused rename mutates nothing');
        expect(loaded.commands.undoDepth, depth);
        expect(loaded.tables.layers[bad.handle], bad);
      }
    });

    test('layer 0 cannot be renamed, but can be recoloured', () {
      final f = _Fixture();
      final zero = f.layer(ReservedHandles.layerZero);
      _expectRefused(f, SetLayerCommand(zero.copyWith(name: 'Zero')));
      final recoloured = zero.copyWith(color: const IndexedColor(3));
      f.doc.commands.execute(SetLayerCommand(recoloured));
      expect(f.layer(ReservedHandles.layerZero), recoloured);
    });

    test('the effective current layer cannot be hidden (M-LP-9)', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.a;
      _expectRefused(f, SetLayerCommand(f.layer(f.a).copyWith(visible: false)));
      // Decision 7 is against the effective layer: with the stored current
      // layer hidden, layer 0 is current and cannot be hidden, while B can.
      f.doc.header.currentLayer = f.c;
      _expectRefused(
          f,
          SetLayerCommand(f.layer(ReservedHandles.layerZero).copyWith(
                visible: false,
              )));
      final hiddenB = f.layer(f.b).copyWith(visible: false);
      f.doc.commands.execute(SetLayerCommand(hiddenB));
      expect(f.layer(f.b), hiddenB);
    });

    test(
        'a hidden layer 0 as the effective current layer can be recoloured '
        'and locked (decision 7 is a transition, R-12b-4)', () {
      final f = _Fixture();
      // The S-6 file state: the stored current layer C is hidden, so layer 0
      // is the effective current layer, and layer 0 itself is hidden by a
      // direct table write.
      f.doc.header.currentLayer = f.c;
      final layers = f.doc.tables.layers;
      final hiddenZero =
          layers[ReservedHandles.layerZero]!.copyWith(visible: false);
      layers
        ..remove(ReservedHandles.layerZero)
        ..add(hiddenZero);
      expect(drawingLayer(f.doc), ReservedHandles.layerZero);
      final recoloured = hiddenZero.copyWith(color: const IndexedColor(3));
      f.doc.commands.execute(SetLayerCommand(recoloured));
      expect(f.layer(ReservedHandles.layerZero), recoloured);
      final locked = recoloured.copyWith(locked: true);
      f.doc.commands.execute(SetLayerCommand(locked));
      expect(f.layer(ReservedHandles.layerZero), locked);
    });

    test(
        'the restore form refuses a name another layer took since, and keeps '
        'the record (Task 2 review R4)', () {
      final f = _Fixture();
      final walls = f.layer(f.a).copyWith(name: 'Walls');
      f.doc.commands.execute(SetLayerCommand(walls));
      // A direct table write, between execute and undo, takes the old name.
      f.doc.tables.layers.add(f.record(f.doc.handleSeed.next(), 'A', 2));
      final before = f.bytes;
      expect(() => f.doc.commands.undo(), throwsStateError);
      expect(f.bytes, before, reason: 'the failed undo mutates nothing');
      expect(f.layer(f.a), walls, reason: 'the record is not lost');
      expect(f.doc.commands.canUndo, isTrue);
    });

    test('the effective current layer can be locked', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.a;
      final locked = f.layer(f.a).copyWith(locked: true);
      f.doc.commands.execute(SetLayerCommand(locked));
      expect(f.layer(f.a), locked);
    });

    test('a missing layer is refused', () {
      final f = _Fixture();
      _expectRefused(
          f, SetLayerCommand(f.record(f.doc.handleSeed.next(), 'Ghost', 2)));
    });
  });

  group('SetCurrentLayerCommand', () {
    test('writes the stored current layer, undo and redo', () {
      final f = _Fixture();
      final command = SetCurrentLayerCommand(f.a);
      expect(command.label, 'Set current layer');
      _expectRoundTrip(f, command, () {
        expect(f.doc.header.currentLayer, f.a);
        expect(drawingLayer(f.doc), f.a);
      });
    });

    test('a locked layer may be current; a hidden or missing one may not', () {
      final f = _Fixture();
      f.doc.commands.execute(SetCurrentLayerCommand(f.b));
      expect(f.doc.header.currentLayer, f.b);
      _expectRefused(f, SetCurrentLayerCommand(f.c));
      _expectRefused(f, SetCurrentLayerCommand(f.doc.handleSeed.next()));
    });
  });

  group('SetEntityLayerCommand', () {
    test('moves the entity, undo restores the column exactly', () {
      final f = _Fixture();
      final slot = f.doc.entities.slotOf(f.line)!;
      final before = f.doc.entities.read(slot);
      final command = SetEntityLayerCommand(f.line, f.b);
      expect(command.label, 'Move to layer');
      _expectRoundTrip(f, command, () {
        final after = f.doc.entities.read(slot);
        expect(after.layer, f.b);
        expect(after.copyWith(layer: f.a), before,
            reason: 'nothing but the layer moved');
      });
    });

    test('refuses a missing layer; a missing entity is an integrity error', () {
      final f = _Fixture();
      _expectRefused(f, SetEntityLayerCommand(f.line, f.doc.handleSeed.next()));
      final ghost = f.doc.handleSeed.next();
      final before = f.bytes;
      expect(() => f.doc.commands.execute(SetEntityLayerCommand(ghost, f.b)),
          throwsStateError);
      expect(f.bytes, before);
    });
  });

  group('SetInstanceLayerCommand', () {
    test('moves the instance, undo restores the node exactly', () {
      final f = _Fixture();
      final before = f.doc.tree[f.instance]! as InstanceNode;
      final command = SetInstanceLayerCommand(f.instance, f.c);
      expect(command.label, 'Move to layer');
      _expectRoundTrip(f, command, () {
        final after = f.doc.tree[f.instance]! as InstanceNode;
        expect(after.layer, f.c);
        expect(after.copyWith(layer: f.a), before);
      });
    });

    test('refuses a missing layer, and a handle that is not an instance', () {
      final f = _Fixture();
      _expectRefused(
          f, SetInstanceLayerCommand(f.instance, f.doc.handleSeed.next()));
      final before = f.bytes;
      expect(
          () => f.doc.commands.execute(SetInstanceLayerCommand(f.group, f.b)),
          throwsStateError);
      expect(f.bytes, before);
    });
  });

  // Spec Testing (R-2): undo succeeds on states a file can hold, because
  // every inverse is the restore form (M-LP-7).
  group('the restore form', () {
    test('(a) undo of picking a current layer while the stored one dangles',
        () {
      final f = _Fixture();
      final dangling = f.doc.handleSeed.next();
      f.doc.header.currentLayer = dangling;
      final loaded = reload(f.doc);
      final before = DraftDocumentCodec.encodeToString(loaded);
      loaded.commands.execute(SetCurrentLayerCommand(f.a));
      loaded.commands.undo();
      expect(loaded.header.currentLayer, dangling);
      expect(DraftDocumentCodec.encodeToString(loaded), before);
    });

    test('(b) undo of showing a loaded hidden current layer', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.c;
      final loaded = reload(f.doc);
      final before = DraftDocumentCodec.encodeToString(loaded);
      final hidden = loaded.tables.layers[f.c]!;
      loaded.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
      expect(drawingLayer(loaded), f.c, reason: 'showing it makes it current');
      // The undo hides the effective current layer: the user form refuses
      // that, the restore form writes it back.
      loaded.commands.undo();
      expect(loaded.tables.layers[f.c], hidden);
      expect(DraftDocumentCodec.encodeToString(loaded), before);
    });

    test('(c) undo of deleting a loaded layer whose name fails D4', () {
      final f = _Fixture();
      final bad = f.record(f.doc.handleSeed.next(), 'Bad:name ', 2);
      f.doc.tables.layers.add(bad);
      final loaded = reload(f.doc);
      final before = DraftDocumentCodec.encodeToString(loaded);
      loaded.commands.execute(RemoveLayerCommand(bad.handle));
      loaded.commands.undo();
      expect(loaded.tables.layers[bad.handle], bad);
      expect(DraftDocumentCodec.encodeToString(loaded), before);
    });

    test('(d) undo of moving an entity off a missing layer', () {
      final f = _Fixture();
      final missing = f.doc.handleSeed.next();
      final stray = f.addLine(owner: f.doc.rootHandle, layer: missing);
      final loaded = reload(f.doc);
      final before = DraftDocumentCodec.encodeToString(loaded);
      loaded.commands.execute(SetEntityLayerCommand(stray, f.a));
      loaded.commands.undo();
      final slot = loaded.entities.slotOf(stray)!;
      expect(loaded.entities.layerAt(slot), missing);
      expect(DraftDocumentCodec.encodeToString(loaded), before);
    });

    test('undo of moving an instance off a missing layer', () {
      final f = _Fixture();
      final missing = f.doc.handleSeed.next();
      final stray = f.addInstance(layer: missing);
      final loaded = reload(f.doc);
      final before = DraftDocumentCodec.encodeToString(loaded);
      loaded.commands.execute(SetInstanceLayerCommand(stray, f.a));
      loaded.commands.undo();
      expect((loaded.tree[stray]! as InstanceNode).layer, missing);
      expect(DraftDocumentCodec.encodeToString(loaded), before);
    });

    test('undo of adding a layer the stored current layer already names', () {
      // A file can hold a current layer naming a handle no layer has; adding
      // a layer at that handle makes it current, and its undo removes the
      // effective current layer, which only the restore form allows.
      final f = _Fixture();
      final h = f.doc.handleSeed.next();
      f.doc.header.currentLayer = h;
      final before = f.bytes;
      f.doc.commands.execute(AddLayerCommand(f.record(h, 'Late', 2)));
      expect(drawingLayer(f.doc), h);
      f.doc.commands.undo();
      expect(f.doc.tables.layers[h], isNull);
      expect(f.bytes, before);
    });
  });

  group('permissions and capabilities', () {
    List<DraftCommand> tableCommands(_Fixture f) => [
          AddLayerCommand(f.record(f.doc.handleSeed.next(), 'New', 6)),
          RemoveLayerCommand(f.d),
          SetLayerCommand(f.layer(f.a).copyWith(name: 'Walls')),
          SetCurrentLayerCommand(f.a),
        ];
    List<DraftCommand> moves(_Fixture f) => [
          SetEntityLayerCommand(f.line, f.b),
          SetInstanceLayerCommand(f.instance, f.b),
        ];

    test(
        'the table commands are structure; the moves need components and '
        'report geometry', () {
      final f = _Fixture();
      for (final command in tableCommands(f)) {
        expect(command.capability, Capability.structure);
        expect(command.capabilities, {Capability.structure});
      }
      for (final command in moves(f)) {
        expect(command.capability, Capability.geometry);
        expect(command.capabilities, {Capability.components});
      }
      // With an ObjectLayer move a mixed selection needs one permission, and
      // the compound still reports what moved.
      final compound = CompoundCommand([
        SetComponentCommand<ObjectLayer>(f.group, ObjectLayer(f.b)),
        ...moves(f),
      ], label: 'Move to layer');
      expect(compound.capabilities, {Capability.components});
      expect(compound.capability, Capability.geometry);
    });

    test('runtime refuses the table commands and allows the moves', () {
      final f = _Fixture(permissions: DraftPermissions.runtime);
      for (final command in tableCommands(f)) {
        final before = f.bytes;
        expect(() => f.doc.commands.execute(command),
            throwsA(isA<PermissionDeniedError>()));
        expect(f.bytes, before);
      }
      for (final command in moves(f)) {
        f.doc.commands.execute(command);
      }
      expect(f.doc.entities.layerAt(f.doc.entities.slotOf(f.line)!), f.b);
      expect((f.doc.tree[f.instance]! as InstanceNode).layer, f.b);
    });

    test('readOnly refuses every one', () {
      final f = _Fixture(permissions: DraftPermissions.readOnly);
      for (final command in [...tableCommands(f), ...moves(f)]) {
        final before = f.bytes;
        expect(() => f.doc.commands.execute(command),
            throwsA(isA<PermissionDeniedError>()));
        expect(f.bytes, before);
      }
    });

    test('touched is never empty: the layer, {old, new}, the moved thing', () {
      final f = _Fixture();
      final h = f.doc.handleSeed.next();
      expect(AddLayerCommand(f.record(h, 'New', 6)).apply(f.doc).touched, {h});
      expect(
          SetLayerCommand(f.layer(f.a).copyWith(name: 'Walls'))
              .apply(f.doc)
              .touched,
          {f.a});
      expect(SetCurrentLayerCommand(f.a).apply(f.doc).touched,
          {ReservedHandles.layerZero, f.a});
      expect(RemoveLayerCommand(f.d).apply(f.doc).touched, {f.d});
      expect(SetEntityLayerCommand(f.line, f.b).apply(f.doc).touched, {f.line});
      expect(SetInstanceLayerCommand(f.instance, f.b).apply(f.doc).touched,
          {f.instance});
    });
  });
}
