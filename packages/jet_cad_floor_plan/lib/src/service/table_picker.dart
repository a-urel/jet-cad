// Picking a table in the selection mode (spec 14c S1, S2): a point inside a
// table's top selects it, whatever else is drawn there.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_index.dart';

/// A table's top in definition space (14s S4): its first leaf.
sealed class TableTop {
  const TableTop();

  /// Whether ([x], [y]) is inside, a point within [tolerance] of the
  /// boundary counting as inside (S1).
  bool contains(double x, double y, Tolerance tolerance);
}

/// A closed polyline's vertices, `x0, y0, x1, y1, ...`.
final class PolygonTop extends TableTop {
  PolygonTop(this.xy);

  final Float64List xy;

  @override
  bool contains(double x, double y, Tolerance tolerance) {
    final n = xy.length ~/ 2;
    if (n < 3) return false;
    var inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = xy[2 * i], yi = xy[2 * i + 1];
      final xj = xy[2 * j], yj = xy[2 * j + 1];
      if (_segmentDistance(x, y, xi, yi, xj, yj) <= tolerance.linear) {
        return true;
      }
      // Even-odd: a ray to +x crosses the edge.
      if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _segmentDistance(
      double px, double py, double ax, double ay, double bx, double by) {
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx - px, cy = ay + t * dy - py;
    return math.sqrt(cx * cx + cy * cy);
  }
}

/// A circle's centre and radius.
final class CircleTop extends TableTop {
  const CircleTop(this.cx, this.cy, this.r);

  final double cx, cy, r;

  @override
  bool contains(double x, double y, Tolerance tolerance) {
    final dx = x - cx, dy = y - cy;
    return math.sqrt(dx * dx + dy * dy) <= r + tolerance.linear;
  }
}

/// The top of [definition] in [doc]: its lowest-handle leaf, when that is
/// a closed polyline or a circle; null otherwise (such a table cannot be
/// picked).
TableTop? tableTopOf(DraftDocument doc, Handle definition) {
  final e = doc.entities;
  int? best;
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != definition) continue;
    if (best == null || e.handleAt(slot).value < e.handleAt(best).value) {
      best = slot;
    }
  }
  if (best == null) return null;
  final payload = doc.geometry.read(e.geomIndexAt(best));
  switch (e.kindAt(best)) {
    case EntityKind.circle:
      return CircleTop(
          payload.coords[0], payload.coords[1], payload.scalars[0]);
    case EntityKind.polyline:
      var xy = payload.coords;
      final n = xy.length;
      // A closing vertex repeating the first is dropped.
      if (n >= 4 && xy[0] == xy[n - 2] && xy[1] == xy[n - 1]) {
        xy = Float64List.sublistView(xy, 0, n - 2);
      }
      return PolygonTop(Float64List.fromList(xy));
    default:
      return null;
  }
}

/// One table the picker can hit.
final class PickCandidate {
  PickCandidate(
      {required this.table,
      required this.inverse,
      required this.top,
      required this.locked});

  final TableInfo table;

  /// World to definition space.
  final Transform2 inverse;
  final TableTop top;

  /// On a locked layer: picked, not moved (S9).
  final bool locked;
}

/// The tables of one plan, ready to pick (S1). Rebuilt when the plan's
/// state id or its tables' revision moves, never per pointer event.
class TablePicker {
  TablePicker(this.document);

  final DraftDocument document;

  /// The boundary tolerance (S1): a point on a top's edge is inside.
  static const Tolerance tolerance = Tolerance(linear: 1e-6, angular: 1e-9);

  List<PickCandidate> _candidates = const [];
  int? _state;
  int? _tablesRevision;

  /// The candidates, ascending by instance handle.
  List<PickCandidate> get candidates {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    if (_state != state || _tablesRevision != revision) {
      _candidates = _build();
      _state = state;
      _tablesRevision = revision;
    }
    return _candidates;
  }

  List<PickCandidate> _build() {
    final tops = <Handle, TableTop?>{};
    final out = <PickCandidate>[];
    for (final t in TableSurvey.of(document).tables) {
      final node = document.tree[t.instance];
      if (node is! InstanceNode) continue;
      final layer = document.tables.layers[node.layer];
      if (layer != null && !layer.visible) continue;
      final det = node.transform.determinant;
      if (det == 0 || !det.isFinite) continue;
      final top = tops.putIfAbsent(
          t.definition, () => tableTopOf(document, t.definition));
      if (top == null) continue;
      out.add(PickCandidate(
          table: t,
          inverse: node.transform.invert(),
          top: top,
          locked: layer?.locked ?? false));
    }
    return out;
  }

  /// The table whose top holds [world], the highest handle among several
  /// (draw order), or null.
  PickCandidate? pick(Vector2 world) {
    final list = candidates;
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      final local = c.inverse.transformPoint(world);
      if (c.top.contains(local.x, local.y, tolerance)) return c;
    }
    return null;
  }
}
