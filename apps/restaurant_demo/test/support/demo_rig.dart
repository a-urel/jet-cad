// The demo's one test rig, for every test in this folder (no copies
// elsewhere): the app pumped at a fixed surface, a key finder, and the one
// unit finder -- a unit's instance by its label, read from the document's
// `UNIT` attribs through the engine's tables, not through the library's
// own index, so a test that asks "which instance is table 7" does not lean
// on the code it checks.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// The demo at [size] (1600 x 1000 by default), one frame past its first.
Future<DemoHomeState> pumpDemo(WidgetTester tester,
    {Size size = const Size(1600, 1000), Locale? locale}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(locale: locale));
  await tester.pump();
  await tester.pump();
  return tester.state<DemoHomeState>(find.byType(DemoHome));
}

/// Every live `UNIT` label of [c]'s document: instance to text, in
/// ascending label handle (the order they were placed).
List<(Handle instance, String text)> unitLabels(PlanController c) {
  final entities = c.document.entities;
  final slots = [
    for (final slot in entities.liveSlots)
      if (entities.tagAt(slot) == kUnitLabelTag) slot,
  ]..sort((a, b) =>
      entities.handleAt(a).value.compareTo(entities.handleAt(b).value));
  return [
    for (final slot in slots) (entities.ownerAt(slot), entities.textAt(slot)),
  ];
}

/// The instance of the unit labelled [label] in [c], or null.
Handle? unitInstance(PlanController c, String label) {
  for (final (instance, text) in unitLabels(c)) {
    if (text == label) return instance;
  }
  return null;
}

/// The instance [h]'s definition's name (`key@1`).
String definitionName(PlanController c, Handle h) => c.document.tree
    .definition((c.document.tree[h]! as InstanceNode).definition)!
    .name;
