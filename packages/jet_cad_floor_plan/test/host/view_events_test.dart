// Host embedding API spec E-1 to E-4 through `FloorPlanView` (Slice 2 plan,
// Task 4): `onTablesMoved`, `onTableDoubleTap`, `onFloorTap` and
// `onTableHover` in the selection mode, on the shared non-degenerate fixture
// (embedding_fixture) under its panned 0.37 px/mm camera, or the same scale
// panned over the table a test needs. Screen points and expected world
// points and centres are computed here by the forward transform (the
// fixture's placements, `canvasOf`) and the camera's inverse written out,
// never read from the code under test. Double taps are driven by gestures
// with explicit stamps, the fake clock pumped differently from them:
// flutter_test stamps every synthetic event `Duration.zero` otherwise.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/host/table_detail.dart';

import 'embedding_fixture.dart';

/// What the host heard, in order.
final class Heard {
  final List<String> log = [];
  final List<List<FloorPlanTableDetail>> moved = [];
  final List<Offset> floors = [];
  final List<String?> hovers = [];

  /// Run inside `onFloorTap`, for a test that looks at the state then.
  void Function()? onFloor;
}

/// Mounts the host at 1440 x 900 in the selection mode, every callback
/// recorded, lets the first fit land, then puts [camera] (the fixture's by
/// default) in place.
Future<(FloorPlanController, Heard)> mount(WidgetTester tester,
    {ViewportTransform? camera}) async {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  c.setMode(FloorPlanMode.selection);
  final heard = Heard();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FloorPlanView(
        controller: c,
        onTableTap: (n) => heard.log.add('tap $n'),
        onLayoutChanged: () => heard.log.add('layout'),
        onTablesMoved: (m) {
          heard.moved.add(m);
          heard.log.add('moved ${[for (final d in m) d.table.number]}');
        },
        onTableDoubleTap: (n) => heard.log.add('double $n'),
        onFloorTap: (w) {
          heard.floors.add(w);
          heard.log.add('floor');
          heard.onFloor?.call();
        },
        onTableHover: heard.hovers.add,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = camera ?? embeddingCamera();
  await tester.pump();
  return (c, heard);
}

/// The fixture's scale, 0.37 px/mm, panned so [t]'s box centre sits at
/// (700, 400) in the canvas.
ViewportTransform cameraOver(EmbeddingTable t) {
  final (x, y) = centerOf(t);
  return ViewportTransform(
      worldToScreenMatrix:
          Transform2(0.37, 0, 0, -0.37, 700 - 0.37 * x, 400 + 0.37 * y));
}

EmbeddingTable table(String n) =>
    embeddingTables.firstWhere((t) => t.number == n);

/// [t]'s point local ([lx], [ly]) in the world, by the forward transform.
(double, double) worldOf(EmbeddingTable t, double lx, double ly) {
  final m = t.transform;
  return (m.a * lx + m.c * ly + m.e, m.b * lx + m.d * ly + m.f);
}

/// [t]'s box centre in the world: the box's own centre through the
/// placement.
(double, double) centerOf(EmbeddingTable t) => worldOf(
    t,
    (embeddingBox.minX + embeddingBox.maxX) / 2,
    (embeddingBox.minY + embeddingBox.maxY) / 2);

Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World ([x], [y]) on the screen, by the forward transform.
Offset screenOf(
    WidgetTester tester, FloorPlanController c, double x, double y) {
  final p = canvasOf(c.cameraController.value, x, y);
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

/// [t]'s point local ([lx], [ly]) (its box centre by default) on the screen.
Offset onTable(WidgetTester tester, FloorPlanController c, EmbeddingTable t,
    [double lx = 700, double ly = 100]) {
  final (x, y) = worldOf(t, lx, ly);
  return screenOf(tester, c, x, y);
}

Duration ms(int n) => Duration(milliseconds: n);

/// A mouse click whose down is stamped [down] (the up 40 ms later).
Future<void> click(WidgetTester tester, Offset at, Duration down) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(at, timeStamp: down);
  await g.up(timeStamp: down + ms(40));
  await g.removePointer();
}

/// A mouse drag from [from] by [by], in three moves, stamped from [down].
Future<void> drag(
    WidgetTester tester, Offset from, Offset by, Duration down) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.down(from, timeStamp: down);
  for (var i = 1; i <= 3; i++) {
    await g.moveTo(from + by * (i / 3), timeStamp: down + ms(20 * i));
  }
  await g.up(timeStamp: down + ms(100));
  await g.removePointer();
}

/// The floor between `1` and `2`, in view under [embeddingCamera]: on no
/// table's box (`1` reaches x 41,053, `2` starts at 42,800).
const double kFloorX = 41900, kFloorY = -26500;

void expectWorld(double got, double want, String reason) =>
    expect(got, closeTo(want, want.abs() * 1e-12), reason: reason);

void main() {
  group('double tap (E-2)', () {
    testWidgets(
        'VE1 both taps report onTableTap, then onTableDoubleTap fires: no '
        'delay', (tester) async {
      final (c, heard) = await mount(tester);
      final p = onTable(tester, c, table('1'));
      await click(tester, p, ms(5000));
      expect(heard.log, ['tap 1'], reason: 'the first tap is not delayed');
      expect(c.selectedTables.value, {'1'}, reason: 'and selects');
      await tester.pump(ms(70));
      await click(tester, p + const Offset(4, -3), ms(5150));
      expect(heard.log, ['tap 1', 'tap 1', 'double 1']);
    });

    testWidgets('VE2 two instances sharing a number: no double tap (M-H20)',
        (tester) async {
      // 0.025 px/mm, panned over the two 7s.
      final (c, heard) = await mount(tester,
          camera: ViewportTransform(
              worldToScreenMatrix:
                  Transform2(0.025, 0, 0, -0.025, -425, -375)));
      final a = onTable(tester, c, embeddingTables[6]);
      final b = onTable(tester, c, embeddingTables[7]);
      expect(embeddingTables[6].number, '7');
      expect(embeddingTables[7].number, '7');
      expect((b - a).distance, lessThan(100), reason: 'premise: in the slop');
      for (final p in [a, b]) {
        expect(c.tableAt(p - canvasOrigin(tester)), '7', reason: 'premise');
      }
      await click(tester, a, ms(1000));
      await click(tester, b, ms(1100));
      expect(heard.log, ['tap 7', 'tap 7']);
    });

    testWidgets(
        'VE3 timed from the downs\' stamps: + 301 ms none, + 299 ms one, '
        'whatever the clock (M-H20b)', (tester) async {
      final (c, heard) = await mount(tester);
      final p = onTable(tester, c, table('1'));
      await click(tester, p, ms(1000));
      await click(tester, p, ms(1301));
      expect(heard.log, ['tap 1', 'tap 1'], reason: '+ 301 ms, clock + 0');
      heard.log.clear();
      await click(tester, p, ms(5000));
      await tester.pump(const Duration(seconds: 1));
      await click(tester, p, ms(5299));
      expect(heard.log, ['tap 1', 'tap 1', 'double 1'],
          reason: '+ 299 ms, clock + 1 s');
    });

    testWidgets(
        'VE4 measured between the downs on the screen: 101 px none, 99 px '
        'one (M-H20c)', (tester) async {
      // Table 4 turned 180 degrees: its box is 800 x 600 mm, 296 x 222 px.
      final four = table('4');
      final (c, heard) = await mount(tester, camera: cameraOver(four));
      final corners = [
        for (final (x, y) in [(300.0, -200.0), (1100.0, 400.0)])
          onTable(tester, c, four, x, y)
      ];
      expect((corners[0].dx - corners[1].dx).abs(), closeTo(296, 1e-9));
      expect((corners[0].dy - corners[1].dy).abs(), closeTo(222, 1e-9));
      final a = onTable(tester, c, four, 450, 100);
      for (final d in [101.0, 99.0]) {
        expect(c.tableAt(a - Offset(d, 0) - canvasOrigin(tester)), '4',
            reason: 'premise: on 4');
      }
      await click(tester, a, ms(1000));
      await click(tester, a - const Offset(101, 0), ms(1100));
      expect(heard.log, ['tap 4', 'tap 4'], reason: '101 px');
      heard.log.clear();
      await click(tester, a, ms(3000));
      await click(tester, a - const Offset(99, 0), ms(3100));
      expect(heard.log, ['tap 4', 'tap 4', 'double 4'], reason: '99 px');
    });

    testWidgets(
        'VE5 a locked table reports a double tap; Shift on either tap '
        'prevents it', (tester) async {
      final (c, heard) = await mount(tester, camera: cameraOver(table('L')));
      final l = onTable(tester, c, table('L'));
      await click(tester, l, ms(1000));
      await click(tester, l, ms(1100));
      expect(heard.log, ['tap L', 'tap L', 'double L']);
      expect(c.selectedTables.value, isEmpty, reason: 'locked: no selection');

      final one = table('1');
      c.cameraController.value = cameraOver(one);
      await tester.pump();
      final p = onTable(tester, c, one);
      for (final shiftFirst in [true, false]) {
        heard.log.clear();
        if (shiftFirst) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await click(tester, p, ms(shiftFirst ? 2000 : 4000));
        if (shiftFirst) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        } else {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        }
        await click(tester, p, ms(shiftFirst ? 2100 : 4100));
        if (!shiftFirst) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }
        expect(heard.log, ['tap 1', 'tap 1'],
            reason: 'Shift on the ${shiftFirst ? 'first' : 'second'} tap');
      }
    });
  });

  testWidgets(
      'VE13 a finger\'s double tap is timed from the raw downs: the first '
      'held past kTouchHoldBack, the second lifted before it', (tester) async {
    final (c, heard) = await mount(tester);
    final p = onTable(tester, c, table('1'));
    final first = await tester.createGesture(pointer: 11);
    await first.down(p, timeStamp: ms(1000));
    await tester.pump(kTouchHoldBack + ms(50));
    await first.up(timeStamp: ms(1160));
    await tester.pump(ms(20));
    final second = await tester.createGesture(pointer: 12);
    await second.down(p + const Offset(6, 4), timeStamp: ms(1290));
    await second.up(timeStamp: ms(1330));
    await tester.pump(ms(500));
    expect(heard.log, ['tap 1', 'tap 1', 'double 1']);
    expect(heard.hovers, isEmpty);
  });

  group('floor tap (E-3)', () {
    testWidgets(
        'VE6 a miss reports the down\'s world point, the selection already '
        'cleared; with Shift it reports and keeps the selection (S-4)',
        (tester) async {
      final (c, heard) = await mount(tester);
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'}, reason: 'premise');
      bool? emptyThen;
      heard.onFloor = () => emptyThen = c.activeSelection.isEmpty;
      final at = screenOf(tester, c, kFloorX, kFloorY);
      expect(c.tableAt(at - canvasOrigin(tester)), isNull, reason: 'premise');
      await click(tester, at, ms(1000));
      expect(heard.log, ['floor']);
      // The camera's inverse written out: x = (sx - e) / a, y = (sy - f) / d.
      final m = c.cameraController.value.worldToScreenMatrix;
      final local = at - canvasOrigin(tester);
      expectWorld(heard.floors.single.dx, (local.dx - m.e) / m.a, 'x');
      expectWorld(heard.floors.single.dy, (local.dy - m.f) / m.d, 'y');
      expectWorld(heard.floors.single.dx, kFloorX, 'x, mm');
      expectWorld(heard.floors.single.dy, kFloorY, 'y, mm, up');
      expect(emptyThen, isTrue);

      c.select({'1'});
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await click(tester, at, ms(2000));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(heard.floors, hasLength(2));
      expect(c.activeSelection.isEmpty, isFalse, reason: 'kept');
    });

    testWidgets(
        'VE7 a tap on the unnumbered table reports neither a tap nor the '
        'floor', (tester) async {
      final unnumbered = embeddingTables[8];
      final (c, heard) = await mount(tester, camera: cameraOver(unnumbered));
      final p = onTable(tester, c, unnumbered);
      await click(tester, p, ms(1000));
      await click(tester, p, ms(1100));
      expect(heard.log, isEmpty);
      expect(c.activeSelection.keys, hasLength(1), reason: 'premise: hit');
    });
  });

  group('moved (E-1)', () {
    testWidgets(
        'VE8 a drag reports the moved table once, after onLayoutChanged, '
        'with its new geometry; Undo, Redo, reset and restore never call it '
        '(M-H21)', (tester) async {
      final (c, heard) = await mount(tester);
      var layoutChanges = 0;
      void count() => layoutChanges++;
      c.serviceLayoutChanges.addListener(count);
      addTearDown(() => c.serviceLayoutChanges.removeListener(count));
      final one = table('1');
      const by = Offset(60, 30);
      await drag(tester, onTable(tester, c, one), by, ms(1000));
      await tester.pump();
      expect(heard.log, ['layout', 'moved [1]']);
      final moved = heard.moved.single.single;
      expect(moved, c.tableDetails.firstWhere((d) => d.table.number == '1'),
          reason: 'the controller\'s fresh detail');
      final (x, y) = centerOf(one);
      expectWorld(moved.center!.dx, x + by.dx / 0.37, 'centre x');
      expectWorld(moved.center!.dy, y - by.dy / 0.37, 'centre y');
      expect(layoutChanges, 1);
      final json = c.serviceLayoutJson()!;

      await tester.tap(find.byKey(const Key('service-undo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('service-redo')));
      await tester.pump();
      c.resetLayout();
      await tester.pump();
      c.restoreServiceLayout(json);
      await tester.pump();
      expect(layoutChanges, 5, reason: 'premise: each one fired');
      expect(heard.moved, hasLength(1));
      expect(heard.log, ['layout', 'moved [1]']);
    });

    testWidgets(
        'VE9 two moved tables sharing a number are both reported, ascending, '
        'each moved by the drag\'s world delta (M-H21b); an unnumbered one '
        'is reported too', (tester) async {
      final a = embeddingTables[6], b = embeddingTables[7];
      final (c, heard) = await mount(tester, camera: cameraOver(a));
      c.select({'7'});
      await tester.pump();
      expect(c.activeSelection.keys, hasLength(2), reason: 'both 7s');
      const by = Offset(-45, 52);
      await drag(tester, onTable(tester, c, a), by, ms(1000));
      final moved = heard.moved.single;
      expect([for (final d in moved) d.table.number], ['7', '7']);
      expect([for (final d in moved) d.mirrored], [false, true],
          reason: 'ascending: the 60 degree one placed first');
      for (final (d, t) in [(moved[0], a), (moved[1], b)]) {
        final (x, y) = centerOf(t);
        expectWorld(d.center!.dx, x + by.dx / 0.37, '${t.label} x');
        expectWorld(d.center!.dy, y - by.dy / 0.37, '${t.label} y');
      }

      final unnumbered = embeddingTables[8];
      c.cameraController.value = cameraOver(unnumbered);
      await tester.pump();
      await drag(tester, onTable(tester, c, unnumbered), const Offset(30, 0),
          ms(3000));
      expect(heard.moved, hasLength(2));
      expect(heard.moved.last.single.table.number, isNull);
    });
  });

  group('hover (E-4)', () {
    testWidgets(
        'VE10 a mouse reports on change only; leaving the canvas reports '
        'null (M-H29 hover per move)', (tester) async {
      final (c, heard) = await mount(tester);
      final one = table('1');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: screenOf(tester, c, kFloorX, kFloorY));
      await mouse.moveTo(onTable(tester, c, one, 600, 0));
      await mouse.moveTo(onTable(tester, c, one));
      await mouse.moveTo(onTable(tester, c, one, 800, 50));
      expect(heard.hovers, ['1']);
      await mouse.moveTo(screenOf(tester, c, kFloorX, kFloorY));
      expect(heard.hovers, ['1', null]);
      await mouse.moveTo(onTable(tester, c, one));
      await mouse.moveTo(onTable(tester, c, one, 650, 120));
      expect(heard.hovers, ['1', null, '1']);
      // Onto the service bar, off the canvas.
      await mouse
          .moveTo(tester.getCenter(find.byKey(const Key('service-bar'))));
      expect(heard.hovers, ['1', null, '1', null]);
      expect(heard.log, isEmpty, reason: 'a hover is no tap');
    });

    testWidgets('VE11 a remount sends no null (S-5): a mode switch and a reset',
        (tester) async {
      final (c, heard) = await mount(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: screenOf(tester, c, kFloorX, kFloorY));
      await mouse.moveTo(onTable(tester, c, table('1')));
      expect(heard.hovers, ['1']);
      c.resetLayout();
      await tester.pump();
      expect(heard.hovers, ['1'], reason: 'reset');
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(heard.hovers, ['1'], reason: 'mode switch');
    });

    testWidgets(
        'VE12 a finger reports no hover (M-H29 hover for touch); a stylus '
        'does', (tester) async {
      final (c, heard) = await mount(tester);
      final p = onTable(tester, c, table('1'));
      await tester.tapAt(p, kind: PointerDeviceKind.touch);
      await tester.pump(ms(500));
      expect(heard.log, ['tap 1'], reason: 'premise: the tap landed');
      expect(heard.hovers, isEmpty);
      final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
      addTearDown(pen.removePointer);
      await pen.addPointer(location: screenOf(tester, c, kFloorX, kFloorY));
      await pen.moveTo(onTable(tester, c, table('2')));
      expect(heard.hovers, ['2']);
    });

    testWidgets(
        'VE16 a hover 3 px outside a table\'s box reports nothing: picked '
        'at the point, without a mouse\'s 6 px reach', (tester) async {
      final (c, heard) = await mount(tester);
      final one = table('1');
      // Table 1 is turned, not scaled: 3 px are 3 / 0.37 mm in its own
      // units, beyond or within its box's right edge.
      const d = 3 / 0.37;
      final outside = onTable(tester, c, one, embeddingBox.maxX + d, 100);
      final inside = onTable(tester, c, one, embeddingBox.maxX - d, 100);
      expect(c.tableAt(inside - canvasOrigin(tester)), '1', reason: 'premise');
      expect(c.tableAt(outside - canvasOrigin(tester)), isNull,
          reason: 'premise');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: screenOf(tester, c, kFloorX, kFloorY));
      await mouse.moveTo(outside);
      expect(heard.hovers, isEmpty, reason: '3 px outside');
      await mouse.moveTo(inside);
      expect(heard.hovers, ['1'], reason: '3 px inside');
      await mouse.moveTo(outside);
      expect(heard.hovers, ['1', null], reason: 'out again');
    });
  });

  group('read at each call, a replaced copy, the list (Task 4 review)', () {
    testWidgets(
        'VE14 the four events are read at each call (R-5): rebuilt with '
        'host B\'s callbacks after host A\'s were read, a double tap, a '
        'hover, a drag and a floor tap are heard by B alone', (tester) async {
      final c = FloorPlanController(json: embeddingPlanJson());
      addTearDown(c.dispose);
      c.setMode(FloorPlanMode.selection);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final log = <String>[];
      Widget host(String tag) => MaterialApp(
            home: Scaffold(
              body: FloorPlanView(
                controller: c,
                onTablesMoved: (m) => log
                    .add('$tag moved ${[for (final d in m) d.table.number]}'),
                onTableDoubleTap: (n) => log.add('$tag double $n'),
                onFloorTap: (_) => log.add('$tag floor'),
                onTableHover: (n) => log.add('$tag hover $n'),
              ),
            ),
          );
      await tester.pumpWidget(host('A'));
      await tester.pump();
      await tester.pump();
      c.cameraController.value = embeddingCamera();
      await tester.pump();
      final one = onTable(tester, c, table('1'));
      final floor = screenOf(tester, c, kFloorX, kFloorY);
      // A's events are read, through both views' records: a hover, then
      // the first tap of a double tap.
      final a = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await a.addPointer(location: floor);
      await a.moveTo(one);
      await a.removePointer();
      await click(tester, one, ms(1000));
      expect(log, ['A hover 1', 'A hover null'], reason: 'premise: A read');

      await tester.pumpWidget(host('B'));
      await click(tester, one, ms(1100));
      final b = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await b.addPointer(location: floor);
      await b.moveTo(one);
      await b.removePointer();
      await drag(tester, one, const Offset(60, 30), ms(3000));
      await click(tester, floor, ms(5000));
      expect(log, [
        'A hover 1',
        'A hover null',
        'B double 1',
        'B hover 1',
        'B hover null',
        'B moved [1]',
        'B floor',
      ]);
    });

    testWidgets(
        'VE15 an onLayoutChanged that resets the layout: that drag reports '
        'no onTablesMoved, and nothing throws (the tables it moved are '
        'gone)', (tester) async {
      final c = FloorPlanController(json: embeddingPlanJson());
      addTearDown(c.dispose);
      c.setMode(FloorPlanMode.selection);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final log = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FloorPlanView(
            controller: c,
            onLayoutChanged: () {
              log.add('layout');
              c.resetLayout();
            },
            onTablesMoved: (m) => log.add('moved ${m.length}'),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      c.cameraController.value = embeddingCamera();
      await tester.pump();
      final one = table('1');
      await drag(
          tester, onTable(tester, c, one), const Offset(60, 30), ms(1000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(log, ['layout']);
      final (x, y) = centerOf(one);
      final now = c.tableDetails.firstWhere((d) => d.table.number == '1');
      expectWorld(now.center!.dx, x, 'premise: reset, x');
      expectWorld(now.center!.dy, y, 'premise: reset, y');
    });

    testWidgets('VE17 the moved list a host is handed is unmodifiable',
        (tester) async {
      final (c, heard) = await mount(tester);
      await drag(tester, onTable(tester, c, table('1')), const Offset(60, 30),
          ms(1000));
      final moved = heard.moved.single;
      expect(moved, hasLength(1), reason: 'premise');
      expect(() => moved.add(moved.first), throwsUnsupportedError);
      expect(moved.removeLast, throwsUnsupportedError);
      expect(heard.moved.single, hasLength(1));
    });
  });
}
