// The merge of 14d into the table groups (main's G4): a context gesture on
// an unselected member selects its whole group first, as a plain tap does,
// so the host's menu acts on the group (spec 14d S6, S7). Over the gesture
// test's plan: tables off the origin, turned and mirrored, numbered out of
// handle order, a hidden member.
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';

import 'table_groups_gesture_test.dart'
    show Host, gesturePlanJson, kScale, onTable;

Future<(Host, List<String>)> mountMenu(WidgetTester tester,
    {FloorPlanLongPress longPress = FloorPlanLongPress.toggleSelection}) async {
  final c = FloorPlanController(json: gesturePlanJson());
  addTearDown(c.dispose);
  final host = Host(c);
  final menus = <String>[];
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: FloorPlanView(
              controller: c,
              longPress: longPress,
              onTableContextMenu: (n, _) => menus.add(n)))));
  c.setMode(FloorPlanMode.selection);
  await tester.pump();
  await tester.pump();
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(kScale, 0, 0, -kScale, 690, 420));
  await tester.pump();
  c.setTableGroups({
    'G7': TableGroup(members: {'12', '3', '7', '9'})
  });
  await tester.pump();
  return (host, menus);
}

Future<void> rightClick(WidgetTester tester, Offset p) async {
  await tester.tapAt(p,
      buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
  await tester.pump();
}

void main() {
  testWidgets(
      'TG-C1 a right click on an unselected member selects its group, '
      'hidden member aside, and reports the member; on a selected group it '
      'keeps it; on a table in no group, that table alone', (tester) async {
    final (h, menus) = await mountMenu(tester);
    await rightClick(tester, onTable(tester, h, '3'));
    expect(h.selected, h.keys({'3', '7', '12'}));
    expect(h.c.selectedGroup.value, 'G7');
    expect(menus, ['3']);
    await rightClick(tester, onTable(tester, h, '12'));
    expect(h.selected, h.keys({'3', '7', '12'}), reason: 'kept');
    await rightClick(tester, onTable(tester, h, '20'));
    expect(h.selected, h.keys({'20'}));
    expect(menus, ['3', '12', '20']);
    expect(h.doc.commands.undoDepth, 0);
  });

  testWidgets(
      'TG-C2 under contextMenu a finger\'s long press on a member selects '
      'its group and reports the member; nothing is toggled', (tester) async {
    final (h, menus) =
        await mountMenu(tester, longPress: FloorPlanLongPress.contextMenu);
    h.c.select({'20'});
    await tester.pump();
    final g = await tester.startGesture(onTable(tester, h, '7'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pump();
    expect(menus, ['7']);
    expect(h.selected, h.keys({'3', '7', '12'}),
        reason: 'the group replaces the selection, never toggled into it');
  });
}
