import 'dart:ui' show Canvas, Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show KeyEvent;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'selection.dart';
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
/// query, the camera to read, and the selection to update.
final class ToolContext {
  const ToolContext({
    required this.document,
    required this.index,
    required this.camera,
    required this.selection,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final SelectionController selection;

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
    _active.cancel(context);
    _active.removeListener(_forward);
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
