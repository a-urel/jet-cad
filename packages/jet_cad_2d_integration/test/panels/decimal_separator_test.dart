// Spec Q0 (the plan's decimal separator) T3-T4: a page's separator reaches
// the stored texts' echoes.
//
// - M-Q0-h (`Q0-E1`, `Q0-E2`): through the editor, under an English UI, the
//   Area and Value rows follow a switch made while their object stays
//   selected, and the Dimension tool's notice on the status line prints
//   the page's separator. `Q0-E3` (the Task 2 review's R-1): under a
//   German UI on a `point` page the three echoes keep the page's `.`, so a
//   UI separator substituted into any of them is red (under an English UI
//   such a substitution changes nothing).
//
// The fixture follows the spec's fixture rule: a page at cm and 1:20, its
// origin off zero; a room off the origin, turned, whose area has a nonzero
// fraction (12.37 m²); a dimension off the origin in a turned group of its
// own, whose length has a nonzero fraction (345.7 cm); `comma` against
// `point`; a UI (English, `.`) that differs from the `comma` page.
// Ported from jet_cad_floor_plan/test/decimal_separator_test.dart (Q0-E1,
// Q0-E2, Q0-E3, Q0-E3b; Q0-S1 and Q0-S2 run in the kit) for
// jet_cad_2d_integration (3a Task 27, Appendix A D-32); assertions
// unchanged but rulings IP-R1 (the rows' keys) and IP-R3 (the notice is a
// KitText, worded by the controller; the tool's private premises are not
// ported).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, ViewportTransform;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/plans.dart';
import '../support/q0_plan.dart';

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

Future<void> select(WidgetTester tester, PlanController c, Handle h) async {
  c.activeSelection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

/// Runs [command] and pumps twice: the `DocChange` arrives a microtask
/// late (10's `RN2` finding), and its rebuild lands in the next frame.
Future<void> run(WidgetTester tester, void Function() command) async {
  command();
  await tester.pump();
  await tester.pump();
}

/// Pumps the editor over [c] at a 1440 x 900 window, under an English UI
/// (the default locale) or, with [german], a German one, and checks the
/// premise that the UI's separator is `.` or `,`, so a page with the other
/// one differs from it.
Future<void> pumpShell(WidgetTester tester, PlanController c,
    {bool german = false}) async {
  await pumpPlanEditor(tester, c,
      locale: german ? const Locale('de') : const Locale('en'));
  expect(
      PlanStrings.of(tester.element(find.byType(PlanEditor))).decimalSeparator,
      german ? ',' : '.',
      reason: 'premise: the UI language');
}

/// The fixture as the editor receives it: a plan file, opened with no
/// history (its controller disposed at tear-down).
({PlanController c, DraftDocument doc, Handle room, Handle dim}) shellPlan() {
  final f = q0PlanJson();
  final c = architectureController(json: f.json);
  addTearDown(c.dispose);
  return (c: c, doc: c.document, room: f.room, dim: f.dim);
}

/// The Dimension tool's notice, through the editor under an English UI or
/// [german] one: for each of [cases] (a page separator and the text the
/// notice must read), two clicks and a hover give a 345.7 cm dimension,
/// and the status line reads `[label] — text`.
Future<void> noticeCases(WidgetTester tester,
    {required bool german,
    required String label,
    required List<(DecimalSeparator, String)> cases}) async {
  final f = shellPlan();
  final doc = f.doc;
  final c = f.c;
  await pumpShell(tester, c, german: german);
  // Two clicks in empty space below the box, 3,457.3 mm apart along
  // world x, at 0.12 px/mm (the aperture is 10 / 0.12 = 83.3 mm; the pair
  // spans 415 px of the 896 px canvas). A hover 900.25 above their
  // midpoint, no Shift: aligned (and horizontal), 3,457.3 mm, 345.7 cm.
  final p0 = corpus.at(-2000.25, -2500.5);
  final p1 = p0 + Vector2(3457.3, 0);
  final q = (p0 + p1) * 0.5 + Vector2(0, 900.25);
  final size = tester.getSize(find.byType(InteractionLayer));
  final mid = (p0 + p1) * 0.5;
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - 0.12 * mid.x, size.height / 2 - 0.12 * mid.y)
          .multiply(Transform2.scale(0.12, 0.12)));
  await tester.pump();
  Offset screen(Vector2 w) {
    final s = c.camera.value.worldToScreen(w);
    return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
  }

  await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
  await tester.pump();
  // Not ported (ruling IP-R3): final tool = view.tools.active as
  // DimensionTool; (the tool is the kit's, internal).
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  Future<void> hover(Vector2 w) async {
    await mouse.moveTo(screen(w));
    await tester.pump();
  }

  for (final (separator, want) in cases) {
    if (pageOf(doc).decimalSeparator != separator) {
      await run(
          tester, () => doc.commands.execute(separatorTo(doc, separator)));
    }
    expect(pageOf(doc).decimalSeparator, separator);
    await tester.tapAt(screen(p0));
    await tester.pump();
    await tester.tapAt(screen(p1));
    await tester.pump();
    // Not ported (ruling IP-R3): expect(tool.points, hasLength(2), reason:
    // '$separator'); the status line below holds only with two points.
    await hover(q);
    // Not ported (ruling IP-R3): expect(tool.hoverKind, isNull, reason:
    // '$separator: premise: free'); an attached end gives another length.
    expect(c.textOf(c.toolNotice.value!), want, reason: '$separator');
    expect(status(tester), '$label — $want', reason: '$separator');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
  }
  await mouse.removePointer();
}

void main() {
  testWidgets(
      'Q0-E1 under an English UI the Area and Value rows follow a switch to '
      'comma made while their object stays selected', (tester) async {
    final f = shellPlan();
    final doc = f.doc;
    await pumpShell(tester, f.c);

    // The room stays selected across the switch, and across its undo.
    await select(tester, f.c, f.room);
    expect(textAt(tester, 'property-area'), '12.37 m²');
    await run(tester,
        () => doc.commands.execute(separatorTo(doc, DecimalSeparator.comma)));
    expect(textAt(tester, 'property-area'), '12,37 m²');
    expect(
        textAt(tester, 'property-area'), textOf(doc, labelsOf(doc, f.room)[1]));
    await run(tester, doc.commands.undo);
    expect(textAt(tester, 'property-area'), '12.37 m²');

    // The dimension likewise.
    await select(tester, f.c, f.dim);
    expect(textAt(tester, 'property-value'), '345.7');
    await run(tester, doc.commands.redo);
    expect(textAt(tester, 'property-value'), '345,7');
    expect(textAt(tester, 'property-value'), dimText(doc, f.dim));
    await run(tester, doc.commands.undo);
    expect(textAt(tester, 'property-value'), '345.7');
    await run(tester,
        () => doc.commands.execute(separatorTo(doc, DecimalSeparator.comma)));
    expect(textAt(tester, 'property-value'), '345,7');
  });

  testWidgets(
      'Q0-E2 under an English UI the Dimension tool\'s notice on the status '
      'line prints the page\'s separator',
      (tester) =>
          noticeCases(tester, german: false, label: 'Dimension', cases: const [
            (DecimalSeparator.point, '345.7'),
            (DecimalSeparator.comma, '345,7'),
          ]));

  testWidgets(
      'Q0-E3 under a German UI on a point page the Area and Value rows keep '
      'the page\'s point', (tester) async {
    final f = shellPlan();
    final doc = f.doc;
    expect(pageOf(doc).decimalSeparator, DecimalSeparator.point);
    await pumpShell(tester, f.c, german: true);
    await select(tester, f.c, f.room);
    expect(textAt(tester, 'property-area'), '12.37 m²');
    await select(tester, f.c, f.dim);
    expect(textAt(tester, 'property-value'), '345.7');
    // And a switch to comma, made while the dimension stays selected,
    // reaches it under this UI too.
    await run(tester,
        () => doc.commands.execute(separatorTo(doc, DecimalSeparator.comma)));
    expect(textAt(tester, 'property-value'), '345,7');
  });

  testWidgets(
      'Q0-E3b under a German UI the notice prints the page\'s separator, a '
      'point included',
      (tester) =>
          noticeCases(tester, german: true, label: 'Bemaßung', cases: const [
            (DecimalSeparator.point, '345.7'),
            (DecimalSeparator.comma, '345,7'),
          ]));
}
