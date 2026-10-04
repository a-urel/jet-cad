import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';

import 'camera_controller.dart';
import 'gesture_policy.dart';

/// Below this span, in screen pixels, two fingers pan but do not zoom
/// (spec 14t T2): a ratio of near-coincident fingers is noise.
const double kPinchMinSpan = 8.0;

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
///
/// **Two fingers** (spec 14t T2) pinch and pan: the two earliest live
/// touches are the pair; each move of either pans by the midpoint's motion
/// and then zooms about the new midpoint by the span's ratio, so the world
/// point under the fingers' midpoint stays under it. A change of pair takes
/// a new baseline and never moves the camera. The interaction layer keeps
/// such a gesture from every tool.
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

  /// The live fingers in the order they went down, and where each is.
  final List<int> _fingers = [];
  final Map<int, Offset> _at = {};

  /// The pair and its last midpoint and span.
  int _p1 = -1, _p2 = -1;
  Offset _focal = Offset.zero;
  double _span = 0;

  void _onDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _fingers.add(event.pointer);
    _at[event.pointer] = event.localPosition;
    _rebase();
  }

  void _onLift(PointerEvent event) {
    if (_at.remove(event.pointer) == null) return;
    _fingers.remove(event.pointer);
    _rebase();
  }

  /// A new pair takes its baseline; the camera does not move.
  void _rebase() {
    if (_fingers.length < 2) {
      _p1 = _p2 = -1;
      return;
    }
    final p1 = _fingers[0], p2 = _fingers[1];
    if (p1 == _p1 && p2 == _p2) return;
    _p1 = p1;
    _p2 = p2;
    final a = _at[p1]!, b = _at[p2]!;
    _focal = (a + b) / 2;
    _span = (a - b).distance;
  }

  /// Pan by the midpoint's motion, then zoom about the new midpoint.
  void _pinch() {
    final a = _at[_p1]!, b = _at[_p2]!;
    final focal = (a + b) / 2;
    final span = (a - b).distance;
    final camera = widget.camera;
    if (focal != _focal) camera.panBy(focal - _focal);
    if (_span >= kPinchMinSpan && span >= kPinchMinSpan && span != _span) {
      camera.zoomAt(focal, span / _span);
    }
    _focal = focal;
    _span = span;
  }

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
        // A horizontal-only signal has no zoom direction; it is not an
        // unmarked zoom-out.
        if (event.scrollDelta.dy == 0) return;
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

  /// A drag with a pan button held pans by the pointer's own delta. Any
  /// other button does nothing here: the left button belongs to selection
  /// (sub-project 02), and leaving it free now is cheaper than unpicking a
  /// learned behaviour later.
  void _onMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      if (!_at.containsKey(event.pointer)) return;
      _at[event.pointer] = event.localPosition;
      if (event.pointer == _p1 || event.pointer == _p2) _pinch();
      return;
    }
    if (event.buttons & widget.policy.panButtons != 0) {
      widget.camera.panBy(event.localDelta);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        onPointerSignal: _onSignal,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onLift,
        onPointerCancel: _onLift,
        child: widget.child,
      );
}
