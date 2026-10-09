// Host embedding API spec, Slice 3, T-1's status, groups, focus and chrome
// rows and T-3 through the real `FloorPlanView` / `ServiceView` (Slice 3
// plan Task 3): the resolved theme reaches the status, frame, chip and veil
// layers through `ServiceView`'s theme notifier, which joins each layer's
// repaint merge and each painter's rebuild key, so a theme change alone
// repaints (M-H33(repaint)); pans rebuild nothing (M-H31); an equal theme
// rebuilds nothing (T-3's ==); the veil with no colour is the paper's
// (M-H32); the bar takes `serviceBarHeight` and a runtime change is
// measured (S-10, T3-d); the theme reaches neither the design, the
// service layout nor an export (invariant 4); and `RenderFloorPlanOverlays`
// keeps its bars under a full theme (invariant 7).
//
// Read back in pixels at device pixel ratio 1 under the floor planner's
// seed (support/palette_fixture.dart): the groups look fixture (members
// 12, 3 and 7 turned and mirrored, placed out of handle order, 20 beside
// them, 0.125 px/mm off the origin), the zone fixture for the veil (a page
// of Blueprint, or none on a dark `canvasBackground` under the light
// theme), and the embedding fixture for the overlays. Expected colours are
// computed here (straight alpha over the pixel without the layer).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_theme.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_overlay.dart'
    show FloorPlanOverlayLayout, FloorPlanOverlaySize;
import 'package:jet_cad_floor_plan/src/service/table_focus_painter.dart';
import 'package:jet_cad_floor_plan/src/service/table_group_painter.dart';
import 'package:jet_cad_floor_plan/src/service/table_status_painter.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/palette_fixture.dart';
import 'embedding_fixture.dart' show embeddingCamera, embeddingPlanJson;
import 'table_groups_look_test.dart'
    show groupSpy, insideTop, kCorners, lookCamera, lookController;
import 'table_overlay_test.dart' show Calls, layerOf, shownCount;
import 'view_test.dart' show move;
import 'theme_canvas_test.dart' show exportPng, fullTheme;
import 'zone_fixture.dart' show quadsNumbered, zonePlanJson;

/// The demo's Bill (`apps/restaurant_demo/lib/main.dart`).
const Color bill = Color(0x99E53935);

const Color frameColour = Color(0xFF00897B);

/// An opaque status under the veil: the veil (the paper's colour) shows
/// only over what is not the paper.
const Color green = Color(0xFF2E7D32);
const Color chipColour = Color(0xFF3949AB);

/// `0xRRGGBB` of [colour]'s RGB at [alpha] (straight) over [under]
/// (`0xRRGGBB`), rounded per channel.
int composite(int colour, double alpha, int under) {
  var rgb = 0;
  for (final shift in const [16, 8, 0]) {
    final s = (colour >> shift) & 0xFF, u = (under >> shift) & 0xFF;
    rgb |= (alpha * s + (1 - alpha) * u).round() << shift;
  }
  return rgb;
}

void expectRgb(int got, int want, int within, String reason) =>
    expect(channelDistance(got, want), lessThanOrEqualTo(within),
        reason: '$reason: ${hex(got)}, want ${hex(want)}');

/// The four selection-mode layers, by their keys.
const List<String> kLayers = [
  'table-status-layer',
  'table-group-layer',
  'table-group-chips',
  'table-focus-layer',
];

CustomPainter painterOf(WidgetTester tester, String key) =>
    tester.widget<CustomPaint>(find.byKey(Key(key))).painter!;

/// Each layer's painter's `debugRebuilds`, `debugAllocations` and, for
/// the veil, `debugRecolours` (0 for the others).
List<(int, int, int)> countersOf(WidgetTester tester) => [
      for (final key in kLayers)
        switch (painterOf(tester, key)) {
          final TableStatusPainter p => (
              p.debugRebuilds,
              p.debugAllocations,
              0
            ),
          final TableGroupPainter p => (p.debugRebuilds, p.debugAllocations, 0),
          final TableFocusPainter p => (
              p.debugRebuilds,
              p.debugAllocations,
              p.debugRecolours
            ),
          _ => throw StateError(key),
        }
    ];

/// The host's view theme: every assignment rebuilds the host's
/// `FloorPlanView` with the value given, an equal one included (a
/// `ValueNotifier` would drop an equal value).
final class HostTheme extends ChangeNotifier {
  HostTheme(this._value);

  FloorPlanTheme? _value;
  FloorPlanTheme? get value => _value;
  set value(FloorPlanTheme? theme) {
    _value = theme;
    notifyListeners();
  }
}

/// [c]'s selection mode under the seed's [mode] theme, the view's theme
/// the returned host's (the host rebuilds the view on each assignment),
/// [camera] (the look fixture's by default) set after the first frames.
Future<HostTheme> pumpHost(WidgetTester tester, FloorPlanController c,
    {FloorPlanTheme? theme,
    ThemeMode mode = ThemeMode.light,
    ViewportTransform? camera}) async {
  windowAt(tester, const Size(1440, 900));
  final host = HostTheme(theme);
  addTearDown(host.dispose);
  c.setMode(FloorPlanMode.selection);
  await pumpThemed(
      tester,
      Scaffold(
          body: ListenableBuilder(
              listenable: host,
              builder: (_, __) =>
                  FloorPlanView(controller: c, theme: host.value))),
      mode);
  await tester.pump();
  await tester.pump();
  c.cameraController.value = camera ?? lookCamera();
  await tester.pump();
  return host;
}

/// The look fixture with a Bill on 3, the group {12, 3, 7} and a focus
/// on the group's members (20 faded).
FloorPlanController lookScene() {
  final c = lookController(white);
  c.setTableStatus(
      {'3': TableStatus(color: bill), '20': TableStatus(color: green)});
  c.setTableGroups({
    'G7': TableGroup(members: const {'12', '3', '7'}, label: 'G7')
  });
  c.setTableFocus({'12', '3', '7'});
  return c;
}

/// G7's chip's left padding pixel (global), clear of its glyphs and its
/// corners, read from the live chips painter.
(int, int) chipPadding(WidgetTester tester) {
  final spy = groupSpy(tester, 'table-group-chips');
  final t = spy.translations.single;
  final r = spy.rrects.single;
  final o = tester.getTopLeft(find.byKey(const Key('table-group-chips')));
  final x = (o.dx + t.dx + r.left + 1.5).floor();
  final y = (o.dy + t.dy + (r.top + r.bottom) / 2).floor();
  return (x, y);
}

/// The frame's left-most point's pixel: the left-most member corner pushed
/// left by [margin].
(int, int) framePixel(WidgetTester tester, {double margin = 150}) {
  final left = kCorners.reduce((a, b) => a.$1 <= b.$1 ? a : b);
  return pixelOf(tester, Vector2(left.$1 - margin, left.$2));
}

void main() {
  testWidgets(
      'M-H33(repaint): the camera, the plan, statuses, groups and focus '
      'still, the host changes only statusFillOpacity, then groupFrameColor, '
      'then groupChipColor, then focusVeilOpacity: after one pump each '
      'layer shows the new value', (tester) async {
    final c = lookScene();
    final host = await pumpHost(tester, c, theme: const FloorPlanTheme());
    final camera = c.cameraController.value;
    final state = c.activeDocument.commands.stateId;
    final (sx, sy) = insideTop(tester, c, '3');
    final (fx, fy) = framePixel(tester);
    final (cx, cy) = chipPadding(tester);
    final (vx, vy) = insideTop(tester, c, '20');
    final grip = rgbOf(PaperPalette.forPaper(white).gripMove);

    // What lies under 20 without the veil (20's own status, which the
    // veil, the paper's colour, shows on), now and at the opacity the
    // status step sets.
    c.setTableFocus(null);
    host.value = const FloorPlanTheme(statusFillOpacity: 0.5);
    await tester.pump();
    final under20Half = (await shoot(tester)).rgbAt(vx, vy);
    host.value = const FloorPlanTheme();
    await tester.pump();
    final under20 = (await shoot(tester)).rgbAt(vx, vy);
    expectRgb(under20, rgbOf(green), 1, 'premise: 20\'s status');
    expect(
        channelDistance(composite(0xFFFFFF, 0.35, under20Half),
            composite(0xFFFFFF, 0.6, under20Half)),
        greaterThan(20),
        reason: 'premise: the opacities read apart');
    c.setTableFocus({'12', '3', '7'});
    await tester.pump();
    var shot = await shoot(tester);
    expectRgb(shot.rgbAt(sx, sy), over(bill, white), 2, 'premise: Bill');
    expectRgb(shot.nearest(fx, fy, grip), grip, 12, 'premise: the frame');
    expectRgb(shot.rgbAt(cx, cy), grip, 1, 'premise: the chip');
    expectRgb(shot.rgbAt(vx, vy), composite(0xFFFFFF, 0.6, under20), 1,
        'premise: 20 veiled');

    host.value = const FloorPlanTheme(statusFillOpacity: 0.5);
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(sx, sy),
        over(bill.withValues(alpha: bill.a * 0.5), white), 2, 'the status');
    expect(channelDistance(over(bill, white), shot.rgbAt(sx, sy)),
        greaterThan(10));

    host.value = host.value!.copyWith(groupFrameColor: frameColour);
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.nearest(fx, fy, rgbOf(frameColour)), rgbOf(frameColour), 12,
        'the frame');
    expect(channelDistance(shot.nearest(fx, fy, grip), grip), greaterThan(40),
        reason: 'no gripMove left on the frame');

    host.value = host.value!.copyWith(groupChipColor: chipColour);
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(cx, cy), rgbOf(chipColour), 1, 'the chip');

    host.value = host.value!.copyWith(focusVeilOpacity: 0.35);
    await tester.pump();
    shot = await shoot(tester);
    expectRgb(shot.rgbAt(vx, vy), composite(0xFFFFFF, 0.35, under20Half), 1,
        'the veil');
    expect(identical(c.cameraController.value, camera), isTrue);
    expect(c.activeDocument.commands.stateId, state);
  });

  testWidgets(
      'M-H31 through the view: ten pans under a full theme leave each of the '
      'four layers\' rebuilds and allocations unchanged; a host rebuild '
      'with an equal, non-identical theme too; a different one rebuilds '
      'each once (T-3\'s ==)', (tester) async {
    final c = lookScene();
    c.setTableStatus({'3': TableStatus(color: bill, caption: 'Bill')});
    final host = await pumpHost(tester, c, theme: fullTheme);
    expect(
        (painterOf(tester, 'table-group-layer') as TableGroupPainter)
            .theme
            ?.value,
        fullTheme,
        reason: 'premise: the theme reaches the painters');
    final before = countersOf(tester);
    for (var i = 0; i < 10; i++) {
      c.panBy(Offset(3.5 + i, -2.25));
      await tester.pump();
    }
    expect(countersOf(tester), before, reason: 'nothing per frame');

    var builds = 0;
    host.addListener(() => builds++);
    host.value = fullTheme.copyWith();
    expect(identical(host.value, fullTheme), isFalse);
    await tester.pump();
    expect(builds, 1, reason: 'premise: the host rebuilt the view');
    c.panBy(const Offset(1, 1));
    await tester.pump();
    expect(countersOf(tester), before, reason: 'an equal theme');

    host.value = fullTheme.copyWith(groupFrameWidth: 5);
    await tester.pump();
    final after = countersOf(tester);
    for (var i = 0; i < kLayers.length; i++) {
      final veil = kLayers[i] == 'table-focus-layer';
      expect(after[i].$1, before[i].$1 + (veil ? 0 : 1),
          reason: '${kLayers[i]}: one rebuild (the veil only recolours)');
      expect(after[i].$3, before[i].$3 + (veil ? 1 : 0),
          reason: '${kLayers[i]}: the veil recolours once');
    }
  });

  group('the veil with no colour is the paper\'s (M-H32)', () {
    /// The zone fixture on a Blueprint page, or none.
    FloorPlanController zone({int? page}) {
      final c = FloorPlanController(json: zonePlanJson());
      addTearDown(c.dispose);
      if (page != null) {
        final d = c.activeDocument;
        d.commands.execute(SetComponentCommand<PageComponent>(
            d.rootHandle, PageComponent(background: page)));
      }
      return c;
    }

    /// Table 7 faded (focus on 3): every pixel well inside 7 is [paper]'s
    /// RGB at 0.35 over the same pixel without the focus.
    Future<void> expectVeiled(
        WidgetTester tester, FloorPlanController c, int paper) async {
      c.setTableFocus(null);
      await tester.pump();
      final under = await shoot(tester);
      c.setTableFocus({'3'});
      await tester.pump();
      final got = await shoot(tester);
      final seven = quadsNumbered(c.activeDocument, '7').single;
      final three = quadsNumbered(c.activeDocument, '3').single;
      final area = find.byType(InteractionLayer);
      final o = tester.getTopLeft(area);
      final size = tester.getSize(area);
      final inv = c.cameraController.value.worldToScreenMatrix.invert();
      var n = 0;
      for (var y = 0; y < size.height.toInt(); y += 2) {
        for (var x = 0; x < size.width.toInt(); x += 2) {
          final px = x + 0.5, py = y + 0.5;
          final wx = inv.a * px + inv.c * py + inv.e;
          final wy = inv.b * px + inv.d * py + inv.f;
          if (!seven.holds(wx, wy, 8) || !three.misses(wx, wy, 8)) continue;
          final gx = o.dx.toInt() + x, gy = o.dy.toInt() + y;
          expectRgb(got.rgbAt(gx, gy),
              composite(paper, 0.35, under.rgbAt(gx, gy)), 1, '($gx, $gy)');
          n++;
        }
      }
      expect(n, greaterThan(2000), reason: 'pixels checked');
    }

    /// Table 7's centre at the canvas's centre, 0.25 px/mm, off the grid.
    Future<void> aimAt7(WidgetTester tester, FloorPlanController c) async {
      final w = quadsNumbered(c.activeDocument, '7').single.centre;
      final size = tester.getSize(find.byType(InteractionLayer));
      c.cameraController.value = ViewportTransform(
          worldToScreenMatrix: Transform2(
              0.25,
              0,
              0,
              -0.25,
              size.width / 2 - 0.25 * w.x + 0.31,
              size.height / 2 + 0.25 * w.y + 0.17));
      await tester.pump();
    }

    testWidgets('Blueprint under the light theme: the veil is Blueprint',
        (tester) async {
      final c = zone(page: blueprint);
      await pumpHost(tester, c,
          theme: const FloorPlanTheme(focusVeilOpacity: 0.35));
      await aimAt7(tester, c);
      await expectVeiled(tester, c, blueprint & 0xFFFFFF);
    });

    testWidgets(
        'a page-less plan on a dark canvasBackground under the light theme: '
        'the veil is the canvas colour', (tester) async {
      const dark = Color(0xFF263238);
      final c = zone();
      await pumpHost(tester, c,
          theme: const FloorPlanTheme(
              canvasBackground: dark, focusVeilOpacity: 0.35));
      await aimAt7(tester, c);
      await expectVeiled(tester, c, rgbOf(dark));
    });
  });

  group('the bar (T-1, S-10)', () {
    Offset canvasIn(WidgetTester tester) =>
        tester.getTopLeft(find.byType(InteractionLayer)) -
        tester.getTopLeft(find.byType(FloorPlanView));

    Offset globalOf(WidgetTester tester, FloorPlanController c, Vector2 w) {
      final s = c.cameraController.value.worldToScreen(w);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(s.x, s.y);
    }

    testWidgets(
        'serviceBarHeight 60: the bar is 60 px, the canvas starts at (0, '
        '60), and the controller measured it there: a switch to the design '
        'reframes by the design origin minus (0, 60)', (tester) async {
      final c = lookController(white);
      await pumpHost(tester, c,
          theme: const FloorPlanTheme(serviceBarHeight: 60));
      expect(tester.getSize(find.byKey(const Key('service-bar'))).height, 60);
      expect(canvasIn(tester), const Offset(0, 60));
      final m = c.cameraController.value.worldToScreenMatrix;
      c.setMode(FloorPlanMode.design);
      final design = floorPlanCanvasSeeds[FloorPlanMode.design]!;
      final n = c.cameraController.value.worldToScreenMatrix;
      expect(n.e - m.e, closeTo(0 - design.dx, 1e-9));
      expect(n.f - m.f, closeTo(60 - design.dy, 1e-9));
      await tester.pump();
    });

    testWidgets(
        'T3-d: a runtime change 44 -> 60 with the plan unchanged, then '
        'design and back: a table keeps its global position, as with 44 '
        '(R-13)', (tester) async {
      final c = lookController(white);
      final host = await pumpHost(tester, c);
      expect(tester.getSize(find.byKey(const Key('service-bar'))).height, 44);
      final doc = c.activeDocument;
      final node =
          doc.tree[TableSurvey.of(doc).withNumber('3').single.instance]!
              as InstanceNode;
      final w = node.transform.transformPoint(Vector2(450, 700));

      // The control: 44 throughout.
      final at44 = globalOf(tester, c, w);
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      expect(globalOf(tester, c, w), at44);
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      expect(globalOf(tester, c, w), at44);

      host.value = const FloorPlanTheme(serviceBarHeight: 60);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), const Offset(0, 60));
      final at60 = globalOf(tester, c, w);
      expect(at60, at44 + const Offset(0, 16),
          reason: 'the plan moves with the canvas');
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      final there = globalOf(tester, c, w);
      expect(there.dx, closeTo(at60.dx, 1e-9), reason: 'design');
      expect(there.dy, closeTo(at60.dy, 1e-9), reason: 'design');
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      final back = globalOf(tester, c, w);
      expect(back.dx, closeTo(at60.dx, 1e-9), reason: 'selection again');
      expect(back.dy, closeTo(at60.dy, 1e-9), reason: 'selection again');
    });
  });

  testWidgets(
      'invariant 4: designJson, the service layout and the PNG export are '
      'the same with and without a full theme in the selection mode, '
      'statuses, groups and focus shown', (tester) async {
    final got = <FloorPlanExport>[];
    final c = lookScene();
    c.setTableStatus({'3': TableStatus(color: bill, caption: 'Bill')});
    c.setGroupStatus({'G7': TableStatus(color: bill, caption: 'G')});
    windowAt(tester, const Size(1440, 900));
    final host = ValueNotifier<FloorPlanTheme?>(null);
    addTearDown(host.dispose);
    c.setMode(FloorPlanMode.selection);
    await pumpThemed(
        tester,
        Scaffold(
            body: ValueListenableBuilder<FloorPlanTheme?>(
                valueListenable: host,
                builder: (_, t, __) =>
                    FloorPlanView(controller: c, theme: t, onExport: got.add))),
        ThemeMode.light);
    await tester.pump();
    await tester.pump();
    c.cameraController.value = lookCamera();
    await tester.pump();
    // A service move, so the layout is not the design's.
    move(c, '20', 610.5, -455.25);
    await tester.pump();
    final plainJson = c.designJson();
    final plainLayout = c.serviceLayoutJson();
    final plain = await exportPng(tester, 'service-export', got);
    expect(plain.sublist(1, 4), 'PNG'.codeUnits);

    host.value = fullTheme;
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('service-bar'))).height, 60,
        reason: 'premise: the theme is in force');
    final themed = await exportPng(tester, 'service-export', got);
    expect(themed, plain);
    expect(c.designJson(), plainJson);
    expect(plainLayout, isNotNull, reason: 'premise: a layout to compare');
    expect(c.serviceLayoutJson(), plainLayout);
  });

  group('invariant 7 with a theme: RenderFloorPlanOverlays\' counters', () {
    /// The embedding fixture in the selection mode under a full theme (the
    /// ambient one), overlays shown, a status, a group and a focus set.
    Future<FloorPlanController> mountThemed(WidgetTester tester, Calls calls,
        {FloorPlanOverlayLayout layout =
            const FloorPlanOverlayLayout()}) async {
      final c = FloorPlanController(json: embeddingPlanJson());
      addTearDown(c.dispose);
      c.setMode(FloorPlanMode.selection);
      c.setTableStatus({'1': TableStatus(color: bill, caption: 'Bill')});
      c.setTableGroups({
        'G': TableGroup(members: const {'2', '3'})
      });
      c.setTableFocus({'1', '2', '3'});
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const [fullTheme]),
        home: Scaffold(
            body: FloorPlanView(
                controller: c,
                tableOverlayBuilder: calls.builder(),
                tableOverlayLayout: layout)),
      ));
      await tester.pump();
      await tester.pump();
      c.cameraController.value = embeddingCamera();
      await tester.pump();
      expect(tester.getSize(find.byKey(const Key('service-bar'))).height, 60,
          reason: 'premise: the theme is in force');
      return c;
    }

    /// Fifty pans and zooms; how many overlays were shown, summed.
    Future<int> fiftyChanges(WidgetTester tester, FloorPlanController c,
        int Function() shown) async {
      var painted = 0;
      for (var i = 0; i < 50; i++) {
        if (i.isEven) {
          c.panBy(Offset(2.5, -1.25 - i / 10));
        } else {
          c.zoomBy(i % 4 == 1 ? 1.02 : 1 / 1.02, focus: const Offset(300, 300));
        }
        await tester.pump();
        painted += shown();
      }
      return painted;
    }

    testWidgets(
        'TO10 themed: natural: across 50 camera changes the render object '
        'allocates nothing, lays out nothing and hands one paint offset per '
        'painted overlay at most; the painters rebuild nothing',
        (tester) async {
      final calls = Calls();
      final c = await mountThemed(tester, calls);
      final layer = layerOf(tester);
      c.panBy(const Offset(1, 1));
      await tester.pump();
      final allocations = layer.debugAllocations;
      final layouts = layer.debugChildLayouts;
      final offsets = layer.debugPaintOffsets;
      final painters = countersOf(tester);
      final painted = await fiftyChanges(tester, c, () => shownCount(layer));
      expect(layer.debugAllocations, allocations,
          reason: '0 per table per camera change');
      expect(layer.debugChildLayouts, layouts, reason: 'natural: no relayout');
      expect(layer.debugPaintOffsets - offsets, lessThanOrEqualTo(painted));
      expect(painted, inExclusiveRange(0, 50 * 7), reason: 'premise');
      expect(countersOf(tester), painters);
      expect(calls.total, 7);
    });

    testWidgets(
        'TO21 themed: box: across 50 camera changes the render object '
        'allocates nothing and lays out each shown overlay once per frame',
        (tester) async {
      final calls = Calls();
      final c = await mountThemed(tester, calls,
          layout: const FloorPlanOverlayLayout(size: FloorPlanOverlaySize.box));
      final layer = layerOf(tester);
      c.panBy(const Offset(1, 1));
      await tester.pump();
      final allocations = layer.debugAllocations;
      final layouts = layer.debugChildLayouts;
      final offsets = layer.debugPaintOffsets;
      final painters = countersOf(tester);
      final painted = await fiftyChanges(tester, c, () => shownCount(layer));
      expect(layer.debugAllocations, allocations);
      expect(layer.debugPaintOffsets - offsets, lessThanOrEqualTo(painted));
      expect(layer.debugChildLayouts - layouts, painted);
      expect(painted, inExclusiveRange(0, 50 * 7), reason: 'premise');
      expect(countersOf(tester), painters);
      expect(calls.total, 7);
    });
  });
}
