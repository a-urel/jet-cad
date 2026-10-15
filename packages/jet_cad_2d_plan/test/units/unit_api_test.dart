// 2b Task 9, spec S3 "The unit API" and S2 "Per-unit data": the units of
// the design, placed and generated, their details and data, the design
// writes and their refusals, select and fitToUnits in design, and
// unitChanges for a row edit. Over Task 5's service fixture (a turned,
// mirrored table off the origin; two seats-only rows, one turned, one
// curved) and Task 8's editor fixture (the units 1 and 2 placed).
import 'package:flutter/painting.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/test_kit.dart';
import '../support/unit_editor_fixture.dart' show unitEditorPlanJson;
import '../support/unit_fixtures.dart' show fxKit;

PlanController design() =>
    controllerFor(kits: [unitKit()], json: serviceFixture().json);

/// The units of [c] labelled [prefix]1, [prefix]2, … (one row's seats).
List<UnitInfo> seatsLabelled(PlanController c, String prefix) => [
      for (final u in c.unitIndex.units)
        if (u.generated && (u.text?.startsWith(prefix) ?? false)) u,
    ];

/// The row whose seats are labelled [prefix]….
Handle rowOf(PlanController c, String prefix) =>
    seatsLabelled(c, prefix).first.owner!;

/// One edit: [row]'s seat count set to [n] (Task 5's row component).
void setRowCount(PlanController c, Handle row, int n) {
  final p = c.document.components.get<RowComponent>(row)!;
  expect(
      c.execute(SetComponentCommand<RowComponent>(row, p.copyWith(count: n))),
      isTrue);
}

/// One edit: [row]'s label prefix set to [prefix].
void setRowPrefix(PlanController c, Handle row, String prefix) {
  final p = c.document.components.get<RowComponent>(row)!;
  expect(
      c.execute(
          SetComponentCommand<RowComponent>(row, p.copyWith(prefix: prefix))),
      isTrue);
}

PlanUnitDetail detailOf(PlanController c, String label) =>
    c.unitDetails.singleWhere((d) => d.unit.label == label);

/// The placed table's label (the fixture's one placed unit).
String tableLabel(PlanController c) =>
    c.unitIndex.units.singleWhere((u) => !u.generated).text!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'UA-units the design\'s units: the placed table and every seat, '
      'ascending by instance; a seat names its row\'s type', () {
    final c = design();
    final units = c.units;
    final index = c.unitIndex.units;
    expect(units, hasLength(index.length));
    expect(units.where((u) => u.generatedBy == null), hasLength(1));
    // M-UA0: `generatedBy: u.ownerType` written `generatedBy: null`.
    expect(units.where((u) => u.generatedBy == 'test.row').length,
        index.length - 1);
    final seat = units.firstWhere((u) => u.generatedBy != null);
    expect((seat.kind, seat.capacity), (UnitKinds.seat, 1));
    expect(c.unitDetails.map((d) => d.unit), units);
  });

  test(
      'UA-shrink-data a row of 12 seats carrying data and a colour shrunk to '
      '10: seats 1-10 keep their handles, data and colour; 11 and 12 '
      'vanish; undo brings them back with theirs (Review Focus 1)', () {
    final c = design();
    final row = rowOf(c, 'A');
    setRowCount(c, row, 12);
    final labels = [for (var i = 1; i <= 12; i++) 'A$i'];
    expect(
        c.setUnitsData({
          for (final l in labels) l: {'pos': l.toLowerCase()}
        }),
        isTrue);
    expect(c.setUnitColour('A11', PlanSwatch.teal), isTrue);
    expect(c.setUnitColour('A3', PlanSwatch.purple), isTrue);
    final handles = {
      for (final u in seatsLabelled(c, 'A')) u.text!: u.instance,
    };
    expect(handles.keys.toSet(), labels.toSet(), reason: 'premise');
    setRowCount(c, row, 10);
    for (var i = 1; i <= 10; i++) {
      final l = 'A$i';
      expect(c.unitIndex.withLabel(l).single.instance, handles[l], reason: l);
      // M-UA1: _detailsOf reading the data of `u.definition`.
      expect(detailOf(c, l).data, {'pos': l.toLowerCase()}, reason: l);
    }
    expect(detailOf(c, 'A3').colour, PlanSwatch.purple);
    expect(c.unitIndex.withLabel('A11'), isEmpty);
    expect(c.unitIndex.withLabel('A12'), isEmpty);
    c.undo();
    expect(c.unitIndex.withLabel('A11').single.instance, handles['A11']);
    expect(detailOf(c, 'A11').data, {'pos': 'a11'});
    expect(detailOf(c, 'A11').colour, PlanSwatch.teal);
    expect(detailOf(c, 'A12').data, {'pos': 'a12'});
  });

  test(
      'UA-seat-data data and a colour on a seat of the turned row: the '
      'write passes the guard, the detail reads them, its geometry is the '
      'seat\'s world place', () {
    final c = design();
    final seat = seatsLabelled(c, 'B')[1];
    final label = seat.text!;
    // M-UA2 (Task 2's guard, cross-check): the components-only write on a
    // generated instance refused.
    expect(c.setUnitData(label, const {'id': 'b2'}), isTrue);
    expect(c.setUnitColour(label, PlanSwatch.orange), isTrue);
    final d = detailOf(c, label);
    expect(d.data, {'id': 'b2'});
    expect(d.colour, PlanSwatch.orange);
    final box = c.document
        .definitionBounds(seat.definition, c.document.leavesByOwner());
    final centre = c.document.tree
        .accumulatedTransform(seat.instance)
        .transformPoint(
            Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2));
    expect(d.center!.dx, closeTo(centre.x, 1e-9));
    expect(d.center!.dy, closeTo(centre.y, 1e-9));
  });

  test(
      'UA-locked-write under a frozen row a seat takes no data, no colour '
      'and no label: false, no step, no lock hint', () {
    final c = design();
    final row = rowOf(c, 'A');
    c.lockBroken({row});
    final depth = c.document.commands.undoDepth;
    // M-UA3: the lock-set check removed (execute refuses, the hint shows).
    expect(c.setUnitData('A1', const {'id': 'x'}), isFalse);
    expect(c.setUnitColour('A1', PlanSwatch.red), isFalse);
    // M-UA-seat-label: setUnitsLabel's generated-or-locked refusal removed.
    expect(c.setUnitLabel('A1', 'Z9'), isFalse);
    expect(c.lockHint.value, isFalse);
    expect(c.document.commands.undoDepth, depth);
    // The placed table is not under the frozen row: it takes data.
    expect(c.setUnitData(tableLabel(c), const {'id': 't'}), isTrue);
  });

  test(
      'UA-locked-label the kit missing, the placed table is held by the lock '
      'set: setUnitLabel is false, no step, no lock hint (final review M-3, '
      'M-UA-lock-label)', () {
    final c = controllerFor(kits: const [], json: serviceFixture().json);
    final table = c.unitIndex.units.singleWhere((u) => !u.generated);
    expect(table.locked, isTrue, reason: 'premise: under the lock set');
    final label = table.text!;
    final depth = c.document.commands.undoDepth;
    expect(c.setUnitLabel(label, '77'), isFalse);
    expect(c.lockHint.value, isFalse, reason: 'a host call raises no hint');
    expect(c.document.commands.undoDepth, depth);
    expect(c.unitIndex.withLabel(label), hasLength(1));
  });

  test(
      'UA-unitAt-seat unitAt finds a seat at its centre, in design and in '
      'service (final review M-2, M-UA-at-seat)', () {
    final c = design();
    Offset at(String label) {
      final centre = detailOf(c, label).center!;
      final p = c.camera.value.worldToScreen(Vector2(centre.dx, centre.dy));
      return Offset(p.x, p.y);
    }

    expect(c.unitIndex.withLabel('A3').single.generated, isTrue,
        reason: 'premise: a seat');
    expect(c.unitAt(at('A3')), 'A3');
    c.setMode(PlanMode.service);
    expect(c.unitAt(at('B2')), 'B2');
    expect(c.unitAt(at('A3')), 'A3');
  });

  test(
      'UA-label-used a label another unit holds is refused, a seat\'s '
      'included; a free one is one Label step', () {
    final c = design();
    final table = tableLabel(c);
    final depth = c.document.commands.undoDepth;
    // M-UA4: the check against the other units' labels removed.
    expect(c.setUnitLabel(table, 'A1'), isFalse);
    expect(c.document.commands.undoDepth, depth);
    expect(c.setUnitLabel(table, ' 77 '), isTrue);
    expect(c.unitIndex.withLabel('77').single.generated, isFalse);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(() => c.setUnitLabel('77', 'ninechars'), throwsArgumentError);
    expect(() => c.setUnitLabel('77', 'a\nb'), throwsArgumentError);
  });

  test('UA-label-seat a seat\'s label is its type\'s: setUnitLabel is false',
      () {
    final c = design();
    final seat = seatsLabelled(c, 'A').first;
    final text =
        c.document.entities.textAt(c.document.entities.slotOf(seat.label!)!);
    // M-UA5: `u.generated ||` dropped (the ATTRIB edit reaches the guard).
    expect(c.setUnitLabel(seat.text!, 'Z9'), isFalse);
    expect(c.document.entities.textAt(c.document.entities.slotOf(seat.label!)!),
        text);
  });

  test(
      'UA-labels-swap setUnitsLabel swaps two tables\' labels in one step; '
      'setUnitLabel alone to a held label is false', () {
    final c = controllerFor(kits: [fxKit()], json: unitEditorPlanJson());
    final one = c.unitIndex.withLabel('1').single.instance;
    final two = c.unitIndex.withLabel('2').single.instance;
    expect(c.setUnitLabel('1', '2'), isFalse);
    final depth = c.document.commands.undoDepth;
    // M-UA6: the after-call check reading the current labels only.
    expect(c.setUnitsLabel({'1': '2', '2': '1'}), isTrue);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(c.unitIndex.withLabel('1').single.instance, two);
    expect(c.unitIndex.withLabel('2').single.instance, one);
    expect(c.setUnitsLabel({'1': '9', '2': '9'}), isFalse,
        reason: 'one label twice');
  });

  test(
      'UA-select-design select in design takes placed units only: a seat\'s '
      'label is ignored', () {
    final c = design();
    final table = c.unitIndex.units.singleWhere((u) => !u.generated);
    // M-UA7: `if (placedOnly && u.generated) continue;` removed.
    c.select({'A1', table.text!});
    expect(c.selection.keys, {SelectionKey.root(table.instance)});
    expect(c.editorSelectedUnits.value, {table.text});
  });

  test(
      'UA-fit-seat fitToUnits frames a seat by its label: true, and the '
      'framing is not the page\'s', () {
    final c = design();
    // M-UA8: generated units skipped in the units' bounds.
    expect(c.fitToUnits({'B1'}), isTrue);
    expect(c.framingFor(const Size(1440, 900)), isNotNull);
    expect(c.fitToUnits({'nope'}), isFalse);
  });

  test(
      'UA-changes-row a row edit reports one change per changed seat, an '
      'add or a remove per seat grown or shrunk, and a relabel as a change',
      () async {
    final c = design();
    final row = rowOf(c, 'A');
    final n = seatsLabelled(c, 'A').length;
    final seen = <PlanUnitChange>[];
    final sub = c.unitChanges.listen(seen.add);
    addTearDown(sub.cancel);
    setRowCount(c, row, n + 2);
    await Future<void>.delayed(Duration.zero);
    expect(seen.whereType<PlanUnitAdded>(), hasLength(2));
    expect(seen.whereType<PlanUnitRemoved>(), isEmpty);
    seen.clear();
    setRowCount(c, row, n);
    await Future<void>.delayed(Duration.zero);
    expect(seen.whereType<PlanUnitRemoved>(), hasLength(2));
    expect(seen.whereType<PlanUnitAdded>(), isEmpty);
    seen.clear();
    setRowPrefix(c, row, 'C');
    await Future<void>.delayed(Duration.zero);
    // M-UA9: the diff matching by label (a relabel as a remove and an add).
    expect(seen, hasLength(n));
    expect(seen, everyElement(isA<PlanUnitChanged>()));
    expect(seen.cast<PlanUnitChanged>().map((ch) => ch.after.unit.label),
        [for (var i = 1; i <= n; i++) 'C$i']);
  });
}
