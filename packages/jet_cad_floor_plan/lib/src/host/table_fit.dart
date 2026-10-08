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
ViewportTransform frameTables(Aabb2 box, Size viewport) {
  assert(!box.isEmpty, 'frameTables needs a non-empty box');
  var minX = box.minX - kTableFitMarginMm, maxX = box.maxX + kTableFitMarginMm;
  var minY = box.minY - kTableFitMarginMm, maxY = box.maxY + kTableFitMarginMm;
  final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  if (maxX - minX < kTableFitMinSpanMm) {
    minX = cx - kTableFitMinSpanMm / 2;
    maxX = cx + kTableFitMinSpanMm / 2;
  }
  if (maxY - minY < kTableFitMinSpanMm) {
    minY = cy - kTableFitMinSpanMm / 2;
    maxY = cy + kTableFitMinSpanMm / 2;
  }
  final fit =
      ViewportTransform.fit(Aabb2.raw(minX, minY, maxX, maxY), viewport);
  final s = fit.worldToScreenMatrix.a;
  final clamped = s.clamp(kMinScale, kMaxScale);
  if (clamped == s) return fit;
  // Dead in practice (a 316,000 px view, a 950 m box), and harmless: the
  // same centre at the bound's scale.
  final mx = (minX + maxX) / 2, my = (minY + maxY) / 2;
  return ViewportTransform(
      worldToScreenMatrix: Transform2(
          clamped,
          0,
          0,
          -clamped,
          viewport.width / 2 - clamped * mx,
          viewport.height / 2 + clamped * my));
}
