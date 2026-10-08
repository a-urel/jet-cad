// Picking a table in the selection mode (spec 14c S1, S2): a point inside a
// table's top selects it, whatever else is drawn there; failing that, a
// point inside the table symbol's bounding box (its chairs, the space
// between them) does (the human, 2026-10-04: no line has to be hit).
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_index.dart';
import '../tables/table_label.dart' show firstLeafOf;

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
/// a closed polyline (its last vertex repeating its first, by exact `==`)
/// or a circle; null otherwise (such a table is not filled, R-8, and is
/// picked by its box alone). [leavesByOwner] as for [firstLeafOf].
TableTop? tableTopOf(DraftDocument doc, Handle definition,
    [Map<Handle, List<int>>? leavesByOwner]) {
  final leaf = firstLeafOf(doc, definition, leavesByOwner);
  if (leaf == null) return null;
  final payload = leaf.payload;
  switch (leaf.kind) {
    case EntityKind.circle:
      return CircleTop(
          payload.coords[0], payload.coords[1], payload.scalars[0]);
    case EntityKind.polyline:
      if (!isClosedPolyline(payload)) return null;
      // The closing vertex repeating the first is dropped.
      final xy = payload.coords;
      return PolygonTop(
          Float64List.fromList(Float64List.sublistView(xy, 0, xy.length - 2)));
    default:
      return null;
  }
}

/// A table the planner can show and act on (zone spec Z0): a survey table
/// on a visible layer, its transform's determinant finite and non-zero,
/// its box non-empty, and the box's four corners finite in the world. The
/// one rule for the picker, the framing and the focus.
final class TableCandidate {
  TableCandidate(
      {required this.table,
      required this.transform,
      required this.box,
      required this.corners,
      required this.locked});

  final TableInfo table;

  /// Definition space to world: the instance's transform.
  final Transform2 transform;

  /// The symbol's bounding box in definition space.
  final Aabb2 box;

  /// [box]'s corners in the world, `x0, y0, ..., x3, y3`: its (min, min),
  /// (max, min), (max, max) and (min, max) through [transform], every one
  /// finite. Counter-clockwise unless the transform mirrors.
  final Float64List corners;

  /// On a locked layer (S9).
  final bool locked;

  /// The axis-aligned bound of [corners] (zone spec Z2): what a framing
  /// frames.
  Aabb2 get worldBounds {
    var minX = corners[0], minY = corners[1], maxX = minX, maxY = minY;
    for (var i = 2; i < 8; i += 2) {
      minX = math.min(minX, corners[i]);
      maxX = math.max(maxX, corners[i]);
      minY = math.min(minY, corners[i + 1]);
      maxY = math.max(maxY, corners[i + 1]);
    }
    return Aabb2.raw(minX, minY, maxX, maxY);
  }
}

/// One table the picker can hit.
final class PickCandidate {
  PickCandidate(
      {required this.table,
      required this.inverse,
      required this.top,
      required this.box,
      required this.locked,
      required this.scale});

  final TableInfo table;

  /// World to definition space.
  final Transform2 inverse;

  /// Null when the first leaf is no top (R-8).
  final TableTop? top;

  /// The symbol's bounding box in definition space: it turns and mirrors
  /// with the table.
  final Aabb2 box;

  /// On a locked layer: picked, not moved (S9).
  final bool locked;

  /// The instance's linear scale, `sqrt(|det|)`: definition units to world.
  final double scale;
}

/// The tables of one plan, ready to pick (S1). The candidates are rebuilt
/// when the plan's state id or its tables' revision moves, never per
/// pointer event; the tops and boxes are kept per definition for the
/// picker's life (R-8: under `runtime` a definition cannot change).
class TablePicker {
  TablePicker(this.document,
      {@visibleForTesting Map<Handle, List<int>> Function()? leavesByOwner})
      : _leavesByOwner = leavesByOwner ?? document.leavesByOwner;

  final DraftDocument document;

  /// [DraftDocument.leavesByOwner], the one entity-store scan of a build;
  /// a test hands in its own to count the scans and to see that every
  /// definition reads the map it returns.
  final Map<Handle, List<int>> Function() _leavesByOwner;

  /// The boundary tolerance (S1): a point on a top's edge is inside.
  static const Tolerance tolerance = Tolerance(linear: 1e-6, angular: 1e-9);

  List<PickCandidate> _candidates = const [];
  final Map<Handle, TableTop?> _tops = {};
  final Map<Handle, Aabb2> _boxes = {};
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
    // One entity-store scan per build, shared by every definition not yet
    // cached, never one per definition (`DraftDocument.definitionBounds`).
    Map<Handle, List<int>>? leaves;
    Map<Handle, List<int>> scan() => leaves ??= _leavesByOwner();
    return [
      for (final c in candidatesOf(document, boxes: _boxes, leaves: scan))
        PickCandidate(
            table: c.table,
            inverse: c.transform.invert(),
            top: _tops.putIfAbsent(c.table.definition,
                () => tableTopOf(document, c.table.definition, scan())),
            box: c.box,
            locked: c.locked,
            scale: math.sqrt(c.transform.determinant.abs())),
    ];
  }

  /// The candidates of [document] (zone spec Z0), ascending by instance
  /// handle. [boxes] caches the definitions' boxes: the picker keeps its
  /// own for its life; a caller with none passes a fresh map. [leaves] is
  /// [DraftDocument.leavesByOwner] or a stand-in, called at most once, and
  /// only when a definition's box is not cached.
  ///
  /// O(nodes + entities): at document-change rate, or at call rate for a
  /// framing, never per frame.
  static List<TableCandidate> candidatesOf(DraftDocument document,
      {required Map<Handle, Aabb2> boxes,
      required Map<Handle, List<int>> Function() leaves}) {
    final out = <TableCandidate>[];
    Map<Handle, List<int>>? scanned;
    for (final t in TableSurvey.of(document).tables) {
      final node = document.tree[t.instance];
      if (node is! InstanceNode) continue;
      final layer = document.tables.layers[node.layer];
      if (layer != null && !layer.visible) continue;
      final m = node.transform;
      final det = m.determinant;
      if (det == 0 || !det.isFinite) continue;
      final box = boxes.putIfAbsent(t.definition,
          () => document.definitionBounds(t.definition, scanned ??= leaves()));
      if (box.isEmpty) continue;
      final corners = Float64List(8);
      void corner(int i, double x, double y) {
        corners[2 * i] = m.a * x + m.c * y + m.e;
        corners[2 * i + 1] = m.b * x + m.d * y + m.f;
      }

      corner(0, box.minX, box.minY);
      corner(1, box.maxX, box.minY);
      corner(2, box.maxX, box.maxY);
      corner(3, box.minX, box.maxY);
      // A NaN or infinite corner (a hand-edited file) is no place: it
      // would poison a framing's bound and a region's path (zone spec Z0).
      if (!corners.every((v) => v.isFinite)) continue;
      out.add(TableCandidate(
          table: t,
          transform: m,
          box: box,
          corners: corners,
          locked: layer?.locked ?? false));
    }
    return out;
  }

  /// The table whose top holds [world], the highest handle among several
  /// (draw order); else the table whose box holds it, the highest handle
  /// among several (a top is never lost under a neighbour's chairs); else
  /// null. On a miss, with a [reach] (a finger's, spec 14t R-11), the
  /// table whose box is nearest within [reach] world units, the higher
  /// handle on a tie.
  PickCandidate? pick(Vector2 world, {double reach = 0}) {
    final list = candidates;
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      final local = c.inverse.transformPoint(world);
      if (c.top?.contains(local.x, local.y, tolerance) ?? false) return c;
    }
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      final local = c.inverse.transformPoint(world);
      if (_boxDistance(c.box, local.x, local.y) <= tolerance.linear) return c;
    }
    if (reach <= 0) return null;
    PickCandidate? best;
    var bestDistance = reach;
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      final local = c.inverse.transformPoint(world);
      // Local units to world: the instance's scale (placements turn and
      // mirror, so it is 1 unless a table was scaled by hand).
      final d = _boxDistance(c.box, local.x, local.y) * c.scale;
      if (d < bestDistance || (best == null && d <= bestDistance)) {
        best = c;
        bestDistance = d;
      }
    }
    return best;
  }

  /// The distance from ([x], [y]) to [box]; zero inside it.
  static double _boxDistance(Aabb2 box, double x, double y) {
    final dx = math.max(math.max(box.minX - x, x - box.maxX), 0.0);
    final dy = math.max(math.max(box.minY - y, y - box.maxY), 0.0);
    return math.sqrt(dx * dx + dy * dy);
  }
}
