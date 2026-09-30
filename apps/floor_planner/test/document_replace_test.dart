// Spec 12a D10 (plan 12a Task 8): New, Open and Open sample ask Save /
// Don't Save / Cancel before they replace a dirty document -- for Open,
// before the picker -- and replace a clean one without asking. Save runs
// the Save step inside the flow's busy span: a cancelled or failed save
// keeps everything, and a save that succeeded while an edit landed asks
// again (T-8). While the nested save is held, nothing else runs.
import 'package:floor_planner/panel_focus.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(-39876.25, 33456.5);

/// The sample's bytes, built here with a measurer of the test's own.
List<int> sampleBytes() {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  return bytesOf(startupPlan(m));
}

Finder get dialog => find.byKey(const Key('replace-dialog'));

/// Whether the toolbar button [id] is enabled, as built.
bool enabled(WidgetTester tester, String id) =>
    tester.widget<IconButton>(find.byKey(Key('toolbar-$id'))).onPressed != null;

const List<String> kIds = [
  'new',
  'open',
  'open-sample',
  'save',
  'save-as',
  'undo',
  'redo',
];

/// The app's document, titled and dirty with history: the sample opened
/// from `/p/plan` as `plan.jetplan`, then a wall drawn through the Wall
/// tool far from the origin under a rotated camera, the shape ended (spec
/// 12a Testing, S-13, T-6). The session must be clean on entry, so the
/// Open asks nothing.
Future<DraftDocument> titledDirty(WidgetTester tester, FakeDocumentFiles files,
    {Vector2? at}) async {
  final session = sessionOf(tester);
  expect(session.dirty.value, isFalse, reason: 'premise: Open asks nothing');
  files.scriptOpen(
      name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
  await hostOf(tester).openFlow();
  await tester.pump();
  final doc = session.document;
  final depth = doc.commands.undoDepth;
  final p = at ?? far;
  await aimCamera(tester, p);
  await drawWall(tester, p + Vector2(-1600, 250), p + Vector2(1400, -450));
  expect(doc.commands.undoDepth, depth + 1, reason: 'premise: an edit');
  expect(session.dirty.value, isTrue, reason: 'premise: dirty');
  expect((
    session.name,
    session.fileName,
    session.location
  ), (
    'plan',
    'plan.jetplan',
    '/p/plan'
  ), reason: 'premise: titled');
  return doc;
}

/// The host kept [doc] as it was: the same object in the session and the
/// shell, not disposed, at [depth], still dirty, titled `plan` at
/// `/p/plan`, and no flow running.
void expectKept(WidgetTester tester, DraftDocument doc, int depth,
    {required String reason}) {
  final session = sessionOf(tester);
  expect(identical(session.document, doc), isTrue, reason: reason);
  expect(identical(viewOf(tester).document, doc), isTrue, reason: reason);
  expect(doc.commands.isDisposed, isFalse, reason: reason);
  expect(doc.commands.undoDepth, depth, reason: reason);
  expect(session.dirty.value, isTrue, reason: reason);
  expect((
    session.name,
    session.fileName,
    session.location
  ), (
    'plan',
    'plan.jetplan',
    '/p/plan'
  ), reason: reason);
  expect(titleOf(tester), '• plan — jet-cad', reason: reason);
  expect(session.busy.value, isFalse, reason: reason);
  expect(dialog, findsNothing, reason: reason);
}

void main() {
  testWidgets(
      'RP1 a dirty document and New, Open sample or Open: the dialog, busy '
      'under it; Cancel and Escape keep everything, with no picker, no '
      'panel and no write (spec 12a D10; M-12a-10)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final doc = await titledDirty(tester, files);
    final depth = doc.commands.undoDepth;
    final session = sessionOf(tester);
    final flows = <String, Future<void> Function()>{
      'New': host.newFlow,
      'Open sample': host.openSampleFlow,
      'Open': host.openFlow,
    };

    for (final MapEntry(key: name, value: run) in flows.entries) {
      for (final escape in [false, true]) {
        final how = '$name, ${escape ? 'Escape' : 'Cancel'}';
        final flow = run();
        await tester.pump();
        expect(dialog, findsOneWidget, reason: how);
        expect(tester.widget<Text>(find.byKey(const Key('replace-title'))).data,
            'Save the changes to plan?',
            reason: how);
        expect(session.busy.value, isTrue, reason: '$how: busy under it');
        for (final id in kIds) {
          expect(enabled(tester, id), isFalse, reason: '$how: $id');
        }
        if (escape) {
          await press(tester, LogicalKeyboardKey.escape);
          await tester.pump();
        } else {
          await answerReplace(tester, 'replace-cancel');
        }
        expect(dialog, findsNothing, reason: '$how: closed');
        noDialog(tester);
        await flow;
        await tester.pump();
        expectKept(tester, doc, depth, reason: how);
        expect(enabled(tester, 'new'), isTrue, reason: '$how: idle again');
      }
    }
    expect(files.openCalls, 1, reason: 'the fixture\'s Open only: no picker');
    expect(files.saveLocationCalls, isEmpty);
    expect(files.writes, isEmpty);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP2 Don\'t Save replaces: New and Open sample from a titled, dirty '
      'document end untitled, with no file name and no location, clean, '
      'and nothing written; the next Save asks where (spec 12a D2, D10, '
      'S-28; t5b-review n-2)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    String shownName() =>
        tester.widget<Text>(find.byKey(const Key('document-name'))).data!;

    final first = await titledDirty(tester, files);
    await discardAndRun(tester, host.newFlow());
    expect(dialog, findsNothing);
    expect(first.commands.isDisposed, isTrue, reason: 'replaced');
    expect(identical(viewOf(tester).document, session.document), isTrue);
    expect(session.document.entities.liveCount, 0, reason: 'the New one');
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(session.dirty.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(), 'Untitled');

    final second = await titledDirty(tester, files, at: far + Vector2(0, 9000));
    await discardAndRun(tester, host.openSampleFlow());
    expect(second.commands.isDisposed, isTrue, reason: 'replaced');
    expect(bytesOf(session.document), sampleBytes(), reason: 'the flat');
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(session.dirty.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(), 'Untitled');
    expect(files.writes, isEmpty, reason: 'Don\'t Save writes nothing');

    // The next Save asks where, rather than writing over /p/plan.
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(2100, 900));
    files.scriptSaveLocation(name: 'new.jetplan', location: '/p/new');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes.single.location, '/p/new');
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP3 Save, and the save does not happen: a cancelled Save As panel '
      '(untitled) or a failed write (titled) keeps everything, dirty, and '
      'replaces nothing (spec 12a D10)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);

    // Untitled: the Save step is a Save As, and its panel is cancelled.
    final launch = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(-1800, 1100));
    expect(session.dirty.value, isTrue, reason: 'premise');
    files.scriptSaveCancel();
    final newing = host.newFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    await newing;
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, isEmpty);
    expect(identical(session.document, launch), isTrue);
    expect(identical(viewOf(tester).document, launch), isTrue);
    expect(launch.commands.isDisposed, isFalse);
    expect(launch.commands.undoDepth, 1);
    expect(session.dirty.value, isTrue);
    expect(session.name, 'Untitled');
    expect(session.busy.value, isFalse);
    expect(dialog, findsNothing);

    // Titled: the write fails; the error, then nothing else.
    await undoKey(tester);
    expect(session.dirty.value, isFalse, reason: 'premise: back to clean');
    final doc = await titledDirty(tester, files);
    final depth = doc.commands.undoDepth;
    files.failNextWrite(StateError('the disk is full'));
    final opening = host.openSampleFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    expect(find.byKey(const Key('document-error')), findsOneWidget);
    expect(session.busy.value, isTrue, reason: 'busy under the error');
    await dismissError(tester);
    noDialog(tester);
    await opening;
    await tester.pump();
    expect(files.writes.single.location, '/p/plan', reason: 'it was tried');
    expectKept(tester, doc, depth, reason: 'after a failed write');
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP4 Save (the default: Enter) writes, then replaces: titled in place, '
      'and untitled through Save As; the bytes are the document\'s before '
      'the swap (spec 12a D10, D13)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);

    final doc = await titledDirty(tester, files);
    final before = bytesOf(doc);
    final newing = host.newFlow();
    await tester.pump();
    expect(dialog, findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter);
    await tester.pump();
    expect(dialog, findsNothing, reason: 'Enter answered it');
    noDialog(tester);
    await newing;
    await tester.pump();
    expect(files.saveLocationCalls, isEmpty, reason: 'in place');
    expect(files.writes.single.location, '/p/plan');
    expect(files.writes.single.bytes, before);
    expect(doc.commands.isDisposed, isTrue, reason: 'then replaced');
    expect(session.document.entities.liveCount, 0, reason: 'the New one');
    expect((session.name, session.location), ('Untitled', null));
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);

    // Untitled: Save asks where, writes, then Open sample replaces.
    final untitled = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(900, 2300));
    final untitledBytes = bytesOf(untitled);
    files.scriptSaveLocation(name: 'room.jetplan', location: '/p/room');
    final opening = host.openSampleFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    await opening;
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, hasLength(2));
    expect(files.writes.last.location, '/p/room');
    expect(files.writes.last.bytes, untitledBytes);
    expect(untitled.commands.isDisposed, isTrue);
    expect(bytesOf(session.document), sampleBytes());
    expect((session.name, session.location), ('Untitled', null));
    expect(session.dirty.value, isFalse);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP5 a clean document with history is replaced without a dialog, by '
      'New, Open sample and Open (the picker at once) (spec 12a D10)',
      (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);

    Future<void> cleanTitled() async {
      final doc = await titledDirty(tester, files);
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(session.dirty.value, isFalse, reason: 'premise: saved');
      expect(doc.commands.undoDepth, greaterThan(0), reason: 'premise');
    }

    await cleanTitled();
    var old = session.document;
    await host.newFlow();
    expect(dialog, findsNothing);
    await tester.pump();
    expect(old.commands.isDisposed, isTrue, reason: 'New replaced it');

    await cleanTitled();
    old = session.document;
    await host.openSampleFlow();
    expect(dialog, findsNothing);
    await tester.pump();
    expect(old.commands.isDisposed, isTrue, reason: 'Open sample did');

    await cleanTitled();
    old = session.document;
    final calls = files.openCalls;
    files.scriptOpen(name: 'other.jetplan', bytes: sampleBytes());
    await host.openFlow();
    expect(dialog, findsNothing);
    expect(files.openCalls, calls + 1, reason: 'the picker at once');
    await tester.pump();
    expect(old.commands.isDisposed, isTrue, reason: 'Open did');
    expect(session.name, 'other');
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP6 Open asks before the picker: Cancel opens no picker; Save writes, '
      'then the picker opens and the file replaces the document (spec 12a '
      'D10)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);
    final depth = doc.commands.undoDepth;
    final calls = files.openCalls;

    final cancelled = host.openFlow();
    await tester.pump();
    expect(dialog, findsOneWidget);
    expect(files.openCalls, calls, reason: 'the dialog comes first');
    await answerReplace(tester, 'replace-cancel');
    noDialog(tester);
    await cancelled;
    await tester.pump();
    expect(files.openCalls, calls, reason: 'Cancel: no picker');
    expectKept(tester, doc, depth, reason: 'Cancel');

    final before = bytesOf(doc);
    files.scriptOpen(
        name: 'other.jetplan', bytes: sampleBytes(), location: '/p/other');
    final saved = host.openFlow();
    await tester.pump();
    expect(files.openCalls, calls, reason: 'the dialog comes first');
    await answerReplace(tester, 'replace-save');
    noDialog(tester);
    await saved;
    await tester.pump();
    expect(files.writes.single.bytes, before);
    expect(files.openCalls, calls + 1, reason: 'then the picker');
    expect(doc.commands.isDisposed, isTrue);
    expect((session.name, session.location), ('other', '/p/other'));
    expect(session.dirty.value, isFalse);
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RP7 a clean document with a Selection panel value typed and not '
      'submitted: New, Open sample and Open settle it first, so the '
      'document is dirty and the dialog appears; Cancel keeps the committed '
      'value (spec 12a D2, D10)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);
    final wall = wallsOf(doc).last;
    await clickAt(tester, far + Vector2(-100, -100));
    expect(viewOf(tester).selection.keys, [SelectionKey.root(wall)],
        reason: 'premise: the drawn wall is selected');

    final flows = <String, Future<void> Function()>{
      'New': host.newFlow,
      'Open sample': host.openSampleFlow,
      'Open': host.openFlow,
    };
    var thickness = 150.25;
    for (final MapEntry(key: name, value: run) in flows.entries) {
      // Saved, so clean; then a thickness typed without Enter.
      await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(session.dirty.value, isFalse, reason: '$name: premise: clean');
      final params = doc.components.get<WallParams>(wall)!;
      final depth = doc.commands.undoDepth;
      thickness += 37.5;
      final field = find.byKey(const Key('wall-thickness'));
      await tester.tap(field);
      await tester.pump();
      await tester.enterText(field, '$thickness');
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isA<PanelFieldFocusNode>(),
          reason: '$name: premise: typed, still focused');
      expect(doc.components.get<WallParams>(wall), params,
          reason: '$name: premise: not committed');
      expect(session.dirty.value, isFalse, reason: '$name: premise: clean');

      final flow = run();
      await tester.pump();
      expect(dialog, findsOneWidget, reason: '$name: the settle made it dirty');
      expect(doc.components.get<WallParams>(wall),
          params.copyWith(thickness: thickness),
          reason: '$name: committed');
      expect(doc.commands.undoDepth, depth + 1, reason: '$name: its own step');
      await answerReplace(tester, 'replace-cancel');
      noDialog(tester);
      await flow;
      await tester.pump();
      expectKept(tester, doc, depth + 1, reason: name);
    }
    expect(files.openCalls, 1, reason: 'only the fixture\'s Open');
    expect(files.writes, hasLength(3));
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'RN1 nested flows: dirty, Cmd+N, Save with the write held -- Cmd+O, '
      'Cmd+S, Cmd+N, Cmd+Z and every button do nothing; the write completes '
      'and the document is replaced (spec 12a D6, D10, T-8)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);
    final depth = doc.commands.undoDepth;
    final before = bytesOf(doc);
    final stateId = doc.commands.stateId;

    files.holdWrites = true;
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN);
    await answerReplace(tester, 'replace-save');
    expect(files.writes, hasLength(1), reason: 'premise: the write is held');
    expect(session.busy.value, isTrue);

    for (final key in [
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyZ,
    ]) {
      await chord(tester, LogicalKeyboardKey.meta, key);
    }
    for (final id in kIds) {
      expect(enabled(tester, id), isFalse, reason: id);
      await tester.tap(find.byKey(Key('toolbar-$id')));
      await tester.pump();
    }
    expect(files.openCalls, 1, reason: 'only the fixture\'s Open');
    expect(files.saveLocationCalls, isEmpty);
    expect(files.writes, hasLength(1), reason: 'no second write');
    expect(dialog, findsNothing, reason: 'no second dialog');
    expect(identical(session.document, doc), isTrue);
    expect(doc.commands.undoDepth, depth);
    expect(doc.commands.stateId, stateId);
    expect(session.busy.value, isTrue);

    files.heldWrites.single.complete();
    await tester.pump();
    await tester.pump();
    expect(files.writes.single.bytes, before);
    expect(doc.commands.isDisposed, isTrue, reason: 'replaced');
    expect(session.document.entities.liveCount, 0, reason: 'the New one');
    expect((session.name, session.location), ('Untitled', null));
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);
    expect(enabled(tester, 'new'), isTrue);
  });

  testWidgets(
      'RN2 nested flows: an edit lands while the Save is held -- the write '
      'completes with the pre-edit bytes and the dialog is shown again, '
      'still busy; Cancel keeps the edit (spec 12a D5, D10, T-8; '
      'M-12a-26)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);
    final before = bytesOf(doc);

    files.holdWrites = true;
    final newing = host.newFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-save');
    expect(files.writes, hasLength(1), reason: 'premise: held');

    // The canvas stays live: a wall through the tool while the write waits.
    await drawWall(
        tester, far + Vector2(-700, 1900), far + Vector2(2600, 1900));
    final depth = doc.commands.undoDepth;
    expect(session.dirty.value, isTrue, reason: 'premise: edited');

    files.heldWrites.single.complete();
    await tester.pump();
    await tester.pump();
    expect(files.writes.single.bytes, before, reason: 'the pre-edit bytes');
    expect(dialog, findsOneWidget, reason: 'asked again');
    expect(identical(session.document, doc), isTrue, reason: 'not replaced');
    expect(session.dirty.value, isTrue);
    expect(session.busy.value, isTrue, reason: 'still the outer flow\'s');
    for (final id in kIds) {
      expect(enabled(tester, id), isFalse, reason: id);
    }

    await answerReplace(tester, 'replace-cancel');
    noDialog(tester);
    await newing;
    await tester.pump();
    expectKept(tester, doc, depth, reason: 'the edit is kept');
    expect(files.writes, hasLength(1));
  });

  testWidgets(
      'RN3 a swap while a write is held: the write, when it lands, does not '
      'mark the new document saved nor give it the old file (spec 12a D3, '
      'D5, S-28; t5-review R6). The commands are disabled while busy, so '
      'the flows are called directly, as nested flows', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = await titledDirty(tester, files);

    files.holdWrites = true;
    final saving = host.saveStep();
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'premise: held');
    final replacing = host.newFlow();
    await discardAndRun(tester, replacing);
    expect(doc.commands.isDisposed, isTrue, reason: 'premise: swapped');
    final fresh = session.document;
    expect((
      session.name,
      session.fileName,
      session.location
    ), (
      'Untitled',
      null,
      null
    ), reason: 'premise');
    expect(session.busy.value, isTrue, reason: 'the save is still running');

    files.heldWrites.single.complete();
    expect(await saving, isTrue);
    await tester.pump();
    expect(identical(session.document, fresh), isTrue);
    expect((
      session.name,
      session.fileName,
      session.location
    ), (
      'Untitled',
      null,
      null
    ), reason: 'the old file is not the new document\'s');
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(session.savedState, fresh.commands.stateId);
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);

    // An edit, then Save asks where rather than writing over /p/plan.
    files.holdWrites = false;
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(1700, -1300));
    expect(session.dirty.value, isTrue);
    files.scriptSaveLocation(name: 'fresh.jetplan', location: '/p/fresh');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes.last.location, '/p/fresh');
    expect(files.unscriptedCalls, 0);
  });
}
