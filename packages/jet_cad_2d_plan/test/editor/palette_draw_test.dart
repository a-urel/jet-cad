// Ported from jet_cad_floor_plan/test/planner_draw_test.dart; assertions unchanged.
//
// The palette and the keyboard over the design composition (Task 16's
// design_harness.dart): A1-A6, A8, A10-A13. The canvas-only cases (A7,
// A17, A20-A22) are Task 15's (test/canvas/canvas_draw_test.dart); the
// page panel's (A9, A14, A15, A18, A19, A23-A26) are Task 18's; the bar's
// read-outs (A16, A27) are Task 20's.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

void main() {
  testWidgets('A1 each palette entry activates its tool', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    for (final (key, name) in const [
      ('tool-plan.line', 'Line'),
      ('tool-plan.polyline', 'Polyline'),
      ('tool-plan.rectangle', 'Rectangle'),
      ('tool-plan.circle', 'Circle'),
      ('tool-plan.arc', 'Arc'),
      ('tool-plan.text', 'Text'),
      ('tool-plan.select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }
  });

  testWidgets('A2 each shortcut activates its tool, and F toggles Fill',
      (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    for (final (key, name) in const [
      (LogicalKeyboardKey.keyL, 'Line'),
      (LogicalKeyboardKey.keyP, 'Polyline'),
      (LogicalKeyboardKey.keyR, 'Rectangle'),
      (LogicalKeyboardKey.keyC, 'Circle'),
      (LogicalKeyboardKey.keyA, 'Arc'),
      (LogicalKeyboardKey.keyT, 'Text'),
      (LogicalKeyboardKey.keyV, 'Select'),
    ]) {
      await press(tester, key);
      expect(status(tester), name);
    }
    bool fill() => tester
        .widget<CheckboxListTile>(find.byKey(const Key('tool-fill')))
        .value!;
    expect(fill(), isFalse);
    await press(tester, LogicalKeyboardKey.keyF);
    expect(fill(), isTrue);
    await tester.tap(find.byKey(const Key('tool-fill')));
    await tester.pump();
    expect(fill(), isFalse);
  });

  testWidgets('A3 activating a drawing tool clears the selection',
      (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    c.selection.replace([SelectionKey.root(f.line)]);
    await tester.pump();
    expect(c.selection.isEmpty, isFalse);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(c.selection.isEmpty, isTrue);
  });

  testWidgets('A4 an idle Escape returns to Select (M-05m)', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    await press(tester, LogicalKeyboardKey.keyL);
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'A5 text end to end: T, click, type, Enter; then focus is back '
      'on the canvas', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100.5, 3050.25));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('text-entry')), 'Kitchen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final text = ofKind(c.document, EntityKind.text).single;
    final slot = c.document.entities.slotOf(text)!;
    expect(c.document.entities.read(slot).text, 'Kitchen');
    expect(
        c.document.geometry
            .read(c.document.entities.geomIndexAt(slot))
            .scalars[0],
        50.0);
    expect(find.byKey(const Key('text-entry')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line', reason: 'Ruling 05-7: focus came back');
  });

  testWidgets(
      'A6 text: Escape and a palette click cancel byte-identically; a '
      'canvas click commits', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    final before = bytes(c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await press(tester, LogicalKeyboardKey.escape);
    expect(bytes(c), before);
    expect(find.byKey(const Key('text-entry')), findsNothing);

    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'y');
    await tester.tap(find.byKey(const Key('tool-plan.select')));
    await tester.pump();
    expect(bytes(c), before);

    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'Hall');
    // Spec 05 D9: a click on the field is not a canvas click.
    await tester.tap(find.byKey(const Key('text-entry')));
    await tester.pump();
    expect(ofKind(c.document, EntityKind.text), isEmpty);
    // Off the field: (7180, 3020) projects 171 px right of and 1.5 px above
    // the anchor, inside the 240 x 32 field, so it would click the field.
    await tester.tapAt(globalOf(tester, c, 7180, 3120));
    await tester.pump();
    expect(ofKind(c.document, EntityKind.text), hasLength(1));
  });

  testWidgets(
      'A8 shell letters typed into the field are not consumed and do '
      'not switch tools (M-05v)', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    for (final key in const [
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyV,
    ]) {
      expect(await press(tester, key), isFalse,
          reason: '$key reaches the platform as text (Ruling 05-9)');
      expect(status(tester), 'Text');
    }
  });

  testWidgets(
      'A10 a shortcut mid-polyline is swallowed; a palette switch cancels '
      'byte-identically (Review Focus 2, Ruling T7-a)', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    final before = bytes(c);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7060, 3090));
    await tester.pump();
    // Spec 05 D3 (pinned by B5): mid-shape the tool handles every other
    // key-down, so the shell's L never arrives. The palette is the switch.
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Polyline');
    expect((activeTool(c) as PolylineTool).isPending, isTrue);
    await tester.tap(find.byKey(const Key('tool-plan.line')));
    await tester.pump();
    expect(status(tester), 'Line');
    expect(bytes(c), before);
  });

  testWidgets(
      'A11 cmd+Z after a commit, with the tool armed and idle, removes '
      'exactly that shape (Review Focus 5)', (tester) async {
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    final before = withoutSeed(c);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, c, 7010, 3020));
    await tester.tapAt(globalOf(tester, c, 7090, 3070));
    await tester.pump();
    expect(ofKind(c.document, EntityKind.polyline), hasLength(1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(withoutSeed(c), before);
    expect(status(tester), 'Rectangle', reason: 'still armed');
  });

  testWidgets('A12 under runtime permissions the drawing tools are disabled',
      (tester) async {
    final f = drawController();
    final c = f.c;
    c.document.commands.permissions = DraftPermissions.runtime;
    await pumpDesign(tester, c);
    expect(
        tester
            .widget<ListTile>(find.byKey(const Key('tool-plan.line')))
            .enabled,
        isFalse);
    expect(
        tester
            .widget<ListTile>(find.byKey(const Key('tool-plan.select')))
            .enabled,
        isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Select');
  });

  testWidgets(
      "A12b every palette entry's drawing flag, by key: under runtime "
      'permissions each drawing tool is disabled and Select is not; with '
      'every permission all are enabled (Plan 11 rvF-paletteNotDrawing)',
      (tester) async {
    // Whether each entry is a drawing tool. The palette must carry exactly
    // these keys: an entry missing here, or missing from the palette, fails.
    // The planner's box, wall, door, window, gap, room, separator and
    // dimension rows are sub-project 3's tools and leave with them.
    const drawing = {
      'tool-plan.select': false,
      'tool-plan.line': true,
      'tool-plan.polyline': true,
      'tool-plan.rectangle': true,
      'tool-plan.circle': true,
      'tool-plan.arc': true,
      'tool-plan.text': true,
    };
    // The tool tiles: the Fill toggle's inner ListTile carries no key.
    List<String> paletteKeys() => [
          for (final t in tester.widgetList<ListTile>(find.descendant(
              of: find.byType(PlanToolPalette),
              matching: find.byType(ListTile))))
            if (t.key case final ValueKey<String> k) k.value,
        ];
    bool enabled(String key) =>
        tester.widget<ListTile>(find.byKey(Key(key))).enabled;

    final f = drawController();
    final c = f.c;
    expect(c.document.commands.permissions.allows(Capability.geometry), isTrue);
    await pumpDesign(tester, c);
    expect(paletteKeys(), unorderedEquals(drawing.keys));
    for (final key in drawing.keys) {
      expect(enabled(key), isTrue, reason: '$key with every permission');
    }

    c.document.commands.permissions = DraftPermissions.runtime;
    expect(
        c.document.commands.permissions.allows(Capability.geometry), isFalse);
    await pumpDesign(tester, c);
    expect(paletteKeys(), unorderedEquals(drawing.keys));
    for (final MapEntry(:key, value: isDrawing) in drawing.entries) {
      expect(enabled(key), !isDrawing,
          reason: isDrawing ? '$key draws: disabled' : '$key: enabled');
    }
  });

  testWidgets(
      'A13 a window switch with text pending keeps the field, its text '
      'and its focus (Ruling T7-b)', (tester) async {
    // The focus manager follows the app lifecycle on desktop and web only,
    // hence the macOS variant.
    FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
    final f = drawController();
    final c = f.c;
    await pumpDesign(tester, c);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, c, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    final placed = c.textTool;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus,
        same(FocusManager.instance.rootScope),
        reason: 'the window switch moved focus off the field');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    expect(placed.controller.text, 'x');
    expect(
        tester
            .state<EditableTextState>(entryEditable)
            .widget
            .focusNode
            .hasFocus,
        isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line');
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
