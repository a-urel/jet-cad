// What alignment guides allocate (alignment guides spec, Constraints; plan
// Task 10): nothing per event over today's baseline. The three tools that
// snap to neighbours -- the design move (`PlanMoveGuides`, the `MoveAdjuster`
// of `SelectTool`), placement (`PlanSymbolTool`) and the service drag
// (`ServiceTool`) -- are driven end to end with prebuilt pointer events
// (built before the meter's window, so the test's own objects stay out of
// it) and prebuilt cameras, guides on and guides off in separate meter
// epochs, at 10 and at 200 references. Today's tools allocate a few objects
// per event whatever the guides do (`GripDrag.moveTo`'s `Transform2`, the
// placement's `_free()`); that is the baseline, it cancels in on minus off,
// and a control epoch with no tool shows the meter's own floor.
//
// Same mechanism as `pick_allocation_test.dart`: the VM's allocation
// profiler through `AllocationMeter`, which needs `--enable-vmservice` under
// `flutter test` and skips with [vmServiceUnavailableReason] without it.
// Only the classes the guide code would build are watched: the noisy core
// classes (`_List`, `_Map`, `_Closure`, `_Double`, `_GrowableList`) are not
// (the meter's doc, failure mode 2). `_Double` is therefore not proved here;
// a boxed double on a hot path would show as a `Vector2` or a typed list
// only if it were stored in one, which is what a regression to a per-event
// candidate or box does.
//
// **The fixtures are not degenerate:** tables 40 m off the origin in a grid,
// every third turned 30 degrees, every fifth turned 90, every fourth
// mirrored; the camera at scale 0.5, panned; the pointers' paths aligned to
// the grid's columns and rows within the aperture, so most events capture
// (asserted: a run whose guides never captured proves nothing).
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_painter.dart';
import 'package:jet_cad_2d_plan/src/guides/guide_solver.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_symbol_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_rig.dart';
import '../support/symbol_fixtures.dart' show settle;
import '../support/unit_fixtures.dart';
import 'vm_allocation_meter.dart';

/// What a guide regression would build per event: a point, a transform, a
/// box, a solution or a reference set (a fresh typed list per event shows as
/// `_Float64List`, a set built per event as `_Set`).
const _watched = {
  'Vector2',
  'Transform2',
  'Aabb2',
  'GuideSolution',
  'GuideReferences',
  '_Float64List',
  '_Set',
};

/// Instances per event admitted over the guides-off epoch: the meter's own
/// noise (a handful per epoch) but not one object per event.
/// What a painter regression makes per call: a paint, a point, a path, a
/// fresh list.
const _painted = {
  'Offset',
  'Paint',
  'Path',
  '_Float32List',
  'Vector2',
  'Transform2',
};

const double _perEventBudget = 0.05;

const int _pointerEvents = 200;
const int _cameraEvents = 50;
const int _rounds = 2;

/// Warm-up events of each kind. The brief's 50 left the JIT mid-way: the
/// baseline's own `Vector2`s and `Transform2`s read 0 or 100 and 250 or 60
/// for the same code on successive runs (escape analysis switching on late),
/// which made on minus off a coin toss. As `pick_allocation_test` warms
/// 20,000 picks, this warms until the readings hold still.
const int _warmPointer = 600;
const int _warmCamera = 200;
const int _ring = 64;

// ---------------------------------------------------------------------------
// The plan: a grid of tables off the origin.

const double _pitch = 2500;
const double _originX = 40000, _originY = -27000;

final ViewportTransform _camera0 = ViewportTransform(
    worldToScreenMatrix: const Transform2(0.5, 0, 0, -0.5, -19000, -13000));

/// Eight cameras, each different from its neighbours: pans and two scales.
final List<ViewportTransform> _cameras = [
  for (var i = 0; i < 8; i++)
    ViewportTransform(
        worldToScreenMatrix: Transform2(i.isEven ? 0.5 : 0.62, 0, 0,
            i.isEven ? -0.5 : -0.62, -19000 + 13.0 * i, -13000 - 7.0 * i)),
];

PlanKit _kit() => PlanKit(
      id: 'fx',
      version: '1.0.0',
      symbols: [
        SymbolLibrarySource(
            label: 'fx',
            read: () async =>
                encodeLibrary(Catalog(kit: 'fx', symbols: [tableSymbol()]))),
      ],
    );

int _columns(int count) => count == 10 ? 5 : 20;
int _rows(int count) => count ~/ _columns(count);

Transform2 _placement(int i, int count) {
  final cols = _columns(count);
  final theta = i % 3 == 1
      ? 30 * math.pi / 180
      : i % 5 == 2
          ? math.pi / 2
          : 0.0;
  return placementAt(
      _originX + _pitch * (i % cols), _originY - _pitch * (i ~/ cols), theta,
      mirrored: i % 4 == 3);
}

/// [count] labelled tables in a grid, the page grid snap off.
String _planOf(int count) => planText([_kit()], (d) {
      for (var i = 0; i < count; i++) {
        final h = placeUnit(d, tableSymbol(), transform: _placement(i, count));
        addUnitLabel(d, h, '${i + 1}');
      }
      d.commands.execute(SetComponentCommand<PageComponent>(
          d.rootHandle,
          d.components
              .get<PageComponent>(d.rootHandle)!
              .copyWith(snapToGrid: false, gridStepMm: 100)));
    });

// ---------------------------------------------------------------------------
// Prebuilt events.

/// Pointer targets: from [from], deltas that bring a moved box onto a
/// column and a row of the grid, within the aperture (6 px at scale 0.5 is
/// 12 mm; jitters of -8..+8 mm), so most events capture, some do not.
List<Vector2> _targets(Vector2 from, int count) {
  final cols = _columns(count), rows = _rows(count);
  return [
    for (var k = 0; k < _ring; k++)
      Vector2(from.x + _pitch * (1 + k % (cols - 1)) + ((k * 3) % 5 - 2) * 4.0,
          from.y - _pitch * (k % rows) + ((k * 7) % 5 - 2) * 4.0),
  ];
}

ToolPointerEvent _event(ViewportTransform cam, Vector2 w,
    {int buttons = 0, int pointer = 7, bool touch = false}) {
  final s = cam.worldToScreen(w);
  return ToolPointerEvent(
      screen: ui.Offset(s.x, s.y),
      world: w.clone(),
      pointer: pointer,
      buttons: buttons,
      shift: false,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / cam.scale,
      kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse);
}

// ---------------------------------------------------------------------------
// The scenes: one tool in its drive, begun before the meter, ready for
// events.

abstract class _Scene {
  /// Events in which the guides captured an axis (read after each).
  int captured = 0;

  void pointer(int i);
  void camera(int i);
  void finish();
}

/// The control: the same prebuilt events and cameras with no tool.
final class _Control extends _Scene {
  _Control(int count)
      : _events = [
          for (final w in _targets(Vector2(_originX, _originY), count))
            _event(_camera0, w, buttons: kPrimaryButton),
        ];

  final List<ToolPointerEvent> _events;
  final CameraController _camera = CameraController(_camera0);
  int touched = 0;

  @override
  void pointer(int i) => touched += _events[i % _ring].pointer;

  @override
  void camera(int i) => _camera.value = _cameras[i % _cameras.length];

  @override
  void finish() {}
}

/// Tables 0..[moved]-1 selected, grabbed on table 0's top edge, dragged by
/// the design move.
final class _DesignScene extends _Scene {
  _DesignScene._(this.c, this.tool, this.ctx, this._events, this._release);

  final PlanController c;
  final Tool tool;
  final ToolContext ctx;
  final List<ToolPointerEvent> _events;
  final ToolPointerEvent _release;

  static _DesignScene build(
      PlanController c, int count, int moved, bool guides) {
    final ctx = c.toolController.context;
    ctx.camera.value = _camera0;
    if (c.snap.objectSnap) c.snap.toggleObjectSnap();
    if (!guides) c.alignmentGuides.toggle();
    c.selectTool('plan.select');
    final doc = c.document;
    final tables = [
      for (final n in doc.tree.nodes)
        if (n is InstanceNode && n.parent == doc.rootHandle) n.handle,
    ]..sort((a, b) => a.value.compareTo(b.value));
    expect(tables, hasLength(count), reason: 'premise: every table');
    c.selection
        .replace([for (final h in tables.take(moved)) SelectionKey.root(h)]);
    final t0 = (doc.tree[tables.first]! as InstanceNode).transform;
    final grab = t0.transformPoint(Vector2(1400, 1100));
    final tool = c.toolController.active;
    final events = [
      for (final w in _targets(grab, count))
        _event(_camera0, w, buttons: kPrimaryButton),
    ];
    tool.onPointerMove(_event(_camera0, grab), ctx);
    tool.onPointerDown(_event(_camera0, grab, buttons: kPrimaryButton), ctx);
    // The first move starts the drag (and allocates, unmetered).
    tool.onPointerMove(events.first, ctx);
    return _DesignScene._(c, tool, ctx, events, _event(_camera0, grab));
  }

  void _count() {
    final s = c.debugMoveGuides.debugSolution;
    if (s.capturedX || s.capturedY) captured++;
  }

  @override
  void pointer(int i) {
    tool.onPointerMove(_events[i % _ring], ctx);
    _count();
  }

  @override
  void camera(int i) {
    ctx.camera.value = _cameras[i % _cameras.length];
    _count();
  }

  @override
  void finish() => tool.onPointerUp(_release, ctx);
}

/// The armed table hovered over the grid.
final class _PlaceScene extends _Scene {
  _PlaceScene._(this.c, this.tool, this.ctx, this._events);

  final PlanController c;
  final PlanSymbolTool tool;
  final ToolContext ctx;
  final List<ToolPointerEvent> _events;

  static _PlaceScene build(PlanController c, int count, bool guides) {
    final ctx = c.toolController.context;
    ctx.camera.value = _camera0;
    if (c.snap.objectSnap) c.snap.toggleObjectSnap();
    if (!guides) c.alignmentGuides.toggle();
    final tool = c.toolFor('plan.symbol')! as PlanSymbolTool;
    expect(c.armSymbol(c.symbolById('fx.table.two@1')!), isTrue);
    final events = [
      for (final w in _targets(Vector2(_originX, _originY), count))
        _event(_camera0, w),
    ];
    tool.onPointerMove(events.first, ctx);
    return _PlaceScene._(c, tool, ctx, events);
  }

  void _count() {
    final s = tool.debugSolution;
    if (s.capturedX || s.capturedY) captured++;
  }

  @override
  void pointer(int i) {
    tool.onPointerMove(_events[i % _ring], ctx);
    _count();
  }

  @override
  void camera(int i) {
    ctx.camera.value = _cameras[i % _cameras.length];
    _count();
  }

  @override
  void finish() {}
}

/// Tables 0..[moved]-1 selected, dragged by the service tool.
final class _ServiceScene extends _Scene {
  _ServiceScene._(this.r, this._events, this._release);

  final ServiceRig r;
  final List<ToolPointerEvent> _events;
  final ToolPointerEvent _release;

  static _ServiceScene build(ServiceRig r, int count, int moved, bool guides) {
    r.c.camera.value = _camera0;
    if (!guides) r.c.alignmentGuides.toggle();
    final tables = [
      for (final n in r.doc.tree.nodes)
        if (n is InstanceNode && n.parent == r.doc.rootHandle) n.handle,
    ]..sort((a, b) => a.value.compareTo(b.value));
    expect(tables, hasLength(count), reason: 'premise: every table');
    r.ctx.selection.replace({for (final h in tables.take(moved)) r.key(h)});
    final grab =
        r.node(tables.first).transform.transformPoint(Vector2(900, 700));
    final events = [
      for (final w in _targets(grab, count))
        _event(_camera0, w, buttons: kPrimaryButton, pointer: 1),
    ];
    r.tool.onPointerDown(
        _event(_camera0, grab, buttons: kPrimaryButton, pointer: 1), r.ctx);
    r.tool.onPointerMove(events.first, r.ctx);
    return _ServiceScene._(r, events, _event(_camera0, grab, pointer: 1));
  }

  void _count() {
    final s = r.tool.debugSolution;
    if (s.capturedX || s.capturedY) captured++;
  }

  @override
  void pointer(int i) {
    r.tool.onPointerMove(_events[i % _ring], r.ctx);
    _count();
  }

  @override
  void camera(int i) {
    r.c.camera.value = _cameras[i % _cameras.length];
    _count();
  }

  @override
  void finish() => r.tool.onPointerUp(_release, r.ctx);
}

// ---------------------------------------------------------------------------
// The readings.

/// Per class, the least and the most instances one window read over the
/// rounds.
final class _Range {
  final Map<String, int> least = {for (final k in _watched) k: 1 << 40};
  final Map<String, int> most = {for (final k in _watched) k: -(1 << 40)};

  void add(Map<String, int> counts, Map<String, int> floor) {
    for (final k in _watched) {
      final net = counts[k]! - floor[k]!;
      least[k] = math.min(least[k]!, net);
      most[k] = math.max(most[k]!, net);
    }
  }

  @override
  String toString() => '{${[
        for (final k in _watched) '$k: ${least[k]}..${most[k]}'
      ].join(', ')}}';
}

// ---------------------------------------------------------------------------
// The measure.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AllocationMeter? meter;

  setUpAll(() async {
    meter = await AllocationMeter.connect();
  });

  tearDownAll(() async {
    await meter?.dispose();
  });

  final plans = <int, String>{};
  String plan(int count) => plans[count] ??= _planOf(count);

  /// [scene] warmed, then [_rounds] epochs, each metering [_pointerEvents]
  /// pointer-driven events and, in its own window, [_cameraEvents]
  /// camera-driven ones, net of the epoch's own floor (an epoch with no
  /// event: the live objects a scene holds read in every epoch, the meter's
  /// failure mode 1, as `pick_allocation_test`'s hall subtracts them). Per
  /// window and class the least and the most of the rounds: an allocation
  /// the code makes on every event is in every round, while the JIT's escape
  /// analysis comes and goes on the *baseline's* own objects (a placement's
  /// `Transform2`s read 1600 and 200 per 200 events in successive rounds of
  /// one scene).
  Future<_Range> epoch(AllocationMeter m, _Scene scene) async {
    for (var i = 0; i < _warmPointer; i++) {
      scene.pointer(i);
    }
    for (var i = 0; i < _warmCamera; i++) {
      scene.camera(i);
    }
    final range = _Range();
    // The floor is the same in every round (measured), so it is read once.
    await m.reset();
    final floor = await m.accumulatedInstances(_watched);
    for (var round = 0; round < _rounds; round++) {
      scene.captured = 0;
      await m.reset();
      for (var i = 0; i < _pointerEvents; i++) {
        scene.pointer(i);
      }
      for (var i = 0; i < _cameraEvents; i++) {
        scene.camera(i);
      }
      range.add(await m.accumulatedInstances(_watched), floor);
    }
    return range;
  }

  Future<_Scene> design(int count, int moved, bool guides) async {
    final c = controllerFor(kits: [_kit()], json: plan(count));
    await settle();
    return _DesignScene.build(c, count, moved, guides);
  }

  Future<_Scene> place(int count, bool guides) async {
    final c = controllerFor(kits: [_kit()], json: plan(count));
    await settle();
    return _PlaceScene.build(c, count, guides);
  }

  Future<_Scene> service(int count, int moved, bool guides) async {
    final r = ServiceRig(plan(count), kits: [_kit()]);
    addTearDown(r.dispose);
    await settle();
    return _ServiceScene.build(r, count, moved, guides);
  }

  /// One tool at [counts] references: control, off and on epochs at each,
  /// the on-minus-off per event bounded, and not growing with the count.
  void tool(String name, Future<_Scene> Function(int count, bool guides) make,
      {int? only}) {
    test(
        '$name: guides add no allocation per event over guides off, at 10 and '
        '200 references',
        timeout: const Timeout(Duration(minutes: 5)), () async {
      final m = meter;
      if (m == null) {
        markTestSkipped(vmServiceUnavailableReason);
        return;
      }
      const events = _pointerEvents + _cameraEvents;
      // One control per tool: the meter's own floor, no tool in the loop.
      final control = await epoch(m, _Control(10));
      final onRanges = <int, _Range>{};
      for (final count in [10, 200]) {
        final offScene = await make(count, false);
        final off = await epoch(m, offScene);
        offScene.finish();
        final onScene = await make(count, true);
        final on = await epoch(m, onScene);
        final captured = onScene.captured;
        onScene.finish();
        onRanges[count] = on;
        // ignore: avoid_print
        print('$name, $count references, per $events events:\n'
            '  control $control\n  off $off\n  on $on\n'
            '  captured on $captured of the last round\'s events');
        expect(captured, greaterThan(100),
            reason: 'premise: the guides captured on many of the events');
        for (final k in _watched) {
          // The least of guides on over the most of guides off: what the
          // guides cost on every event, past any baseline allocation the
          // JIT leaves in or out.
          expect(on.least[k]! - off.most[k]!,
              lessThanOrEqualTo(_perEventBudget * events),
              reason: '$name $k, $count references: on '
                  '${on.least[k]}..${on.most[k]}, off '
                  '${off.least[k]}..${off.most[k]}, control '
                  '${control.most[k]} over $events events');
        }
      }
      for (final k in _watched) {
        expect(
            onRanges[200]!.least[k]!,
            lessThanOrEqualTo(
                onRanges[10]!.most[k]! + _perEventBudget * events),
            reason: '$name $k: guides on read more at 200 references '
                '(${onRanges[200]!.least[k]}..${onRanges[200]!.most[k]}) than '
                'at 10 (${onRanges[10]!.least[k]}..${onRanges[10]!.most[k]})');
      }
    });
  }

  tool('GA1 design move of one table', (n, g) => design(n, 1, g));
  tool('GA2 design move of three tables', (n, g) => design(n, 3, g));
  tool('GA3 placement', place);
  tool('GA4 service drag of one table', (n, g) => service(n, 1, g));
  tool('GA5 service drag of three tables', (n, g) => service(n, 3, g));

  test(
      'GA6 the painter draws a full solution through one list: no Offset, '
      'Paint, Path or typed list per call', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final s = GuideSolution();
    for (var i = 0; i < kGuideCapacity; i++) {
      s.lines[4 * i] = (i % 2).toDouble();
      s.lines[4 * i + 1] = 40000.0 + 130 * i;
      s.lines[4 * i + 2] = -26000.0 - 90 * i;
      s.lines[4 * i + 3] = -24000.0 + 70 * i;
      s.marks[4 * i] = (i % 2).toDouble();
      s.marks[4 * i + 1] = 41000.0 + 50 * i;
      s.marks[4 * i + 2] = 42000.0 + 90 * i;
      s.marks[4 * i + 3] = -25000.0 - 40 * i;
    }
    s.lineCount = kGuideCapacity;
    s.markCount = kGuideCapacity;
    final canvas = ui.Canvas(ui.PictureRecorder());
    final painter = GuidePainter();
    const colour = ui.Color(0xFFE0218A);
    final camera = Transform2.translation(300, 500)
        .multiply(Transform2.rotation(0.3))
        .multiply(Transform2.scale(0.5, -0.5));
    for (var i = 0; i < 50; i++) {
      painter.paint(canvas, camera, s, color: colour, strokePixels: 1);
    }
    // The premise: the segments are real (not all degenerate).
    expect(painter.debugPoints.any((v) => v != 0), isTrue);
    await m.reset();
    final floor = await m.accumulatedInstances(_painted);
    await m.reset();
    const calls = 100;
    for (var i = 0; i < calls; i++) {
      painter.paint(canvas, camera, s, color: colour, strokePixels: 1);
    }
    final read = await m.accumulatedInstances(_painted);
    final counts = {for (final k in _painted) k: read[k]! - floor[k]!};
    // ignore: avoid_print
    print('GuidePainter over $calls calls: $counts');
    for (final MapEntry(key: name, value: count) in counts.entries) {
      expect(count / calls, lessThanOrEqualTo(_perEventBudget),
          reason: '$name: $count over $calls paints');
    }
  });

  test(
      'GA7 the solution\'s buffers keep their capacity: 16 lines and 16 '
      'marks, the same lists across solves, however many references capture',
      () {
    // 200 references on one row, the aperture covering all of them: far
    // more candidates than the buffers hold.
    final boxes = Float64List(4 * 200);
    for (var i = 0; i < 200; i++) {
      boxes[4 * i] = 40000.0 + 3 * i;
      boxes[4 * i + 1] = -26000.0 - 700 * i;
      boxes[4 * i + 2] = 40000.0 + 3 * i + 1200;
      boxes[4 * i + 3] = -26000.0 - 700 * i + 800;
    }
    final refs =
        GuideReferences(boxes, [for (var i = 0; i < 200; i++) Handle(i + 10)]);
    final s = GuideSolution();
    final lines = s.lines, marks = s.marks;
    expect(lines, hasLength(4 * kGuideCapacity));
    expect(marks, hasLength(4 * kGuideCapacity));
    for (var k = 0; k < 3; k++) {
      solveGuides(refs,
          minX: 40200.0 + k,
          minY: -26100.0,
          maxX: 41400.0 + k,
          maxY: -25300.0,
          aperture: 2000,
          freeX: true,
          freeY: true,
          fallbackDx: 0,
          fallbackDy: 0,
          moving: const <Handle>{},
          out: s);
      expect(identical(s.lines, lines), isTrue);
      expect(identical(s.marks, marks), isTrue);
      expect(s.lineCount, lessThanOrEqualTo(kGuideCapacity));
      expect(s.markCount, lessThanOrEqualTo(kGuideCapacity));
    }
    expect(s.lineCount + s.markCount, greaterThan(0),
        reason: 'premise: the far-out solve produced guides');
    s.reset();
    expect(identical(s.lines, lines), isTrue);
    expect(identical(s.marks, marks), isTrue);
  });
}
