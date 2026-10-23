// Ported from jet_cad_floor_plan/test/host/table_groups_toolbar_test.dart;
// assertions unchanged.
//
// Ports TB1-TB7 (all seven); none is left to Part B.
//
// Table-groups spec G5 (2b spec S4 "The service bar"): the service bar's
// Merge and Split, through the real `PlanServiceView`. Units are placed off
// the origin, turned and mirrored (one an asymmetric trapezoid), labelled
// out of handle order (`G7` holds 12, 3 and 7); one sits on a locked layer
// and one on a hidden layer; two are unlabelled; a variant carries a label
// twice (a hand-edited file). The camera is off the origin at 0.06 px per
// mm. The selection is made by mouse taps (Shift adds) and
// `controller.select`.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart' show UnitInfo;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/service_fixtures.dart';
import '../../support/service_host.dart' show byKey, serviceController;

/// The camera: world (0, 0) at screen (690, 420), 0.06 px per mm, y up.
const double kScale = 0.06;

UnitGroup group(Set<String> members) => UnitGroup(members: members);

/// The view under test and what its host heard.
final class Host {
  Host(this.c);

  final PlanController c;

  /// `merge <labels>` per `onMergeRequested` (the set as received) and
  /// `split <id>` per `onSplitRequested`, in the order heard.
  final List<Object> heard = [];

  /// The sets `onMergeRequested` received, in order.
  final List<Set<String>> merged = [];

  DraftDocument get doc => c.activeDocument;
}

Widget view(Host h, {bool merge = true, bool split = true}) => MaterialApp(
    home: Scaffold(
        body: PlanServiceView(
            controller: h.c,
            onMergeRequested: merge
                ? (labels) {
                    h.merged.add(labels);
                    h.heard.add('merge');
                  }
                : null,
            onSplitRequested: split ? (id) => h.heard.add('split $id') : null,
            onUnitTap: (_) {})));

/// The source mounted first and switched after; the view alone shows
/// nothing until the switch, so it is switched first here.
Future<Host> mount(WidgetTester tester,
    {bool duplicate = false, bool merge = true, bool split = true}) async {
  final c = serviceController(json: toolbarPlanJson(duplicate: duplicate));
  final host = Host(c);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  c.setMode(PlanMode.service);
  await tester.pumpWidget(view(host, merge: merge, split: split));
  await tester.pump();
  await tester.pump();
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(kScale, 0, 0, -kScale, 690, 420));
  await tester.pump();
  return host;
}

/// The placement point of [unit] on the screen, in the test's coordinates.
Offset onSurveyed(WidgetTester tester, Host h, UnitInfo unit) {
  final node = h.doc.tree[unit.instance]! as InstanceNode;
  final trapezoid = unit.symbolKey == trapezoidTable.key;
  final w = node.transform
      .transformPoint(trapezoid ? Vector2(900, 650) : Vector2(900, 700));
  final s = h.c.camera.value.worldToScreen(w);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// The [which]th unit labelled [n] on the screen.
Offset onTable(WidgetTester tester, Host h, String n, {int which = 0}) =>
    onSurveyed(tester, h, h.c.unitIndex.withLabel(n)[which]);

/// The [which]th unlabelled unit on the screen.
Offset onUnnumbered(WidgetTester tester, Host h, int which) => onSurveyed(
    tester,
    h,
    h.c.unitIndex.units.where((u) => u.text == null).elementAt(which));

Future<void> tap(WidgetTester tester, Offset p, {bool add = false}) async {
  if (add) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(p, kind: PointerDeviceKind.mouse);
  if (add) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

bool enabled(WidgetTester tester, String k) =>
    tester.widget<IconButton>(byKey(k)).onPressed != null;

/// Merge's and Split's enabled flags, as `(merge, split)`.
(bool, bool) flags(WidgetTester tester) =>
    (enabled(tester, 'service-merge'), enabled(tester, 'service-split'));

Future<void> press(WidgetTester tester, String k) async {
  await tester.tap(byKey(k));
  await tester.pump();
}

int selectedCount(Host h) => h.c.activeSelection.keys.length;

void main() {
  testWidgets(
      'TB1 Merge: disabled for one table, two unnumbered tables, a numbered '
      'plus an unnumbered table and exactly one whole group; enabled for '
      'two numbered tables and a group plus a table, reporting exactly '
      'selectedTables (M-TG-16)', (tester) async {
    final h = await mount(tester);
    h.c.setUnitGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false), reason: 'nothing selected');

    await tap(tester, onTable(tester, h, '20'));
    expect(h.c.selectedUnits.value, {'20'});
    expect(flags(tester), (false, false), reason: 'one table');

    await tap(tester, onUnnumbered(tester, h, 0));
    await tap(tester, onUnnumbered(tester, h, 1), add: true);
    expect(selectedCount(h), 2);
    expect(h.c.selectedUnits.value, isEmpty);
    expect(flags(tester), (false, false), reason: 'two unnumbered tables');
    // A groups change makes both flags recompute over the same selection.
    h.c.setUnitGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
      'G1': group({'20'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false),
        reason: 'two unnumbered tables, recomputed');
    h.c.setUnitGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });

    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(selectedCount(h), 3);
    expect(h.c.selectedUnits.value, {'20'});
    expect(flags(tester).$1, isFalse,
        reason: 'unnumbered tables count for nothing');

    await tap(tester, onTable(tester, h, '7'));
    expect(h.c.selectedUnits.value, {'3', '7', '12'});
    expect(flags(tester), (false, true), reason: 'exactly one whole group');
    await press(tester, 'service-merge');
    expect(h.heard, isEmpty, reason: 'disabled: no call');

    await tap(tester, onTable(tester, h, '20'));
    await tap(tester, onTable(tester, h, '5'), add: true);
    expect(h.c.selectedUnits.value, {'5', '20'},
        reason: 'G9\'s hidden 9 is never selected');
    expect(flags(tester), (true, false), reason: 'a group plus a table');
    await press(tester, 'service-merge');
    expect(h.heard, ['merge']);
    expect(h.merged.single, {'5', '20'});

    h.c.setUnitGroups({});
    h.c.select({'20', '3'});
    await tester.pump();
    expect(flags(tester), (true, false), reason: 'two numbered tables');
    await press(tester, 'service-merge');
    expect(h.merged.last, {'3', '20'});

    h.c.setUnitGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '7'}),
    });
    h.c.select({'7', '20'});
    await tester.pump();
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.last, {'3', '7', '12', '20'},
        reason: 'exactly the selected numbers, the group not collapsed');
    expect(h.merged.last, h.c.selectedUnits.value);
    expect(h.heard, ['merge', 'merge', 'merge']);
    expect(h.doc.commands.undoDepth, 0, reason: 'the planner only asks');
    expect(h.c.unitGroups.value.keys, ['G9', 'G7'],
        reason: 'the planner never changes a group itself');
  });

  testWidgets(
      'TB2 Merge is disabled for two tables sharing one duplicate number '
      '(M-TG-16)', (tester) async {
    final h = await mount(tester, duplicate: true);
    h.c.setUnitGroups({
      'G2': group({'20', '8'})
    });
    await tap(tester, onTable(tester, h, '3'));
    await tap(tester, onTable(tester, h, '3', which: 1), add: true);
    expect(selectedCount(h), 2);
    expect(h.c.selectedUnits.value, {'3'});
    expect(flags(tester), (false, false));
    // Recomputed over the same selection by a groups change.
    h.c.setUnitGroups({
      'G2': group({'20', '8'}),
      'G5': group({'5', '9'}),
    });
    await tester.pump();
    expect(flags(tester), (false, false),
        reason: 'one number, though two tables');

    await tap(tester, onTable(tester, h, '12'), add: true);
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.single, {'3', '12'});
  });

  testWidgets(
      'TB3 Split: disabled for a group plus one table, part of a group and a '
      'group plus an unnumbered table; enabled for exactly one group\'s '
      'selectable members, its locked third member not selected, reporting '
      'the id (M-TG-17, the button half)', (tester) async {
    final h = await mount(tester);
    // Part of a group: 12 alone, then grouped with 3 and the locked 8.
    await tap(tester, onTable(tester, h, '12'));
    h.c.setUnitGroups({
      'G9': group({'9', '5'}),
      'G7': group({'12', '3', '8'}),
    });
    await tester.pump();
    expect(h.c.selectedUnits.value, {'12'});
    expect(flags(tester), (false, false), reason: 'part of a group');
    await press(tester, 'service-split');
    expect(h.heard, isEmpty, reason: 'disabled: no call');

    await tap(tester, onTable(tester, h, '3'));
    expect(h.c.selectedUnits.value, {'3', '12'});
    expect(flags(tester), (false, true),
        reason: 'G7\'s selectable members; its locked 8 is not needed');
    await press(tester, 'service-split');
    expect(h.heard, ['split G7']);

    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(h.c.selectedUnits.value, {'3', '12', '20'});
    expect(flags(tester), (true, false), reason: 'a group plus one table');

    await tap(tester, onTable(tester, h, '12'));
    await tap(tester, onUnnumbered(tester, h, 1), add: true);
    expect(selectedCount(h), 3);
    expect(h.c.selectedUnits.value, {'3', '12'});
    expect(flags(tester), (false, false),
        reason: 'a group plus an unnumbered table');

    await tap(tester, onTable(tester, h, '5'));
    expect(h.c.selectedUnits.value, {'5'});
    expect(flags(tester), (false, true), reason: 'G9\'s 9 is hidden');
    await press(tester, 'service-split');
    expect(h.heard, ['split G7', 'split G9']);
    expect(h.merged, isEmpty);
    expect(h.c.unitGroups.value.keys, ['G9', 'G7'],
        reason: 'the planner never changes a group itself');
  });

  testWidgets(
      'TB4 with the selection unchanged, setTableGroups flips the flags: '
      'grouping the selected tables turns Merge off and Split on, and back '
      '(M-TG-17b through the widgets)', (tester) async {
    final h = await mount(tester);
    await tap(tester, onTable(tester, h, '3'));
    await tap(tester, onTable(tester, h, '20'), add: true);
    expect(h.c.selectedUnits.value, {'3', '20'});
    expect(flags(tester), (true, false));

    h.c.setUnitGroups({
      'G2': group({'20', '3'})
    });
    await tester.pump();
    expect(h.c.selectedUnits.value, {'3', '20'}, reason: 'unchanged');
    expect(flags(tester), (false, true));
    await press(tester, 'service-split');
    expect(h.heard, ['split G2']);

    h.c.setUnitGroups({
      'G2': group({'20', '3', '7'})
    });
    await tester.pump();
    expect(flags(tester), (false, false), reason: 'now part of G2');

    h.c.setUnitGroups({
      'G2': group({'20', '9'}),
      'G4': group({'3', '12'}),
    });
    await tester.pump();
    expect(flags(tester), (true, false), reason: 'two groups, parts of each');

    h.c.setUnitGroups({});
    await tester.pump();
    expect(flags(tester), (true, false));
    await press(tester, 'service-merge');
    expect(h.merged.single, {'3', '20'});
    expect(h.heard, ['split G2', 'merge']);
  });

  testWidgets(
      'TB5 without a merge or a split callback, its button is absent; it '
      'appears when the host rebuilds with one, and the bar keeps its order '
      '(M-TG-18)', (tester) async {
    final h = await mount(tester, merge: false, split: false);
    expect(byKey('service-bar'), findsOneWidget);
    expect(byKey('service-merge'), findsNothing);
    expect(byKey('service-split'), findsNothing);
    for (final k in ['service-undo', 'service-redo', 'service-print']) {
      expect(byKey(k), findsOneWidget, reason: k);
    }

    await tester.pumpWidget(view(h, merge: true, split: false));
    expect(byKey('service-merge'), findsOneWidget);
    expect(byKey('service-split'), findsNothing);

    await tester.pumpWidget(view(h, merge: false, split: true));
    expect(byKey('service-merge'), findsNothing);
    expect(byKey('service-split'), findsOneWidget);

    await tester.pumpWidget(view(h));
    final xs = [
      for (final k in [
        'service-undo',
        'service-redo',
        'service-merge',
        'service-split',
        'service-print'
      ])
        tester.getTopLeft(byKey(k)).dx
    ];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]), reason: 'order at $i: $xs');
    }
    expect(tester.widget<IconButton>(byKey('service-merge')).tooltip, 'Merge');
    expect(tester.widget<IconButton>(byKey('service-split')).tooltip, 'Split');
    expect(find.byIcon(Icons.merge_type), findsOneWidget);
    expect(find.byIcon(Icons.call_split), findsOneWidget);

    // The rebuilt bar follows the selection as the first did.
    h.c.setUnitGroups({
      'G7': group({'12', '3', '7'})
    });
    await tap(tester, onTable(tester, h, '7'));
    expect(flags(tester), (false, true));
    await press(tester, 'service-split');
    expect(h.heard, ['split G7']);
  });

  testWidgets(
      'TB6 the flags are released: a resetLayout\'s new bar listens, leaving '
      'the selection mode leaves none listening (review 4 finding 2)',
      (tester) async {
    final h = await mount(tester);
    // Only the bar's two flags listen to selectedGroup.
    final sg = h.c.selectedGroup as ValueNotifier<String?>;
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isTrue, reason: 'premise');
    final before = h.c.activeDocument;
    h.c.resetService();
    await tester.pump();
    await tester.pump();
    expect(identical(before, h.c.activeDocument), isFalse, reason: 'premise');
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isTrue, reason: 'the new view listens');
    h.c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    // ignore: invalid_use_of_protected_member
    expect(sg.hasListeners, isFalse, reason: 'no view left listening');
  });

  testWidgets(
      'TB7 no merge or split callback: Print sits 8 px after Redo, as before '
      '(R-C4-1, review 4 finding 1)', (tester) async {
    await mount(tester, merge: false, split: false);
    // The guides' toggle joins Undo and Redo (task 9b), so Print sits 8 px
    // after it.
    expect(
        tester.getTopLeft(byKey('service-guides')).dx -
            tester.getTopRight(byKey('service-redo')).dx,
        0);
    final gap = tester.getTopLeft(byKey('service-print')).dx -
        tester.getTopRight(byKey('service-guides')).dx;
    expect(gap, 8);
  });
}
