// The demo's one test rig, for every test in this folder (no copies
// elsewhere): the app pumped at a fixed surface, a key finder, and the one
// unit finder -- a unit's instance by its label, read from the document's
// `UNIT` attribs through the engine's tables, not through the library's
// own index, so a test that asks "which instance is table 7" does not lean
// on the code it checks.
import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/main.dart';

Finder byKey(String k) => find.byKey(Key(k));

/// The demo at [size] (1600 x 1000 by default), one frame past its first.
Future<DemoHomeState> pumpDemo(WidgetTester tester,
    {Size size = const Size(1600, 1000),
    Locale? locale,
    math.Random? random}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(RestaurantDemo(locale: locale, random: random));
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

/// The handle of [instance]'s `UNIT` label entity in [c]'s design.
Handle labelEntity(PlanController c, Handle instance) {
  final entities = c.document.entities;
  for (final slot in entities.liveSlots) {
    if (entities.tagAt(slot) == kUnitLabelTag &&
        entities.ownerAt(slot) == instance) {
      return entities.handleAt(slot);
    }
  }
  throw StateError('no label on ${instance.toHex()}');
}

/// Renames units in [c]'s design by raw commands, all at once (an old label
/// to its new one): `setUnitLabel` refuses a label another unit holds, and a
/// fixture may pass through one. One undo step.
void relabel(PlanController c, Map<String, String> renames) {
  final commands = <DraftCommand>[
    for (final e in renames.entries)
      SetEntityTextCommand(
          labelEntity(c, unitInstance(c, e.key)!), e.value, kUnitLabelTag),
  ];
  c.document.commands.execute(CompoundCommand(commands, label: 'Relabel'));
}

/// Moves the unit labelled [label] of [c]'s design to a new layer named
/// [name], hidden and/or locked, by raw commands.
void putOnLayer(PlanController c, String label, String name,
    {bool visible = true, bool locked = false}) {
  final doc = c.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final layer = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: layer,
      name: name,
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked)));
  doc.commands.execute(SetInstanceLayerCommand(unitInstance(c, label)!, layer));
}

/// The unit labelled [label]'s placement in [c]'s active plan (the service
/// copy in service), read from the document's tree.
Transform2 placementOf(PlanController c, String label) =>
    (c.activeDocument.tree[unitInstance(c, label)!]! as InstanceNode).transform;

/// The centre of the unit labelled [label] on the screen (global
/// coordinates), through the controller's camera.
Offset unitScreen(PlanController c, String label) {
  final detail = c.unitDetails.singleWhere((d) => d.unit.label == label);
  return c.worldToGlobal(detail.center!)!;
}

/// The four corners of the unit labelled [label]'s box on the screen
/// (global coordinates).
List<Offset> unitCorners(PlanController c, String label) {
  final detail = c.unitDetails.singleWhere((d) => d.unit.label == label);
  return [for (final p in detail.corners) c.worldToGlobal(p)!];
}

/// A right click at [at].
Future<void> rightClick(WidgetTester tester, Offset at) async {
  await tester.tapAt(at,
      buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// The mode toggle's Service, pumped.
Future<void> enterService(WidgetTester tester) async {
  await tester.tap(byKey('mode-service'));
  await tester.pump();
  await tester.pump();
}
