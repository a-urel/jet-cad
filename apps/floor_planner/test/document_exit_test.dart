// Spec 12a D11 (plan 12a Task 8): the app's exit request -- Cmd+Q, Quit,
// and on macOS the window's close button -- driven through the binding, so
// the host's listener is registered and disposed for real (S-18). In order
// (T-7): busy cancels with no second dialog; pending input is settled; a
// clean document exits; a dirty one asks Save / Don't Save / Cancel. A
// shape part-way does not block (U-7). And the web's exit guard is armed
// exactly while the document is dirty, across a swap.
import 'dart:ui' show AppExitResponse;

import 'package:floor_planner/panel_focus.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';
import 'support/fake_exit_guard.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(44321.75, -36543.25);

Finder get dialog => find.byKey(const Key('replace-dialog'));

/// The launch document edited through the Wall tool far from the origin
/// under a rotated camera, the shape ended, then saved as `/p/hall`:
/// titled, clean, with history.
Future<DraftDocument> titledClean(
    WidgetTester tester, FakeDocumentFiles files) async {
  final session = sessionOf(tester);
  final doc = session.document;
  await aimCamera(tester, far);
  await drawWall(tester, far + Vector2(-1500, -200), far + Vector2(1500, 400));
  files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
  await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
  await tester.pump();
  expect(files.writes, isNotEmpty, reason: 'premise: saved');
  expect(session.dirty.value, isFalse, reason: 'premise: clean');
  expect(doc.commands.undoDepth, 1, reason: 'premise: history');
  expect(session.name, 'hall', reason: 'premise: titled');
  return doc;
}

/// [titledClean], then one more wall: dirty, with history.
Future<DraftDocument> titledDirty(
    WidgetTester tester, FakeDocumentFiles files) async {
  final doc = await titledClean(tester, files);
  await drawWall(tester, far + Vector2(-400, 1600), far + Vector2(2200, 1600));
  expect(sessionOf(tester).dirty.value, isTrue, reason: 'premise: dirty');
  expect(doc.commands.undoDepth, 2, reason: 'premise');
  return doc;
}

/// Asks the app to exit, as the engine does for Cmd+Q, and pumps a frame;
/// for a request that must answer without asking: it fails, rather than
/// waits forever, if the request put up a dialog.
Future<AppExitResponse> requestExit(WidgetTester tester) async {
  final before = tester.widgetList(dialog).length;
  final response = tester.binding.handleRequestAppExit();
  await tester.pump();
  expect(tester.widgetList(dialog).length, before,
      reason: 'the request asked nothing');
  return response;
}

void main() {
  testWidgets(
      'EX1 a clean document exits with no dialog: the launch document, one '
      'saved as just before, and one saved in place (spec 12a D11, S-18; '
      'M-12a-2)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);

    // The launch document, never edited.
    expect(await requestExit(tester), AppExitResponse.exit);
    expect(dialog, findsNothing);

    // Edited, then Cmd+S (a Save As), then the exit: no dialog. No premise
    // reads the save point in between, so the exit is what sees it.
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(
        tester, far + Vector2(-1500, -200), far + Vector2(1500, 400));
    files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'premise: written');
    expect(await requestExit(tester), AppExitResponse.exit,
        reason: 'saved, so nothing to ask');

    // Edited again and saved in place: the same.
    await drawWall(tester, far + Vector2(0, -2000), far + Vector2(0, 2000));
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.writes.last.location, '/p/hall', reason: 'premise: in place');
    expect(await requestExit(tester), AppExitResponse.exit,
        reason: 'saved in place, so nothing to ask');
    expect(identical(session.document, doc), isTrue);
    expect(session.busy.value, isFalse);
  });

  testWidgets(
      'EX2 a dirty document asks: Cancel (and Escape) cancel and keep '
      'everything; Save that fails cancels; Don\'t Save exits without '
      'writing; Save that succeeds '
      'writes the document\'s bytes and exits (spec 12a D11)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);
    final writes = files.writes.length;

    void expectKept(String reason) {
      expect(identical(session.document, doc), isTrue, reason: reason);
      expect(doc.commands.isDisposed, isFalse, reason: reason);
      expect(doc.commands.undoDepth, 2, reason: reason);
      expect(session.dirty.value, isTrue, reason: reason);
      expect(session.busy.value, isFalse, reason: reason);
      expect(dialog, findsNothing, reason: reason);
    }

    // Cancel.
    var response = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(dialog, findsOneWidget);
    expect(session.busy.value, isTrue, reason: 'busy under the dialog');
    await answerReplace(tester, 'replace-cancel');
    noDialog(tester);
    expect(await response, AppExitResponse.cancel);
    expectKept('Cancel');

    // Escape.
    response = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(dialog, findsOneWidget);
    await press(tester, LogicalKeyboardKey.escape);
    await tester.pump();
    expect(dialog, findsNothing, reason: 'Escape answered it');
    noDialog(tester);
    expect(await response, AppExitResponse.cancel);
    expectKept('Escape');
    expect(files.writes, hasLength(writes), reason: 'nothing written');

    // Save, and the write fails: the error, then cancel.
    files.failNextWrite(StateError('the disk is full'));
    response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    expect(find.byKey(const Key('document-error')), findsOneWidget);
    await dismissError(tester);
    noDialog(tester);
    expect(await response, AppExitResponse.cancel);
    expectKept('a failed save');
    expect(files.writes, hasLength(writes + 1), reason: 'it was tried');

    // Don't Save: exit, and nothing is written.
    response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-discard');
    noDialog(tester);
    expect(await response, AppExitResponse.exit);
    expect(files.writes, hasLength(writes + 1));
    expect(identical(session.document, doc), isTrue, reason: 'not replaced');
    expect(session.busy.value, isFalse);

    // Save, and it succeeds: the bytes, then exit.
    final before = bytesOf(doc);
    response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    expect(await response, AppExitResponse.exit);
    expect(files.writes.last.location, '/p/hall');
    expect(files.writes.last.bytes, before);
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'EX3 an untitled dirty document: Save runs Save As; a cancelled panel '
      'cancels the exit (spec 12a D9, D11)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(-2500, 1200));
    expect(session.dirty.value, isTrue, reason: 'premise');

    files.scriptSaveCancel();
    var response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    expect(await response, AppExitResponse.cancel);
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, isEmpty);
    expect(session.dirty.value, isTrue);
    expect(session.busy.value, isFalse);

    files.scriptSaveLocation(name: 'porch.jetplan', location: '/p/porch');
    response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    expect(await response, AppExitResponse.exit);
    expect(files.writes.single.location, '/p/porch');
    expect(files.writes.single.bytes, bytesOf(doc));
    expect(session.dirty.value, isFalse);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'EX4 busy cancels at once with no second dialog: while a New asks, '
      'while a save is held, and while the exit\'s own save is held; an '
      'edit during that held save asks again (spec 12a D10, D11, S-17, T-8)',
      (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);

    // A New's dialog is up.
    final newing = host.newFlow();
    await tester.pump();
    expect(dialog, findsOneWidget, reason: 'premise');
    expect(await requestExit(tester), AppExitResponse.cancel);
    expect(dialog, findsOneWidget, reason: 'no second dialog');
    await answerReplace(tester, 'replace-cancel');
    noDialog(tester);
    await newing;

    // A Cmd+S write is held.
    files.holdWrites = true;
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    expect(files.heldWrites, hasLength(1), reason: 'premise');
    expect(await requestExit(tester), AppExitResponse.cancel);
    expect(dialog, findsNothing);
    files.heldWrites.last.complete();
    await tester.pump();
    await tester.pump();
    expect(session.dirty.value, isFalse, reason: 'premise: saved');

    // The exit's own Save is held; an edit lands meanwhile.
    await drawWall(tester, far + Vector2(2000, -900), far + Vector2(2000, 900));
    final before = bytesOf(doc);
    final response = tester.binding.handleRequestAppExit();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    expect(files.heldWrites, hasLength(2), reason: 'premise: held');
    expect(await requestExit(tester), AppExitResponse.cancel,
        reason: 'a second request while the first is saving');
    expect(dialog, findsNothing);
    await drawWall(
        tester, far + Vector2(-2000, -900), far + Vector2(-2000, 900));
    files.heldWrites.last.complete();
    await tester.pump();
    await tester.pump();
    expect(files.writes.last.bytes, before, reason: 'the pre-edit bytes');
    expect(dialog, findsOneWidget, reason: 'dirty again: asked again');
    expect(session.busy.value, isTrue);
    await answerReplace(tester, 'replace-discard');
    noDialog(tester);
    expect(await response, AppExitResponse.exit);
    expect(session.busy.value, isFalse);
  });

  testWidgets(
      'EX5 a clean document with a Selection panel value typed and not '
      'submitted: the exit settles first, so the value is committed and the '
      'dialog appears; Cancel keeps it (spec 12a D2, D11, T-7; M-12a-25)',
      (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledClean(tester, files);
    final wall = wallsOf(doc).single;
    final params = doc.components.get<WallParams>(wall)!;
    expect(params.thickness, isNot(212.5), reason: 'premise');
    await clickAt(tester, far + Vector2(0, 100));
    expect(viewOf(tester).selection.keys, [SelectionKey.root(wall)],
        reason: 'premise: the wall is selected');
    final field = find.byKey(const Key('wall-thickness'));
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, '212.5');
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isA<PanelFieldFocusNode>(),
        reason: 'premise: typed, the field focused');
    expect(doc.components.get<WallParams>(wall), params,
        reason: 'premise: not committed');
    expect(session.dirty.value, isFalse, reason: 'premise: clean');

    final response = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(dialog, findsOneWidget, reason: 'the typed value made it dirty');
    expect(doc.components.get<WallParams>(wall),
        params.copyWith(thickness: 212.5));
    expect(doc.commands.undoDepth, 2, reason: 'the commit is its own step');
    await answerReplace(tester, 'replace-cancel');
    noDialog(tester);
    expect(await response, AppExitResponse.cancel);
    expect(doc.components.get<WallParams>(wall)!.thickness, 212.5);
    expect(session.dirty.value, isTrue);
  });

  testWidgets(
      'EX6 a shape part-way does not block the exit (spec 12a U-7): clean '
      'with a Wall part-way exits; a Wall chain with a wall down asks',
      (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    await titledClean(tester, files);
    final view = viewOf(tester);

    await press(tester, LogicalKeyboardKey.keyW);
    await clickAt(tester, far + Vector2(-900, -2600));
    expect(view.tools.active.isMidShape, isTrue, reason: 'premise');
    expect(session.dirty.value, isFalse, reason: 'premise: nothing placed');
    expect(await requestExit(tester), AppExitResponse.exit);
    expect(dialog, findsNothing);

    await clickAt(tester, far + Vector2(1900, -2600));
    expect(view.tools.active.isMidShape, isTrue,
        reason: 'premise: the chain goes on');
    expect(session.dirty.value, isTrue, reason: 'premise: a wall is down');
    final response = tester.binding.handleRequestAppExit();
    await tester.pump();
    expect(dialog, findsOneWidget);
    await answerReplace(tester, 'replace-discard');
    noDialog(tester);
    expect(await response, AppExitResponse.exit);
  });

  testWidgets(
      'EX7 the listener goes with the host: a dirty document, the app '
      'removed, then an exit request exits with nothing asked and no error '
      '(spec 12a D11, S-18)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    await titledDirty(tester, files);
    await tester.pumpWidget(const SizedBox());
    expect(await requestExit(tester), AppExitResponse.exit);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'EG1 the exit guard is armed exactly while the document is dirty: '
      'edit, undo, redo, a web-style save, and across a New and an Open '
      'sample; disposed with the host (spec 12a D9, D11)', (tester) async {
    final files = FakeDocumentFiles(writesInPlace: false);
    final guard = FakeExitGuard();
    final host = await pumpApp(tester, files, exitGuard: guard);
    final session = sessionOf(tester);
    expect(guard.armings, [false], reason: 'clean at launch');

    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(2400, 300));
    expect(guard.armings, [false, true], reason: 'edit');
    await undoKey(tester);
    expect(guard.armings, [false, true, false], reason: 'undo');
    await tester.tap(find.byKey(const Key('toolbar-redo')));
    await tester.pump();
    expect(guard.armings, [false, true, false, true], reason: 'redo');
    files.scriptSaveLocation(name: 'deck.jetplan', location: 'deck.jetplan');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(guard.isArmed, isFalse, reason: 'saved (downloaded)');
    expect(guard.armings, hasLength(5));

    // A titled web document's Save downloads without asking; clean again.
    await drawWall(tester, far + Vector2(0, 1500), far + Vector2(2400, 1500));
    expect(guard.isArmed, isTrue);
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(1), reason: 'no second ask');
    expect(files.writes, hasLength(2));
    expect(guard.isArmed, isFalse);

    // Across a swap: dirty, New (Don't Save) disarms; the new document's
    // edits arm it again.
    await drawWall(tester, far + Vector2(0, 3000), far + Vector2(2400, 3000));
    expect(guard.isArmed, isTrue);
    await discardAndRun(tester, host.newFlow());
    expect(guard.isArmed, isFalse, reason: 'the New document is clean');
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(-2400, 300));
    expect(guard.isArmed, isTrue, reason: 'the new document\'s edit');
    await undoKey(tester);
    expect(guard.isArmed, isFalse, reason: 'the new document\'s undo');
    await drawWall(tester, far, far + Vector2(-2400, -300));
    await discardAndRun(tester, host.openSampleFlow());
    expect(guard.isArmed, isFalse, reason: 'the sample is clean');
    expect(
        guard.armings,
        [
          false, true, false, true, false, // launch, edit, undo, redo, save
          true, false, // edit, save
          true, false, // edit, New
          true, false, // edit, undo
          true, false, // edit, Open sample
        ],
        reason: 'set only when dirty changes');
    expect(session.dirty.value, isFalse);

    expect(guard.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(guard.disposed, isTrue, reason: 'disposed with the host');
  });
}
