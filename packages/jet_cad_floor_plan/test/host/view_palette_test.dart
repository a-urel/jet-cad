// Dark theme spec D1, D4, D5, F-10 (plan Task 4): the host's views. Each
// view derives its own palettes from its own page and the theme (invariant
// 4), so two views in one frame show their own papers' sets (M-DT-11); the
// selection mode's `ServiceView` follows the theme and the paper as the
// shell does, a document without a page included (M-DT-10).
//
// Read back in pixels under the floor planner's seed (support/
// palette_fixture.dart). `restaurant_demo` mounts one view at a time
// (F-10), so the two-view harness is this file's own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/service_view.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';

import '../support/palette_fixture.dart';

/// A controller over the fixture's document on [paper] (null: no page),
/// and the selected line's handle (a decode keeps handles).
({FloorPlanController c, Handle selected, Handle ink}) controllerOn(
    int? paper) {
  final m = FlutterTextMeasurer();
  final f = paletteDoc(m, paper: paper);
  final json = DraftDocumentCodec.encodeToString(f.doc);
  f.doc.dispose();
  m.clear();
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  return (c: c, selected: f.selected, ink: f.ink);
}

/// The host's [FloorPlanView]s, side by side in one frame.
Widget views(List<FloorPlanController> cs) => Scaffold(
        body: Row(children: [
      for (final c in cs) Expanded(child: FloorPlanView(controller: c)),
    ]));

/// Pumps [cs] side by side in [mode] (each [width] wide), puts each in
/// [viewMode], sets the fixture's camera and selects each one's line.
Future<void> pumpViews(
    WidgetTester tester,
    List<({FloorPlanController c, Handle selected, Handle ink})> cs,
    ThemeMode mode,
    {FloorPlanMode viewMode = FloorPlanMode.design,
    double width = 1440}) async {
  windowAt(tester, Size(width * cs.length, 900));
  for (final v in cs) {
    v.c.setMode(viewMode);
  }
  await pumpThemed(tester, views([for (final v in cs) v.c]), mode);
  await tester.pump();
  await tester.pump();
  for (final v in cs) {
    v.c.camera.value = paletteCamera;
    v.c.activeSelection.replace([SelectionKey.root(v.selected)]);
  }
  await tester.pump();
}

DraftCanvasState canvasOf(WidgetTester tester, int view) =>
    tester.state<DraftCanvasState>(find.byType(DraftCanvas).at(view));

void main() {
  for (final viewMode in FloorPlanMode.values) {
    testWidgets(
        'M-DT-11 (${viewMode.name} mode): two views side by side in one frame, '
        'White and Blueprint, each with a line selected, show the light and '
        'the dark selection colour and their own ink', (tester) async {
      final onWhite = controllerOn(white);
      final onBlueprint = controllerOn(blueprint);
      await pumpViews(tester, [onWhite, onBlueprint], ThemeMode.dark,
          viewMode: viewMode);
      expect(find.byType(PlannerView), findsNWidgets(2));
      expect(find.byType(ServiceView),
          findsNWidgets(viewMode == FloorPlanMode.selection ? 2 : 0));

      final shot = await shoot(tester);
      final left = look(tester, shot, view: 0);
      final right = look(tester, shot, view: 1);
      expectSelection(left, PaperPalette.light, 'White view');
      expectSelection(right, PaperPalette.dark, 'Blueprint view');
      expectDarkInk(left, 'White view');
      expectLightInk(right, 'Blueprint view');
      // One theme, so one chrome for both.
      expectEdge(left, ChromePalette.dark, 'White view');
      expectEdge(right, ChromePalette.dark, 'Blueprint view');
      expectPainters(tester, ChromePalette.dark, PaperPalette.light, 'White',
          view: 0, withRulers: viewMode == FloorPlanMode.design);
      expectPainters(tester, ChromePalette.dark, PaperPalette.dark, 'Blueprint',
          view: 1, withRulers: viewMode == FloorPlanMode.design);
    });
  }

  // ServiceView's own crossings: its chrome is the sheet edge alone (no
  // rulers in the selection mode).
  for (final (mode, paper, name) in [
    (ThemeMode.light, blueprint, 'light theme, Blueprint paper'),
    (ThemeMode.dark, white, 'dark theme, White paper'),
    (ThemeMode.dark, blueprint, 'dark theme, Blueprint paper'),
  ]) {
    testWidgets(
        'ServiceView, $name: the selection takes the paper\'s set and the '
        'sheet edge the theme\'s chrome', (tester) async {
      final v = controllerOn(paper);
      await pumpViews(tester, [v], mode, viewMode: FloorPlanMode.selection);
      expect(find.byType(ServiceView), findsOneWidget);
      final chrome =
          mode == ThemeMode.dark ? ChromePalette.dark : ChromePalette.light;
      final set = paper == blueprint ? PaperPalette.dark : PaperPalette.light;
      final seen = look(tester, await shoot(tester));
      expect(seen.rulerBar, isNull, reason: 'no rulers in the selection mode');
      expectSelection(seen, set, name);
      expectEdge(seen, chrome, name);
      paper == blueprint
          ? expectLightInk(seen, name)
          : expectDarkInk(seen, name);
      final view = tester.widget<PlannerView>(find.byType(PlannerView));
      expect(view.chrome, chrome);
      expect(view.paper, set);
      expectPainters(tester, chrome, set, name, withRulers: false);
    });
  }

  testWidgets(
      'M-DT-10, ServiceView: no page, light then dark theme: the ink and the '
      'selection follow the surface, re-derived on the switch, and back',
      (tester) async {
    final v = controllerOn(null);
    expect(
        v.c.activeDocument.components
            .get<PageComponent>(v.c.activeDocument.rootHandle),
        isNull);
    await pumpViews(tester, [v], ThemeMode.light,
        viewMode: FloorPlanMode.selection);
    var seen = look(tester, await shoot(tester));
    expectDarkInk(seen, 'no page, light');
    expectSelection(seen, PaperPalette.light, 'no page, light');

    await pumpThemed(tester, views([v.c]), ThemeMode.dark);
    await tester.pump();
    final ink = v.c.activeDocument.entities.slotOf(v.ink)!;
    expect(
        canvasOf(tester, 0)
            .painter
            .resolver
            .styleFor(ink, StyleContext.documentRoot)
            .argb,
        0xFFFFFFFF);
    seen = look(tester, await shoot(tester));
    expectLightInk(seen, 'no page, after the switch to dark');
    expectSelection(seen, PaperPalette.dark, 'no page, after the switch');

    await pumpThemed(tester, views([v.c]), ThemeMode.light);
    await tester.pump();
    seen = look(tester, await shoot(tester));
    expectDarkInk(seen, 'no page, back to light');
    expectSelection(seen, PaperPalette.light, 'no page, back to light');
  });

  testWidgets(
      'ServiceView, a theme switch with no camera move repaints the sheet '
      'edge in the dark chrome; White to Blueprint repaints the selection',
      (tester) async {
    final v = controllerOn(white);
    await pumpViews(tester, [v], ThemeMode.light,
        viewMode: FloorPlanMode.selection);
    final camera = v.c.camera.value;
    var seen = look(tester, await shoot(tester));
    expectEdge(seen, ChromePalette.light, 'light');

    await pumpThemed(tester, views([v.c]), ThemeMode.dark);
    await tester.pump();
    expect(identical(v.c.camera.value, camera), isTrue);
    seen = look(tester, await shoot(tester));
    expectEdge(seen, ChromePalette.dark, 'after the switch to dark');
    expectSelection(seen, PaperPalette.light, 'White stays the light set');

    final doc = v.c.activeDocument;
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        doc.components
            .get<PageComponent>(doc.rootHandle)!
            .copyWith(background: blueprint)));
    await tester.pump();
    seen = look(tester, await shoot(tester));
    expectSelection(seen, PaperPalette.dark, 'Blueprint');
    expectLightInk(seen, 'Blueprint');
  });
}
