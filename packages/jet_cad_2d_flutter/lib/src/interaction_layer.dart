import 'dart:async';

import 'package:flutter/gestures.dart'
    show
        PointerDeviceKind,
        PointerExitEvent,
        PointerHoverEvent,
        kMiddleMouseButton,
        kPressTimeout,
        kPrimaryButton,
        kTouchSlop;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'input_claim.dart';
import 'tool.dart';

/// Pick radius in **screen** pixels (spec D7).
///
/// A tool never sees this constant: [ToolPointerEvent.pickRadiusWorld] is it
/// divided by the camera's scale, per event, so a 6 px reach on screen stays
/// 6 px on screen at any zoom. It lives here rather than in `select_tool.dart`
/// because this is the one place that performs the conversion; the tool and
/// its tests import it back.
const double kPickRadiusPixels = 6.0;

/// How far a fingertip's miss may reach, in screen pixels (spec 14t R-3): a
/// 48 px target.
const double kTouchPickRadiusPixels = 24.0;

/// How long a finger is held back before a [TouchPress.press] tool sees its
/// down (spec 14t T3): long enough for a pinch's second finger to land.
const Duration kTouchHoldBack = kPressTimeout;

/// Turns Flutter's pointer and key events into calls on the active [Tool].
///
/// A `Listener`, not a `GestureDetector`, for the same reason
/// `CameraGestureDetector` is one: there is no arena to win here, and the
/// button masks the routing table is written against are `Listener`'s.
///
/// Two layers read the same pointer stream and they agree on one boundary:
/// **any event whose button mask contains the pan button
/// ([kMiddleMouseButton]) is the camera's**, and is ignored here outright —
/// including a primary+middle mask, and including a move in which the primary
/// disappears while the middle is held. That last case is why the rule is
/// checked first: it means a middle press during a drag does not silently end
/// the drag as a synthesised up. The pointer's own [PointerUpEvent], whose
/// mask is empty, is what ends it.
///
/// Everything else is a small state machine over one active pointer. A
/// primary down with no pointer active claims it; a move from that pointer
/// with the primary still set is a move; a move in which the primary
/// disappears, or an up, ends it. A move in which the primary *appears* on a
/// pointer while none is active is treated as a down, because a pointer that
/// was already on screen when the button went down reaches a `Listener` as a
/// move, not as a down. A hover carries `buttons == 0` and is a move with no
/// press behind it, and `MouseRegion.onExit` reaches the tool only while no
/// pointer is active — a captured pointer's drag is allowed to leave the box
/// and come back, and ends on its own up.
///
/// **Touch** (spec 14t T3) runs in sessions, from a finger down while no
/// finger is down until none is. The first finger is **held back**: a
/// [TouchPress.press] tool sees its down when it lifts, leaves the slop or
/// has been held for [kTouchHoldBack]; a [TouchPress.lift] tool sees it
/// only when it lifts, at the lift's position, and its moves past the slop
/// as hovers. A second finger makes the session **multi**: a held finger is
/// dropped unseen, a routed one is released (its tool cancelled unless
/// idle), and no touch reaches a tool until every finger lifts — the
/// pinch is `CameraGestureDetector`'s. A finger's move never becomes a
/// down, a touch hover is never routed, and the tool hears
/// [Tool.onPointerExit] when a session goes multi or ends.
///
/// **Claims** (host embedding API spec G-5): a pointer whose down landed on
/// an [InputClaim] inside this layer reaches no tool, from that down through
/// its up or cancel, whatever its kind or buttons: it starts no gesture,
/// joins no touch session (a finger on a claim is no second finger) and
/// ends none. A hover that lands on a claim is an exit for the tool, as if
/// the pointer had left the canvas.
class InteractionLayer extends StatefulWidget {
  const InteractionLayer({
    super.key,
    required this.tools,
    required this.child,
  });

  /// The controller whose `active` tool receives the events and whose
  /// `context` carries the document, index, camera and selection.
  final ToolController tools;

  final Widget child;

  @override
  State<InteractionLayer> createState() => _InteractionLayerState();
}

class _InteractionLayerState extends State<InteractionLayer> {
  final FocusNode _focus = FocusNode(debugLabel: 'InteractionLayer');

  /// The pointer the tool is following, or -1 when none is.
  int _activePointer = -1;

  /// The button mask of the last event routed for [_activePointer]. A
  /// `PointerMoveEvent` carries the *current* mask, so "the primary was
  /// released" is only visible as a change against this.
  int _lastButtons = 0;

  ToolContext get _ctx => widget.tools.context;
  Tool get _tool => widget.tools.active;

  /// The active tool's cursor, mirrored for the `MouseRegion`'s builder.
  ///
  /// Not a builder on [widget.tools] itself: [_release] runs in
  /// [deactivate], where cancelling a live drag makes the tool notify, and a
  /// rebuild request from this subtree while it leaves the tree asserts
  /// (`markNeedsBuild` during build). [_leaving] mutes the mirror from then
  /// on; [activate] unmutes it.
  late final ValueNotifier<MouseCursor> _cursor =
      ValueNotifier<MouseCursor>(_tool.cursor);
  bool _leaving = false;

  void _onTools() {
    // A finger held for the outgoing tool is not the new tool's (R-9b).
    if (!identical(_tool, _lastTool)) {
      _lastTool = _tool;
      _dropHeld();
    }
    if (!_leaving) _cursor.value = _tool.cursor;
  }

  /// The tool [_onTools] last saw active.
  late Tool _lastTool;

  /// The touch session (spec 14t T3): the live fingers, whether a second
  /// finger has been down, and the first finger while it is held back.
  final Set<int> _touches = {};
  bool _multi = false;
  PointerDownEvent? _held;
  Timer? _holdTimer;

  /// A [TouchPress.lift] finger past the slop: its moves are hovers.
  bool _aiming = false;

  /// The last hover landed on an [InputClaim], and the tool heard the exit
  /// it stands for; cleared by the next hover or down the tool hears.
  bool _overClaim = false;

  @override
  void initState() {
    super.initState();
    _lastTool = _tool;
    widget.tools.addListener(_onTools);
  }

  @override
  void didUpdateWidget(InteractionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.tools, widget.tools)) return;
    _dropHeld();
    oldWidget.tools.removeListener(_onTools);
    widget.tools.addListener(_onTools);
    _onTools();
  }

  /// Resolves one pointer sample into both spaces and snapshots the modifier
  /// state, so a tool never inverts the camera or reads the keyboard itself.
  ToolPointerEvent _wrap(PointerEvent e) =>
      _event(e.localPosition, e.pointer, e.buttons, e.kind, e.timeStamp);

  /// One sample at [local], through the camera as it is now (R-9d),
  /// stamped [timeStamp]: the raw pointer event's time (spec E-2).
  ToolPointerEvent _event(Offset local, int pointer, int buttons,
      PointerDeviceKind kind, Duration timeStamp) {
    final cam = _ctx.camera.value;
    final keyboard = HardwareKeyboard.instance;
    final touch = kind == PointerDeviceKind.touch;
    return ToolPointerEvent(
      screen: local,
      world: cam.screenToWorld(Vector2(local.dx, local.dy)),
      pointer: pointer,
      buttons: buttons,
      shift: keyboard.isShiftPressed,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      pickRadiusWorld: kPickRadiusPixels / cam.scale,
      kind: kind,
      reachRadiusWorld: touch ? kTouchPickRadiusPixels / cam.scale : null,
      timeStamp: timeStamp,
    );
  }

  static bool _isTouch(PointerEvent e) => e.kind == PointerDeviceKind.touch;

  // ---- Touch (spec 14t T3) ------------------------------------------------

  void _touchDown(PointerDownEvent e) {
    final first = _touches.isEmpty;
    _touches.add(e.pointer);
    if (_multi) return;
    if (first) {
      if (_activePointer != -1) {
        // A precise pointer holds the layer: this session reaches no tool.
        _multi = true;
        return;
      }
      // The held finger claims the layer (R-9a).
      _held = e;
      _aiming = false;
      _activePointer = e.pointer;
      _lastButtons = e.buttons;
      if (_tool.touchPress == TouchPress.press) {
        _holdTimer = Timer(kTouchHoldBack, _routeHeld);
      }
      return;
    }
    _goMulti();
  }

  /// A second finger: the gesture is the camera's until every finger lifts.
  void _goMulti() {
    _multi = true;
    if (_held != null) {
      _dropHeld();
    } else if (_activePointer != -1 && _touches.contains(_activePointer)) {
      _activePointer = -1;
      _lastButtons = 0;
      // A drawing tool's pending shape survives a pinch (R-8): only a tool
      // part-way through a press is cancelled.
      if (_tool.phase != ToolPhase.idle) _tool.cancel(_ctx);
    }
    // Not while a precise pointer holds the layer: an exit would cancel
    // its drag (review F-1).
    if (_activePointer == -1) _tool.onPointerExit(_ctx);
  }

  /// The held finger is routed as a down at its own position (press mode).
  void _routeHeld() {
    _holdTimer?.cancel();
    _holdTimer = null;
    final held = _held;
    if (held == null) return;
    _held = null;
    _focus.requestFocus();
    _tool.onPointerDown(_wrap(held), _ctx);
  }

  /// The held finger, never routed, is forgotten; the layer is free.
  void _dropHeld() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_held == null) return;
    _held = null;
    _aiming = false;
    _activePointer = -1;
    _lastButtons = 0;
  }

  void _touchMove(PointerMoveEvent e) {
    if (_multi) return;
    final held = _held;
    if (held != null) {
      if (e.pointer != held.pointer) return;
      if (!_aiming &&
          (e.localPosition - held.localPosition).distance <= kTouchSlop) {
        return;
      }
      if (_tool.touchPress == TouchPress.press) {
        _routeHeld();
        _lastButtons = e.buttons;
        _tool.onPointerMove(_wrap(e), _ctx);
      } else {
        // Aiming: a hover the tool can show, never a press.
        _aiming = true;
        _tool.onPointerMove(
            _event(e.localPosition, e.pointer, 0, e.kind, e.timeStamp), _ctx);
      }
      return;
    }
    // No promotion for a finger (TS-6): only the routed one moves.
    if (e.pointer != _activePointer) return;
    _lastButtons = e.buttons;
    _tool.onPointerMove(_wrap(e), _ctx);
  }

  void _touchUp(PointerUpEvent e) {
    _touches.remove(e.pointer);
    if (!_multi) {
      final held = _held;
      if (held != null && e.pointer == held.pointer) {
        final press = _tool.touchPress == TouchPress.press;
        _holdTimer?.cancel();
        _holdTimer = null;
        _held = null;
        _aiming = false;
        final size = context.size;
        if (!press &&
            size != null &&
            !(Offset.zero & size).contains(e.localPosition)) {
          // A lift-mode finger lifted off the canvas places nothing there
          // (review F-7): the press is withdrawn.
          _activePointer = -1;
          _lastButtons = 0;
          if (_touches.isEmpty) _endSession();
          return;
        }
        _focus.requestFocus();
        // A tap: press mode at the down's position, lift mode at the lift's;
        // either way stamped with the raw down's time (spec E-2).
        _tool.onPointerDown(
            press
                ? _wrap(held)
                : _event(e.localPosition, e.pointer, held.buttons, e.kind,
                    held.timeStamp),
            _ctx);
        _activePointer = -1;
        _lastButtons = 0;
        _tool.onPointerUp(_wrap(e), _ctx);
      } else if (e.pointer == _activePointer) {
        _activePointer = -1;
        _lastButtons = 0;
        _tool.onPointerUp(_wrap(e), _ctx);
      }
    }
    if (_touches.isEmpty) _endSession();
  }

  void _touchCancel(PointerCancelEvent e) {
    _touches.remove(e.pointer);
    if (!_multi) {
      if (_held?.pointer == e.pointer) {
        _dropHeld();
      } else if (e.pointer == _activePointer) {
        _activePointer = -1;
        _lastButtons = 0;
        _tool.cancel(_ctx);
      }
    }
    if (_touches.isEmpty) _endSession();
  }

  /// The last finger lifted: touch has no hover, so the tool hears an exit
  /// (R-10).
  void _endSession() {
    _multi = false;
    _dropHeld();
    // Not while a precise pointer holds the layer: an exit would cancel
    // its drag (review F-1).
    if (_activePointer == -1) _tool.onPointerExit(_ctx);
  }

  /// The whole session forgotten (R-9b): the layer leaves the tree.
  void _clearTouches() {
    _dropHeld();
    _touches.clear();
    _multi = false;
  }

  bool _cameraOwned(int buttons) => buttons & kMiddleMouseButton != 0;

  void _onDown(PointerDownEvent e) {
    // A claimed pointer is the claim's, from this down to its up (G-5).
    if (InputClaim.claimed(e)) return;
    _overClaim = false;
    if (_isTouch(e)) return _touchDown(e);
    // No precise pointer while a touch session runs (R-9a).
    if (_cameraOwned(e.buttons) ||
        _activePointer != -1 ||
        _touches.isNotEmpty) {
      return;
    }
    if (e.buttons & kPrimaryButton == 0) return;
    _focus.requestFocus();
    _activePointer = e.pointer;
    _lastButtons = e.buttons;
    _tool.onPointerDown(_wrap(e), _ctx);
  }

  void _onMove(PointerMoveEvent e) {
    if (InputClaim.claimed(e)) return;
    if (_isTouch(e)) return _touchMove(e);
    if (_cameraOwned(e.buttons)) return;
    final hadPrimary = _lastButtons & kPrimaryButton != 0;
    final hasPrimary = e.buttons & kPrimaryButton != 0;
    if (e.pointer == _activePointer) {
      _lastButtons = e.buttons;
      if (hadPrimary && !hasPrimary) {
        _activePointer = -1;
        _tool.onPointerUp(_wrap(e), _ctx);
      } else {
        _tool.onPointerMove(_wrap(e), _ctx);
      }
      return;
    }
    if (_activePointer == -1 && hasPrimary && _touches.isEmpty) {
      // Treated as a down in every respect, focus included.
      _focus.requestFocus();
      _activePointer = e.pointer;
      _lastButtons = e.buttons;
      _tool.onPointerDown(_wrap(e), _ctx);
    }
  }

  void _onUp(PointerUpEvent e) {
    if (InputClaim.claimed(e)) return;
    if (_isTouch(e)) return _touchUp(e);
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.onPointerUp(_wrap(e), _ctx);
  }

  void _onCancel(PointerCancelEvent e) {
    if (InputClaim.claimed(e)) return;
    if (_isTouch(e)) return _touchCancel(e);
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.cancel(_ctx);
  }

  void _onHover(PointerHoverEvent e) {
    // A finger has no hover; the web sends one after every lift (TS-3).
    if (_isTouch(e) || _activePointer != -1 || _touches.isNotEmpty) return;
    // Over a claim the pointer is not over the canvas (G-5): one exit.
    if (InputClaim.claimed(e)) {
      if (_overClaim) return;
      _overClaim = true;
      _tool.onPointerExit(_ctx);
      return;
    }
    _overClaim = false;
    _tool.onPointerMove(_wrap(e), _ctx);
  }

  /// Exit is a hover statement, so it is only a statement while nothing is
  /// pressed. A pointer that went down inside the layer is **captured**: its
  /// moves and its up keep arriving wherever it goes, and the gesture ends on
  /// that up. Handing the exit to the tool anyway would drop a live band the
  /// moment the drag crossed the layer's edge — which is precisely the drag
  /// that wants to reach past it. [SelectTool.onPointerExit] is left cancelling
  /// a drag, for a future caller that means it.
  void _onExit(PointerExitEvent e) {
    if (_activePointer != -1) return;
    _tool.onPointerExit(_ctx);
  }

  /// Both halves are idempotent — `setHover(null)` on a null hover and
  /// `cancel` on an idle tool each return before notifying — so running this
  /// on `deactivate` *and* on `dispose` costs two early returns and covers
  /// the case where the layer leaves the tree without being disposed.
  void _release() {
    _leaving = true;
    _clearTouches();
    _ctx.selection.setHover(null);
    _tool.cancel(_ctx);
  }

  @override
  void deactivate() {
    _release();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
    _onTools();
  }

  @override
  void dispose() {
    _release();
    widget.tools.removeListener(_onTools);
    _cursor.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        // Spec 03 D5: a cursor is a widget parameter, so it needs a
        // rebuild. Only the MouseRegion is rebuilt, and only when the tool
        // (or a swap) changes the cursor; the Listener subtree is the cached
        // child.
        child: ValueListenableBuilder<MouseCursor>(
          valueListenable: _cursor,
          builder: (context, cursor, child) => MouseRegion(
            cursor: cursor,
            onExit: _onExit,
            child: child,
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            onPointerHover: _onHover,
            child: widget.child,
          ),
        ),
      );
}
