// Spec 12a D2's settle (plan 12a Task 7): a flow commits typed but
// unsubmitted input before it reads the document, synchronously -- a
// Selection panel value lands as its own step, an open text entry is
// committed, and the page scale field is re-synced to the stored scale --
// and the saved bytes, the save point and the dirty state all see it. A
// toolbar click on macOS with a mouse does not end the text entry first
// (T-1). A text entry ended by a click elsewhere hands the focus back to
// the canvas, where the file chords work.
import 'dart:convert';

import 'package:floor_planner/panel_focus.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/panel_number.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(37654.25, -28765.5);

/// Cmd+S, spelled out; whether the key-down was handled.
Future<bool> cmdS(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
  return handled;
}

/// Cmd+Shift+S (Save As), spelled out; whether the key-down was handled.
Future<bool> cmdShiftS(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  final handled = await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
  return handled;
}

/// The saved [bytes] decoded as the app opens a file.
DraftDocument decoded(List<int> bytes) {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  final doc = DraftDocumentCodec.decodeString(utf8.decode(bytes),
      measurer: m,
      registerComponents: registerAppComponents,
      diagnostics: <Diagnostic>[]);
  addTearDown(doc.dispose);
  return doc;
}

/// The strings of [doc]'s text entities.
List<String> textsOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.text)
          doc.entities.read(slot).text,
    ];

double scaleOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.scaleDenominator;

/// Whether the canvas (the `InteractionLayer`'s node) has the focus.
bool canvasFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'InteractionLayer';

/// The text in the page panel's scale field.
String scaleField(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('page-scale')))
    .controller!
    .text;

Finder get entry => find.byKey(const Key('text-entry'));

/// The Text tool, a click at world [at] (a mouse when [mouse]), then
/// [text] typed into the entry without Enter.
Future<void> openEntry(WidgetTester tester, Vector2 at, String text,
    {bool mouse = false}) async {
  await press(tester, LogicalKeyboardKey.keyT);
  await tester.tapAt(globalOf(tester, at),
      kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch);
  await tester.pump();
  expect(entry, findsOneWidget, reason: 'premise: the entry is open');
  await tester.enterText(entry, text);
  await tester.pump();
  expect(FocusManager.instance.primaryFocus?.debugLabel, 'text-entry',
      reason: 'premise: the entry has the focus');
}

void main() {
  for (final saveAs in [false, true]) {
    final keys = saveAs ? 'Cmd+Shift+S' : 'Cmd+S';
    testWidgets(
        'ST1${saveAs ? 'b' : ''} a selected wall\'s thickness typed without '
        'Enter, then $keys: the bytes carry it, the commit is its own step, '
        'and the document is clean after '
        '(spec 12a D2, S-4, S-5, S-19; M-12a-11)', (tester) async {
      final files = FakeDocumentFiles();
      await pumpApp(tester, files);
      final session = sessionOf(tester);
      final doc = session.document;
      await aimCamera(tester, far);
      await drawWall(
          tester, far + Vector2(-1700, -300), far + Vector2(1300, 500));
      await drawWall(
          tester, far + Vector2(-800, 1400), far + Vector2(1800, 2200));
      final wall = wallsOf(doc).last;
      final params = doc.components.get<WallParams>(wall)!;
      expect(params.thickness, isNot(262.5), reason: 'premise');

      await clickAt(tester, far + Vector2(500, 1800));
      expect(viewOf(tester).selection.keys, [SelectionKey.root(wall)],
          reason: 'premise: the wall is selected');
      final thickness = find.byKey(const Key('wall-thickness'));
      await tester.tap(thickness);
      await tester.pump();
      await tester.enterText(thickness, '262.5');
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isA<PanelFieldFocusNode>(),
          reason: 'premise: typed, the field still focused');
      expect(doc.components.get<WallParams>(wall), params,
          reason: 'premise: nothing committed yet');
      expect(doc.commands.undoDepth, 2, reason: 'premise');
      expect(session.dirty.value, isTrue, reason: 'premise: dirty');

      files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
      expect(await (saveAs ? cmdShiftS(tester) : cmdS(tester)), isTrue);
      await tester.pump();

      expect(files.writes, hasLength(1));
      final saved = files.writes.single.bytes;
      expect(decoded(saved).components.get<WallParams>(wall),
          params.copyWith(thickness: 262.5),
          reason: 'the bytes carry the typed thickness');
      expect(saved, bytesOf(doc), reason: 'encoded at the committed state');
      expect(doc.components.get<WallParams>(wall)!.thickness, 262.5);
      expect(doc.commands.undoDepth, 3, reason: 'the commit is its own step');
      expect(session.dirty.value, isFalse, reason: 'clean after the save');
      expect(session.savedState, doc.commands.stateId);
      expect(canvasFocused(), isTrue, reason: 'handed back to the canvas');

      // One undo takes back the commit alone.
      await undoKey(tester);
      expect(doc.components.get<WallParams>(wall), params);
      expect(wallsOf(doc), hasLength(2));
      expect(session.dirty.value, isTrue);
    });
  }

  testWidgets(
      'ST2 a text entry with typed text, then Cmd+S: the bytes contain the '
      'text entity, committed as one step, and the document is clean after; '
      'the focus is back on the canvas (spec 12a D2, R-5; M-12a-11)',
      (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(-1500, 0), far + Vector2(1500, 900));
    await openEntry(tester, far + Vector2(-400, 1600), 'Kitchen');
    expect(textsOf(doc), isEmpty, reason: 'premise: not committed');
    expect(doc.commands.undoDepth, 1, reason: 'premise');

    files.scriptSaveLocation(name: 'plan.jetplan', location: '/p/plan');
    expect(await cmdS(tester), isTrue);
    await tester.pump();

    expect(files.writes, hasLength(1));
    final saved = files.writes.single.bytes;
    expect(textsOf(decoded(saved)), ['Kitchen'],
        reason: 'the bytes contain the text entity');
    expect(saved, bytesOf(doc));
    expect(textsOf(doc), ['Kitchen']);
    expect(doc.commands.undoDepth, 2, reason: 'one step');
    expect(entry, findsNothing, reason: 'the entry is closed');
    expect(session.dirty.value, isFalse, reason: 'clean after the save');
    expect(canvasFocused(), isTrue);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(viewOf(tester).tools.active, isA<LineTool>(),
        reason: 'the letters reach the shell again');
  });

  testWidgets(
      'ST3 the same through the toolbar on macOS with a mouse: an open entry '
      'leaves Save enabled, and a click on toolbar-save saves the typed text '
      '(spec 12a D2, D7, T-1, U-1; M-12a-22, M-12a-28)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(
        tester, far + Vector2(-900, -1200), far + Vector2(1600, -600));
    await openEntry(tester, far + Vector2(300, 700), 'Hall', mouse: true);
    expect(textsOf(doc), isEmpty, reason: 'premise: not committed');
    final save = find.byKey(const Key('toolbar-save'));
    expect(tester.widget<IconButton>(save).onPressed, isNotNull,
        reason: 'an open entry is not mid-shape: Save is enabled');

    files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
    await tester.tap(save, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.pump();

    expect(files.writes, hasLength(1));
    final saved = files.writes.single.bytes;
    expect(textsOf(decoded(saved)), ['Hall'],
        reason: 'the bytes contain the text entity');
    expect(saved, bytesOf(doc));
    expect(doc.commands.undoDepth, 2, reason: 'one step');
    expect(entry, findsNothing);
    expect(session.dirty.value, isFalse, reason: 'clean after the save');
    expect(canvasFocused(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
      'ST4 a page scale typed without Enter, then Cmd+S: nothing is '
      'committed, the bytes carry the stored scale, and the field shows it '
      'after (spec 12a D2, D14, T-13)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    final scale = find.byKey(const Key('page-scale'));

    // A stored scale that is not the default, submitted: one step, dirty.
    await tester.tap(scale);
    await tester.pump();
    await tester.enterText(scale, '125');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(scaleOf(doc), 125, reason: 'premise: submitted');
    expect(doc.commands.undoDepth, 1, reason: 'premise');
    expect(session.dirty.value, isTrue, reason: 'premise');

    await tester.tap(scale);
    await tester.pump();
    await tester.enterText(scale, '40');
    await tester.pump();
    expect(scaleField(tester), '40', reason: 'premise: typed');
    expect(FocusManager.instance.primaryFocus, isA<PanelFieldFocusNode>(),
        reason: 'premise: the field still focused');

    files.scriptSaveLocation(name: 'sheet.jetplan', location: '/p/sheet');
    expect(await cmdS(tester), isTrue);
    await tester.pump();

    expect(files.writes, hasLength(1));
    final saved = files.writes.single.bytes;
    expect(scaleOf(decoded(saved)), 125, reason: 'the stored scale is saved');
    expect(saved, bytesOf(doc));
    expect(scaleOf(doc), 125, reason: 'nothing committed');
    expect(doc.commands.undoDepth, 1);
    expect(scaleField(tester), panelNumberText(125),
        reason: 'the field shows the stored scale');
    expect(session.dirty.value, isFalse);
    expect(canvasFocused(), isTrue);
  });

  testWidgets(
      'ST5 a text entry ended by a mouse click on the tool palette or on a '
      'panel, or by a touch on a panel, is cancelled, and hands the focus '
      'back to the canvas: Cmd+S then saves (plan 12a Task 7; spec 05 D9, '
      '12a D6)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(
        tester, far + Vector2(-1300, 400), far + Vector2(1100, 1700));
    files.scriptSaveLocation(name: 'room.jetplan', location: '/p/room');
    await cmdS(tester);
    expect(files.writes, hasLength(1), reason: 'premise: titled');

    // A mouse on the palette and on a panel; a touch on the panel, which
    // on macOS ends the entry too (EditableText's own platform rule).
    for (final (i, (target, kind)) in [
      (find.byKey(const Key('tool-line')), PointerDeviceKind.mouse),
      (find.text('Page'), PointerDeviceKind.mouse),
      (find.text('Page'), PointerDeviceKind.touch),
    ].indexed) {
      final before = bytesOf(doc);
      await openEntry(tester, far + Vector2(-200.0 + 900 * i, 2400), 'Porch',
          mouse: true);
      await tester.tap(target, kind: kind);
      await tester.pump();
      expect(entry, findsNothing, reason: '$target $kind: the entry ended');
      expect(bytesOf(doc), before,
          reason: '$target $kind: cancelled, not committed');
      expect(canvasFocused(), isTrue,
          reason: '$target $kind: the canvas has it');

      expect(await cmdS(tester), isTrue, reason: '$target $kind');
      await tester.pump();
      expect(files.writes, hasLength(2 + i),
          reason: '$target $kind: Cmd+S saves');
      expect(files.writes.last.location, '/p/room');
      expect(files.writes.last.bytes, before);
      await press(tester, LogicalKeyboardKey.escape);
    }
    expect(session.dirty.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
      'ST6 a touch outside the entry on Android keeps it open with the focus, '
      'as EditableText\'s default does, and a mouse click ends it: the '
      'hand-back drops the focus only where the default would '
      '(plan 12a Task 7)', (tester) async {
    await pumpApp(tester, FakeDocumentFiles());
    final doc = sessionOf(tester).document;
    await aimCamera(tester, far);
    await openEntry(tester, far + Vector2(-600, 1100), 'Stair');
    await tester.tap(find.text('Page'));
    await tester.pump();
    expect(entry, findsOneWidget, reason: 'still open');
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'text-entry');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(textsOf(doc), ['Stair'], reason: 'Enter still commits it');

    // A mouse on Android is not a touch: the entry ends, cancelled, and
    // the canvas has the focus.
    final before = bytesOf(doc);
    await openEntry(tester, far + Vector2(700, 1900), 'Porch', mouse: true);
    await tester.tap(find.text('Page'), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(entry, findsNothing, reason: 'a mouse click ends the entry');
    expect(bytesOf(doc), before, reason: 'cancelled, not committed');
    expect(canvasFocused(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'ST7 a page scale typed and left by Tab, not by a tap, still shows the '
      'typed text; Cmd+S re-syncs it to the stored scale all the same, with '
      'nothing committed (plan 12a Task 7 deviation 2; spec 12a D2, D14)',
      (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    final scale = find.byKey(const Key('page-scale'));
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(-1100, 200), far + Vector2(1700, 900));
    final stored = scaleOf(doc);

    await tester.tap(scale);
    await tester.pump();
    await tester.enterText(scale, '40');
    await tester.pump();
    await press(tester, LogicalKeyboardKey.tab);
    expect(
        FocusManager.instance.primaryFocus, isNot(isA<PanelFieldFocusNode>()),
        reason: 'premise: Tab left the field');
    expect(scaleField(tester), '40', reason: 'premise: the text stays');
    expect(scaleOf(doc), stored, reason: 'premise: nothing committed');

    files.scriptSaveLocation(name: 'tab.jetplan', location: '/p/tab');
    expect(await cmdS(tester), isTrue);
    await tester.pump();

    expect(files.writes, hasLength(1));
    expect(scaleOf(decoded(files.writes.single.bytes)), stored);
    expect(scaleField(tester), panelNumberText(stored),
        reason: 'the field shows the stored scale');
    expect(doc.commands.undoDepth, 1, reason: 'nothing committed');
    expect(session.dirty.value, isFalse);
  });

  testWidgets(
      'ST8 an open text entry with nothing typed, then Cmd+S: the settle '
      'closes it, commits nothing, and the canvas has the focus (plan 12a '
      'Task 7 deviation 6; spec 12a D2, R-5)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(-1400, -700), far + Vector2(900, 400));
    await openEntry(tester, far + Vector2(250, 1300), '');
    final before = bytesOf(doc);

    files.scriptSaveLocation(name: 'empty.jetplan', location: '/p/empty');
    expect(await cmdS(tester), isTrue);
    await tester.pump();

    expect(entry, findsNothing, reason: 'the settle closed the entry');
    expect(canvasFocused(), isTrue);
    expect(files.writes.single.bytes, before, reason: 'nothing committed');
    expect(textsOf(doc), isEmpty);
    expect(doc.commands.undoDepth, 1);
    expect(session.dirty.value, isFalse);
  });
}
