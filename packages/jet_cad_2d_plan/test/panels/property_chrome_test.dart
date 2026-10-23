// The property panel in shadcn (plan 2026-10-23, Task 6): what each kind of
// row is built from, and that the field and choice rules of the panel hold
// on the new parts.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/rows.dart';
import 'package:jet_cad_2d_plan/src/chrome/select.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSelect;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/design_harness.dart';
import '../support/harness.dart' show controllerFor, planText;
import '../support/panel_kits.dart';
import '../support/unit_fixtures.dart';

Finder byKey(String k) => find.byKey(Key(k));

Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

Future<PlanController> boxPanel(WidgetTester tester,
    {BoxParams params = const BoxParams(120, 70, count: 3)}) async {
  final c = boxController();
  final b = addBox(c, Vector2(7010, 3020), params);
  await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
  await select(tester, c, [b]);
  return c;
}

BoxParams boxOf(PlanController c) =>
    c.document.components.withComponent<BoxParams>().map((h) {
      return c.document.components.get<BoxParams>(h)!;
    }).single;

PlanTextField fieldOf(WidgetTester tester, String key) =>
    tester.widget<PlanTextField>(byKey(key));

Future<void> pick(WidgetTester tester, String row, String option) async {
  await tester.ensureVisible(byKey(row));
  await tester.tap(find.descendant(
      of: byKey(row), matching: find.byType(ShadSelect<Object?>)));
  await tester.pumpAndSettle();
  await tester.tap(byKey('$row-$option'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'PP1 a numeric property field is a PlanTextField with today\'s key, '
      'label and suffix', (tester) async {
    await boxPanel(tester);
    final width = fieldOf(tester, 'property-width');
    expect(width.label, 'Width');
    expect(width.suffix, 'mm');
    expect(width.controller.text, '120');
    expect(fieldOf(tester, 'property-turn').suffix, '°');
    expect(fieldOf(tester, 'property-count').suffix, isNull);
    expect(fieldOf(tester, 'property-label').label, isNotEmpty);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'PP2 a field locked by permissions while focused stays focused, '
      'selectable, uneditable; unlocked again it edits', (tester) async {
    final c = await boxPanel(tester);
    await tester.tap(byKey('property-width'));
    await tester.pump();
    final field = fieldOf(tester, 'property-width');
    expect(field.focusNode!.hasFocus, isTrue, reason: 'premise: focused');
    c.permissions = PlanPermissions.full.copyWith(reshape: false);
    await tester.pump();
    expect(fieldOf(tester, 'property-width').readOnly, isTrue);
    expect(field.focusNode!.hasFocus, isTrue, reason: 'still focused');
    await tester.enterText(byKey('property-width'), '150');
    await tester.pump();
    expect(field.controller.text, '120', reason: 'uneditable');
    field.controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pump();
    expect(field.controller.selection.extentOffset, 2, reason: 'selectable');
    expect(field.focusNode!.hasFocus, isTrue);
    c.permissions = PlanPermissions.full;
    await tester.pump();
    expect(fieldOf(tester, 'property-width').readOnly, isFalse);
    await tester.enterText(byKey('property-width'), '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(boxOf(c).width, 150);
  });

  testWidgets(
      'PP3 a choice property whose write is refused shows the model\'s '
      'value after the pick', (tester) async {
    final c = await boxPanel(tester);
    expect(find.text('Matte'), findsWidgets, reason: 'premise');
    // The panel is built enabled; the engine refuses the step.
    c.document.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    final depth = c.document.commands.undoDepth;
    await pick(tester, 'property-finish', 'gloss');
    expect(boxOf(c).finish, BoxFinish.matte, reason: 'premise: refused');
    expect(c.document.commands.undoDepth, depth);
    final shown = tester.widget<PlanSelect<Object?>>(byKey('property-finish'));
    expect(shown.value, BoxFinish.matte);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Matte')),
        findsOneWidget);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Gloss')),
        findsNothing);
  });

  testWidgets('PP4 undo after a choice change shows the old choice',
      (tester) async {
    final c = await boxPanel(tester);
    await pick(tester, 'property-finish', 'gloss');
    expect(boxOf(c).finish, BoxFinish.gloss);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Gloss')),
        findsOneWidget);
    c.document.commands.undo();
    await tester.pump();
    await tester.pump();
    expect(boxOf(c).finish, BoxFinish.matte);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Matte')),
        findsOneWidget);
    expect(
        find.descendant(
            of: byKey('property-finish'), matching: find.text('Gloss')),
        findsNothing);
  });

  testWidgets(
      'PP5 read-only displays (value, text, symbol metadata, capacity) are '
      'PlanReadOnlyField with today\'s labels', (tester) async {
    await boxPanel(tester);
    PlanReadOnlyField around(String key) =>
        tester.widget<PlanReadOnlyField>(find.ancestor(
            of: byKey(key), matching: find.byType(PlanReadOnlyField)));
    expect(around('property-area').label, 'Area');
    expect(tester.widget<Text>(byKey('property-area')).data, '0.0084 m²');

    final json = planText([fxKit()], (d) {
      placeAt(d, planterSymbol, Vector2(-2400.5, 1300.25));
      addUnitLabel(
          d, placeAt(d, tableSymbol(seats: 4), Vector2(2400.75, 1300.5)), '1');
    });
    final c = controllerFor(kits: [fxKit()], json: json);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PlanPropertyPanel(controller: c)))));
    final table = c.unitIndex.withLabel('1').single;
    await select(tester, c, [table.instance]);
    expect(around('unit-capacity').label, 'Seats');
    expect(tester.widget<Text>(byKey('unit-capacity')).data, '4');
    final planter = c.document.tree.nodes
        .whereType<InstanceNode>()
        .where((n) => n.handle != table.instance)
        .single;
    await select(tester, c, [planter.handle]);
    expect(around('symbol-name').label, 'Name');
    expect(around('symbol-size').label, 'Size');
    expect(tester.widget<Text>(byKey('symbol-name')).data, 'Test planter');
  });

  testWidgets('PP6 a boolean property is a PlanSwitchRow', (tester) async {
    final c = await boxPanel(tester);
    final row = tester.widget<PlanSwitchRow>(byKey('property-solid'));
    expect(row.value, isFalse);
    expect(row.onChanged, isNotNull);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.ensureVisible(byKey('property-solid'));
    await tester.tap(byKey('property-solid'));
    await tester.pumpAndSettle();
    expect(boxOf(c).solid, isTrue);
    expect(tester.widget<PlanSwitchRow>(byKey('property-solid')).value, isTrue);
  });

  testWidgets(
      'PP7 at 375 px in the phone drawer a PlanSelect\'s popover lies fully '
      'inside the screen', (tester) async {
    final c = boxController();
    addBox(c, Vector2(7010, 3020), const BoxParams(120, 70));
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PlanEditor(controller: c, gallery: false))));
    await tester.pump();
    await tester.pump();
    final box = c.document.components.withComponent<BoxParams>().single;
    await select(tester, c, [box]);
    await tester.tap(byKey('chrome-right-button'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byKey('property-finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: byKey('property-finish'),
        matching: find.byType(ShadSelect<Object?>)));
    await tester.pumpAndSettle();
    final option = byKey('property-finish-gloss');
    expect(option, findsOneWidget);
    const screen = Rect.fromLTWH(0, 0, 375, 812);
    final rect = tester.getRect(option);
    expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
        isTrue,
        reason: 'the option $rect lies inside $screen');
    final popover = tester.getRect(
        find.ancestor(of: option, matching: find.byType(DecoratedBox)).last);
    expect(popover.left, greaterThanOrEqualTo(0));
    expect(popover.right, lessThanOrEqualTo(375));
    expect(popover.top, greaterThanOrEqualTo(0));
    expect(popover.bottom, lessThanOrEqualTo(812));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}
