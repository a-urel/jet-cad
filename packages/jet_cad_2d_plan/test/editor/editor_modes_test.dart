// Ported from jet_cad_floor_plan/test/host/bars_test.dart and
// test/host/table_overlay_test.dart; assertions unchanged.
//
// Ports, from bars_test.dart: the group "the canvas re-measured (R-13, S-10
// generalised)" (M-H47(serviceBar), T2-f, "a bar of the mode not shown
// changed"), the eight R-3 tests of "the review fixes" and K1; from
// table_overlay_test.dart: TO13, TO14, TO23 and TO32 (TO32 moved from Part
// A by controller ruling: its layer toggle is a structure command, so it
// runs on the design's canvas); from chrome_change_test.dart, the groups
// "F-2 a controller swapped and disposed in one step, a bar hidden" and
// "F-3 chrome changed in the mode shown keeps the plan in place" (no task
// placed them; they pin the chrome kept in place, `chromeMoved`, which
// M-SV-R2 removes; the editor capabilities -> `Caps` below: PlanEditor's
// permissions, which decide the left column, and its rulers). Each switches modes inside one widget,
// PlanEditor (2b spec S4; today's R-13 kept by the controller and the
// editor).
//
// Adaptations: FloorPlanView -> PlanEditor (`serviceBar:`, `bar:`);
// FloorPlanMode.selection -> PlanMode.service; cameraController -> camera;
// TableSurvey -> the controller's unit index; the editor capabilities'
// rulers -> PlanEditor's `rulers`, readOnly -> PlanPermissions.readOnly
// (no tool but select: no left column); the editor fixture -> Task 8's
// unit_editor_fixture.dart; the overlay test's helpers -> Part A's
// unit_overlay_test.dart. On the embedding fixture (turned, mirrored,
// scaled units 40 m off the origin) under `embeddingCamera()`.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform, kRulerThickness;
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_camera.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor_bar.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/view/plan_service_bar.dart';
import 'package:jet_cad_2d_plan/src/service/view/unit_overlays.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../service/view/unit_overlay_test.dart'
    show Badge, Calls, badgeOf, badgeWanted, expectRect, tableNumbered;
import '../support/service_fixtures.dart';
import '../support/service_host.dart' show serviceController;
import '../support/unit_editor_fixture.dart'
    show editorCamera, kEditorSurface, unitEditorPlanJson;

/// The bars the host rebuilds its view with, and what it heard.
final class BarHost {
  BarHost(this.c, PlanServiceBar service, PlanEditorBar editor)
      : bars = ValueNotifier((service, editor));

  final PlanController c;
  final ValueNotifier<(PlanServiceBar, PlanEditorBar)> bars;

  /// The sets `onMergeRequested` received.
  final List<Set<String>> merged = [];

  set service(PlanServiceBar bar) => bars.value = (bar, bars.value.$2);
  set editor(PlanEditorBar bar) => bars.value = (bars.value.$1, bar);
}

/// [embeddingPlanJson] in [mode] under an editor whose bars a [BarHost]
/// rebuilds; Export, Merge and Split offered unless told otherwise.
Future<BarHost> mountHost(WidgetTester tester,
    {PlanMode mode = PlanMode.service,
    PlanServiceBar service = const PlanServiceBar(),
    PlanEditorBar editor = const PlanEditorBar(),
    bool export = true,
    bool groups = true,
    PlanTheme? theme}) async {
  final c = serviceController();
  c.setMode(mode);
  final h = BarHost(c, service, editor);
  addTearDown(h.bars.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ValueListenableBuilder(
              valueListenable: h.bars,
              builder: (_, bars, __) => PlanEditor(
                  controller: c,
                  onExport: export ? (_) {} : null,
                  onMergeRequested: groups ? h.merged.add : null,
                  onSplitRequested: groups ? (_) {} : null,
                  serviceBar: bars.$1,
                  bar: bars.$2,
                  theme: theme)))));
  await tester.pump();
  await tester.pump();
  c.camera.value = embeddingCamera();
  await tester.pump();
  return h;
}

/// Where the shown canvas starts in the editor.
Offset canvasIn(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer)) -
    tester.getTopLeft(find.byType(PlanEditor));

/// World [w] on the screen, by the camera's forward transform from the
/// shown canvas's origin.
Offset globalOf(WidgetTester tester, PlanController c, Vector2 w) {
  final p = canvasOf(c.camera.value, w.x, w.y);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(p.x, p.y);
}

/// The world centre of unit [n]'s box in the active plan, by the
/// fixture's own transform of [embeddingBox]'s centre.
Vector2 centreOf(PlanController c, String n) {
  final d = c.activeDocument;
  final node =
      d.tree[c.unitIndex.withLabel(n).single.instance]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

void expectAt(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason (x)');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason (y)');
}

/// A switch into [mode], and unit 1 at its place: in the first frame
/// (drawn with the camera the switch left, before any correction after
/// it), with no correction after that frame, and, when [rect], by
/// `worldToGlobal` at the switch itself.
Future<void> expectFirstFrame(
    WidgetTester tester, PlanController c, PlanMode mode, String reason,
    {required bool rect}) async {
  final w = centreOf(c, '1');
  final at = globalOf(tester, c, w);
  c.setMode(mode);
  final m = c.camera.value.worldToScreenMatrix;
  if (rect) {
    expectAt(c.worldToGlobal(Offset(w.x, w.y))!, at,
        '$reason: worldToGlobal at the switch');
  }
  await tester.pump();
  final n = c.camera.value.worldToScreenMatrix;
  expect([n.a, n.b, n.c, n.d, n.e, n.f], [m.a, m.b, m.c, m.d, m.e, m.f],
      reason: '$reason: no correction after the frame');
  final layer = tester.getTopLeft(find.byType(InteractionLayer));
  final frame = canvasOf(ViewportTransform(worldToScreenMatrix: m), w.x, w.y);
  expectAt(layer + Offset(frame.x, frame.y), at, '$reason: the first frame');
  await tester.pump();
  expectAt(globalOf(tester, c, w), at, '$reason: settled');
}

/// table_overlay_test.dart's `mount` over PlanEditor: the host's builder
/// and the overlay modes, at 1440 x 900; then the fixture's camera.
Future<void> mountOverlays(WidgetTester tester, PlanController c,
    {PlanUnitOverlayBuilder? builder, Set<PlanMode>? modes}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: modes == null
              ? PlanEditor(controller: c, unitOverlayBuilder: builder)
              : PlanEditor(
                  controller: c,
                  unitOverlayBuilder: builder,
                  unitOverlayModes: modes))));
  await tester.pump();
  await tester.pump();
  c.camera.value = embeddingCamera();
  await tester.pump();
}

void main() {
  setUp(() => Badge.created = 0);

  group('the canvas re-measured (R-13, S-10 generalised)', () {
    /// Unit 1's box centre on the screen, read in each mode of
    /// design -> selection -> design, after each switch's frames.
    Future<void> expectKept(WidgetTester tester, PlanController c,
        List<PlanMode> modes, String reason) async {
      final w = centreOf(c, '1');
      final at = globalOf(tester, c, w);
      for (final mode in modes) {
        c.setMode(mode);
        await tester.pump();
        await tester.pump();
        expectAt(globalOf(tester, c, w), at, '$reason: $mode');
      }
    }

    testWidgets(
        'M-H47(serviceBar) hidden from the start: the controller measured '
        "the selection canvas at the view's top, and a round trip keeps a "
        'table in place at the first switch; shown at runtime, again',
        (tester) async {
      final h = await mountHost(tester,
          mode: PlanMode.design, service: const PlanServiceBar(visible: false));
      final c = h.c;
      final design = canvasIn(tester);
      await expectKept(
          tester, c, [PlanMode.service, PlanMode.design], 'hidden');
      c.setMode(PlanMode.service);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), Offset.zero);
      // The controller's selection origin, read by the reframing it makes
      // into the design: by (selection origin - design origin).
      final m = c.camera.value.worldToScreenMatrix;
      c.setMode(PlanMode.design);
      final n = c.camera.value.worldToScreenMatrix;
      expect(n.e - m.e, closeTo(0 - design.dx, 1e-9));
      expect(n.f - m.f, closeTo(0 - design.dy, 1e-9));
      await tester.pump();
      await tester.pump();

      c.setMode(PlanMode.service);
      await tester.pump();
      await tester.pump();
      h.service = const PlanServiceBar();
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), const Offset(0, kServiceBarHeight));
      await expectKept(tester, c, [PlanMode.design, PlanMode.service], 'shown');
      h.service = const PlanServiceBar(visible: false);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester), Offset.zero);
      await expectKept(
          tester, c, [PlanMode.design, PlanMode.service], 'hidden again');
    });

    testWidgets(
        'T2-f the editor bar hidden at runtime with the plan unchanged, '
        'then design -> selection -> design: a table keeps its place; shown '
        'again, the same', (tester) async {
      final h = await mountHost(tester, mode: PlanMode.design);
      final c = h.c;
      h.editor = const PlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, kRulerThickness));
      await expectKept(
          tester, c, [PlanMode.service, PlanMode.design], 'hidden');
      h.editor = const PlanEditorBar();
      await tester.pump();
      await tester.pump();
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, 44 + kRulerThickness));
      await expectKept(tester, c, [PlanMode.service, PlanMode.design], 'shown');
    });

    testWidgets(
        'a bar of the mode not shown changed: the next switch keeps the '
        'table in place (the seed corrected)', (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      h.editor = const PlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectKept(
          tester, c, [PlanMode.design, PlanMode.service], 'editor hidden');
    });
  });

  group('the review fixes (s4-task-2-review R-3)', () {
    testWidgets(
        'R-3 the service bar hidden from the start: the first switch into '
        'the selection mode is exact from its first frame', (tester) async {
      final h = await mountHost(tester,
          mode: PlanMode.design, service: const PlanServiceBar(visible: false));
      // M-SV-R3: canvasAssumed ignores the chrome.
      await expectFirstFrame(tester, h.c, PlanMode.service, 'hidden',
          rect: false);
      expect(canvasIn(tester), Offset.zero, reason: 'premise');
      await expectFirstFrame(tester, h.c, PlanMode.design, 'back', rect: true);
    });

    testWidgets(
        "R-3 the theme's 60 px service bar: the first switch into the "
        'selection mode is exact from its first frame', (tester) async {
      final h = await mountHost(tester,
          mode: PlanMode.design, theme: const PlanTheme(serviceBarHeight: 60));
      await expectFirstFrame(tester, h.c, PlanMode.service, 'theme 60',
          rect: false);
      expect(canvasIn(tester), const Offset(0, 60), reason: 'premise');
      await expectFirstFrame(tester, h.c, PlanMode.design, 'back', rect: true);
    });

    testWidgets(
        'R-3 the editor bar hidden while the selection mode is shown: the '
        'switch into the design mode is exact from its first frame, and '
        'worldToGlobal from the switch', (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      await expectFirstFrame(tester, c, PlanMode.design, 'first', rect: false);
      await expectFirstFrame(tester, c, PlanMode.service, 'back', rect: true);
      h.editor = const PlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.design, 'hidden', rect: true);
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, kRulerThickness),
          reason: 'premise');
      expect(c.canvasRect.value!.topLeft,
          tester.getTopLeft(find.byType(InteractionLayer)));
      await expectFirstFrame(tester, c, PlanMode.service, 'again', rect: true);
      h.editor = const PlanEditorBar();
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.design, 'shown', rect: true);
    });

    testWidgets(
        'R-3 the service bar hidden, then the theme\'s bar changed, while '
        'the design mode is shown: each switch into the selection mode is '
        'exact from its first frame, and worldToGlobal from the switch',
        (tester) async {
      final h = await mountHost(tester);
      final c = h.c;
      await expectFirstFrame(tester, c, PlanMode.design, 'first', rect: false);
      h.service = const PlanServiceBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'hidden', rect: true);
      expect(canvasIn(tester), Offset.zero, reason: 'premise');
      final size = c.canvasRect.value!.size;
      expect(size.height, tester.getSize(find.byType(InteractionLayer)).height,
          reason: 'the rect taken at the switch: the far corner kept');
      await expectFirstFrame(tester, c, PlanMode.design, 'back', rect: true);
      h.service = const PlanServiceBar();
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'shown', rect: true);
    });

    testWidgets(
        'R-3 a switch made while no view is shown, then a view whose service '
        'bar is hidden, unlike the last view\'s: the plan keeps its place '
        '(the shown mode is left to its measurement)', (tester) async {
      final c = serviceController();
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(PlanServiceBar? bar) => MaterialApp(
          home: Scaffold(
              body: bar == null
                  ? const SizedBox()
                  : PlanEditor(controller: c, serviceBar: bar)));
      await tester.pumpWidget(app(const PlanServiceBar()));
      await tester.pump();
      await tester.pump();
      c.camera.value = embeddingCamera();
      await tester.pump();
      final w = centreOf(c, '1');
      final at = globalOf(tester, c, w);
      await tester.pumpWidget(app(null));
      c.setMode(PlanMode.service);
      await tester.pumpWidget(app(const PlanServiceBar(visible: false)));
      await tester.pump();
      expect(canvasIn(tester), Offset.zero, reason: 'premise');
      expectAt(globalOf(tester, c, w), at, 'remounted in the selection mode');
    });

    testWidgets(
        'R-3 a bar hidden while its mode is shown, shown again while it is '
        'not: the next switch into it is exact from its first frame',
        (tester) async {
      final h = await mountHost(tester, mode: PlanMode.design);
      final c = h.c;
      h.editor = const PlanEditorBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'away', rect: false);
      h.editor = const PlanEditorBar();
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.design, 'editor back',
          rect: true);
      expect(canvasIn(tester),
          const Offset(240 + kRulerThickness, 44 + kRulerThickness),
          reason: 'premise');
      h.service = const PlanServiceBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'hidden', rect: true);
      h.service = const PlanServiceBar();
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.design, 'away again',
          rect: true);
      h.service = const PlanServiceBar(visible: false);
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'service back',
          rect: true);
    });

    testWidgets(
        "R-3 the ambient theme's service bar height changed while the design "
        'mode is shown, the view not rebuilt: the next switch into the '
        'selection mode is exact from its first frame', (tester) async {
      final c = serviceController();
      final height = ValueNotifier<double?>(null);
      addTearDown(height.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var builds = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ValueListenableBuilder<double?>(
                  valueListenable: height,
                  // The view is the builder's child: a theme change does not
                  // rebuild it.
                  child: Builder(builder: (context) {
                    builds++;
                    return PlanEditor(controller: c);
                  }),
                  builder: (context, h, child) => Theme(
                      data: ThemeData(extensions: [
                        if (h != null) PlanTheme(serviceBarHeight: h)
                      ]),
                      child: child!)))));
      await tester.pump();
      await tester.pump();
      c.camera.value = embeddingCamera();
      await tester.pump();
      height.value = 60;
      await tester.pump();
      await tester.pump();
      expect(builds, 1, reason: 'premise: the view was not rebuilt');
      await expectFirstFrame(tester, c, PlanMode.service, 'theme 60',
          rect: false);
      expect(canvasIn(tester), const Offset(0, 60), reason: 'premise');
      await expectFirstFrame(tester, c, PlanMode.design, 'back', rect: true);
      height.value = 52;
      await tester.pump();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.service, 'theme 52',
          rect: true);
      expect(canvasIn(tester), const Offset(0, 52), reason: 'premise');
    });

    testWidgets(
        "R-3 the editor's rulers and left column gone and back while the "
        'selection mode is shown: each switch into the design mode is exact '
        'from its first frame', (tester) async {
      final c = serviceController();
      c.setMode(PlanMode.service);
      final rulers = ValueNotifier(true);
      addTearDown(rulers.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ValueListenableBuilder(
                  valueListenable: rulers,
                  builder: (_, v, __) =>
                      PlanEditor(controller: c, rulers: v)))));
      await tester.pump();
      await tester.pump();
      c.camera.value = embeddingCamera();
      await tester.pump();
      await expectFirstFrame(tester, c, PlanMode.design, 'full', rect: false);
      for (final (name, ruled, permissions, origin) in [
        ('no rulers', false, PlanPermissions.full, const Offset(240, 44)),
        (
          'readOnly, no left column',
          true,
          PlanPermissions.readOnly,
          const Offset(kRulerThickness, 44 + kRulerThickness)
        ),
        (
          'full again',
          true,
          PlanPermissions.full,
          const Offset(240 + kRulerThickness, 44 + kRulerThickness)
        ),
      ]) {
        await expectFirstFrame(tester, c, PlanMode.service, name, rect: true);
        rulers.value = ruled;
        c.permissions = permissions;
        await tester.pump();
        await tester.pump();
        // M-SV-R5: the left column always counted.
        await expectFirstFrame(tester, c, PlanMode.design, name, rect: true);
        expect(canvasIn(tester), origin, reason: '$name: premise');
      }
    });
  });

  testWidgets(
      'K1 (final review F-6, mutant S05) the service bar hidden, the '
      'selection mode shown first: a round trip through the design mode, '
      'the host rebuilding its view there, comes back exact from its first '
      'frame', (tester) async {
    final c = serviceController(json: unitEditorPlanJson());
    c.setMode(PlanMode.service);
    await tester.binding.setSurfaceSize(kEditorSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rebuild = ValueNotifier(0);
    addTearDown(rebuild.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder<int>(
                valueListenable: rebuild,
                builder: (_, n, __) => PlanEditor(
                    controller: c,
                    exportName: 'plan$n',
                    serviceBar: const PlanServiceBar(visible: false))))));
    await tester.pump();
    await tester.pump();
    c.camera.value = editorCamera();
    await tester.pump();
    Offset at(ViewportTransform camera) {
      final p = canvasOf(camera, 22000, 16000);
      return tester.getTopLeft(find.byType(InteractionLayer)) +
          Offset(p.x, p.y);
    }

    final before = at(c.camera.value);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expectAt(at(c.camera.value), before, 'design');
    // The host rebuilds its view while the design mode is shown: the view
    // assumes the selection canvas from its chrome against the basis its
    // first measurement recorded.
    rebuild.value++;
    await tester.pump();
    await tester.pump();
    c.setMode(PlanMode.service);
    // The camera the switch made, read before the frame's measurement.
    final m = c.camera.value;
    await tester.pump();
    expectAt(at(m), before, 'the first frame back in the selection mode');
    await tester.pump();
    expectAt(at(c.camera.value), before, 'settled');
  });

  testWidgets(
      'TO13 overlays are not shown in the design mode by default; asked for, '
      'they are, on the design\'s canvas (M-H19b(design default), G-5)',
      (tester) async {
    final c = serviceController();
    final calls = Calls();
    await mountOverlays(tester, c, builder: calls.builder());
    expect(find.byType(Badge, skipOffstage: false), findsNothing,
        reason: 'M-H19b: the design mode shows none by default');
    expect(find.byType(UnitOverlayLayer), findsNothing);
    expect(calls.total, 0);

    final d = serviceController();
    await mountOverlays(tester, d,
        builder: calls.builder(), modes: {PlanMode.design});
    expect(find.byType(Badge, skipOffstage: false), findsNWidgets(7));
    expectRect(tester.getRect(badgeOf('1')),
        badgeWanted(tester, tableNumbered('1'), embeddingCamera()), 'design');
    d.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Badge, skipOffstage: false), findsNothing,
        reason: 'not asked for in the selection mode');
  });

  testWidgets('TO14 no builder: no layer in the tree, in either mode (H-8)',
      (tester) async {
    final c = serviceController();
    await mountOverlays(tester, c);
    expect(find.byType(UnitOverlayLayer), findsNothing);
    expect(
        tester.allRenderObjects.whereType<RenderPlanUnitOverlays>(), isEmpty);
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    expect(find.byType(UnitOverlayLayer), findsNothing);
    expect(
        tester.allRenderObjects.whereType<RenderPlanUnitOverlays>(), isEmpty);
  });

  testWidgets(
      'TO23 overlays in both modes across mode switches, then camera '
      'changes: no listener outlives its render object (review R-4)',
      (tester) async {
    final c = serviceController();
    c.setMode(PlanMode.service);
    await mountOverlays(tester, c,
        builder: Calls().builder(), modes: {PlanMode.service, PlanMode.design});
    for (final mode in [PlanMode.design, PlanMode.service]) {
      c.setMode(mode);
      await tester.pump();
      await tester.pump();
      c.panBy(const Offset(10, 10));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: mode.name);
    }
    expect(tester.allRenderObjects.whereType<RenderPlanUnitOverlays>(),
        hasLength(1));
  });

  testWidgets(
      'TO32 each overlay is keyed by its own table\'s instance: with the '
      'hidden 5 before L and the 7s, showing and hiding its layer keeps '
      'every other badge\'s State (final review F-4)', (tester) async {
    final c = serviceController();
    final calls = Calls();
    await mountOverlays(tester, c,
        builder: calls.builder(), modes: {PlanMode.design});
    Map<Offset, State> states() => {
          for (final e in find.byType(Badge).evaluate())
            (e.widget as Badge).overlay.detail.center!:
                (e as StatefulElement).state,
        };
    final before = states();
    expect(before.length, 7, reason: 'premise: 5 is hidden');
    final created = Badge.created;
    final d = c.activeDocument;
    final hidden = d.tables.layers.byName(kEmbeddingHidden)!;

    d.commands.execute(SetLayerCommand(hidden.copyWith(visible: true)));
    await tester.pump();
    await tester.pump();
    final shown = states();
    expect(shown.length, 8, reason: '5 is shown');
    expect(Badge.created, created + 1, reason: 'only 5\'s badge is new');
    for (final MapEntry(key: at, value: state) in before.entries) {
      expect(identical(shown[at], state), isTrue,
          reason: 'the badge at $at keeps its State');
    }

    final again = Badge.created;
    d.commands.execute(SetLayerCommand(
        d.tables.layers.byName(kEmbeddingHidden)!.copyWith(visible: false)));
    await tester.pump();
    await tester.pump();
    final after = states();
    expect(after.length, 7, reason: '5 is hidden again');
    expect(Badge.created, again, reason: 'no badge is new');
    for (final MapEntry(key: at, value: state) in before.entries) {
      expect(identical(after[at], state), isTrue,
          reason: 'the badge at $at keeps its State');
    }
  });

  // ---- chrome_change_test.dart: F-2 and F-3 ----

  group('F-2 a controller swapped and disposed in one step, a bar hidden', () {
    for (final mode in PlanMode.values) {
      for (final (name, service, editor, caps) in [
        (
          'the service bar hidden',
          const PlanServiceBar(visible: false),
          const PlanEditorBar(),
          Caps.full
        ),
        (
          'the editor bar hidden',
          const PlanServiceBar(),
          const PlanEditorBar(visible: false),
          Caps.full
        ),
        (
          'both bars hidden, no column, read only',
          const PlanServiceBar(visible: false),
          const PlanEditorBar(visible: false),
          kNoColumns
        ),
      ]) {
        testWidgets('${mode.name}, $name: no assertion', (tester) async {
          // Disposed by the test, as the host does.
          final a = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
          final h = await mountChrome(tester,
              mode: mode,
              service: service,
              editor: editor,
              caps: caps,
              controller: a);
          final b = PlanController(kits: [fxKit()], json: unitEditorPlanJson())
            ..setMode(mode);
          addTearDown(b.dispose);
          h.controller.value = b;
          a.dispose();
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(InteractionLayer), findsOneWidget,
              reason: 'premise: the new plan shown');
        });
      }
    }
  });

  group('F-3 chrome changed in the mode shown keeps the plan in place', () {
    /// Changes the chrome by [change] and checks, at the first frame, that
    /// unit 1 is where it was by the camera, by its overlay and in the
    /// pixels around it; after the frame, that `canvasRect` and
    /// `worldToGlobal` agree; at the next, that the host's widget beside
    /// the view was built with the camera. Returns the canvas's move.
    Future<Offset> expectKept(WidgetTester tester, ChromeHost h,
        void Function() change, String reason) async {
      final c = h.c;
      final w = centreOf(c, '1');
      final at = chromeGlobalOf(tester, c, w);
      final overlay = overlayAt(tester, '1');
      final canvas = canvasOrigin(tester);
      final before = await shootView(tester);
      change();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: reason);
      final moved = canvasOrigin(tester) - canvas;
      expect(moved, isNot(Offset.zero), reason: '$reason: premise');
      // M-SV-R2: chromeMoved pans nothing.
      expectAt(
          chromeGlobalOf(tester, c, w), at, '$reason: frame 1, the camera');
      expectAt(overlayAt(tester, '1'), overlay, '$reason: frame 1, overlay');
      final after = await shootView(tester);
      expect(
          largestDifference(pixelsAt(after, at, 30), pixelsAt(before, at, 30)),
          lessThanOrEqualTo(2),
          reason: '$reason: frame 1, the pixels');
      // After the frame: the rect, worldToGlobal and the host's listener.
      expect(c.canvasRect.value!.topLeft, canvasOrigin(tester),
          reason: '$reason: canvasRect');
      expectAt(
          c.worldToGlobal(Offset(w.x, w.y))!, at, '$reason: worldToGlobal');
      await tester.pump();
      expect(identical(h.heard.last, c.cameraValue.value), isTrue,
          reason: '$reason: the host heard the pan');
      expectAt(chromeGlobalOf(tester, c, w), at, '$reason: settled');
      expectAt(overlayAt(tester, '1'), overlay, '$reason: overlay settled');
      return moved;
    }

    testWidgets(
        'design: the left column hidden (full -> readOnly) and shown again',
        (tester) async {
      final h = await mountChrome(tester);
      expect(
          await expectKept(
              tester, h, () => h.caps.value = Caps.readOnly, 'hidden'),
          const Offset(-240, 0));
      expect(
          await expectKept(tester, h, () => h.caps.value = Caps.full, 'shown'),
          const Offset(240, 0));
    });

    testWidgets(
        'design: the editor bar hidden and shown, then the rulers off and '
        'on', (tester) async {
      final h = await mountChrome(tester);
      expect(
          await expectKept(
              tester,
              h,
              () => h.editor.value = const PlanEditorBar(visible: false),
              'bar hidden'),
          const Offset(0, -44));
      expect(
          await expectKept(tester, h,
              () => h.editor.value = const PlanEditorBar(), 'bar shown'),
          const Offset(0, 44));
      expect(
          await expectKept(tester, h,
              () => h.caps.value = Caps.full.copyWith(rulers: false), 'off'),
          const Offset(-kRulerThickness, -kRulerThickness));
      expect(await expectKept(tester, h, () => h.caps.value = Caps.full, 'on'),
          const Offset(kRulerThickness, kRulerThickness));
    });

    testWidgets(
        'selection: a 60 px service bar hidden and shown; a change of the '
        "theme's bar height, 60 -> 44, still moves the plan with the canvas "
        "(Slice 3's S-10)", (tester) async {
      final h = await mountChrome(tester,
          mode: PlanMode.service, theme: const PlanTheme(serviceBarHeight: 60));
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const PlanServiceBar(visible: false),
              'hidden'),
          const Offset(0, -60));
      expect(
          await expectKept(tester, h,
              () => h.service.value = const PlanServiceBar(), 'shown'),
          const Offset(0, 60));
      final c = h.c;
      final w = centreOf(c, '1');
      final at = chromeGlobalOf(tester, c, w);
      final m = c.camera.value;
      h.theme.value = const PlanTheme(serviceBarHeight: 44);
      await tester.pump();
      await tester.pump();
      expect(identical(c.camera.value, m), isTrue,
          reason: 'no pan for the theme');
      expectAt(chromeGlobalOf(tester, c, w), at - const Offset(0, 16),
          'the plan moved with the canvas');
      // Hidden at 44 now: the pan is the bar's height today.
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const PlanServiceBar(visible: false),
              'hidden at 44'),
          const Offset(0, -44));
    });

    testWidgets(
        'a mode switch after a change in place still keeps the plan: '
        'design, the left column hidden, then selection and back',
        (tester) async {
      final h = await mountChrome(tester);
      await expectKept(tester, h, () => h.caps.value = Caps.readOnly, 'hidden');
      final c = h.c;
      final w = centreOf(c, '1');
      final at = chromeGlobalOf(tester, c, w);
      for (final mode in [PlanMode.service, PlanMode.design]) {
        c.setMode(mode);
        await tester.pump();
        expectAt(chromeGlobalOf(tester, c, w), at, '$mode: frame 1');
        await tester.pump();
        expectAt(chromeGlobalOf(tester, c, w), at, '$mode: settled');
      }
    });

    testWidgets(
        'a change right after a mode switch the host made without '
        'rebuilding its view: the selection mode, its bar hidden',
        (tester) async {
      final h = await mountChrome(tester);
      h.c.setMode(PlanMode.service);
      await tester.pump();
      await tester.pump();
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const PlanServiceBar(visible: false),
              'hidden'),
          const Offset(0, -44));
    });

    for (final mode in PlanMode.values) {
      testWidgets(
          '${mode.name}: a host rebuild with the default chrome moves '
          'nothing (the camera the identical value)', (tester) async {
        final h = await mountChrome(tester, mode: mode);
        final m = h.c.camera.value;
        h.caps.value = Caps.full.copyWith();
        h.service.value =
            const PlanServiceBar(actions: PlanServiceAction.values);
        h.editor.value = const PlanEditorBar(actions: PlanEditorAction.values);
        await tester.pump();
        await tester.pump();
        expect(identical(h.c.camera.value, m), isTrue);
      });
    }

    testWidgets(
        'a controller swapped back with other chrome in one step: its camera '
        "is its own, not panned by the chrome the other's plan was laid out "
        'in', (tester) async {
      final a = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
      addTearDown(a.dispose);
      final h = await mountChrome(tester);
      final b = h.c;
      final m = b.camera.value.worldToScreenMatrix;
      h.controller.value = a;
      await tester.pump();
      await tester.pump();
      h.controller.value = b;
      h.caps.value = Caps.readOnly;
      await tester.pump();
      await tester.pump();
      final n = b.camera.value.worldToScreenMatrix;
      expect((n.a, n.e, n.f), (m.a, m.e, m.f));
    });

    testWidgets(
        "the camera's notification held for after the frame is dropped when "
        'the controller is disposed first', (tester) async {
      final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
      var heard = 0;
      c.cameraValue.addListener(() => heard++);
      final m = c.camera.value.worldToScreenMatrix;
      c.chromeMoved(const Offset(240, 44), Offset.zero);
      final n = c.camera.value.worldToScreenMatrix;
      expect((n.e - m.e, n.f - m.f), (240, 44), reason: 'panned at once');
      expect(heard, 0, reason: 'heard after the frame');
      c.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(heard, 0);
    });

    testWidgets("the camera's held notification arrives after the frame",
        (tester) async {
      final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
      addTearDown(c.dispose);
      var heard = 0;
      c.cameraValue.addListener(() => heard++);
      c.chromeMoved(const Offset(0, 60), Offset.zero);
      c.chromeMoved(const Offset(0, 0), const Offset(0, 60));
      expect(heard, 0);
      await tester.pump();
      expect(heard, 1, reason: 'one notification for the frame');
    });
  });
}

// ---- chrome_change_test.dart's host ----

/// Today's editor capabilities as PlanEditor has them: the permissions (no
/// tool but Select: no left column) and the rulers.
final class Caps {
  const Caps(this.permissions, {this.rulers = true, this.panels = true});

  final PlanPermissions permissions;
  final bool rulers;

  /// The right column's panels.
  final bool panels;

  static const Caps full = Caps(PlanPermissions.full);
  static const Caps readOnly = Caps(PlanPermissions.readOnly);

  Caps copyWith({bool? rulers}) =>
      Caps(permissions, rulers: rulers ?? this.rulers, panels: panels);
}

/// No side column: no tool but Select, no panel.
const Caps kNoColumns = Caps(PlanPermissions.readOnly, panels: false);

/// The view's chrome as a host rebuilds it.
final class ChromeHost {
  ChromeHost(PlanController c, Caps caps, PlanServiceBar service,
      PlanEditorBar editor, PlanTheme? theme)
      : controller = ValueNotifier(c),
        caps = ValueNotifier(caps),
        service = ValueNotifier(service),
        editor = ValueNotifier(editor),
        theme = ValueNotifier(theme) {
    // The permissions are the controller's: set outside the build.
    this.caps.addListener(_permit);
    controller.addListener(_permit);
    _permit();
  }

  final ValueNotifier<PlanController> controller;
  final ValueNotifier<Caps> caps;
  final ValueNotifier<PlanServiceBar> service;
  final ValueNotifier<PlanEditorBar> editor;
  final ValueNotifier<PlanTheme?> theme;

  /// The camera values a host widget outside the view was built with.
  final List<PlanCamera> heard = [];

  PlanController get c => controller.value;

  void _permit() {
    if (!c.isDisposed) c.permissions = caps.value.permissions;
  }

  void dispose() {
    controller.dispose();
    caps.dispose();
    service.dispose();
    editor.dispose();
    theme.dispose();
  }
}

final GlobalKey chromeShotKey = GlobalKey();

/// The unit editor fixture in [mode] under an editor whose chrome a
/// [ChromeHost] rebuilds, with a host overlay on every unit in both modes
/// and a host widget beside the editor that rebuilds on the camera.
Future<ChromeHost> mountChrome(WidgetTester tester,
    {PlanMode mode = PlanMode.design,
    Caps caps = Caps.full,
    PlanServiceBar service = const PlanServiceBar(),
    PlanEditorBar editor = const PlanEditorBar(),
    PlanTheme? theme,
    PlanController? controller}) async {
  final c =
      controller ?? PlanController(kits: [fxKit()], json: unitEditorPlanJson());
  if (controller == null) addTearDown(c.dispose);
  c.setMode(mode);
  final h = ChromeHost(c, caps, service, editor, theme);
  addTearDown(h.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListenableBuilder(
              listenable: Listenable.merge(
                  [h.controller, h.caps, h.service, h.editor, h.theme]),
              builder: (_, __) => Column(children: [
                    // A host widget outside the view that rebuilds on the
                    // camera: notified while the view builds, it would
                    // assert.
                    ValueListenableBuilder<PlanCamera>(
                        valueListenable: h.c.cameraValue,
                        builder: (_, camera, __) {
                          h.heard.add(camera);
                          return const SizedBox(height: 10);
                        }),
                    Expanded(
                        child: RepaintBoundary(
                            key: chromeShotKey,
                            child: PlanEditor(
                                controller: h.c,
                                rulers: h.caps.value.rulers,
                                propertyPanel: h.caps.value.panels,
                                layerPanel: h.caps.value.panels,
                                pagePanel: h.caps.value.panels,
                                serviceBar: h.service.value,
                                bar: h.editor.value,
                                theme: h.theme.value,
                                unitOverlayModes: const {
                                  PlanMode.design,
                                  PlanMode.service
                                },
                                unitOverlayBuilder: (_, unit) => SizedBox(
                                    key: Key(
                                        'overlay-${unit.detail.unit.label}'),
                                    width: 12,
                                    height: 12)))),
                  ])))));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return h;
}

/// The shown canvas's top left, global.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform from the
/// shown canvas's origin (chrome_change_test.dart's `globalOf`).
Offset chromeGlobalOf(WidgetTester tester, PlanController c, Vector2 w) {
  final p = canvasOf(c.camera.value, w.x, w.y);
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

/// The editor's pixels, and the shot's width and global origin.
Future<(ByteData, int, Offset)> shootView(WidgetTester tester) async {
  final boundary = chromeShotKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  final origin = boundary.localToGlobal(Offset.zero);
  final (bytes, width) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (raw!, width);
  }))!;
  return (bytes, width, origin);
}

/// The pixels of the global square of side 2 × [r] about [at].
List<int> pixelsAt((ByteData, int, Offset) shot, Offset at, int r) {
  final (bytes, width, origin) = shot;
  final x0 = (at.dx - origin.dx).round(), y0 = (at.dy - origin.dy).round();
  return [
    for (var y = y0 - r; y < y0 + r; y++)
      for (var x = x0 - r; x < x0 + r; x++)
        bytes.getUint32((y * width + x) * 4),
  ];
}

/// The largest difference of one channel between two runs of pixels. A
/// layer drawn at another offset in its parent may round an edge's
/// coverage one level apart; a plan moved by even a pixel differs by far
/// more.
int largestDifference(List<int> a, List<int> b) {
  var most = 0;
  for (var i = 0; i < a.length; i++) {
    for (var shift = 0; shift < 32; shift += 8) {
      final d = ((a[i] >> shift) & 0xff) - ((b[i] >> shift) & 0xff);
      if (d.abs() > most) most = d.abs();
    }
  }
  return most;
}

/// Unit [n]'s overlay centre, global.
Offset overlayAt(WidgetTester tester, String n) =>
    tester.getCenter(find.byKey(Key('overlay-$n')));
