// Host embedding API spec E-1 to E-4 at the selection mode's tool, with
// explicit `ToolPointerEvent`s (Slice 2 plan, Task 4): the moved instances
// a drag reports, the double tap timed and measured from the raw downs'
// stamps and screen points, the floor tap's world point, the hover. On the
// shared non-degenerate fixture (embedding_fixture) decoded as a service
// copy, under its panned 0.37 px/mm camera. Screen points are computed here
// by the forward transform of the fixture's placements; expected world
// points by the camera's inverse written out, never read from the code.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart'
    show
        PointerDeviceKind,
        kDoubleTapSlop,
        kDoubleTapTimeout,
        kLongPressTimeout,
        kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart'
    show TableGroup;
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/service/table_select_tool.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../host/embedding_fixture.dart';
import 'table_status_painter_test.dart' show rowOfTables;

/// A picker that counts its picks.
class CountingPicker extends TablePicker {
  CountingPicker(super.document);

  int picks = 0;

  @override
  PickCandidate? pick(Vector2 world, {double reach = 0}) {
    picks++;
    return super.pick(world, reach: reach);
  }
}

/// What a test counts.
final class Tally {
  int count = 0;
}

/// A candidate's inverse that counts every new object it is asked for:
/// a point or a direction mapped, a product, an inverse, a list, a string
/// (Task 4 review R-5). The coefficients are read as fields, which build
/// nothing.
final class CountingTransform extends Transform2 {
  CountingTransform(Transform2 m, this.made)
      : super(m.a, m.b, m.c, m.d, m.e, m.f);

  /// Shared by every inverse of a picker (a transform is immutable).
  final Tally made;

  @override
  Vector2 transformPoint(Vector2 p) {
    made.count++;
    return super.transformPoint(p);
  }

  @override
  Vector2 transformDirection(Vector2 v) {
    made.count++;
    return super.transformDirection(v);
  }

  @override
  Transform2 multiply(Transform2 other) {
    made.count++;
    return super.multiply(other);
  }

  @override
  Transform2 invert() {
    made.count++;
    return super.invert();
  }

  @override
  List<double> toJson() {
    made.count++;
    return super.toJson();
  }

  @override
  String toString() {
    made.count++;
    return super.toString();
  }
}

final class Rig {
  Rig() {
    doc = DraftDocumentCodec.decodeString(embeddingPlanJson(),
        permissions: DraftPermissions.runtime,
        registerComponents: registerAppComponents,
        diagnostics: <Diagnostic>[]);
    camera = CameraController(embeddingCamera());
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    picker = CountingPicker(doc);
    tool = TableSelectTool(
        picker: picker,
        groups: ValueNotifier(const {}),
        callbacks: () => (
              onTableTap: (n) => log.add('tap $n'),
              onLayoutChanged: () => log.add('layout'),
              onGroupTap: null,
              onMergeRequested: null,
              onSplitRequested: null,
            ),
        events: () => events);
    ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
  }

  late final DraftDocument doc;
  late final CameraController camera;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final CountingPicker picker;
  late final TableSelectTool tool;
  late final ToolContext ctx;

  /// What the host heard, in order.
  final List<String> log = [];
  final List<List<Handle>> moved = [];
  final List<Offset> floors = [];
  final List<String?> hovers = [];

  /// The events the tool reads at each call; every one logged.
  late ServiceEvents<Handle> events = (
    onTablesMoved: (m) {
      moved.add(m);
      log.add('moved ${m.length}');
    },
    onTableDoubleTap: (n) => log.add('double $n'),
    onFloorTap: (w) {
      floors.add(w);
      log.add('floor');
    },
    onTableHover: hovers.add,
  );

  void dispose() {
    tool.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    doc.dispose();
  }

  /// Instance of the [i]th table of [embeddingTables] (survey order).
  Handle instance(int i) => TableSurvey.of(doc).tables[i].instance;

  /// The screen point of local ([x], [y]) of [t], by the forward transform.
  Offset at(EmbeddingTable t, [double x = 700, double y = 100]) {
    final m = t.transform;
    final p = canvasOf(
        camera.value, m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
    return Offset(p.x, p.y);
  }

  ToolPointerEvent ev(Offset screen,
          {int buttons = kPrimaryButton,
          bool shift = false,
          PointerDeviceKind kind = PointerDeviceKind.mouse,
          Duration time = Duration.zero}) =>
      ToolPointerEvent(
        screen: screen,
        world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 6 / camera.value.scale,
        kind: kind,
        reachRadiusWorld:
            kind == PointerDeviceKind.touch ? 24 / camera.value.scale : null,
        timeStamp: time,
      );

  /// A tap whose down is stamped [down] (the up 40 ms later).
  void tap(Offset s, Duration down, {bool shift = false}) {
    tool.onPointerDown(ev(s, shift: shift, time: down), ctx);
    tool.onPointerUp(
        ev(s, buttons: 0, time: down + const Duration(milliseconds: 40)), ctx);
  }

  void hover(Offset s, {PointerDeviceKind kind = PointerDeviceKind.mouse}) =>
      tool.onPointerMove(ev(s, buttons: 0, kind: kind), ctx);

  void drag(Offset from, Offset to, Duration down) {
    tool.onPointerDown(ev(from, time: down), ctx);
    tool.onPointerMove(ev(Offset.lerp(from, to, 0.5)!, time: down), ctx);
    tool.onPointerMove(ev(to, time: down), ctx);
    tool.onPointerUp(ev(to, buttons: 0, time: down), ctx);
  }
}

Rig rig() {
  final r = Rig();
  addTearDown(r.dispose);
  return r;
}

EmbeddingTable table(String n) =>
    embeddingTables.firstWhere((t) => t.number == n);

Duration ms(int n) => Duration(milliseconds: n);

/// A floor point: inside the page, between `1` and `2`'s row and the next,
/// on no table's box.
const double kFloorX = 41500, kFloorY = -29300;

void main() {
  group('double tap (E-2)', () {
    testWidgets(
        'SE1 two taps on one table within the timeout and the slop: two taps, '
        'then the double tap; a third tap starts anew', (tester) async {
      final r = rig();
      final p = r.at(table('1'));
      r.tap(p, ms(5000));
      r.tap(p + const Offset(3, 2), ms(5200));
      expect(r.log, ['tap 1', 'tap 1', 'double 1']);
      r.tap(p, ms(5300));
      expect(r.log, ['tap 1', 'tap 1', 'double 1', 'tap 1'],
          reason: 'the chain reset: a third tap is a first');
      r.tap(p, ms(5400));
      expect(r.log.last, 'double 1', reason: 'the fourth completes anew');
    });

    testWidgets(
        'SE2 the bounds are inclusive and measured between the two downs '
        '(S-6): exactly kDoubleTapTimeout and exactly kDoubleTapSlop fire; '
        'one millisecond or a pixel more does not', (tester) async {
      expect(kDoubleTapTimeout, ms(300));
      expect(kDoubleTapSlop, 100);
      // Table 4 is turned 180 degrees: its local x is the screen's -x, and
      // its box is 800 mm = 296 px wide, so 100 px fit inside it.
      // Whole pixels, so the differences below are exact.
      final r = rig();
      final near = r.at(table('4'), 450, 100);
      final a = Offset(near.dx.roundToDouble(), near.dy.roundToDouble());
      final b = a + const Offset(-100, 0);
      final c = a + const Offset(-101, 0);
      expect((b - a).distance, 100, reason: 'premise');
      for (final p in [a, b, c]) {
        expect(r.picker.pick(r.ev(p).world)?.table.instance, r.instance(3),
            reason: 'premise: on 4');
      }
      r.tap(a, ms(1000));
      r.tap(a, ms(1300));
      expect(r.log, ['tap 4', 'tap 4', 'double 4'], reason: 'exactly 300');
      r.log.clear();
      r.tap(a, ms(2000));
      r.tap(a, ms(2301));
      expect(r.log, ['tap 4', 'tap 4'], reason: '301 ms');
      r.log.clear();
      // The second tap of 301 ms is kept: one 300 ms after it completes.
      r.tap(a, ms(2601));
      expect(r.log, ['tap 4', 'double 4']);
      r.log.clear();
      r.tap(a, ms(4000));
      r.tap(b, ms(4100));
      expect(r.log, ['tap 4', 'tap 4', 'double 4'], reason: 'exactly 100 px');
      r.log.clear();
      r.tap(a, ms(6000));
      r.tap(c, ms(6100));
      expect(r.log, ['tap 4', 'tap 4'], reason: '101 px');
    });

    testWidgets(
        'SE3 the time is the downs\' stamps: the ups\' and the clock\'s are '
        'not read', (tester) async {
      final r = rig();
      final p = r.at(table('2'));
      r.tool.onPointerDown(r.ev(p, time: ms(1000)), r.ctx);
      r.tool.onPointerUp(r.ev(p, buttons: 0, time: ms(1250)), r.ctx);
      await tester.pump(const Duration(seconds: 2));
      r.tool.onPointerDown(r.ev(p, time: ms(1290)), r.ctx);
      r.tool.onPointerUp(r.ev(p, buttons: 0, time: ms(9000)), r.ctx);
      expect(r.log, ['tap 2', 'tap 2', 'double 2']);
    });

    testWidgets(
        'SE4 a modifier on either tap prevents it; a modifier tap breaks the '
        'chain', (tester) async {
      final r = rig();
      final p = r.at(table('1'));
      r.tap(p, ms(1000), shift: true);
      r.tap(p, ms(1100));
      expect(r.log.where((l) => l.startsWith('double')), isEmpty,
          reason: 'Shift on the first');
      r.tap(p, ms(1200), shift: true);
      expect(r.log.where((l) => l.startsWith('double')), isEmpty,
          reason: 'Shift on the second');
      r.tap(p, ms(1300));
      expect(r.log.where((l) => l.startsWith('double')), isEmpty,
          reason: 'the Shift tap broke the chain: this is a first tap');
      r.tap(p, ms(1400));
      expect(r.log.last, 'double 1');
    });

    testWidgets(
        'SE5 another instance sharing the number, the unnumbered table, the '
        'floor, a drag and a long press each reset the chain; another '
        'instance\'s tap is kept', (tester) async {
      final r = rig();
      // At 0.025 px/mm the two 7s' centres are within the slop.
      r.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2(0.025, 0, 0, -0.025, -425, -375));
      final seven = r.at(table('7'));
      final sevenB = r.at(embeddingTables[7]);
      expect(embeddingTables[7].number, '7', reason: 'premise: " 7 "');
      expect((sevenB - seven).distance, lessThan(kDoubleTapSlop),
          reason: 'premise: within the slop');
      for (final (p, i) in [(seven, 6), (sevenB, 7)]) {
        expect(r.picker.pick(r.ev(p).world)?.table.instance, r.instance(i),
            reason: 'premise: on its own 7');
      }
      r.tap(seven, ms(1000));
      r.tap(sevenB, ms(1100));
      expect(r.log, ['tap 7', 'tap 7'], reason: 'two instances (M-H20)');
      r.tap(sevenB, ms(1200));
      expect(r.log.last, 'double 7', reason: 'the other instance was kept');
      r.log.clear();
      r.camera.value = embeddingCamera();

      final one = r.at(table('1'));
      final unnumbered = r.at(embeddingTables[8]);
      final floor = canvasOf(r.camera.value, kFloorX, kFloorY);
      for (final (what, between) in <(String, void Function(Duration))>[
        ('the unnumbered table', (t) => r.tap(unnumbered, t)),
        ('the floor', (t) => r.tap(Offset(floor.x, floor.y), t)),
        ('a drag', (t) => r.drag(one, one + const Offset(0, 60), t)),
      ]) {
        r.log.clear();
        r.tap(one, ms(20000));
        between(ms(20050));
        // The table may have moved: tap where it is now.
        final node = r.doc.tree[r.instance(0)]! as InstanceNode;
        final m = node.transform;
        final now = canvasOf(r.camera.value, m.a * 700 + m.c * 100 + m.e,
            m.b * 700 + m.d * 100 + m.f);
        r.tap(Offset(now.x, now.y), ms(20100));
        expect(r.log.where((l) => l.startsWith('double')), isEmpty,
            reason: what);
        if (r.doc.commands.undoDepth > 0) r.doc.commands.undo();
      }

      r.log.clear();
      final p = r.at(table('1'));
      // The stamps stay within the timeout while the fake clock runs the
      // long press: only the reset tells the last tap from a double tap.
      r.tap(p, ms(30000));
      r.tool.onPointerDown(r.ev(p, time: ms(30050)), r.ctx);
      await tester.pump(kLongPressTimeout + ms(10));
      r.tool.onPointerUp(r.ev(p, buttons: 0, time: ms(30090)), r.ctx);
      r.tap(p, ms(30200));
      expect(r.log, ['tap 1', 'tap 1'], reason: 'a long press');
    });

    testWidgets('SE6 a cancelled press resets the chain', (tester) async {
      final r = rig();
      final p = r.at(table('1'));
      r.tap(p, ms(1000));
      r.tool.onPointerDown(r.ev(p, time: ms(1050)), r.ctx);
      r.tool.cancel(r.ctx);
      r.tap(p, ms(1100));
      expect(r.log, ['tap 1', 'tap 1']);
    });

    testWidgets('SE7 a locked table reports its double tap', (tester) async {
      final r = rig();
      final p = r.at(table('L'));
      r.tap(p, ms(1000));
      r.tap(p, ms(1100));
      expect(r.log, ['tap L', 'tap L', 'double L']);
      expect(r.selection.isEmpty, isTrue, reason: 'locked: never selected');
    });
    testWidgets(
        'SE14 with a group: tap, then groupTap, then the double tap, which '
        'reports the member\'s own number; taps on two members of one '
        'group are no double tap', (tester) async {
      final r = rig();
      // At 0.025 px/mm the members 1 and 2, 3 m apart, are within the slop.
      r.camera.value = ViewportTransform(
          worldToScreenMatrix: Transform2(0.025, 0, 0, -0.025, -425, -375));
      final groups = ValueNotifier<Map<String, TableGroup>>({
        'g': TableGroup(members: {'1', '2'})
      });
      addTearDown(groups.dispose);
      final tool = TableSelectTool(
          picker: r.picker,
          groups: groups,
          callbacks: () => (
                onTableTap: (n) => r.log.add('tap $n'),
                onLayoutChanged: null,
                onGroupTap: (g, n) => r.log.add('group $g $n'),
                onMergeRequested: null,
                onSplitRequested: null,
              ),
          events: () => r.events);
      addTearDown(tool.dispose);
      void tap(Offset s, Duration down) {
        tool.onPointerDown(r.ev(s, time: down), r.ctx);
        tool.onPointerUp(r.ev(s, buttons: 0, time: down + ms(40)), r.ctx);
      }

      final one = r.at(table('1'));
      final two = r.at(table('2'));
      expect((two - one).distance, lessThan(kDoubleTapSlop),
          reason: 'premise: within the slop');
      for (final (p, i) in [(one, 0), (two, 1)]) {
        expect(r.picker.pick(r.ev(p).world)?.table.instance, r.instance(i),
            reason: 'premise: on its own table');
      }
      tap(one, ms(1000));
      tap(one, ms(1100));
      expect(r.log, ['tap 1', 'group g 1', 'tap 1', 'group g 1', 'double 1']);
      expect(r.selection.keys, hasLength(2),
          reason: 'premise: a member stands for its group');
      r.log.clear();
      tap(two, ms(3000));
      tap(two, ms(3100));
      expect(r.log, ['tap 2', 'group g 2', 'tap 2', 'group g 2', 'double 2'],
          reason: 'the member\'s number, not the first member\'s');
      r.log.clear();
      tap(one, ms(5000));
      tap(two, ms(5100));
      tap(one, ms(5200));
      expect(
          r.log,
          [
            'tap 1', 'group g 1', 'tap 2', 'group g 2', 'tap 1', 'group g 1' //
          ],
          reason: 'one group, two tables: each tap keeps its own table');
    });
  });

  group('floor tap (E-3)', () {
    testWidgets(
        'SE8 a miss reports the down\'s world point after the selection '
        'logic, with or without a modifier (S-4)', (tester) async {
      final r = rig();
      r.tap(r.at(table('1')), ms(1000));
      expect(r.selection.isEmpty, isFalse, reason: 'premise');
      final down = canvasOf(r.camera.value, kFloorX, kFloorY);
      final cam = r.camera.value.worldToScreenMatrix;
      var emptyInCallback = false;
      r.events = (
        onTablesMoved: null,
        onTableDoubleTap: null,
        onFloorTap: (w) {
          r.floors.add(w);
          emptyInCallback = r.selection.isEmpty;
        },
        onTableHover: null,
      );
      // The up lands elsewhere: the down's point is the one reported.
      r.tool.onPointerDown(r.ev(Offset(down.x, down.y), time: ms(2000)), r.ctx);
      r.tool.onPointerUp(
          r.ev(Offset(down.x + 4, down.y - 3), buttons: 0, time: ms(2040)),
          r.ctx);
      expect(r.floors, hasLength(1));
      // The camera's inverse, written out: x = (sx - e) / a, y = (sy - f) / d.
      expect(r.floors.single.dx,
          closeTo((down.x - cam.e) / cam.a, kFloorX.abs() * 1e-12));
      expect(r.floors.single.dy,
          closeTo((down.y - cam.f) / cam.d, kFloorY.abs() * 1e-12));
      expect(r.floors.single.dx, closeTo(kFloorX, kFloorX.abs() * 1e-12));
      expect(r.floors.single.dy, closeTo(kFloorY, kFloorY.abs() * 1e-12));
      expect(emptyInCallback, isTrue, reason: 'the selection already cleared');

      r.tap(r.at(table('1')), ms(3000));
      r.tap(Offset(down.x, down.y), ms(4000), shift: true);
      expect(r.floors, hasLength(2), reason: 'a modifier miss reports too');
      expect(r.selection.isEmpty, isFalse, reason: 'and keeps the selection');
    });

    testWidgets(
        'SE9 a tap on the unnumbered table reports neither a tap nor the '
        'floor', (tester) async {
      final r = rig();
      r.tap(r.at(embeddingTables[8]), ms(1000));
      expect(r.log, isEmpty);
      expect(r.selection.keys, {SelectionKey.root(r.instance(8))},
          reason: 'premise: it was hit');
    });
  });

  group('moved (E-1)', () {
    testWidgets(
        'SE10 a drag reports the moved live instances once, ascending, after '
        'onLayoutChanged; a zero drag reports nothing', (tester) async {
      final r = rig();
      r.tap(r.at(table('4')), ms(1000));
      r.tap(r.at(table('1')), ms(2000), shift: true);
      r.log.clear();
      final from = r.at(table('4'));
      r.drag(from, from + const Offset(40, 25), ms(3000));
      expect(r.log, ['layout', 'moved 2']);
      expect(r.moved.single, [r.instance(0), r.instance(3)]);
      expect(r.moved.single[0].value < r.moved.single[1].value, isTrue);
      expect(() => r.moved.single.add(r.instance(1)), throwsUnsupportedError);
      r.log.clear();
      final two = r.at(table('2'));
      r.tool.onPointerDown(r.ev(two, time: ms(5000)), r.ctx);
      r.tool.onPointerMove(r.ev(two + const Offset(40, 0)), r.ctx);
      r.tool.onPointerMove(r.ev(two), r.ctx);
      r.tool.onPointerUp(r.ev(two, buttons: 0), r.ctx);
      expect(r.log, isEmpty, reason: 'a zero drag: nothing');
      expect(r.doc.commands.undoDepth, 1, reason: 'premise: no step');
    });
  });

  group('hover (E-4)', () {
    testWidgets(
        'SE11 a mouse hover reports on change only; an exit reports null when '
        'the last was not (M-H29 hover per move)', (tester) async {
      final r = rig();
      final one = table('1');
      r.hover(r.at(one, 600, 0));
      r.hover(r.at(one, 700, 100));
      r.hover(r.at(one, 800, 50));
      expect(r.hovers, ['1']);
      final floor = canvasOf(r.camera.value, kFloorX, kFloorY);
      r.hover(Offset(floor.x, floor.y));
      r.hover(Offset(floor.x + 5, floor.y));
      expect(r.hovers, ['1', null]);
      r.hover(r.at(one));
      r.hover(r.at(one, 650, 120));
      expect(r.hovers, ['1', null, '1']);
      r.hover(r.at(embeddingTables[8]));
      expect(r.hovers, ['1', null, '1', null], reason: 'unnumbered: null');
      r.tool.onPointerExit(r.ctx);
      expect(r.hovers, ['1', null, '1', null], reason: 'already null');
      r.hover(r.at(table('L')));
      r.tool.onPointerExit(r.ctx);
      r.tool.onPointerExit(r.ctx);
      expect(r.hovers, ['1', null, '1', null, 'L', null]);
    });

    testWidgets(
        'SE12 a stylus hovers; a finger never does (M-H29 hover for touch)',
        (tester) async {
      final r = rig();
      r.hover(r.at(table('1')), kind: PointerDeviceKind.touch);
      expect(r.hovers, isEmpty, reason: 'touch');
      r.hover(r.at(table('1')), kind: PointerDeviceKind.stylus);
      expect(r.hovers, ['1'], reason: 'stylus');
      r.hover(r.at(table('2')), kind: PointerDeviceKind.invertedStylus);
      expect(r.hovers, ['1', '2']);
    });

    testWidgets('SE13 no callback: no pick at all; a press\'s move is no hover',
        (tester) async {
      final r = rig();
      r.events = kNoServiceEvents;
      r.hover(r.at(table('1')));
      r.hover(r.at(table('2')));
      expect(r.picker.picks, 0, reason: 'no pick without the callback');
      r.events = (
        onTablesMoved: null,
        onTableDoubleTap: null,
        onFloorTap: null,
        onTableHover: r.hovers.add,
      );
      r.hover(r.at(table('1')));
      expect(r.picker.picks, 1);
      expect(r.hovers, ['1']);
      final p = r.at(table('2'));
      r.tool.onPointerDown(r.ev(p), r.ctx);
      r.tool.onPointerMove(r.ev(p + const Offset(2, 1)), r.ctx);
      r.tool.onPointerUp(r.ev(p, buttons: 0), r.ctx);
      expect(r.hovers, ['1'], reason: 'a pressed move is not a hover');
    });

    testWidgets(
        'SE15 with onTableHover set, hovers over 60 tables\' tops, their '
        'boxes and the floor between them allocate nothing per table: no '
        'inverse is asked for a point, no candidate is rebuilt (CLAUDE.md; '
        'Task 4 review R-5)', (tester) async {
      // Trapezoid tables in rows 40 m off the origin, each turned 37
      // degrees and mirrored, numbered 1..60, the base point (900, 650) of
      // each at its row's place.
      final doc = rowOfTables(60);
      final made = Tally();
      final inverses = <CountingTransform>[];
      final picker = TablePicker(doc, invert: (m) {
        final inverse = CountingTransform(m.invert(), made);
        inverses.add(inverse);
        return inverse;
      });
      final hovers = <String?>[];
      final ServiceEvents<Handle> events = (
        onTablesMoved: null,
        onTableDoubleTap: null,
        onFloorTap: null,
        onTableHover: hovers.add,
      );
      final tool = TableSelectTool(
          picker: picker,
          groups: ValueNotifier(const {}),
          callbacks: () => (
                onTableTap: null,
                onLayoutChanged: null,
                onGroupTap: null,
                onMergeRequested: null,
                onSplitRequested: null,
              ),
          events: () => events);
      // 0.1 px/mm, y up, panned: a mouse's 6 px are 60 mm.
      const view = Transform2(0.1, 0, 0, -0.1, -3900, -2600);
      final camera =
          CameraController(ViewportTransform(worldToScreenMatrix: view));
      final index = SpatialIndex(doc);
      final selection = SelectionController(doc);
      final ctx = ToolContext(
          document: doc, index: index, camera: camera, selection: selection);
      addTearDown(() {
        tool.dispose();
        selection.dispose();
        index.dispose();
        camera.dispose();
        doc.dispose();
      });
      void hover(double x, double y) => tool.onPointerMove(
          ToolPointerEvent(
              screen: Offset(view.a * x + view.e, view.d * y + view.f),
              world: Vector2(x, y),
              pointer: 1,
              buttons: 0,
              shift: false,
              control: false,
              meta: false,
              alt: false,
              pickRadiusWorld: 60),
          ctx);

      final tables = TableSurvey.of(doc).tables;
      expect([
        for (final t in tables) t.number
      ], [
        for (var k = 1; k <= 60; k++) '$k'
      ], reason: 'premise');
      final placements = [
        for (final t in tables)
          (doc.tree[t.instance]! as InstanceNode).transform
      ];
      (double, double) on(Transform2 m, double x, double y) =>
          (m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);
      // Per table, by the forward transform: a point of its top; a point
      // of its box off its top (the second pass); the floor beyond its
      // base point, 1.77 m from every base and so off every box (each box
      // reaches 0.79 m from its base), where both passes run in full.
      final round = [
        for (final m in placements) ...[
          on(m, 900, 600),
          on(m, 250, 950),
          (on(m, 900, 650).$1 + 1250, on(m, 900, 650).$2 - 1250),
        ]
      ];
      final candidates = picker.candidates;
      expect(inverses, hasLength(60), reason: 'one inverse per candidate');
      for (final c in candidates) {
        expect(c.top!.contains(250, 950, TablePicker.tolerance), isFalse,
            reason: 'premise: the box point is off the top');
      }
      final heard = [
        for (var k = 1; k <= 60; k++) ...['$k', null]
      ];
      for (final (x, y) in round) {
        hover(x, y); // warm-up
      }
      expect(hovers, heard, reason: 'premise: each pick lands');

      made.count = 0;
      for (var pass = 0; pass < 5; pass++) {
        for (final (x, y) in round) {
          hover(x, y);
        }
      }
      expect(hovers, [for (var pass = 0; pass < 6; pass++) ...heard]);
      expect(made.count, 0,
          reason: '900 hovers asked no inverse for a new object');
      expect(inverses, hasLength(60), reason: 'no inverse built anew');
      expect(identical(picker.candidates, candidates), isTrue,
          reason: 'the candidates are cached, not rebuilt per move');
    });
  });

  group('double tap slop (final review F-6)', () {
    testWidgets(
        'SE16 the slop is measured from the first tap\'s down, not where it '
        'came up: a first tap that drifts 15 px (within kTouchSlop) before '
        'its up neither breaks a double tap 99 px from its down nor makes '
        'one 101 px from it', (tester) async {
      final r = rig();
      final near = r.at(table('4'), 450, 100);
      final a = Offset(near.dx.roundToDouble(), near.dy.roundToDouble());
      const drift = Offset(15, 0);
      final points = [
        a,
        a + drift,
        a - drift,
        a + const Offset(-99, 0),
        a + const Offset(-101, 0)
      ];
      for (final p in points) {
        expect(r.picker.pick(r.ev(p).world)?.table.instance, r.instance(3),
            reason: 'premise: on 4');
      }

      /// A tap down at [down], moved to [up] before it comes up there.
      void drifting(Offset down, Offset up, Duration at) {
        r.tool.onPointerDown(r.ev(down, time: at), r.ctx);
        r.tool.onPointerMove(r.ev(up, time: at + ms(20)), r.ctx);
        r.tool.onPointerUp(r.ev(up, buttons: 0, time: at + ms(40)), r.ctx);
      }

      // 99 px from the first down, 114 px from its up: a double tap. The
      // drifting tap is logged as a tap: 15 px is within kTouchSlop.
      drifting(a, a + drift, ms(1000));
      r.tap(a + const Offset(-99, 0), ms(1100));
      expect(r.log, ['tap 4', 'tap 4', 'double 4'], reason: '99 px');
      r.log.clear();

      // 101 px from the first down, 86 px from its up: two taps.
      drifting(a, a - drift, ms(3000));
      r.tap(a + const Offset(-101, 0), ms(3100));
      expect(r.log, ['tap 4', 'tap 4'], reason: '101 px');
    });
  });
}
