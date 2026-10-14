// Ported from jet_cad_floor_plan/test/invariants/band_allocation_test.dart; assertions unchanged.
// What a live band builds per frame (rubber-band spec RB-6, RB16): the
// selection mode's tool paints its band through one kept
// `SelectionBandPainter`, so a band's frame builds no `Paint` and no `Path`.
// Measured, not inferred: the Dart VM's own allocation profiler, through
// `AllocationMeter` (`vm_allocation_meter.dart`), as `pick_allocation_test`
// does.
//
// **Under `flutter test` the profiler needs `--enable-vmservice`**: CI runs
// this package's tests with it. Without it the test skips with
// [vmServiceUnavailableReason], and CI's standing comparison reads such a
// skip as red.
//
// **What the VM sees.** `Paint` is a Dart class of `dart:ui`; `Path` is an
// interface whose engine-backed implementation is the Dart wrapper class
// `_NativePath`. The profiler counts those Dart wrappers (the engine's own
// native memory is not on the Dart heap). A `Paint` holds its fields in a
// `ByteData` (`_ByteDataView` to the VM) that the canvas hands the engine:
// measured while building this test, the JIT may scalar-replace a `Paint`
// built and drawn at once (M-RB19 once read 2 `Paint`s over 1,000 frames)
// but never its escaping `_ByteDataView` (1,002 on every run), so both are
// watched. `_Uint8List`, the view's buffer, is not: the meter's own round
// trip makes some 900 of them per epoch. The test proves the meter sees a
// paint and a path before it trusts a clean reading: a control loop that
// builds a known number of each must read at least that many.
//
// **The fixture is not degenerate:** the camera is y-flipped, scaled and off
// the origin; the plan holds a turned, mirrored table; the band's pointer
// moves 1 px per frame on a triangle wave across the press, so the frames
// alternate between window (a stroked rect) and crossing (a dashed path).
library;

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/service/service_state.dart' show UnitGroup;
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/service_rig.dart' show hallController;
import '../support/unit_fixtures.dart';
import 'vm_allocation_meter.dart';

/// The classes a per-frame paint or path would make, as the VM names them.
const _watched = {'Paint', '_ByteDataView', 'Path', '_NativePath'};

/// Instances admitted over the measured frames, all classes together, past
/// the no-frame baseline.
const int _budget = 2;

const int _frames = 1000;

/// The pointer's x at frame [i]: a triangle wave about the press's x, 1 px
/// per frame, from 100 px left of it to 100 px right and back.
double _x(double pressX, int i) => pressX + 100 - ((i % 400) - 200).abs();

/// RB16's frames over a live band of [tool]: the measure, the control and
/// the budget, from a band pressed at [press] (2b Task 14: shared with
/// RB16-hall).
Future<void> bandFrames(
    AllocationMeter m,
    Tool tool,
    ToolContext ctx,
    CameraController camera,
    ui.Offset press,
    ToolPointerEvent Function(ui.Offset s) ev) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const viewport = ui.Size(1400, 900);
  var windows = 0, crossings = 0;
  void frames(int n) {
    for (var i = 0; i < n; i++) {
      final at = ui.Offset(_x(press.dx, i), 300 + (i % 2).toDouble());
      tool.onPointerMove(ev(at), ctx);
      tool.paintOverlay(canvas, camera.value, viewport, PaperPalette.light);
    }
  }

  // Premise: the wave alternates the modes.
  for (var i = 0; i < _frames; i++) {
    if (bandModeFor(press, ui.Offset(_x(press.dx, i), 0)) == BandMode.window) {
      windows++;
    } else {
      crossings++;
    }
  }
  expect(windows, greaterThan(_frames ~/ 4));
  expect(crossings, greaterThan(_frames ~/ 4));

  // Warm: the JIT optimises the move and the paint before the count.
  frames(4 * _frames);
  // The baseline: an epoch with no frame. It reads the painter's own kept
  // objects (two paints, their two data views, one path), live since the
  // tool was built: the meter's failure mode 1, measured at 5 whatever
  // the frame count (0 or 1,000). The frames are held to their excess
  // over it.
  await m.reset();
  final baseline = await m.accumulatedInstances(_watched);
  await m.reset();
  frames(_frames);
  final counts = await m.accumulatedInstances(_watched);
  expect(tool.phase, ToolPhase.dragging, reason: 'premise: still banding');
  recorder.endRecording().dispose();

  // The meter sees both classes: a control loop builds 100 of each. Run
  // after the measure, so its live objects never reach the measured
  // epoch (the meter's failure mode 1).
  await m.reset();
  final kept = [
    for (var i = 0; i < 100; i++) (ui.Paint(), ui.Path()),
  ];
  final control = await m.accumulatedInstances(_watched);
  expect(kept, hasLength(100));
  expect(control['Paint'], greaterThanOrEqualTo(100),
      reason: 'premise: the meter sees a Paint ($control)');
  expect(control['_ByteDataView'], greaterThanOrEqualTo(100),
      reason: 'premise: the meter sees a Paint\'s data ($control)');
  expect(control['_NativePath']! + control['Path']!, greaterThanOrEqualTo(100),
      reason: 'premise: the meter sees a Path ($control)');

  int sum(Map<String, int> c) => c.values.fold(0, (a, b) => a + b);
  expect(sum(counts) - sum(baseline), lessThanOrEqualTo(_budget),
      reason: '$counts over $_frames frames, $baseline with none');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AllocationMeter? meter;

  setUpAll(() async {
    meter = await AllocationMeter.connect();
  });

  tearDownAll(() async {
    await meter?.dispose();
  });

  test(
      'RB16 a live band builds no Paint and no Path per frame, window and '
      'crossing alike (M-RB19)', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final doc = unitPlan();
    placeAt(doc, tableSymbol(), Vector2(-2000, 1000),
        quarterTurns: 1, mirrored: true);
    final camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 700, 450)));
    final index = SpatialIndex(doc);
    final selection = SelectionController(doc);
    final groups = ValueNotifier<Map<String, UnitGroup>>(const {});
    final tool = ServiceTool(
        picker: UnitPicker(doc, unitsOf(doc)),
        groups: groups,
        callbacks: () => kNoServiceCallbacks,
        options: () => (
              longPress: PlanLongPress.toggleSelection,
              onUnitContextMenu: null,
              floorDrag: PlanFloorDrag.band,
            ));
    addTearDown(() {
      tool.dispose();
      groups.dispose();
      selection.dispose();
      index.dispose();
      camera.dispose();
    });
    final ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
    ToolPointerEvent ev(ui.Offset s, {int buttons = kPrimaryButton}) =>
        ToolPointerEvent(
          screen: s,
          world: camera.value.screenToWorld(Vector2(s.dx, s.dy)),
          pointer: 1,
          buttons: buttons,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: 6 / camera.value.scale,
          kind: PointerDeviceKind.mouse,
        );

    const press = ui.Offset(900, 120);
    tool.onPointerDown(ev(press), ctx);
    tool.onPointerMove(ev(const ui.Offset(1100, 300)), ctx);
    expect(tool.phase, ToolPhase.dragging, reason: 'premise: a live band');

    await bandFrames(m, tool, ctx, camera, press, ev);
  });

  test(
      'RB16-hall a live band over the hall (500 seats in 25 rows) builds no '
      'Paint and no Path per frame (2b Review Focus 5)', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final hall = hallController();
    addTearDown(hall.dispose);
    final s = hall.serviceSession!;
    s.host = ServiceHost(
        options: () => (
              longPress: PlanLongPress.toggleSelection,
              onUnitContextMenu: null,
              floorDrag: PlanFloorDrag.band,
            ));
    hall.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, -3300, -2250));
    final camera = hall.camera;
    final ctx = s.toolContext;
    ToolPointerEvent ev(ui.Offset p) => ToolPointerEvent(
          screen: p,
          world: camera.value.screenToWorld(Vector2(p.dx, p.dy)),
          pointer: 1,
          buttons: kPrimaryButton,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: 6 / camera.value.scale,
          kind: PointerDeviceKind.mouse,
        );
    const press = ui.Offset(900, 120);
    expect(s.picker.pick(ev(press).world), isNull,
        reason: 'premise: the press is on the floor');
    expect(s.picker.candidates.where((c) => c.unit.generated), hasLength(500),
        reason: 'premise: the hall');
    s.tool.onPointerDown(ev(press), ctx);
    s.tool.onPointerMove(ev(const ui.Offset(1100, 300)), ctx);
    expect(s.tool.phase, ToolPhase.dragging, reason: 'premise: a live band');
    // The controller refreshes its selected labels and group on every
    // selection change (O(units)); a band changes it at its up only.
    var notified = 0;
    void count() => notified++;
    s.selection.addListener(count);
    addTearDown(() => s.selection.removeListener(count));
    await bandFrames(m, s.tool, ctx, camera, press, ev);
    expect(notified, 0,
        reason: 'premise: no selection change, so no controller refresh, '
            'per frame');
  });
}
