// Ported from jet_cad_floor_plan/test/selection_panel_test.dart: SE13, SE15
// and SE16, which need the Page panel beside the property panel (Task 17
// sent them here, controller ruling R-m); assertions unchanged. Task 17's
// adaptations apply: the box kit's box.box in place of floor_planner.box,
// the design composition, and its tool letter B ("Box") where the source
// pressed W ("Wall"), a sub-project 3 tool.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/panel_kits.dart';
import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

Finder get width => find.byKey(const Key('property-width'));
Finder get height => find.byKey(const Key('property-height'));

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// `c.document.components.withComponent<BoxParams>()`, ascending: today's
/// `boxes(view.document)`.
List<Handle> boxes(PlanController c) =>
    c.document.components.withComponent<BoxParams>().toList();

/// The box controller in the design composition, the right column the
/// property panel above the page panel (selection_panel_test.dart's
/// `pumpBoxPanel`, with the Page panel), in a window 1080 high.
Future<PlanController> pumpBoxPanel(WidgetTester tester) async {
  final c = boxController();
  final doc = c.document;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      doc.components
          .get<PageComponent>(doc.rootHandle)!
          .copyWith(snapToGrid: true)));
  doc.commands.clearHistory();
  await pumpDesign(tester, c,
      right: Column(children: [
        PlanPropertyPanel(controller: c),
        PlanPagePanel(controller: c),
      ]));
  // A taller window than the drawing fixture's 1440 x 900, where the
  // column (the box's section, the colour row and the layer field above
  // the Page panel) puts the scale field's centre at y 928, below the
  // window's edge: no tap reaches it. The canvas only grows down, so the
  // camera's world points stay where they were.
  await tester.binding.setSurfaceSize(const Size(1440, 1080));
  await tester.pump();
  return c;
}

/// Draws two overlapping boxes: B, then BX4's four clicks, then a pump.
/// Copied from floor_plan/test/support/box_rig.dart:89-96.
Future<void> drawTwoBoxes(WidgetTester tester, PlanController c) async {
  await press(tester, LogicalKeyboardKey.keyB);
  await tester.tapAt(globalOf(tester, c, 7010, 3020));
  await tester.tapAt(globalOf(tester, c, 7130, 3090));
  await tester.tapAt(globalOf(tester, c, 7100, 3060));
  await tester.tapAt(globalOf(tester, c, 7190, 3120));
  await tester.pump();
}

/// A fresh composition with SE's two boxes drawn, selection empty.
Future<PlanController> pumpBoxes(WidgetTester tester) async {
  final c = await pumpBoxPanel(tester);
  await drawTwoBoxes(tester, c);
  await press(tester, LogicalKeyboardKey.keyV);
  return c;
}

void main() {
  Finder pageScale() => find.byKey(const Key('page-scale'));

  /// Selects the first of SE's boxes (120 x 70), types 150 into Width and
  /// then 90 into Height, with no Enter: both fields are now in the scope's
  /// focus history, Width before Height. Returns the box.
  Future<Handle> typeWidthThenHeight(
      WidgetTester tester, PlanController c) async {
    final b = boxes(c).first;
    await select(tester, c, [b]);
    expect([textOf(tester, width), textOf(tester, height)], ['120', '70']);
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.pump();
    await tester.tap(height);
    await tester.pump();
    await tester.enterText(height, '90');
    await tester.pump();
    return b;
  }

  List<double> sizeOf(PlanController c, Handle b) {
    final p = c.document.components.get<BoxParams>(b)!;
    return [p.width, p.height];
  }

  testWidgets(
      "SE13 Enter in the page panel's scale after Width then Height commits "
      'all three and hands focus back to the canvas, past both Selection '
      'panel fields (fix/post-07 F3)', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    final depth = doc.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, c);
    await tester.tap(pageScale());
    await tester.pump();
    await tester.enterText(pageScale(), '75');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sizeOf(c, b), [150, 90]);
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator,
        75);
    expect(doc.commands.undoDepth, depth + 3);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
  });

  testWidgets(
      "SE15 a tap on the page panel's scale after Width, then a mouse click "
      "on the panel's title before a frame: the hand-back walks from the "
      'focused scale, not from Width, and ends on the canvas (fix/post-07 '
      'F2F3b m1)', (tester) async {
    final c = await pumpBoxes(tester);
    final b = boxes(c).first;
    await select(tester, c, [b]);
    await tester.tap(width);
    await tester.pump();
    final widthNode = tester.widget<TextField>(width).focusNode!;
    final scaleNode = tester.widget<TextField>(pageScale()).focusNode!;
    // No frame: Width's tap-outside is still armed from its last build,
    // and the scale's is not armed yet.
    await tester.tap(pageScale());
    expect(FocusManager.instance.primaryFocus, same(scaleNode));
    expect(widthNode.hasFocus, isFalse);
    await tester.tapAt(
        tester.getCenter(find.descendant(
            of: find.byType(PlanPagePanel), matching: find.text('Page'))),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
  });

  testWidgets(
      'SE16 a mouse click on empty paper after Width, then one on the page '
      "panel's title before a frame: the canvas has the focus, so there is "
      'nothing to hand back, and the canvas keeps it (fix/post-07 F2F3c m-a)',
      (tester) async {
    final c = await pumpBoxes(tester);
    final b = boxes(c).first;
    await select(tester, c, [b]);
    await tester.tap(width);
    await tester.pump();
    final widthNode = tester.widget<TextField>(width).focusNode!;
    expect(widthNode.hasFocus, isTrue);
    // Empty paper, clear of both boxes; no frame, so Width's tap-outside is
    // still armed from its last build.
    await tester.tapAt(globalOf(tester, c, 7150, 3250),
        kind: PointerDeviceKind.mouse);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await tester.tapAt(
        tester.getCenter(find.descendant(
            of: find.byType(PlanPagePanel), matching: find.text('Page'))),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
  });
}
