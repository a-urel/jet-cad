// 2b spec S4 "The service tool", "A drag"; S2 "Locked units", "Unlabelled,
// duplicate and bad labels"; Review Focus 4: the service tool over placed
// and generated units, on the controller's service copy. The fixture is
// Task 5's serviceFixture(): a table a quarter turn and mirrored off the
// origin, row A (six seats) turned, row B (five seats) curved, all off the
// origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_state.dart' show UnitGroup;
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/service_fixture.dart';
import '../support/service_rig.dart';

/// [json] in service over `unitKit()`, or over no kit ([missingKit]: the
/// table and both rows are then held by the lock set).
ServiceRig rig(String json,
    {bool missingKit = false, void Function(PlanController c)? design}) {
  final r = ServiceRig(json,
      kits: missingKit ? const <PlanKit>[] : null, design: design);
  addTearDown(r.dispose);
  return r;
}

void main() {
  testWidgets(
      'ST-seat a seat is picked, selected alone and reported by its label; '
      'a seat in a group selects the group and reports it (M-ST-seat)',
      (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final a3 = f.seatsA[2], b2 = f.seatsB[1], b3 = f.seatsB[2];
    expect(r.c.unitIndex[a3]!.generated, isTrue, reason: 'premise: a seat');
    r.c.setUnitGroups({
      'g': UnitGroup(members: {'B2', 'B3'})
    });

    r.tap(r.inside(a3));
    expect(r.keys, {r.key(a3)});
    expect(r.taps, ['A3']);
    expect(r.c.selectedUnits.value, {'A3'});

    r.tap(r.inside(b2), time: const Duration(seconds: 1));
    expect(r.keys, {r.key(b2), r.key(b3)});
    expect(r.taps, ['A3', 'B2']);
    expect(r.groupTaps, ['g:B2']);
  });

  testWidgets(
      'ST-mixed-drag a drag from the table with two seats selected moves the '
      'table alone, translation only, one step; the seats stay '
      '(M-ST-mixed)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table, a1 = f.seatsA[0], a2 = f.seatsA[1];
    r.tap(r.inside(t));
    r.tap(r.inside(a1), shift: true);
    r.tap(r.inside(a2), shift: true);
    expect(r.keys, {r.key(t), r.key(a1), r.key(a2)}, reason: 'premise');
    final table0 = parts(r.node(t).transform);
    final seats0 = [parts(r.node(a1).transform), parts(r.node(a2).transform)];
    final from = r.inside(t);
    final by = Vector2(600, -300);
    final dx = (from.x + by.x) - from.x, dy = (from.y + by.y) - from.y;

    r.drag(from, by);
    expect(parts(r.node(t).transform),
        [...table0.take(4), table0[4] + dx, table0[5] + dy]);
    expect(parts(r.node(a1).transform), seats0[0]);
    expect(parts(r.node(a2).transform), seats0[1]);
    expect(r.layouts, 1);
    expect(r.moved, [
      [t]
    ]);
    expect(r.keys, {r.key(t), r.key(a1), r.key(a2)},
        reason: 'the selection is kept');
  });

  testWidgets(
      'ST-group-seat a group mixing the table and a seat is never dragged: '
      'the drag is spent, nothing moves, the selection is kept '
      '(M-ST-group)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table, a1 = f.seatsA[0];
    final label = r.c.unitIndex[t]!.text!;
    r.c.setUnitGroups({
      'g': UnitGroup(members: {label, 'A1'})
    });
    r.tap(r.inside(t));
    expect(r.keys, {r.key(t), r.key(a1)}, reason: 'premise: the group');
    final table0 = parts(r.node(t).transform);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(parts(r.node(t).transform), table0);
    expect(r.layouts, 0);
    expect(r.moved, isEmpty);
    expect(r.keys, {r.key(t), r.key(a1)});
  });

  testWidgets(
      'ST-locked-seat Review Focus 4: the kit missing, a seat is tapped and '
      'reported with its group, never selected by a tap, a long press, a '
      'band or a context click, never dragged (M-ST-locked)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json, missingKit: true);
    final a2 = f.seatsA[1];
    expect(r.c.unitIndex[a2]!.locked, isTrue, reason: 'premise: locked');
    expect(r.c.unitIndex[a2]!.generated, isTrue, reason: 'premise: a seat');
    r.c.setUnitGroups({
      'g': UnitGroup(members: {'A2', 'A3'})
    });

    r.tap(r.inside(a2));
    expect(r.taps, ['A2']);
    expect(r.groupTaps, ['g:A2']);
    expect(r.keys, isEmpty, reason: 'a tap selects nothing');
    // A group's selectable members exclude a locked one, so a grouped tap
    // selects nothing either way: a lone locked seat pins the rule itself.
    r.tap(r.inside(f.seatsA[4]), time: const Duration(seconds: 1));
    expect(r.taps, ['A2', 'A5']);
    expect(r.keys, isEmpty, reason: 'a lone locked seat\'s tap selects none');

    // Under toggle a locked press starts no timer (T:236-243): held past
    // the long press, it is a tap.
    r.down(r.inside(a2), time: const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    r.up(r.inside(a2), time: const Duration(seconds: 3));
    expect(r.keys, isEmpty, reason: 'a long press selects nothing');

    r.band(padded(unionOf([for (final s in f.seatsA) r.worldBox(s)]), 400),
        crossing: true);
    expect(r.keys, isEmpty, reason: 'a band selects nothing');

    r.withMenu();
    r.tool.secondaryClick(r.inside(a2), const Offset(12, 34), r.ctx.selection);
    expect(r.menus, [('A2', const Offset(12, 34))]);
    expect(r.keys, isEmpty, reason: 'a context click selects nothing');

    r.options = kDefaultServiceOptions;
    final seat0 = parts(r.node(a2).transform);
    r.drag(r.inside(a2), Vector2(600, -300));
    expect(parts(r.node(a2).transform), seat0);
    expect(r.layouts, 0);
    expect(r.moved, isEmpty);
  });

  testWidgets(
      'ST-unlabelled an unlabelled table is selected by a tap and dragged, '
      'reported by onUnitsMoved, never by a label-keyed callback '
      '(M-ST-unlabelled)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json, design: (c) {
      for (final (label, _) in unitLabelsOf(c.document, f.table)) {
        expect(
            c.execute(SetEntityTextCommand(label, '', kUnitLabelTag)), isTrue);
      }
    });
    final t = f.table;
    expect(r.c.unitIndex[t]!.text, isNull, reason: 'premise: unlabelled');

    r.tap(r.inside(t));
    r.tap(r.inside(t), time: const Duration(milliseconds: 100));
    expect(r.keys, {r.key(t)});
    expect(r.taps, isEmpty);
    expect(r.doubleTaps, isEmpty);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(r.layouts, 1);
    expect(r.moved, [
      [t]
    ]);
  });

  testWidgets(
      'ST-band-two-rows a crossing band over both rows takes every seat of '
      'both as a root key and not the table; a window round row B takes row '
      'B\'s seats alone (M-ST-band)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final rows = unionOf([
      for (final s in [...f.seatsA, ...f.seatsB]) r.worldBox(s)
    ]);
    final rowB = unionOf([for (final s in f.seatsB) r.worldBox(s)]);
    expect(overlaps(padded(rows, 50), r.worldBox(f.table)), isFalse,
        reason: 'premise: the table lies off both rows');
    for (final s in f.seatsA) {
      expect(overlaps(padded(rowB, 50), r.worldBox(s)), isFalse,
          reason: 'premise: row A lies off row B\'s window');
    }

    r.band(padded(rows, 50), crossing: true);
    expect(r.keys, {
      for (final s in [...f.seatsA, ...f.seatsB]) r.key(s)
    });

    r.band(padded(rowB, 50));
    expect(r.keys, {for (final s in f.seatsB) r.key(s)});
  });

  testWidgets(
      'ST-secondary a context click on an unselected seat selects it alone '
      'and reports its label; on a selected unit it keeps the selection; '
      'with no menu it does nothing (M-ST-secondary)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final a1 = f.seatsA[0], t = f.table;
    r.withMenu();
    r.tool.secondaryClick(r.inside(a1), const Offset(5, 6), r.ctx.selection);
    expect(r.keys, {r.key(a1)});
    expect(r.menus, [('A1', const Offset(5, 6))]);

    r.tap(r.inside(t), shift: true);
    final label = r.c.unitIndex[t]!.text!;
    r.tool.secondaryClick(r.inside(t), const Offset(7, 8), r.ctx.selection);
    expect(r.keys, {r.key(a1), r.key(t)}, reason: 'a selected unit keeps it');
    expect(r.menus.last, (label, const Offset(7, 8)));

    r.options = kDefaultServiceOptions;
    r.ctx.selection.clear();
    r.tool.secondaryClick(r.inside(a1), const Offset(5, 6), r.ctx.selection);
    expect(r.keys, isEmpty, reason: 'no menu: nothing');
    expect(r.menus, hasLength(2));
  });

  testWidgets(
      'ST-move-gate serviceMove false: a drag from the table pans, the '
      'table stays; the permission is read at each press (M-ST-gate)',
      (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table;
    final table0 = parts(r.node(t).transform);
    r.c.permissions = r.c.permissions.copyWith(serviceMove: false);
    final camera0 = parts(r.c.camera.value.worldToScreenMatrix);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(parts(r.node(t).transform), table0);
    expect(r.layouts, 0);
    expect(parts(r.c.camera.value.worldToScreenMatrix), isNot(camera0),
        reason: 'the drag panned');

    r.c.permissions = r.c.permissions.copyWith(serviceMove: true);
    r.drag(r.inside(t), Vector2(600, -300));
    expect(r.layouts, 1, reason: 'read again at the next press');
  });
}
