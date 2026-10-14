// Spec 2a P2, "The widgets": PlanCanvas alone, with only a controller. It
// fits the plan on its first frame (today's PlannerView), shows a
// controller in one canvas at a time, follows the controller's document
// swap, carries the rulers, grid and snapping options, pushes the app's
// locale into the controller (spec P5) and shows the lock hint (spec P4).
// The palette fixture: a 1:20 page off the origin, two ACI 7 lines.
//
// CV-8 and CV-9 are the carried items of Tasks 9 and 11: a locale report
// that lands after its controller was disposed, and a grip drag in flight
// whose type fails before the release.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:jet_cad_2d_plan/src/controller/camera_bounds.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_fixture.dart';
import '../support/harness.dart';
import '../support/test_kit.dart' show addObject;
import '../support/throwing_kit.dart';

/// The six numbers of [v]'s world-to-screen matrix.
List<double> m(ViewportTransform v) {
  final t = v.worldToScreenMatrix;
  return [t.a, t.b, t.c, t.d, t.e, t.f];
}

Future<void> pumpAlone(WidgetTester tester, Widget body) async {
  windowAt(tester, const Size(1200, 700));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  await tester.pump();
}

/// [c]'s page fitted to the drawing area, clamped as every fit is.
List<double> pageFit(WidgetTester tester, PlanController c) {
  final size = tester.getSize(find.byType(InteractionLayer));
  final page = c.document.components.get<PageComponent>(c.document.rootHandle)!;
  return m(clampCameraScale(fitToPage(page, size), size,
      minScale: c.camera.minScale, maxScale: c.camera.maxScale));
}

void main() {
  testWidgets(
      'CV-1 the plan is fitted to the drawing area on the first frame, '
      'inside the zoom bounds (M-CV-1)', (tester) async {
    final c = paletteController(paper: white).c;
    final before = m(c.camera.value);
    await pumpAlone(tester, PlanCanvas(controller: c));
    final want = pageFit(tester, c);
    expect(want, isNot(before),
        reason: 'premise: the controller\'s nominal camera is not the fit');
    expect(m(c.camera.value), want);
  });

  testWidgets(
      'CV-2 one controller in two canvases asserts after the frame; two '
      'controllers, one canvas, and a canvas moved to another parent do not '
      '(M-CV-2a, M-CV-2b)', (tester) async {
    final c = paletteController(paper: white).c;
    final d = paletteController(paper: blueprint).c;
    windowAt(tester, const Size(1200, 700));
    Widget row(List<PlanController> cs) => MaterialApp(
            home: Row(children: [
          for (final x in cs) Expanded(child: PlanCanvas(controller: x)),
        ]));
    await tester.pumpWidget(row([c, d]));
    expect(tester.takeException(), isNull, reason: 'two controllers');
    await tester.pumpWidget(row([c]));
    expect(tester.takeException(), isNull, reason: 'one canvas');
    // A Column in place of the Row: a new canvas for c, the old one
    // disposed in the same frame.
    await tester.pumpWidget(MaterialApp(
        home: Column(children: [Expanded(child: PlanCanvas(controller: c))])));
    expect(tester.takeException(), isNull,
        reason: 'a canvas that replaces another is not a second one');
    await tester.pumpWidget(row([c, c]));
    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('one PlanCanvas at a time'));
  });

  testWidgets(
      'CV-3 load: the canvas draws the controller\'s new document and fits '
      'its page (M-CV-3)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c));
    final first = c.document;
    c.load(paletteText(paper: blueprint, originX: -5000, originY: 8000).json);
    await tester.pump();
    await tester.pump();
    expect(identical(c.document, first), isFalse,
        reason: 'premise: load made a new document');
    final canvas = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    expect(identical(canvas.widget.document, c.document), isTrue);
    expect(m(c.camera.value), pageFit(tester, c),
        reason: 'the new plan is fitted on its first frame');
    expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).paper,
        PaperPalette.dark,
        reason: 'the paper set is the new page\'s (Blueprint)');
  });

  testWidgets(
      'CV-4 the lock hint shows while controller.lockHint is set and clears '
      'after kLockHintDuration (M-CV-4a, M-CV-4b)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c));
    final hint = find.byKey(const Key('plan-lock-hint'));
    expect(hint, findsNothing);
    c.lockHint.value = true;
    await tester.pump();
    expect(hint, findsOneWidget);
    expect(
        find.descendant(of: hint, matching: find.text('This object is locked')),
        findsOneWidget);
    await tester.pump(kLockHintDuration);
    await tester.pump();
    expect(c.lockHint.value, isFalse);
    expect(hint, findsNothing);
  });

  testWidgets(
      'CV-5 rulers: false and grid: false: no ruler frame and a page chrome '
      'without the grid; the defaults draw both (M-CV-5)', (tester) async {
    final c = paletteController(paper: white).c;
    PageChromePainter chrome() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<PageChromePainter>()
        .single;
    await pumpAlone(
        tester, PlanCanvas(controller: c, rulers: false, grid: false));
    expect(find.byType(RulerFrame), findsNothing);
    expect(chrome().grid, isFalse);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    expect(chrome().grid, isTrue);
  });

  testWidgets(
      'CV-6 snapping: false turns object snap off for the tools and keeps '
      'the user\'s F3 setting; snapping: true turns it back (M-CV-6a, '
      'M-CV-6b)', (tester) async {
    final c = paletteController(paper: white).c;
    await pumpAlone(tester, PlanCanvas(controller: c, snapping: false));
    expect(c.snap.objectSnap, isTrue, reason: 'the user\'s setting');
    expect(c.toolController.context.snap!.objectSnap, isFalse,
        reason: 'what the tools read');
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    expect(c.toolController.context.snap!.objectSnap, isTrue);
  });

  testWidgets(
      'CV-7 the canvas pushes the app\'s locale into controller.locale and '
      'follows a change of language (M-CV-7)', (tester) async {
    final c = paletteController(paper: white).c;
    Future<void> pumpIn(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('de'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: PlanCanvas(controller: c))));
      await tester.pump();
    }

    await pumpIn(const Locale('tr'));
    expect(c.locale.value, const Locale('tr'));
    await pumpIn(const Locale('de'));
    expect(c.locale.value, const Locale('de'));
  });

  testWidgets(
      'CV-8 a locale report owed by a mounted canvas whose controller is '
      'disposed in the same frame reports nothing and throws nothing '
      '(M-CV-8)', (tester) async {
    // Disposed by the test itself, not at tear-down: a second dispose
    // asserts.
    final c =
        PlanController(kits: const [], json: paletteText(paper: white).json);
    Widget app(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('de'), Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: PlanCanvas(controller: c)));
    windowAt(tester, const Size(1200, 700));
    await tester.pumpWidget(app(const Locale('tr')));
    await tester.pump();
    expect(c.locale.value, const Locale('tr'), reason: 'premise: it reports');
    // The host lets the controller go at the end of the frame in which the
    // language changes: its callback is queued before the canvas's report,
    // which then finds a disposed controller under a mounted canvas.
    SchedulerBinding.instance.addPostFrameCallback((_) => c.dispose());
    await tester.pumpWidget(app(const Locale('de')));
    expect(tester.takeException(), isNull,
        reason: 'reportLocale on a disposed controller asserts');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CV-9 a grip drag in flight whose type fails before the release ends '
      'cleanly: no commit, no exception, plan.select idle, one diagnostic; '
      'the same drag on a healthy type commits (M-CV-9)', (tester) async {
    final boom = ThrowingKit();
    late Handle block;
    final json = planText([boom.kit], (d) {
      // Grid snap off, so the drop is where the pointer is.
      d.commands.execute(SetComponentCommand<PageComponent>(
          d.rootHandle,
          d.components
              .get<PageComponent>(d.rootHandle)!
              .copyWith(snapToGrid: false)));
      block = addObject<BlockComponent>(d, const BlockComponent(size: 400),
          at: Vector2(1300, -700));
    });
    final c = controllerFor(kits: [boom.kit], json: json);
    await pumpAlone(tester, PlanCanvas(controller: c));
    double size() => c.document.components.get<BlockComponent>(block)!.size;
    Vector2 grip() => Vector2(1300 + size() / 2, -700);
    Future<void> drag(double toX) async {
      c.selection.replace([SelectionKey.root(block)]);
      await tester.pump();
      final g = grip();
      final at = globalOf(tester, c, g.x, g.y);
      final gesture =
          await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await tester.pump();
      final to = globalOf(tester, c, toX, -700);
      for (var i = 1; i <= 4; i++) {
        await gesture.moveTo(Offset.lerp(at, to, i / 4)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    // The positive control: a healthy drag to 1300 + 450 sets 900.
    await drag(1750);
    expect(size(), closeTo(900, 1e-6), reason: 'premise: the drag commits');
    expect(c.canUndo.value, isTrue);
    final committed = size();
    c.document.commands.clearHistory();
    final depth = c.document.commands.undoDepth;
    final before = c.diagnostics.value.length;

    // The type's preview throws from the first move on: the guard refuses
    // the drag in flight, and the release's drag answers null.
    boom.failing.add('gripsPreview');
    await drag(2100);
    expect(tester.takeException(), isNull);
    expect(size(), committed, reason: 'nothing committed');
    expect(c.document.commands.undoDepth, depth);
    expect(c.planSelect.dragKind, isNull, reason: 'the drag ended');
    final added = c.diagnostics.value.sublist(before);
    expect(added.map((d) => (d.kitId, d.code)),
        [('boom', KitDiagnosticCode.hookFailed)]);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
