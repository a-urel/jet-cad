// Ported from apps/floor_planner/test/document_save_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "document_save_test.dart"): DS1-DS7, all PORT. The save point is the
// state the bytes were encoded at (`save()` then `markSaved()`); a failed or
// cancelled save leaves it and clears busy; an untitled Save asks where, a
// titled one writes in place (macOS) or downloads under its name without
// asking (web); the web's name prompt; a Save As whose panel throws shows
// the error and changes nothing. Library half of DS1: packages/
// jet_cad_2d_plan/test/controller/plan_controller_test.dart C4.
import 'package:architecture_demo/document_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_fakes.dart';
import 'support/app_rig.dart';

final Vector2 far = Vector2(-38765.5, 29345.75);

/// The app with the sample opened from `flat.jetplan` (at [location]),
/// then edited through the Wall tool far from the origin: titled, dirty,
/// one step of history.
Future<AppRig> titledDirty(
    WidgetTester tester, FakeDocumentFiles files, Object? location) async {
  final rig = await pumpApp(tester, files: files);
  files.scriptOpen(
      name: 'flat.jetplan', bytes: sampleBytes(), location: location);
  await rig.host.openFlow();
  await tester.pump();
  await aimCamera(tester, rig.controller, far);
  await drawWall(tester, rig.controller, far, far + Vector2(2600, -900));
  expect(rig.session.name, 'flat', reason: 'premise: titled');
  expect(rig.controller.document.commands.undoDepth, 1, reason: 'premise');
  expect(rig.controller.dirty.value, isTrue, reason: 'premise: dirty');
  return rig;
}

void main() {
  for (final inPlace in [true, false]) {
    testWidgets(
        'DS1 the save point is the encoded state: an edit while the write is '
        'held leaves the plan dirty, the bytes are the pre-edit ones, and '
        'undoing that edit is clean (writesInPlace: $inPlace; spec 12a D5, '
        'S-2; M-12a-13)', (tester) async {
      final files = FakeDocumentFiles(writesInPlace: inPlace);
      final rig = await titledDirty(tester, files, inPlace ? '/p/flat' : null);
      final c = rig.controller;
      final encoded = bytesOf(c);

      files.holdWrites = true;
      final saving = rig.host.saveStep();
      await tester.pump();
      expect(files.writes, hasLength(1));
      expect(files.writes.single.bytes, encoded);
      expect(
          files.writes.single.location, inPlace ? '/p/flat' : 'flat.jetplan');
      expect(files.saveLocationCalls, isEmpty, reason: 'titled: no ask');
      expect(rig.session.busy.value, isTrue);

      // The canvas stays live while the write is pending.
      await drawWall(
          tester, c, far + Vector2(0, 1500), far + Vector2(-1800, 2900));
      expect(c.document.commands.undoDepth, 2,
          reason: 'premise: edited meanwhile');
      files.heldWrites.single.complete();
      await tester.pump();
      expect(await saving, isTrue);
      await tester.pump();
      expect(rig.session.busy.value, isFalse);
      expect(c.dirty.value, isTrue,
          reason: 'the edit made during the write is not saved');
      expect(titleOf(tester), '• flat — jet-cad');
      await undoKey(tester);
      expect(c.dirty.value, isFalse,
          reason: 'the saved state is the one before that edit');
    });
  }

  testWidgets(
      'DS2 a failed write from dirty: the dialog, still dirty, busy '
      'cleared; then a save writes and is clean (spec 12a D5, S-13, S-21; '
      'M-12a-3, M-12a-17)', (tester) async {
    final files = FakeDocumentFiles();
    final rig = await titledDirty(tester, files, '/p/flat');
    final c = rig.controller;
    final doc = c.document;

    files.failNextWrite(Exception('the disk is full'));
    final failing = rig.host.saveStep();
    await tester.pump();
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'the write was tried');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        'Could not save flat.jetplan');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-text'))).data,
        'Exception: the disk is full');
    expect(rig.session.busy.value, isTrue, reason: 'busy under the dialog');
    await dismissError(tester);
    expect(await failing, isFalse);
    expect(c.dirty.value, isTrue, reason: 'the save point stays');
    expect(rig.session.busy.value, isFalse, reason: 'busy cleared');
    expect(doc.commands.undoDepth, 1);

    final retry = rig.host.saveStep();
    await tester.pump();
    expect(await retry, isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, bytesOf(c));
    expect(c.dirty.value, isFalse);
    expect(rig.session.busy.value, isFalse);
  });

  testWidgets(
      'DS3 a cancelled Save As from dirty: no write, no dialog, still dirty '
      'and untitled; on a titled plan too (spec 12a D5, D9; M-12a-3)',
      (tester) async {
    final files = FakeDocumentFiles();
    final rig = await pumpApp(tester, files: files);
    final c = rig.controller;
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(-2100, 400));
    expect(c.dirty.value, isTrue, reason: 'premise');

    files.scriptSaveCancel();
    expect(await rig.host.saveStep(), isFalse, reason: 'untitled: Save As');
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, isEmpty);
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(c.dirty.value, isTrue);
    expect(rig.session.name, 'Untitled');
    expect(rig.session.busy.value, isFalse);

    // Titled now; a cancelled Save As keeps its name, location and dirt.
    files.scriptSaveLocation(name: 'a.jetplan', location: '/p/a');
    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    await drawWall(tester, c, far + Vector2(0, 900), far + Vector2(1300, 900));
    expect(c.dirty.value, isTrue, reason: 'premise');
    files.scriptSaveCancel();
    expect(await rig.host.saveAsStep(), isFalse);
    await tester.pump();
    expect(files.saveLocationCalls,
        ['Untitled.jetplan', 'Untitled.jetplan', 'a.jetplan']);
    expect(files.writes, hasLength(1));
    expect(c.dirty.value, isTrue);
    expect((rig.session.name, rig.session.location), ('a', '/p/a'));
  });

  testWidgets(
      'DS4 an untitled Save asks where, names the plan after the file and '
      'saves there from then on; Save As asks again and moves it (spec 12a '
      'D9)', (tester) async {
    final files = FakeDocumentFiles();
    final rig = await pumpApp(tester, files: files);
    final c = rig.controller;
    final session = rig.session;
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(1700, 1700));

    files.scriptSaveLocation(name: 'house.jetplan', location: '/p/house');
    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes.single.location, '/p/house');
    expect(files.writes.single.name, 'house.jetplan');
    expect(files.writes.single.bytes, bytesOf(c));
    expect((session.name, session.fileName, session.location),
        ('house', 'house.jetplan', '/p/house'));
    expect(c.dirty.value, isFalse);
    expect(titleOf(tester), 'house — jet-cad');

    await drawWall(tester, c, far + Vector2(0, -900), far + Vector2(900, -900));
    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(1), reason: 'no second ask');
    expect(files.writes.last.location, '/p/house');
    expect(c.dirty.value, isFalse);

    files.scriptSaveLocation(name: 'barn.jetplan', location: '/p/barn');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    expect(files.saveLocationCalls.last, 'house.jetplan');
    expect(files.writes.last.location, '/p/barn');
    expect((session.name, session.location), ('barn', '/p/barn'));
    expect(titleOf(tester), 'barn — jet-cad');
  });

  testWidgets(
      'DS5 web: Save on a titled plan downloads under its name without '
      'asking and marks it clean (spec 12a D9, decision 9)', (tester) async {
    final files = FakeDocumentFiles(writesInPlace: false);
    final rig = await titledDirty(tester, files, null);
    final c = rig.controller;
    expect(rig.session.location, isNull, reason: 'premise: the web gives none');
    final saving = rig.host.saveStep();
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
    expect(files.writes.single.bytes, bytesOf(c));
    expect(c.dirty.value, isFalse);
    expect(rig.session.name, 'flat');
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

  testWidgets(
      'DS7 a Save As whose panel throws, from a titled dirty plan: the '
      'dialog, false, still dirty and titled, no write, busy cleared (spec '
      '12a D5, D8, S-21; Task 5 deviation 5)', (tester) async {
    final files = FakeDocumentFiles();
    final rig = await titledDirty(tester, files, '/p/flat');
    final c = rig.controller;
    final session = rig.session;
    final doc = c.document;

    files.scriptSaveLocationThrow(StateError('the panel failed'));
    final saving = rig.host.saveAsStep();
    await tester.pump();
    await tester.pump();
    expect(files.saveLocationCalls, ['flat.jetplan']);
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        'Could not save flat');
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-text'))).data,
        'Bad state: the panel failed');
    expect(session.busy.value, isTrue, reason: 'busy under the dialog');
    await dismissError(tester);
    expect(await saving, isFalse);
    expect(find.byKey(const Key('document-error')), findsNothing);
    expect(files.writes, isEmpty);
    expect(c.dirty.value, isTrue, reason: 'the save point stays');
    expect(session.busy.value, isFalse, reason: 'busy cleared');
    expect(identical(c.document, doc), isTrue);
    expect(doc.commands.undoDepth, 1);
    expect((session.name, session.fileName, session.location),
        ('flat', 'flat.jetplan', '/p/flat'));
    expect(titleOf(tester), '• flat — jet-cad');
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'DS8 the app unmounted during a held write: the flow ends without '
      'touching the disposed session (no error)', (tester) async {
    // Mutation M-DS8: `_flow`'s finally sets `busy.value = false` without
    // the isDisposed check: "A ValueNotifier<bool> was used after being
    // disposed".
    final files = FakeDocumentFiles(writesInPlace: true);
    final rig = await titledDirty(tester, files, '/p/flat');
    final session = rig.session;
    files.holdWrites = true;
    final saving = rig.host.saveStep();
    await tester.pump();
    expect(session.busy.value, isTrue, reason: 'premise: in flight');

    await tester.pumpWidget(const SizedBox());
    expect(session.isDisposed, isTrue, reason: 'premise: torn down');
    files.heldWrites.single.complete();
    await saving;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
