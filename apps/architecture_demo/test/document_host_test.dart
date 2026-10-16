// Ported from apps/floor_planner/test/document_host_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "document_host_test.dart"). DH1, DH4, DH5 are SPLIT (the -open half is
// here; the intent half is covered by the library tests named at each
// case); DH2, DH3, DH6 are PORT; DH7 is DROPPED: its premise (a per-swap
// shell rebuild that re-wires the busy flag's listeners) is gone, the
// controller and the editor stay across a swap, and the behaviour after a
// swap is covered by RN1 and DC7 in document_replace_test.dart and
// document_commands_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTools;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_rig.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(41234.5, 27345.25);

/// Edit, undo, redo, save, and a cut redo branch, on the host's current
/// plan, with the title following. The plan is clean at [name] on entry;
/// [saveAs] is true when the first save asks where (an untitled plan).
Future<void> dirtyRun(AppRig rig,
    {required String name, required bool saveAs}) async {
  final tester = rig.tester;
  final c = rig.controller;
  final commands = c.document.commands;
  expect(c.dirty.value, isFalse, reason: 'premise: clean');
  expect(titleOf(tester), '$name — jet-cad');
  await aimCamera(tester, c, far);

  // Edit: dirty. Undo: clean. Redo: dirty.
  await drawWall(tester, c, far + Vector2(-1500, 0), far + Vector2(1500, 0));
  final base = commands.undoDepth;
  expect(base, greaterThan(0), reason: 'premise: an edit');
  expect(c.dirty.value, isTrue, reason: 'edit');
  expect(titleOf(tester), '• $name — jet-cad');
  await undoKey(tester);
  expect(c.dirty.value, isFalse, reason: 'undo returns to the save');
  expect(titleOf(tester), '$name — jet-cad');
  c.redo();
  await tester.pump();
  expect(c.dirty.value, isTrue, reason: 'redo');
  expect(titleOf(tester), '• $name — jet-cad');

  // Save: clean, at the encoded state.
  if (saveAs) {
    rig.files.scriptSaveLocation(name: 'run.jetplan', location: '/plans/run');
  }
  final saved = rig.host.saveStep();
  await tester.pump();
  expect(await saved, isTrue);
  await tester.pump();
  final savedName = saveAs ? 'run' : name;
  expect(c.dirty.value, isFalse, reason: 'save');
  expect(titleOf(tester), '$savedName — jet-cad');

  // Undo past the save: dirty. Another edit cuts the saved state's redo
  // branch: dirty, and no undo or redo comes back to it.
  await undoKey(tester);
  expect(c.dirty.value, isTrue, reason: 'undo past the save');
  await drawWall(tester, c, far + Vector2(0, -1500), far + Vector2(0, 1500));
  expect(c.document.commands.canRedo, isFalse,
      reason: 'premise: the branch is cut');
  expect(c.dirty.value, isTrue, reason: 'another edit');
  await undoKey(tester);
  expect(c.dirty.value, isTrue, reason: 'the saved state is gone for good');
  c.redo();
  await tester.pump();
  expect(c.dirty.value, isTrue, reason: 'and not on the redo either');
  expect(titleOf(tester), '• $savedName — jet-cad');
}

void main() {
  testWidgets(
      'DH1-open the app launches on the empty plan: untitled, clean, no '
      'history, millimetres, the default page live (spec 12a D4, T-11)',
      (tester) async {
    // Intent half: COVERED, checked: packages/jet_cad_2d_plan/test/
    // controller/plan_controller_test.dart:30 (C1), controller/new_plan_test.dart:34
    // (ND1), packages/jet_cad_2d_integration/test/scaffold/prepare_test.dart:21
    // (SC-prepare, DASHED at handle 6) and packages/jet_cad_2d_plan/test/
    // editor/editor_view_test.dart:49 ("a bare editor opens on the empty
    // document and its default page").
    // Decided: premise impossible (the launch plan is the controller's: its
    // DASHED record and page are the library's, not the app's).
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;

    expect(doc.entities.liveCount, 0);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(rig.session.name, 'Untitled');
    expect(rig.session.fileName, isNull);
    expect(rig.session.location, isNull);
    expect(c.dirty.value, isFalse);
    expect(rig.session.busy.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(tester), 'Untitled');
    // The page, live: the document's component, the zoom text, the panel.
    expect(doc.components.get<PageComponent>(doc.rootHandle),
        PageComponent(originX: -7425, originY: -5250));
    expect(tester.widget<Text>(find.byKey(const Key('zoom-text'))).data,
        startsWith('1:50 · '));
    expect(find.byType(PlanPagePanel), findsOneWidget);
    expect(find.byKey(const Key('page-scale')), findsOneWidget);
    expect(rig.files.openCalls + rig.files.saveLocationCalls.length, 0);
    expect(rig.files.writes, isEmpty);
  });

  testWidgets(
      'DH2 New after an edit (Don\'t Save) replaces the plan with a fresh '
      'empty one, untitled and clean; Open sample opens the flat untitled '
      'and clean (spec 12a D4, D10)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(2000, 700));
    final first = c.document;
    expect(c.dirty.value, isTrue, reason: 'premise');

    await discardAndRun(tester, rig.host.newFlow());
    final fresh = c.document;
    expect(identical(fresh, first), isFalse);
    expect(fresh.entities.liveCount, 0);
    expect(fresh.commands.canUndo, isFalse);
    expect(fresh.components.get<PageComponent>(fresh.rootHandle),
        PageComponent(originX: -7425, originY: -5250));
    expect(rig.session.name, 'Untitled');
    expect(c.dirty.value, isFalse);
    expect(titleOf(tester), 'Untitled — jet-cad');

    await rig.host.openSampleFlow();
    await tester.pump();
    final sample = c.document;
    expect(identical(sample, fresh), isFalse);
    expect(c.save(), sampleText(), reason: 'the flat, unchanged');
    expect(sample.entities.liveCount, greaterThanOrEqualTo(500));
    expect(sample.commands.canUndo, isFalse, reason: 'nothing to undo');
    expect(rig.session.name, 'Untitled');
    expect(rig.session.fileName, isNull);
    expect(c.dirty.value, isFalse);
    expect(rig.session.busy.value, isFalse);
    expect(rig.files.writes, isEmpty);
  });

  testWidgets(
      'DH3 dirty follows the undo position against the save point: edit, '
      'undo, redo, save, and a cut branch (spec 12a D5; M-12a-2, M-12a-4)',
      (tester) async {
    final rig = await pumpApp(tester);
    await dirtyRun(rig, name: 'Untitled', saveAs: true);
    expect(rig.files.writes, hasLength(1));
    expect(rig.session.location, '/plans/run');
  });

  testWidgets(
      'DH4-open the same after an Open: the title and dirty follow the '
      'opened plan, whose save point is the load (spec 12a D5; M-12a-19)',
      (tester) async {
    // Intent half: COVERED, checked: packages/jet_cad_2d_plan/test/
    // controller/plan_controller_test.dart:119 C6 ("a load forgets the last
    // save's state").
    // Decided: premise impossible (there is no per-document change
    // subscription to re-make: the controller's dirty is recomputed on every
    // command and on a load).
    final rig = await pumpApp(tester);
    final c = rig.controller;
    // The launch plan is edited first, so its own changes are not what makes
    // the opened one read dirty.
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(0, 2500));
    rig.files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/plans/flat');
    await discardAndRun(tester, rig.host.openFlow());
    expect(rig.session.name, 'flat');
    expect(rig.session.location, '/plans/flat');
    expect(c.document.entities.liveCount, greaterThanOrEqualTo(500),
        reason: 'premise: the flat is open');
    await dirtyRun(rig, name: 'flat', saveAs: false);
    expect(rig.files.writes.single.location, '/plans/flat',
        reason: 'a titled plan saves in place');
  });

  testWidgets(
      'DH5-open swap hygiene: one controller across New and Open, the old '
      'document disposed and released by everything that held it, the '
      'selection and the tool reset, and the object-snap setting survives '
      'and still toggles (spec 12a D2, S-11; M-12a-20, M-12a-21)',
      (tester) async {
    // Intent half: COVERED, checked: packages/jet_cad_2d_plan/test/
    // controller/lifetimes_test.dart:23 (C-life1, products disposed on a swap)
    // and packages/jet_cad_2d_plan/test/panels/layer_page_controller_test.dart:123
    // (LP-1, the old document loses the panel's listener). The snap setting's
    // survival is unpinned there, so it is pinned here.
    // Decided: premise impossible (no per-swap shell: the editor keeps the
    // controller, and the controller's identity is what stays).
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final host = rig.host;
    final launch = c.document;
    await rig.host.openSampleFlow();
    await tester.pump();
    final old = c.document;
    expect(launch.commands.isDisposed, isTrue, reason: 'the first swap');
    expect(identical(rig.controller, c), isTrue,
        reason: 'one controller across the swap');

    // The old plan in a state of its own: object snap off, a wall selected,
    // the Wall tool active.
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    c.activeSelection.replace([SelectionKey.root(wallsOf(c).first)]);
    await tester.pump();
    expect(c.activeSelection.isEmpty, isFalse, reason: 'premise');
    await press(tester, LogicalKeyboardKey.keyW);
    expect(c.activeTool.value, ArchitectureTools.wall, reason: 'premise');
    expect(old.commands.expander, isNotNull, reason: 'premise: installed');
    expect(old.commands.onAfterMutate, isNotNull, reason: 'premise');
    expect(old.commands.onBeforeMutate, isNotNull, reason: 'premise');
    expect(old.tables.debugListenerCount, greaterThan(0), reason: 'premise');

    rig.files.scriptOpen(name: 'flat.jetplan', bytes: sampleBytes());
    await rig.host.openFlow();
    await tester.pump();
    await tester.pump();

    expect(identical(c.document, old), isFalse);
    expect(old.commands.isDisposed, isTrue, reason: 'disposed after the swap');
    expect(old.commands.expander, isNull);
    expect(old.commands.onAfterMutate, isNull);
    expect(old.commands.onBeforeMutate, isNull);
    expect(old.tables.debugListenerCount, 0);
    expect(c.activeSelection.isEmpty, isTrue);
    expect(c.activeTool.value, 'plan.select');
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off',
        reason: 'the setting survives the swap');
    await press(tester, LogicalKeyboardKey.f3);
    expect(
        tester.widget<Text>(find.byKey(const Key('osnap-text'))).data, 'OSNAP');
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    expect(identical(rig.host, host), isTrue, reason: 'one host');
  });

  testWidgets(
      'DH6 New and Open sample from a titled plan forget its file: untitled, '
      'no file name, no location, and the next Save asks where instead of '
      'writing over the old file; the old document lives until the swap\'s '
      'frame (spec 12a D2, S-11, S-28)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final session = rig.session;
    final host = rig.host;

    // Titled and saved: opened from /p/plan, edited through the Wall tool
    // far from the origin, then Cmd+S writes in place.
    files.scriptOpen(
        name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
    await host.openFlow();
    await tester.pump();
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(1900, -600));
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    final saved = c.document;
    expect(files.writes.single.location, '/p/plan', reason: 'premise');
    expect(files.saveLocationCalls, isEmpty, reason: 'premise: in place');
    expect(saved.commands.undoDepth, 1, reason: 'premise: edited');
    expect(c.dirty.value, isFalse, reason: 'premise: saved');
    expect((
      session.name,
      session.fileName,
      session.location
    ), (
      'plan',
      'plan.jetplan',
      '/p/plan'
    ), reason: 'premise: titled');

    // New. The old document is still live until the frame; after it, not.
    await host.newFlow();
    expect(identical(c.document, saved), isFalse, reason: 'premise: swapped');
    expect(saved.commands.isDisposed, isFalse,
        reason: 'not disposed under the still-mounted old views');
    await tester.pump();
    expect(saved.commands.isDisposed, isTrue, reason: 'disposed after it');
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(tester), 'Untitled');

    // An edit, then Cmd+S: a Save As, not a write over /p/plan.
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far + Vector2(0, 800), far + Vector2(-2200, 800));
    expect(c.dirty.value, isTrue, reason: 'premise');
    files.scriptSaveLocation(name: 'fresh.jetplan', location: '/p/fresh');
    await chord(tester, LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(files.saveLocationCalls, ['Untitled.jetplan']);
    expect(files.writes, hasLength(2));
    expect(files.writes.last.location, '/p/fresh');
    expect(files.writes.last.bytes, bytesOf(c));
    expect((session.name, session.location), ('fresh', '/p/fresh'));
    expect(c.dirty.value, isFalse);

    // Titled and left clean: opened from /p/plan again, edited and undone.
    files.scriptOpen(
        name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
    await host.openFlow();
    await tester.pump();
    final clean = c.document;
    await aimCamera(tester, c, far);
    await drawWall(
        tester, c, far + Vector2(300, -1200), far + Vector2(300, 1700));
    await undoKey(tester);
    expect(clean.commands.canRedo, isTrue, reason: 'premise: edited, undone');
    expect(c.dirty.value, isFalse, reason: 'premise: clean');
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
        reason: 'not disposed under the still-mounted old views');
    await tester.pump();
    expect(clean.commands.isDisposed, isTrue);
    expect((session.name, session.fileName, session.location),
        ('Untitled', null, null));
    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(tester), 'Untitled');
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
}
