// Spec 11 D12 through PlanEditor (3a Task 22, spec C1.2, C6): the Dimension
// tool's letter, palette row and Esc, Enter and status line, and its
// notice on the status line. Ported from jet_cad_floor_plan's
// test/dimension_tool_test.dart (TL4 :572, TL5 :1357, TL7 :843): the
// lines that read the plan's public surface; the tool's own state is
// TL4k and TL5k in the kit (ruling DT-R1). DT-notice-locale is new: the
// notice in German words with the page's separator.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanStrings;
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'dimension_plans.dart';

/// The sample's walls, column, separator and openings at [place] on a plan
/// whose page snaps to no grid (the fixture change: today's document had
/// no page).
Built sampleIn(DraftDocument doc, Placement place) {
  setPage(doc, PageComponent(snapToGrid: false));
  return buildPlanIn(doc, [...sampleWalls(), sampleColumn],
      seps: const [sampleSeparator], openings: sampleOpenings, place: place);
}

void main() {
  testWidgets(
      'TL4 Esc with points pending stays in the tool and places nothing, and '
      'Esc again returns to Select; a second click on the first point, or on '
      'the same wall end point 5 µm away, places nothing; Enter with points '
      'pending does nothing', (tester) async {
    for (final place in const [origin, corpusGroups]) {
      final c = planOf((doc) => sampleIn(doc, place));
      final doc = c.document;
      await pumpPlan(tester, c);
      // The Hall's inner corner E1/0/left, (12,250, 8,250); the camera at
      // 0.3 px/mm on it: the aperture is 10 / 0.3 = 33.3 mm.
      final corner = place.at(12250, 8250);
      await centreOn(tester, c, corner, 0.3);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(status(tester), 'Dimension', reason: '$place');
      expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
      final near = place.at(12253, 8254); // 5 mm off
      final free = place.at(12900.25, 8900.5);
      final free2 = place.at(13300.75, 9150.25);
      final depth = doc.commands.undoDepth;

      // Esc with one point, then with two: nothing is placed.
      await clickAt(tester, c, near);
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Dimension', reason: 'still the tool');
      await clickAt(tester, c, near);
      await clickAt(tester, c, free);
      await press(tester, LogicalKeyboardKey.escape);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);

      // A second click on the first point, on the corner and at a free
      // point (TL4k asserts the one pending point).
      await clickAt(tester, c, near);
      await clickAt(tester, c, near);
      await press(tester, LogicalKeyboardKey.escape);
      await clickAt(tester, c, free);
      await clickAt(tester, c, free);

      // Enter with one point pending, then with two: nothing is placed.
      await press(tester, LogicalKeyboardKey.enter);
      await clickAt(tester, c, free2);
      await press(tester, LogicalKeyboardKey.enter);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);
      await press(tester, LogicalKeyboardKey.escape);

      // The same wall end point 5 µm away, at a legal zoom (0.052 px/mm:
      // the aperture is 10 / 0.052 = 192.3 mm), a fixed 500 mm grid whose
      // origin is a node 5e-6 mm east of the outer corner (12,000, 8,000).
      final outer = place.at(12000, 8000);
      final node = outer + Vector2(5e-6, 0);
      final page = PageComponent(
          originX: node.x, originY: node.y, gridStepMm: 500, snapToGrid: true);
      setPage(doc, page);
      await tester.pump();
      await tester.pump();
      const pxPerMm = 0.052;
      expect(kSnapAperturePixels / pxPerMm, closeTo(192.3, 0.05));
      expect(dragGridStepMm(page, pxPerMm), 500);
      await centreOn(tester, c, outer, pxPerMm);
      await clickAt(tester, c, outer + turnedBy(place, -3, -4));
      final raw1 = outer + turnedBy(place, -170, -170);
      expect((raw1 - outer).length, closeTo(240.4, 0.05));
      await clickAt(tester, c, raw1);

      // Esc drops it; Esc again returns to Select.
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Dimension');
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Select');
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth + 1, reason: 'the page alone');
    }
  });

  testWidgets(
      'TL5 the status line reads Dimension — 4.69 over the Hall\'s corners, '
      'and clears after the commit and on a switch to Select', (tester) async {
    for (final place in const [origin, corpusGroups]) {
      final c = planOf((doc) => sampleIn(doc, place)); // 1:50 m
      final doc = c.document;
      await pumpPlan(tester, c);
      // E1/0/left (12,250, 8,250) and P1/0/left (16,940, 8,250); the
      // camera at 0.12 px/mm centred between them (the aperture is 10 /
      // 0.12 = 83.3 mm; the pair spans 4,690 × 0.12 = 563 px, inside the
      // canvas: DT-R3).
      expect(tester.getSize(find.byType(InteractionLayer)).width,
          greaterThan(4690 * 0.12));
      await centreOn(tester, c, place.at(14595, 8250), 0.12);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final layer = tester.getTopLeft(find.byType(InteractionLayer));
      Future<void> hover(Vector2 w) async {
        final s = c.camera.value.worldToScreen(w);
        await mouse.moveTo(layer + Offset(s.x, s.y));
        await tester.pump();
      }

      for (final commit in [true, false]) {
        final why = '${commit ? 'commit' : 'switch'}, $place';
        await clickAt(tester, c, place.at(12253, 8254));
        await clickAt(tester, c, place.at(16937, 8254));
        // A hover in the Hall, 900.25 above the pair (1,400.25 the second
        // time), no Shift: aligned, 16,940 − 12,250 = 4,690 mm, 4.69 in
        // metres.
        final q = place.at(14600.5, commit ? 9150.25 : 9650.25);
        await hover(q);
        expect(noticeText(c), '4.69', reason: why); // DT-R4
        expect(status(tester), 'Dimension — 4.69', reason: why);
        if (commit) {
          await clickAt(tester, c, q);
          expect(dims(doc), hasLength(1), reason: why);
          expect(dimText(doc, dims(doc).single), '4.69', reason: why);
          expect(noticeText(c), isNull, reason: '$why: after the commit');
          expect(status(tester), 'Dimension', reason: why);
          await tester.pump();
          expect(status(tester), 'Dimension', reason: '$why: change heard');
        } else {
          await tester.tap(byKey('tool-plan.select'));
          await tester.pump();
          expect(noticeText(c), isNull, reason: '$why: deactivated');
          expect(status(tester), 'Select', reason: why);
        }
      }
      await mouse.removePointer();
    }
  });

  testWidgets(
      'TL7 I activates the Dimension tool from the canvas and the palette; '
      'typing I into a panel text field switches nothing', (tester) async {
    final c = planOf((doc) {
      buildPlanIn(doc, [...sampleWalls(), sampleColumn],
          seps: const [sampleSeparator], openings: sampleOpenings);
      final (x, y) = sampleSeeds['Hall']!;
      addRoom(doc, Vector2(x, y), 'Hall');
    });
    final doc = c.document;
    await pumpPlan(tester, c);
    expect(status(tester), 'Select');
    await press(tester, LogicalKeyboardKey.keyI);
    expect(status(tester), 'Dimension', reason: 'I on the canvas');
    expect(c.activeTool.value, ArchitectureTools.dimension); // DT-R2
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await tester.tap(byKey('tool-architecture.dimension'));
    await tester.pump();
    expect(status(tester), 'Dimension', reason: 'the palette entry');
    await press(tester, LogicalKeyboardKey.keyV);

    // The Hall's Name field, focused: I types into it.
    final hall = doc.components
        .withComponent<RoomParams>()
        .firstWhere((h) => doc.components.get<RoomParams>(h)!.name == 'Hall');
    await select(tester, c, [hall]);
    final status0 = status(tester);
    expect(status0, startsWith('Select'));
    final name = byKey('property-name');
    await tester.tap(name);
    await tester.pump();
    tester.testTextInput.enterText('');
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyI), isFalse,
        reason: 'I reaches the platform as text');
    tester.testTextInput.enterText('I');
    await tester.pump();
    expect(tester.widget<PlanTextField>(name).controller.text, 'I');
    expect(status(tester), status0, reason: 'I switched no tool');
    expect(c.activeTool.value, isNot(ArchitectureTools.dimension)); // DT-R2
  });

  testWidgets(
      'DT-notice-locale the status line words the notice in the UI '
      'language, the value in the page\'s separator: Bemaßung — 4.69 on a '
      'point page and Bemaßung — 4,69 on a comma page under German (a comma '
      'UI); a switch to English re-words it a frame later (spec C1.2, C3.6, '
      'Q0; M-DT7)', (tester) async {
    expect(PlanStrings.forLocale(const Locale('de')).decimalSeparator, ',',
        reason: 'premise: a comma UI');
    for (final (separator, value) in const [
      (DecimalSeparator.point, '4.69'),
      (DecimalSeparator.comma, '4,69'),
    ]) {
      final why = 'page ${separator.char}';
      final c = planOf((doc) => sampleIn(doc, corpusGroups));
      await pumpPlan(tester, c, locale: const Locale('de'));
      // An untouched plan takes the UI's separator when the locale is
      // first reported (2a P2): the page is set afterwards, by an edit.
      final page =
          PageComponent(snapToGrid: false, decimalSeparator: separator);
      setPage(c.document, page);
      await tester.pump();
      await tester.pump();
      expect(
          c.document.components.get<PageComponent>(c.document.rootHandle), page,
          reason: '$why: premise: the page');
      await centreOn(tester, c, corpusGroups.at(14595, 8250), 0.12);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(status(tester), 'Bemaßung', reason: '$why: premise: German');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final layer = tester.getTopLeft(find.byType(InteractionLayer));
      await clickAt(tester, c, corpusGroups.at(12253, 8254));
      await clickAt(tester, c, corpusGroups.at(16937, 8254));
      final s = c.camera.value.worldToScreen(corpusGroups.at(14600.5, 9150.25));
      await mouse.moveTo(layer + Offset(s.x, s.y));
      await tester.pump();
      expect(status(tester), 'Bemaßung — $value', reason: why);
      // The same notice, the language switched: worded anew once the
      // locale has reached the controller (one frame late, accepted).
      await pumpPlan(tester, c);
      await tester.pump();
      await tester.pump();
      expect(status(tester), 'Dimension — $value', reason: '$why: English');
      await mouse.removePointer();
    }
  });
}
