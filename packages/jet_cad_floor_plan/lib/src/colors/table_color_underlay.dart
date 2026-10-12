// A page export's underlay of the plan's coloured tables (plan colours spec
// PC-7): each table's colour as a fill of its top under the drawing, in
// the export and in the print. The paper is white, so no tone is applied
// (a dark canvas tones; a sheet does not).
//
// Dart over `package:jet_cad_2d` and the render package's underlay types,
// with the table and component types of this package; no handle crosses
// the host barrel.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageUnderlayCircle, PageUnderlayFill, PageUnderlayPolygon;

import '../service/table_picker.dart';
import '../tables/table_color_component.dart';
import '../tables/table_index.dart';

/// The underlay of [document]'s coloured tables (plan colours spec PC-7):
/// every live table on a visible layer whose colour this release knows, its
/// top in its definition's space (a polygon closed and triangulated,
/// skipped when it does not triangulate; or a circle), its instance's
/// transform, its hue at alpha `round(255 * opacity)`. Ascending by
/// instance handle. White paper: no tone.
///
/// A table with no top (R-8), a colour of an unknown name and a table on a
/// hidden layer have no fill, as on the canvas. Tables are root-level
/// (`TableSurvey`'s rule), so the instance's transform is its world one.
List<PageUnderlayFill> tableColorUnderlay(
    DraftDocument document, double opacity) {
  final alpha = (255 * opacity).round();
  final layers = document.tables.layers;
  final out = <PageUnderlayFill>[];
  for (final t in TableSurvey.of(document).tables) {
    final colour =
        document.components.get<FloorPlanTableColor>(t.instance)?.colorValue;
    if (colour == null) continue;
    final node = document.tree[t.instance];
    if (node is! InstanceNode) continue;
    if (layers[node.layer] case final l? when !l.visible) continue;
    final argb = (alpha << 24) | colour.rgb;
    switch (tableTopOf(document, t.definition)) {
      case PolygonTop(:final xy):
        final n = xy.length ~/ 2;
        final closed = Float64List(2 * (n + 1))
          ..setRange(0, 2 * n, xy)
          ..[2 * n] = xy[0]
          ..[2 * n + 1] = xy[1];
        final triangles = triangulateSimplePolygon(closed, n + 1);
        if (triangles.isEmpty) continue;
        out.add(PageUnderlayPolygon(
            placement: node.transform,
            argb: argb,
            xy: closed,
            count: n + 1,
            triangles: triangles));
      case CircleTop(:final cx, :final cy, :final r):
        out.add(PageUnderlayCircle(
            placement: node.transform, argb: argb, cx: cx, cy: cy, r: r));
      case null:
        break;
    }
  }
  return out;
}
