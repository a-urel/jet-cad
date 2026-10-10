import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// O-10: an undone node removal puts the node back at its index among its
/// parent's `children`, not at the end.
///
/// Every container here lists its children **out of handle order**. A
/// fixture whose `children` were already ascending could not tell "restore
/// the index" from "insert sorted by handle" (the plan's M5), and draw order
/// is ascending handle value, so nothing drawn would tell them apart either:
/// only the encoding does.
final class Fixture {
  Fixture() {
    final seed = doc.handleSeed;
    // Allocated first, added out of order below.
    for (var i = 0; i < 5; i++) {
      top.add(seed.next());
    }
    for (var i = 0; i < 3; i++) {
      nested.add(seed.next());
    }
    definition = seed.next();
    for (var i = 0; i < 2; i++) {
      inDefinition.add(seed.next());
    }

    doc.commands.execute(AddDefinitionCommand(Definition(
      handle: definition,
      name: 'D',
      basePoint: Vector2(-40, 25),
      children: const [],
    )));
    // The root: [t2, t0, t4, t1, t3]; t2 is the group holding [n2, n0, n1].
    for (final i in [2, 0, 4, 1, 3]) {
      doc.commands.execute(AddNodeCommand(i == 4
          ? InstanceNode(
              handle: top[i],
              parent: doc.rootHandle,
              transform: placed(i),
              definition: definition,
              layer: ReservedHandles.layerZero)
          : group(top[i], doc.rootHandle, placed(i))));
    }
    for (final i in [2, 0, 1]) {
      doc.commands.execute(AddNodeCommand(group(nested[i], top[2], placed(i))));
    }
    for (final i in [1, 0]) {
      doc.commands.execute(
          AddNodeCommand(group(inDefinition[i], definition, placed(i))));
    }
  }

  final DraftDocument doc = DraftDocument.empty();
  final List<Handle> top = [];
  final List<Handle> nested = [];
  late final Handle definition;
  final List<Handle> inDefinition = [];

  static Transform2 placed(int i) =>
      Transform2.translation(310.0 * i - 75, 42.5)
          .multiply(Transform2.rotation(math.pi / 7 * (i + 1)));

  static GroupNode group(Handle h, Handle parent, Transform2 t) =>
      GroupNode(handle: h, parent: parent, transform: t, children: const []);

  String encoded() => DraftDocumentCodec.encodeToString(doc);

  List<Handle> childrenOf(Handle container) => switch (doc.tree[container]) {
        GroupNode(:final children) => children,
        _ => doc.tree.definition(container)!.children,
      };
}

DraftCommand delete(List<Handle> handles) =>
    CompoundCommand([for (final h in handles) RemoveNodeCommand(h)],
        label: 'Delete');

void main() {
  test('the fixture lists every container out of handle order (premise)', () {
    final f = Fixture();
    final root = f.childrenOf(f.doc.rootHandle);
    expect(root, [f.top[2], f.top[0], f.top[4], f.top[1], f.top[3]]);
    expect(f.childrenOf(f.top[2]), [f.nested[2], f.nested[0], f.nested[1]]);
    expect(f.childrenOf(f.definition), [f.inDefinition[1], f.inDefinition[0]]);
    for (final list in [
      root,
      f.childrenOf(f.top[2]),
      f.childrenOf(f.definition),
    ]) {
      final sorted = [...list]..sort((a, b) => a.value.compareTo(b.value));
      expect(list, isNot(sorted));
    }
  });

  test(
      'N1 the root\'s middle child deleted and undone: the encoding byte for '
      'byte; redo deletes it again; undo again restores it again', () {
    final f = Fixture();
    final before = f.encoded();
    // top[4], an instance, sits third of five.
    f.doc.commands.execute(RemoveNodeCommand(f.top[4]));
    final deleted = f.encoded();
    expect(f.doc.tree[f.top[4]], isNull, reason: 'premise');

    f.doc.commands.undo();
    expect(f.childrenOf(f.doc.rootHandle),
        [f.top[2], f.top[0], f.top[4], f.top[1], f.top[3]]);
    expect(f.encoded(), before);
    f.doc.commands.redo();
    expect(f.encoded(), deleted);
    f.doc.commands.undo();
    expect(f.encoded(), before);
  });

  for (final order in [
    [0, 1],
    [1, 0],
  ]) {
    test(
        'N2 two non-adjacent root children deleted in one step (removed '
        'in the order $order) and undone: byte for byte; redo and undo '
        'again', () {
      final f = Fixture();
      final before = f.encoded();
      final depth = f.doc.commands.undoDepth;
      // top[0] sits second and top[1] fourth: non-adjacent.
      f.doc.commands.execute(delete([for (final i in order) f.top[i]]));
      expect(f.doc.commands.undoDepth, depth + 1, reason: 'one step');
      expect(f.childrenOf(f.doc.rootHandle), [f.top[2], f.top[4], f.top[3]]);
      final deleted = f.encoded();

      f.doc.commands.undo();
      expect(f.encoded(), before);
      f.doc.commands.redo();
      expect(f.encoded(), deleted);
      f.doc.commands.undo();
      expect(f.encoded(), before);
    });
  }

  test(
      'N3 a nested group\'s first child, and a node inside a definition, '
      'deleted in one step and undone: byte for byte', () {
    final f = Fixture();
    final before = f.encoded();
    f.doc.commands.execute(delete([f.nested[2], f.inDefinition[1]]));
    expect(f.childrenOf(f.top[2]), [f.nested[0], f.nested[1]]);
    expect(f.childrenOf(f.definition), [f.inDefinition[0]]);
    f.doc.commands.undo();
    expect(f.childrenOf(f.top[2]), [f.nested[2], f.nested[0], f.nested[1]]);
    expect(f.childrenOf(f.definition), [f.inDefinition[1], f.inDefinition[0]]);
    expect(f.encoded(), before);
  });

  test(
      'N3b a group deleted with its children, children first (the select '
      'tool\'s cascade): byte for byte', () {
    final f = Fixture();
    final before = f.encoded();
    f.doc.commands
        .execute(delete([f.nested[0], f.nested[2], f.nested[1], f.top[2]]));
    expect(f.childrenOf(f.doc.rootHandle),
        [f.top[0], f.top[4], f.top[1], f.top[3]]);
    f.doc.commands.undo();
    expect(f.encoded(), before);
  });

  group('N4 AddNodeCommand\'s index', () {
    late Fixture f;
    late Handle h;
    setUp(() {
      f = Fixture();
      h = f.doc.handleSeed.next();
    });

    test('0 inserts first; the length appends; undo removes it', () {
      final before = f.encoded();
      f.doc.commands.execute(AddNodeCommand(
          Fixture.group(h, f.top[2], Fixture.placed(3)),
          index: 0));
      expect(
          f.childrenOf(f.top[2]), [h, f.nested[2], f.nested[0], f.nested[1]]);
      f.doc.commands.undo();
      expect(f.encoded(), before);

      f.doc.commands.execute(AddNodeCommand(
          Fixture.group(h, f.top[2], Fixture.placed(3)),
          index: 3));
      expect(
          f.childrenOf(f.top[2]), [f.nested[2], f.nested[0], f.nested[1], h]);
    });

    test('1 inserts between; the removal\'s inverse carries it', () {
      f.doc.commands.execute(AddNodeCommand(
          Fixture.group(h, f.definition, Fixture.placed(3)),
          index: 1));
      expect(f.childrenOf(f.definition),
          [f.inDefinition[1], h, f.inDefinition[0]]);
      final result = RemoveNodeCommand(h).apply(f.doc);
      expect((result.inverse as AddNodeCommand).index, 1);
    });

    for (final index in [-1, 4]) {
      test('$index is a RangeError, nothing changed, no history', () {
        final before = f.encoded();
        final depth = f.doc.commands.undoDepth;
        expect(
            () => f.doc.commands.execute(AddNodeCommand(
                Fixture.group(h, f.top[2], Fixture.placed(3)),
                index: index)),
            throwsA(isA<RangeError>()));
        expect(f.doc.tree[h], isNull);
        expect(f.encoded(), before);
        expect(f.doc.commands.undoDepth, depth);
      });
    }

    test('an index under a parent that lists no children is an ArgumentError',
        () {
      final before = f.encoded();
      expect(
          () => f.doc.commands.execute(AddNodeCommand(
              Fixture.group(h, Handle.none, Fixture.placed(3)),
              index: 0)),
          throwsA(isA<ArgumentError>()));
      expect(f.doc.tree[h], isNull);
      expect(f.encoded(), before);
    });
  });

  test('N5 without an index AddNodeCommand appends (today\'s meaning)', () {
    final f = Fixture();
    final h = f.doc.handleSeed.next();
    f.doc.commands
        .execute(AddNodeCommand(Fixture.group(h, f.top[2], Fixture.placed(3))));
    expect(f.childrenOf(f.top[2]), [f.nested[2], f.nested[0], f.nested[1], h]);
  });

  test(
      'N7 a raw list naming a leaf and a dangling handle before the node: '
      'the raw index is restored, and the encoding byte for byte', () {
    final f = Fixture();
    final leaf = f.doc.handleSeed.next();
    const dangling = Handle(90001);
    f.doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: leaf,
        owner: f.top[2],
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
        coords: Float64List.fromList([-120, 35, 410, -60]),
        scalars: Float64List(0),
      ),
    ));
    final g = f.doc.tree[f.top[2]]! as GroupNode;
    // What an older file or a DXF BLOCK can hold: a leaf handle and a
    // handle naming nothing, between the nodes.
    final raw = [leaf, f.nested[2], dangling, f.nested[0], f.nested[1]];
    f.doc.tree.replaceNode(g.copyWith(children: raw));
    final before = f.encoded();
    // nested[0] sits at raw index 3 and at index 1 among the nodes only:
    // an index taken from the filtered list would put it back first.
    f.doc.commands.execute(RemoveNodeCommand(f.nested[0]));
    f.doc.commands.undo();
    expect(f.childrenOf(f.top[2]), raw);
    expect(f.encoded(), before);
  });

  test(
      'N6 a parent listing the removed handle twice: undo restores one copy, '
      'at the first index', () {
    final f = Fixture();
    final g = f.doc.tree[f.top[2]]! as GroupNode;
    // A malformed list, as a hand-edited file could carry.
    f.doc.tree.replaceNode(g.copyWith(
        children: [f.nested[2], f.nested[0], f.nested[1], f.nested[0]]));
    f.doc.commands.execute(RemoveNodeCommand(f.nested[0]));
    expect(f.childrenOf(f.top[2]), [f.nested[2], f.nested[1]]);
    f.doc.commands.undo();
    expect(f.childrenOf(f.top[2]), [f.nested[2], f.nested[0], f.nested[1]]);
  });
}
