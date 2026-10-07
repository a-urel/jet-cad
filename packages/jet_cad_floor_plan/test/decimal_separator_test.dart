// Spec Q0 (the plan's decimal separator) T2-T4: a page's separator reaches
// the stored texts and their echoes.
//
// - M-Q0-a (`Q0-S1`): switching the page to `comma` rewrites the room's
//   area TEXT and the dimension's value TEXT in one history entry (the two
//   `pageKey`s, F-3); Undo restores the encoding byte for byte, Redo the
//   commas.
// - M-Q0-h (`Q0-E1`, `Q0-E2`): through the shell, under an English UI, the
//   Area and Value rows follow a switch made while their object stays
//   selected, and the Dimension tool's notice on the status line prints
//   the page's separator.
//
// The fixture follows the spec's fixture rule: a page at cm and 1:20, its
// origin off zero; a room off the origin, turned, whose area has a nonzero
// fraction (12.37 m²); a dimension off the origin in a turned group of its
// own, whose length has a nonzero fraction (345.7 cm); `comma` against
// `point`; a UI (English, `.`) that differs from the `comma` page.
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension_tool.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

/// A box of four 200 mm centred walls, centrelines (0, 0)-(4,050, 3,413):
/// inner faces x 100..3,950, y 100..3,313, 3,850 × 3,213 = 12,370,050 mm²,
/// 12.37005 m² (0.00495 from the tie 12.375).
const List<W> q0Walls = [
  W(0, 0, 4050, 0, 200),
  W(4050, 0, 4050, 3413, 200),
  W(4050, 3413, 0, 3413, 200),
  W(0, 3413, 0, 0, 200),
];

/// The fixture's page: cm at 1:20, its origin off zero, grid snap off (so a
/// tool click resolves to its raw point), the separator `point`.
final PageComponent q0Page = PageComponent(
    originX: -4180.5,
    originY: 2645.25,
    scaleDenominator: 20,
    displayUnit: DisplayUnit.centimeters,
    snapToGrid: false);

/// The fixture: [q0Walls] at the corpus far origin turned 23° ([corpus]),
/// [q0Page], a room `Kitchen` seeded at plan (1,500.25, 1,700.75), and an
/// aligned dimension in a root group of its own at plan (600.5, 4,400.25)
/// turned a further 0.4 rad, from local (−120.5, 40.25) to (3,336.8,
/// 40.25): 3,457.3 mm, 3,457 tenths of a cm (0.2 from the half), 345.7.
/// The dimension sits above the box (plan y 4,400 > 3,413 + 100).
({Plan plan, Handle room, Handle dim}) q0Plan(
    {TextMeasurer measurer = const InsertionPointMeasurer()}) {
  final plan = buildPlan(q0Walls, place: corpus, measurer: measurer);
  attachPage(plan.doc, q0Page);
  final room = addRoom(plan.doc, plan.at(1500.25, 1700.75), 'Kitchen');
  final dim = addDimension(
      plan.doc, const FixedEnd(-120.5, 40.25), const FixedEnd(3336.8, 40.25),
      offset: 300.25,
      at: corpus.m
          .multiply(Transform2.translation(600.5, 4400.25))
          .multiply(Transform2.rotation(0.4)));
  return (plan: plan, room: room, dim: dim);
}

/// [doc]'s page with separator [s], one command, as the Page panel's `_set`
/// makes it.
DraftCommand separatorTo(DraftDocument doc, DecimalSeparator s) =>
    SetComponentCommand<PageComponent>(
        doc.rootHandle, pageOf(doc).copyWith(decimalSeparator: s));

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> select(WidgetTester tester, PlannerView view, Handle h) async {
  view.selection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

/// Runs [command] and pumps twice: the `DocChange` arrives a microtask
/// late (10's `RN2` finding), and its rebuild lands in the next frame.
Future<void> run(WidgetTester tester, void Function() command) async {
  command();
  await tester.pump();
  await tester.pump();
}

/// Pumps the shell over [doc] under an English UI (the default locale) at
/// a 1440 x 900 window, and checks the premise that the UI's separator is
/// `.`, so a `comma` page differs from it.
Future<PlannerView> pumpShell(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  expect(
      FloorPlanStrings.of(tester.element(find.byType(PlannerShell)))
          .decimalSeparator,
      '.',
      reason: 'premise: an English UI');
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

/// The fixture as the shell receives it: built through a system of its
/// own, which is disposed, and the history cleared.
({DraftDocument doc, Handle room, Handle dim}) shellPlan() {
  final f = q0Plan(measurer: FlutterTextMeasurer());
  f.plan.system.dispose();
  f.plan.doc.commands.clearHistory();
  return (doc: f.plan.doc, room: f.room, dim: f.dim);
}

void main() {
  test(
      'Q0-S1 a switch to comma rewrites the area and the dimension value in '
      'one undo step; Undo restores the bytes, Redo the commas', () {
    final f = q0Plan();
    final doc = f.plan.doc;
    // Premises: the fixture is what it says, and prints with a point.
    final g = doc.tree.accumulatedTransform(f.dim);
    expect(g.b, isNot(0), reason: 'premise: the dimension group is turned');
    expect(pageOf(doc).decimalSeparator, DecimalSeparator.point);
    expect(labelStrings(doc, f.room), ['Kitchen', '12.37 m²']);
    expect(dimText(doc, f.dim), '345.7');
    expect(driftOf(doc), isEmpty);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    final roomKids = kids(doc, f.room), dimKids = kids(doc, f.dim);

    doc.commands.execute(separatorTo(doc, DecimalSeparator.comma));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one history entry');
    expect(labelStrings(doc, f.room), ['Kitchen', '12,37 m²']);
    expect(dimText(doc, f.dim), '345,7');
    expect(kids(doc, f.room), roomKids, reason: 'rewritten in place');
    expect(kids(doc, f.dim), dimKids, reason: 'rewritten in place');
    expect(driftOf(doc), isEmpty);
    final after = enc(doc);

    doc.commands.undo();
    expect(enc(doc), before, reason: 'Undo restores the bytes');
    expect(labelStrings(doc, f.room), ['Kitchen', '12.37 m²']);
    expect(dimText(doc, f.dim), '345.7');

    doc.commands.redo();
    expect(labelStrings(doc, f.room), ['Kitchen', '12,37 m²']);
    expect(dimText(doc, f.dim), '345,7');
    expect(enc(doc), after, reason: 'Redo gives the comma bytes again');
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'Q0-E1 under an English UI the Area and Value rows follow a switch to '
      'comma made while their object stays selected', (tester) async {
    final f = shellPlan();
    final doc = f.doc;
    final view = await pumpShell(tester, doc);

    // The room stays selected across the switch, and across its undo.
    await select(tester, view, f.room);
    expect(textAt(tester, 'room-area'), '12.37 m²');
    await run(tester,
        () => doc.commands.execute(separatorTo(doc, DecimalSeparator.comma)));
    expect(textAt(tester, 'room-area'), '12,37 m²');
    expect(textAt(tester, 'room-area'), textOf(doc, labelsOf(doc, f.room)[1]));
    await run(tester, doc.commands.undo);
    expect(textAt(tester, 'room-area'), '12.37 m²');

    // The dimension likewise.
    await select(tester, view, f.dim);
    expect(textAt(tester, 'dimension-value'), '345.7');
    await run(tester, doc.commands.redo);
    expect(textAt(tester, 'dimension-value'), '345,7');
    expect(textAt(tester, 'dimension-value'), dimText(doc, f.dim));
    await run(tester, doc.commands.undo);
    expect(textAt(tester, 'dimension-value'), '345.7');
    await run(tester,
        () => doc.commands.execute(separatorTo(doc, DecimalSeparator.comma)));
    expect(textAt(tester, 'dimension-value'), '345,7');
  });

  testWidgets(
      'Q0-E2 under an English UI the Dimension tool\'s notice on the status '
      'line prints the page\'s separator', (tester) async {
    final f = shellPlan();
    final doc = f.doc;
    final view = await pumpShell(tester, doc);
    // Two clicks in empty space below the box, 3,457.3 mm apart along
    // world x, at 0.12 px/mm (the aperture is 10 / 0.12 = 83.3 mm; the pair
    // spans 415 px of the 896 px canvas). A hover 900.25 above their
    // midpoint, no Shift: aligned (and horizontal), 3,457.3 mm, 345.7 cm.
    final p0 = corpus.at(-2000.25, -2500.5);
    final p1 = p0 + Vector2(3457.3, 0);
    final q = (p0 + p1) * 0.5 + Vector2(0, 900.25);
    final size = tester.getSize(find.byType(InteractionLayer));
    final mid = (p0 + p1) * 0.5;
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(
                size.width / 2 - 0.12 * mid.x, size.height / 2 - 0.12 * mid.y)
            .multiply(Transform2.scale(0.12, 0.12)));
    await tester.pump();
    Offset screen(Vector2 w) {
      final s = view.camera.value.worldToScreen(w);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    final tool = view.tools.active as DimensionTool;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    Future<void> hover(Vector2 w) async {
      await mouse.moveTo(screen(w));
      await tester.pump();
    }

    for (final (separator, want) in [
      (DecimalSeparator.point, '345.7'),
      (DecimalSeparator.comma, '345,7'),
    ]) {
      if (pageOf(doc).decimalSeparator != separator) {
        await run(
            tester, () => doc.commands.execute(separatorTo(doc, separator)));
      }
      expect(pageOf(doc).decimalSeparator, separator);
      await tester.tapAt(screen(p0));
      await tester.pump();
      await tester.tapAt(screen(p1));
      await tester.pump();
      expect(tool.points, hasLength(2), reason: '$separator');
      await hover(q);
      expect(tool.hoverKind, isNull, reason: '$separator: premise: free');
      expect(tool.notice.value, want, reason: '$separator');
      expect(status(tester), 'Dimension — $want', reason: '$separator');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    }
    await mouse.removePointer();
  });
}
