// Ported from jet_cad_floor_plan/test/service/service_options_test.dart;
// assertions unchanged.
//
// Ports SO1-SO6 (controller ruling R-15: they drive the view's listeners,
// so they need PlanServiceView). Spec 14d S5-S7 (revision 2; 2b spec S4
// "Options" and "Permissions"): the service options, driven through
// PlanServiceView and real pointers (V-1): moves forbidden, the secondary
// click's context menu, and the long press as a context menu. Units are
// turned, mirrored and off the sheet's centre; one is locked, one
// unlabelled.
//
// Adaptations: FloorPlanView -> PlanServiceView, mounted in design and
// switched to service (today's order, under the first fit); the view
// option `serviceMoves` -> `PlanPermissions.serviceMove` (Task 14: a
// permission read at each press); `onTableContextMenu` ->
// `onUnitContextMenu`; FloorPlanLongPress -> PlanLongPress;
// cameraController -> camera; selectedTables -> selectedUnits; the plan
// built over the fixture kit, each unit labelled as today's numbering
// placer labelled it.
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_tool.dart'
    show PlanLongPress;
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/harness.dart' show catalogOf, planText;
import '../../support/service_fixtures.dart';
import '../../support/service_host.dart' show serviceController;
import '../../support/unit_fixtures.dart' show unitIndexOf;

/// Units 1 (turned, mirrored), 2, 3 (on a locked layer), 4 (relabelled
/// to nothing) and 5 (turned), around the sheet's centre.
String optionsPlan() => planText([fxKit()], (doc) {
      final sheet =
          sheetWorldRect(doc.components.get<PageComponent>(doc.rootHandle)!);
      final cx = (sheet.minX + sheet.maxX) / 2,
          cy = (sheet.minY + sheet.maxY) / 2;
      var n = 0;
      for (final (dx, dy, turns, mirrored) in const [
        (-2600.5, 900.25, 1, true),
        (2100.75, -700.5, 0, false),
        (-300.25, -2400.5, 2, false),
        (3900.5, 2300.25, 0, false),
        (-4300.25, -1900.75, 3, false),
      ]) {
        final h = placeAt(doc, tableSymbol(), Vector2(cx + dx, cy + dy),
            quarterTurns: turns, mirrored: mirrored);
        addUnitLabel(doc, h, '${++n}');
      }
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      final locked = doc.handleSeed.next();
      doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: locked,
          name: 'Locked',
          color: const IndexedColor(1),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: true,
          locked: false)));
      final survey = unitIndexOf(doc, catalog: catalogOf([fxKit()]));
      doc.commands.execute(SetInstanceLayerCommand(
          survey.withLabel('3').single.instance, locked));
      doc.commands.execute(
          SetLayerCommand(doc.tables.layers[locked]!.copyWith(locked: true)));
      doc.commands.execute(SetEntityTextCommand(
          survey.withLabel('4').single.label!, '', kUnitLabelTag));
      doc.commands.clearHistory();
    });

/// The instance of unit [n]; unit 4 by its place among the units.
InstanceNode node(PlanController c, String n) {
  final d = c.activeDocument;
  final units = c.unitIndex.units;
  final t = n == '4' ? units[3] : units.singleWhere((t) => t.text == n);
  return d.tree[t.instance]! as InstanceNode;
}

/// Unit [n]'s top centre on the screen.
Offset at(WidgetTester tester, PlanController c, String n) {
  final w = node(c, n).transform.transformPoint(Vector2(900, 700));
  final s = c.camera.value.worldToScreen(w);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

class Host {
  final taps = <String>[];
  final menus = <(String, Offset)>[];
  late PlanController c;

  Widget view(
          {bool menu = true,
          PlanLongPress longPress = PlanLongPress.toggleSelection}) =>
      MaterialApp(
          home: Scaffold(
              body: PlanServiceView(
                  controller: c,
                  onUnitTap: taps.add,
                  longPress: longPress,
                  onUnitContextMenu:
                      menu ? (n, p) => menus.add((n, p)) : null)));
}

Future<Host> pumpService(WidgetTester tester,
    {bool serviceMoves = true,
    bool menu = true,
    PlanLongPress longPress = PlanLongPress.toggleSelection}) async {
  final h = Host()..c = serviceController(json: optionsPlan());
  h.c.permissions = h.c.permissions.copyWith(serviceMove: serviceMoves);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(h.view(menu: menu, longPress: longPress));
  h.c.setMode(PlanMode.service);
  await tester.pump();
  await tester.pump();
  return h;
}

Future<void> rightClick(WidgetTester tester, Offset p) async {
  await tester.tapAt(p,
      buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
  await tester.pump();
}

void main() {
  testWidgets(
      'SO1 with moves off a drag from a table, selected or locked, pans and '
      'executes nothing; switched on after mount, the next drag moves '
      '(spec 14d S5, M-14d-o)', (tester) async {
    final h = await pumpService(tester, serviceMoves: false);
    final c = h.c;
    c.select({'2'});
    await tester.pump();
    final before = parts(node(c, '2').transform);
    for (final n in ['2', '3', '1']) {
      final pan = c.camera.value.worldToScreen(Vector2.zero());
      final g = await tester.startGesture(at(tester, c, n),
          kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(35, 25));
      await g.up();
      await tester.pump();
      final now = c.camera.value.worldToScreen(Vector2.zero());
      expect(now.x - pan.x, closeTo(75, 1e-6), reason: 'table $n pans');
      expect(now.y - pan.y, closeTo(25, 1e-6), reason: 'table $n pans');
    }
    expect(c.activeDocument.commands.undoDepth, 0);
    expect(parts(node(c, '2').transform), before);
    expect(c.serviceEdited, isFalse);

    c.permissions = c.permissions.copyWith(serviceMove: true);
    await tester.pumpWidget(h.view());
    final g = await tester.startGesture(at(tester, c, '2'),
        kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(40, 0));
    await g.moveBy(const Offset(35, 25));
    await g.up();
    await tester.pump();
    expect(c.activeDocument.commands.undoDepth, 1);
    expect(c.serviceEdited, isTrue);
  });

  testWidgets(
      'SO2 a secondary click: an unselected table becomes the selection and '
      'is reported at the pointer; a selected one keeps the selection; a '
      'locked one changes nothing; an unnumbered one is selected, not '
      'reported; the floor and a slide report nothing; no tap is reported '
      '(spec 14d S6, M-14d-p)', (tester) async {
    final h = await pumpService(tester);
    final c = h.c;

    final p1 = at(tester, c, '1');
    await rightClick(tester, p1);
    expect(h.menus, [('1', p1)]);
    expect(c.selectedUnits.value, {'1'});

    c.select({'1', '2', '5'});
    await tester.pump();
    await rightClick(tester, at(tester, c, '2'));
    expect(h.menus.last.$1, '2');
    expect(c.selectedUnits.value, {'1', '2', '5'});

    await rightClick(tester, at(tester, c, '3'));
    expect(h.menus.last.$1, '3', reason: 'a locked table is reported');
    expect(c.selectedUnits.value, {'1', '2', '5'});

    await rightClick(tester, at(tester, c, '4'));
    expect(h.menus, hasLength(3), reason: 'an unnumbered table: no report');
    expect(c.activeSelection.keys, {SelectionKey.root(node(c, '4').handle)},
        reason: 'but it is selected alone');

    c.select({'5'});
    await tester.pump();
    final floor = at(tester, c, '2') + const Offset(0, 260);
    await rightClick(tester, floor);
    // A slide past the touch slop, both ends on table 1.
    final from = at(tester, c, '1') - const Offset(10, 0);
    final g = await tester.startGesture(from,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await g.moveBy(const Offset(20, 0));
    await g.up();
    await tester.pump();
    expect(h.menus, hasLength(3), reason: 'the floor; a slide');
    expect(c.selectedUnits.value, {'5'});
    await rightClick(tester, from + const Offset(20, 0));
    expect(h.menus.last.$1, '1', reason: 'premise: the slide ends on 1');
    c.select({'5'});
    await tester.pump();
    expect(h.menus, hasLength(4));
    expect(h.taps, isEmpty);
    expect(c.activeDocument.commands.undoDepth, 0);
  });

  testWidgets(
      'SO3 Ctrl with the primary button still toggles; it is never a '
      'context click (spec 14d S6)', (tester) async {
    final h = await pumpService(tester);
    final c = h.c;
    c.select({'1'});
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tapAt(at(tester, c, '2'), kind: PointerDeviceKind.mouse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'});
    expect(h.menus, isEmpty);
    expect(h.taps, ['2']);
  });

  testWidgets(
      'SO4 under contextMenu a finger held 500 ms from contact reports the '
      'table at the finger and toggles nothing; a locked table too; under '
      'the default it still toggles (spec 14d S7, M-14d-p, M-14d-t)',
      (tester) async {
    final h = await pumpService(tester, longPress: PlanLongPress.contextMenu);
    final c = h.c;
    c.select({'5'});
    await tester.pump();

    final p2 = at(tester, c, '2');
    final g = await tester.startGesture(p2, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 480));
    expect(h.menus, isEmpty, reason: 'not before 500 ms');
    await tester.pump(const Duration(milliseconds: 40));
    expect(h.menus, hasLength(1));
    expect(h.menus.single.$1, '2');
    expect((h.menus.single.$2 - p2).distance, lessThan(1e-6));
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'2'}, reason: 'selected alone');
    expect(h.taps, isEmpty);

    final g3 = await tester.startGesture(at(tester, c, '3'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 600));
    await g3.up();
    await tester.pump();
    expect(h.menus.last.$1, '3');
    expect(c.selectedUnits.value, {'2'});

    await tester.pumpWidget(h.view());
    final g1 = await tester.startGesture(at(tester, c, '1'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 600));
    await g1.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'toggled in');
    expect(h.menus, hasLength(2));
  });

  testWidgets(
      'SO5 without onTableContextMenu a secondary click changes nothing: a '
      'selection of three stays (review F-2)', (tester) async {
    final h = await pumpService(tester, menu: false);
    final c = h.c;
    c.select({'1', '2', '5'});
    await tester.pump();
    await rightClick(tester, at(tester, c, '1'));
    await rightClick(tester, at(tester, c, '4'));
    expect(c.selectedUnits.value, {'1', '2', '5'});
    expect(h.taps, isEmpty);
  });

  testWidgets(
      'SO6 a secondary click while a primary gesture is held reports '
      'nothing and changes nothing (spec 14d S6, review F-4)', (tester) async {
    final h = await pumpService(tester);
    final c = h.c;
    c.select({'5'});
    await tester.pump();
    final pen = await tester.startGesture(at(tester, c, '1'),
        kind: PointerDeviceKind.stylus);
    await tester.pump();
    await rightClick(tester, at(tester, c, '2'));
    expect(h.menus, isEmpty);
    expect(c.selectedUnits.value, {'5'});
    await pen.cancel();
    await tester.pump();
    await rightClick(tester, at(tester, c, '2'));
    expect(h.menus.single.$1, '2', reason: 'premise: idle, it reports');
  });
}
