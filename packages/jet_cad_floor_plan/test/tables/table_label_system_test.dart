// Spec 14a T12: the table system keeps a table's number upright inside the
// edit that turns the table, stacked on the parametric system's expander.
// Tables are placed off the origin, turned and mirrored; the rotation is
// 37 degrees about a point that is neither the origin nor the table.
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/box.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label_system.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_fixture.dart';

/// A plan with the parametric system and the table system installed, in
/// the shell's order, torn down in reverse.
DraftDocument rig({DraftDocument? doc}) {
  final d = doc ?? plan();
  final parametric = installParametric(d);
  final tables = TableLabelSystem(d)..install();
  addTearDown(() {
    tables.dispose();
    parametric.dispose();
  });
  return d;
}

InstanceNode placeTable(DraftDocument doc, Vector2 at,
    {int quarterTurns = 0, bool mirrored = false}) {
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: at, quarterTurns: quarterTurns, mirrored: mirrored));
  return doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
}

/// The grip drag's rotate: `T_about(pivot) · R(theta) · T(-pivot)` after the
/// node's transform, in a `Rotate` compound.
DraftCommand rotate(InstanceNode node, double theta, Vector2 pivot) =>
    CompoundCommand([
      TransformNodeCommand(
          node.handle,
          Transform2.translation(pivot.x, pivot.y)
              .multiply(Transform2.rotation(theta))
              .multiply(Transform2.translation(-pivot.x, -pivot.y))
              .multiply(node.transform)),
    ], label: 'Rotate');

GeometryPayload labelPayload(DraftDocument doc, Handle instance) {
  final label = tablesOf(doc).firstWhere((t) => t.instance == instance).label!;
  return doc.geometry
      .read(doc.entities.geomIndexAt(doc.entities.slotOf(label)!));
}

/// The label's world linear map: the instance's linear part times the
/// text's own, `R(rotation) · diag(widthFactor, 1)`.
Transform2 labelWorldLinear(DraftDocument doc, Handle instance) {
  final t = (doc.tree[instance]! as InstanceNode).transform;
  final s = labelPayload(doc, instance).scalars;
  return Transform2(t.a, t.b, t.c, t.d, 0, 0)
      .multiply(Transform2.rotation(s[1]))
      .multiply(Transform2.scale(s[2], 1));
}

void expectUpright(DraftDocument doc, Handle instance) {
  final w = labelWorldLinear(doc, instance);
  expect([
    w.a,
    w.b,
    w.c,
    w.d
  ], [
    closeTo(1, 1e-12),
    closeTo(0, 1e-12),
    closeTo(0, 1e-12),
    closeTo(1, 1e-12)
  ]);
}

final Vector2 pivot = Vector2(-1750, 3300);

void main() {
  test(
      'LS1 a 37° turn of a mirrored table stamps its number upright in the '
      'same step; undo and redo carry both (M-14a-8, M-14a-10)', () {
    final doc = rig();
    final node = placeTable(doc, Vector2(2400, -1300), mirrored: true);
    final before = labelPayload(doc, node.handle);
    expectUpright(doc, node.handle);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(rotate(node, kDeg37, pivot));

    expect(doc.commands.undoDepth, depth + 1, reason: 'one step, not two');
    expectUpright(doc, node.handle);
    final after = labelPayload(doc, node.handle);
    expect(after.coords, before.coords, reason: 'the anchor stays put');
    expect(after.scalars[0], before.scalars[0]);
    expect(after.scalars[1], isNot(before.scalars[1]));

    doc.commands.undo();
    expect((doc.tree[node.handle]! as InstanceNode).transform, node.transform);
    expect(labelPayload(doc, node.handle), before);
    doc.commands.redo();
    expect(labelPayload(doc, node.handle), after);
    expectUpright(doc, node.handle);
  });

  test(
      'LS2 a translation writes no label: the edit touches the table only '
      'and stays a transform (M-14a-9)', () async {
    final doc = rig();
    final node = placeTable(doc, Vector2(-900, 4100), quarterTurns: 3);
    final label = tablesOf(doc).single.label!;
    final before = labelPayload(doc, node.handle);
    final changes = <DocChange>[];
    final sub = doc.changes.listen(changes.add);
    addTearDown(sub.cancel);

    doc.commands.execute(CompoundCommand([
      TransformNodeCommand(node.handle,
          Transform2.translation(1234.5, -678.25).multiply(node.transform)),
    ], label: 'Move'));
    await pumpEventQueue();

    expect(labelPayload(doc, node.handle), before);
    final applied = changes.whereType<CommandApplied>().single;
    expect(applied.touched, {node.handle});
    expect(applied.touched.contains(label), isFalse);
    expect(applied.capability, Capability.transform);
  });

  test(
      'LS3 stacked on the parametric system: a box still regenerates, a '
      'table still stamps (M-14a-11)', () {
    final doc = rig();
    final box = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: box,
          parent: doc.rootHandle,
          transform: Transform2.translation(5000, 5000),
          children: const [])),
      SetComponentCommand<BoxParams>(box, const BoxParams(1200, 800)),
    ], label: 'Add box'));
    final lines = doc.entities.liveSlots
        .where((s) => doc.entities.ownerAt(s) == box)
        .length;
    expect(lines, 4, reason: 'the parametric system regenerated the box');

    final node = placeTable(doc, Vector2(-2500, -2500), quarterTurns: 1);
    doc.commands.execute(rotate(node, -kDeg37, pivot));
    expectUpright(doc, node.handle);
  });

  test(
      'LS4 dispose in the shell\'s order empties the slot; a slot taken '
      'by someone else is not released, and asserts', () {
    final doc = plan();
    final parametric = installParametric(doc);
    final tables = TableLabelSystem(doc)..install();
    tables.dispose();
    parametric.dispose();
    expect(doc.commands.expander, isNull);

    final again = installParametric(doc);
    final tables2 = TableLabelSystem(doc)..install();
    DraftCommand other(DraftCommand c) => c;
    doc.commands.expander = other;
    expect(tables2.dispose, throwsA(isA<AssertionError>()));
    expect(doc.commands.expander, other,
        reason: 'never releases a slot it does not hold');
    doc.commands.expander = null;
    again.dispose();
  });

  test(
      'LS5 a turn executed under transform-only permissions undoes and '
      'redoes there (M-14a-20)', () {
    final doc = rig();
    final node = placeTable(doc, Vector2(3100, 2700), mirrored: true);
    doc.commands.permissions = DraftPermissions.runtime;
    doc.commands.execute(rotate(node, kDeg37, pivot));
    expectUpright(doc, node.handle);

    expect(doc.commands.undo, returnsNormally);
    expectUpright(doc, node.handle);
    expect(doc.commands.redo, returnsNormally);
    expectUpright(doc, node.handle);
  });

  test('LS6 a plan with no servable symbol is passed through unwrapped', () {
    final doc = rig();
    final seen = <DraftCommand>[];
    final inner = doc.commands.expander!;
    doc.commands.expander = (c) {
      final out = inner(c);
      seen.add(out);
      return out;
    };
    doc.commands.execute(
        placeSymbol(doc, entryOf(planterSymbol), at: Vector2(600, -600)));
    expect(seen.single, isNot(isA<TableLabelEdit>()));
    doc.commands.expander = inner;
  });

  group('the drawn label (render check, F-16)', () {
    /// The residual the painter hands `DrawSink.text` for [doc]'s label,
    /// through [camera] over [size].
    Transform2 textResidual(
        DraftDocument doc, ViewportTransform camera, Size size) {
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      final painter = DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc));
      final sink = RecordingDrawSink();
      painter.paint(sink, camera, size);
      final ops = sink.ops;
      final at = ops.indexWhere((op) => op is TextOp);
      expect(at, greaterThan(0), reason: 'the label was drawn');
      return (ops[at - 1] as BeginResidualOp).residual;
    }

    void expectCameraAligned(Transform2 r, ViewportTransform camera) {
      final c = camera.worldToScreenMatrix;
      final k = r.a / c.a;
      expect(k, greaterThan(0));
      expect(r.b, closeTo(k * c.b, 1e-9 * k.abs()));
      expect(r.c, closeTo(k * c.c, 1e-9 * k.abs()));
      expect(r.d, closeTo(k * c.d, 1e-9 * k.abs()));
    }

    test('LS7 on the screen camera and the page camera', () {
      final doc =
          rig(doc: DraftDocument.empty(measurer: MetricModelMeasurer()));
      registerAppComponents(doc.components);
      final page = PageComponent();
      final sheet = sheetWorldRect(page);
      final centre = Vector2((sheet.minX + sheet.maxX) / 2 + 300,
          (sheet.minY + sheet.maxY) / 2 - 200);
      final node = placeTable(doc, centre, mirrored: true);
      doc.commands.execute(rotate(node, kDeg37, centre + Vector2(450, 0)));

      const size = Size(800, 600);
      final screen = ViewportTransform.fit(doc.extents, size);
      expectCameraAligned(textResidual(doc, screen, size), screen);

      final paper = pageCamera(page, 72 / 25.4);
      expectCameraAligned(
          textResidual(doc, paper.camera, paper.size), paper.camera);
    });
  });
}
