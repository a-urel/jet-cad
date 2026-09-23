import 'dart:convert' show jsonDecode;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 1:20 page anchored at (7000, 3000), grid snap off, and one line to
/// select. `DraftCanvas` needs a `FlutterTextMeasurer`.
({DraftDocument doc, Handle line}) drawDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  final add = addDrafted(doc, EntityKind.line,
      linePayload(Vector2(7137.3, 3161.7), Vector2(7300.9, 3190.1)));
  doc.commands.execute(add);
  doc.commands.clearHistory();
  return (doc: doc, line: add.record.handle);
}

/// Pumps the shell, then sets a zoomed, rotated, **non-reflecting** camera:
/// the app camera in `planner_grips_test.dart` is a reflection, whose
/// `b == c` hides a transposition.
Future<PlannerView> pumpDraw(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.35).multiply(Transform2.scale(2.0, 2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

String bytes(PlannerView view) =>
    DraftDocumentCodec.encodeToString(view.document);

/// The snapshot less `handleSeed`: undo never lowers the seed (handles are
/// never reused), so a commit and its undo differ from the start in it alone.
Map<String, Object?> withoutSeed(PlannerView view) =>
    (jsonDecode(bytes(view)) as Map<String, Object?>)..remove('handleSeed');

/// The inline field's `EditableText`; the page panel's scale field has one
/// too.
final Finder entryEditable = find.descendant(
    of: find.byKey(const Key('text-entry')),
    matching: find.byType(EditableText));

List<Handle> ofKind(DraftDocument doc, EntityKind kind) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == kind) doc.entities.handleAt(slot),
    ];

void main() {
  testWidgets('A1 each palette entry activates its tool', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    for (final (key, name) in const [
      ('tool-line', 'Line'),
      ('tool-polyline', 'Polyline'),
      ('tool-rectangle', 'Rectangle'),
      ('tool-circle', 'Circle'),
      ('tool-arc', 'Arc'),
      ('tool-text', 'Text'),
      ('tool-select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }
  });

  testWidgets('A2 each shortcut activates its tool, and F toggles Fill',
      (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
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
    final d = drawDoc(FlutterTextMeasurer());
    final view = await pumpDraw(tester, d.doc);
    view.selection.replace([SelectionKey.root(d.line)]);
    await tester.pump();
    expect(view.selection.isEmpty, isFalse);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(view.selection.isEmpty, isTrue);
  });

  testWidgets('A4 an idle Escape returns to Select (M-05m)', (tester) async {
    await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyL);
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'A5 text end to end: T, click, type, Enter; then focus is back '
      'on the canvas', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('text-entry')), 'Kitchen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final text = ofKind(view.document, EntityKind.text).single;
    final slot = view.document.entities.slotOf(text)!;
    expect(view.document.entities.read(slot).text, 'Kitchen');
    expect(
        view.document.geometry
            .read(view.document.entities.geomIndexAt(slot))
            .scalars[0],
        50.0);
    expect(find.byKey(const Key('text-entry')), findsNothing);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Line', reason: 'Ruling 05-7: focus came back');
  });

  testWidgets(
      'A6 text: Escape and a palette click cancel byte-identically; a '
      'canvas click commits', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await press(tester, LogicalKeyboardKey.escape);
    expect(bytes(view), before);
    expect(find.byKey(const Key('text-entry')), findsNothing);

    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'y');
    await tester.tap(find.byKey(const Key('tool-select')));
    await tester.pump();
    expect(bytes(view), before);

    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'Hall');
    // Spec 05 D9: a click on the field is not a canvas click.
    await tester.tap(find.byKey(const Key('text-entry')));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.text), isEmpty);
    // Off the field: (7180, 3020) projects 171 px right of and 1.5 px above
    // the anchor, inside the 240 x 32 field, so it would click the field.
    await tester.tapAt(globalOf(tester, view, 7180, 3120));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.text), hasLength(1));
  });

  testWidgets(
      'A7 the field sits at the camera\'s point and survives a pan '
      'with its state (M-05n, M-05u)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100.5, 3050.25));
    await tester.pump();
    final field = find.byKey(const Key('text-entry'));
    final placed = view.tools.active as TextTool;
    final at = placed.pending.value!.point;
    Offset corner() =>
        tester.getBottomLeft(find.byKey(const Key('text-entry-box')));
    final want = globalOf(tester, view, at.x, at.y);
    expect((corner() - want).distance, lessThan(0.5));
    await tester.enterText(field, 'abc');
    final state = tester.state<EditableTextState>(entryEditable);
    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(40, -25)
            .multiply(view.camera.value.worldToScreenMatrix));
    await tester.pump();
    expect((corner() - globalOf(tester, view, at.x, at.y)).distance,
        lessThan(0.5));
    expect(identical(tester.state<EditableTextState>(entryEditable), state),
        isTrue,
        reason: 'Ruling 05-10: never rebuilt by the camera');
    expect(state.widget.focusNode.hasFocus, isTrue);
    expect(placed.controller.text, 'abc');
  });

  testWidgets(
      'A8 shell letters typed into the field are not consumed and do '
      'not switch tools (M-05v)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
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
      'A9 letters and cmd+Z in the page panel\'s scale field neither '
      'switch tools nor undo the document (Review Focus 1)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(view.document.commands.undoDepth, 1);
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(await press(tester, LogicalKeyboardKey.keyL), isFalse);
    expect(status(tester), 'Rectangle');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(view.document.commands.undoDepth, 1, reason: 'not undone');
  });

  testWidgets(
      'A10 a shortcut mid-polyline is swallowed; a palette switch cancels '
      'byte-identically (Review Focus 2, Ruling T7-a)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7060, 3090));
    await tester.pump();
    // Spec 05 D3 (pinned by B5): mid-shape the tool handles every other
    // key-down, so the shell's L never arrives. The palette is the switch.
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Polyline');
    expect((view.tools.active as PolylineTool).isPending, isTrue);
    await tester.tap(find.byKey(const Key('tool-line')));
    await tester.pump();
    expect(status(tester), 'Line');
    expect(bytes(view), before);
  });

  testWidgets(
      'A11 cmd+Z after a commit, with the tool armed and idle, removes '
      'exactly that shape (Review Focus 5)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = withoutSeed(view);
    await press(tester, LogicalKeyboardKey.keyR);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7090, 3070));
    await tester.pump();
    expect(ofKind(view.document, EntityKind.polyline), hasLength(1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(withoutSeed(view), before);
    expect(status(tester), 'Rectangle', reason: 'still armed');
  });

  testWidgets('A12 under runtime permissions the drawing tools are disabled',
      (tester) async {
    final d = drawDoc(FlutterTextMeasurer());
    d.doc.commands.permissions = DraftPermissions.runtime;
    await pumpDraw(tester, d.doc);
    expect(tester.widget<ListTile>(find.byKey(const Key('tool-line'))).enabled,
        isFalse);
    expect(
        tester.widget<ListTile>(find.byKey(const Key('tool-select'))).enabled,
        isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'A13 a window switch with text pending keeps the field, its text '
      'and its focus (Ruling T7-b)', (tester) async {
    // The focus manager follows the app lifecycle on desktop and web only,
    // hence the macOS variant.
    FocusManager.instance.listenToApplicationLifecycleChangesIfSupported();
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    final placed = view.tools.active as TextTool;
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

  testWidgets(
      'A14 Escape in the page panel\'s scale field keeps a pending '
      'polyline (spec 05 D9: the guard covers the shell\'s Escape)',
      (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7060, 3090));
    await tester.pump();
    final polyline = view.tools.active as PolylineTool;
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
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    final before = bytes(view);
    await press(tester, LogicalKeyboardKey.keyT);
    await tester.tapAt(globalOf(tester, view, 7100, 3050));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-entry')), 'x');
    await tester.tap(find.byKey(const Key('page-scale')));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsNothing);
    expect((view.tools.active as TextTool).pending.value, isNull);
    expect(bytes(view), before);
  });

  testWidgets(
      'A16 F3 mid-polyline flips OSNAP and keeps the shape pending '
      '(Ruling F-2)', (tester) async {
    final view = await pumpDraw(tester, drawDoc(FlutterTextMeasurer()).doc);
    await press(tester, LogicalKeyboardKey.keyP);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7060, 3090));
    await tester.pump();
    final polyline = view.tools.active as PolylineTool;
    expect(polyline.isPending, isTrue);
    String osnapText() =>
        tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;
    expect(osnapText(), 'OSNAP');
    await press(tester, LogicalKeyboardKey.f3);
    expect(osnapText(), 'osnap off',
        reason: 'the tool ignores F3, so it reaches the shell');
    expect(status(tester), 'Polyline');
    expect(polyline.isPending, isTrue);
  });
}
