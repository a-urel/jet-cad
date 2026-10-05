// Dark canvas decision note (2026-10-05) K1–K3, wired: the host's views,
// design mode (the shell) and selection mode (`ServiceView`), read back in
// pixels under the floor planner's seed (support/palette_fixture.dart).
//
// Beside the fixture's ACI 7 lines the document carries two fixed colours
// as the planner draws them: a wall-black `TrueColor(0x000000)` line and a
// floor-finish `TrueColor(0xBBBBBB)` line. Each lies a whole number of
// pixels below the sheet's top, so it sits on pixel centres.
//
// Named mutants: M-DC-2 (Blueprint shown dark too), M-DC-3 (`_paperArgb`
// back to the page's background), M-DC-4 (the re-toning resolver not
// installed), M-DC-1 through the widgets (the sheet keeps the page's fill).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/palette_fixture.dart';

/// The fixed-colour lines' y: 3000 and 2800 mm below the sheet's top
/// (7200), whole multiples of 8 mm.
const double wallY = 4200, finishY = 4400;

/// A sheet pixel clear of every line.
final Vector2 bare = Vector2(10500, 6400);

FloorPlanController controllerOn(int paper) {
  final m = FlutterTextMeasurer();
  final f = paletteDoc(m, paper: paper);
  for (final (y, rgb) in [(wallY, 0x000000), (finishY, 0xBBBBBB)]) {
    f.doc.commands.execute(AddEntityCommand(
      record: draftRecord(
          f.doc.handleSeed.next(), f.doc.rootHandle, EntityKind.line,
          layer: ReservedHandles.layerZero, color: TrueColor(rgb)),
      payload: linePayload(Vector2(lineX0, y), Vector2(lineX1, y)),
    ));
  }
  final json = DraftDocumentCodec.encodeToString(f.doc);
  f.doc.dispose();
  m.clear();
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  return c;
}

Future<void> pumpView(WidgetTester tester, FloorPlanController c,
    ThemeMode mode, FloorPlanMode viewMode) async {
  windowAt(tester, const Size(1440, 900));
  c.setMode(viewMode);
  await pumpThemed(tester, Scaffold(body: FloorPlanView(controller: c)), mode);
  await tester.pump();
  await tester.pump();
  c.camera.value = paletteCamera;
  await tester.pump();
}

/// The brightest pixel of the 3 x 3 block on the line at [y].
int lineAt(WidgetTester tester, Shot shot, double y) {
  final (x, py) = pixelOf(tester, Vector2(sampleX, y));
  return shot.brightest(x, py);
}

/// The darkest pixel of the 3 x 3 block on the line at [y]: the line's
/// own colour on a light paper.
int darkLineAt(WidgetTester tester, Shot shot, double y) {
  final (x, py) = pixelOf(tester, Vector2(sampleX, y));
  return shot.darkest(x, py);
}

int bareAt(WidgetTester tester, Shot shot) {
  final (x, y) = pixelOf(tester, bare);
  return shot.rgbAt(x, y);
}

void main() {
  for (final viewMode in FloorPlanMode.values) {
    group('${viewMode.name} mode', () {
      testWidgets(
          'M-DC-1, M-DC-3, M-DC-4: dark theme on White: the sheet is '
          'kDarkCanvasPaper, the black wall white, the light-grey finish '
          'dark grey, ACI 7 white, the overlays the dark set; the page '
          'keeps White', (tester) async {
        final c = controllerOn(white);
        await pumpView(tester, c, ThemeMode.dark, viewMode);
        final shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(kDarkCanvasPaper & 0xFFFFFF));
        final wall = lineAt(tester, shot, wallY);
        expect(channelDistance(wall, 0xFFFFFF), lessThanOrEqualTo(24),
            reason: 'wall ${hex(wall)}');
        final finish = lineAt(tester, shot, finishY);
        final want = darkCanvasTone(0xBBBBBB, kDarkCanvasPaper);
        expect(channelDistance(finish, want), lessThanOrEqualTo(12),
            reason: 'finish ${hex(finish)}, want ${hex(want)}');
        final ink = lineAt(tester, shot, inkY);
        expect(channelDistance(ink, 0xFFFFFF), lessThanOrEqualTo(24),
            reason: 'ACI 7 ${hex(ink)}');

        final view = tester.widget<PlannerView>(find.byType(PlannerView));
        expect(view.paper, PaperPalette.dark);
        expect(view.sheetArgb, kDarkCanvasPaper);
        expect(view.resolver, isA<DarkCanvasStyleResolver>());
        final doc = c.activeDocument;
        expect(doc.components.get<PageComponent>(doc.rootHandle)!.background,
            white,
            reason: 'display only (K4)');
      });

      testWidgets(
          'M-DC-2: dark theme on Blueprint: the sheet stays Blueprint and '
          'nothing is re-toned: the black wall stays black', (tester) async {
        final c = controllerOn(blueprint);
        await pumpView(tester, c, ThemeMode.dark, viewMode);
        final shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(blueprint & 0xFFFFFF));
        final wall = lineAt(tester, shot, wallY);
        expect(
            channelDistance(wall, blueprint & 0xFFFFFF), lessThanOrEqualTo(12),
            reason: 'the black wall\'s brightest pixel is the paper '
                '${hex(wall)}');
        final view = tester.widget<PlannerView>(find.byType(PlannerView));
        expect(view.sheetArgb, isNull);
        expect(view.resolver, isA<DocumentStyleResolver>());
      });

      testWidgets(
          'light theme on White: as before: a white sheet, black wall, the '
          'finish its own grey; a live switch to dark and back re-tones and '
          'restores', (tester) async {
        final c = controllerOn(white);
        await pumpView(tester, c, ThemeMode.light, viewMode);
        var shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(0xFFFFFF));
        expect(channelDistance(darkLineAt(tester, shot, finishY), 0xBBBBBB),
            lessThanOrEqualTo(12));
        expect(channelDistance(darkLineAt(tester, shot, wallY), 0x000000),
            lessThanOrEqualTo(24));
        expect(tester.widget<PlannerView>(find.byType(PlannerView)).sheetArgb,
            isNull);

        await pumpThemed(tester, Scaffold(body: FloorPlanView(controller: c)),
            ThemeMode.dark);
        await tester.pump();
        shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(kDarkCanvasPaper & 0xFFFFFF));
        expect(channelDistance(lineAt(tester, shot, wallY), 0xFFFFFF),
            lessThanOrEqualTo(24));

        await pumpThemed(tester, Scaffold(body: FloorPlanView(controller: c)),
            ThemeMode.light);
        await tester.pump();
        shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(0xFFFFFF));
        expect(channelDistance(darkLineAt(tester, shot, finishY), 0xBBBBBB),
            lessThanOrEqualTo(12));
      });

      testWidgets(
          'dark theme, White to Blueprint and back: the sheet and the '
          'resolver follow the page', (tester) async {
        final c = controllerOn(white);
        await pumpView(tester, c, ThemeMode.dark, viewMode);
        final doc = c.activeDocument;
        void setPaper(int argb) =>
            doc.commands.execute(SetComponentCommand<PageComponent>(
                doc.rootHandle,
                doc.components
                    .get<PageComponent>(doc.rootHandle)!
                    .copyWith(background: argb)));
        setPaper(blueprint);
        await tester.pump();
        await tester.pump();
        var shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(blueprint & 0xFFFFFF));
        expect(tester.widget<PlannerView>(find.byType(PlannerView)).resolver,
            isA<DocumentStyleResolver>());

        setPaper(0xFFFAF6EC); // Ivory: light, so shown dark again
        await tester.pump();
        await tester.pump();
        shot = await shoot(tester);
        expect(hex(bareAt(tester, shot)), hex(kDarkCanvasPaper & 0xFFFFFF));
        expect(channelDistance(lineAt(tester, shot, wallY), 0xFFFFFF),
            lessThanOrEqualTo(24));
      });
    });
  }
}
