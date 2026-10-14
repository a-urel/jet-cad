// Ported from jet_cad_floor_plan/test/host/table_groups_look_test.dart;
// assertions unchanged.
//
// Ports TG-V1-TG-V6, TG-Z3 and TG-Z4 (controller ruling R-15: they read the
// service painters through the mounted view). Table-groups spec G3 (2b
// spec S4 "Painting") through the real `PlanEditor` / `PlanServiceView`:
// the frames under the status fills, the chips above the drafting, a group
// status read back in pixels after `setGroupStatus` alone, the frame in the
// paper's colour whatever the theme, an unknown member that a design edit
// later adds, a member on a hidden layer, and nothing in the design mode.
//
// Under the seed of 2a's canvas fixture (support/canvas_fixture.dart), at
// device pixel ratio 1. The members (12, 3, 7, placed in that order) are
// turned and mirrored; the camera is off the origin at 0.125 px/mm and puts
// the frame bounds' top line (the chip's bottom edge, fixes X3) on a pixel
// centre. Unit 20's chair line lies a whole 8 px above it, on a pixel
// centre strictly inside the chip's rows.
//
// Adaptations: FloorPlanView -> PlanEditor (TG-V1 and TG-V6 switch modes
// inside one widget); FloorPlanMode.selection -> PlanMode.service;
// setTableGroups/setTableStatus/setTableFocus -> setUnitGroups/
// setUnitStatus/setUnitFocus; TableGroup/TableStatus -> UnitGroup/
// UnitStatus; the layers' keys `table-*` -> `unit-*` (Task 15);
// kTableFocusVeilAlpha -> kUnitFocusVeilAlpha; cameraController -> camera;
// the plan built over the fixture kit (`fx`), each unit labelled at
// placement; TG-V6's new unit placed and labelled 99 by the unit fixture's
// helpers; the zone fixture -> unit_zone_fixture.dart; the spies -> Task
// 15's painter tests.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_focus_painter.dart'
    show kUnitFocusVeilAlpha;
import 'package:jet_cad_2d_plan/src/service/paint/unit_group_painter.dart';
import 'package:jet_cad_2d_plan/src/service/paint/unit_status_painter.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/service_state.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../../support/canvas_fixture.dart';
import '../../support/harness.dart' show planText;
import '../../support/service_host.dart' show serviceController;
import '../../support/unit_fixtures.dart';
import '../../support/unit_zone_fixture.dart'
    show TestQuad, veilOver, zoneSymbolBoxes;
import '../paint/unit_group_painter_test.dart' show GroupSpy;
import '../paint/unit_status_painter_test.dart' show SpyCanvas;

/// The demo's statuses (`apps/restaurant_demo/lib/main.dart`).
const Color ordered = Color(0x99FFB300), eating = Color(0x9943A047);
const Color bill = Color(0x99E53935);

/// The members' placements (base points inside the fixture's sheet).
final List<(String, Transform2)> kMembers = [
  ('12', placementAt(8200, 4000, kDeg37, mirrored: true)),
  ('3', placementAt(9900, 3800, -kDeg37)),
  ('7', placementAt(11500, 4200, 2 * kDeg37, mirrored: true)),
];

/// The world corners of [tableSymbol]'s box under [t].
List<(double, double)> boxCorners(Transform2 t) => [
      for (final (x, y) in const [
        (300.0, -50.0),
        (1500.0, -50.0),
        (1500.0, 1450.0),
        (300.0, 1450.0)
      ])
        (t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f)
    ];

/// The members' corners, and G7's frame's top-most point (its bounds'
/// centre x at its maximum y), computed here independently of the painter.
final List<(double, double)> kCorners = [
  for (final (_, t) in kMembers) ...boxCorners(t)
];
final double kAnchorX = (kCorners.map((c) => c.$1).reduce(math.min) +
        kCorners.map((c) => c.$1).reduce(math.max)) /
    2;
final double kAnchorY =
    kCorners.map((c) => c.$2).reduce(math.max) + kGroupFrameMarginMm;

/// The drawing area's row the camera puts [kAnchorY] on (its centre).
const int kAnchorRow = 300;

/// How many whole pixels unit 20's chair line lies above [kAnchorRow]:
/// 64 mm at 0.125 px/mm, so the line falls on a pixel centre strictly
/// inside the chip, whose bottom edge is the anchor (fixes X3).
const int kChairRowsUp = 8;

/// The camera: the sheet's left edge at x = 40.5, [kAnchorY] at
/// y = [kAnchorRow] + 0.5, 0.125 px/mm, y up.
ViewportTransform lookCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(pxPerMm, 0, 0, -pxPerMm,
        40.5 - pxPerMm * sheetMinX, kAnchorRow + 0.5 + pxPerMm * kAnchorY));

/// A controller over a plan with a 1:20 page of [paper] (grid off) and the
/// units: the members 12, 3 and 7; 20, not a member, whose lower chair's
/// bottom line runs through G7's chip, [kChairRowsUp] pixels above the
/// anchor; 9 on a hidden layer.
PlanController lookController(int paper) {
  final json = planText([fxKit()], (doc) {
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        PageComponent(
            scaleDenominator: 20,
            originX: sheetMinX,
            originY: sheetMinY,
            background: paper,
            gridVisible: false,
            snapToGrid: false)));
    final placements = [
      for (final (n, t) in kMembers) (n, t),
      // The chair's bottom edge is 750 below the base point.
      ('20', placementAt(kAnchorX, kAnchorY + kChairRowsUp / pxPerMm + 750, 0)),
      ('9', placementAt(12200, 6400, kDeg37)),
    ];
    final units = [
      for (final (n, t) in placements)
        (n, placeUnit(doc, tableSymbol(), transform: t))
    ];
    for (final (n, h) in units) {
      addUnitLabel(doc, h, n);
    }
    final hidden = addLayer(doc, 'Hidden', visible: false);
    doc.commands.execute(SetInstanceLayerCommand(units[4].$2, hidden));
    doc.commands.clearHistory();
  });
  return serviceController(json: json);
}

/// Pumps [c]'s selection mode in [mode] and sets the camera.
Future<void> pumpLook(
    WidgetTester tester, PlanController c, ThemeMode mode) async {
  windowAt(tester, const Size(1440, 900));
  c.setMode(PlanMode.service);
  await pumpThemed(tester, Scaffold(body: PlanEditor(controller: c)), mode);
  await tester.pump();
  await tester.pump();
  c.camera.value = lookCamera();
  await tester.pump();
}

/// What the live painter under [key] hands a canvas.
GroupSpy groupSpy(WidgetTester tester, String key) {
  final layer = find.byKey(Key(key));
  final spy = GroupSpy();
  tester.widget<CustomPaint>(layer).painter!.paint(spy, tester.getSize(layer));
  return spy;
}

SpyCanvas statusSpy(WidgetTester tester) {
  final layer = find.byKey(const Key('unit-status-layer'));
  final spy = SpyCanvas();
  (tester.widget<CustomPaint>(layer).painter! as UnitStatusPainter)
      .paint(spy, tester.getSize(layer));
  return spy;
}

UnitGroupPainter chips(WidgetTester tester) => tester
    .widget<CustomPaint>(find.byKey(const Key('unit-group-chips')))
    .painter! as UnitGroupPainter;

/// The global pixel inside unit [n]'s top at definition (450, 700): clear
/// of its edges, its chairs and its label.
(int, int) insideTop(WidgetTester tester, PlanController c, String n) {
  final doc = c.activeDocument;
  final node =
      doc.tree[c.unitIndex.withLabel(n).single.instance]! as InstanceNode;
  return pixelOf(tester, node.transform.transformPoint(Vector2(450, 700)));
}

void expectRgb(int got, int want, int within, String reason) =>
    expect(channelDistance(got, want), lessThanOrEqualTo(within),
        reason: '$reason: ${hex(got)}, want ${hex(want)}');

void main() {
  testWidgets(
      'TG-V1 the frames under the status layer, the chips above the '
      'drafting and below the selection overlay; nothing in the design mode '
      '(G3)', (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '3', '7'})
    });
    windowAt(tester, const Size(1440, 900));
    await pumpThemed(
        tester, Scaffold(body: PlanEditor(controller: c)), ThemeMode.light);
    for (final key in [
      'unit-group-layer',
      'unit-status-layer',
      'unit-group-chips'
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: 'design: $key');
    }
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    final under = tester.widget<Stack>(find
        .ancestor(
            of: find.byKey(const Key('unit-status-layer')),
            matching: find.byType(Stack))
        .first);
    final keys = [
      for (final child in under.children)
        ((child as RepaintBoundary).child! as CustomPaint).key
    ];
    expect(keys, const [Key('unit-group-layer'), Key('unit-status-layer')]);
    final area = tester.widget<Stack>(find
        .ancestor(of: find.byType(DraftCanvas), matching: find.byType(Stack))
        .first);
    int indexOf(Finder f) => area.children.indexWhere((w) => find
        .descendant(of: find.byWidget(w), matching: f)
        .evaluate()
        .isNotEmpty);
    final canvas = area.children.indexWhere((w) => w is DraftCanvas);
    final chip = indexOf(find.byKey(const Key('unit-group-chips')));
    final overlay = indexOf(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SelectionOverlayPainter));
    expect(canvas < chip && chip < overlay, isTrue,
        reason: 'canvas $canvas, chips $chip, overlay $overlay');
  });

  testWidgets(
      'TG-V2 M-TG-22: the chip\'s pixels over a chair line show the chip: '
      'it is drawn above the drafting', (tester) async {
    final c = lookController(white);
    await pumpLook(tester, c, ThemeMode.light);
    // Set after the camera: the chips layer repaints on the groups.
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '3', '7'}, label: 'G7')
    });
    await tester.pump();
    final spy = groupSpy(tester, 'unit-group-chips');
    final t = spy.translations.single;
    final layer = find.byKey(const Key('unit-group-chips'));
    final o = tester.getTopLeft(layer);
    // The chip's rounded rectangle in global pixels.
    final chip = spy.rrects.single.shift(o + Offset(t.dx, t.dy));
    // Premises: the chip's bottom edge is the anchor's row centre (X3);
    // the chair's line (x within 225 mm of the anchor) is kChairRowsUp
    // rows above it and runs through the chip's left padding, the whole
    // sampled pixel strictly inside the rounded rectangle.
    expect(t.dy + spy.rrects.single.bottom, closeTo(kAnchorRow + 0.5, 1e-6));
    final (ax, ay) =
        pixelOf(tester, Vector2(kAnchorX, kAnchorY + kChairRowsUp / pxPerMm));
    expect(ay, o.dy + kAnchorRow - kChairRowsUp, reason: 'the chair row');
    final sx = (o.dx + t.dx - kGroupChipPaddingX / 2).floor();
    expect(ax - sx, lessThan(225 * pxPerMm), reason: 'on the chair line');
    for (final (dx, dy) in const [
      (0.0, 0.0),
      (1.0, 0.0),
      (0.0, 1.0),
      (1.0, 1.0)
    ]) {
      final corner = Offset(sx + 0.1 + 0.8 * dx, ay + 0.1 + 0.8 * dy);
      expect(chip.contains(corner), isTrue,
          reason: 'premise: pixel ($sx, $ay) inside the chip $chip');
    }
    expect(chip.top < ay && ay + 1 < chip.bottom, isTrue,
        reason: 'premise: row $ay strictly inside the chip\'s rows');
    final paper = PaperPalette.forPaper(white);
    final shot = await shoot(tester);
    // Without the chip the chair line is there: the same row a chip
    // width to the left of the chip, still on the line.
    expect(chip.right < ax - 22 || chip.left > ax - 21, isTrue,
        reason: 'premise: pixel ${ax - 22} is clear of the chip $chip');
    expect(channelDistance(shot.rgbAt(ax - 22, ay), 0xFFFFFF), greaterThan(100),
        reason: 'premise: the chair line is drawn on row $ay');
    expectRgb(shot.rgbAt(sx, ay), rgbOf(paper.gripMove), 3, 'the chip');
  });

  testWidgets(
      'TG-V3 M-TG-10: a member with its own Ordered and a group Bill fills '
      'Bill; clearing the group status shows Ordered; read after '
      'setGroupStatus with no camera or document change', (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '3', '7'})
    });
    await pumpLook(tester, c, ThemeMode.light);
    c.setUnitStatus(
        {'3': UnitStatus(color: ordered), '20': UnitStatus(color: eating)});
    await tester.pump();
    final (x3, y3) = insideTop(tester, c, '3');
    final (x12, y12) = insideTop(tester, c, '12');
    final (x20, y20) = insideTop(tester, c, '20');
    var shot = await shoot(tester);
    expectRgb(shot.rgbAt(x3, y3), over(ordered, white), 2, '3 Ordered');
    expectRgb(shot.rgbAt(x12, y12), 0xFFFFFF, 0, '12 no status');

    final camera = c.camera.value;
    final state = c.activeDocument.commands.stateId;
    c.setGroupStatus({'G7': UnitStatus(color: bill, caption: 'Bill')});
    await tester.pump();
    expect(identical(c.camera.value, camera), isTrue);
    expect(c.activeDocument.commands.stateId, state);
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(x3, y3), over(bill, white), 2, '3 Bill');
    expectRgb(shot.rgbAt(x12, y12), over(bill, white), 2, '12 Bill');
    expectRgb(shot.rgbAt(x20, y20), over(eating, white), 2, '20 its own');

    c.setGroupStatus(const {});
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(x3, y3), over(ordered, white), 2, '3 Ordered again');
    expectRgb(shot.rgbAt(x12, y12), 0xFFFFFF, 0, '12 cleared');

    // The group's status back, then 3 leaves the group: the groups alone
    // change, and 3 shows its own status.
    c.setGroupStatus({'G7': UnitStatus(color: bill, caption: 'Bill')});
    await tester.pump();
    expectRgb((await shoot(tester)).rgbAt(x3, y3), over(bill, white), 2,
        '3 Bill again');
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '7'})
    });
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(x3, y3), over(ordered, white), 2, '3 out: Ordered');
    expectRgb(shot.rgbAt(x12, y12), over(bill, white), 2, '12 still Bill');
  });

  testWidgets(
      'TG-V4 M-TG-21: the frame is in the shown paper\'s gripMove, not the '
      'theme\'s: Blueprint under the light theme 0xC4A0FF, White under the '
      'light theme 0x7A3FD1, and White under the dark theme, shown dark '
      '(dark canvas K1), 0xC4A0FF', (tester) async {
    // The frame's left-most point: the left-most corner pushed left by the
    // margin.
    final left = kCorners.reduce((a, b) => a.$1 <= b.$1 ? a : b);
    for (final (paper, mode, want, not) in [
      (blueprint, ThemeMode.light, 0xC4A0FF, 0x7A3FD1),
      (white, ThemeMode.light, 0x7A3FD1, 0xC4A0FF),
      (white, ThemeMode.dark, 0xC4A0FF, 0x7A3FD1),
    ]) {
      final c = lookController(paper);
      await pumpLook(tester, c, mode);
      // Set after the camera: the frames layer repaints on the groups.
      c.setUnitGroups({
        'G7': UnitGroup(members: const {'12', '3', '7'})
      });
      await tester.pump();
      final spy = groupSpy(tester, 'unit-group-layer');
      expect(spy.paints.single.color.toARGB32(), 0xFF000000 | want);
      final (x, y) =
          pixelOf(tester, Vector2(left.$1 - kGroupFrameMarginMm, left.$2));
      final seen = (await shoot(tester)).nearest(x, y, want);
      // A 2 px stroke on a curve: the nearest pixel is all but covered.
      expectRgb(seen, want, 12, '${hex(paper)} in $mode');
      expect(channelDistance(seen, not), greaterThan(40));
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'TG-V5 M-TG-13: a group whose second member is on a hidden layer draws '
      'no frame and no chip, and its status still fills the visible member',
      (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G9': UnitGroup(members: const {'12', '9'})
    });
    c.setGroupStatus({'G9': UnitStatus(color: bill)});
    await pumpLook(tester, c, ThemeMode.light);
    expect(groupSpy(tester, 'unit-group-layer').paths, isEmpty);
    expect(groupSpy(tester, 'unit-group-chips').paragraphs, isEmpty);
    expect(statusSpy(tester).paths, hasLength(1));
    final (x, y) = insideTop(tester, c, '12');
    expectRgb(
        (await shoot(tester)).rgbAt(x, y), over(bill, white), 2, '12 filled');
  });

  testWidgets(
      'TG-V6 M-TG-3: a group naming 99 before table 99 exists draws its '
      'frame once a table numbered 99 is added in the design and the mode '
      'is switched back', (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G9': UnitGroup(members: const {'3', '99'})
    });
    await pumpLook(tester, c, ThemeMode.light);
    expect(groupSpy(tester, 'unit-group-layer').paths, isEmpty,
        reason: 'one visible member');

    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    final design = c.activeDocument;
    final added = placeUnit(design, tableSymbol(),
        transform: placementAt(10600, 6000, -kDeg37));
    addUnitLabel(design, added, '99');
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    c.camera.value = lookCamera();
    await tester.pump();
    final path = groupSpy(tester, 'unit-group-layer').paths.single;
    expect(path.contains(const Offset(10600, 6000)), isTrue,
        reason: '99 inside its frame');
    expect(path.contains(const Offset(9900, 3800)), isTrue, reason: '3');
    groupSpy(tester, 'unit-group-chips');
    expect(chips(tester).debugChipTexts, ['3+99']);
  });

  testWidgets(
      'TG-Z3 M-Z38: the frames and the chips repaint on setTableFocus alone; '
      'focused on 20, G7\'s chip is the paper at 0.6 over gripMove on the '
      'screen; focused on 3 it is gripMove again (zone spec Z14)',
      (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '3', '7'}, label: 'G7')
    });
    await pumpLook(tester, c, ThemeMode.light);
    final repaints = <String, int>{};
    for (final key in ['unit-group-layer', 'unit-group-chips']) {
      final painter = tester.widget<CustomPaint>(find.byKey(Key(key))).painter!;
      void count() => repaints[key] = (repaints[key] ?? 0) + 1;
      painter.addListener(count);
      addTearDown(() => painter.removeListener(count));
    }
    final camera = c.camera.value;
    final state = c.activeDocument.commands.stateId;
    c.setUnitFocus({'20'});
    expect(repaints, {'unit-group-layer': 1, 'unit-group-chips': 1});
    await tester.pump();
    expect(identical(c.camera.value, camera), isTrue);
    expect(c.activeDocument.commands.stateId, state);

    final spy = groupSpy(tester, 'unit-group-chips');
    expect(spy.rrects, hasLength(2), reason: 'the chip, then its veil');
    final t = spy.translations.single;
    final o = tester.getTopLeft(find.byKey(const Key('unit-group-chips')));
    final chip = spy.rrects.first.shift(o + Offset(t.dx, t.dy));
    final sx = (o.dx + t.dx - kGroupChipPaddingX / 2).floor();
    final sy = (chip.top + chip.bottom) ~/ 2;
    for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      expect(chip.contains(Offset(sx + 0.1 + 0.8 * dx, sy + 0.1 + 0.8 * dy)),
          isTrue,
          reason: 'premise: pixel ($sx, $sy) inside the chip $chip');
    }
    final grip = rgbOf(PaperPalette.forPaper(white).gripMove);
    var shot = await shoot(tester);
    expectRgb(shot.rgbAt(sx, sy), veilOver(0xFFFFFF, grip), 1, 'veiled');
    final frame = groupSpy(tester, 'unit-group-layer').paints.single;
    expect(frame.color.a, closeTo(1 - kUnitFocusVeilAlpha, 1e-6),
        reason: 'the faded frame');

    c.setUnitFocus({'3'});
    expect(repaints, {'unit-group-layer': 2, 'unit-group-chips': 2});
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(sx, sy), grip, 1, 'a focused member: unveiled');
    expect(groupSpy(tester, 'unit-group-layer').paints.single.color.a, 1);
  });

  testWidgets(
      'TG-Z4 the Task 2 review\'s O3: the chips lie above the veil -- focused '
      'on 3, G7 straddles the focus and its chip, over the faded table 20, '
      'is gripMove unveiled, while 20 beside it is veiled (zone spec Z13, '
      'Z14)', (tester) async {
    final c = lookController(white);
    c.setUnitGroups({
      'G7': UnitGroup(members: const {'12', '3', '7'}, label: 'G7')
    });
    await pumpLook(tester, c, ThemeMode.light);
    final under = await shoot(tester);
    c.setUnitFocus({'3'});
    await tester.pump();
    final spy = groupSpy(tester, 'unit-group-chips');
    expect(spy.rrects, hasLength(1), reason: 'premise: G7 straddles');
    final t = spy.translations.single;
    final layer = find.byKey(const Key('unit-group-chips'));
    final o = tester.getTopLeft(layer);
    final chip = spy.rrects.single.shift(o + Offset(t.dx, t.dy));
    // Four rows above 20's chair line: inside the chip and inside 20's quad
    // (the chair is the box's lower edge, fixes X3's fixture).
    final sx = (o.dx + t.dx - kGroupChipPaddingX / 2).floor();
    final sy = (o.dy + kAnchorRow - kChairRowsUp - 4).toInt();
    final doc = c.activeDocument;
    final node =
        doc.tree[c.unitIndex.withLabel('20').single.instance]! as InstanceNode;
    final twenty =
        TestQuad(node.transform, zoneSymbolBoxes[tableSymbol().key]!);
    final inv = c.camera.value.worldToScreenMatrix.invert();
    bool inTwenty(int x, int y) {
      final px = x + 0.5 - o.dx, py = y + 0.5 - o.dy;
      return twenty.holds(inv.a * px + inv.c * py + inv.e,
          inv.b * px + inv.d * py + inv.f, 1 / pxPerMm);
    }

    for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
      expect(chip.contains(Offset(sx + 0.1 + 0.8 * dx, sy + 0.1 + 0.8 * dy)),
          isTrue,
          reason: 'premise: pixel ($sx, $sy) inside the chip $chip');
    }
    expect(inTwenty(sx, sy), isTrue, reason: 'premise: over 20');
    final bx = chip.left.floor() - 12;
    expect(inTwenty(bx, sy), isTrue, reason: 'premise: 20 beside the chip');
    final grip = rgbOf(PaperPalette.forPaper(white).gripMove);
    final shot = await shoot(tester);
    expectRgb(shot.rgbAt(bx, sy), veilOver(0xFFFFFF, under.rgbAt(bx, sy)), 1,
        'premise: 20 is veiled');
    expectRgb(shot.rgbAt(sx, sy), grip, 1, 'G7\'s chip over the veil');
  });
}
