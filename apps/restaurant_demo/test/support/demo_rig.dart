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
import 'package:restaurant_demo/samples/place_tables.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show GlobalShadLocalizations, ShadSelectState;

/// The tick that lets a non-English shadcn locale arrive: `ShadApp` loads
/// German and Turkish words through a deferred import, which completes on a
/// timer, not on a bare frame. [pumpDemo] first loads both on the real event
/// loop (the deferred libraries then stay loaded for the file).
const Duration kLocaleTick = Duration(milliseconds: 1);

Finder byKey(String k) => find.byKey(Key(k));

/// The demo at [size] (1600 x 1000 by default), one frame past its first.
Future<DemoHomeState> pumpDemo(WidgetTester tester,
    {Size size = const Size(1600, 1000),
    Locale? locale,
    math.Random? random,
    PagePrinter? printer}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    for (final language in const ['de', 'tr']) {
      await GlobalShadLocalizations.delegate.load(Locale(language));
    }
  });
  await tester.pumpWidget(
      RestaurantDemo(locale: locale, random: random, printer: printer));
  await tester.pump();
  await tester.pump(kLocaleTick);
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

/// Scrolls the side panel until [key] is in view (it is a lazy list): from
/// the top, so a key above the current offset is found too.
Future<void> reveal(WidgetTester tester, String key) async {
  await tester.drag(byKey('side-panel'), const Offset(0, 100000));
  await tester.pump();
  await tester.scrollUntilVisible(byKey(key), 100,
      scrollable: find
          .descendant(
              of: byKey('side-panel'), matching: find.byType(Scrollable))
          .first);
  await tester.pump();
}

/// [reveal]s [key] in the side panel, taps it and pumps two frames.
Future<void> pressInPanel(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.pump();
}

/// Two frames: the controller's streams and the view's listeners settle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// [settle] for a language switch: the second frame carries
/// [kLocaleTick].
Future<void> settleLocale(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(kLocaleTick);
}

/// Taps the language button [code] and settles past the new words' arrival.
Future<void> switchLanguage(WidgetTester tester, String code) async {
  await tester.tap(byKey('lang-$code'));
  await settleLocale(tester);
}

/// Taps the widget keyed [key] and settles.
Future<void> press(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await settle(tester);
}

/// The text of the `Text` keyed [key].
String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

/// The sorted tables line of the side panel.
String tablesText(WidgetTester tester) => textOf(tester, 'tables');

Duration ms(int n) => Duration(milliseconds: n);

/// A floor point of the Salon, world millimetres: between the top row
/// (1 to 3, from y 1625) and the middle one (4 and 5, up to y 0), left of
/// 6 and 7 (from x 2975): on no table's box, off the origin.
const Offset kFloor = Offset(-3210, 810);

/// A mouse click whose down is stamped [down], the up 40 ms later.
Future<void> click(WidgetTester tester, Offset at, Duration down) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(at, timeStamp: down);
  await g.up(timeStamp: down + ms(40));
  await g.removePointer();
}

/// A mouse drag from [from] by [by], in three moves.
Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(from, timeStamp: ms(5000));
  for (var i = 1; i <= 3; i++) {
    await g.moveTo(from + by * (i / 3), timeStamp: ms(5000 + 20 * i));
  }
  await g.up(timeStamp: ms(5100));
  await g.removePointer();
}

/// A service move of the unit labelled [label] in [c]'s service copy, by a
/// raw command (a gesture would do it too: this one needs no geometry).
void serviceMove(PlanController c, String label,
    {double dx = 400, double dy = -300}) {
  final doc = c.activeDocument;
  final node = doc.tree[unitInstance(c, label)!]! as InstanceNode;
  doc.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

/// Pumps, letting the real clock run, until [done] or about 8 s.
Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 400 && !done(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Places a bar stool into [c]'s design [x] mm right and [y] mm up of the
/// sheet's lower-left corner, its label [label] (an empty one leaves it
/// unnumbered): the sample's placer, then the label set by a raw command.
Handle placeStool(PlanController c, double x, double y,
    {required String label}) {
  final instance = TablePlacer(c.document).place('restaurant.bar.stool', x, y);
  c.document.commands.execute(
      SetEntityTextCommand(labelEntity(c, instance), label, kUnitLabelTag));
  return instance;
}

/// Every unit's data that has any, by label (a missing label reads `—`).
Map<String, Map<String, String>> dataByLabel(PlanController c) => {
      for (final d in c.unitDetails)
        if (d.data.isNotEmpty) d.unit.label ?? '—': d.data,
    };

/// Picks record [id] in the inspector's combo (an empty [id] is the "none"
/// entry, which unlinks), the menu opened and closed.
Future<void> pickRecord(WidgetTester tester, String id) async {
  await tester.tap(byKey('pos-id'));
  await tester.pumpAndSettle();
  final option = byKey(id.isEmpty ? 'pos-id-none' : 'pos-id-$id').last;
  // A long list scrolls to the shown record, and the select's chevron then
  // covers the entries at its edge: scroll the entry into view first.
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option);
  await tester.pumpAndSettle();
}

/// The id the inspector's combo shows: the text of its selected entry's
/// first word, empty for none.
String pickedId(WidgetTester tester) {
  final select = tester.state<ShadSelectState<String>>(byKey('pos-id'));
  return select.controller.value.single;
}
