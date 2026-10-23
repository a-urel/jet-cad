// Alignment guides in design moves (alignment guides spec, "The delta" and
// "Priority against the existing chain"): the plan's MoveAdjuster for
// plan.select. After the snap chain has resolved a body move's target, it
// solves the guides on the moved objects' box and replaces the target on
// each axis a guide captures.
import 'dart:ui' show Canvas, Size;

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'guide_painter.dart';
import 'guide_references.dart';
import 'guide_settings.dart';
import 'guide_solver.dart';

/// The guides of a design move. One per document session; it allocates
/// nothing per [adjust] or [paint] (one solution, one box, one painter).
final class PlanMoveGuides implements MoveAdjuster {
  PlanMoveGuides(
      {required this.references,
      required this.settings,
      required this.strokePixels,
      required this.movable});

  final GuideReferenceCache references;
  final PlanGuideSettings settings;

  /// The guide stroke in screen pixels, read at paint.
  final double Function() strokePixels;

  /// Whether the root-level node [Handle] is a movable object: a root
  /// instance. A leaf entity, a group or a line is not.
  final bool Function(Handle root) movable;

  final GuideSolution _solution = GuideSolution();
  final GuidePainter _painter = GuidePainter();
  final Float64List _box = Float64List(4);
  Set<Handle>? _moving;
  bool _eligible = false;

  /// The last solution, the one [paint] draws (tests read it).
  @visibleForTesting
  GuideSolution get debugSolution => _solution;

  @override
  Listenable get changes => settings;

  @override
  void begin(ToolContext ctx, Set<Handle> moving) {
    _solution.reset();
    _moving = moving;
    _eligible = false;
    // Drag start: the loop may allocate. Every moved handle must be a
    // movable object, and at least one must have a box.
    for (final h in moving) {
      if (!movable(h)) return;
    }
    _eligible = references.unionOf(moving, _box);
  }

  @override
  void adjust(ToolContext ctx,
      {required Vector2 raw,
      required Vector2 base,
      required Vector2? orthoBase,
      required bool objectSnapped,
      required bool touch,
      required bool alt,
      required Vector2 target}) {
    final moving = _moving;
    if (moving == null || !_eligible || !settings.on || alt) {
      _solution.reset();
      return;
    }
    final scale = ctx.camera.value.scale;
    final aperture =
        (touch ? kGuideTouchAperturePixels : kGuideAperturePixels) / scale;
    // Shift: the axis the chain pins takes no guide (resolveDragPoint's
    // rule: the major axis moves, the minor one is pinned).
    var freeX = true, freeY = true;
    if (orthoBase != null) {
      final dx = raw.x - orthoBase.x, dy = raw.y - orthoBase.y;
      if (dx.abs() >= dy.abs()) {
        freeY = false;
      } else {
        freeX = false;
      }
    }
    final dRawX = raw.x - base.x, dRawY = raw.y - base.y;
    solveGuides(references.current,
        minX: _box[0] + dRawX,
        minY: _box[1] + dRawY,
        maxX: _box[2] + dRawX,
        maxY: _box[3] + dRawY,
        aperture: aperture,
        freeX: freeX,
        freeY: freeY,
        fallbackDx: target.x - raw.x,
        fallbackDy: target.y - raw.y,
        moving: moving,
        out: _solution);
    // Only a captured axis is written: the other keeps the chain's value
    // bit for bit. An object-snapped target is replaced too (C-8).
    if (_solution.capturedX) target.x = raw.x + _solution.dx;
    if (_solution.capturedY) target.y = raw.y + _solution.dy;
  }

  @override
  void suppress() => _solution.reset();

  @override
  void paint(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    if (_solution.lineCount == 0 && _solution.markCount == 0) return;
    _painter.paint(canvas, camera.worldToScreenMatrix, _solution,
        color: paper.guideColor, strokePixels: strokePixels());
  }

  @override
  void end() {
    _solution.reset();
    _moving = null;
    _eligible = false;
  }
}
