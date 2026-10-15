// Ported from jet_cad_floor_plan/test/host/band_view_test.dart; assertions
// unchanged.
//
// Ports RBV1-RBV8 (controller ruling R-15: they drive the view's
// listeners). Rubber-band spec RB-1 (the view's `floorDrag`; 2b spec S4
// "Options"), with RB-2's touch and phase rules and RB-5's keys, driven
// through PlanEditor (today's FloorPlanView: RBV4 switches modes inside
// one widget) and real pointers (V-1). The camera is the view's own fit:
// y-flipped, scaled and off the origin; units are turned and one is
// mirrored; the plan holds a group {5, 6}, a unit on a locked layer (3),
// an unlabelled unit (4), a unit on a hidden layer (7) and a planter.
//
// Adaptations: FloorPlanView -> PlanEditor; FloorPlanMode.selection ->
// PlanMode.service; FloorPlanFloorDrag/FloorPlanLongPress ->
// PlanFloorDrag/PlanLongPress; onTableTap/onTableContextMenu ->
// onUnitTap/onUnitContextMenu; cameraController -> camera;
// selectedTables, setTableGroups, setTableStatus, setTableFocus ->
// selectedUnits, setUnitGroups, setUnitStatus, setUnitFocus; TableGroup,
// TableStatus -> UnitGroup, UnitStatus; the plan built over the fixture
// kit, each unit labelled as today's numbering placer labelled it.
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart';
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/harness.dart' show catalogOf, planText;
import '../../support/service_fixtures.dart';
import '../../support/service_host.dart' show serviceController;
import '../../support/unit_fixtures.dart' show planterSymbol, unitIndexOf;

/// Where each unit stands, as offsets from the sheet's centre in world
/// units (y up). Units 1 (turned a quarter, mirrored), 2, 3 (locked), 4
/// (unlabelled), 5 and 6 (group 'g'), 7 (hidden), then the planter.
const List<(double, double, int, bool)> _places = [
  (-4000.5, 1500.25, 1, true),
  (-1000.25, 1500.75, 0, false),
  (-1000.75, -2500.5, 2, false),
  (2500.5, 1500.25, 0, false),
  (2500.25, -2500.75, 3, false),
  (5000.75, -2500.25, 0, false),
  (-4000.25, -2500.5, 0, false),
];

/// The planter's offset.
const (double, double) _planterAt = (-6500.5, 1500.25);

String bandPlan() => planText([fxKit()], (doc) {
      final sheet =
          sheetWorldRect(doc.components.get<PageComponent>(doc.rootHandle)!);
      final cx = (sheet.minX + sheet.maxX) / 2,
          cy = (sheet.minY + sheet.maxY) / 2;
      var n = 0;
      for (final (dx, dy, turns, mirrored) in _places) {
        final h = placeAt(doc, tableSymbol(), Vector2(cx + dx, cy + dy),
            quarterTurns: turns, mirrored: mirrored);
        addUnitLabel(doc, h, '${++n}');
      }
      placeAt(
          doc, planterSymbol, Vector2(cx + _planterAt.$1, cy + _planterAt.$2));
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      Handle layer(String name) {
        final h = doc.handleSeed.next();
        doc.commands.execute(AddLayerCommand(LayerRecord(
            handle: h,
            name: name,
            color: const IndexedColor(1),
            linetype: zero.linetype,
            lineweight: zero.lineweight,
            transparency: zero.transparency,
            visible: true,
            locked: false)));
        return h;
      }

      final locked = layer('Locked'), hidden = layer('Hidden');
      final survey = unitIndexOf(doc, catalog: catalogOf([fxKit()]));
      doc.commands.execute(SetInstanceLayerCommand(
          survey.withLabel('3').single.instance, locked));
      doc.commands.execute(SetInstanceLayerCommand(
          survey.withLabel('7').single.instance, hidden));
      doc.commands.execute(
          SetLayerCommand(doc.tables.layers[locked]!.copyWith(locked: true)));
      doc.commands.execute(
          SetLayerCommand(doc.tables.layers[hidden]!.copyWith(visible: false)));
      doc.commands.execute(SetEntityTextCommand(
          survey.withLabel('4').single.label!, '', kUnitLabelTag));
      doc.commands.clearHistory();
    });

InstanceNode node(PlanController c, String n) {
  final d = c.activeDocument;
  final units = c.unitIndex.units;
  final t = n == '4' ? units[3] : units.singleWhere((t) => t.text == n);
  return d.tree[t.instance]! as InstanceNode;
}

/// A unit's top centre on the screen (its base point).
Offset centre(WidgetTester tester, PlanController c, String n) {
  final w = node(c, n).transform.transformPoint(Vector2(900, 700));
  return global(tester, c, w);
}

Offset global(WidgetTester tester, PlanController c, Vector2 world) {
  final s = c.camera.value.worldToScreen(world);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// The point [dx], [dy] (world units, y up) from the sheet's centre.
Offset floorAt(WidgetTester tester, PlanController c, double dx, double dy) {
  final sheet = sheetWorldRect(c.activeDocument.components
      .get<PageComponent>(c.activeDocument.rootHandle)!);
  return global(
      tester,
      c,
      Vector2((sheet.minX + sheet.maxX) / 2 + dx,
          (sheet.minY + sheet.maxY) / 2 + dy));
}

/// Screen pixels per world unit.
double pxPerUnit(PlanController c) {
  final v = c.camera.value;
  return (v.worldToScreen(Vector2(1000, 0)).x -
              v.worldToScreen(Vector2.zero()).x)
          .abs() /
      1000;
}

Offset worldZero(PlanController c) {
  final s = c.camera.value.worldToScreen(Vector2.zero());
  return Offset(s.x, s.y);
}

/// The band that takes units 1 and 2 whole, left to right.
(Offset, Offset) over12(WidgetTester tester, PlanController c) => (
      floorAt(tester, c, -5600, 3200),
      floorAt(tester, c, 300, 300),
    );

class Host {
  final taps = <String>[];
  final floorTaps = <Offset>[];
  final menus = <(String, Offset)>[];
  late PlanController c;

  Widget view({
    PlanFloorDrag floorDrag = PlanFloorDrag.band,
    bool userCamera = true,
    bool shortcuts = true,
    PlanLongPress longPress = PlanLongPress.toggleSelection,
  }) =>
      MaterialApp(
          home: Scaffold(
              body: PlanEditor(
                  controller: c,
                  floorDrag: floorDrag,
                  userCamera: userCamera,
                  shortcuts: shortcuts,
                  longPress: longPress,
                  onUnitTap: taps.add,
                  onFloorTap: floorTaps.add,
                  onUnitContextMenu: (n, p) => menus.add((n, p)))));
}

Future<Host> pumpBand(WidgetTester tester,
    {PlanFloorDrag floorDrag = PlanFloorDrag.band,
    bool userCamera = true,
    bool shortcuts = true,
    PlanLongPress longPress = PlanLongPress.toggleSelection}) async {
  final h = Host()..c = serviceController(json: bandPlan());
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(h.view(
      floorDrag: floorDrag,
      userCamera: userCamera,
      shortcuts: shortcuts,
      longPress: longPress));
  h.c.setMode(PlanMode.service);
  await tester.pump();
  await tester.pump();
  return h;
}

/// Moves [g] from [from] to [to] in steps of at most 12 px, pumping
/// between: the first step stays inside the touch slop, so a finger's
/// hold-back (spec 14t) releases on a later one.
Future<void> glide(
    WidgetTester tester, TestGesture g, Offset from, Offset to) async {
  final steps = ((to - from).distance / 12).ceil().clamp(2, 400);
  for (var i = 1; i <= steps; i++) {
    await g.moveTo(Offset.lerp(from, to, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> drag(
    WidgetTester tester, PointerDeviceKind kind, Offset from, Offset to) async {
  final g = await tester.startGesture(from, kind: kind);
  await glide(tester, g, from, to);
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets(
      'RBV1 under band a one-finger drag from the floor selects the tables '
      'it takes and the camera stays; a mouse does the same; two fingers pan '
      'and select nothing; a second finger landing mid-band cancels it, and '
      'a tap then selects (RB3; M-RB3, M-RB3b)', (tester) async {
    final h = await pumpBand(tester);
    final c = h.c;
    c.select({'5'});
    await tester.pump();
    final (from, to) = over12(tester, c);
    final before = worldZero(c);

    await drag(tester, PointerDeviceKind.touch, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'a finger bands');
    expect(worldZero(c), before, reason: 'the camera did not move');
    expect(h.floorTaps, isEmpty);
    expect(h.taps, isEmpty);

    c.select({'5'});
    await tester.pump();
    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'a mouse bands');
    expect(worldZero(c), before);

    // Two fingers on the floor, moved together: the camera pans.
    c.select({'5'});
    await tester.pump();
    final f1 = floorAt(tester, c, 5200, 3000);
    final f2 = f1 + const Offset(60, 0);
    final g1 = await tester.startGesture(f1, kind: PointerDeviceKind.touch);
    final g2 = await tester.startGesture(f2, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 1; i <= 8; i++) {
      await g1.moveTo(f1 + Offset(0, 14.0 * i));
      await g2.moveTo(f2 + Offset(0, 14.0 * i));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pump();
    expect((worldZero(c) - before).distance, greaterThan(60),
        reason: 'two fingers pan');
    expect(c.selectedUnits.value, {'5'}, reason: 'and select nothing');

    // A second finger landing mid-band cancels it.
    c.fitToView();
    await tester.pump();
    final (a, b) = over12(tester, c);
    final first = await tester.startGesture(a, kind: PointerDeviceKind.touch);
    await glide(tester, first, a, b);
    final second = await tester.startGesture(floorAt(tester, c, 5200, 3000),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 50));
    await first.moveBy(const Offset(10, 6));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'5'},
        reason: 'the band was cancelled, the selection is unchanged');
    await tester.tapAt(centre(tester, c, '1'), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.selectedUnits.value, {'1'}, reason: 'a tap then selects');
  });

  testWidgets(
      'RBV2 under band with userCamera false the band selects (RB4; '
      'M-RB4)', (tester) async {
    final h = await pumpBand(tester, userCamera: false);
    final c = h.c;
    c.select({'5'});
    await tester.pump();
    final (from, to) = over12(tester, c);
    final before = worldZero(c);
    await drag(tester, PointerDeviceKind.touch, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'a finger bands');
    c.select({'5'});
    await tester.pump();
    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'a mouse bands');
    expect(worldZero(c), before, reason: 'a locked camera stays');
  });

  testWidgets(
      'RBV3 selectedTables notifies exactly once for a band, and no tap or '
      'floor tap is reported (RB13)', (tester) async {
    final h = await pumpBand(tester);
    final c = h.c;
    var notified = 0;
    c.selectedUnits.addListener(() => notified++);
    final (from, to) = over12(tester, c);
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await glide(tester, g, from, to);
    expect(notified, 0, reason: 'a live band selects nothing');
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'});
    expect(notified, 1);
    expect(h.taps, isEmpty);
    expect(h.floorTaps, isEmpty);
  });

  testWidgets(
      'RBV4 under shortcuts false Escape mid-band ends it, a secondary click '
      'mid-band opens no menu, and a mode switch mid-band leaves the '
      'selection as it was (RB14; M-RB17)', (tester) async {
    final h = await pumpBand(tester, shortcuts: false);
    final c = h.c;
    c.select({'5'});
    await tester.pump();
    final (from, to) = over12(tester, c);

    // Premise: with shortcuts off an idle Escape does not clear.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.selectedUnits.value, {'5'}, reason: 'premise: idle Escape');

    // Premise: the same drag, without Escape, bands.
    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'premise: it bands');
    c.select({'5'});
    await tester.pump();

    var g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await glide(tester, g, from, to);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await g.moveBy(const Offset(-12, 8));
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'5'}, reason: 'Escape ended the band');

    // A secondary click on table 2 mid-band.
    g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await glide(tester, g, from, to);
    final menu = await tester.startGesture(centre(tester, c, '2'),
        kind: PointerDeviceKind.stylus, buttons: kSecondaryMouseButton);
    await menu.up();
    await tester.pump();
    expect(h.menus, isEmpty, reason: 'no menu mid-band');
    expect(c.selectedUnits.value, {'5'}, reason: 'no selection from it');
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'},
        reason: 'the band went on and finished');

    // A mode switch mid-band, and back.
    c.select({'5'});
    await tester.pump();
    g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    await glide(tester, g, from, to);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'5'},
        reason: 'the band was dropped: the selection is as it was');
    expect(h.menus, isEmpty);
  });

  testWidgets(
      'RBV5 floorDrag is read at each press: flipped to band by a rebuild '
      'the next drag bands; flipped back mid-band, that band finishes as a '
      'band', (tester) async {
    final h = await pumpBand(tester, floorDrag: PlanFloorDrag.pan);
    final c = h.c;
    final (from, to) = over12(tester, c);
    final before = worldZero(c);

    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect(c.selectedUnits.value, isEmpty, reason: 'pan: a drag pans');
    final panned = worldZero(c);
    expect((panned - before - (to - from)).distance, lessThan(1e-6));

    await tester.pumpWidget(h.view());
    c.fitToView();
    await tester.pump();
    final (a, b) = over12(tester, c);
    await drag(tester, PointerDeviceKind.mouse, a, b);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'band: the next bands');

    c.select({'5'});
    await tester.pump();
    final g = await tester.startGesture(a, kind: PointerDeviceKind.mouse);
    final mid = Offset.lerp(a, b, 0.5)!;
    await glide(tester, g, a, mid);
    await tester.pumpWidget(h.view(floorDrag: PlanFloorDrag.pan));
    await glide(tester, g, mid, b);
    final moved = worldZero(c);
    await g.up();
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'},
        reason: 'the band in progress finished as a band');
    expect(worldZero(c), moved);
  });

  testWidgets(
      'RBV6 a table out of focus, a status and a group colour do not stop a '
      'band: it takes veiled tables (RB18)', (tester) async {
    final h = await pumpBand(tester);
    final c = h.c;
    c.setUnitGroups({
      'g': UnitGroup(members: {'5', '6'}, label: 'Party')
    });
    c.setUnitStatus({'2': UnitStatus(color: const Color(0xFF00AA00))});
    c.setGroupStatus({'g': UnitStatus(color: const Color(0xFFAA0000))});
    c.setUnitFocus({'2'});
    await tester.pump();
    final (from, to) = over12(tester, c);
    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect(c.selectedUnits.value, {'1', '2'},
        reason: 'table 1 is veiled, still taken');
    await drag(tester, PointerDeviceKind.mouse, floorAt(tester, c, 1600, -4600),
        floorAt(tester, c, 6500, -700));
    expect(c.selectedUnits.value, {'5', '6'},
        reason: 'a coloured group, veiled, is taken whole');
  });

  testWidgets(
      'RBV7 under contextMenu and band a held table reports its menu, a '
      'floor drag bands; a finger 10 px off a table bands, taps select it, '
      'and a finger on its top moves it (RB19; M-RB21)', (tester) async {
    final h = await pumpBand(tester, longPress: PlanLongPress.contextMenu);
    final c = h.c;
    final press = await tester.startGesture(centre(tester, c, '1'),
        kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 600));
    await press.up();
    await tester.pump();
    expect(h.menus.map((m) => m.$1), ['1'], reason: 'a held table: its menu');
    expect(c.selectedUnits.value, {'1'});

    final (from, to) = over12(tester, c);
    await drag(tester, PointerDeviceKind.touch, from, to);
    expect(c.selectedUnits.value, {'1', '2'}, reason: 'a floor drag bands');
    expect(h.menus, hasLength(1));

    // 10 px off table 2's top, to its left (the top is 1200 wide and 800
    // tall about the base point; the chairs sit within 225 of its middle).
    final s = pxPerUnit(c);
    final edge = global(tester, c,
        node(c, '2').transform.transformPoint(Vector2(900 - 600, 700)));
    final near = edge - const Offset(10, 0);
    expect(near.dx, lessThan(edge.dx));
    c.select({'5'});
    await tester.pump();
    final undo = c.activeDocument.commands.undoDepth;
    await drag(tester, PointerDeviceKind.touch, near, centre(tester, c, '1'));
    expect(c.selectedUnits.value, {'1'},
        reason: 'a finger 10 px off a table bands (right to left: touched)');
    expect(c.activeDocument.commands.undoDepth, undo, reason: 'nothing moved');
    expect(s, greaterThan(0));

    await tester.tapAt(near, kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.selectedUnits.value, {'2'}, reason: 'a tap there selects 2');
    expect(h.taps.last, '2');

    final top = centre(tester, c, '2');
    await drag(
        tester, PointerDeviceKind.touch, top, top + const Offset(0, -80));
    expect(c.activeDocument.commands.undoDepth, undo + 1,
        reason: 'a finger on the top moves it');
    expect(c.selectedUnits.value, {'2'});
  });

  testWidgets(
      'RBV8 under pan, the default, a Shift mouse drag adds to the '
      'selection and a plain one pans', (tester) async {
    final h = await pumpBand(tester, floorDrag: PlanFloorDrag.pan);
    final c = h.c;
    // Table 4 has no number: it is selected, but selectedTables lacks it.
    await tester.tapAt(centre(tester, c, '4'), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.selectedUnits.value, isEmpty, reason: 'premise: 4 is selected');
    expect(c.activeSelection.keys, hasLength(1));
    final four = c.activeSelection.keys.single;

    final (from, to) = over12(tester, c);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await drag(tester, PointerDeviceKind.mouse, from, to);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(c.selectedUnits.value, {'1', '2'});
    expect(c.activeSelection.keys, contains(four), reason: 'added to 4');
    expect(c.activeSelection.keys, hasLength(3));

    final before = worldZero(c);
    await drag(tester, PointerDeviceKind.mouse, from, to);
    expect((worldZero(c) - before - (to - from)).distance, lessThan(1e-6),
        reason: 'a plain drag pans');
    expect(c.selectedUnits.value, {'1', '2'});
    expect(c.activeSelection.keys, hasLength(3));
  });
}
