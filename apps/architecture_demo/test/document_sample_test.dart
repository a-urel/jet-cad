// The new cases of the document flows (spec B6; brief of Task 4, step 6):
//   N2  Open sample: the flat is there, clean, with nothing to undo; an edit
//       makes it dirty and New then asks.
//   N4  The sample saved as a file, New, Open: the plan, its text and its
//       title come back.
//   SV-edit-during-write  An edit made while the write is held stays dirty
//       (the save point is the state `save()` encoded).
//   OP-garbage  A file that is not a plan changes nothing: not the text, the
//       name, the dirty mark nor the history.
// Mutations are named at each case and listed in the Task 4 report.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_rig.dart';

/// The sample's furniture: the eight filled regions the flat draws at the
/// root (they are drafted fills, not library symbols).
int rootFills(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.fill &&
            doc.entities.ownerAt(slot) == doc.rootHandle)
          slot,
    ].length;

void main() {
  testWidgets(
      'N2 Open sample: walls, rooms and furniture are there, clean, with '
      'nothing to undo; an edit makes it dirty and New asks', (tester) async {
    // Mutations: M-N2a opens the sample with `newPlan(build: buildSampleFlat)`
    // followed by an `execute` (an undo step, dirty): the clean and the undo
    // assertions go red. M-N2b makes `_mayDiscard` return true without
    // asking: the dialog assertion goes red.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    expect(liveOfAny(c, ArchitectureTypes.wall), 0, reason: 'premise: empty');

    await rig.tapKey('toolbar-open-sample');
    await tester.pump();
    expect(liveOfAny(c, ArchitectureTypes.wall), 10, reason: 'walls');
    expect(liveOfAny(c, ArchitectureTypes.room), 7, reason: 'rooms');
    expect(liveOfAny(c, ArchitectureTypes.opening), 15, reason: 'openings');
    expect(liveOfAny(c, ArchitectureTypes.separator), 1, reason: 'separator');
    expect(liveOfAny(c, ArchitectureTypes.dimension), 5, reason: 'dimensions');
    expect(rootFills(c.document), 8, reason: 'furniture');
    expect(c.dirty.value, isFalse, reason: 'clean');
    expect(c.canUndo.value, isFalse, reason: 'nothing to undo');
    expect(c.document.commands.undoDepth, 0);
    expect(rig.session.name, 'Untitled');
    expect(titleOf(tester), 'Untitled — jet-cad');

    await rig.editOnce();
    expect(c.dirty.value, isTrue, reason: 'an edit');
    expect(c.canUndo.value, isTrue);
    final asking = rig.host.newFlow();
    await tester.pump();
    expect(find.byKey(const Key('replace-dialog')), findsOneWidget,
        reason: 'New asks about the edit');
    await answerReplace(tester, 'replace-cancel');
    await asking;
    await tester.pump();
    expect(c.dirty.value, isTrue, reason: 'Cancel kept the plan');
    expect(liveOfAny(c, ArchitectureTypes.wall), 11);
  });

  testWidgets(
      'N4 the sample saved as flat.jetplan, New, Open flat.jetplan: the '
      'plan\'s text is the saved text, the title reads flat, clean',
      (tester) async {
    // Mutation M-N4: the write takes `save()` of a fresh `newPlan`: the
    // texts differ, red.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    await rig.tapKey('toolbar-open-sample');
    await tester.pump();

    files.scriptSaveLocation(name: 'flat.jetplan', location: '/plans/flat');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    final saved = files.writes.single.bytes;
    expect(utf8.decode(saved), sampleText(), reason: 'premise: the flat');

    await rig.host.newFlow();
    await tester.pump();
    expect(liveOfAny(c, ArchitectureTypes.wall), 0, reason: 'premise: New');
    expect(rig.session.name, 'Untitled');

    files.scriptOpen(
        name: 'flat.jetplan', bytes: saved, location: '/plans/flat');
    await rig.host.openFlow();
    await tester.pump();
    expect(c.save(), utf8.decode(saved), reason: 'the saved text');
    expect(liveOfAny(c, ArchitectureTypes.wall), 10);
    expect(titleOf(tester), 'flat — jet-cad');
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'SV-edit-during-write an edit made while the write is held: the '
      'plan is dirty when the write completes (Review Focus 1)',
      (tester) async {
    // Mutation: after the write, the host calls `save()` again and then
    // `markSaved()` (the state read after the await is the save point): the
    // edit is marked saved, dirty is false, red.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    await aimCamera(tester, c, kFar);
    await drawWall(tester, c, kFar, kFar + Vector2(1800, 700));
    files.scriptSaveLocation(name: 'a.jetplan', location: '/p/a');
    files.holdWrites = true;

    final saving = rig.host.saveStep();
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'premise: the write is held');
    final encoded = files.writes.single.bytes;
    await rig.editOnce(at: kFar + Vector2(0, 6000));
    expect(c.dirty.value, isTrue, reason: 'premise: edited during the write');

    files.heldWrites.single.complete();
    expect(await saving, isTrue);
    await tester.pump();
    expect(c.dirty.value, isTrue, reason: 'the edit is not on disk');
    expect(titleOf(tester), '• a — jet-cad');
    expect(files.writes.single.bytes, encoded, reason: 'the pre-edit bytes');
    expect(rig.session.name, 'a');
  });

  testWidgets(
      'OP-garbage a file that is not a plan, opened over an edited, named '
      'plan: the error dialog says it could not be opened, and the text, '
      'the name, the dirty mark and the undo history are unchanged '
      '(Review Focus 2)', (tester) async {
    // Mutation: the session is named before `load` is called: the name
    // changes to the garbage file's, red.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    files.scriptOpen(
        name: 'plan.jetplan', bytes: sampleBytes(), location: '/p/plan');
    await rig.host.openFlow();
    await tester.pump();
    await rig.editOnce();
    expect(c.dirty.value, isTrue, reason: 'premise: edited');
    expect(rig.session.name, 'plan', reason: 'premise: named');
    final text = c.save();
    final depth = c.document.commands.undoDepth;

    files.scriptOpen(
        name: 'junk.jetplan',
        bytes: utf8.encode('{"not": "a plan"}'),
        location: '/p/junk');
    final opening = rig.host.openFlow();
    await tester.pump();
    await answerReplace(tester, 'replace-discard');
    expect(find.byKey(const Key('document-error')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('document-error-title'))).data,
        'Could not open junk.jetplan');
    await dismissError(tester);
    await opening;
    await tester.pump();

    expect(c.save(), text, reason: 'the plan\'s text');
    expect(rig.session.name, 'plan', reason: 'the name');
    expect(rig.session.fileName, 'plan.jetplan');
    expect(rig.session.location, '/p/plan');
    expect(c.dirty.value, isTrue, reason: 'still dirty');
    expect(c.canUndo.value, isTrue, reason: 'undo is still available');
    expect(c.document.commands.undoDepth, depth);
    expect(titleOf(tester), '• plan — jet-cad');
    expect(rig.session.busy.value, isFalse);
  });
}
