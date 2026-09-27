import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'room_inputs.dart';
import 'separator.dart';

/// Spec 10 D20: the Separator tool (S). A `PlacementTool` of **two clicks
/// per separator**, not chained (R-20): after the second click it waits for
/// a new first click. Escape cancels a pending start, then returns to the
/// select tool.
///
/// - **Points** resolve through the drawing tools' chain and mask (05 D4,
///   `kDragSnapMask`), as the Line tool's do: decision 17's "existing
///   snaps".
/// - **Band trimming** (R-21): the second click stores what
///   [trimSeparator] makes of the two resolved points, over the shell's
///   [RoomInputs], with F3's object snap. Nothing when it makes nothing
///   (both ends in one band, or too short): the start stays pending.
/// - **The commit**: one [CompoundCommand], the separator's group at the
///   identity and its [SeparatorParams], needing structure, components and
///   geometry: one undo step. A refused commit places nothing.
/// - **The rubber band** is the segment from the start to the hover point,
///   as [trimSeparator] would store it: computed per pointer move, painted
///   per frame from two stored points.
///
/// The inputs are invalidated at every second click, before the trim, and
/// right after the commit (Ruling 10-11): the document's change stream
/// delivers after the current task.
class SeparatorTool extends PlacementTool {
  SeparatorTool(this.inputs);

  /// The shell's document adapter, shared with the Room tool and the
  /// separator grips (Ruling 10-11). The tool never disposes it.
  final RoomInputs inputs;

  /// The context of the last hover, for [hovered], which has none.
  ToolContext? _context;

  /// The rubber band, as it would be stored. Reused, never reallocated.
  final Vector2 _bandStart = Vector2.zero();
  final Vector2 _bandEnd = Vector2.zero();
  bool _bandShown = false;

  /// The rubber band's two points, or null when none is drawn.
  @visibleForTesting
  (Vector2, Vector2)? get debugBand =>
      points.isEmpty || !_bandShown ? null : (_bandStart, _bandEnd);

  @override
  String get name => 'Separator';

  static bool _objectSnap(ToolContext? ctx) => ctx?.snap?.objectSnap ?? true;

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    _context = ctx;
    super.onPointerMove(e, ctx);
  }

  /// Runs after every hover's resolution, so [hoverPoint] is the resolved
  /// point. With no start pending there is no rubber band.
  @override
  void hovered(Vector2 raw) {
    _bandShown = false;
    if (points.isEmpty) return;
    final trimmed = trimSeparator(points.first, hoverPoint, inputs,
        objectSnap: _objectSnap(_context));
    if (trimmed == null) return;
    _bandStart.setFrom(trimmed.$1);
    _bandEnd.setFrom(trimmed.$2);
    _bandShown = true;
  }

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      _bandShown = false;
      return;
    }
    inputs.invalidate();
    final trimmed = trimSeparator(points.first, point, inputs,
        objectSnap: _objectSnap(ctx));
    if (trimmed == null) return;
    final (s, e) = trimmed;
    try {
      commit(ctx, () {
        final doc = ctx.document;
        final h = doc.handleSeed.next();
        return CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<SeparatorParams>(
              h, SeparatorParams(s.x, s.y, e.x, e.y)),
        ], label: 'Add separator');
      }, needs: const {
        Capability.structure,
        Capability.components,
        Capability.geometry,
      });
    } on ArgumentError {
      // Refused: nothing is placed.
    } on StateError {
      // Likewise.
    }
    inputs.invalidate();
    clearShape();
  }

  @override
  void finish(ToolContext ctx) => clearShape();

  @override
  void clearShape() {
    super.clearShape();
    _bandShown = false;
  }

  /// The pending separator, trimmed as it would be stored.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    if (points.isEmpty || !hoverVisible || !_bandShown) return;
    band
      ..reset()
      ..moveTo(_bandStart.x - origin.x, _bandStart.y - origin.y)
      ..lineTo(_bandEnd.x - origin.x, _bandEnd.y - origin.y);
    canvas.drawPath(band, bandPaint);
  }
}
