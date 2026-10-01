import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// Spec 12b D3's two warnings: `header.current_layer_unusable` and
/// `component.object_layer_missing`.
///
/// Fixture (plan P-6): layers A (ACI 1), B (ACI 5, locked), C (ACI 3,
/// hidden) beside a visible layer 0, and a parametric-object-shaped group
/// under a non-identity transform carrying `ObjectLayer(A)`.
class _Fixture {
  final DraftDocument doc = DraftDocument.empty();
  late final Handle a = _addLayer('A', 1);
  late final Handle b = _addLayer('B', 5, locked: true);
  late final Handle c = _addLayer('C', 3, visible: false);
  late final Handle group;

  _Fixture() {
    a;
    b;
    c;
    group = doc.handleSeed.next();
    doc.tree.addNode(GroupNode(
      handle: group,
      parent: doc.rootHandle,
      transform: Transform2.translation(-250, 640)
          .multiply(Transform2.rotation(math.pi / 3)),
      children: const [],
    ));
    doc.components.attach(group, ObjectLayer(a));
    doc.header.currentLayer = b;
  }

  Handle _addLayer(String name, int aci,
      {bool visible = true, bool locked = false}) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    final handle = doc.handleSeed.next();
    doc.tables.layers.add(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    ));
    return handle;
  }

  List<Diagnostic> withCode(String code) => [
        for (final d in doc.validate())
          if (d.code == code) d
      ];
}

void main() {
  test(
      'a clean document with layers, a locked current layer and an object '
      'on a layer reports nothing', () {
    final f = _Fixture();
    expect(f.doc.validate(), isEmpty);
  });

  group('header.current_layer_unusable', () {
    test('is a warning when the stored current layer names no layer', () {
      final f = _Fixture();
      final dangling = f.doc.handleSeed.next();
      f.doc.header.currentLayer = dangling;
      final found = f.withCode(ValidationCodes.currentLayerUnusable);
      expect(found, hasLength(1));
      expect(found.single.severity, DiagnosticSeverity.warning);
      expect(found.single.handles, [dangling]);
      expect(f.doc.validate(), hasLength(1));
    });

    test('is a warning when the stored current layer is hidden', () {
      final f = _Fixture();
      f.doc.header.currentLayer = f.c;
      final found = f.withCode(ValidationCodes.currentLayerUnusable);
      expect(found, hasLength(1));
      expect(found.single.severity, DiagnosticSeverity.warning);
      expect(found.single.handles, [f.c]);
    });

    test('a removed current layer is reported', () {
      final f = _Fixture();
      f.doc.tables.layers.remove(f.b);
      expect(f.withCode(ValidationCodes.currentLayerUnusable), hasLength(1));
    });
  });

  group('component.object_layer_missing', () {
    test('is a warning for an ObjectLayer on a live node naming no layer', () {
      final f = _Fixture();
      final missing = f.doc.handleSeed.next();
      f.doc.components.attach(f.group, ObjectLayer(missing));
      final found = f.withCode(ValidationCodes.objectLayerMissing);
      expect(found, hasLength(1));
      expect(found.single.severity, DiagnosticSeverity.warning);
      expect(found.single.handles, [f.group, missing]);
      expect(f.doc.validate(), hasLength(1));
    });

    test('is a warning for an ObjectLayer on a dead handle too', () {
      final f = _Fixture();
      final dead = f.doc.handleSeed.next();
      f.doc.components.attach(dead, ObjectLayer(f.c));
      expect(f.doc.validate(), isEmpty,
          reason: 'a dead handle naming an existing layer is not reported');
      f.doc.tables.layers.remove(f.c);
      final found = f.withCode(ValidationCodes.objectLayerMissing);
      expect(found, hasLength(1));
      expect(found.single.handles, [dead, f.c]);
    });

    test('an ObjectLayer naming a hidden layer is not reported', () {
      final f = _Fixture();
      f.doc.components.attach(f.group, ObjectLayer(f.c));
      expect(f.doc.validate(), isEmpty);
    });
  });
}
