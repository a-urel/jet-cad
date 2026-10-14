// A page export's underlay of the plan's coloured units (plan colours spec
// PC-7; 2b spec S4 "Painting"): each unit's colour as a fill of its top
// under the drawing, in the export and in the print. The paper is white,
// so no tone is applied. Ported from jet_cad_floor_plan/lib/src/colors/
// table_color_underlay.dart over units, placed and generated.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageUnderlayCircle, PageUnderlayFill, PageUnderlayPolygon;
import 'package:meta/meta.dart' show internal;

import '../service/unit_picker.dart' show CircleTop, PolygonTop, unitTopOf;
import '../units/unit_components.dart' show UnitColour;
import '../units/unit_index.dart' show UnitIndex;
import '../theme/plan_theme.dart' show kUnitColourOpacity;

/// The underlay of [document]'s coloured units, as [index] reads them:
/// every unit on a visible layer whose colour this release knows, not of
/// an object in [omitted] (a type with `exported: false`), its top in its
/// definition's space (a polygon closed and triangulated, skipped when it
/// does not triangulate; or a circle), placed by the unit's world
/// transform (a seat's: its row's group × its instance), its hue at alpha
/// `round(255 * opacity)`. Ascending by instance handle. White paper: no
/// tone.
///
/// A unit with no top, a colour of an unknown name and a unit on a hidden
/// layer have no fill, as on the canvas. A self-intersecting polygon top
/// is skipped here while the canvas fills it (today's known difference).
///
/// Throws an [ArgumentError] when [opacity] is not finite or lies outside
/// `[0, 1]`.
@internal
List<PageUnderlayFill> unitColourUnderlay(
    UnitIndex index, DraftDocument document, double opacity,
    {Set<Handle> omitted = const {}}) {
  if (!opacity.isFinite || opacity < 0 || opacity > 1) {
    throw ArgumentError.value(opacity, 'opacity', 'must be in [0, 1]');
  }
  final alpha = (255 * opacity).round();
  final out = <PageUnderlayFill>[];
  for (final u in index.units) {
    final colour = document.components.get<UnitColour>(u.instance)?.swatch;
    if (colour == null || !u.visible) continue;
    if (u.owner case final owner? when omitted.contains(owner)) continue;
    final argb = (alpha << 24) | colour.rgb;
    switch (unitTopOf(document, u.definition)) {
      case PolygonTop(:final xy):
        final n = xy.length ~/ 2;
        final closed = Float64List(2 * (n + 1))
          ..setRange(0, 2 * n, xy)
          ..[2 * n] = xy[0]
          ..[2 * n + 1] = xy[1];
        final triangles = triangulateSimplePolygon(closed, n + 1);
        if (triangles.isEmpty) continue;
        out.add(PageUnderlayPolygon(
            placement: u.toWorld,
            argb: argb,
            xy: closed,
            count: n + 1,
            triangles: triangles));
      case CircleTop(:final cx, :final cy, :final r):
        out.add(PageUnderlayCircle(
            placement: u.toWorld, argb: argb, cx: cx, cy: cy, r: r));
      case null:
        break;
    }
  }
  return out;
}

/// [given], or [kUnitColourOpacity] when null; an [ArgumentError] named
/// `unitColourOpacity` when it is not finite or lies outside `[0, 1]`
/// (today's `_checkedOpacity`, floor_plan_controller.dart:1374-1383).
@internal
double checkedUnitColourOpacity(double? given) {
  if (given == null) return kUnitColourOpacity;
  if (!given.isFinite || given < 0 || given > 1) {
    throw ArgumentError.value(given, 'unitColourOpacity', 'must be in [0, 1]');
  }
  return given;
}

/// The unit fills a request's built-in exporter draws, set by the flows
/// before they call it: an exporter is handed a codec copy and no catalog,
/// so the fills are made from the live document's unit index.
@internal
final Expando<List<PageUnderlayFill>> unitFillsOf =
    Expando<List<PageUnderlayFill>>('unit fills');
