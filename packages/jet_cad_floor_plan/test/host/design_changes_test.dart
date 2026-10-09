// Host embedding API spec E-5 (Slice 2 plan, Task 3): the controller's
// designChanges -- a design edit, undo or redo reported as the tables
// added, removed and changed, by instance, in ascending instance order;
// FloorPlanPlanReplaced on load and newPlan in either mode, after the old
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
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_floor_plan/src/host/design_changes.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_detail.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';

import 'embedding_fixture.dart';

/// Data as a host writes it: keys out of order, a value with a space, a dot
/// and a non-ASCII letter, an empty value.
Map<String, String> hostData() => {
      'zeta': 'Masa 4.ğ',
      'id': '7f3c-ä',
      'alpha': '',
    };

/// A controller over the fixture, disposed after the test.
FloorPlanController fixtureController() {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// [fixtureController] shown in a design view of 1440 x 900, fitted.
Future<FloorPlanController> mounted(WidgetTester tester) async {
  final c = fixtureController();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FloorPlanView(controller: c))));
  await tester.pump();
  await tester.pump();
  return c;
}

/// Every change [c] reports from now on, in order.
List<FloorPlanDesignChange> listen(FloorPlanController c) {
  final seen = <FloorPlanDesignChange>[];
  final sub = c.designChanges.listen(seen.add);
  addTearDown(sub.cancel);
  return seen;
}

/// The instances of the tables numbered [n] in [c]'s active plan, ascending.
List<Handle> instancesOf(FloorPlanController c, String n) => [
      for (final t in TableSurvey.of(c.activeDocument).withNumber(n)) t.instance
    ];

/// The detail of [instance] in [c]'s current list.
FloorPlanTableDetail detailOf(FloorPlanController c, Handle instance) =>
    c.tableDetails[c.tableDetailInstances.indexOf(instance)];

/// [d] with the fields given replaced.
FloorPlanTableDetail copyOf(FloorPlanTableDetail d,
        {FloorPlanTable? table, bool? locked, Map<String, String>? data}) =>
    FloorPlanTableDetail(
        table: table ?? d.table,
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
        'setTablesData on L, 4 and 1 (in that order) is a Changed for 1, 4 '
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
          c.setTablesData({
            'L': {'id': 'l'},
            '4': hostData(),
            ' 1 ': {'zeta': 'z', 'id': 'one'},
          }),
          isTrue);
      expect(seen, isEmpty, reason: 'delivered asynchronously');
      await tester.pump();
      expect(seen, [
        FloorPlanTableChanged(b1, copyOf(b1, data: {'id': 'one', 'zeta': 'z'})),
        FloorPlanTableChanged(b4, copyOf(b4, data: hostData())),
        FloorPlanTableChanged(bl, copyOf(bl, data: {'id': 'l'})),
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
      final before = c.tableDetails;
      final doc = c.activeDocument;
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
        for (final d in onZero)
          FloorPlanTableChanged(d, copyOf(d, locked: true))
      ]);

      seen.clear();
      c.undo();
      await tester.pump();
      expect(seen, [
        for (final d in onZero)
          FloorPlanTableChanged(copyOf(d, locked: true), d)
      ]);

      seen.clear();
      final hidden = doc.tables.layers.byName(kEmbeddingHidden)!;
      doc.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
      await tester.pump();
      expect(seen, hasLength(1));
      final change = seen.single as FloorPlanTableChanged;
      expect(change.before.table.number, '5');
      expect(change.before.center, isNull, reason: 'hidden: no geometry');
      expect(change.after.table.visible, isTrue);
      expectNear(change.after.center, boxCentre(fixtureTable('5').transform),
          'shown: its box centre, by the forward transform');
      expect(change.after.layer, kEmbeddingHidden);
    });

    testWidgets(
        'DC3 a renumber of 1 to 21: one Changed, the number only, its data '
        'kept', (tester) async {
      final c = await mounted(tester);
      expect(c.setTableData('1', hostData()), isTrue);
      final one = instancesOf(c, '1').single;
      final b1 = detailOf(c, one);
      expect(b1.data, hostData(), reason: 'premise');
      final seen = listen(c);

      final label = TableSurvey.of(c.activeDocument).withNumber('1').single;
      c.activeDocument.commands
          .execute(SetEntityTextCommand(label.label!, '21', kTableLabelTag));
      await tester.pump();
      expect(seen, [
        FloorPlanTableChanged(
            b1,
            copyOf(b1,
                table: FloorPlanTable(
                    number: '21',
                    seats: b1.table.seats,
                    symbolKey: b1.table.symbolKey))),
      ]);
      expect((seen.single as FloorPlanTableChanged).after.data, hostData());
    });

    testWidgets(
        'DC4 setTableData: one Changed, the data only; the same data again '
        'reports nothing; undo and redo report the reverse and the same',
        (tester) async {
      final c = await mounted(tester);
      final two = instancesOf(c, '2').single;
      final b2 = detailOf(c, two);
      expect(b2.mirrored, isTrue, reason: 'premise: 2 is the mirrored one');
      final seen = listen(c);

      expect(c.setTableData('2', hostData()), isTrue);
      await tester.pump();
      final changed = FloorPlanTableChanged(b2, copyOf(b2, data: hostData()));
      expect(seen, [changed]);
      expect(c.setTableData(' 2 ', hostData()), isTrue);
      await tester.pump();
      expect(seen, [changed], reason: 'no edit, no change');

      c.undo();
      await tester.pump();
      expect(seen.last, FloorPlanTableChanged(changed.after, b2));
      c.redo();
      await tester.pump();
      expect(
          seen, [changed, FloorPlanTableChanged(changed.after, b2), changed]);
    });

    testWidgets(
        'DC5 M-H25: deleting 3 is exactly [Removed(3)]; its undo exactly '
        '[Added(3)], equal to it, data included; its redo the Removed again',
        (tester) async {
      final c = await mounted(tester);
      expect(c.setTableData('3', hostData()), isTrue);
      final three = instancesOf(c, '3').single;
      final b3 = detailOf(c, three);
      expectNear(b3.center, boxCentre(fixtureTable('3').transform),
          'premise: 3 where the fixture puts it');
      expect(b3.data, hostData(), reason: 'premise');
      expect(c.tableDetailInstances.last.value > three.value, isTrue,
          reason: 'premise: tables after 3, which an index diff shifts');
      final seen = listen(c);

      c.select({'3'});
      await tester.pump();
      expect(c.selectedTables.value, {'3'}, reason: 'premise');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(c.activeDocument.tree[three], isNull, reason: 'premise: deleted');
      expect(seen, [FloorPlanTableRemoved(b3)]);

      c.undo();
      await tester.pump();
      expect(seen, [FloorPlanTableRemoved(b3), FloorPlanTableAdded(b3)]);
      expect((seen[1] as FloorPlanTableAdded).table,
          (seen[0] as FloorPlanTableRemoved).table);
      expect((seen[1] as FloorPlanTableAdded).table.data, hostData());

      c.redo();
      await tester.pump();
      expect(seen.skip(2), [FloorPlanTableRemoved(b3)]);
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
        c.activeDocument.commands.execute(
            TransformNodeCommand(instance, shift.multiply(fixture.transform)));
        await tester.pump();
        expect(seen, hasLength(1), reason: '"$label"');
        final change = seen.single as FloorPlanTableChanged;
        expect(change.before, before, reason: '"$label"');
        expectNear(change.after.center,
            boxCentre(shift.multiply(fixture.transform)), 'moved by the shift');
        expect(change.after.mirrored, mirrored);
        expect(change.after.rotation, closeTo(before.rotation, 1e-12));
        expect(change.after.table, before.table);
        expect(change.after, detailOf(c, instance));
      }
    });

    testWidgets(
        'DC7 M-H29(service moves): in the selection mode a service drag of '
        '1, its Undo, its Redo, resetLayout and restoreServiceLayout '
        'report nothing; back in the design mode an edit is reported',
        (tester) async {
      final c = await mounted(tester);
      final seen = listen(c);
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      final camera = embeddingCamera();
      c.cameraController.value = camera;
      await tester.pump();
      final one = fixtureTable('1');
      final w = boxCentre(one.transform);
      final p = canvasOf(camera, w.dx, w.dy);
      final origin = tester.getTopLeft(find.byType(InteractionLayer));
      final before = c.tableDetails.first;
      expect(before.table.number, '1', reason: 'premise');

      final g = await tester.startGesture(origin + Offset(p.x, p.y));
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(40, 25));
      await g.up();
      await tester.pump();
      expect(c.serviceEdited, isTrue, reason: 'premise: a service move');
      expect(c.tableDetails.first.center == before.center, isFalse,
          reason: 'premise: 1 moved in the copy');
      final layout = c.serviceLayoutJson()!;
      c.undo();
      await tester.pump();
      expect(c.serviceEdited, isFalse, reason: 'premise: undone');
      c.redo();
      await tester.pump();
      expect(c.serviceEdited, isTrue, reason: 'premise: redone');
      c.resetLayout();
      await tester.pump();
      c.restoreServiceLayout(layout);
      await tester.pump();
      expect(c.serviceEdited, isTrue, reason: 'premise: restored');
      expect(seen, isEmpty);

      c.setMode(FloorPlanMode.design);
      await tester.pump();
      expect(seen, isEmpty, reason: 'a mode switch is no design change');
      expect(c.setTableData('1', hostData()), isTrue);
      await tester.pump();
      expect(seen,
          [FloorPlanTableChanged(before, copyOf(before, data: hostData()))],
          reason: 'the listener is live; the design never moved');
    });

    testWidgets(
        'DC8 newPlan: exactly [FloorPlanPlanReplaced()], no Removed per '
        'table; a load: the same', (tester) async {
      final c = await mounted(tester);
      final seen = listen(c);
      c.newPlan();
      await tester.pump();
      expect(seen, [const FloorPlanPlanReplaced()]);
      expect(c.tableDetails, isEmpty, reason: 'premise: an empty plan');
      c.load(embeddingPlanJson());
      await tester.pump();
      expect(
          seen, [const FloorPlanPlanReplaced(), const FloorPlanPlanReplaced()]);
    });

    testWidgets(
        'DC9 an edit then a load in one synchronous step: the edit\'s change, '
        'then FloorPlanPlanReplaced, then an edit of the loaded plan',
        (tester) async {
      final c = await mounted(tester);
      final b2 = detailOf(c, instancesOf(c, '2').single);
      final seen = listen(c);

      expect(c.setTableData('2', hostData()), isTrue);
      c.load(embeddingPlanJson());
      final l = detailOf(c, instancesOf(c, 'L').single);
      expect(c.setTableData('L', {'id': 'l'}), isTrue);
      expect(seen, isEmpty, reason: 'delivered asynchronously');
      await tester.pump();
      expect(seen, [
        FloorPlanTableChanged(b2, copyOf(b2, data: hostData())),
        const FloorPlanPlanReplaced(),
        FloorPlanTableChanged(l, copyOf(l, data: {'id': 'l'})),
      ]);
    });
  });

  testWidgets(
      'DC10 M-H29(PlanReplaced in the selection mode): there, a load is '
      'exactly [FloorPlanPlanReplaced()], and so is a newPlan', (tester) async {
    final c = fixtureController();
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    final seen = listen(c);
    c.load(embeddingPlanJson());
    await tester.pump();
    expect(seen, [const FloorPlanPlanReplaced()]);
    c.newPlan();
    await tester.pump();
    expect(
        seen, [const FloorPlanPlanReplaced(), const FloorPlanPlanReplaced()]);
    expect(c.mode.value, FloorPlanMode.selection, reason: 'premise');
  });

  testWidgets(
      'DC11 nothing is read with no listener, nor after the last cancel; one '
      'read per listen and per moved design; two edits of one synchronous '
      'step are one read and one report', (tester) async {
    final c = fixtureController();
    final doc = c.activeDocument;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    expect(c.setTableData('1', hostData()), isTrue);
    doc.commands.execute(SetLayerCommand(zero.copyWith(locked: true)));
    c.undo();
    c.redo();
    await tester.pump();
    c.load(embeddingPlanJson());
    c.newPlan();
    c.load(embeddingPlanJson());
    await tester.pump();
    expect(c.designScans, 0, reason: 'no listener: nothing read');

    final first = <FloorPlanDesignChange>[];
    final a = c.designChanges.listen(first.add);
    expect(c.designScans, 1, reason: 'the baseline');
    final second = <FloorPlanDesignChange>[];
    final b = c.designChanges.listen(second.add);
    expect(c.designScans, 1, reason: 'one baseline for every listener');

    final one = instancesOf(c, '1').single;
    final b1 = detailOf(c, one);
    expect(c.setTableData('1', {'id': 'a'}), isTrue);
    expect(c.setTableData('1', {'id': 'b'}), isTrue);
    await tester.pump();
    expect(c.designScans, 2, reason: 'the second event finds nothing new');
    final change = FloorPlanTableChanged(b1, copyOf(b1, data: {'id': 'b'}));
    expect(first, [change]);
    expect(second, [change]);

    // Not awaited: awaiting a cancel here left the next pump hanging (seen
    // while writing this test); the cancel itself is synchronous.
    unawaited(a.cancel());
    expect(c.setTableData('1', {'id': 'c'}), isTrue);
    await tester.pump();
    expect(c.designScans, 3, reason: 'one listener left');
    expect(second, [change, isA<FloorPlanTableChanged>()]);
    expect(first, [change]);

    unawaited(b.cancel());
    final scans = c.designScans;
    expect(c.setTableData('1', {'id': 'd'}), isTrue);
    c.undo();
    await tester.pump();
    c.load(embeddingPlanJson());
    c.newPlan();
    await tester.pump();
    expect(c.designScans, scans, reason: 'after the last cancel: nothing');

    c.load(embeddingPlanJson());
    await tester.pump();
    expect(c.designScans, scans, reason: 'premise: still nothing');
    final two = detailOf(c, instancesOf(c, '2').single);
    expect(c.setTableData('2', {'id': 'before'}), isTrue);
    final third = listen(c);
    expect(c.designScans, scans + 1, reason: 'a new baseline');
    await tester.pump();
    expect(third, isEmpty,
        reason: 'an edit made before the listen is not owed');
    expect(c.setTableData('2', hostData()), isTrue);
    await tester.pump();
    expect(third, [
      FloorPlanTableChanged(
          copyOf(two, data: {'id': 'before'}), copyOf(two, data: hostData()))
    ]);
    expect(c.designScans, scans + 2);
  });

  testWidgets(
      'DC12 dispose closes the stream: an edit made just before it is not '
      'reported, and nothing comes after', (tester) async {
    final c = FloorPlanController(json: embeddingPlanJson());
    final seen = <FloorPlanDesignChange>[];
    var done = false;
    c.designChanges.listen(seen.add, onDone: () => done = true);
    expect(c.setTableData('1', hostData()), isTrue);
    c.dispose();
    await tester.pump();
    expect(seen, isEmpty);
    expect(done, isTrue);
  });

  test('DC13 the four changes: ==, hashCode and toString', () {
    const table = FloorPlanTable(number: '7', seats: 4, symbolKey: 'k');
    const a = FloorPlanTableDetail(
        table: table,
        center: Offset(46100.5, -30900.4),
        size: Size(800, 600),
        rotation: 1.25,
        mirrored: true,
        corners: [Offset(1, 2), Offset(3, 4), Offset(5, 6), Offset(7, 8)],
        layer: 'Locked',
        locked: true,
        data: {'id': 'x'});
    const b = FloorPlanTableDetail(
        table: table,
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: [],
        layer: '0',
        locked: false);
    final a2 = FloorPlanTableDetail(
        table: const FloorPlanTable(number: '7', seats: 4, symbolKey: 'k'),
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

    expect(FloorPlanTableAdded(a), FloorPlanTableAdded(a2));
    expect(FloorPlanTableAdded(a).hashCode, FloorPlanTableAdded(a2).hashCode);
    expect(FloorPlanTableAdded(a) == FloorPlanTableAdded(b), isFalse);
    expect(FloorPlanTableAdded(a) == FloorPlanTableRemoved(a), isFalse);
    expect(FloorPlanTableRemoved(a), FloorPlanTableRemoved(a2));
    expect(
        FloorPlanTableRemoved(a).hashCode, FloorPlanTableRemoved(a2).hashCode);
    expect(FloorPlanTableRemoved(a) == FloorPlanTableRemoved(b), isFalse);
    expect(FloorPlanTableChanged(a, b), FloorPlanTableChanged(a2, b));
    expect(FloorPlanTableChanged(a, b).hashCode,
        FloorPlanTableChanged(a2, b).hashCode);
    expect(FloorPlanTableChanged(a, b) == FloorPlanTableChanged(b, a), isFalse,
        reason: 'before and after are ordered');
    expect(FloorPlanTableChanged(a, b) == FloorPlanTableChanged(a, a), isFalse);
    expect(const FloorPlanPlanReplaced(), const FloorPlanPlanReplaced());
    expect(const FloorPlanPlanReplaced().hashCode,
        const FloorPlanPlanReplaced().hashCode);
    expect(const FloorPlanPlanReplaced() == FloorPlanTableAdded(a), isFalse);

    const ta = 'FloorPlanTableDetail(FloorPlanTable(7, 4, k, visible: true), '
        'center: Offset(46100.5, -30900.4), size: Size(800.0, 600.0), '
        'rotation: 1.25, mirrored: true, corners: [Offset(1.0, 2.0), '
        'Offset(3.0, 4.0), Offset(5.0, 6.0), Offset(7.0, 8.0)], '
        'layer: Locked, locked: true, data: {id: x})';
    const tb = 'FloorPlanTableDetail(FloorPlanTable(7, 4, k, visible: true), '
        'center: null, size: null, rotation: 0.0, mirrored: false, '
        'corners: [], layer: 0, locked: false, data: {})';
    expect(FloorPlanTableAdded(a).toString(), 'FloorPlanTableAdded($ta)');
    expect(FloorPlanTableRemoved(b).toString(), 'FloorPlanTableRemoved($tb)');
    expect(FloorPlanTableChanged(a, b).toString(),
        'FloorPlanTableChanged($ta, $tb)');
    expect(const FloorPlanPlanReplaced().toString(), 'FloorPlanPlanReplaced()');
  });

  test('DC14 the diff: by instance, ascending, whatever the numbers', () {
    FloorPlanTableDetail t(String? n, {String layer = '0'}) =>
        FloorPlanTableDetail(
            table: FloorPlanTable(number: n, seats: 2, symbolKey: null),
            center: null,
            size: null,
            rotation: 0,
            mirrored: false,
            corners: const [],
            layer: layer,
            locked: false);
    // 0x31 removed, 0x33 renumbered to the removed one's number, 0x34
    // unchanged, 0x35 added, 0x36 moved to another layer.
    final changes = diffTableDetails(
        const [Handle(0x31), Handle(0x33), Handle(0x34), Handle(0x36)],
        [t('7'), t('8'), t(null), t('7')],
        const [Handle(0x33), Handle(0x34), Handle(0x35), Handle(0x36)],
        [t('7'), t(null), t('8'), t('7', layer: 'B')]);
    expect(changes, [
      FloorPlanTableRemoved(t('7')),
      FloorPlanTableChanged(t('8'), t('7')),
      FloorPlanTableAdded(t('8')),
      FloorPlanTableChanged(t('7'), t('7', layer: 'B')),
    ]);
    expect(diffTableDetails(const [], const [], const [], const []), isEmpty);
  });
}
