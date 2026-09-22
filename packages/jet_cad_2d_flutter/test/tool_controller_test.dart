import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter/widgets.dart' show Canvas, KeyEventResult, Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:jet_cad_2d_flutter/src/viewport_transform.dart';

import 'support/selection_fixture.dart';

class _CountingTool extends Tool {
  _CountingTool(this.name, {this.notifyOnCancel = false});

  @override
  final String name;

  @override
  ToolPhase phase = ToolPhase.idle;

  int cancelCount = 0;

  /// When set, `cancel` notifies its own listeners in addition to
  /// incrementing [cancelCount] — the shape of a real tool that clears its
  /// own overlay state on cancel (Task 5's `SelectTool`). `ToolController`
  /// must not let this leak into a second controller notification.
  final bool notifyOnCancel;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}

  @override
  void onPointerExit(ToolContext ctx) {}

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;

  @override
  void cancel(ToolContext ctx) {
    cancelCount++;
    if (notifyOnCancel) notifyListeners();
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}

  /// `notifyListeners` is `@protected` on `ChangeNotifier`; this exposes it
  /// so the test can simulate the tool announcing a change of its own.
  void ping() => notifyListeners();
}

void main() {
  test(
      'ToolController forwards the active tool, swaps on activate, and '
      'stops forwarding the outgoing tool', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(1.5, const Offset(40, -25));
    final ctx = ToolContext(
      document: doc,
      index: index,
      camera: camera,
      selection: selection,
    );

    final a = _CountingTool('a');
    final b = _CountingTool('b');
    final controller = ToolController(initial: a, context: ctx);

    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    expect(controller.active, same(a));

    a.ping();
    expect(notifyCount, 1,
        reason: 'the initial tool is listened to from construction');

    controller.activate(b);
    expect(a.cancelCount, 1, reason: 'the outgoing tool is cancelled');
    expect(controller.active, same(b));
    expect(notifyCount, 2, reason: 'activate notifies exactly once');

    a.ping();
    expect(notifyCount, 2, reason: 'the outgoing tool is no longer forwarded');

    b.ping();
    expect(notifyCount, 3, reason: 'the new active tool is forwarded');

    // Activating the already-active tool is a no-op: no cancel, no notify.
    controller.activate(b);
    expect(b.cancelCount, 0);
    expect(notifyCount, 3);

    controller.dispose();
    expect(() => b.ping(), returnsNormally,
        reason: 'dispose removes the active listener; the tool itself '
            'still works, it is simply not forwarded any more');
    expect(notifyCount, 3);
  });

  test(
      'activate notifies exactly once even when the outgoing tool notifies '
      'its own listeners from cancel', () {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final camera = cameraAt(1.5, const Offset(40, -25));
    final ctx = ToolContext(
      document: doc,
      index: index,
      camera: camera,
      selection: selection,
    );

    final a = _CountingTool('a', notifyOnCancel: true);
    final b = _CountingTool('b');
    final controller = ToolController(initial: a, context: ctx);

    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    final before = notifyCount;
    controller.activate(b);

    expect(a.cancelCount, 1);
    expect(controller.active, same(b));
    expect(notifyCount, before + 1,
        reason: 'cancel notifying its own (by-then-unhooked) listeners must '
            'not add a second controller notification for one activate '
            'call');
  });
}
