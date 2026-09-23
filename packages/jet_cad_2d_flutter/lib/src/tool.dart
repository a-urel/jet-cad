import 'dart:ui' show Canvas, Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show KeyEvent, MouseCursor;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'grip_cache.dart';
import 'page_notifier.dart';
import 'selection.dart';
import 'snap_settings.dart';
import 'viewport_transform.dart';

/// One pointer sample handed to a [Tool], already resolved into both screen
/// and world space so a tool never has to invert the camera itself.
final class ToolPointerEvent {
  const ToolPointerEvent({
    required this.screen,
    required this.world,
    required this.pointer,
    required this.buttons,
    required this.shift,
    required this.control,
    required this.meta,
    required this.alt,
    required this.pickRadiusWorld,
  });

  final Offset screen;
  final Vector2 world;
  final int pointer;
  final int buttons;
  final bool shift, control, meta, alt;
  final double pickRadiusWorld;
}

/// Everything a [Tool] needs to act: the document to mutate, the index to
/// query, the camera to read, the selection to update — and, since 03, the
/// page, the snap settings and the grips, each optional so every 02 call
/// site still compiles (spec D10).
final class ToolContext {
  const ToolContext({
    required this.document,
    required this.index,
    required this.camera,
    required this.selection,
    this.page,
    this.snap,
    this.grips,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final SelectionController selection;

  /// The page, for the drag's grid snap; null: no grid snap.
  final PageNotifier? page;

  /// F3's toggle; null: object snap is on.
  final SnapSettings? snap;

  /// The selection's grips and box; null: no grip or rotation grip is drawn
  /// or hit.
  final GripCache? grips;

  void execute(DraftCommand command) => document.commands.execute(command);
}

enum ToolPhase { idle, pressed, dragging }

/// The interface every interactive tool implements. A `ChangeNotifier` so
/// [ToolController] can forward a tool's own notifications (an overlay
/// change, a phase change) without polling.
abstract class Tool extends ChangeNotifier {
  String get name;
  ToolPhase get phase;
  void onPointerDown(ToolPointerEvent e, ToolContext ctx);
  void onPointerMove(ToolPointerEvent e, ToolContext ctx);
  void onPointerUp(ToolPointerEvent e, ToolContext ctx);
  void onPointerExit(ToolContext ctx);
  KeyEventResult onKey(KeyEvent event, ToolContext ctx);
  void cancel(ToolContext ctx);
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport);

  /// The pointer's cursor over the layer (spec 03 D5). `InteractionLayer`
  /// rebuilds its `MouseRegion` when the tool notifies.
  MouseCursor get cursor => MouseCursor.defer;

  /// The world transform a live move or rotate would apply, for the
  /// overlay's preview (spec 03 D7); null otherwise.
  Transform2? get selectionPreviewTransform => null;

  /// Paints under the overlay's rebased world matrix, `worldToScreen ∘
  /// translate(origin)`, so coordinates handed to [canvas] must be `world −
  /// origin` (Ruling 03-3). [scale] is the camera's, for stroke widths.
  void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {}
}

/// Holds the active [Tool] and forwards its notifications, so a widget can
/// listen to the controller alone rather than re-subscribing on every swap.
class ToolController extends ChangeNotifier {
  ToolController({required Tool initial, required this.context})
      : _active = initial {
    _active.addListener(_forward);
  }

  final ToolContext context;
  Tool _active;
  Tool get active => _active;

  void activate(Tool next) {
    if (identical(next, _active)) return;
    // Unhook the outgoing tool's listener before cancelling it: `cancel`
    // may itself call `notifyListeners` (a tool that clears its own overlay
    // on cancel, for instance), and that must not be forwarded — this
    // `activate` call notifies exactly once, at the end, for the swap.
    _active.removeListener(_forward);
    _active.cancel(context);
    _active = next;
    _active.addListener(_forward);
    notifyListeners();
  }

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _active.removeListener(_forward);
    super.dispose();
  }
}
