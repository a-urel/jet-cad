import 'package:flutter/gestures.dart'
    show
        PointerExitEvent,
        PointerHoverEvent,
        kMiddleMouseButton,
        kPrimaryButton;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'tool.dart';

/// Pick radius in **screen** pixels (spec D7).
///
/// A tool never sees this constant: [ToolPointerEvent.pickRadiusWorld] is it
/// divided by the camera's scale, per event, so a 6 px reach on screen stays
/// 6 px on screen at any zoom. It lives here rather than in `select_tool.dart`
/// because this is the one place that performs the conversion; the tool and
/// its tests import it back.
const double kPickRadiusPixels = 6.0;

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

  /// Resolves one pointer sample into both spaces and snapshots the modifier
  /// state, so a tool never inverts the camera or reads the keyboard itself.
  ToolPointerEvent _wrap(PointerEvent e) {
    final cam = _ctx.camera.value;
    final local = e.localPosition;
    final keyboard = HardwareKeyboard.instance;
    return ToolPointerEvent(
      screen: local,
      world: cam.screenToWorld(Vector2(local.dx, local.dy)),
      pointer: e.pointer,
      buttons: e.buttons,
      shift: keyboard.isShiftPressed,
      control: keyboard.isControlPressed,
      meta: keyboard.isMetaPressed,
      alt: keyboard.isAltPressed,
      pickRadiusWorld: kPickRadiusPixels / cam.scale,
    );
  }

  bool _cameraOwned(int buttons) => buttons & kMiddleMouseButton != 0;

  void _onDown(PointerDownEvent e) {
    if (_cameraOwned(e.buttons) || _activePointer != -1) return;
    if (e.buttons & kPrimaryButton == 0) return;
    _focus.requestFocus();
    _activePointer = e.pointer;
    _lastButtons = e.buttons;
    _tool.onPointerDown(_wrap(e), _ctx);
  }

  void _onMove(PointerMoveEvent e) {
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
    if (_activePointer == -1 && hasPrimary) {
      // Treated as a down in every respect, focus included.
      _focus.requestFocus();
      _activePointer = e.pointer;
      _lastButtons = e.buttons;
      _tool.onPointerDown(_wrap(e), _ctx);
    }
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.onPointerUp(_wrap(e), _ctx);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = -1;
    _lastButtons = 0;
    _tool.cancel(_ctx);
  }

  void _onHover(PointerHoverEvent e) {
    if (_activePointer != -1) return;
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
    _ctx.selection.setHover(null);
    _tool.cancel(_ctx);
  }

  @override
  void deactivate() {
    _release();
    super.deactivate();
  }

  @override
  void dispose() {
    _release();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, event) => _tool.onKey(event, _ctx),
        child: MouseRegion(
          onExit: _onExit,
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
