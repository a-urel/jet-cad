import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks a subtree whose pointers are its own (host embedding API spec G-5):
/// a widget a host lays over the canvas -- a badge on a table -- that takes
/// the pointers landing on it, so the canvas under it does not act on them
/// too.
///
/// The canvas's raw listeners, [InteractionLayer] and
/// [CameraGestureDetector], are ancestors of such a widget and sit on the
/// same hit-test path, so without a mark they would hear every pointer the
/// widget hears. The mark is a render object on that path: Flutter
/// dispatches a pointer event along the path from the deepest entry up, so
/// the mark hears an event before any ancestor's listener does, and an
/// ancestor asks [claimed] what it heard.
///
/// A claim must therefore sit below (deeper than) every listener that
/// consults it: a listener inside or below a claim hears a down before the
/// claim records it, so the down reads as unclaimed and its moves and up as
/// claimed, which leaves that listener's tool pressed.
///
/// What a claim takes:
///
/// - **A pointer that goes down on it**, of any kind and any button, from
///   that down through its up or cancel: the down, every move, the up. An
///   ancestor that asks [claimed] ignores the whole sequence, so a tap is
///   the widget's alone, a drag that starts on it moves nothing under it,
///   and a finger on it is no finger of a pinch. A pointer that goes down
///   **off** the claim is not claimed, wherever it moves afterwards.
/// - **A hover** that lands on it: [claimed] is true for that hover event.
/// - **A pointer signal** (a wheel, a scale) that lands on it: [claimed] is
///   true for that event. It is not taken outright: the camera then defers
///   to Flutter's [PointerSignalResolver], so a wheel over a claim still
///   zooms unless something inside the claim (a scrollable) registers for
///   the signal first.
///
/// A trackpad's pan and zoom ([PointerPanZoomStartEvent] and its updates)
/// is never claimed: it is the camera's anywhere on the canvas.
///
/// The claim is hit only where its child is: a transparent gap in the
/// child, which hits nothing, is the canvas's.
///
/// **Cost.** Nothing at all for a pointer that is not claimed: [claimed]
/// reads an empty map and compares one reference. A claimed down records
/// its pointer and adds one pointer route, which removes both on the
/// pointer's up or cancel.
class InputClaim extends SingleChildRenderObjectWidget {
  const InputClaim({super.key, super.child});

  @override
  RenderInputClaim createRenderObject(BuildContext context) =>
      RenderInputClaim();

  /// Whether [event] is claimed by an [InputClaim] on its hit-test path.
  ///
  /// For a [PointerDownEvent], a [PointerMoveEvent], a [PointerUpEvent] or
  /// a [PointerCancelEvent]: whether the pointer's down went through a
  /// claim, so true from that down through its up or cancel, for every
  /// listener that hears them. For a [PointerHoverEvent] or a
  /// [PointerSignalEvent]: whether that event went through a claim. False
  /// for anything else.
  ///
  /// Meaningful in a handler of an **ancestor** of the claim, which hears
  /// the event after it; that is where the canvas's listeners are.
  static bool claimed(PointerEvent event) => RenderInputClaim.claimed(event);
}

/// The render object of an [InputClaim]: a [RenderProxyBox] that records,
/// in [handleEvent], the pointers whose down reached it and the last hover
/// or signal that did.
class RenderInputClaim extends RenderProxyBox {
  RenderInputClaim({RenderBox? child}) : super(child);

  /// Each claimed pointer's down, untransformed, until its up or cancel.
  static final Map<int, PointerEvent> _downs = <int, PointerEvent>{};

  /// The last hover or signal, untransformed, that reached a claim.
  static PointerEvent? _passed;

  /// How many pointers are claimed now: 0 whenever no pointer is down on a
  /// claim.
  @visibleForTesting
  static int get debugClaimedPointers => _downs.length;

  /// See [InputClaim.claimed].
  static bool claimed(PointerEvent event) {
    if (event is PointerHoverEvent || event is PointerSignalEvent) {
      return identical(_passed, event.original ?? event);
    }
    if (_downs.isEmpty) return false;
    if (event is PointerDownEvent) {
      final down = _downs[event.pointer];
      if (down == null) return false;
      if (identical(down, event.original ?? event)) return true;
      // A down that missed every claim, on the id of a pointer whose up
      // never arrived (a test that left it down): that record is stale.
      _forget(event.pointer);
      return false;
    }
    if (event is PointerMoveEvent ||
        event is PointerUpEvent ||
        event is PointerCancelEvent) {
      return _downs.containsKey(event.pointer);
    }
    return false;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      final pointer = event.pointer;
      // A claim inside a claim hears the same down twice: one record, one
      // route.
      final fresh = !_downs.containsKey(pointer);
      _downs[pointer] = event.original ?? event;
      if (fresh) {
        // The binding routes a pointer's events after the whole hit-test
        // path has heard them: the record outlives every listener's up.
        GestureBinding.instance.pointerRouter.addRoute(pointer, _release);
      }
    } else if (event is PointerHoverEvent || event is PointerSignalEvent) {
      _passed = event.original ?? event;
    }
  }

  /// The claimed pointer's route: its up or cancel ends the claim.
  static void _release(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _forget(event.pointer);
    }
  }

  static void _forget(int pointer) {
    if (_downs.remove(pointer) == null) return;
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _release);
  }
}
