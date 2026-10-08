// Framing tables (zone spec Z3): the camera a framing sets, from the bound
// of the tables' boxes and the drawing area's size. Pure: no document, no
// controller.
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

import '../startup_plan.dart' show kMaxScale, kMinScale;

/// The floor a framing shows round its tables, per side, in millimetres:
/// an aisle, and the group frame (150 mm) at any zoom (zone spec Z3).
const double kTableFitMarginMm = 500;

/// The least span a framing shows on each axis, in millimetres: 3 m of
/// floor round one table, never a poster of it (zone spec Z3).
const double kTableFitMinSpanMm = 3000;

/// The camera that frames [box], a non-empty world bound of tables, in a
/// drawing area of [viewport] (zone spec Z3): [box] grown by
/// [kTableFitMarginMm] per side, then about its centre to at least
/// [kTableFitMinSpanMm] per axis, fitted as [ViewportTransform.fit] fits
/// (5 % margin, y flipped), its scale clamped to `[kMinScale, kMaxScale]`
/// about the same centre.
///
/// The centre is taken as `min / 2 + max / 2`, which cannot overflow where
/// `(min + max) / 2` would (Task 1 review R-1: a table near the double
/// range); halving is exact, so elsewhere the two are the same number.
ViewportTransform frameTables(Aabb2 box, Size viewport) {
  assert(!box.isEmpty, 'frameTables needs a non-empty box');
  var minX = box.minX - kTableFitMarginMm, maxX = box.maxX + kTableFitMarginMm;
  var minY = box.minY - kTableFitMarginMm, maxY = box.maxY + kTableFitMarginMm;
  final cx = minX / 2 + maxX / 2, cy = minY / 2 + maxY / 2;
  if (maxX - minX < kTableFitMinSpanMm) {
    minX = cx - kTableFitMinSpanMm / 2;
    maxX = cx + kTableFitMinSpanMm / 2;
  }
  if (maxY - minY < kTableFitMinSpanMm) {
    minY = cy - kTableFitMinSpanMm / 2;
    maxY = cy + kTableFitMinSpanMm / 2;
  }
  // The fit's scale; its translation is built here, about the safe
  // centre, since `ViewportTransform.fit` takes `(min + max) / 2`.
  final s = ViewportTransform.fit(Aabb2.raw(minX, minY, maxX, maxY), viewport)
      .worldToScreenMatrix
      .a;
  // The clamp is dead in practice (a 316,000 px view, a 950 m box), and
  // harmless: the same centre at the bound's scale.
  final clamped = s.clamp(kMinScale, kMaxScale);
  final mx = minX / 2 + maxX / 2, my = minY / 2 + maxY / 2;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(
          clamped,
          0,
          0,
          -clamped,
          viewport.width / 2 - clamped * mx,
          viewport.height / 2 + clamped * my));
}
