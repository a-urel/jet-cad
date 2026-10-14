// Ported from jet_cad_floor_plan/test/tables/table_section_test.dart (TS9,
// TS10); assertions unchanged.
// Spec 2b S4: the unit section's quarter turn about the base point, and the
// label following its unit to a hidden layer (T8). Units are placed off the
// origin, turned and mirrored.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show CatalogSymbol;
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label_system.dart';
import 'package:jet_cad_2d_plan/src/units/unit_rotate.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/unit_fixtures.dart';

/// A plan with the parametric and label systems, as the session has them.
DraftDocument rig() {
  final doc = plan();
  final parametric = ParametricSystem(doc, ParametricCatalog())..install();
  final labels = UnitLabelSystem(doc)..install();
  addTearDown(() {
    labels.dispose();
    parametric.dispose();
  });
  return doc;
}

Handle placeOne(DraftDocument doc, CatalogSymbol s, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(s),
      at: at,
      quarterTurns: quarterTurns,
      mirrored: mirrored,
      units: unitIndexOf(doc)));
  return doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b)
      .handle;
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

void main() {
  test(
      'TS9 a 37°-turned table: the base point stays, the linear part turns '
      'exactly, four turns return within rounding', () {
    final doc = rig();
    final a = placeOne(doc, tableSymbol(), Vector2(-2300.5, 1700.25));
    final node0 = doc.tree[a]! as InstanceNode;
    doc.commands.execute(TransformNodeCommand(
        a, placementAt(-2300.5, 1700.25, kDeg37, mirrored: true)));
    final start = (doc.tree[a]! as InstanceNode).transform;
    expect(parts(start), isNot(parts(node0.transform)));
    for (var k = 0; k < 4; k++) {
      doc.commands.execute(rotateUnitCommand(doc, a, 1)!);
      final t = (doc.tree[a]! as InstanceNode).transform;
      final w = t.transformPoint(Vector2(900, 700));
      expect(w.x, closeTo(-2300.5, 1e-9));
      expect(w.y, closeTo(1700.25, 1e-9));
    }
    final end = (doc.tree[a]! as InstanceNode).transform;
    expect([end.a, end.b, end.c, end.d], [start.a, start.b, start.c, start.d]);
    expect(end.e, closeTo(start.e, 1e-9));
    expect(end.f, closeTo(start.f, 1e-9));
  });

  test(
      'TS10 a table moved to a hidden layer hides its number; back, it shows '
      '(M-14a-12)', () {
    final doc = rig();
    final layerA = doc.handleSeed.next();
    final layerB = doc.handleSeed.next();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    for (final (h, name, visible) in [
      (layerA, 'A', true),
      (layerB, 'B', false),
    ]) {
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(3),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: visible,
          locked: false)));
    }
    doc.commands.execute(SetCurrentLayerCommand(layerA));
    final a =
        placeOne(doc, tableSymbol(), Vector2(-2300, 1700), mirrored: true);
    final slot = doc.entities.slotOf(unitIndexOf(doc).units.single.label!)!;
    bool drawn() =>
        FilterEvaluator(doc).acceptsEntity(slot, const QueryFilter.rendering());
    expect(drawn(), isTrue);
    doc.commands.execute(SetInstanceLayerCommand(a, layerB));
    expect(drawn(), isFalse);
    doc.commands.execute(SetInstanceLayerCommand(a, layerA));
    expect(drawn(), isTrue);
  });
}
