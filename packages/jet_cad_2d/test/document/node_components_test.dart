// Spec "A removed node takes its components" (revision 3), N-1 to N-7:
// RemoveNodeCommand takes every component of its handle, registered and
// unknown, and its inverse puts them back exactly, the node at its index.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A registered test type with two non-default fields.
final class Mark implements Component {
  static const String id = 'test.mark';
  const Mark(this.count, this.label);
  final int count;
  final String label;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'count': count, 'label': label};
  static Mark fromJson(Map<String, Object?> j) =>
      Mark(j['count']! as int, j['label']! as String);
  @override
  bool operator ==(Object other) =>
      other is Mark && other.count == count && other.label == label;
  @override
  int get hashCode => Object.hash(count, label);
}

/// Registered only in a second document: a type this one does not map.
/// Its id sorts after `jet_cad.object_layer` (spec N-4, M-16).
final class Foreign implements Component {
  static const String id = 'test.foreign';
  const Foreign();
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => const {'f': 1};
  static Foreign fromJson(Map<String, Object?> j) => const Foreign();
  @override
  bool operator ==(Object other) => other is Foreign;
  @override
  int get hashCode => 1;
}

/// Not layer 0, which is what an absent ObjectLayer reads as.
const Handle kLayer = Handle(0x2A1);

/// Unknown payloads, attached `later` first: not in type-id order.
Map<String, Object?> later() => {
      'typeId': 'z.later',
      'nested': {
        'k': [1, 2.5]
      },
      'note': 'kept verbatim',
    };
Map<String, Object?> earlier() => {'typeId': 'a.earlier', 'v': -3};

typedef Scene = ({
  DraftDocument doc,
  Handle parent,
  Handle node,
  Handle sibling,
  Handle last,
});

/// A group [parent] 40 m off the origin, turned, holding [node], [sibling]
/// and [last] in that order (not ascending: [sibling] < [node]). [node]
/// carries Mark, ObjectLayer and two unknown payloads; [sibling] Mark,
/// ObjectLayer and one unknown payload, with other values. History cleared.
Scene scene() {
  final doc = DraftDocument.empty();
  doc.components.register<Mark>(Mark.id, Mark.fromJson);
  final parent = doc.handleSeed.next();
  final sibling = doc.handleSeed.next();
  final node = doc.handleSeed.next();
  final last = doc.handleSeed.next();
  GroupNode group(Handle h, Handle p, Transform2 t) =>
      GroupNode(handle: h, parent: p, transform: t, children: const []);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(group(
        parent,
        doc.rootHandle,
        Transform2.translation(4e4, -2.7e4)
            .multiply(Transform2.rotation(0.6)))),
    AddNodeCommand(group(node, parent,
        Transform2.translation(310, -925).multiply(Transform2.rotation(-1.1)))),
    AddNodeCommand(group(sibling, parent, Transform2.translation(-75, 40))),
    AddNodeCommand(group(last, parent, Transform2.translation(12, 13))),
    SetComponentCommand<Mark>(node, const Mark(7, 'north')),
    SetComponentCommand<ObjectLayer>(node, const ObjectLayer(kLayer)),
    SetComponentCommand<Mark>(sibling, const Mark(3, 'south')),
    SetComponentCommand<ObjectLayer>(sibling, const ObjectLayer(kLayer)),
  ], label: 'Fixture'));
  doc.components
    ..attachUnknown(node, later())
    ..attachUnknown(node, earlier())
    ..attachUnknown(sibling, earlier());
  doc.commands.clearHistory();
  return (doc: doc, parent: parent, node: node, sibling: sibling, last: last);
}

String enc(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

List<Handle> childrenOf(DraftDocument doc, Handle g) =>
    (doc.tree[g]! as GroupNode).children;

/// Snapshots compared field by field: registered `==` in order, unknown
/// payloads by their JSON in order.
void expectSameSnapshot(ComponentSnapshot actual, ComponentSnapshot expected) {
  expect([for (final (id, _) in actual.components) id],
      [for (final (id, _) in expected.components) id]);
  expect([for (final (_, c) in actual.components) c],
      [for (final (_, c) in expected.components) c]);
  expect(jsonEncode(actual.unknown), jsonEncode(expected.unknown));
}

bool namesHandle(DraftDocument doc, Handle h) => doc.components
    .toJson()
    .values
    .any((perType) => (perType! as Map).containsKey('${h.value}'));

const DraftPermissions kNoComponents = DraftPermissions(
    transform: true, components: false, geometry: true, structure: true);

void main() {
  test('N-1 a removal takes every component of its handle, no other', () {
    final s = scene();
    final doc = s.doc;
    final siblingBefore = doc.components.snapshotOf(s.sibling);
    expect(doc.components.unknownOf(s.node), hasLength(2), reason: 'premise');

    doc.commands.execute(RemoveNodeCommand(s.node));

    expect(doc.tree[s.node], isNull);
    expect(doc.components.get<Mark>(s.node), isNull);
    expect(doc.components.get<ObjectLayer>(s.node), isNull);
    expect(doc.components.unknownOf(s.node), isEmpty);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    expect(namesHandle(doc, s.node), isFalse);
    expectSameSnapshot(doc.components.snapshotOf(s.sibling), siblingBefore);
  });

  test(
      'N-2 undo restores the snapshot and the index byte for byte; redo '
      'removes them again', () {
    final s = scene();
    final doc = s.doc;
    final before = enc(doc);
    final snapshot = doc.components.snapshotOf(s.node);
    final order = childrenOf(doc, s.parent);
    expect(order.indexOf(s.node), 0, reason: 'premise: not the append');

    doc.commands.execute(RemoveNodeCommand(s.node));
    final removed = enc(doc);
    doc.commands.undo();
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
    expect(childrenOf(doc, s.parent), order);
    expect(enc(doc), before);
    doc.commands.redo();
    expect(enc(doc), removed);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    doc.commands.undo();
    expect(enc(doc), before);
  });

  test('N-3 capabilities, and a profile without components', () {
    final s = scene();
    final doc = s.doc;
    final remove = RemoveNodeCommand(s.node);
    expect(remove.capabilities, {Capability.structure, Capability.components});
    expect(remove.capability, Capability.structure);
    final bare = AddNodeCommand(GroupNode(
        handle: const Handle(0x9000),
        parent: s.parent,
        transform: Transform2.identity(),
        children: const []));
    expect(bare.capabilities, {Capability.structure});
    final carrying = AddNodeCommand(bare.node,
        components: doc.components.snapshotOf(s.sibling));
    expect(
        carrying.capabilities, {Capability.structure, Capability.components});
    expect(carrying.capability, Capability.structure);

    doc.commands.permissions = kNoComponents;
    final before = enc(doc);
    expect(() => doc.commands.execute(RemoveNodeCommand(s.node)),
        throwsA(isA<PermissionDeniedError>()));
    expect(enc(doc), before);

    // D-2: an add is allowed, its undo (a removal) is not, and stays.
    doc.commands.execute(bare);
    final depth = doc.commands.undoDepth;
    expect(() => doc.commands.undo(), throwsA(isA<PermissionDeniedError>()));
    expect(doc.commands.undoDepth, depth);
    expect(doc.tree[bare.node.handle], isNotNull);
  });

  group('N-4 a refused add leaves everything as it was', () {
    /// A snapshot from a second document: ObjectLayer (mapped here) and
    /// Foreign (not mapped here), plus an unknown payload.
    ComponentSnapshot foreignSnapshot() {
      final other = DraftDocument.empty();
      other.components.register<Foreign>(Foreign.id, Foreign.fromJson);
      final h = other.handleSeed.next();
      other.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: other.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<ObjectLayer>(h, const ObjectLayer(kLayer)),
        SetComponentCommand<Foreign>(h, const Foreign()),
      ], label: 'Other'));
      other.components.attachUnknown(h, later());
      final snap = other.components.snapshotOf(h);
      expect([
        for (final (id, _) in snap.components) id
      ], [
        'jet_cad.object_layer',
        'test.foreign'
      ], reason: 'premise: the mapped type sorts first');
      return snap;
    }

    void expectNothingOn(DraftDocument doc, Handle h) {
      expect(doc.tree[h], isNull);
      expect(doc.components.snapshotOf(h).isEmpty, isTrue);
    }

    test('an unmapped type id, the mapped one sorting first', () {
      final s = scene();
      final doc = s.doc;
      final h = doc.handleSeed.next(); // before `before`: the seed is encoded
      final before = enc(doc);
      final order = childrenOf(doc, s.parent);
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: h,
                  parent: s.parent,
                  transform: Transform2.translation(5, 6),
                  children: const []),
              components: foreignSnapshot())),
          throwsA(isA<StateError>()));
      expectNothingOn(doc, h);
      expect(childrenOf(doc, s.parent), order);
      expect(enc(doc), before);
      expect(doc.commands.undoDepth, 0);
    });

    test(
        'the same under a parent that already lists the handle, the raw '
        'list compared (the encoder filters a dangling entry)', () {
      final s = scene();
      final doc = s.doc;
      final g = doc.handleSeed.next();
      final x = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: g,
          parent: doc.rootHandle,
          transform: Transform2.translation(-3e3, 2e3),
          children: [x])));
      expect(childrenOf(doc, g), [x], reason: 'premise: dangling entry');
      expect(doc.tree[x], isNull, reason: 'premise');
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: x,
                  parent: g,
                  transform: Transform2.identity(),
                  children: const []),
              components: foreignSnapshot())),
          throwsA(isA<StateError>()));
      expect(childrenOf(doc, g), [x], reason: 'M-14: the raw list kept');
      expectNothingOn(doc, x);
    });

    test('a definition cycle, with a mapped snapshot', () {
      final s = scene();
      final doc = s.doc;
      final d = doc.handleSeed.next();
      doc.commands.execute(AddDefinitionCommand(Definition(
          handle: d,
          name: 'D',
          basePoint: Vector2(40, 30),
          children: const [])));
      final i = doc.handleSeed.next();
      expect(
          () => doc.commands.execute(AddNodeCommand(
              InstanceNode(
                  handle: i,
                  parent: d,
                  transform: Transform2.rotation(math.pi / 2),
                  definition: d,
                  layer: ReservedHandles.layerZero),
              components: doc.components.snapshotOf(s.sibling))),
          throwsA(isA<CycleDetectedError>()));
      expectNothingOn(doc, i);
    });

    test('an index out of range, with a mapped snapshot', () {
      final s = scene();
      final doc = s.doc;
      final h = doc.handleSeed.next(); // before `before`: the seed is encoded
      final before = enc(doc);
      expect(
          () => doc.commands.execute(AddNodeCommand(
              GroupNode(
                  handle: h,
                  parent: s.parent,
                  transform: Transform2.identity(),
                  children: const []),
              index: 99,
              components: doc.components.snapshotOf(s.sibling))),
          throwsA(isA<RangeError>()));
      expectNothingOn(doc, h);
      expect(enc(doc), before);
    });
  });

  test(
      'N-5 a compound delete whose second removal fails rolls the first '
      'back with its components', () {
    final s = scene();
    final doc = s.doc;
    final before = enc(doc);
    final snapshot = doc.components.snapshotOf(s.node);
    expect(
        () => doc.commands.execute(CompoundCommand([
              RemoveNodeCommand(s.node),
              RemoveNodeCommand(const Handle(0xDEAD))
            ], label: 'Delete')),
        throwsA(isA<StateError>()));
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
    expect(enc(doc), before);
  });

  test(
      'N-6 re-parent: bare drops the components, carrying keeps them, '
      'unknown order included', () {
    final s = scene();
    final doc = s.doc;
    final snapshot = doc.components.snapshotOf(s.node);
    final moved = GroupNode(
        handle: s.node,
        parent: s.last,
        transform: Transform2.translation(1, 2),
        children: const []);

    doc.commands.execute(CompoundCommand(
        [RemoveNodeCommand(s.node), AddNodeCommand(moved)],
        label: 'Re-parent, bare'));
    expect(doc.tree[s.node]!.parent, s.last);
    expect(doc.components.snapshotOf(s.node).isEmpty, isTrue);
    doc.commands.undo();

    doc.commands.execute(CompoundCommand([
      RemoveNodeCommand(s.node),
      AddNodeCommand(moved, components: doc.components.snapshotOf(s.node)),
    ], label: 'Re-parent'));
    expect(doc.tree[s.node]!.parent, s.last);
    expectSameSnapshot(doc.components.snapshotOf(s.node), snapshot);
  });

  test('N-7 a plan carrying orphans loads and saves byte for byte', () {
    final s = scene();
    final doc = s.doc;
    const dead = Handle(0x7777);
    doc.components.attach<Mark>(dead, const Mark(9, 'orphan'));
    doc.components.attachUnknown(dead, later());
    expect(doc.tree[dead], isNull, reason: 'premise: names nothing');
    final json = enc(doc);
    final loaded = DraftDocumentCodec.decodeString(json,
        registerComponents: (r) => r.register<Mark>(Mark.id, Mark.fromJson));
    expect(loaded.components.get<Mark>(dead), const Mark(9, 'orphan'));
    expect(enc(loaded), json);
  });
}
