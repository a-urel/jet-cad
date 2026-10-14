// Ported from jet_cad_floor_plan test/host/design_changes_test.dart (2b
// Task 9, spec S3 `unitChanges`, S5): the design's unit changes. DC10 and
// DC16 (the service mode) are Task 11's; DC15 reads Task 13's
// `serviceEdited`, so Task 13 ported it; DC7 also reads Task 13's record and
// reset and drags with the service tool, so Task 14 ports it. DC8, DC9,
// DC11, DC12, DC13 and DC17 were ported by 2a for the object-level
// `changes` stream (plan_change_test.dart); they are ported again here for
// `unitChanges`, whose code is its own (controller ruling R-13, F-T9c).
// Today's header follows.
//
// Host embedding API spec E-5 (Slice 2 plan, Task 3): the controller's
// unitChanges -- a design edit, undo or redo reported as the tables
// added, removed and changed, by instance, in ascending instance order;
// PlanUnitsReplaced on load and newPlan in either mode, after the old
// design's last changes; nothing from the selection mode; nothing read while
// no one listens. On the embedding fixture: tables turned 30 degrees,
// mirrored at 90, scaled (1.5, 0.8), turned 180, all 40 m off the origin;
// `5` hidden, `L` locked; `7` and ` 7 ` sharing a number; an unnumbered
// table; `9` with no finite corner. The design view is mounted, so the
// shell's TableLabelSystem runs (the Delete's data expander, the labels).
// Expected centres come from the fixture's transforms, by the forward
// transform.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_detail.dart'
    show diffUnitDetails;

import '../support/unit_embedding_fixture.dart';
import '../support/unit_fixtures.dart' show fxKit;

/// Data as a host writes it: keys out of order, a value with a space, a dot
/// and a non-ASCII letter, an empty value.
Map<String, String> hostData() => {
      'zeta': 'Masa 4.ğ',
      'id': '7f3c-ä',
      'alpha': '',
    };

/// A controller over the fixture, disposed after the test.
PlanController fixtureController() {
  final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// [fixtureController] shown in a design view of 1440 x 900, fitted.
Future<PlanController> mounted(WidgetTester tester) async {
  final c = fixtureController();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
  await tester.pump();
  return c;
}

/// Every change [c] reports from now on, in order.
List<PlanUnitChange> listen(PlanController c) {
  final seen = <PlanUnitChange>[];
  final sub = c.unitChanges.listen(seen.add);
  addTearDown(sub.cancel);
  return seen;
}

/// The instances of the tables numbered [n] in [c]'s active plan, ascending.
List<Handle> instancesOf(PlanController c, String n) =>
    [for (final t in c.unitIndex.withLabel(n)) t.instance];

/// The detail of [instance] in [c]'s current list.
PlanUnitDetail detailOf(PlanController c, Handle instance) =>
    c.unitDetails[c.unitDetailInstances.indexOf(instance)];

/// [d] with the fields given replaced.
PlanUnitDetail copyOf(PlanUnitDetail d,
        {PlanUnit? table, bool? locked, Map<String, String>? data}) =>
    PlanUnitDetail(
        unit: table ?? d.unit,
        center: d.center,
        size: d.size,
        rotation: d.rotation,
        mirrored: d.mirrored,
        corners: d.corners,
        layer: d.layer,
        locked: locked ?? d.locked,
        data: data ?? d.data);

/// The fixture's table labelled [label].
EmbeddingTable fixtureTable(String label) =>
    embeddingTables.firstWhere((t) => t.label == label);

/// The world image of definition point ([x], [y]) through [t].
Offset worldOf(Transform2 t, double x, double y) =>
    Offset(t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f);

/// [embeddingBox]'s centre, (700, 100), through [t].
Offset boxCentre(Transform2 t) => worldOf(t, 700, 100);

/// [actual] is [expected] within 1e-12 relative.
void expectNear(Offset? actual, Offset expected, String reason) {
  expect(actual, isNotNull, reason: reason);
  expect(actual!.dx, closeTo(expected.dx, expected.dx.abs() * 1e-12),
      reason: reason);
  expect(actual.dy, closeTo(expected.dy, expected.dy.abs() * 1e-12),
      reason: reason);
}

void main() {
  group('with the design view mounted', () {
    testWidgets(
        'DC1 one edit, several changes in ascending instance order: '
        'setUnitsData on L, 4 and 1 (in that order) is a Changed for 1, 4 '
        'and L, the data only', (tester) async {
      final c = await mounted(tester);
      final one = instancesOf(c, '1').single,
          four = instancesOf(c, '4').single,
          l = instancesOf(c, 'L').single;
      expect(one.value < four.value && four.value < l.value, isTrue,
          reason: 'premise: placed 1, 4, L');
      final b1 = detailOf(c, one), b4 = detailOf(c, four), bl = detailOf(c, l);
      final seen = listen(c);

      expect(
          c.setUnitsData({
            'L': {'id': 'l'},
            '4': hostData(),
            ' 1 ': {'zeta': 'z', 'id': 'one'},
          }),
          isTrue);
      expect(seen, isEmpty, reason: 'delivered asynchronously');
      await tester.pump();
      expect(seen, [
        PlanUnitChanged(b1, copyOf(b1, data: {'id': 'one', 'zeta': 'z'})),
        PlanUnitChanged(b4, copyOf(b4, data: hostData())),
        PlanUnitChanged(bl, copyOf(bl, data: {'id': 'l'})),
      ]);
      expectNear(b1.center, boxCentre(fixtureTable('1').transform),
          'premise: 1 where the fixture puts it');
      expect(bl.locked, isTrue, reason: 'premise: a locked table takes data');
    });

    testWidgets(
        'DC2 a layer locked: one Changed per table on it, locked only; its '
        'undo the reverse; the hidden layer shown: one Changed for 5, now '
        'with its geometry', (tester) async {
      final c = await mounted(tester);
      final before = c.unitDetails;
      final doc = c.document;
      final seen = listen(c);
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;

      doc.commands.execute(SetLayerCommand(zero.copyWith(locked: true)));
      await tester.pump();
      final onZero = [
        for (final d in before)
          if (d.layer == zero.name) d
      ];
      expect(onZero, hasLength(8),
          reason: 'premise: 1, 2, 3, 4, both 7s, the unnumbered, 9');
      expect(seen, [
        for (final d in onZero) PlanUnitChanged(d, copyOf(d, locked: true))
      ]);

      seen.clear();
      c.undo();
      await tester.pump();
      expect(seen, [
        for (final d in onZero) PlanUnitChanged(copyOf(d, locked: true), d)
      ]);

      seen.clear();
      final hidden = doc.tables.layers.byName(kEmbeddingHidden)!;
      doc.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
      await tester.pump();
      expect(seen, hasLength(1));
      final change = seen.single as PlanUnitChanged;
      expect(change.before.unit.label, '5');
      expect(change.before.center, isNull, reason: 'hidden: no geometry');
      expect(change.after.unit.visible, isTrue);
      expectNear(change.after.center, boxCentre(fixtureTable('5').transform),
          'shown: its box centre, by the forward transform');
      expect(change.after.layer, kEmbeddingHidden);
    });

    testWidgets(
        'DC3 a renumber of 1 to 21: one Changed, the number only, its data '
        'kept', (tester) async {
      final c = await mounted(tester);
      expect(c.setUnitData('1', hostData()), isTrue);
      final one = instancesOf(c, '1').single;
      final b1 = detailOf(c, one);
      expect(b1.data, hostData(), reason: 'premise');
      final seen = listen(c);

      final label = c.unitIndex.withLabel('1').single;
      c.document.commands
          .execute(SetEntityTextCommand(label.label!, '21', kUnitLabelTag));
      await tester.pump();
      expect(seen, [
        PlanUnitChanged(
            b1,
            copyOf(b1,
                table: PlanUnit(
                    label: '21',
                    kind: b1.unit.kind,
                    capacity: b1.unit.capacity,
                    symbolKey: b1.unit.symbolKey))),
      ]);
      expect((seen.single as PlanUnitChanged).after.data, hostData());
    });

    testWidgets(
        'DC4 setUnitData: one Changed, the data only; the same data again '
        'reports nothing; undo and redo report the reverse and the same',
        (tester) async {
      final c = await mounted(tester);
      final two = instancesOf(c, '2').single;
      final b2 = detailOf(c, two);
      expect(b2.mirrored, isTrue, reason: 'premise: 2 is the mirrored one');
      final seen = listen(c);

      expect(c.setUnitData('2', hostData()), isTrue);
      await tester.pump();
      final changed = PlanUnitChanged(b2, copyOf(b2, data: hostData()));
      expect(seen, [changed]);
      expect(c.setUnitData(' 2 ', hostData()), isTrue);
      await tester.pump();
      expect(seen, [changed], reason: 'no edit, no change');

      c.undo();
      await tester.pump();
      expect(seen.last, PlanUnitChanged(changed.after, b2));
      c.redo();
      await tester.pump();
      expect(seen, [changed, PlanUnitChanged(changed.after, b2), changed]);
    });

    testWidgets(
        'DC5 M-H25: deleting 3 is exactly [Removed(3)]; its undo exactly '
        '[Added(3)], equal to it, data included; its redo the Removed again',
        (tester) async {
      final c = await mounted(tester);
      expect(c.setUnitData('3', hostData()), isTrue);
      final three = instancesOf(c, '3').single;
      final b3 = detailOf(c, three);
      expectNear(b3.center, boxCentre(fixtureTable('3').transform),
          'premise: 3 where the fixture puts it');
      expect(b3.data, hostData(), reason: 'premise');
      expect(c.unitDetailInstances.last.value > three.value, isTrue,
          reason: 'premise: tables after 3, which an index diff shifts');
      final seen = listen(c);

      c.select({'3'});
      await tester.pump();
      expect(c.editorSelectedUnits.value, {'3'}, reason: 'premise');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(c.document.tree[three], isNull, reason: 'premise: deleted');
      expect(seen, [PlanUnitRemoved(b3)]);

      c.undo();
      await tester.pump();
      expect(seen, [PlanUnitRemoved(b3), PlanUnitAdded(b3)]);
      expect(
          (seen[1] as PlanUnitAdded).unit, (seen[0] as PlanUnitRemoved).unit);
      expect((seen[1] as PlanUnitAdded).unit.data, hostData());

      c.redo();
      await tester.pump();
      expect(seen.skip(2), [PlanUnitRemoved(b3)]);
    });

    testWidgets(
        'DC6 M-H25: a move of " 7 " is exactly one Changed whose before and '
        'after are that table\'s, never the other 7\'s; then a move of 7, '
        'the same for it', (tester) async {
      final c = await mounted(tester);
      final sevens = instancesOf(c, '7');
      expect(sevens, hasLength(2), reason: 'premise: 7 and " 7 "');
      final seen = listen(c);
      // " 7 " (placed second, mirrored) first, then 7: a diff keyed by the
      // number, whichever of the two it keeps, misses one of them.
      for (final (index, label, mirrored) in [
        (1, ' 7 ', true),
        (0, '7', false),
      ]) {
        seen.clear();
        final instance = sevens[index];
        final before = detailOf(c, instance);
        final fixture = fixtureTable(label);
        expect(before.mirrored, mirrored, reason: 'premise: "$label"');
        expectNear(before.center, boxCentre(fixture.transform), 'premise');

        final shift = Transform2.translation(1200, -700);
        c.document.commands.execute(
            TransformNodeCommand(instance, shift.multiply(fixture.transform)));
        await tester.pump();
        expect(seen, hasLength(1), reason: '"$label"');
        final change = seen.single as PlanUnitChanged;
        expect(change.before, before, reason: '"$label"');
        expectNear(change.after.center,
            boxCentre(shift.multiply(fixture.transform)), 'moved by the shift');
        expect(change.after.mirrored, mirrored);
        expect(change.after.rotation, closeTo(before.rotation, 1e-12));
        expect(change.after.unit, before.unit);
        expect(change.after, detailOf(c, instance));
      }
    });

    // DC7 (service moves report nothing): Task 14 ports it (it reads Task
    // 13's serviceEdited, record and reset, and drags with the service
    // tool).

    testWidgets(
        'DC8 newPlan: exactly [PlanUnitsReplaced()], no Removed per '
        'table; a load: the same', (tester) async {
      final c = await mounted(tester);
      final seen = listen(c);
      c.newPlan();
      await tester.pump();
      expect(seen, [const PlanUnitsReplaced()]);
      expect(c.unitDetails, isEmpty, reason: 'premise: an empty plan');
      c.load(embeddingPlanJson());
      await tester.pump();
      expect(seen, [const PlanUnitsReplaced(), const PlanUnitsReplaced()]);
    });

    testWidgets(
        'DC9 an edit then a load in one synchronous step: the edit\'s change, '
        'then PlanUnitsReplaced, then an edit of the loaded plan',
        (tester) async {
      final c = await mounted(tester);
      final b2 = detailOf(c, instancesOf(c, '2').single);
      final seen = listen(c);

      expect(c.setUnitData('2', hostData()), isTrue);
      c.load(embeddingPlanJson());
      final l = detailOf(c, instancesOf(c, 'L').single);
      expect(c.setUnitData('L', {'id': 'l'}), isTrue);
      expect(seen, isEmpty, reason: 'delivered asynchronously');
      await tester.pump();
      expect(seen, [
        PlanUnitChanged(b2, copyOf(b2, data: hostData())),
        const PlanUnitsReplaced(),
        PlanUnitChanged(l, copyOf(l, data: {'id': 'l'})),
      ]);
    });
  });

  testWidgets(
      'DC10 M-H29(PlanReplaced in service): there, a load is '
      'exactly [PlanUnitsReplaced()], and so is a newPlan', (tester) async {
    final c = fixtureController();
    c.setMode(PlanMode.service);
    await tester.pump();
    final seen = listen(c);
    c.load(embeddingPlanJson());
    await tester.pump();
    expect(seen, [const PlanUnitsReplaced()]);
    c.newPlan();
    await tester.pump();
    expect(seen, [const PlanUnitsReplaced(), const PlanUnitsReplaced()]);
    expect(c.mode.value, PlanMode.service, reason: 'premise');
  });

  testWidgets(
      'DC11 nothing is read with no listener, nor after the last cancel; one '
      'read per listen and per moved design; two edits of one synchronous '
      'step are one read and one report', (tester) async {
    final c = fixtureController();
    final doc = c.document;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    expect(c.setUnitData('1', hostData()), isTrue);
    doc.commands.execute(SetLayerCommand(zero.copyWith(locked: true)));
    c.undo();
    c.redo();
    await tester.pump();
    c.load(embeddingPlanJson());
    c.newPlan();
    c.load(embeddingPlanJson());
    await tester.pump();
    expect(c.debugUnitScans, 0, reason: 'no listener: nothing read');

    final first = <PlanUnitChange>[];
    final a = c.unitChanges.listen(first.add);
    expect(c.debugUnitScans, 1, reason: 'the baseline');
    final second = <PlanUnitChange>[];
    final b = c.unitChanges.listen(second.add);
    expect(c.debugUnitScans, 1, reason: 'one baseline for every listener');

    final one = instancesOf(c, '1').single;
    final b1 = detailOf(c, one);
    expect(c.setUnitData('1', {'id': 'a'}), isTrue);
    expect(c.setUnitData('1', {'id': 'b'}), isTrue);
    await tester.pump();
    expect(c.debugUnitScans, 2, reason: 'the second event finds nothing new');
    final change = PlanUnitChanged(b1, copyOf(b1, data: {'id': 'b'}));
    expect(first, [change]);
    expect(second, [change]);

    // Not awaited: awaiting a cancel here left the next pump hanging (seen
    // while writing this test); the cancel itself is synchronous.
    unawaited(a.cancel());
    expect(c.setUnitData('1', {'id': 'c'}), isTrue);
    await tester.pump();
    expect(c.debugUnitScans, 3, reason: 'one listener left');
    expect(second, [change, isA<PlanUnitChanged>()]);
    expect(first, [change]);

    unawaited(b.cancel());
    final scans = c.debugUnitScans;
    expect(c.setUnitData('1', {'id': 'd'}), isTrue);
    c.undo();
    await tester.pump();
    c.load(embeddingPlanJson());
    c.newPlan();
    await tester.pump();
    expect(c.debugUnitScans, scans, reason: 'after the last cancel: nothing');

    c.load(embeddingPlanJson());
    await tester.pump();
    expect(c.debugUnitScans, scans, reason: 'premise: still nothing');
    final two = detailOf(c, instancesOf(c, '2').single);
    expect(c.setUnitData('2', {'id': 'before'}), isTrue);
    final third = listen(c);
    expect(c.debugUnitScans, scans + 1, reason: 'a new baseline');
    await tester.pump();
    expect(third, isEmpty,
        reason: 'an edit made before the listen is not owed');
    expect(c.setUnitData('2', hostData()), isTrue);
    await tester.pump();
    expect(third, [
      PlanUnitChanged(
          copyOf(two, data: {'id': 'before'}), copyOf(two, data: hostData()))
    ]);
    expect(c.debugUnitScans, scans + 2);
  });

  testWidgets(
      'DC12 dispose closes the stream: an edit made just before it is not '
      'reported, and nothing comes after', (tester) async {
    final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
    final seen = <PlanUnitChange>[];
    var done = false;
    c.unitChanges.listen(seen.add, onDone: () => done = true);
    expect(c.setUnitData('1', hostData()), isTrue);
    c.dispose();
    await tester.pump();
    expect(seen, isEmpty);
    expect(done, isTrue);
  });

  test('DC13 the four changes: ==, hashCode and toString', () {
    const table =
        PlanUnit(label: '7', kind: 'table', capacity: 4, symbolKey: 'k');
    const a = PlanUnitDetail(
        unit: table,
        center: Offset(46100.5, -30900.4),
        size: Size(800, 600),
        rotation: 1.25,
        mirrored: true,
        corners: [Offset(1, 2), Offset(3, 4), Offset(5, 6), Offset(7, 8)],
        layer: 'Locked',
        locked: true,
        data: {'id': 'x'});
    const b = PlanUnitDetail(
        unit: table,
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: [],
        layer: '0',
        locked: false);
    final a2 = PlanUnitDetail(
        unit: const PlanUnit(
            label: '7', kind: 'table', capacity: 4, symbolKey: 'k'),
        center: const Offset(46100.5, -30900.4),
        size: const Size(800, 600),
        rotation: 1.25,
        mirrored: true,
        corners: [
          const Offset(1, 2),
          const Offset(3, 4),
          const Offset(5, 6),
          const Offset(7, 8)
        ],
        layer: 'Locked',
        locked: true,
        data: {'id': 'x'});
    expect(a2 == a, isTrue, reason: 'premise: equal, not identical');

    expect(PlanUnitAdded(a), PlanUnitAdded(a2));
    expect(PlanUnitAdded(a).hashCode, PlanUnitAdded(a2).hashCode);
    expect(PlanUnitAdded(a) == PlanUnitAdded(b), isFalse);
    expect(PlanUnitAdded(a) == PlanUnitRemoved(a), isFalse);
    expect(PlanUnitRemoved(a), PlanUnitRemoved(a2));
    expect(PlanUnitRemoved(a).hashCode, PlanUnitRemoved(a2).hashCode);
    expect(PlanUnitRemoved(a) == PlanUnitRemoved(b), isFalse);
    expect(PlanUnitChanged(a, b), PlanUnitChanged(a2, b));
    expect(PlanUnitChanged(a, b).hashCode, PlanUnitChanged(a2, b).hashCode);
    expect(PlanUnitChanged(a, b) == PlanUnitChanged(b, a), isFalse,
        reason: 'before and after are ordered');
    expect(PlanUnitChanged(a, b) == PlanUnitChanged(a, a), isFalse);
    expect(const PlanUnitsReplaced(), const PlanUnitsReplaced());
    expect(
        const PlanUnitsReplaced().hashCode, const PlanUnitsReplaced().hashCode);
    expect(const PlanUnitsReplaced() == PlanUnitAdded(a), isFalse);

    const ta = 'PlanUnitDetail(PlanUnit(7, table, 4, k, visible: true), '
        'center: Offset(46100.5, -30900.4), size: Size(800.0, 600.0), '
        'rotation: 1.25, mirrored: true, corners: [Offset(1.0, 2.0), '
        'Offset(3.0, 4.0), Offset(5.0, 6.0), Offset(7.0, 8.0)], '
        'layer: Locked, locked: true, data: {id: x})';
    const tb = 'PlanUnitDetail(PlanUnit(7, table, 4, k, visible: true), '
        'center: null, size: null, rotation: 0.0, mirrored: false, '
        'corners: [], layer: 0, locked: false, data: {})';
    expect(PlanUnitAdded(a).toString(), 'PlanUnitAdded($ta)');
    expect(PlanUnitRemoved(b).toString(), 'PlanUnitRemoved($tb)');
    expect(PlanUnitChanged(a, b).toString(), 'PlanUnitChanged($ta, $tb)');
    expect(const PlanUnitsReplaced().toString(), 'PlanUnitsReplaced()');
  });

  test('DC14 the diff: by instance, ascending, whatever the numbers', () {
    PlanUnitDetail t(String? n, {String layer = '0'}) => PlanUnitDetail(
        unit: PlanUnit(label: n, kind: 'table', capacity: 2, symbolKey: null),
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: const [],
        layer: layer,
        locked: false);
    // 0x31 removed, 0x33 renumbered to the removed one's number, 0x34
    // unchanged, 0x35 added, 0x36 moved to another layer.
    final changes = diffUnitDetails(
        const [Handle(0x31), Handle(0x33), Handle(0x34), Handle(0x36)],
        [t('7'), t('8'), t(null), t('7')],
        const [Handle(0x33), Handle(0x34), Handle(0x35), Handle(0x36)],
        [t('7'), t(null), t('8'), t('7', layer: 'B')]);
    expect(changes, [
      PlanUnitRemoved(t('7')),
      PlanUnitChanged(t('8'), t('7')),
      PlanUnitAdded(t('8')),
      PlanUnitChanged(t('7'), t('7', layer: 'B')),
    ]);
    expect(diffUnitDetails(const [], const [], const [], const []), isEmpty);
  });

  testWidgets(
      'DC15 O7: a listen in service after a service move of 1 takes the '
      'design\'s units, not the copy\'s: back in design, nothing; then '
      'setUnitData on 2 is exactly one Changed for 2 (2b Task 13)',
      (tester) async {
    final c = fixtureController();
    final b2 = detailOf(c, instancesOf(c, '2').single);
    final b1 = detailOf(c, instancesOf(c, '1').single);
    c.setMode(PlanMode.service);
    await tester.pump();
    final one = instancesOf(c, '1').single;
    final fixture = fixtureTable('1');
    final shift = Transform2.translation(1200, -700);
    c.activeDocument.commands
        .execute(TransformNodeCommand(one, shift.multiply(fixture.transform)));
    await tester.pump();
    expect(c.serviceEdited, isTrue, reason: 'premise: a service move');
    expectNear(detailOf(c, one).center,
        boxCentre(shift.multiply(fixture.transform)), 'premise: 1 moved');
    final seen = listen(c);

    c.setMode(PlanMode.design);
    await tester.pump();
    expect(seen, isEmpty, reason: 'a mode switch is no design change');
    expect(detailOf(c, one), b1, reason: 'premise: the design never moved');
    expect(c.setUnitData('2', hostData()), isTrue);
    await tester.pump();
    // M-DC15: the baseline taken from the active (the copy's) units.
    expect(seen, [PlanUnitChanged(b2, copyOf(b2, data: hostData()))],
        reason: 'the service move of 1 is no design change');
  });

  testWidgets(
      'DC16 M-H29(service moves), the trigger alone: an edit then '
      'setMode(service) in one synchronous step is reported at the next '
      'pump, not withheld until the design moves again', (tester) async {
    final c = fixtureController();
    final b2 = detailOf(c, instancesOf(c, '2').single);
    final seen = listen(c);

    expect(c.setUnitData('2', hostData()), isTrue);
    c.setMode(PlanMode.service);
    expect(seen, isEmpty, reason: 'delivered asynchronously');
    await tester.pump();
    expect(seen, [PlanUnitChanged(b2, copyOf(b2, data: hostData()))]);
    expect(c.mode.value, PlanMode.service, reason: 'premise');
  });

  testWidgets(
      'DC17 O10: a failed load reports nothing and drops nothing owed: an '
      'edit, then load of "not json" and of a JSON that is no plan, both '
      'throwing, is exactly the edit\'s Changed, no PlanUnitsReplaced',
      (tester) async {
    final c = fixtureController();
    final b1 = detailOf(c, instancesOf(c, '1').single);
    final seen = listen(c);

    expect(c.setUnitData('1', hostData()), isTrue);
    expect(() => c.load('not json'), throwsFormatException);
    expect(() => c.load('{"x": 1}'), throwsFormatException);
    await tester.pump();
    final changed = PlanUnitChanged(b1, copyOf(b1, data: hostData()));
    expect(seen, [changed]);

    expect(() => c.load('not json'), throwsFormatException);
    await tester.pump();
    expect(seen, [changed], reason: 'nothing owed, nothing reported');
    expect(c.setUnitData('1', {'id': 'next'}), isTrue);
    await tester.pump();
    expect(
        seen,
        [
          changed,
          PlanUnitChanged(changed.after, copyOf(b1, data: {'id': 'next'}))
        ],
        reason: 'the same plan, the same baseline');
  });

  testWidgets(
      'DC18 final review F-1: an edit, a load and dispose() in one '
      'synchronous step deliver nothing -- not the edit\'s Changed nor the '
      'PlanUnitsReplaced the load reported -- and then done', (tester) async {
    final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
    final seen = <PlanUnitChange>[];
    var done = false;
    c.unitChanges.listen(seen.add, onDone: () => done = true);
    expect(c.setUnitData('1', hostData()), isTrue);
    c.load(embeddingPlanJson());
    c.dispose();
    await tester.pump();
    expect(seen, isEmpty);
    expect(done, isTrue);

    // newPlan, too.
    final d = PlanController(kits: [fxKit()], json: embeddingPlanJson());
    final seenD = <PlanUnitChange>[];
    var doneD = false;
    d.unitChanges.listen(seenD.add, onDone: () => doneD = true);
    d.newPlan();
    d.dispose();
    await tester.pump();
    expect(seenD, isEmpty);
    expect(doneD, isTrue);
  });

  testWidgets(
      'DC19 final review F-1: a listener that disposes the controller on the '
      'first change of a report hears no second one, and then done',
      (tester) async {
    final c = PlanController(kits: [fxKit()], json: embeddingPlanJson());
    final seen = <PlanUnitChange>[];
    var done = false;
    c.unitChanges.listen((change) {
      seen.add(change);
      c.dispose();
    }, onDone: () => done = true);
    expect(
        c.setUnitsData({
          '1': {'id': 'one'},
          '2': {'id': 'two'},
        }),
        isTrue);
    await tester.pump();
    expect(seen, hasLength(1), reason: 'the report had two changes');
    expect(seen.single, isA<PlanUnitChanged>());
    expect(done, isTrue);
  });
}
