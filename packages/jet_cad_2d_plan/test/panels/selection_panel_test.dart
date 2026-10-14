// Ported from jet_cad_floor_plan/test/selection_panel_test.dart; assertions unchanged.
//
// The box cases (SE1-SE12, SE14, SE17, SE18, WS7 (Box)) over the box kit's
// box.box (a stand-in for today's floor_planner.box), in the design
// composition with PlanPropertyPanel on the right. The wall cases (WS*) are
// sub-project 3's; SE13, SE15 and SE16 need the Page panel (Task 18).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/l10n/panel_number.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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

/// The box controller in the design composition, the property panel on the
/// right: today's `pumpDraw(tester, boxDoc(FlutterTextMeasurer()))`.
///
/// The page snaps to its grid here (boxDoc's does not): this composition
/// puts the canvas elsewhere than today's shell did, and under the rotated
/// camera a click's world point no longer comes back exactly (BX4's first
/// box drew 120 x 69.99999999999955); the grid gives the clicks today's
/// exact corners, so the boxes are today's 120 x 70 and 90 x 60.
Future<PlanController> pumpBoxPanel(WidgetTester tester) async {
  final c = boxController();
  final doc = c.document;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      doc.components
          .get<PageComponent>(doc.rootHandle)!
          .copyWith(snapToGrid: true)));
  doc.commands.clearHistory();
  await pumpDesign(tester, c, right: PlanPropertyPanel(controller: c));
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

Future<void> enterAndSubmit(
    WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

/// The panel's title, `Box`: a plain Text outside every field's tap region.
Finder get panelTitle => find.descendant(
    of: find.byKey(const Key('property-panel')), matching: find.text('Box'));

void main() {
  testWidgets('SE1 shown for exactly one selected box', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final bs = boxes(c);
    expect(width, findsNothing);
    c.selection.replace([SelectionKey.root(bs.first)]);
    await tester.pump();
    expect(width, findsOneWidget);
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SE2 hidden for none, two, and a non-box', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final bs = boxes(c);
    c.selection.replace([for (final b in bs) SelectionKey.root(b)]);
    await tester.pump();
    expect(width, findsNothing);
    final line = addDrafted(c.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)),
        layer: ReservedHandles.layerZero);
    c.document.commands.execute(line);
    c.selection.replace([SelectionKey.root(line.record.handle)]);
    await tester.pump();
    expect(width, findsNothing);
  });

  testWidgets('SE3 Enter commits one step and regenerates', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final b = boxes(c).first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = c.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.document.components.get<BoxParams>(b)!.width, 150);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(ParametricSystem(c.document, catalogOf([boxKit])).drift(), isEmpty);
  });

  testWidgets('SE4 an invalid value reverts and commits nothing',
      (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final b = boxes(c).first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = c.document.commands.undoDepth;
    for (final bad in ['0', '-3', 'abc']) {
      await tester.enterText(height, bad);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(height).controller!.text, '70');
    }
    expect(c.document.commands.undoDepth, depth);
  });

  testWidgets('SE5 under runtime the fields are read-only', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    c.document.commands.permissions = DraftPermissions.runtime;
    c.selection.replace([SelectionKey.root(boxes(c).first)]);
    await tester.pump();
    expect(tester.widget<TextField>(width).readOnly, isTrue);
  });

  testWidgets(
      'SE6 undo after a panel edit shows the old width '
      '(Review Focus 4)', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final b = boxes(c).first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    c.document.commands.undo();
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SE7 typing B in the width field does not switch tools',
      (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    await press(tester, LogicalKeyboardKey.keyV);
    c.selection.replace([SelectionKey.root(boxes(c).first)]);
    await tester.pump();
    await tester.tap(width);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });

  testWidgets(
      'SE8 a tap outside the width field commits it via focus loss, '
      'with no Enter', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final b = boxes(c).first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = c.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.pump();
    // No TextInputAction.done: the commit must come from the field's own
    // `FocusNode` losing focus, which `onTapOutside` triggers by unfocusing
    // -- not from a tap-outside handler that submits directly. Not a tap on
    // the Height field: `TextField`'s default `groupId` is `EditableText`,
    // so every plain `TextField` shares it, and a tap on another one counts
    // as *inside* the group, never outside -- this would fail to exercise
    // `onTapOutside` at all. The panel's "Box" title is a plain `Text`,
    // genuinely outside every field's tap region (`find.descendant` because
    // the status line has its own "Box" text while the Box tool is armed).
    await tester.tap(panelTitle);
    await tester.pump();
    expect(c.document.components.get<BoxParams>(b)!.width, 150);
    expect(c.document.commands.undoDepth, depth + 1);
  });

  testWidgets(
      'SE9 hovering geometry, or an unrelated edit, does not wipe an '
      'uncommitted value; a later commit still stores it', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final bs = boxes(c);
    final b = bs.first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = c.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.pump();
    // The real hover API (packages/jet_cad_2d_flutter/lib/src/selection.dart):
    // hovering different geometry notifies `SelectionController`'s
    // listeners exactly like a selection change would.
    c.selection.setHover(SelectionKey.root(bs[1]));
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '150');
    // Clears the hover again, in the test, rather than leaving that to
    // `InteractionLayer._release`'s own teardown-time clear: a real
    // (non-idempotent) hover change happening as an unmanaged side effect
    // of the widget tree tearing down is unrelated noise this test does not
    // want to depend on.
    c.selection.setHover(null);
    await tester.pump();
    // An unrelated document edit: drawing a plain line notifies the
    // panel's document-change listener too, and must not touch the field
    // either.
    final line = addDrafted(c.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)),
        layer: ReservedHandles.layerZero);
    c.document.commands.execute(line);
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(c.document.components.get<BoxParams>(b)!.width, 150);
    expect(c.document.commands.undoDepth, depth + 2);
  });

  testWidgets(
      'SE10 moving focus from Width to Height commits Width, with no '
      'Enter', (tester) async {
    final c = await pumpBoxPanel(tester);
    await drawTwoBoxes(tester, c);
    final b = boxes(c).first;
    c.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.pump();
    await tester.tap(height);
    await tester.pump();
    await tester.enterText(height, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final p = c.document.components.get<BoxParams>(b)!;
    expect(p.width, 150);
    expect(p.height, 90);
  });

  testWidgets(
      'WS7 (Box) the commit target is pinned at focus gain: a selection '
      'change while a field has focus does not redirect its commit (M-07p)',
      (tester) async {
    final box = await pumpBoxes(tester);
    final bs = boxes(box);
    final b0 = box.document.components.get<BoxParams>(bs[0])!;
    final b1 = box.document.components.get<BoxParams>(bs[1])!;
    await select(tester, box, [bs[0]]);
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.pump();
    await select(tester, box, [bs[1]]);
    expect(textOf(tester, width), '150');
    await tester.tap(panelTitle);
    await tester.pump();
    List<double> sizeOf(Handle h) {
      final p = box.document.components.get<BoxParams>(h)!;
      return [p.width, p.height];
    }

    expect(sizeOf(bs[0]), [150, b0.height]);
    expect(sizeOf(bs[1]), [b1.width, b1.height]);
    expect(textOf(tester, width), '90');
  });

  test(
      'SE18 every finite value shows as text that parses back to exactly '
      'it, sign of zero included; whole numbers below 2^53 without ".0" '
      '(post-11 _number)', () {
    const two53 = 9007199254740992.0;
    final values = [
      0.0, -0.0, 1.0, 200.0, -40.0, 262.5, 0.1, 1e-12, 5e-324, //
      two53 - 1, two53, two53 + 2, 9223372036854775807.0, 1e20, 1e300,
      -1e300, double.maxFinite,
      // In [2^63, 2^64) in magnitude: an integer text there saturates, on
      // the VM, to 2^63 - 1 or -2^63, which parse back to +-2^63 (Q4
      // review m1).
      1e19, -1.8e19,
    ];
    for (final v in values) {
      final text = panelNumberText(v);
      final back = double.parse(text);
      expect(back, v, reason: '$v shows "$text"');
      expect(back.isNegative, v.isNegative, reason: '$v shows "$text"');
    }
    expect([
      for (final v in [0.0, 1.0, 200.0, -40.0, two53 - 1]) panelNumberText(v)
    ], [
      '0',
      '1',
      '200',
      '-40',
      '9007199254740991'
    ]);
  });

  testWidgets(
      'SE17 a Box width of 1e20 committed with Enter, then focus loss, is '
      'one undo step storing 1e20: the shown text parses back to it '
      '(post-11 _number)', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    final b = boxes(c).first;
    final height = doc.components.get<BoxParams>(b)!.height;
    await select(tester, c, [b]);
    await tester.tap(width);
    await tester.pump();
    final depth = doc.commands.undoDepth;
    // Enter commits, and hands focus back to the canvas: the focus loss
    // commits the shown text again.
    await enterAndSubmit(tester, width, '1e20');
    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.components.get<BoxParams>(b), BoxParams(1e20, height));
    expect(double.parse(textOf(tester, width)), 1e20);
    // Another focus loss, by a tap outside: still nothing to write.
    await tester.tap(width);
    await tester.pump();
    await tester.tap(panelTitle);
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1);
    expect(doc.components.get<BoxParams>(b)!.width, 1e20);
    doc.commands.undo();
    await tester.pump();
    expect(doc.components.get<BoxParams>(b)!.width, isNot(1e20));
  });

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
  });

  testWidgets(
      'SE14 a canvas click after Width then Height commits both and leaves '
      "the canvas's own focus request alone (fix/post-07 F3)", (tester) async {
    final c = await pumpBoxes(tester);
    final depth = c.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, c);
    // Empty paper, clear of both boxes: the click also clears the
    // selection, which unmounts the fields.
    await tester.tapAt(globalOf(tester, c, 7150, 3250));
    await tester.pump();
    expect(sizeOf(c, b), [150, 90]);
    expect(c.document.commands.undoDepth, depth + 2);
    expect(width, findsNothing);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
  });
}
