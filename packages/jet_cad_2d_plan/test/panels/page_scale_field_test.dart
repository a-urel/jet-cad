// Ported from jet_cad_floor_plan/test/planner_draw_test.dart: the page
// panel's cases (A9, A14, A15, A18, A19, A23-A26), which Task 16 sent here;
// assertions unchanged. Task 16's adaptations of the file apply
// (palette_draw_test.dart): `drawController` and the design composition
// (design_harness.dart: the status line, the palette, the canvas and the
// shortcuts) in place of the shell, the Page panel as its right column;
// the tool letters are the generic ones. A16 and A27 read the bar's
// read-outs: Task 20's.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

/// [c] in the design composition with its Page panel on the right, under
/// the drawing fixture's rotated, zoomed camera: today's
/// `pumpDraw(tester, drawDoc(...).doc)`.
Future<PlanController> pumpScale(WidgetTester tester) async {
  final c = drawController().c;
  await pumpDesign(tester, c, right: PlanPagePanel(controller: c));
  return c;
}

void main() {
  Finder scale() => find.byKey(const Key('page-scale'));

  String scaleText(WidgetTester tester) =>
      tester.widget<PlanTextField>(scale()).controller.text;

  testWidgets(
      'A9 letters and cmd+Z in the page panel\'s scale field neither '
      'switch tools nor undo the document (Review Focus 1)', (tester) async {
    final c = await pumpScale(tester);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7090, 3070));
    await tester.pump();
    expect(c.document.commands.undoDepth, 1);
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyL), isFalse);
    expect(status(tester), 'Rectangle');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(c.document.commands.undoDepth, 1, reason: 'not undone');
  });

  testWidgets(
      'SET-2 settling with the focus in the page scale field hands it back '
      'to the canvas and shows the stored scale', (tester) async {
    final c = await pumpScale(tester);
    final shown = scaleText(tester);
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '77');
    expect(FocusManager.instance.primaryFocus, isNot(same(canvasFocus(tester))),
        reason: 'premise: the focus is in the field');

    c.settlePendingInput();
    await tester.pump();
    // M-SET-2: drop `_scaleFocus.handBack()` from `resyncScale`.
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    expect(scaleText(tester), shown);
    expect(c.document.commands.undoDepth, 0);
  });

  testWidgets(
      'A14 Escape in the page panel\'s scale field keeps a pending '
      'polyline (spec 05 D9: the guard covers the shell\'s Escape)',
      (tester) async {
    final c = await pumpScale(tester);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    final polyline = activeTool(c) as PolylineTool;
    expect(polyline.isPending, isTrue);
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Polyline');
    expect(polyline.isPending, isTrue);
  });

  testWidgets(
      'A15 a click into the page panel\'s field cancels a pending text '
      'byte-identically (spec 05 D9: any other loss of focus)', (tester) async {
    final c = await pumpScale(tester);
    final before = bytes(c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsNothing);
    expect((activeTool(c) as TextTool).pending.value, isNull);
    expect(bytes(c), before);
  });

  testWidgets(
      "A18 Enter in the page panel's scale field commits it and hands focus "
      "back to the canvas: the tool's Escape and the shell's letters work at "
      'once (fix/post-07 F2)', (tester) async {
    final c = await pumpScale(tester);
    final doc = c.document;
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    final polyline = activeTool(c) as PolylineTool;
    expect(polyline.isPending, isTrue);
    final depth = doc.commands.undoDepth;
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '75');
    // Every text the field shows from Enter on: none. The field already
    // shows 75, Enter does not re-sync it, and the page listener finds 75.
    final controller = tester.widget<PlanTextField>(scale()).controller;
    final shown = <String>[];
    void record() => shown.add(controller.text);
    controller.addListener(record);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    controller.removeListener(record);
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator,
        75);
    expect(doc.commands.undoDepth, depth + 1);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    expect(scaleText(tester), '75');
    expect(shown, isEmpty,
        reason: "the field's text never changes from Enter on");
    await press(tester, LogicalKeyboardKey.escape);
    expect(polyline.isPending, isFalse, reason: "Escape reached the tool");
    expect(status(tester), 'Polyline');
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
  });

  testWidgets(
      "A19 a mouse click outside the page panel's scale field, on the "
      "panel's title or on the canvas, hands focus back to the canvas "
      '(fix/post-07 F2)', (tester) async {
    final c = await pumpScale(tester);
    // A mouse: the field's default tap-outside unfocuses only for one here.
    Future<void> clickAt(Offset at) async {
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump();
    }

    await tester.tap(scale());
    await tester.pump();
    await clickAt(tester.getCenter(find.descendant(
        of: find.byType(PlanPagePanel), matching: find.text('Page'))));
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyR);
    expect(status(tester), 'Rectangle');
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');

    // The canvas click requests the focus itself: the hand-back must not
    // take it away again.
    await tester.tap(scale());
    await tester.pump();
    await clickAt(globalOf(tester, c, 7150, 3250));
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
  });

  testWidgets(
      "A23 the page panel's scale field left without Enter shows the page's "
      "scale again: typed 75 on 1:20, then a mouse click on the panel's "
      'title commits nothing (fix/post-07 F2F3b m2)', (tester) async {
    final c = await pumpScale(tester);
    final doc = c.document;
    final depth = doc.commands.undoDepth;
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '75');
    await tester.pump();
    expect(scaleText(tester), '75');
    await tester.tapAt(
        tester.getCenter(find.descendant(
            of: find.byType(PlanPagePanel), matching: find.text('Page'))),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator,
        20);
    expect(doc.commands.undoDepth, depth);
    expect(scaleText(tester), '20',
        reason: 'the field never shows a scale the page does not have');
  });

  testWidgets(
      "A24 the page panel's scale field follows an undo and a redo of a "
      'scale commit: 75 over 1:20, back to 20, on to 75 (fix/post-07 F2F3c '
      'I1)', (tester) async {
    final c = await pumpScale(tester);
    final doc = c.document;
    double model() =>
        doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator;
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '75');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect([model(), scaleText(tester)], [75, '75']);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
        reason: 'the field is not focused: only the page can move it');
    doc.commands.undo();
    await tester.pump();
    expect([model(), scaleText(tester)], [20, '20']);
    doc.commands.redo();
    await tester.pump();
    expect([model(), scaleText(tester)], [75, '75']);
  });

  testWidgets(
      "A25 a window blur while typing in the page panel's scale field keeps "
      'the typed text: on web the engine first closes the text input '
      'connection, which unfocuses the field while the app is still resumed '
      '(fix/post-07 F2F3d)', (tester) async {
    final c = await pumpScale(tester);
    final doc = c.document;
    final depth = doc.commands.undoDepth;
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '75');
    await tester.pump();
    final node = tester.widget<PlanTextField>(scale()).focusNode!;
    expect(node.hasFocus, isTrue);
    // Resumed, as on web until the window's own blur: a lifecycle guard
    // (f5920de's) lets a focus-loss re-sync through here.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // The web engine's `handleBlur` for an `<input>` blur with no element
    // to take the focus; the window's blur comes after it.
    tester.testTextInput.closeConnection();
    await tester.pump();
    expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
    expect(node.hasFocus, isFalse, reason: 'the closed connection unfocused');
    expect(scaleText(tester), '75', reason: 'no tap, so no re-sync');
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator,
        20);
    expect(doc.commands.undoDepth, depth);
  });

  testWidgets(
      "A26 a scale of 1e20 committed by Enter in the page panel, then Enter "
      'again on the unchanged text, is one undo step storing exactly 1e20: '
      'the field shows text that parses back to it (post-11 m3)',
      (tester) async {
    final c = await pumpScale(tester);
    final doc = c.document;
    double model() =>
        doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator;
    final depth = doc.commands.undoDepth;
    await tester.tap(scale());
    await tester.pump();
    await tester.enterText(scale(), '1e20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(model(), 1e20);
    expect(doc.commands.undoDepth, depth + 1);
    final shown = scaleText(tester);
    expect(double.parse(shown), 1e20, reason: 'the field shows "$shown"');
    // Enter again on the text the field shows: nothing to write.
    await tester.tap(scale());
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(model(), 1e20);
    expect(doc.commands.undoDepth, depth + 1);
    expect(scaleText(tester), shown);
  });
}
