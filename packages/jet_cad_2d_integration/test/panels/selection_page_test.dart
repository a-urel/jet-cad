// Ported from jet_cad_floor_plan/test/selection_panel_test.dart: SE11, SE12,
// SE13, SE15, SE16, through 2a's ports (jet_cad_2d_plan/test/panels/
// selection_panel_test.dart, selection_page_test.dart) with the
// architecture kit's box and the source's Wall lines restored (3a Task 27,
// Appendix A D-20); assertions unchanged.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show BoxParams;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/chrome/text_field.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart';
import '../support/editor_rig.dart' show pagePlanJson;
import '../support/room_plans.dart' show select;

Finder get width => find.byKey(const Key('property-width'));
Finder get height => find.byKey(const Key('property-height'));

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<PlanTextField>(f).controller.text;

/// `c.document.components.withComponent<BoxParams>()`, ascending: today's
/// `boxes(view.document)`.
List<Handle> boxes(PlanController c) =>
    c.document.components.withComponent<BoxParams>().toList();

/// 2a's box fixture (`panel_kits.dart`'s `boxController`): a 1:20 page
/// anchored at (7000, 3000), grid snap off, nothing drawn, as a plan file.
String boxPlanJson() => pagePlanJson(PageComponent(
    scaleDenominator: 20, originX: 7000, originY: 3000, snapToGrid: false));

/// The architecture kit's controller over [boxPlanJson] in the editor, the
/// right column the property panel above the page panel (the layer panel
/// off, as 2a's composition), in a window 1080 high (so the scale field is
/// on screen), under the drawing camera (`canvas_fixture.dart`'s
/// `pumpDraw`: turned 0.35, 2 px/mm, centred on (7150, 3110)).
Future<PlanController> pumpBoxPanel(WidgetTester tester) async {
  final c = architectureController(json: boxPlanJson());
  addTearDown(c.dispose);
  final doc = c.document;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      doc.components
          .get<PageComponent>(doc.rootHandle)!
          .copyWith(snapToGrid: true)));
  doc.commands.clearHistory();
  await pumpEditor(tester, c,
      window: const Size(1440, 1080),
      centre: Vector2(7150, 3110),
      layerPanel: false);
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

/// The panel's title, `Box`: a plain Text outside every field's tap region.
Finder get panelTitle => find.descendant(
    of: find.byKey(const Key('property-panel')), matching: find.text('Box'));

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
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });

  testWidgets(
      'SE11 a tap on the panel after Width then Height commits both and '
      'hands focus back to the canvas, not to Width (fix/post-07 F3, B7)',
      (tester) async {
    final c = await pumpBoxes(tester);
    final depth = c.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, c);
    await tester.tap(panelTitle);
    await tester.pump();
    expect(sizeOf(c, b), [150, 90]);
    expect(c.document.commands.undoDepth, depth + 2);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });

  testWidgets(
      'SE12 Enter in Height after Width commits both and hands focus back to '
      'the canvas, not to Width (fix/post-07 F3)', (tester) async {
    final c = await pumpBoxes(tester);
    final depth = c.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, c);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sizeOf(c, b), [150, 90]);
    expect(c.document.commands.undoDepth, depth + 2);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
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
    final widthNode = tester.widget<PlanTextField>(width).focusNode!;
    final scaleNode = tester.widget<PlanTextField>(pageScale()).focusNode!;
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
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
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
    final widthNode = tester.widget<PlanTextField>(width).focusNode!;
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
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });
}
