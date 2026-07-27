import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('GroupNode', () {
    final group = GroupNode(
      handle: const Handle(10),
      parent: Handle.none,
      transform: Transform2.translation(5, 5),
      children: const [Handle(11), Handle(12)],
    );

    test('defaults: visible, not a DXF group', () {
      expect(group.visible, isTrue);
      // Only a group that arrived as a DXF GROUP exports as one; groups made
      // in the designer export as anonymous blocks.
      expect(group.exportAsDxfGroup, isFalse);
    });

    test('child order is preserved, because it is draw order', () {
      expect(group.children, [const Handle(11), const Handle(12)]);
    });

    test('copyWith replaces one field and leaves the rest', () {
      final hidden = group.copyWith(visible: false);
      expect(hidden.visible, isFalse);
      expect(hidden.children, group.children);
      expect(hidden.handle, group.handle);
    });

    test('json round-trips through the Node dispatcher', () {
      final decoded = Node.fromJson(group.toJson());
      expect(decoded, isA<GroupNode>());
      expect(decoded, group);
    });

    test('json key order is stable', () {
      expect(group.toJson().keys.toList(), [
        'type',
        'handle',
        'parent',
        'transform',
        'visible',
        'children',
        'exportAsDxfGroup'
      ]);
    });
  });

  group('InstanceNode', () {
    final instance = InstanceNode(
      handle: const Handle(20),
      parent: const Handle(10),
      transform: Transform2.scale(-1, 2),
      definition: const Handle(30),
      layer: ReservedHandles.layerZero,
    );

    test('carries a definition reference and its own layer', () {
      expect(instance.definition, const Handle(30));
      expect(instance.layer, ReservedHandles.layerZero);
    });

    test('supports a mirroring transform', () {
      // Negative scale is explicitly supported; a TRS-only transform could not
      // represent it, which is why Transform2 is a full affine.
      expect(instance.transform.determinant, lessThan(0));
    });

    test('has no attributes field — ATTRIBs are child entities', () {
      // A Map<String,String> could not reconstruct a DXF ATTRIB, which is a
      // full text entity with its own placement, style and flags. This test
      // exists so nobody adds the field back.
      expect(instance.toJson().containsKey('attributes'), isFalse);
    });

    test('json round-trips through the Node dispatcher', () {
      final decoded = Node.fromJson(instance.toJson());
      expect(decoded, isA<InstanceNode>());
      expect(decoded, instance);
    });
  });

  group('Definition', () {
    final definition = Definition(
      handle: const Handle(30),
      name: 'Table-4Seat',
      basePoint: Vector2(0.5, 0.25),
      children: const [Handle(31), Handle(32)],
    );

    test('carries a base point, which insertion alignment depends on', () {
      expect(definition.basePoint, Vector2(0.5, 0.25));
    });

    test('is not a Node — a prototype has no parent and no transform', () {
      expect(definition, isNot(isA<Node>()));
    });

    test('defaults to not being an xref', () {
      expect(definition.isXref, isFalse);
      expect(definition.xrefPath, isEmpty);
    });

    test('an xref records its path so it survives a round-trip unresolved', () {
      final xref = definition.copyWith(isXref: true, xrefPath: 'site.dwg');
      expect(xref.isXref, isTrue);
      expect(Definition.fromJson(xref.toJson()), xref);
    });

    test('json round-trips', () {
      expect(Definition.fromJson(definition.toJson()), definition);
    });
  });
}
