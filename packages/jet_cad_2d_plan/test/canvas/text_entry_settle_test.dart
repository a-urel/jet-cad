// The text entry's settle (planner_shell.dart:845-865, Task 4b): the
// controller's `settlePendingInput` finishes an open entry as Enter would,
// the entry's registration follows its life (released on dispose, moved on a
// controller swap).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/text_entry_overlay.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

/// [c]'s text tool with a pending placement and [text] typed.
TextTool openEntry(PlanController c, String text) {
  final tool = c.textTool;
  tool.accept(Vector2(7100, 3050), c.toolContext);
  tool.controller.text = text;
  expect(tool.isPending, isTrue, reason: 'premise: the entry is open');
  return tool;
}

Widget overlay(PlanController c, CameraController camera) => MaterialApp(
        home: Scaffold(
            body: Stack(children: [
      TextEntryOverlay(
          controller: c,
          tool: c.textTool,
          tools: c.toolController,
          camera: camera),
    ])));

void main() {
  testWidgets(
      'TES-1 saving with a text entry open commits the typed text as one '
      'step and closes the entry; M-SET-1: drop the overlay\'s '
      'registerSettle (planner_shell.dart:845-865)', (tester) async {
    final c = drawController().c;
    await pumpDesign(tester, c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'Kitchen');
    final depth = c.document.commands.undoDepth;
    expect(bytes(c), isNot(contains('Kitchen')), reason: 'premise: typed only');

    final saved = c.save();
    await tester.pump();
    expect(saved, contains('Kitchen'));
    expect(c.document.commands.undoDepth, depth + 1, reason: 'one step');
    expect(find.byKey(const Key('text-entry')), findsNothing);
    expect((activeTool(c) as TextTool).pending.value, isNull);
    expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
        reason: 'the focus is back on the canvas');
  });

  testWidgets(
      'TES-2 an unmounted overlay\'s settle is withdrawn: a later save '
      'commits nothing through it; M-TES-2: drop the release in dispose',
      (tester) async {
    final c = drawController().c;
    final camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300)));
    addTearDown(camera.dispose);
    await tester.pumpWidget(overlay(c, camera));
    final tool = openEntry(c, 'Leak');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(tool.isPending, isTrue, reason: 'premise: still open, no overlay');

    final saved = c.save();
    expect(saved, isNot(contains('Leak')));
    expect(tool.isPending, isTrue, reason: 'nobody finished it');
  });

  testWidgets(
      'TES-3 a controller swap moves the overlay\'s settle: the old '
      'controller settles nothing of the new one\'s, the new one settles it; '
      'M-TES-3a: drop the release in didUpdateWidget; M-TES-3b: drop the '
      're-registration', (tester) async {
    final a = drawController().c;
    final b = drawController().c;
    final camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300)));
    addTearDown(camera.dispose);
    await tester.pumpWidget(overlay(a, camera));
    await tester.pumpWidget(overlay(b, camera));
    final base = b.document.commands.undoDepth;
    final tool = openEntry(b, 'Swapped');
    await tester.pump();

    a.settlePendingInput();
    expect(tool.isPending, isTrue,
        reason: 'the old controller\'s settle is gone');
    expect(b.document.commands.undoDepth, base);

    b.settlePendingInput();
    await tester.pump();
    expect(tool.isPending, isFalse);
    expect(b.document.commands.undoDepth, base + 1, reason: 'one step');
    expect(bytes(b), contains('Swapped'),
        reason: 'the new controller settles it');
  });
}
