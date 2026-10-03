// The selection mode's tool (spec 14c S3, S4, S8, R-1, R-5 to R-7): tap a
// table to select it, long press to add or remove one, drag to move the
// selected tables for the service, drag the floor to pan.
import 'dart:async';
import 'dart:ui' show Canvas, Offset, Size;

import 'package:flutter/gestures.dart'
    show kLongPressTimeout, kPrimaryButton, kTouchSlop;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'table_picker.dart';

/// What the tool tells its host, read at each call (R-5): a rebuilt host
/// closure is never stale.
typedef ServiceCallbacks = ({
  void Function(String number)? onTableTap,
  void Function()? onLayoutChanged,
});

enum _Gesture { none, pressed, dragging, panning, spent }

/// The selection mode's tool (S3). One per service view; disposed with it.
class TableSelectTool extends Tool {
  TableSelectTool({required this.picker, required this.callbacks});

  final TablePicker picker;
  final ServiceCallbacks Function() callbacks;

  _Gesture _gesture = _Gesture.none;
  int _pointer = -1;
  Offset _pressScreen = Offset.zero;
  Offset _lastScreen = Offset.zero;
  final Vector2 _pressWorld = Vector2.zero();
  PickCandidate? _hit;
  bool _toggle = false;
  Timer? _timer;

  /// The drag's translation, in world units.
  double _dx = 0, _dy = 0;

  /// The tables a drag moves: the selection when it began.
  List<Handle> _moving = const [];

  @override
  String get name => 'Tables';

  /// A down only classifies a press and `cancel` executes nothing, so a
  /// finger reaches this tool after the hold-back (spec 14t R-1).
  @override
  TouchPress get touchPress => TouchPress.press;

  @override
  ToolPhase get phase => switch (_gesture) {
        _Gesture.none => ToolPhase.idle,
        _Gesture.pressed || _Gesture.spent => ToolPhase.pressed,
        _Gesture.dragging || _Gesture.panning => ToolPhase.dragging,
      };

  /// The outlines follow the drag (F-2).
  @override
  Transform2? get selectionPreviewTransform =>
      _gesture == _Gesture.dragging ? Transform2.translation(_dx, _dy) : null;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton == 0 || _gesture != _Gesture.none) return;
    _pointer = e.pointer;
    _pressScreen = e.screen;
    _lastScreen = e.screen;
    _pressWorld.setFrom(e.world);
    // A finger that misses every top reaches the nearest within 24 px
    // (spec 14t R-11); a mouse picks by containment only.
    _hit = picker.pick(e.world, reach: e.isTouch ? e.reachRadiusWorld : 0);
    _toggle = e.shift || e.control || e.meta;
    _gesture = _Gesture.pressed;
    _dx = _dy = 0;
    final hit = _hit;
    if (hit != null && !hit.locked) {
      // A finger's down arrives kTouchHoldBack after it touched, so the
      // long press still falls 500 ms from contact (spec 14t T5, R-9f).
      _timer = Timer(
          e.isTouch ? kLongPressTimeout - kTouchHoldBack : kLongPressTimeout,
          () => _longPress(ctx));
    }
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    // A hover (no button) is not a gesture (R-6).
    if (e.pointer != _pointer || e.buttons & kPrimaryButton == 0) return;
    switch (_gesture) {
      case _Gesture.none || _Gesture.spent:
        return;
      case _Gesture.pressed:
        if ((e.screen - _pressScreen).distance <= kTouchSlop) return;
        _timer?.cancel();
        _timer = null;
        final hit = _hit;
        if (hit == null) {
          _gesture = _Gesture.panning;
        } else if (hit.locked) {
          // A locked table is tapped only (R-1): no move, no pan.
          _gesture = _Gesture.spent;
          notifyListeners();
          return;
        } else {
          final key = SelectionKey.root(hit.table.instance);
          if (!ctx.selection.keys.contains(key)) ctx.selection.replace([key]);
          _moving = [
            for (final k in ctx.selection.keys)
              if (k.chain.isEmpty) k.target
          ]..sort((a, b) => a.value.compareTo(b.value));
          _gesture = _Gesture.dragging;
        }
        _drag(e, ctx);
      case _Gesture.dragging || _Gesture.panning:
        _drag(e, ctx);
    }
  }

  void _drag(ToolPointerEvent e, ToolContext ctx) {
    if (_gesture == _Gesture.panning) {
      ctx.camera.panBy(e.screen - _lastScreen);
    } else {
      _dx = e.world.x - _pressWorld.x;
      _dy = e.world.y - _pressWorld.y;
    }
    _lastScreen = e.screen;
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_gesture) {
      case _Gesture.pressed:
        _tap(ctx);
      case _Gesture.dragging:
        _move(ctx);
      case _Gesture.none || _Gesture.panning || _Gesture.spent:
        break;
    }
    _reset();
    notifyListeners();
  }

  /// A tap (S3): a table alone, or toggled with Shift or Ctrl/Cmd; empty
  /// floor clears, unless a modifier is held (R-6).
  void _tap(ToolContext ctx) {
    final hit = _hit;
    if (hit == null) {
      if (!_toggle) ctx.selection.clear();
      return;
    }
    if (!hit.locked) {
      final key = SelectionKey.root(hit.table.instance);
      if (_toggle) {
        ctx.selection.toggle([key]);
      } else {
        ctx.selection.replace([key]);
      }
    }
    final number = hit.table.number;
    if (number != null) callbacks().onTableTap?.call(number);
  }

  /// The drag's one step (D16): each moved table translated, as it is now,
  /// and only if it is still live (R-6). Nothing for a zero translation.
  void _move(ToolContext ctx) {
    if (_dx == 0 && _dy == 0) return;
    final t = Transform2.translation(_dx, _dy);
    final commands = <DraftCommand>[
      for (final h in _moving)
        if (ctx.document.tree[h] case final InstanceNode node)
          TransformNodeCommand(h, t.multiply(node.transform)),
    ];
    if (commands.isEmpty) return;
    ctx.execute(CompoundCommand(commands, label: 'Move'));
    callbacks().onLayoutChanged?.call();
  }

  /// A long press (decision 9): the table toggled; the gesture is spent, so
  /// moves and the up do nothing, and no tap is reported (R-6).
  void _longPress(ToolContext ctx) {
    _timer = null;
    final hit = _hit;
    if (_gesture != _Gesture.pressed || hit == null || hit.locked) return;
    ctx.selection.toggle([SelectionKey.root(hit.table.instance)]);
    _gesture = _Gesture.spent;
    notifyListeners();
  }

  @override
  void onPointerExit(ToolContext ctx) {}

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _gesture == _Gesture.none) {
      ctx.selection.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// A pointer cancel, a mode switch, a new copy: the drag is dropped and
  /// nothing is executed (R-5).
  @override
  void cancel(ToolContext ctx) {
    if (_gesture == _Gesture.none && _timer == null) return;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _gesture = _Gesture.none;
    _pointer = -1;
    _hit = null;
    _moving = const [];
    _dx = _dy = 0;
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
