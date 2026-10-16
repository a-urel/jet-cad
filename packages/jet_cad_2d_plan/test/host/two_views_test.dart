// Sub-project 4a R2 H3: two views of one controller. A PlanServiceView
// (unlike PlanCanvas, which asserts in debug) may be shown twice over one
// controller. The canvas placed last drives `canvasRect` and with it the
// camera's zoom focus; the other draws the same plan. A canvas is placed
// when it first reports and again whenever it moves or resizes. Unmounting
// the one that drives hands the role to the one placed before it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/service_host.dart';

const Key firstKey = Key('first-view');
const Key secondKey = Key('second-view');

Widget views(PlanController c,
        {bool first = true, bool second = true, double firstWidth = 500}) =>
    MaterialApp(
        home: Scaffold(
            body: Stack(children: [
      if (first)
        Positioned(
            left: 0,
            top: 0,
            width: firstWidth,
            height: 600,
            child: KeyedSubtree(
                key: firstKey,
                child: PlanServiceView(controller: c, autofocus: false))),
      if (second)
        Positioned(
            left: 500,
            top: 100,
            width: 300,
            height: 400,
            child: KeyedSubtree(
                key: secondKey,
                child: PlanServiceView(controller: c, autofocus: false))),
    ])));

/// The drawing area of the view keyed [k], in global pixels.
Rect canvasOf(WidgetTester tester, Key k) => tester.getRect(find.descendant(
    of: find.byKey(k), matching: find.byType(InteractionLayer)));

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
      'H3 the canvas placed last drives canvasRect and the zoom focus; '
      'placing the other again hands it over; unmounted, the one before '
      'takes over', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = serviceController()..setMode(PlanMode.service);

    await tester.pumpWidget(views(c, second: false));
    await frames(tester);
    final first = canvasOf(tester, firstKey);
    expect(c.canvasRect.value, first, reason: 'premise: one view');

    // A second view, mounted after the first has been placed.
    await tester.pumpWidget(views(c));
    await frames(tester);
    final second = canvasOf(tester, secondKey);
    expect(second.size, isNot(first.size), reason: 'premise');
    expect(second.topLeft, isNot(first.topLeft), reason: 'premise');
    expect(c.canvasRect.value, second, reason: 'the last placed drives');

    // The zoom focus is the driving canvas's centre.
    final focus = second.size.center(Offset.zero);
    final before = c.camera.value;
    final world = before.screenToWorld(Vector2(focus.dx, focus.dy));
    expect(c.zoomBy(2), isTrue);
    expect(c.camera.value.scale, closeTo(before.scale * 2, 1e-9));
    final at = c.camera.value.worldToScreen(world);
    expect(at.x, closeTo(focus.dx, 1e-6));
    expect(at.y, closeTo(focus.dy, 1e-6));

    // The first is placed again (resized): now it is the last placed.
    await tester.pumpWidget(views(c, firstWidth: 420));
    await frames(tester);
    final moved = canvasOf(tester, firstKey);
    expect(moved.width, 420, reason: 'premise');
    expect(c.canvasRect.value, moved, reason: 're-placed, so it drives');

    // The one that drives goes: the other takes over, after a frame.
    await tester.pumpWidget(views(c, first: false));
    await frames(tester);
    expect(find.byKey(firstKey), findsNothing);
    expect(c.canvasRect.value, canvasOf(tester, secondKey));

    await tester.pumpWidget(views(c, first: false, second: false));
    await frames(tester);
    expect(c.canvasRect.value, isNull, reason: 'no canvas, none drives');
  });

  testWidgets(
      'H3 three views: the driver is the most recent reporter, also after '
      'an unmount (not the first, not the first mounted)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = serviceController()..setMode(PlanMode.service);
    const keys = {'a': Key('view-a'), 'b': Key('view-b'), 'c': Key('view-c')};
    const lefts = {'a': 0.0, 'b': 450.0, 'c': 900.0};

    Widget three(Set<String> shown, Map<String, double> widths) => MaterialApp(
            home: Scaffold(
                body: Stack(children: [
          for (final n in ['a', 'b', 'c'])
            if (shown.contains(n))
              Positioned(
                  key: ValueKey(n),
                  left: lefts[n],
                  top: 0,
                  width: widths[n] ?? 300,
                  height: 400,
                  child: KeyedSubtree(
                      key: keys[n],
                      child: PlanServiceView(controller: c, autofocus: false)))
        ])));

    final widths = <String, double>{};
    final shown = <String>{};
    Future<void> show() async {
      await tester.pumpWidget(three({...shown}, {...widths}));
      await frames(tester);
    }

    Rect canvas(String n) => canvasOf(tester, keys[n]!);

    for (final n in ['a', 'b', 'c']) {
      shown.add(n);
      await show();
    }
    expect(c.canvasRect.value, canvas('c'), reason: 'C placed last');

    widths['a'] = 280;
    await show();
    expect(c.canvasRect.value, canvas('a'), reason: 'A reported again');
    widths['b'] = 320;
    await show();
    expect(c.canvasRect.value, canvas('b'), reason: 'B reported again');

    // Order of reports: C, A, B. B goes: A, the latest remaining reporter.
    shown.remove('b');
    await show();
    expect(c.canvasRect.value, canvas('a'), reason: 'not C, not the first');

    shown.remove('a');
    await show();
    expect(c.canvasRect.value, canvas('c'));
  });
}
