// Spec 12a D5, D9 (plan 12a Task 5): the save point is the state the bytes
// were encoded at; a failed or cancelled save leaves it and clears busy;
// an untitled Save asks where, a titled one writes in place (macOS) or
// downloads under its name without asking (web); the web's name prompt.
import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';

final Vector2 far = Vector2(-38765.5, 29345.75);

List<int> sampleBytes() {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  return bytesOf(startupPlan(m));
}

/// The app with the sample opened from `flat.jetplan` (at [location]),
/// then edited through the Wall tool far from the origin: titled, dirty,
/// one step of history.
Future<DocumentHostState> titledDirty(
    WidgetTester tester, FakeDocumentFiles files, Object? location) async {
  final host = await pumpApp(tester, files);
  files.scriptOpen(
      name: 'flat.jetplan', bytes: sampleBytes(), location: location);
  await host.openFlow();
  await tester.pump();
  await aimCamera(tester, far);
  await drawWall(tester, far, far + Vector2(2600, -900));
  final session = sessionOf(tester);
  expect(session.name, 'flat', reason: 'premise: titled');
  expect(session.document.commands.undoDepth, 1, reason: 'premise');
  expect(session.dirty.value, isTrue, reason: 'premise: dirty');
  return host;
}

void main() {
  for (final inPlace in [true, false]) {
    testWidgets(
        'DS1 the save point is the encoded state: an edit while the write is '
        'held leaves the document dirty, the bytes are the pre-edit ones, '
        'and undoing that edit is clean (writesInPlace: $inPlace; spec 12a '
        'D5, S-2; M-12a-13)', (tester) async {
      final files = FakeDocumentFiles(writesInPlace: inPlace);
      final host = await titledDirty(tester, files, inPlace ? '/p/flat' : null);
      final session = sessionOf(tester);
      final doc = session.document;
      final encoded = bytesOf(doc);

      files.holdWrites = true;
      final saving = host.saveStep();
      await tester.pump();
      expect(files.writes, hasLength(1));
      expect(files.writes.single.bytes, encoded);
      expect(
          files.writes.single.location, inPlace ? '/p/flat' : 'flat.jetplan');
      expect(files.saveLocationCalls, isEmpty, reason: 'titled: no ask');
      expect(session.busy.value, isTrue);

      // The canvas stays live while the write is pending.
      await drawWall(
          tester, far + Vector2(0, 1500), far + Vector2(-1800, 2900));
      expect(doc.commands.undoDepth, 2, reason: 'premise: edited meanwhile');
      files.heldWrites.single.complete();
      await tester.pump();
      expect(await saving, isTrue);
      await tester.pump();
      expect(session.busy.value, isFalse);
      expect(session.dirty.value, isTrue,
          reason: 'the edit made during the write is not saved');
      expect(titleOf(tester), '• flat — jet-cad');
      await undoKey(tester);
      expect(session.dirty.value, isFalse,
          reason: 'the saved state is the one before that edit');
    });
  }

  testWidgets(
      'DS2 a failed write from dirty: the dialog, still dirty, busy '
      'cleared; then a save writes and is clean (spec 12a D5, S-13, S-21; '
      'M-12a-3, M-12a-17)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await titledDirty(tester, files, '/p/flat');
    final session = sessionOf(tester);
    final doc = session.document;

    files.failNextWrite(Exception('the disk is full'));
    final failing = host.saveStep();
    await tester.pump();
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'the write was tried');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        'Could not save flat.jetplan');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-text'))).data,
        'Exception: the disk is full');
    expect(session.busy.value, isTrue, reason: 'busy under the dialog');
    await dismissError(tester);
    expect(await failing, isFalse);
    expect(session.dirty.value, isTrue, reason: 'the save point stays');
    expect(session.busy.value, isFalse, reason: 'busy cleared');
    expect(doc.commands.undoDepth, 1);

    final retry = host.saveStep();
    await tester.pump();
    expect(await retry, isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, bytesOf(doc));
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);
  });

  testWidgets(
      'DS3 a cancelled Save As from dirty: no write, no dialog, still dirty '
      'and untitled; on a titled document too (spec 12a D5, D9; M-12a-3)',
      (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(-2100, 400));
    expect(session.dirty.value, isTrue, reason: 'premise');

    files.scriptSaveCancel();
    expect(await host.saveStep(), isFalse, reason: 'untitled: Save As');
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, isEmpty);
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(session.dirty.value, isTrue);
    expect(session.name, 'Untitled');
    expect(session.busy.value, isFalse);

    // Titled now; a cancelled Save As keeps its name, location and dirt.
    files.scriptSaveLocation(name: 'a.jetplan', location: '/p/a');
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    await drawWall(tester, far + Vector2(0, 900), far + Vector2(1300, 900));
    expect(session.dirty.value, isTrue, reason: 'premise');
    files.scriptSaveCancel();
    expect(await host.saveAsStep(), isFalse);
    await tester.pump();
    expect(files.saveLocationCalls,
        ['Untitled.jetplan', 'Untitled.jetplan', 'a.jetplan']);
    expect(files.writes, hasLength(1));
    expect(session.dirty.value, isTrue);
    expect((session.name, session.location), ('a', '/p/a'));
  });

  testWidgets(
      'DS4 an untitled Save asks where, names the document after the file '
      'and saves there from then on; Save As asks again and moves it (spec '
      '12a D9)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(1700, 1700));
    final doc = session.document;

    files.scriptSaveLocation(name: 'house.jetplan', location: '/p/house');
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes.single.location, '/p/house');
    expect(files.writes.single.name, 'house.jetplan');
    expect(files.writes.single.bytes, bytesOf(doc));
    expect((session.name, session.fileName, session.location),
        ('house', 'house.jetplan', '/p/house'));
    expect(session.dirty.value, isFalse);
    expect(titleOf(tester), 'house — jet-cad');

    await drawWall(tester, far + Vector2(0, -900), far + Vector2(900, -900));
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(1), reason: 'no second ask');
    expect(files.writes.last.location, '/p/house');
    expect(session.dirty.value, isFalse);

    files.scriptSaveLocation(name: 'barn.jetplan', location: '/p/barn');
    expect(await host.saveAsStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls.last, 'house.jetplan');
    expect(files.writes.last.location, '/p/barn');
    expect((session.name, session.location), ('barn', '/p/barn'));
    expect(titleOf(tester), 'barn — jet-cad');
  });

  testWidgets(
      'DS5 web: Save on a titled document downloads under its name without '
      'asking and marks it clean (spec 12a D9, decision 9)', (tester) async {
    final files = FakeDocumentFiles(writesInPlace: false);
    final host = await titledDirty(tester, files, null);
    final session = sessionOf(tester);
    expect(session.location, isNull, reason: 'premise: the web gives none');
    final saving = host.saveStep();
    await tester.pump();
    await tester.pump();
    expect(files.saveLocationCalls, isEmpty, reason: 'no name prompt');
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(await saving, isTrue);
    await tester.pump();
    // The write takes the file's name as its location (Task 4 review n-1):
    // the web download ignores it, and the interface wants one.
    expect(files.writes.single.location, 'flat.jetplan');
    expect(files.writes.single.name, 'flat.jetplan');
    expect(files.writes.single.bytes, bytesOf(session.document));
    expect(session.dirty.value, isFalse);
    expect(session.name, 'flat');
  });

  testWidgets(
      'DS6 the web name prompt starts from the suggestion and returns the '
      'typed name on Save or Enter, null on Cancel (spec 12a D9, T-12)',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    })));

    Future<String?> ask() =>
        showDocumentNamePrompt(context, 'Untitled.jetplan');

    var answer = ask();
    await tester.pump();
    await tester.pump();
    final field = find.byKey(const Key('name-prompt-field'));
    expect(
        tester.widget<TextField>(field).controller!.text, 'Untitled.jetplan');
    await tester.enterText(field, 'Kitchen');
    await tester.tap(find.byKey(const Key('name-prompt-save')));
    await tester.pump();
    expect(await answer, 'Kitchen');

    answer = ask();
    await tester.pump();
    await tester.pump();
    await tester.enterText(field, 'Hall');
    await tester.tap(find.byKey(const Key('name-prompt-cancel')));
    await tester.pump();
    expect(await answer, isNull);

    answer = ask();
    await tester.pump();
    await tester.pump();
    await tester.enterText(field, 'Bath');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(await answer, 'Bath');
    expect(find.byKey(const Key('name-prompt')), findsNothing);
  });
}
