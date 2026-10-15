// The service record at the controller (spec 2b S3 "The service record",
// `serviceEdited`, `serviceChanges`, `resetService`; decision 4; S5 rows
// 3-8). Ported from jet_cad_floor_plan's test/host/controller_test.dart
// (C2, C10, C14, C16-C20, CF3, CF4) with assertions unchanged but where the
// format itself is the premise (ruling R13-a: C16, C20) and today's names
// renamed (R13-b); the new SR- tests pin the groups in the record, the
// strict match over locked and generated units, today's format refused,
// `serviceEdited` against the groups held on entering, `resetService`
// clearing the groups and `serviceChanges` on `setUnitGroups` in service.
// Units are turned, mirrored and off the origin; moves are off-grid.
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/service/service_record.dart';

import '../support/harness.dart' show controllerFor;
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit, unitKit;

/// A version-1 record of [moves] and [groups], as a host would store one.
String record(
        {List<Map<String, Object?>> moves = const [],
        List<Map<String, Object?>> groups = const []}) =>
    jsonEncode({
      'format': 'jet_cad.service',
      'version': 1,
      'moves': moves,
      'groups': groups,
    });

/// A record's move of [node] (labelled [label]) by ([dx], [dy]).
Map<String, Object?> moveOf(
        InstanceNode node, String? label, double dx, double dy) =>
    {
      'handle': node.handle.toHex(),
      'label': label,
      'from': node.transform.toJson(),
      'to': Transform2.translation(dx, dy).multiply(node.transform).toJson(),
    };

/// A record's group.
Map<String, Object?> groupOf(String id, List<String> members,
        [String? label]) =>
    {'id': id, 'members': members, 'label': label};

/// Today's `zoned(tester)`: a controller over the service plan with a
/// turned-off-origin camera of its own.
PlanController zoned() {
  final c = controllerFor(kits: [testKit()], json: servicePlanText());
  c.camera.value = ViewportTransform(
      worldToScreenMatrix:
          const Transform2(0.0375, 0, 0, -0.0375, 612.5, 431.25));
  return c;
}

void main() {
  testWidgets(
      'SR-C2 the barrier: service edits never reach the design, and the '
      'service mode\'s Undo and Redo never reach a design edit (M-14f, '
      'M-14b2-1)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    drawLine(c);
    drawLine(c);
    c.undo(); // one design step on the redo stack
    await tester.pump();
    final design = c.save();
    final depth = c.activeDocument.commands.undoDepth;
    expect(c.canRedo.value, isTrue);
    expect(c.dirty.value, isTrue);
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isFalse);

    c.setMode(PlanMode.service);
    expect(c.canUndo.value, isFalse, reason: 'the copy has no history');
    expect(c.canRedo.value, isFalse);
    move(c, '1', 750, -250);
    move(c, '2', -125, 400);
    await tester.pump();
    expect(c.save(), design, reason: 'the design is untouched');
    expect(c.dirty.value, isFalse);
    expect(c.serviceEdited, isTrue);

    for (var k = 0; k < 5; k++) {
      c.undo();
    }
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.save(), design);
    for (var k = 0; k < 5; k++) {
      c.redo();
    }
    await tester.pump();
    expect(c.canRedo.value, isFalse);
    expect(c.save(), design, reason: 'Redo never redoes a design edit');

    c.setMode(PlanMode.design);
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, depth,
        reason: 'the design\'s history is the same');
    expect(c.canRedo.value, isTrue);
    expect(c.save(), design);
  });

  testWidgets(
      'SR-C10 the selection survives a mode switch and resetService; a '
      'hidden or locked unit cannot be selected (H13)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.select({'1', '3'});
    c.setMode(PlanMode.service);
    expect(c.selectedUnits.value, {'1', '3'});
    move(c, '1', 600, 0);
    c.resetService();
    expect(c.selectedUnits.value, {'1', '3'});
    expect(c.serviceEdited, isFalse);
    c.setMode(PlanMode.design);
    expect(c.selectedUnits.value, {'1', '3'});

    // Unit 2 on a locked layer.
    final doc = c.activeDocument;
    final locked = addLayer(doc, 'Locked', visible: true, locked: true);
    doc.commands
        .execute(SetInstanceLayerCommand(unitNode(doc, '2').handle, locked));
    c.select({'2', '3'});
    expect(c.selectedUnits.value, {'3'});
    await tester.pump();
  });

  testWidgets(
      'SR-C14 revision moves on every change of the active plan, and only of '
      'it (demo review F-1)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    var r = c.revision.value;
    int moved() {
      final d = c.revision.value - r;
      r = c.revision.value;
      return d;
    }

    drawLine(c);
    await tester.pump();
    expect(moved(), 1);
    c.undo();
    await tester.pump();
    expect(moved(), 1);
    c.setMode(PlanMode.service);
    expect(moved(), 1);
    move(c, '1', 300, 0);
    await tester.pump();
    expect(moved(), 1);
    c.resetService();
    expect(moved(), 1);
    c.load(servicePlanText());
    expect(moved(), 1);
    c.select({'1'});
    await tester.pump();
    expect(moved(), 0, reason: 'a selection is not a change of the plan');
  });

  testWidgets(
      'SR-restore-revision a restore moves revision once and notifies the '
      'listeners once; a reset notifies them once (spec S3; final review '
      'I-3, M-SR-restore-rev, M-SR-restore-notify, M-SR-reset-notify)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '1', 750.25, -250.5);
    final json = c.serviceJson()!;
    await tester.pump();
    var notified = 0;
    void count() => notified++;
    c.addListener(count);
    final r = c.revision.value;

    c.restoreService(json);
    expect(c.revision.value - r, 1);
    expect(notified, 1);

    notified = 0;
    c.resetService();
    expect(notified, 1);
    c.removeListener(count);
    await tester.pump();
  });

  testWidgets(
      'SR-C16 the service record: null in design; a restore puts the moves '
      'back as the copy\'s floor, re-selects by label, and no Undo removes '
      'it (spec 14d S1-S3, M-14d-m, M-14d-t)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    expect(c.serviceJson(), isNull);
    c.setMode(PlanMode.service);
    // Ruling R13-a: today's ['tables'].
    expect((jsonDecode(c.serviceJson()!) as Map)['moves'], isEmpty);
    move(c, '1', 750.25, -250.5);
    move(c, '3', -125.125, 400.75);
    final want1 = parts(unitNode(c.activeDocument, '1').transform);
    final want3 = parts(unitNode(c.activeDocument, '3').transform);
    final json = c.serviceJson()!;
    await tester.pump();

    c.setMode(PlanMode.design);
    c.setMode(PlanMode.service);
    expect(c.serviceEdited, isFalse, reason: 'premise: a fresh copy');
    c.select({'2'});
    final copy = c.activeDocument;
    final restored = c.restoreService(json);
    expect(restored.appliedMoves, ['1', '3']);
    expect(restored.droppedMoves, isEmpty);
    expect(identical(c.activeDocument, copy), isFalse, reason: 'a new copy');
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(parts(unitNode(c.activeDocument, '3').transform), want3);
    expect(c.selectedUnits.value, {'2'});
    expect(c.serviceEdited, isTrue);
    // M-SR9: the restore's command is left in the copy's history.
    expect(c.canUndo.value, isFalse, reason: 'the restore is no step');
    c.undo();
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(c.serviceJson(), json);
    await tester.pump();
  });

  testWidgets(
      'SR-C17 serviceEdited is the record, not the depth: a unit dragged '
      'back exactly is no edit; a restore, a move and its undo still are '
      '(spec 14d S3, M-14d-m)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '2', 333.5, -71.25);
    move(c, '2', -333.5, 71.25);
    expect(c.activeDocument.commands.undoDepth, 2, reason: 'premise');
    expect(c.serviceEdited, isFalse);

    move(c, '1', 90.5, 12.75);
    final json = c.serviceJson()!;
    c.resetService();
    expect(c.serviceEdited, isFalse);
    c.restoreService(json);
    move(c, '3', 15.5, 15.5);
    c.undo();
    expect(c.activeDocument.commands.undoDepth, 0, reason: 'premise');
    expect(c.serviceEdited, isTrue);
    await tester.pump();
  });

  testWidgets(
      'SR-C18 serviceChanges fires on a move, Undo, Redo, resetService and '
      'a restore, never on a mode switch or a load (spec 14d S4, M-14d-r)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    var heard = 0;
    c.serviceChanges.addListener(() => heard++);
    Future<int> after(void Function() act) async {
      final before = heard;
      act();
      await tester.pump();
      return heard - before;
    }

    expect(await after(() => move(c, '1', 10.5, 0)), 0,
        reason: 'a design edit is not the service record');
    expect(await after(() => c.setMode(PlanMode.service)), 0);
    expect(await after(() => move(c, '1', 20.25, 5)), 1);
    final json = c.serviceJson()!;
    expect(await after(c.undo), 1);
    expect(await after(c.redo), 1);
    expect(await after(c.resetService), 1);
    expect(await after(() => c.restoreService(json)), 1);
    expect(await after(() => c.load(servicePlanText())), 0);
    expect(await after(() => c.setMode(PlanMode.design)), 0);
  });

  testWidgets(
      'SR-C20 an Undo followed at once by a switch to design is heard, '
      'before the switch: a host saving on it keeps the undone record '
      '(review 14d-2)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    await tester.pump();
    final saved = <String?>[];
    c.serviceChanges.addListener(() => saved.add(c.serviceJson()));
    move(c, '1', 20.25, 5);
    await tester.pump();
    expect(saved, hasLength(1), reason: 'premise: the move is heard');
    // Ruling R13-a: today's '"tables":[{' and '"tables":[]'.
    expect(saved.last, contains('"moves":[{'), reason: 'premise: a move');
    c.undo();
    c.setMode(PlanMode.design);
    // M-SR20: undo's announce deleted.
    expect(saved, hasLength(2), reason: 'heard before the switch');
    expect(saved.last, contains('"moves":[]'));
    await tester.pump();
    expect(saved, hasLength(2), reason: 'and only once');
  });

  testWidgets(
      'SR-C19 a restore in design is a StateError; a text that is not a '
      'record changes nothing; a stale entry is dropped (spec 14d S2)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    expect(() => c.restoreService('{}'), throwsStateError);
    c.setMode(PlanMode.service);
    move(c, '1', 44.5, 0);
    move(c, '2', 0, -61.75);
    final json = c.serviceJson()!;
    final copy = c.activeDocument;
    final revision = c.revision.value;
    expect(() => c.restoreService('{"format":"x"}'), throwsFormatException);
    expect(identical(c.activeDocument, copy), isTrue);
    expect(c.revision.value, revision);

    // The design moves unit 2 after the record was stored.
    c.setMode(PlanMode.design);
    move(c, '2', 5, 5);
    final designed2 = parts(unitNode(c.activeDocument, '2').transform);
    c.setMode(PlanMode.service);
    final r = c.restoreService(json);
    expect(r.appliedMoves, ['1']);
    expect(r.droppedMoves, ['2']);
    expect(parts(unitNode(c.activeDocument, '2').transform), designed2,
        reason: 'a dropped entry leaves the unit at its designed place');
    await tester.pump();
  });

  testWidgets(
      'SR-CF3 the focus is kept, by label, across setMode, resetService, '
      'restoreService, load and newPlan (M-Z20)', (tester) async {
    final c = zoned();
    c.setUnitFocus({'7'});
    final focus = c.unitFocus.value;
    void kept(String after) =>
        expect(c.unitFocus.value, same(focus), reason: after);
    c.setMode(PlanMode.service);
    kept('setMode');
    move(c, '3', 410.5, -95.25);
    final json = c.serviceJson()!;
    c.resetService();
    kept('resetService');
    expect(c.restoreService(json).appliedMoves, ['3']);
    kept('restoreService');
    c.load(servicePlanText());
    kept('load');
    c.newPlan();
    kept('newPlan');
    c.setMode(PlanMode.design);
    kept('setMode back');
    await tester.pump();
  });

  testWidgets(
      'SR-CF4 the focus is not plan state: no json, dirty, undo depth, '
      'revision, record change, notification or settle, in either mode '
      '(M-Z27)', (tester) async {
    final c = zoned();
    drawLine(c);
    await tester.pump();
    var notified = 0, layouts = 0, settled = 0;
    c.addListener(() => notified++);
    c.serviceChanges.addListener(() => layouts++);
    final withdraw = c.registerSettle(() => settled++);
    addTearDown(withdraw);

    void expectUnmoved(void Function() act) {
      final json = c.save();
      final dirty = c.dirty.value;
      final depth = c.activeDocument.commands.undoDepth;
      final redo = c.activeDocument.commands.canRedo;
      final revision = c.revision.value;
      final before = (notified, layouts, settled);
      act();
      expect((notified, layouts, settled), before);
      expect(c.activeDocument.commands.undoDepth, depth);
      expect(c.activeDocument.commands.canRedo, redo);
      expect(c.revision.value, revision);
      expect(c.dirty.value, dirty);
      expect(c.save(), json);
    }

    expect(c.dirty.value, isTrue, reason: 'premise');
    expectUnmoved(() => c.setUnitFocus({'3', '7'}));
    expectUnmoved(() => c.setUnitFocus(null));
    c.setMode(PlanMode.service);
    move(c, '3', 410.5, -95.25);
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, 1, reason: 'premise');
    expectUnmoved(() => c.setUnitFocus({}));
    expectUnmoved(() => c.setUnitFocus({'2'}));
    await tester.pump();
    expect((notified, layouts), (1, 1), reason: 'the switch, the move');
  });

  testWidgets(
      'SR-state-kept statuses, group statuses and the focus are kept, '
      'identical, across a mode switch, resetService, restoreService, load '
      'and newPlan; the groups across a mode switch, load and newPlan (a '
      'reset clears them, a restore replaces them); the selection is kept '
      'by label by a reset and a restore, cleared by load and newPlan '
      '(spec S3, S5; Task 12 review)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitStatus({
      '1': bill,
      '3': UnitStatus(color: const Color(0x8043A047), caption: 'Paid')
    });
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'}, label: 'Smith')
    });
    c.setGroupStatus({'g': bill});
    c.setUnitFocus({'1', '3'});
    final statuses = c.unitStatuses.value;
    final groupStatuses = c.groupStatuses.value;
    final focus = c.unitFocus.value;
    var groups = c.unitGroups.value;
    void kept(String after, {bool andGroups = true}) {
      expect(c.unitStatuses.value, same(statuses), reason: after);
      expect(c.groupStatuses.value, same(groupStatuses), reason: after);
      expect(c.unitFocus.value, same(focus), reason: after);
      if (andGroups) {
        expect(c.unitGroups.value, same(groups), reason: after);
      }
    }

    c.setMode(PlanMode.service);
    kept('setMode');
    move(c, '3', 410.5, -95.25);
    final json = c.serviceJson()!;
    c.select({'3'});
    // M-SR21: resetService clears the statuses.
    c.resetService();
    kept('resetService', andGroups: false);
    expect(c.unitGroups.value, isEmpty, reason: 'premise: SR-reset');
    expect(c.selectedUnits.value, {'3'});
    // M-SR22: restoreService clears the focus.
    expect(c.restoreService(json).appliedGroups, ['g']);
    kept('restoreService', andGroups: false);
    expect(c.unitGroups.value, groups, reason: 'the record\'s, equal');
    expect(c.selectedUnits.value, {'3'});
    groups = c.unitGroups.value;
    // M-SR23: a load or a new plan clears the groups.
    c.load(servicePlanText());
    kept('load');
    expect(c.selectedUnits.value, isEmpty, reason: 'a load clears it');
    c.select({'3'});
    expect(c.selectedUnits.value, {'3'}, reason: 'premise');
    c.newPlan();
    kept('newPlan');
    expect(c.selectedUnits.value, isEmpty, reason: 'a new plan clears it');
    c.setMode(PlanMode.design);
    kept('setMode back');
    await tester.pump();
  });

  testWidgets(
      'SR-roundtrip moves and groups saved, then restored into a fresh copy: '
      'every move and group applied, the host\'s groups replaced by the '
      'record\'s in its order, and the record written again byte for byte',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '3', -125.125, 400.75);
    move(c, '1', 750.25, -250.5);
    c.setUnitGroups({
      'g2': UnitGroup(members: {'3', '2'}, label: 'Smith'),
      'g1': UnitGroup(members: {'1'}),
    });
    final json = c.serviceJson()!;
    final decoded = jsonDecode(json) as Map<String, Object?>;
    expect(decoded['format'], 'jet_cad.service');
    expect(decoded['version'], 1);
    expect([
      for (final m in decoded['moves']! as List) (m as Map)['label']
    ], [
      '1',
      '3'
    ], reason: 'ascending by handle');
    // M-SR1: the encoding drops a group's label.
    expect(decoded['groups'], [
      {
        'id': 'g2',
        'members': ['3', '2'],
        'label': 'Smith'
      },
      {
        'id': 'g1',
        'members': ['1'],
        'label': null
      },
    ]);
    final want1 = parts(unitNode(c.activeDocument, '1').transform);
    final want3 = parts(unitNode(c.activeDocument, '3').transform);
    c.setMode(PlanMode.design);
    c.setUnitGroups({
      'gX': UnitGroup(members: {'2'})
    });
    c.setMode(PlanMode.service);
    final r = c.restoreService(json);
    expect(r.appliedMoves, ['1', '3']);
    expect(r.droppedMoves, isEmpty);
    expect(r.appliedGroups, ['g2', 'g1']);
    expect(r.droppedGroups, isEmpty);
    expect(c.unitGroups.value.keys, ['g2', 'g1']);
    expect(c.unitGroups.value['g2'],
        UnitGroup(members: {'3', '2'}, label: 'Smith'));
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(parts(unitNode(c.activeDocument, '3').transform), want3);
    expect(c.serviceJson(), json, reason: 'byte for byte');
    await tester.pump();
  });

  testWidgets(
      'SR-design-edited (Review Focus 2) a record saved, the design edited '
      '(table 2 relabelled 9), the record restored: the unchanged table\'s '
      'move applies, the relabelled one\'s drops, a group naming the old '
      'label drops whole and is reported, the copy\'s history is cleared',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    move(c, '1', 750.25, -250.5);
    move(c, '2', -125.125, 400.75);
    c.setUnitGroups({
      'g1': UnitGroup(members: {'2', '3'}),
      'g2': UnitGroup(members: {'1'}),
    });
    final json = c.serviceJson()!;
    final want1 = parts(unitNode(c.activeDocument, '1').transform);
    c.setMode(PlanMode.design);
    final two = unitNode(c.document, '2');
    c.document.commands.execute(SetEntityTextCommand(
        labelEntityOf(c.document, two.handle)!, '9', kUnitLabelTag));
    c.setMode(PlanMode.service);
    move(c, '3', 15.5, 15.5);
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: a service step');
    final r = c.restoreService(json);
    // M-SR7: the strict match ignores the label.
    expect(r.appliedMoves, ['1']);
    expect(r.droppedMoves, ['2']);
    // M-SR8: a group whose label names no unit is applied.
    expect(r.appliedGroups, ['g2']);
    expect(r.droppedGroups, ['g1']);
    expect(c.unitGroups.value.keys, ['g2']);
    expect(parts(unitNode(c.activeDocument, '1').transform), want1);
    expect(
        parts(unitNode(c.activeDocument, '9').transform), parts(two.transform),
        reason: 'the relabelled table at its design place');
    expect(parts(unitNode(c.activeDocument, '3').transform),
        parts(unitNode(c.document, '3').transform),
        reason: 'a new copy: the move of 3 is gone');
    // M-SR9: the restore's command is left in the copy's history.
    expect(c.canUndo.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'SR-groups-replaced restoreService replaces the groups a host set in '
      'design with the record\'s; a record with none clears them',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'gX': UnitGroup(members: {'2', '3'})
    });
    c.setMode(PlanMode.service);
    final r = c.restoreService(record(groups: [
      groupOf('g1', ['1'])
    ]));
    // M-SR3: the record's groups merged into the host's.
    expect(c.unitGroups.value.keys, ['g1']);
    expect(r.appliedGroups, ['g1']);
    final none = c.restoreService(record());
    expect(c.unitGroups.value, isEmpty);
    expect(none.appliedGroups, isEmpty);
    expect(none.droppedGroups, isEmpty);
    await tester.pump();
  });

  testWidgets(
      'SR-invalid-groups groups breaking the validation are dropped and '
      'reported, never a FormatException: a blank id, an id equal after '
      'trimming, an empty group, a label already in a group, a label naming '
      'no unit (dropped whole); a shared label is kept', (tester) async {
    final c = controllerFor(
        kits: [testKit()], json: servicePlanText(duplicate: true));
    c.setMode(PlanMode.service);
    late ServiceRestore r;
    // M-SR4: the restore validates the groups with validateUnitGroups.
    expect(
        () => r = c.restoreService(record(groups: [
              groupOf('', ['1']),
              groupOf('g1', ['1']),
              groupOf(' g1 ', ['2']),
              groupOf('g2', [' ', '']),
              groupOf('g3', ['1', '2']),
              groupOf('g5', ['2', '99']),
              groupOf('g4', ['2'], 'Pair'),
            ])),
        returnsNormally);
    // M-SR5: a member naming no unit is dropped from its group instead.
    expect(r.appliedGroups, ['g1', 'g4']);
    expect(r.droppedGroups, ['', 'g1', 'g2', 'g3', 'g5']);
    expect(c.unitGroups.value, {
      'g1': UnitGroup(members: {'1'}),
      'g4': UnitGroup(members: {'2'}, label: 'Pair'),
    });
    expect(c.selectableMembers('g4'), {'2'},
        reason: 'the label two units share');
    await tester.pump();
  });

  testWidgets(
      'SR-locked-move-dropped a move of a locked unit (a missing kit\'s '
      'table) and a move of a seat are dropped; the unlocked table\'s '
      'applies', (tester) async {
    final c = controllerFor(kits: [testKit()], json: lockedPlanText());
    final one = unitNode(c.document, '1');
    final five = unitNode(c.document, '5');
    final moves = [
      moveOf(one, '1', 410.5, -95.25),
      moveOf(five, '5', 120.25, 33.5),
    ];
    // M-SR10: the strict match ignores isLockedUnit.
    final m = matchServiceMoves(c.document, c.unitIndex,
        decodeServiceRecord(record(moves: moves)).moves);
    expect([for (final e in m.applied) e.label], ['1']);
    expect([for (final e in m.dropped) e.label], ['5']);
    c.setMode(PlanMode.service);
    final r = c.restoreService(record(moves: moves));
    expect(r.appliedMoves, ['1']);
    expect(r.droppedMoves, ['5']);
    expect(parts(unitNode(c.activeDocument, '5').transform),
        parts(five.transform));

    final h = hall();
    final c2 = controllerFor(kits: [unitKit()], json: h.json);
    final seat = c2.document.tree[h.seats[0][0]]! as InstanceNode;
    final label = labelOf(c2.document, seat.handle);
    c2.setMode(PlanMode.service);
    // M-SR11: the strict match lets a generated unit move.
    final r2 =
        c2.restoreService(record(moves: [moveOf(seat, label, 300.5, 0)]));
    expect(r2.appliedMoves, isEmpty);
    expect(r2.droppedMoves, [label], reason: 'only placed units move');
    await tester.pump();
  });

  testWidgets(
      'SR-old-format-refused today\'s jet_cad.service_layout text, and that '
      'format with the new keys, are FormatExceptions; nothing changes',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    c.setMode(PlanMode.service);
    move(c, '1', 44.5, 0);
    await tester.pump();
    final copy = c.activeDocument;
    final revision = c.revision.value;
    final groups = c.unitGroups.value;
    final one = unitNode(c.document, '1');
    final today = jsonEncode({
      'format': 'jet_cad.service_layout',
      'version': 1,
      'tables': [
        {
          'handle': one.handle.toHex(),
          'number': '1',
          'from': one.transform.toJson(),
          'to':
              Transform2.translation(44.5, 0).multiply(one.transform).toJson(),
        }
      ],
    });
    final disguised = jsonEncode({
      'format': 'jet_cad.service_layout',
      'version': 1,
      'moves': <Object?>[],
      'groups': <Object?>[],
    });
    // M-SR12: the format is not checked.
    for (final text in [today, disguised]) {
      expect(() => c.restoreService(text), throwsFormatException, reason: text);
      expect(c.activeDocument, same(copy));
      expect(c.revision.value, revision);
      expect(c.unitGroups.value, same(groups));
      expect(c.serviceEdited, isTrue, reason: 'the move is kept');
    }
  });

  testWidgets(
      'SR-edited-after-enter serviceEdited compares the groups with those '
      'held on entering: false right after entering with groups set in '
      'design, true once they differ, false again when they are equal',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    c.setMode(PlanMode.service);
    // M-SR13: entering service does not take the groups held then.
    expect(c.serviceEdited, isFalse, reason: 'groups set in design, no move');
    c.setUnitGroups({
      'g': UnitGroup(members: {'2', '1'})
    });
    expect(c.serviceEdited, isFalse, reason: 'equal groups');
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    expect(c.serviceEdited, isTrue);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    expect(c.serviceEdited, isFalse);
    c.setMode(PlanMode.design);
    expect(c.serviceEdited, isFalse, reason: 'design');
    c.setUnitGroups(const {});
    c.setMode(PlanMode.service);
    expect(c.serviceEdited, isFalse, reason: 'the groups held on entering');
    await tester.pump();
  });

  testWidgets(
      'SR-edited-after-load a load or a new plan in service rebuilds the copy '
      'and takes the groups held then: the groups changed since entering '
      'read as an edit before, as none after (spec S3 serviceEdited)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    c.setMode(PlanMode.service);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '3'})
    });
    expect(c.serviceEdited, isTrue, reason: 'premise: groups changed');
    c.load(servicePlanText());
    // M-SR24: a load or a new plan keeps the groups held on entering.
    expect(c.serviceEdited, isFalse, reason: 'a load: a fresh copy');
    c.setUnitGroups({
      'g': UnitGroup(members: {'2'})
    });
    expect(c.serviceEdited, isTrue, reason: 'premise: groups changed');
    c.newPlan();
    expect(c.serviceEdited, isFalse, reason: 'a new plan: a fresh copy');
    await tester.pump();
  });

  testWidgets(
      'SR-reset resetService rebuilds the copy and clears the groups in '
      'service; in design it is a silent no-op', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    var heard = 0;
    c.serviceChanges.addListener(() => heard++);
    final revision = c.revision.value;
    // M-SR15: resetService clears the groups in design.
    c.resetService();
    expect(c.unitGroups.value.keys, ['g']);
    expect(heard, 0);
    expect(c.revision.value, revision);
    c.setMode(PlanMode.service);
    move(c, '1', 600, 0);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '3'})
    });
    await tester.pump();
    heard = 0;
    final copy = c.activeDocument;
    c.resetService();
    // M-SR16: resetService keeps the groups (today's resetLayout).
    expect(c.unitGroups.value, isEmpty);
    expect(c.activeDocument, isNot(same(copy)));
    expect(parts(unitNode(c.activeDocument, '1').transform),
        parts(unitNode(c.document, '1').transform));
    expect(c.serviceEdited, isFalse);
    expect(heard, 1);
    await tester.pump();
  });

  testWidgets(
      'SR-changes-timing setUnitGroups fires serviceChanges in service only; '
      'statuses, group statuses and the focus never; nor setMode, load or '
      'newPlan', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    var heard = 0, groups = 0;
    c.serviceChanges.addListener(() => heard++);
    c.unitGroups.addListener(() => groups++);
    c.setUnitGroups({
      'g': UnitGroup(members: {'1'})
    });
    // M-SR17: setUnitGroups fires serviceChanges in design too.
    expect((heard, groups), (0, 1));
    c.setMode(PlanMode.service);
    expect(heard, 0, reason: 'never on setMode');
    c.setUnitGroups({
      'g': UnitGroup(members: {'1', '2'})
    });
    // M-SR18: setUnitGroups does not fire serviceChanges.
    expect((heard, groups), (1, 2));
    c.setUnitStatus({'1': bill});
    c.setGroupStatus({'g': bill});
    c.setUnitFocus({'1'});
    expect(heard, 1, reason: 'not in the record');
    expect(
        () => c.setUnitGroups({
              '': UnitGroup(members: {'1'})
            }),
        throwsArgumentError);
    expect(heard, 1, reason: 'a refused set fires nothing');
    c.load(servicePlanText());
    expect(heard, 1, reason: 'never on load');
    c.newPlan();
    expect(heard, 1, reason: 'never on newPlan');
    c.setMode(PlanMode.design);
    await tester.pump();
    expect(heard, 1);
  });
}
