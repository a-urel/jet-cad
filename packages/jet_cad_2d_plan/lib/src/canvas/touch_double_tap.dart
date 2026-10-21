import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:meta/meta.dart' show internal;

/// A touch double tap ends the active tool's pending shape, as Enter does.
///
/// A phone has no Enter key, and a chain tool (the Wall tool, the
/// Polyline tool) keeps its chain until it is finished. This widget only
/// watches raw pointer events (it joins no gesture arena, so the camera's
/// pan and pinch, the long press and the tool's own taps are untouched) and,
/// for a second quick tap of a pair, sends the tool the same Enter key-down
/// its `onKey` finishes on. Nothing runs with no pending shape, and a mouse
/// or pen never counts: a desktop double click keeps meaning two clicks.
///
/// The rule, by what the user sees: the first tap of the pair is a
/// deliberate point and stays, the chain ends there. The second tap's down
/// finishes the chain before the layer below routes that tap, so the tap
/// cannot add a wall; the tap then starts a lone first point, which is
/// finished again on its lift. The result equals Enter after the first tap.
@internal
class TouchDoubleTapFinish extends StatefulWidget {
  const TouchDoubleTapFinish({
    super.key,
    required this.tools,
    required this.child,
  });

  final ToolController tools;
  final Widget child;

  /// The longest gap between two taps of a pair, and the longest a tap may
  /// press (past it the press is a long press, not a tap).
  static const Duration timeout = Duration(milliseconds: 300);

  /// The shortest gap: a finger cannot lift and land again faster, so two
  /// contacts closer than this (synthetic ones, a jittery sensor) are two
  /// plain taps.
  static const Duration settle = Duration(milliseconds: 20);

  /// How far apart the two taps may land, and how far one may move.
  static const double slop = 40;

  @override
  State<TouchDoubleTapFinish> createState() => _TouchDoubleTapFinishState();
}

class _TouchDoubleTapFinishState extends State<TouchDoubleTapFinish> {
  final Set<int> _touches = {};

  /// Where the last clean tap lifted, until [TouchDoubleTapFinish.timeout]
  /// passes.
  Offset? _lastTap;
  Timer? _gap;

  /// Whether [TouchDoubleTapFinish.settle] has passed since that lift: two
  /// contacts closer in time are not one finger's second tap.
  bool _settled = false;
  Timer? _settling;

  /// The pointer that may still become a tap, where it went down, whether it
  /// is the second of a pair and whether it has stopped being a tap.
  int _candidate = -1;
  Offset _downAt = Offset.zero;
  bool _second = false;
  bool _spoiled = false;
  Timer? _press;

  void _forget() {
    _gap?.cancel();
    _gap = null;
    _settling?.cancel();
    _settling = null;
    _lastTap = null;
    _press?.cancel();
    _press = null;
    _candidate = -1;
    _second = false;
  }

  /// Enter, through the tool's own key path, only while a shape is pending.
  bool _end() {
    final tool = widget.tools.active;
    if (!tool.isMidShape) return false;
    tool.onKey(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      ),
      widget.tools.context,
    );
    return true;
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _touches.add(e.pointer);
    if (_touches.length > 1) {
      _forget();
      return;
    }
    _candidate = e.pointer;
    _downAt = e.localPosition;
    _spoiled = false;
    _press?.cancel();
    _press = Timer(TouchDoubleTapFinish.timeout, () => _spoiled = true);
    final last = _lastTap;
    _second = last != null &&
        _settled &&
        (e.localPosition - last).distance <= TouchDoubleTapFinish.slop;
    _second = _second && _end();
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _candidate) return;
    if ((e.localPosition - _downAt).distance > TouchDoubleTapFinish.slop) {
      _spoiled = true;
    }
  }

  void _up(PointerUpEvent e) {
    if (!_touches.remove(e.pointer) || e.pointer != _candidate) return;
    final tap = !_spoiled;
    final second = _second;
    _forget();
    if (!tap) return;
    if (second) {
      // The layer below has routed this tap by now: a lone first point.
      _end();
      return;
    }
    _lastTap = e.localPosition;
    _gap = Timer(TouchDoubleTapFinish.timeout, () => _lastTap = null);
    _settled = false;
    _settling = Timer(TouchDoubleTapFinish.settle, () => _settled = true);
  }

  void _cancel(PointerCancelEvent e) {
    _touches.remove(e.pointer);
    _forget();
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: widget.child,
      );
}
