// Spec 12a D2, D4, D5 (plan 12a Task 5): the app launches on the empty
// document; New and Open sample swap the document; dirty follows the undo
// position against the save point, on the launch document and on an
// opened one; a swap leaves nothing of the old document live, and New or
// Open sample from a titled document forgets its file.
import 'package:floor_planner/document_host.dart';
import 'package:jet_cad_floor_plan/editor.dart';
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
final Vector2 far = Vector2(41234.5, 27345.25);

/// The sample's bytes, built here with a measurer of the test's own.
List<int> sampleBytes() {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  return bytesOf(startupPlan(m));
}

/// Edit, undo, redo, save, and a cut redo branch, on the host's current
/// document (spec 12a D5, decision 5), with the title following. The
/// document is clean at [name] on entry; [saveAs] is true when the first
/// save asks where (an untitled document).
Future<void> dirtyRun(WidgetTester tester, FakeDocumentFiles files,
    {required String name, required bool saveAs}) async {
  final session = sessionOf(tester);
  final host = hostOf(tester);
  final doc = session.document;
  expect(session.dirty.value, isFalse, reason: 'premise: clean');
  expect(titleOf(tester), '$name — jet-cad');
  await aimCamera(tester, far);

  // Edit: dirty. Undo: clean. Redo: dirty.
  await drawWall(tester, far + Vector2(-1500, 0), far + Vector2(1500, 0));
  expect(doc.commands.undoDepth, 1, reason: 'premise: one edit');
  expect(session.dirty.value, isTrue, reason: 'edit');
  expect(titleOf(tester), '• $name — jet-cad');
  await undoKey(tester);
  expect(doc.commands.undoDepth, 0, reason: 'premise: undone');
  expect(session.dirty.value, isFalse, reason: 'undo returns to the save');
  expect(titleOf(tester), '$name — jet-cad');
  doc.commands.redo();
  await tester.pump();
  expect(session.dirty.value, isTrue, reason: 'redo');
  expect(titleOf(tester), '• $name — jet-cad');

  // Save: clean, at the encoded state.
  if (saveAs) {
    files.scriptSaveLocation(name: 'run.jetplan', location: '/plans/run');
  }
  final saved = host.saveStep();
  await tester.pump();
  expect(await saved, isTrue);
  await tester.pump();
  final savedName = saveAs ? 'run' : name;
  expect(session.dirty.value, isFalse, reason: 'save');
  expect(titleOf(tester), '$savedName — jet-cad');

  // Undo past the save: dirty. Another edit cuts the saved state's redo
  // branch: dirty, and no undo or redo comes back to it.
  await undoKey(tester);
  expect(session.dirty.value, isTrue, reason: 'undo past the save');
  await drawWall(tester, far + Vector2(0, -1500), far + Vector2(0, 1500));
  expect(doc.commands.canRedo, isFalse, reason: 'premise: the branch is cut');
  expect(session.dirty.value, isTrue, reason: 'another edit');
  await undoKey(tester);
  expect(doc.commands.undoDepth, 0, reason: 'premise');
  expect(session.dirty.value, isTrue,
      reason: 'the saved state is gone for good');
  doc.commands.redo();
  await tester.pump();
  expect(session.dirty.value, isTrue, reason: 'and not on the redo either');
  expect(titleOf(tester), '• $savedName — jet-cad');
}

void main() {
  testWidgets(
      'DH1 the app launches on the empty document: untitled, clean, no '
      'history, millimetres, DASHED, and the literal page live (spec 12a D4, '
      'T-11)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final view = viewOf(tester);
    final doc = view.document;

    expect(identical(doc, session.document), isTrue);
    expect(doc.entities.liveCount, 0);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
    expect(session.name, 'Untitled');
    expect(session.fileName, isNull);
    expect(session.location, isNull);
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');
    // The page, live: the notifier, the zoom text, the page panel.
    expect(view.page.value, PageComponent(originX: -7425, originY: -5250));
    expect(tester.widget<Text>(find.byKey(const Key('zoom-text'))).data,
        startsWith('1:50 · '));
    expect(find.byType(PagePanel), findsOneWidget);
    expect(find.byKey(const Key('page-scale')), findsOneWidget);
    expect(files.openCalls + files.saveLocationCalls.length, 0);
    expect(files.writes, isEmpty);
  });

  testWidgets(
      'DH2 New after an edit (Don\'t Save) replaces the document with a '
      'fresh empty one, untitled and clean; Open sample opens the flat '
      'untitled and clean (spec 12a D4, D10)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(2000, 700));
    final first = session.document;
    expect(session.dirty.value, isTrue, reason: 'premise');

    await discardAndRun(tester, host.newFlow());
    final fresh = session.document;
    expect(identical(fresh, first), isFalse);
    expect(identical(viewOf(tester).document, fresh), isTrue,
        reason: 'the shell is the new document\'s');
    expect(fresh.entities.liveCount, 0);
    expect(fresh.commands.canUndo, isFalse);
    expect(viewOf(tester).page.value,
        PageComponent(originX: -7425, originY: -5250));
    expect(session.name, 'Untitled');
    expect(session.dirty.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');

    await host.openSampleFlow();
    await tester.pump();
    final sample = session.document;
    expect(identical(sample, fresh), isFalse);
    expect(bytesOf(sample), sampleBytes(), reason: 'the flat, unchanged');
    expect(
        viewOf(tester).document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(session.name, 'Untitled');
    expect(session.fileName, isNull);
    expect(session.dirty.value, isFalse);
    expect(session.busy.value, isFalse);
    expect(files.writes, isEmpty);
  });

  testWidgets(
      'DH3 dirty follows the undo position against the save point: edit, '
      'undo, redo, save, and a cut branch (spec 12a D5; M-12a-2, M-12a-4)',
      (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    await dirtyRun(tester, files, name: 'Untitled', saveAs: true);
    expect(files.writes, hasLength(1));
    expect(sessionOf(tester).location, '/plans/run');
  });

  testWidgets(
      'DH4 the same after an Open: the subscription is the opened '
      'document\'s (spec 12a D5, S-23; M-12a-19)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    // The launch document is edited first, so its own changes are not what
    // makes the opened one read dirty.
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(0, 2500));
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/plans/flat');
    await discardAndRun(tester, host.openFlow());
    final session = sessionOf(tester);
    expect(session.name, 'flat');
    expect(session.location, '/plans/flat');
    expect(session.document.entities.liveCount, greaterThanOrEqualTo(500),
        reason: 'premise: the flat is open');
    await dirtyRun(tester, files, name: 'flat', saveAs: false);
    expect(files.writes.single.location, '/plans/flat',
        reason: 'a titled document saves in place');
  });

  testWidgets(
      'DH5 swap hygiene: the old document is disposed and released by '
      'everything that held it; the new shell starts fresh, and the '
      'object-snap setting survives and still toggles (spec 12a D2, S-11; '
      'M-12a-20, M-12a-21)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final launch = sessionOf(tester).document;
    await host.openSampleFlow();
    await tester.pump();
    final old = sessionOf(tester).document;
    expect(launch.commands.isDisposed, isTrue, reason: 'the first swap');

    // The old shell in a state of its own: object snap off, a wall
    // selected, the Wall tool active.
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    final view = viewOf(tester);
    view.selection.replace([SelectionKey.root(wallsOf(old).first)]);
    await tester.pump();
    expect(view.selection.isEmpty, isFalse, reason: 'premise');
    await press(tester, LogicalKeyboardKey.keyW);
    expect(view.tools.active, isNot(isA<SelectTool>()), reason: 'premise');
    expect(old.commands.expander, isNotNull, reason: 'premise: installed');
    expect(old.commands.onAfterMutate, isNotNull, reason: 'premise');
    expect(old.commands.onBeforeMutate, isNotNull, reason: 'premise');
    expect(old.tables.debugListenerCount, greaterThan(0), reason: 'premise');

    files.scriptOpen(name: 'flat.jetplan', bytes: sampleBytes());
    await host.openFlow();
    await tester.pump();
    await tester.pump();

    final now = viewOf(tester);
    expect(identical(now.document, old), isFalse);
    expect(old.commands.isDisposed, isTrue, reason: 'disposed after the swap');
    expect(old.commands.expander, isNull);
    expect(old.commands.onAfterMutate, isNull);
    expect(old.commands.onBeforeMutate, isNull);
    expect(old.tables.debugListenerCount, 0);
    expect(now.selection.isEmpty, isTrue);
    expect(now.tools.active, isA<SelectTool>());
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off',
        reason: 'the setting survives the swap');
    expect(hostOf(tester).snap.objectSnap, isFalse);
    await press(tester, LogicalKeyboardKey.f3);
    expect(
        tester.widget<Text>(find.byKey(const Key('osnap-text'))).data, 'OSNAP');
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    expect(identical(hostOf(tester), host), isTrue);
  });

  testWidgets(
      'DH6 New and Open sample from a titled document forget its file: '
      'untitled, no file name, no location, and the next Save asks where '
      'instead of writing over the old file; the old document lives until '
      'the swap\'s frame (spec 12a D2, S-11, S-28)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    String shownName() =>
        tester.widget<Text>(find.byKey(const Key('document-name'))).data!;

    // Titled and saved: opened from /p/plan, edited through the Wall tool
    // far from the origin, then Cmd+S writes in place.
    files.scriptOpen(
        name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
    await host.openFlow();
    await tester.pump();
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(1900, -600));
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    final saved = session.document;
    expect(files.writes.single.location, '/p/plan', reason: 'premise');
    expect(files.saveLocationCalls, isEmpty, reason: 'premise: in place');
    expect(saved.commands.undoDepth, 1, reason: 'premise: edited');
    expect(session.dirty.value, isFalse, reason: 'premise: saved');
    expect((
      session.name,
      session.fileName,
      session.location
    ), (
      'plan',
      'plan.jetplan',
      '/p/plan'
    ), reason: 'premise: titled');

    // New. The old shell is still mounted until the frame, so the old
    // document is not disposed yet; after the frame it is.
    await host.newFlow();
    expect(identical(viewOf(tester).document, saved), isTrue,
        reason: 'premise: the old shell until the frame');
    expect(saved.commands.isDisposed, isFalse,
        reason: 'not disposed under the still-mounted old shell');
    await tester.pump();
    expect(saved.commands.isDisposed, isTrue, reason: 'disposed after it');
    expect(identical(viewOf(tester).document, session.document), isTrue);
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(), 'Untitled');

    // An edit, then Cmd+S: a Save As, not a write over /p/plan.
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(0, 800), far + Vector2(-2200, 800));
    expect(session.dirty.value, isTrue, reason: 'premise');
    files.scriptSaveLocation(name: 'fresh.jetplan', location: '/p/fresh');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, hasLength(2));
    expect(files.writes.last.location, '/p/fresh');
    expect(files.writes.last.bytes, bytesOf(session.document));
    expect((session.name, session.location), ('fresh', '/p/fresh'));
    expect(session.dirty.value, isFalse);

    // Titled and left clean: opened from /p/plan again, edited and undone.
    files.scriptOpen(
        name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
    await host.openFlow();
    await tester.pump();
    final clean = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far + Vector2(300, -1200), far + Vector2(300, 1700));
    await undoKey(tester);
    expect(clean.commands.canRedo, isTrue, reason: 'premise: edited, undone');
    expect(session.dirty.value, isFalse, reason: 'premise: clean');
    expect((
      session.name,
      session.fileName,
      session.location
    ), (
      'plan',
      'plan.jetplan',
      '/p/plan'
    ), reason: 'premise: titled');

    // Open sample: the same, and the Save step asks too.
    await host.openSampleFlow();
    expect(clean.commands.isDisposed, isFalse,
        reason: 'not disposed under the still-mounted old shell');
    await tester.pump();
    expect(clean.commands.isDisposed, isTrue);
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(), 'Untitled');
    files.scriptSaveLocation(name: 'flat.jetplan', location: '/p/flat');
    final saving = host.saveStep();
    await tester.pump();
    expect(await saving, isTrue);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan', 'Untitled.jetplan']);
    expect(files.writes, hasLength(3));
    expect(files.writes.last.location, '/p/flat');
    expect(files.writes.map((w) => w.location).where((l) => l == '/p/plan'),
        hasLength(1),
        reason: 'the opened file was written once, by its own Save');
    expect(files.unscriptedCalls, 0);
  });

  testWidgets(
      'DH7 a swap leaves the busy flag with the listeners it had: the old '
      "shell's command flags let go of it (spec 12a D2, S-11)", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final measurer = FlutterTextMeasurer();
    final session = _CountingSession(newDocument(measurer), measurer);
    final files = FakeDocumentFiles();
    await tester.pumpWidget(MaterialApp(
        home: DocumentHost(
            session: session, files: files, exitGuard: FakeExitGuard())));
    await tester.pump();
    final host = tester.state<DocumentHostState>(find.byType(DocumentHost));
    final listening = session.countingBusy.listeners;
    expect(listening, greaterThan(1),
        reason: 'premise: the host and the shell listen');

    Future<void> swapped(String what) async {
      await tester.pump();
      await tester.pump();
      expect(session.countingBusy.listeners, listening, reason: what);
    }

    final launch = session.document;
    await host.newFlow();
    await swapped('New');
    expect(identical(session.document, launch), isFalse, reason: 'premise');
    await host.openSampleFlow();
    await swapped('Open sample');
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
    await host.openFlow();
    await swapped('Open');
    expect(session.name, 'flat', reason: 'premise: opened');

    // Busy still reaches the new shell's buttons.
    session.busy.value = true;
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byKey(const Key('toolbar-save')))
            .onPressed,
        isNull);
    session.busy.value = false;
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}

/// A busy notifier that counts its listeners.
class _CountingBusy extends ValueNotifier<bool> {
  _CountingBusy() : super(false);

  final _added = <VoidCallback>[];

  int get listeners => _added.length;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _added.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _added.remove(listener);
  }
}

/// A session whose [busy] counts its listeners.
class _CountingSession extends DocumentSession {
  _CountingSession(super.document, super.measurer);

  final _CountingBusy countingBusy = _CountingBusy();

  @override
  ValueNotifier<bool> get busy => countingBusy;
}
