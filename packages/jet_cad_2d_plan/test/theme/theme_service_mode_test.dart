// Ported from jet_cad_floor_plan/test/host/floor_plan_theme_test.dart;
// assertions unchanged.
//
// Ports (controller ruling R-15; Task 15's plan decision "what moves to
// Task 16"): the selection runs of the group "resolution (T-2, S-11), in
// both modes" (P-6, M-H30 and the ambient switch, each run for
// PlanMode.service through PlanEditor; the design runs are 2a's,
// editor/editor_theme_test.dart), and the tests at :832-1020 that read
// the service view: "G-5, H-8: an ambient switch …", "G-5, H-8: a
// scope-only change …", R-1 and R-2. Not ported again (already ported
// by 2a in design form): "a host rebuild with an equal, non-identical
// view theme …" (editor_theme_test.dart, and TH17), S-12 (ED-7,
// plan_editor_test.dart) and "FloorPlanTheme through the barrel alone"
// (editor_theme_test.dart).
//
// Host embedding API spec, Slice 3, T-2, S-11, T-3 and G-5 (2b spec S4
// "Painting"): the theme's resolution below PlanEditor in service, the
// ambient extension with the view's set fields over it, provided by an
// inherited widget compared by `==`, so a theme change rebuilds no host
// overlay. The plan is the embedding fixture (units turned, mirrored and
// scaled 40 m off the origin) under its panned camera.
//
// Adaptations: FloorPlanView -> PlanEditor; FloorPlanMode.selection ->
// PlanMode.service; the theme read inside ServiceView -> inside the
// service view's canvas (PlanCanvasView); tableOverlayBuilder ->
// unitOverlayBuilder; cameraController -> camera; the themes, the field
// table and the reader -> Task 15's plan_theme_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/view/unit_overlays.dart';
import 'package:jet_cad_2d_plan/src/theme/plan_theme.dart';

import '../support/service_fixtures.dart' show embeddingCamera;
import '../support/service_host.dart' show serviceController;
import 'plan_theme_test.dart'
    show
        ThemeReader,
        darkTheme,
        darkWith,
        edgeA,
        edgeB,
        expectWithinEnds,
        fullA,
        fullB,
        lightTheme,
        lightWith;

/// The embedding fixture's controller in [mode].
PlanController controllerIn(PlanMode mode) {
  final c = serviceController();
  c.setMode(mode);
  return c;
}

/// The resolved theme as an element under the service view's scope reads
/// it (today's read inside ServiceView).
PlanTheme? resolvedIn(WidgetTester tester, PlanMode mode) {
  expect(mode, PlanMode.service, reason: 'the service runs alone');
  return PlanThemeScope.of(tester.element(find.byType(PlanCanvasView)));
}

/// Pumps [view] at 1440 x 900 under [theme] (zero theme animation) and
/// lets the first frames land.
Future<void> pumpUnder(WidgetTester tester, Widget view,
    {ThemeData? theme,
    ThemeData? dark,
    ThemeMode mode = ThemeMode.light}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      theme: theme ?? lightTheme,
      darkTheme: dark ?? darkTheme,
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(body: view)));
  await tester.pump();
}

void main() {
  group('resolution (T-2, S-11), in both modes', () {
    for (final mode in [PlanMode.service]) {
      testWidgets(
          'P-6 (${mode.name}): no theme anywhere resolves to null; ambient '
          'only is the ambient itself; view only the view itself',
          (tester) async {
        final c = controllerIn(mode);
        await pumpUnder(tester, PlanEditor(controller: c));
        expect(resolvedIn(tester, mode), isNull);

        await pumpUnder(tester, PlanEditor(controller: c),
            theme: lightWith(fullA));
        expect(identical(resolvedIn(tester, mode), fullA), isTrue);

        await pumpUnder(tester, PlanEditor(controller: c, theme: fullB));
        expect(identical(resolvedIn(tester, mode), fullB), isTrue);
      });

      testWidgets(
          'M-H30 (${mode.name}): one field in the ambient theme and another '
          'in the view\'s resolve to both; one field in both takes the '
          'view\'s', (tester) async {
        final c = controllerIn(mode);
        await pumpUnder(
            tester,
            PlanEditor(
                controller: c,
                theme: const PlanTheme(selectionOnLight: Color(0xFFD81B60))),
            theme:
                lightWith(const PlanTheme(groupFrameColor: Color(0xFF00897B))));
        expect(
            resolvedIn(tester, mode),
            const PlanTheme(
                groupFrameColor: Color(0xFF00897B),
                selectionOnLight: Color(0xFFD81B60)));

        await pumpUnder(
            tester,
            PlanEditor(
                controller: c, theme: const PlanTheme(selectionWidth: 5)),
            theme: lightWith(const PlanTheme(
                selectionWidth: 3, groupFrameColor: Color(0xFF00897B))));
        expect(
            resolvedIn(tester, mode),
            const PlanTheme(
                selectionWidth: 5, groupFrameColor: Color(0xFF00897B)));
      });

      testWidgets(
          'an ambient switch (light with A to dark with B, zero animation) '
          'reaches the ${mode.name} mode after one pump', (tester) async {
        final c = controllerIn(mode);
        final view = PlanEditor(controller: c);
        await pumpUnder(tester, view,
            theme: lightWith(fullA), dark: darkWith(fullB));
        expect(resolvedIn(tester, mode), fullA);
        await pumpUnder(tester, view,
            theme: lightWith(fullA),
            dark: darkWith(fullB),
            mode: ThemeMode.dark);
        expect(resolvedIn(tester, mode), fullB);
      });
    }
  });

  /// A badge per overlaid unit, counting the builder's calls.
  Widget? Function(BuildContext, PlanUnitOverlay) counting(List<int> calls) =>
      (context, table) {
        calls[0]++;
        return const SizedBox(width: 20, height: 10);
      };

  const viewTheme = PlanTheme(selectionWidth: 4.5);
  const other = PlanTheme(selectionWidth: 5, statusFillOpacity: 0.25);

  testWidgets(
      'G-5, H-8: an ambient switch (light with A to dark with another) calls '
      'the overlay builder 0 times', (tester) async {
    final c = controllerIn(PlanMode.service);
    final calls = [0];
    // One view widget throughout: the host never rebuilds it.
    final view = PlanEditor(
        controller: c, unitOverlayBuilder: counting(calls), theme: viewTheme);
    await pumpUnder(tester, view,
        theme: lightWith(fullA), dark: darkWith(other));
    c.camera.value = embeddingCamera();
    await tester.pump();
    expect(calls[0], 7, reason: 'the fixture\'s seven overlaid tables');
    expect(resolvedIn(tester, PlanMode.service), fullA.merge(viewTheme));
    await pumpUnder(tester, view,
        theme: lightWith(fullA), dark: darkWith(other), mode: ThemeMode.dark);
    expect(resolvedIn(tester, PlanMode.service), other.merge(viewTheme));
    expect(calls[0], 7, reason: 'an ambient switch builds no overlay');
  });

  testWidgets(
      'G-5, H-8: a scope-only change (the host\'s Theme around an unchanged '
      'view) calls the overlay builder 0 times; a host rebuild of the view '
      'calls it for every table', (tester) async {
    final c = controllerIn(PlanMode.service);
    final calls = [0];
    final local = ValueNotifier<ThemeData>(lightWith(fullA));
    addTearDown(local.dispose);
    Widget hostOf(PlanEditor view) => ValueListenableBuilder<ThemeData>(
        valueListenable: local,
        builder: (context, data, child) => Theme(data: data, child: child!),
        child: view);
    final view = PlanEditor(
        controller: c, unitOverlayBuilder: counting(calls), theme: viewTheme);
    await pumpUnder(tester, hostOf(view));
    c.camera.value = embeddingCamera();
    await tester.pump();
    expect(calls[0], 7);
    expect(resolvedIn(tester, PlanMode.service), fullA.merge(viewTheme));
    local.value = darkWith(other);
    await tester.pump();
    expect(resolvedIn(tester, PlanMode.service), other.merge(viewTheme));
    expect(calls[0], 7, reason: 'a scope-only change builds no overlay');

    // The counter counts: a host rebuild of the view builds every overlay
    // again (G-5).
    await pumpUnder(
        tester,
        hostOf(PlanEditor(
            controller: c,
            unitOverlayBuilder: counting(calls),
            theme: viewTheme)));
    expect(calls[0], 14);
  });

  testWidgets(
      'R-1: an AnimatedTheme with Curves.easeOutBack between two valid '
      'themes, both ways: no exception on any frame, every value within its '
      'ends', (tester) async {
    final c = controllerIn(PlanMode.service);
    final view = PlanEditor(controller: c);
    Widget hostOf(ThemeData data) => AnimatedTheme(
        data: data,
        curve: Curves.easeOutBack,
        duration: const Duration(milliseconds: 200),
        child: view);
    await pumpUnder(tester, hostOf(lightWith(edgeA)));
    expect(resolvedIn(tester, PlanMode.service), edgeA);
    for (final (from, to, data) in [
      (edgeA, edgeB, darkWith(edgeB)),
      (edgeB, edgeA, lightWith(edgeA)),
    ]) {
      await pumpUnder(tester, hostOf(data));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final reason = '${from == edgeA ? 'A to B' : 'B to A'}, frame $i';
        expect(tester.takeException(), isNull, reason: reason);
        expectWithinEnds(
            resolvedIn(tester, PlanMode.service)!, from, to, reason);
      }
      expect(resolvedIn(tester, PlanMode.service), to);
    }
  });

  testWidgets(
      'R-2: an animated switch between ThemeData carrying equal themes '
      'notifies no dependent; one carrying different themes does',
      (tester) async {
    final c = controllerIn(PlanMode.service);
    final log = <PlanTheme?>[];
    Widget? reader(BuildContext context, PlanUnitOverlay table) =>
        table.detail.unit.label == '1' ? ThemeReader(log: log) : null;
    final view = PlanEditor(controller: c, unitOverlayBuilder: reader);
    Widget hostOf(ThemeData data) => AnimatedTheme(
        data: data, duration: const Duration(milliseconds: 200), child: view);
    await pumpUnder(tester, hostOf(lightWith(fullA)));
    c.camera.value = embeddingCamera();
    await tester.pump();
    expect(find.byType(ThemeReader), findsOneWidget);
    expect(log, [fullA]);

    await pumpUnder(tester, hostOf(darkWith(fullA.copyWith())));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(Theme.of(tester.element(find.byType(PlanCanvasView))).brightness,
        Brightness.dark,
        reason: 'the switch ran');
    expect(log, [fullA], reason: 'an equal theme notifies nobody');

    // The reader counts: a different theme notifies it.
    await pumpUnder(tester, hostOf(lightWith(fullB)));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(log.length, greaterThan(1));
    expect(log.last, fullB);
  });
}
