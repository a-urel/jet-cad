import 'dart:convert';

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/box_rig.dart';
import 'support/wall_fixture.dart';
import 'support/wall_shell.dart';

// Named SE1-SE7, not SP1-SP7 as the task brief has it: `startup_plan_test.dart`
// already uses SP1-SP5 (controller ruling for Task 8).

Finder get width => find.byKey(const Key('box-width'));
Finder get height => find.byKey(const Key('box-height'));
Finder get thickness => find.byKey(const Key('wall-thickness'));
Finder get wallSection => find.byKey(const Key('wall-section'));

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

/// The justification segment's selection.
Set<Justification> shownJustification(WidgetTester tester) => tester
    .widget<SegmentedButton<Justification>>(
        find.byKey(const Key('wall-justification')))
    .selected;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

// Spec 07 D11's Wall section. Every wall sits at the far origin in its own
// rotated group (`groupAt`), the plan is turned 23 degrees, and the camera
// is rotated.

const Handle wa = Handle(1300), wb = Handle(2600), wc = Handle(3900);
const Handle bx = Handle(5200);

/// An L at the far origin: A (200, centre) runs into [lCorner] and B (115,
/// left) runs out of it at 110 degrees, each in its own rotated group.
final Vector2 lStart = plan(0, 0), lCorner = plan(3000, 0);
final Vector2 lEnd = polar(lCorner, 23 + 110, 2500);

/// A 1:20 page near the far origin, grid snap on at 10 mm; the L, a free
/// wall C (150, right) and a box in its own rotated group; no history.
DraftDocument panelDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          gridStepMm: 10)));
  // The shell installs the parametric system itself; the objects are added
  // through a temporary one, which regenerates them as they are created.
  final system = installParametric(doc);
  doc.commands
      .execute(addWall(doc, wa, lStart, lCorner, 200, Justification.centre));
  doc.commands
      .execute(addWall(doc, wb, lCorner, lEnd, 115, Justification.left));
  doc.commands.execute(addWall(
      doc, wc, plan(500, 1500), plan(2500, 1900), 150, Justification.right));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: bx,
        parent: doc.rootHandle,
        transform: groupAt(bx.value),
        children: const [])),
    SetComponentCommand<BoxParams>(bx, const BoxParams(120, 70)),
  ], label: 'Add box'));
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell over [doc], then sets a rotated, non-reflecting camera
/// centred on the L's corner.
Future<PlannerView> pumpPanel(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(0.15, 0.15));
  final mid = linear.transformPoint(lCorner);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Future<void> select(
    WidgetTester tester, PlannerView view, List<Handle> hs) async {
  view.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// A primary click at world [p].
Future<void> clickWorld(
    WidgetTester tester, PlannerView view, Vector2 p) async {
  final s = view.camera.value.worldToScreen(p);
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
  await tester.pump();
}

/// A fresh shell with SE's two boxes drawn, selection empty.
Future<PlannerView> pumpBoxes(WidgetTester tester) async {
  final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
  await drawTwoBoxes(tester, view);
  await press(tester, LogicalKeyboardKey.keyV);
  return view;
}

Future<void> enterAndSubmit(
    WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('SE1 shown for exactly one selected box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final bs = boxes(view.document);
    expect(width, findsNothing);
    view.selection.replace([SelectionKey.root(bs.first)]);
    await tester.pump();
    expect(width, findsOneWidget);
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SE2 hidden for none, two, and a non-box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final bs = boxes(view.document);
    view.selection.replace([for (final b in bs) SelectionKey.root(b)]);
    await tester.pump();
    expect(width, findsNothing);
    final line = addDrafted(view.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)));
    view.document.commands.execute(line);
    view.selection.replace([SelectionKey.root(line.record.handle)]);
    await tester.pump();
    expect(width, findsNothing);
  });

  testWidgets('SE3 Enter commits one step and regenerates', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 1);
    expect(ParametricSystem(view.document, parametricCatalog).drift(), isEmpty);
  });

  testWidgets('SE4 an invalid value reverts and commits nothing',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    for (final bad in ['0', '-3', 'abc']) {
      await tester.enterText(height, bad);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(height).controller!.text, '70');
    }
    expect(view.document.commands.undoDepth, depth);
  });

  testWidgets('SE5 under runtime the fields are read-only', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    view.document.commands.permissions = DraftPermissions.runtime;
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    expect(tester.widget<TextField>(width).readOnly, isTrue);
  });

  testWidgets(
      'SE6 undo after a panel edit shows the old width '
      '(Review Focus 4)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    view.document.commands.undo();
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SE7 typing B in the width field does not switch tools',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    await press(tester, LogicalKeyboardKey.keyV);
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    await tester.tap(width);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });

  testWidgets(
      'SE8 a tap outside the width field commits it via focus loss, '
      'with no Enter', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.pump();
    // No TextInputAction.done: the commit must come from the field's own
    // `FocusNode` losing focus, which `onTapOutside` triggers by unfocusing
    // -- not from a tap-outside handler that submits directly. Not a tap on
    // the Height field: `TextField`'s default `groupId` is `EditableText`,
    // so every plain `TextField` shares it, and a tap on another one counts
    // as *inside* the group, never outside -- this would fail to exercise
    // `onTapOutside` at all. The panel's "Box" label is a plain `Text`,
    // genuinely outside every field's tap region (`find.descendant` because
    // the status bar has its own "Box" text while the Box tool is armed).
    await tester.tap(find.descendant(
        of: find.byKey(const Key('selection-panel')),
        matching: find.text('Box')));
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 1);
  });

  testWidgets(
      'SE9 hovering geometry, or an unrelated edit, does not wipe an '
      'uncommitted value; a later commit still stores it', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final bs = boxes(view.document);
    final b = bs.first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.pump();
    // The real hover API (packages/jet_cad_2d_flutter/lib/src/selection.dart):
    // hovering different geometry notifies `SelectionController`'s
    // listeners exactly like a selection change would.
    view.selection.setHover(SelectionKey.root(bs[1]));
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '150');
    // Clears the hover again, in the test, rather than leaving that to
    // `InteractionLayer._release`'s own teardown-time clear
    // (packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart): a real
    // (non-idempotent) hover change happening as an unmanaged side effect
    // of the widget tree tearing down is unrelated noise this test does not
    // want to depend on.
    view.selection.setHover(null);
    await tester.pump();
    // An unrelated document edit: drawing a plain line notifies the
    // panel's document-change listener too, and must not touch the field
    // either.
    final line = addDrafted(view.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)));
    view.document.commands.execute(line);
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 2);
  });

  testWidgets(
      'SE10 moving focus from Width to Height commits Width, with no '
      'Enter', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.pump();
    await tester.tap(height);
    await tester.pump();
    await tester.enterText(height, '90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final p = view.document.components.get<BoxParams>(b)!;
    expect(p.width, 150);
    expect(p.height, 90);
  });

  testWidgets(
      'WS1 the Wall section shows for exactly one selected wall; hidden for '
      'none, two, and a box (which shows the Box section)', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    expect(wallSection, findsNothing);
    await select(tester, view, [wb]);
    expect(wallSection, findsOneWidget);
    expect(width, findsNothing);
    expect(textOf(tester, thickness), '115');
    expect(shownJustification(tester), {Justification.left});
    await select(tester, view, [wc]);
    expect(textOf(tester, thickness), '150');
    expect(shownJustification(tester), {Justification.right});
    await select(tester, view, [wa, wb]);
    expect(wallSection, findsNothing);
    await select(tester, view, [bx]);
    expect(wallSection, findsNothing);
    expect(textOf(tester, width), '120');
    await select(tester, view, []);
    expect(wallSection, findsNothing);
    expect(width, findsNothing);
  });

  testWidgets(
      'WS2 Enter commits the thickness in one undo step; the joined L '
      'regenerates, still mitred; undo shows the old value', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    await select(tester, view, [wa]);
    await enterAndSubmit(tester, thickness, '262.5');
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 262.5),
        reason: 'only the thickness, exactly');
    expect(doc.components.get<WallParams>(wb), pb);
    expectMitre(doc, wa, wb);
    expect(driftOf(doc), isEmpty);
    expect(textOf(tester, thickness), '262.5');
    doc.commands.undo();
    await tester.pump();
    expect(textOf(tester, thickness), '200');
    expect(doc.components.get<WallParams>(wa), pa);
  });

  testWidgets(
      'WS3 a thickness <= wallJoin.linear or unparseable reverts and commits '
      'nothing, for a wall and for the tool settings (final review m1)',
      (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    final pc = doc.components.get<WallParams>(wc)!;
    await select(tester, view, [wc]);
    // 1e-12 and wallJoin.linear itself are positive: the model would store
    // either (C's local outline triangulates), so only the floor refuses.
    for (final bad in ['0', '-40', '-0', 'abc', '', '1e-12', '0.000001']) {
      await enterAndSubmit(tester, thickness, bad);
      expect(textOf(tester, thickness), '150', reason: bad);
    }
    expect(doc.commands.undoDepth, 0);
    expect(doc.components.get<WallParams>(wc), pc);
    // W itself: Enter handed focus back to the canvas.
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(textOf(tester, thickness), '200');
    for (final bad in ['0', '-40', '1e-12', '0.000001']) {
      await enterAndSubmit(tester, thickness, bad);
      expect(textOf(tester, thickness), '200', reason: bad);
      expect((view.tools.active as WallTool).settings.value.thickness, 200,
          reason: bad);
    }
    await clickWorld(tester, view, plan(400, 900));
    await clickWorld(tester, view, plan(1900, 800));
    final w = walls(doc).last;
    expect(w, isNot(wc));
    expect(doc.components.get<WallParams>(w)!.thickness, 200);
  });

  testWidgets(
      "WS4 a justification change on a joined wall moves both walls' "
      'corners, in one undo step (Review Focus 4)', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    expectMitre(doc, wa, wb);
    final ra0 = worldOutline(doc, wa), rb0 = worldOutline(doc, wb);
    final shared0 = sharedNear(ra0, rb0);
    final pa = doc.components.get<WallParams>(wa)!;
    await select(tester, view, [wa]);
    expect(shownJustification(tester), {Justification.centre});
    await tapKey(tester, 'wall-left');
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wa),
        pa.copyWith(justification: Justification.left));
    expect(shownJustification(tester), {Justification.left});
    // The corners: A's two faces now sit at (200, 0), so both mitre
    // corners are the oracle meets of the new faces with B's.
    expectMitre(doc, wa, wb);
    final ra1 = worldOutline(doc, wa), rb1 = worldOutline(doc, wb);
    final shared1 = sharedNear(ra1, rb1);
    for (final p in shared0) {
      expect(nearestIn(shared1, p), greaterThan(50),
          reason: 'every shared corner moved');
    }
    // B's corners at the joint moved; its two at the far end did not.
    expect(sharedNear(rb0, rb1), hasLength(2));
    expect([for (final p in sharedNear(rb0, rb1)) nearestIn(shared0, p)],
        everyElement(greaterThan(1000)));
    // A's start is free: its square end moved by the face shift alone.
    expect(sharedNear(ra0, ra1), isEmpty);
    expect(driftOf(doc), isEmpty);
    await tapKey(tester, 'wall-left');
    expect(doc.commands.undoDepth, 1, reason: 'the same value is no step');
    doc.commands.undo();
    await tester.pump();
    expect(shownJustification(tester), {Justification.centre});
    expect(sharedNear(worldOutline(doc, wa), ra0), hasLength(4));
    expectMitre(doc, wa, wb);
  });

  testWidgets(
      'WS5 under runtime the Wall section is read-only: the field and the '
      'toggle', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    doc.commands.permissions = DraftPermissions.runtime;
    await select(tester, view, [wa]);
    expect(tester.widget<TextField>(thickness).readOnly, isTrue);
    expect(
        tester
            .widget<SegmentedButton<Justification>>(
                find.byKey(const Key('wall-justification')))
            .onSelectionChanged,
        isNull);
    await tapKey(tester, 'wall-right');
    expect(doc.components.get<WallParams>(wa), pa);
    expect(doc.commands.undoDepth, 0);
    doc.commands.permissions = DraftPermissions.all;
    await select(tester, view, [wb]);
    expect(tester.widget<TextField>(thickness).readOnly, isFalse);
  });

  testWidgets(
      "WS6 with the Wall tool active the section edits the tool's settings "
      '(no undo step) and the next wall uses them; tool letters typed in '
      'the field do not switch tools', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(wallSection, findsOneWidget);
    expect(textOf(tester, thickness), '200');
    expect(shownJustification(tester), {Justification.centre});
    await enterAndSubmit(tester, thickness, '115');
    await tapKey(tester, 'wall-left');
    expect(doc.commands.undoDepth, 0, reason: 'settings are not the model');
    await tester.tap(thickness);
    await tester.pump();
    for (final k in [LogicalKeyboardKey.keyV, LogicalKeyboardKey.keyB]) {
      await press(tester, k);
      expect(status(tester), 'Wall');
    }
    await clickWorld(tester, view, plan(400, 900));
    await clickWorld(tester, view, plan(1900, 800));
    await press(tester, LogicalKeyboardKey.enter);
    final w = walls(doc).last;
    expect(w, isNot(wc));
    final p = doc.components.get<WallParams>(w)!;
    expect([p.thickness, p.justification], [115, Justification.left]);
    expect(textOf(tester, thickness), '115');
    expect(shownJustification(tester), {Justification.left});
    PlacementTool tool() => view.tools.active as PlacementTool;

    // Typed with no Enter, then a click mid-chain: the keystrokes already
    // reached the settings, so that click's wall has them (review round 1,
    // I1).
    await clickWorld(tester, view, plan(1500, -900));
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '400');
    await tester.pump();
    await clickWorld(tester, view, plan(2800, -1000));
    final w400 = walls(doc).last;
    expect(w400, isNot(w));
    expect(doc.components.get<WallParams>(w400)!.thickness, 400);
    expect(tool().isPending, isTrue);

    // Mid-chain, Enter in the field hands focus back to the canvas: Escape
    // ends the chain with no extra wall, and the letters work again.
    final count = walls(doc).length;
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '90');
    expect(tool().isPending, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(tool().isPending, isFalse);
    expect(walls(doc), hasLength(count));
    expect(status(tester), 'Wall');
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '95');
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    expect(textOf(tester, thickness), '95');

    // Back to Select: the section follows the selection again.
    await press(tester, LogicalKeyboardKey.keyV);
    expect(wallSection, findsNothing);
    await select(tester, view, [wa]);
    expect(textOf(tester, thickness), '200');
  });

  testWidgets(
      'WS7 (Wall) the commit target is pinned at focus gain: a selection '
      'change while a field has focus does not redirect its commit (M-07p); '
      'a pinned wall that dies drops the text', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    final pc = doc.components.get<WallParams>(wc)!;
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '260');
    await tester.pump();
    await select(tester, view, [wc]);
    expect(textOf(tester, thickness), '260', reason: 'focused: not reloaded');
    // Blur: a tap outside the field, on the section's title.
    await tester.tap(wallSection);
    await tester.pump();
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 260));
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.undoDepth, 1);
    expect(textOf(tester, thickness), '150', reason: "now C's");

    // Enter after the selection change: the value still lands on A, once,
    // and the field then shows C (review round 1, I3).
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '275');
    await select(tester, view, [wc]);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(doc.components.get<WallParams>(wa), pa.copyWith(thickness: 275));
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.undoDepth, 2);
    expect(textOf(tester, thickness), '150');

    // The pinned wall dies while another wall is shown, so the field stays
    // mounted: blurring drops the text (review round 1, I2).
    const we = Handle(7800);
    doc.commands.execute(addWall(
        doc, we, plan(0, -900), plan(1400, -1300), 90, Justification.left));
    await select(tester, view, [we]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '333');
    await select(tester, view, [wc]);
    doc.commands.undo();
    await tester.pump();
    expect(doc.tree[we], isNull);
    expect(wallSection, findsOneWidget);
    await tester.tap(wallSection);
    await tester.pump();
    expect(doc.components.get<WallParams>(wc), pc);
    expect(doc.commands.canRedo, isTrue, reason: 'nothing was executed');
    expect(textOf(tester, thickness), '150');

    // The pinned wall dies while the field has focus: the section hides,
    // the field loses focus, and the text is dropped.
    const wd = Handle(6500);
    doc.commands.execute(addWall(
        doc, wd, plan(0, -900), plan(1400, -1300), 90, Justification.left));
    await select(tester, view, [wd]);
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '333');
    await tester.pump();
    doc.commands.undo();
    await tester.pump();
    expect(doc.tree[wd], isNull);
    expect(wallSection, findsNothing);
    expect(doc.commands.canRedo, isTrue, reason: 'nothing was executed');
    expect(doc.commands.undoDepth, 2);
    expect([
      for (final h in walls(doc)) doc.components.get<WallParams>(h)!.thickness
    ], [
      275,
      115,
      150
    ]);
  });

  testWidgets(
      'WS7 (Box) the commit target is pinned at focus gain: a selection '
      'change while a field has focus does not redirect its commit (M-07p)',
      (tester) async {
    final box = await pumpBoxes(tester);
    final bs = boxes(box.document);
    final b0 = box.document.components.get<BoxParams>(bs[0])!;
    final b1 = box.document.components.get<BoxParams>(bs[1])!;
    await select(tester, box, [bs[0]]);
    await tester.tap(width);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.pump();
    await select(tester, box, [bs[1]]);
    expect(textOf(tester, width), '150');
    await tester.tap(find.descendant(
        of: find.byKey(const Key('selection-panel')),
        matching: find.text('Box')));
    await tester.pump();
    List<double> sizeOf(Handle h) {
      final p = box.document.components.get<BoxParams>(h)!;
      return [p.width, p.height];
    }

    expect(sizeOf(bs[0]), [150, b0.height]);
    expect(sizeOf(bs[1]), [b1.width, b1.height]);
    expect(textOf(tester, width), '90');
  });

  testWidgets(
      'WS8 with geometry allowed and components denied, the Wall and Box '
      'fields are read-only: a commit is a SetComponentCommand (final '
      'review m4)', (tester) async {
    final view = await pumpPanel(tester, panelDoc(FlutterTextMeasurer()));
    final doc = view.document;
    final pa = doc.components.get<WallParams>(wa)!;
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    await select(tester, view, [wa]);
    expect(tester.widget<TextField>(thickness).readOnly, isTrue);
    expect(
        tester
            .widget<SegmentedButton<Justification>>(
                find.byKey(const Key('wall-justification')))
            .onSelectionChanged,
        isNull);
    await tapKey(tester, 'wall-right');
    expect(doc.components.get<WallParams>(wa), pa);
    await select(tester, view, [bx]);
    expect(tester.widget<TextField>(width).readOnly, isTrue);
    expect(tester.widget<TextField>(height).readOnly, isTrue);
    expect(doc.commands.undoDepth, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'WS9 an edit the document refuses (a loaded fill naming another '
      "wall's outline) reverts the field and re-pins it: no exception "
      'escapes Enter, the focus loss or the justification toggle (final '
      'review m1)', (tester) async {
    final j = DraftDocumentCodec.encode(panelDoc(FlutterTextMeasurer()));
    // A's fill names B's outline: a malformed file the planner refuses
    // to regenerate (spec 07 D8).
    final src = panelDoc(FlutterTextMeasurer());
    final aFill =
        kids(src, wa).firstWhere((k) => kindOf(src, k) == EntityKind.fill);
    final bFill =
        kids(src, wb).firstWhere((k) => kindOf(src, k) == EntityKind.fill);
    final bOutline = payloadOf(src, bFill).scalars[0];
    for (final e in j['entities']! as List) {
      final entity = e as Map<String, Object?>;
      if ((entity['record']! as Map)['handle'] == aFill.value) {
        (entity['geometry']! as Map)['scalars'] = [bOutline];
      }
    }
    final doc = DraftDocumentCodec.decode(
        jsonDecode(jsonEncode(j)) as Map<String, Object?>,
        measurer: FlutterTextMeasurer(), registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });
    final view = await pumpPanel(tester, doc);
    final pa = doc.components.get<WallParams>(wa)!;
    final before = enc(doc);
    await select(tester, view, [wa]);
    await tester.tap(thickness);
    await tester.pump();
    await enterAndSubmit(tester, thickness, '250');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '200', reason: 'reverted');
    expect(doc.components.get<WallParams>(wa), pa);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);
    // The focus loss alone: typed, then a tap outside.
    await tester.tap(thickness);
    await tester.pump();
    await tester.enterText(thickness, '260');
    await tester.pump();
    await tester.tap(wallSection);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(textOf(tester, thickness), '200');
    expect(enc(doc), before);
    // The justification toggle: refused alike, and it keeps showing A's.
    await tapKey(tester, 'wall-left');
    expect(tester.takeException(), isNull);
    expect(shownJustification(tester), {Justification.centre});
    expect(doc.components.get<WallParams>(wa), pa);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);
    // C, no neighbour of A's, is sound: its edit lands.
    await select(tester, view, [wc]);
    await enterAndSubmit(tester, thickness, '120');
    expect(doc.components.get<WallParams>(wc)!.thickness, 120);
    expect(doc.commands.undoDepth, 1);
  });

  /// The canvas's own focus node: the `Focus` the `InteractionLayer` builds.
  FocusNode canvasFocus(WidgetTester tester) => tester
      .widget<Focus>(find
          .descendant(
              of: find.byType(InteractionLayer), matching: find.byType(Focus))
          .first)
      .focusNode!;

  Finder pageScale() => find.byKey(const Key('page-scale'));

  /// Selects the first of SE's boxes (120 x 70), types 150 into Width and
  /// then 90 into Height, with no Enter: both fields are now in the scope's
  /// focus history, Width before Height. Returns the box.
  Future<Handle> typeWidthThenHeight(
      WidgetTester tester, PlannerView view) async {
    final b = boxes(view.document).first;
    await select(tester, view, [b]);
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

  List<double> sizeOf(PlannerView view, Handle b) {
    final p = view.document.components.get<BoxParams>(b)!;
    return [p.width, p.height];
  }

  testWidgets(
      'SE11 a tap on the panel after Width then Height commits both and '
      'hands focus back to the canvas, not to Width (fix/post-07 F3, B7)',
      (tester) async {
    final view = await pumpBoxes(tester);
    final depth = view.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, view);
    await tester.tap(find.descendant(
        of: find.byKey(const Key('selection-panel')),
        matching: find.text('Box')));
    await tester.pump();
    expect(sizeOf(view, b), [150, 90]);
    expect(view.document.commands.undoDepth, depth + 2);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });

  testWidgets(
      'SE12 Enter in Height after Width commits both and hands focus back to '
      'the canvas, not to Width (fix/post-07 F3)', (tester) async {
    final view = await pumpBoxes(tester);
    final depth = view.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, view);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sizeOf(view, b), [150, 90]);
    expect(view.document.commands.undoDepth, depth + 2);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });

  testWidgets(
      "SE13 Enter in the page panel's scale after Width then Height commits "
      'all three and hands focus back to the canvas, past both Selection '
      'panel fields (fix/post-07 F3)', (tester) async {
    final view = await pumpBoxes(tester);
    final doc = view.document;
    final depth = doc.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, view);
    await tester.tap(pageScale());
    await tester.pump();
    await tester.enterText(pageScale(), '50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sizeOf(view, b), [150, 90]);
    expect(doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator,
        50);
    expect(doc.commands.undoDepth, depth + 3);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
  });

  testWidgets(
      'SE14 a canvas click after Width then Height commits both and leaves '
      "the canvas's own focus request alone (fix/post-07 F3)", (tester) async {
    final view = await pumpBoxes(tester);
    final depth = view.document.commands.undoDepth;
    final b = await typeWidthThenHeight(tester, view);
    // Empty paper, clear of both boxes: the click also clears the
    // selection, which unmounts the fields.
    await tester.tapAt(globalOf(tester, view, 7150, 3250));
    await tester.pump();
    expect(sizeOf(view, b), [150, 90]);
    expect(view.document.commands.undoDepth, depth + 2);
    expect(width, findsNothing);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)));
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
  });
}
