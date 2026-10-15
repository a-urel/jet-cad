// Spec P4 "The failure boundary", the tool rows: every armed tool is wrapped
// in a guarding Tool decorator. A kit tool's event that throws is a
// diagnostic, a cancel and plan.select; a refusal (PlanLocked, or E2's
// DanglingReferenceError) only cancels the gesture and shows the hint; a
// paint that throws is skipped and the tool cancelled after the frame; a
// generic tool's own error is rethrown as today. The decorator forwards
// what it does not guard.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A tool whose members throw [errors] by name; it counts its cancels and
/// paints, and reports [midShape] and [toolPhase].
final class _Inner extends Tool {
  final Map<String, Object> errors = {};
  int cancels = 0;
  int paints = 0;
  bool midShape = true;
  ToolPhase toolPhase = ToolPhase.dragging;

  void _maybe(String member) {
    final e = errors[member];
    if (e != null) throw e;
  }

  void ping() => notifyListeners();

  @override
  String get name => 'inner';
  @override
  ToolPhase get phase {
    _maybe('phase');
    return toolPhase;
  }

  @override
  bool get isMidShape {
    _maybe('isMidShape');
    return midShape;
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) =>
      _maybe('onPointerDown');
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) =>
      _maybe('onPointerMove');
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) =>
      _maybe('onPointerUp');
  @override
  void onPointerExit(ToolContext ctx) => _maybe('onPointerExit');
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    _maybe('onKey');
    return KeyEventResult.handled;
  }

  @override
  void cancel(ToolContext ctx) => cancels++;
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    paints++;
    _maybe('paintOverlay');
  }
}

final class _Rig {
  _Rig({this.kitId = 'box', this.toolId = 'box.stamp', this.refusal}) {
    final d = DraftDocument.empty();
    index = SpatialIndex(d);
    selection = SelectionController(d);
    ctx = ToolContext(
        document: d,
        index: index,
        camera: CameraController(ViewportTransform(
            worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300))),
        selection: selection);
    tool = GuardedTool(
        inner: inner,
        kitId: kitId,
        toolId: toolId,
        log: log,
        lockHint: hint,
        onFailed: () => failed++,
        refusal: refusal);
  }

  final String kitId;
  final String toolId;
  final bool Function(Object error)? refusal;
  final _Inner inner = _Inner();
  final DiagnosticsLog log = DiagnosticsLog();
  final ValueNotifier<bool> hint = ValueNotifier(false);
  late final SpatialIndex index;
  late final SelectionController selection;
  late final ToolContext ctx;
  late final GuardedTool tool;
  int failed = 0;

  void dispose() {
    tool.dispose();
    index.dispose();
    selection.dispose();
    hint.dispose();
    log.dispose();
  }
}

final ToolPointerEvent down = ToolPointerEvent(
    screen: const Offset(410.5, 290.25),
    world: Vector2(84.0, 78.0),
    pointer: 1,
    buttons: 1,
    shift: false,
    control: false,
    meta: false,
    alt: false,
    pickRadiusWorld: 48);

const KeyDownEvent keyR = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyR,
    logicalKey: LogicalKeyboardKey.keyR,
    timeStamp: Duration.zero);

/// Each event member, called on [t] with [ctx].
final Map<String, void Function(Tool t, ToolContext ctx)> events = {
  'onPointerDown': (t, ctx) => t.onPointerDown(down, ctx),
  'onPointerMove': (t, ctx) => t.onPointerMove(down, ctx),
  'onPointerUp': (t, ctx) => t.onPointerUp(down, ctx),
  'onPointerExit': (t, ctx) => t.onPointerExit(ctx),
  'onKey': (t, ctx) => t.onKey(keyR, ctx),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'F-T1 a kit tool\'s event that throws: no exception, one diagnostic '
      'naming the tool, the tool cancelled, plan.select asked for', () {
    for (final MapEntry(key: member, value: call) in events.entries) {
      final r = _Rig();
      r.inner.errors[member] = StateError('boom in $member');
      // M-F-T1-<member>: that member's `try` removed in GuardedTool.
      expect(() => call(r.tool, r.ctx), returnsNormally, reason: member);
      final d = r.log.entries.value;
      expect(d, hasLength(1), reason: member);
      expect((
        d.single.kitId,
        d.single.subject,
        d.single.code
      ), (
        'box',
        'box.stamp',
        KitDiagnosticCode.hookFailed
      ), reason: member);
      expect(r.inner.cancels, 1, reason: member);
      expect(r.failed, 1, reason: member);
      expect(r.hint.value, isFalse, reason: member);
      r.dispose();
    }
  });

  test(
      'F-T2 a refusal (PlanLocked, or E2\'s DanglingReferenceError) shows '
      'the hint and cancels the gesture: no diagnostic, the tool stays', () {
    for (final refusal in <Object>[
      const PlanLocked(),
      const DanglingReferenceError(Handle(4101), Handle(4102)),
    ]) {
      final r = _Rig();
      r.inner.errors['onPointerUp'] = refusal;
      // M-F-T2: the refusal branch of `_failed` removed: the refusal is
      // then a kit failure (a diagnostic, plan.select).
      r.tool.onPointerUp(down, r.ctx);
      expect(r.hint.value, isTrue, reason: '$refusal');
      expect(r.inner.cancels, 1, reason: '$refusal');
      expect(r.failed, 0, reason: '$refusal');
      expect(r.log.entries.value, isEmpty, reason: '$refusal');
      r.dispose();
    }
  });

  test(
      'F-T3 a KitHookFailure reaching a generic tool is the kit\'s: the '
      'diagnostic names the failing type, the tool is cancelled', () {
    final r = _Rig(kitId: 'plan', toolId: 'plan.line');
    r.inner.errors['onPointerUp'] =
        const KitHookFailure('ring', 'ring.disc', 'generate', HookError());
    r.tool.onPointerUp(down, r.ctx);
    final d = r.log.entries.value.single;
    // M-F-T3: the KitHookFailure attributed to the tool (kitId, toolId).
    expect((d.kitId, d.subject), ('ring', 'ring.disc'));
    expect(r.inner.cancels, 1);
    expect(r.failed, 1);
    r.dispose();
  });

  test('F-T4 a generic tool\'s own error is rethrown, as today', () {
    final r = _Rig(kitId: 'plan', toolId: 'plan.select');
    r.inner.errors['onPointerUp'] = StateError('a refused edit');
    // M-F-T4: `_failed` treating every tool as a kit's swallows it.
    expect(() => r.tool.onPointerUp(down, r.ctx), throwsStateError);
    expect(r.failed, 0);
    expect(r.log.entries.value, isEmpty);
    r.dispose();
  });

  test(
      'F-T7 plan.select\'s refusal (spec 3a C1.8 (2)) is the drop\'s alone: '
      'an ArgumentError from any other event is rethrown, as F-T4; the '
      'same error at the drop cancels the gesture, with no diagnostic', () {
    for (final MapEntry(key: member, value: call) in events.entries) {
      final r = _Rig(
          kitId: 'plan',
          toolId: 'plan.select',
          refusal: (error) => error is ArgumentError);
      r.inner.errors[member] =
          ArgumentError.value(3.5, 'side', 'refused in $member');
      if (member == 'onPointerUp') {
        // M-F-T7b: `onPointerUp` without `drop: true`: the drop's refusal
        // is rethrown.
        expect(() => call(r.tool, r.ctx), returnsNormally, reason: member);
        expect(r.inner.cancels, 1, reason: member);
      } else {
        // M-F-T7a: `_failed` consulting `refusal` for every event: the
        // error is cancelled quietly.
        expect(() => call(r.tool, r.ctx), throwsArgumentError, reason: member);
        expect(r.inner.cancels, 0, reason: member);
      }
      expect(r.failed, 0, reason: member);
      expect(r.log.entries.value, isEmpty, reason: member);
      expect(r.hint.value, isFalse, reason: member);
      r.dispose();
    }
  });

  testWidgets(
      'F-T5 a kit tool\'s paint that throws is skipped; the tool is '
      'cancelled after the frame, and not painted again', (tester) async {
    final r = _Rig();
    addTearDown(r.dispose);
    r.inner.errors['paintOverlay'] = StateError('paint');
    final canvas = Canvas(ui.PictureRecorder());
    final camera = ViewportTransform(
        worldToScreenMatrix: Transform2(0.125, 0, 0, -0.125, 400, 300));
    r.tool
        .paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    // M-F-T5: `onFailed` called at once instead of after the frame.
    expect(r.failed, 0, reason: 'not inside the paint');
    r.tool
        .paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    expect(r.inner.paints, 1, reason: 'a broken overlay is skipped');
    await tester.pump();
    expect(r.failed, 1);
    expect(r.log.entries.value, hasLength(1));
    r.tool.cancel(r.ctx);
    r.inner.errors.clear();
    r.tool
        .paintOverlay(canvas, camera, const Size(800, 600), PaperPalette.light);
    expect(r.inner.paints, 2, reason: 'a cancel clears the broken flag');
  });

  test(
      'F-T6 the decorator forwards phase, isMidShape and notifications; a '
      'kit getter that throws answers the safe default with a diagnostic',
      () async {
    final r = _Rig();
    // M-F-T6a: `isMidShape` answering false without asking the inner.
    expect(r.tool.isMidShape, isTrue);
    expect(r.tool.phase, ToolPhase.dragging);
    var heard = 0;
    r.tool.addListener(() => heard++);
    // M-F-T6b: the constructor without `inner.addListener(_forward)`.
    r.inner.ping();
    expect(heard, 1);
    r.inner.errors['isMidShape'] = StateError('mid');
    expect(r.tool.isMidShape, isFalse);
    r.inner.errors['phase'] = StateError('phase');
    expect(r.tool.phase, ToolPhase.idle);
    expect(identical(r.tool.inner, r.inner), isTrue);
    r.dispose();
    // M-F-T6c: `dispose` without `inner.dispose()`.
    expect(() => r.inner.addListener(() {}), throwsFlutterError,
        reason: 'the decorator owns and disposes its tool');
  });
}

/// A neutral error value for a constructed KitHookFailure.
final class HookError implements Exception {
  const HookError();
}
