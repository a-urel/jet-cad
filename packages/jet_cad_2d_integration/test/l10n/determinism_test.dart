// ignore_for_file: invalid_use_of_internal_member
// Spec 14d I-3, M-14d-g (revision 2, V-9): a document's bytes never depend
// on the UI language. From a loaded plan, the same edits made through the
// UI in English and in Turkish -- a table placed from the palette, turned
// through the Rotation field by a fractional angle typed with the
// language's separator, renumbered through the Number field, a room and a
// layer named explicitly (review 14d-1 F-4) -- encode to the same bytes.
//
// Spec Q0 M-Q0-f: and the plan's text with them. A room is deleted and
// drawn again with the Room tool, and the Bath diagonal is dragged, so an
// area and a dimension value are generated afresh in each language; both
// print the page's `point`, never the UI's comma.
// Ported from jet_cad_floor_plan/test/l10n/determinism_test.dart (3a Task
// 27, Appendix A D-24); assertions unchanged but the rulings named: IP-R1
// (`room-name` is `property-name`) and IP-R4 (the table is the fixture
// kit's `fx.dining.table.two`, its label field `unit-label`).
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectTool, SelectionKey, SymbolGallery;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart'
    show dimLines, dimText, labelsOf, planWith, textOf;
import '../support/units.dart' show diningTableTwo, fxKit;

/// The sample plan, with a layer `Bar` beside its own, over the
/// architecture kit and the fixture kit's library table (ruling IP-R4).
(String, Handle) samplePlan() {
  late Handle bar;
  final json = planWith((doc) {
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    bar = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: bar,
        name: 'Bar',
        color: const IndexedColor(5),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: true,
        locked: false)));
  }, kits: [
    architectureKit,
    fxKit(library: [diningTableTwo])
  ], first: buildSampleFlat);
  return (json, bar);
}

Future<void> commit(WidgetTester tester, String key, String text) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// [doc]'s rooms, ascending.
List<Handle> roomsOf(DraftDocument doc) =>
    doc.components.withComponent<RoomParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

/// The Kitchen's seed in the sample (spec 10 D23), a point in no band.
final Vector2 kitchenSeed = Vector2(19000, 10000);

/// [json] edited through the UI in [locale]; the design's encoding.
Future<String> editedIn(
    WidgetTester tester, (String, Handle) plan, Locale locale) async {
  final (json, bar) = plan;
  final c = PlanController(kits: [
    architectureKit,
    fxKit(library: [diningTableTwo])
  ], json: json);
  await pumpEditor(tester, c, locale: locale);
  await tester.tap(find.byKey(const Key('tab-symbols')));
  await tester.pump();
  expect(await symbolsReady(tester, c), isTrue,
      reason: 'premise: the libraries loaded');
  await tester.pump();
  // The gallery builds its cells lazily, and the kit's furniture comes
  // first: the fixture kit's table is scrolled into view (a fixture change,
  // ruling IP-R4: today's dining table sat in the first screen of today's
  // library).
  final cell = find.byKey(const Key('symbol-cell-fx.dining.table.two@1'));
  await tester.scrollUntilVisible(cell, 200,
      scrollable: find
          .descendant(
              of: find.byType(SymbolGallery), matching: find.byType(Scrollable))
          .first);
  await tester.ensureVisible(cell);
  await tester.pump();
  await tester.tap(cell);
  await tester.pump();
  final canvas = tester.getRect(find.byType(InteractionLayer));
  await tester.tapAt(canvas.center + const Offset(37, -23));
  await tester.pump();
  await tester.pump();
  final placed = c.document.tree.nodes.whereType<InstanceNode>();
  expect(placed, hasLength(1), reason: 'premise: one table placed');
  c.activeSelection.replace([SelectionKey.root(placed.single.handle)]);
  await tester.pump();
  await commit(
      tester, 'symbol-rotation', locale.languageCode == 'tr' ? '30,5' : '30.5');
  await commit(tester, 'unit-label', '7');
  // A room named explicitly.
  final doc = c.document;
  final room = doc.tree.nodes
      .firstWhere((n) => doc.components.get<RoomParams>(n.handle) != null)
      .handle;
  c.activeSelection.replace([SelectionKey.root(room)]);
  await tester.pump();
  await tester.pump();
  await commit(tester, 'property-name', 'Teras');
  // A layer named explicitly.
  final name = find.byKey(Key('layer-name-${bar.toHex()}'));
  await tester.tap(name);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(name);
  await tester.pump();
  await tester.pump();
  final field = find.byKey(Key('layer-name-field-${bar.toHex()}'));
  await tester.enterText(field, 'Salon');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump(const Duration(seconds: 1));

  // A room drawn (M-Q0-f): the Kitchen selected, deleted with the Delete
  // key, and drawn again in its face with the Room tool, then named
  // explicitly (its numbered name is the language's, L7).
  final kitchen = roomsOf(doc)[3];
  expect(doc.components.get<RoomParams>(kitchen)!.name, 'Kitchen',
      reason: 'premise: the sample\'s fourth room');
  // Escape leaves the palette's place tool for Select.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  // The canvas holds every plan tool in the guard: the tool inside it
  // (`toolFor`, @internal, ruling R-P9) is the Flutter layer's SelectTool.
  expect(c.toolFor(c.activeTool.value), isA<SelectTool>(),
      reason: 'premise: the keys reach the canvas\'s Select tool');
  c.activeSelection.replace([SelectionKey.root(kitchen)]);
  await tester.pump();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.delete);
  await tester.pump();
  await tester.pump();
  expect(doc.components.get<RoomParams>(kitchen), isNull,
      reason: 'premise: deleted');
  await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
  await tester.pump();
  await tester.tapAt(globalAt(tester, c, kitchenSeed + Vector2(0.37, 0.61)));
  await tester.pump();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  final drawn = roomsOf(doc).last;
  expect(drawn.value, greaterThan(kitchen.value), reason: 'premise: drawn');
  expect(textOf(doc, labelsOf(doc, drawn)[1]), '13.97 m²',
      reason: 'premise: its area generated, with the page\'s point');
  c.activeSelection.replace([SelectionKey.root(drawn)]);
  await tester.pump();
  await tester.pump();
  await commit(tester, 'property-name', 'Ofis');

  // A dimension moved (M-Q0-f): the Bath diagonal clicked a quarter of the
  // way along and its body dragged, object snap off, so its fixed end
  // moves and its value is generated afresh.
  await tester.sendKeyEvent(LogicalKeyboardKey.f3);
  await tester.pump();
  final diagonal = (doc.components.withComponent<DimensionParams>().toList()
        ..sort((a, b) => a.value.compareTo(b.value)))
      .last;
  expect(dimText(doc, diagonal), '3.58', reason: 'premise: the diagonal');
  final (d0, d1) = dimLines(doc, diagonal)[0];
  final grab = d0 + (d1 - d0) * 0.25;
  await tester.tapAt(globalAt(tester, c, grab));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(c.activeSelection.keys, [SelectionKey.root(diagonal)],
      reason: 'premise: the click selects the diagonal');
  final from = globalAt(tester, c, grab);
  final to = globalAt(tester, c, grab + Vector2(-612.5, 437.5));
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(from);
  await gesture.moveTo(from + const Offset(12, 7));
  await gesture.moveTo(to);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
  final moved = dimText(doc, diagonal);
  // The drag snaps to the page's grid; the length rounds to 4.68 m.
  expect(moved, '4.68',
      reason: 'dragged, its value anew with the page\'s point, never the '
          'UI\'s comma');

  final out = c.save();
  await tester.pumpWidget(const SizedBox());
  c.dispose();
  return out;
}

void main() {
  testWidgets(
      'DT1 the same UI edits in English and in Turkish encode the same '
      '(I-3, M-14d-g)', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final plan = samplePlan();
    final en = await editedIn(tester, plan, const Locale('en'));
    final tr = await editedIn(tester, plan, const Locale('tr'));
    expect(en, contains('"7"'), reason: 'premise: renumbered');
    expect(en, contains('"Teras"'), reason: 'premise: the room named');
    expect(en, contains('"Salon"'), reason: 'premise: the layer named');
    expect(en, isNot(contains('"Bar"')), reason: 'premise: renamed');
    expect(en, contains('0.86162916'), reason: 'premise: turned 30.5 degrees');
    expect(en, contains('Square dining table, 2 seats'),
        reason: 'premise: the copy keeps the library\'s English name');
    expect(en, contains('"Ofis"'), reason: 'premise: the room drawn');
    expect(en, contains('13.97 m²'), reason: 'premise: its area');
    expect(en, contains('"4.68"'), reason: 'premise: moved');
    expect(en, isNot(contains('"3.58"')), reason: 'premise: moved');
    expect(tr, en);
  });
}
