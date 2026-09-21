import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

import 'camera_controller.dart';
import 'gesture_policy.dart';

/// Pans and zooms a [CameraController] from pointer input, wrapping the
/// view it drives.
///
/// A `Listener`, not a `GestureDetector`: the events this needs
/// (`onPointerSignal`, `onPointerPanZoomStart/Update`) are `Listener`'s, and
/// the arena a `GestureDetector` joins would have to be fought for nothing.
/// It is a separate widget rather than a `DraftCanvas` feature so a host that
/// drives the camera itself -- the measurement harness -- simply does not
/// use it.
///
/// Which input does what is the spec's D3 table. The desktop trackpad arrives
/// as a `PointerPanZoom*` sequence whose `pan` and `scale` are **cumulative
/// since the gesture began**; `localPanDelta` is the engine's own per-event
/// pan, and `scale` is divided by the running value so three updates of a
/// steady pinch to 1.5 zoom by 1.5, not 1.5^3. The anchor is held where the
/// gesture began, not under the drifting pointer.
class CameraGestureDetector extends StatefulWidget {
  const CameraGestureDetector({
    super.key,
    required this.camera,
    required this.policy,
    required this.child,
  });

  final CameraController camera;
  final GesturePolicy policy;
  final Widget child;

  @override
  State<CameraGestureDetector> createState() => _CameraGestureDetectorState();
}

class _CameraGestureDetectorState extends State<CameraGestureDetector> {
  /// The cumulative `scale` already applied from the gesture in progress.
  ///
  /// Reset when a gesture starts rather than when one ends: a start event is
  /// guaranteed to precede every update, an end event is not guaranteed to
  /// arrive at all.
  double _gestureZoom = 1.0;

  /// Where the trackpad gesture began, in this widget's coordinates.
  Offset _gestureAnchor = Offset.zero;

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _gestureZoom = 1.0;
    _gestureAnchor = event.localPosition;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final camera = widget.camera;
    final delta = event.localPanDelta;
    if (delta != Offset.zero) camera.panBy(delta);
    final scale = event.scale;
    // `zoomAt` ignores a non-positive or non-finite factor, but the running
    // value must not be poisoned by one either.
    if (!scale.isFinite || scale <= 0) return;
    // A two-finger scroll reports scale == 1.0 on every update; zooming by
    // 1.0 would build a transform and notify for nothing (Ruling 01-4).
    if (scale == _gestureZoom) return;
    camera.zoomAt(_gestureAnchor, scale / _gestureZoom);
    _gestureZoom = scale;
  }

  /// The scroll-signal rule, in the spec's order: a modifier held zooms; a
  /// trackpad-kind scroll pans; otherwise the policy decides.
  ///
  /// `PointerScrollEvent` carries no modifier fields, so the keyboard state
  /// is read from [HardwareKeyboard]. On a macOS browser a real ctrl+wheel
  /// reaches here as a plain scroll signal (the engine reserves the DOM
  /// `ctrlKey` for a synthesised pinch when the physical key is up); on a
  /// Windows or Linux browser it arrives as a [PointerScaleEvent] instead.
  /// Cmd+wheel is a plain scroll signal everywhere.
  ///
  /// A [PointerScaleEvent]'s `scale` is per-event -- the engine computes
  /// `exp(-deltaY / 200)` from each DOM event on its own -- so it is applied
  /// raw and **not** divided by the running trackpad value.
  void _onSignal(PointerSignalEvent event) {
    final camera = widget.camera;
    if (event is PointerScaleEvent) {
      camera.zoomAt(event.localPosition, event.scale);
      return;
    }
    if (event is! PointerScrollEvent) return;
    final policy = widget.policy;
    final keyboard = HardwareKeyboard.instance;
    final action = keyboard.isControlPressed || keyboard.isMetaPressed
        ? ScrollSignalAction.zoom
        : event.kind == PointerDeviceKind.trackpad
            ? ScrollSignalAction.pan
            : policy.mouseWheel;
    switch (action) {
      case ScrollSignalAction.zoom:
        // Scroll up is negative dy on every platform Flutter reports.
        camera.zoomAt(
            event.localPosition,
            event.scrollDelta.dy < 0
                ? policy.wheelZoomStep
                : 1 / policy.wheelZoomStep);
      case ScrollSignalAction.pan:
        // `scrollDelta` is content-scroll: positive dy is "scroll down", the
        // content moves up, so the camera pans by the negation.
        camera.panBy(-event.scrollDelta);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        onPointerSignal: _onSignal,
        child: widget.child,
      );
}
