// Ported from jet_cad_floor_plan/test/host/bars_test.dart and
// test/host/table_overlay_test.dart; assertions unchanged.
//
// Ports, from bars_test.dart: the group "the canvas re-measured (R-13, S-10
// generalised)" (M-H47(serviceBar), T2-f, "a bar of the mode not shown
// changed"), the eight R-3 tests of "the review fixes" and K1; from
// table_overlay_test.dart: TO13, TO14, TO23 and TO32 (TO32 moved from Part
// A by controller ruling: its layer toggle is a structure command, so it
// runs on the design's canvas). Each switches modes inside one widget,
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
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform, kRulerThickness;
import 'package:jet_cad_2d_plan/src/controller/permissions.dart';
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
      // M-SV-R2: chromeMoved pans nothing.
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
}
