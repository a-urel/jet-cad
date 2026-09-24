import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/box_rig.dart';

// Named SE1-SE7, not SP1-SP7 as the task brief has it: `startup_plan_test.dart`
// already uses SP1-SP5 (controller ruling for Task 8).

Finder get width => find.byKey(const Key('box-width'));
Finder get height => find.byKey(const Key('box-height'));

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
    expect(ParametricSystem(view.document, boxCatalog).drift(), isEmpty);
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

  testWidgets('SE8 a tap outside the width field commits it, with no Enter',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.pump();
    // No TextInputAction.done: the commit must come from the tap below.
    // Not a tap on the Height field: `TextField`'s default `groupId` is
    // `EditableText`, so every plain `TextField` shares it, and a tap on
    // another one counts as *inside* the group, never outside -- this
    // would fail to exercise `onTapOutside` at all. The panel's "Box"
    // label is a plain `Text`, genuinely outside every field's tap region
    // (`find.descendant` because the status bar has its own "Box" text
    // while the Box tool is armed).
    await tester.tap(find.descendant(
        of: find.byKey(const Key('selection-panel')),
        matching: find.text('Box')));
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 1);
  });
}
