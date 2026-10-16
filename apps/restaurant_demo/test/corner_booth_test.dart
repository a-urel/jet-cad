// SC3 (restaurant-kit audit, PORT; old symbol_section_catalog_test): the
// real corner booth, whose base point is off its box's centre x, turned to
// 37 degrees and mirrored through the Symbol section's own controls keeps
// its footprint and its number upright, one undo each. The behaviour needs
// the plan library and the real asset, so it runs here, on the demo's
// controller over both kits; the Symbol section's logic on a test kit's
// corner unit is the plan library's SW6.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/samples/place_tables.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/demo_rig.dart';

/// The world corners of [h]'s box, rounded to 1e-6 and sorted.
List<(double, double)> footprint(DraftDocument doc, Handle h) {
  final node = doc.tree[h]! as InstanceNode;
  final b = boxOfDefinition(doc, node.definition)!;
  double r(double v) => (v * 1e6).roundToDouble() / 1e6;
  return [
    for (final (x, y) in [
      (b.left, b.front),
      (b.right, b.front),
      (b.right, b.back),
      (b.left, b.back),
    ])
      (() {
        final p = node.transform.transformPoint(Vector2(x, y));
        return (r(p.x), r(p.y));
      })(),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SC3 the corner booth turned to 37 then mirrored: its footprint stays, '
      'its number stays upright; one undo each', (tester) async {
    final c = PlanController(kits: [architectureKit, restaurantKit]);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: planLocalizationsDelegates,
      supportedLocales: planSupportedLocales,
      home: Scaffold(
          body: SingleChildScrollView(child: PlanPropertyPanel(controller: c))),
    ));
    await tester.pump();
    final doc = c.document;

    final entry = restaurantSymbolEntries()['restaurant.booth.corner@1']!;
    final box = boxOfEntry(entry)!;
    expect(entry.definition.basePoint.x, isNot((box.left + box.right) / 2),
        reason: 'premise: the base point is off the box\'s centre x');

    // Far from the origin and off the sheet's centre; a number before it, so
    // the booth's is not "1".
    final placer = TablePlacer(doc)
      ..place('restaurant.table.rect.four', 900, 900);
    final booth =
        placer.place('restaurant.booth.corner', 11000, 8300, quarterTurns: 1);
    expect(unitLabels(c).map((l) => l.$2), ['1', '2']);
    expect(unitInstance(c, '2'), booth);
    Transform2 transform() => (doc.tree[booth]! as InstanceNode).transform;

    void expectUpright(String why) {
      final entities = doc.entities;
      final slot = entities.liveSlots.singleWhere((s) =>
          entities.ownerAt(s) == booth && entities.tagAt(s) == kUnitLabelTag);
      final scalars = doc.geometry.read(entities.geomIndexAt(slot)).scalars;
      final want = unitLabelStamp(transform());
      expect(scalars[1], closeTo(want.rotation, 1e-12), reason: why);
      expect(scalars[2], want.widthFactor, reason: why);
    }

    double degrees() =>
        math.atan2(transform().b, transform().a) * 180 / math.pi;

    c.select({'2'});
    await tester.pump();
    expect(byKey('symbol-section'), findsOneWidget);
    expectUpright('placed');
    final depth = doc.commands.undoDepth;
    final placed = footprint(doc, booth);
    expect(degrees(), closeTo(90, 1e-9), reason: 'premise: a quarter turn');

    await tester.pump(kDoubleTapTimeout * 2);
    await tester.tap(byKey('symbol-rotation'));
    await tester.pump();
    await tester.enterText(byKey('symbol-rotation'), '37');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(degrees(), closeTo(37, 1e-9));
    expect(doc.commands.undoDepth, depth + 1);
    expectUpright('turned');
    final turned = footprint(doc, booth);

    await tester.tap(byKey('symbol-mirror'));
    await tester.pump();
    expect(transform().determinant, closeTo(-1, 1e-12), reason: 'mirrored');
    expect(footprint(doc, booth), turned, reason: 'the footprint stays');
    expectUpright('mirrored');
    expect(doc.commands.undoDepth, depth + 2, reason: 'one step each');

    doc.commands.undo();
    expect(footprint(doc, booth), turned);
    expect(transform().determinant, closeTo(1, 1e-12));
    expectUpright('one undo');
    doc.commands.undo();
    expect(footprint(doc, booth), placed);
    expect(degrees(), closeTo(90, 1e-9));
    expectUpright('two undos');
  });
}
